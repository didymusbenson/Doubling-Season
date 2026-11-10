import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

import '../domain/table_state.dart';
import '../storage/storage_namespace.dart';
import '../storage/table_repository.dart';
import 'legacy_migration.dart';

/// An isolated fixture destination. No API in this module opens legacy boxes,
/// clears them, invokes production boot, or promotes into the live table store.
abstract class LegacyMigrationStorage {
  Object get lockIdentity => this;
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> flush();
}

class HiveLegacyMigrationStorage extends LegacyMigrationStorage {
  final Box<String> _box;
  HiveLegacyMigrationStorage._(this._box);

  static Future<HiveLegacyMigrationStorage> openFixture(
    String fixtureId,
  ) async {
    if (!RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(fixtureId)) {
      throw const FormatException(
        'Use a simple, explicit migration fixture ID.',
      );
    }
    final prefix = tableStorageNamespace.isEmpty
        ? ''
        : '${tableStorageNamespace}__';
    return HiveLegacyMigrationStorage._(
      await Hive.openBox<String>(
        '${prefix}legacy_migration_fixture_${fixtureId}_v1',
      ),
    );
  }

  @override
  Object get lockIdentity => _box;
  @override
  Future<String?> read(String key) async => _box.get(key);
  @override
  Future<void> write(String key, String value) => _box.put(key, value);
  @override
  Future<void> flush() => _box.flush();
  Future<void> close() => _box.close();
}

class LegacyMigrationResult {
  final TabletState state;
  final String transactionId;
  final List<String> blockers;
  final List<String> warnings;
  final bool committed;
  LegacyMigrationResult({
    required this.state,
    required this.transactionId,
    required this.blockers,
    required this.warnings,
    required this.committed,
  });
}

/// Copy → verify → stage → verify → commit as one self-contained generation.
/// A failed/uncertain acknowledgement is retried by inspecting existing records,
/// never by clearing storage or regenerating identities. Retained records/media
/// have no automatic cleanup. All entry points serialize per physical box.
class LegacyMigrationJournal {
  static final Map<Object, Future<void>> _locks = {};
  final LegacyMigrationStorage storage;
  LegacyMigrationJournal(this.storage);

  Future<T> _locked<T>(Future<T> Function() operation) async {
    final identity = storage.lockIdentity;
    final previous = _locks[identity] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[identity] = done.future;
    await previous;
    try {
      return await operation();
    } finally {
      done.complete();
      if (identical(_locks[identity], done.future)) _locks.remove(identity);
    }
  }

  /// [localMedia] must already be copied from an authorized fixture; keys are
  /// its exact original file references. We never follow a URL or filesystem path.
  /// Missing files retain their references and are reported, not silently erased.
  Future<LegacyMigrationResult> prepare(
    LegacyMigrationSnapshot snapshot, {
    required Map<String, Uint8List> localMedia,
  }) {
    // Capture the caller's mutable bytes synchronously before the first await.
    final media = {
      for (final entry in localMedia.entries)
        entry.key: Uint8List.fromList(entry.value),
    };
    return _locked(() async {
      final manifest = <String, String>{};
      for (final entry in media.entries) {
        if (!_isLocal(entry.key) ||
            entry.value.isEmpty ||
            entry.value.length > 12 * 1024 * 1024) {
          throw FormatException('Invalid image size for ${entry.key}.');
        }
        manifest[entry.key] = sha256.convert(entry.value).toString();
      }
      final source = {'snapshot': snapshot.toJson(), 'mediaManifest': manifest};
      final transactionId = migrationDigest(source);
      final current = await _readRecord('current');
      if (current != null) {
        if (current['transactionId'] != transactionId) {
          throw StateError(
            'This destination already belongs to another snapshot.',
          );
        }
        await _verifyCommitted(current);
        return _result(current, committed: true);
      }
      await _retain('source', source);
      for (final entry in media.entries) {
        final hash = manifest[entry.key]!;
        await _retain('media_$hash', {
          'sha256': hash,
          'bytes': base64Encode(entry.value),
        });
      }
      await _verifyMedia(manifest);

      final mapped = LegacyMigrationConverter().convert(snapshot);
      final warnings = [...mapped.warnings];
      final references = _localReferences(snapshot.toJson());
      for (final ref in references) {
        if (!manifest.containsKey(ref)) {
          warnings.add('Missing local artwork retained for recovery: $ref');
        }
      }
      // Remap only known artwork fields, never a name/description containing a path.
      final remapped = _remap(mapped.state.toJson(), manifest);
      final state = TabletState.fromJson(jsonMap(remapped));
      state.library['legacyMigrationReceipt'] = {
        'version': 1,
        'mappingVersion': LegacyMigrationConverter.mappingVersion,
        'sourceId': snapshot.sourceId,
        'sourceDigest': snapshot.digest,
        'transactionId': transactionId,
        'identities': mapped.identities,
      };
      validateTabletState(state);
      final candidate = {
        'mappingVersion': LegacyMigrationConverter.mappingVersion,
        'transactionId': transactionId,
        'sourceDigest': snapshot.digest,
        'state': state.toJson(),
        'blockers': mapped.blockers,
        'warnings': warnings,
        'mediaManifest': manifest,
      };
      await _retain('candidate', candidate);
      return _result((await _readRecord('candidate'))!, committed: false);
    });
  }

  /// Commit an already validated fixture generation, with its marker in the
  /// same record as the board. This never changes TableRepository's authority.
  Future<LegacyMigrationResult> commit(String transactionId) => _locked(
    () async {
      final current = await _readRecord('current');
      if (current != null) {
        if (current['transactionId'] != transactionId) {
          throw StateError('Another migration is already committed.');
        }
        await _verifyCommitted(current);
        return _result(current, committed: true);
      }
      final source = await _readRecord('source');
      final candidate = await _readRecord('candidate');
      if (source == null ||
          candidate == null ||
          migrationDigest(source) != transactionId ||
          candidate['transactionId'] != transactionId) {
        throw StateError('A complete matching migration has not been staged.');
      }
      _verifySource(source, candidate);
      final result = _result(candidate, committed: false);
      if (result.blockers.isNotEmpty) {
        throw StateError(
          'Migration has unresolved mappings: ${result.blockers.join(' ')}',
        );
      }
      await _verifyMedia(jsonMap(candidate['mediaManifest']));
      await _retain('current', candidate);
      return _result((await _readRecord('current'))!, committed: true);
    },
  );

  Future<LegacyMigrationResult?> openCommitted() => _locked(() async {
    final record = await _readRecord('current');
    if (record == null) return null;
    await _verifyCommitted(record);
    return _result(record, committed: true);
  });

  void _verifySource(Map<String, dynamic> source, Map<String, dynamic> record) {
    final snapshot = LegacyMigrationSnapshot(jsonMap(source['snapshot']));
    if (migrationDigest(source) != record['transactionId'] ||
        snapshot.digest != record['sourceDigest'] ||
        migrationDigest(source['mediaManifest']) !=
            migrationDigest(record['mediaManifest'])) {
      throw const FormatException('Migration source/commit identity mismatch.');
    }
  }

  Future<void> _verifyCommitted(Map<String, dynamic> record) async {
    final source = await _readRecord('source');
    if (source == null) {
      throw const FormatException('Migration source is missing.');
    }
    _verifySource(source, record);
    await _verifyMedia(jsonMap(record['mediaManifest']));
    await storage.flush();
  }

  Future<Uint8List?> readMedia(String reference) => _locked(() async {
    if (!reference.startsWith('tablet-art:')) return null;
    final hash = reference.substring('tablet-art:'.length);
    final record = await _readRecord('media_$hash');
    if (record == null) return null;
    return _decodeMedia(record, hash);
  });

  Uint8List _decodeMedia(Map<String, dynamic> record, String hash) {
    final bytes = base64Decode(record['bytes'] as String);
    if (record['sha256'] != hash || sha256.convert(bytes).toString() != hash) {
      throw const FormatException('Copied artwork integrity check failed.');
    }
    return bytes;
  }

  Future<void> _verifyMedia(Map<String, dynamic> manifest) async {
    for (final hash in manifest.values.toSet()) {
      final record = await _readRecord('media_$hash');
      if (record == null) {
        throw const FormatException('Copied artwork is missing.');
      }
      _decodeMedia(record, hash as String);
    }
  }

  LegacyMigrationResult _result(
    Map<String, dynamic> record, {
    required bool committed,
  }) {
    final state = TabletState.fromJson(jsonMap(record['state']));
    validateTabletState(state);
    final receipt = jsonMap(state.library['legacyMigrationReceipt']);
    if (record['mappingVersion'] != LegacyMigrationConverter.mappingVersion ||
        receipt['mappingVersion'] != LegacyMigrationConverter.mappingVersion ||
        receipt['version'] != 1 ||
        receipt['transactionId'] != record['transactionId'] ||
        receipt['sourceDigest'] != record['sourceDigest']) {
      throw const FormatException('Migration board/marker identity mismatch.');
    }
    final blockers = List<String>.from(record['blockers'] as List);
    if (committed && blockers.isNotEmpty) {
      throw const FormatException('An incomplete migration cannot be opened.');
    }
    return LegacyMigrationResult(
      state: state,
      transactionId: record['transactionId'] as String,
      blockers: blockers,
      warnings: List<String>.from(record['warnings'] as List),
      committed: committed,
    );
  }

  Future<Map<String, dynamic>?> _readRecord(String key) async {
    final encoded = await storage.read(key);
    if (encoded == null) return null;
    final envelope = jsonMap(jsonDecode(encoded));
    if (envelope['format'] != 'legacy-migration-record' ||
        envelope['version'] != 1) {
      throw const FormatException(
        'Unsupported migration record. Data was preserved.',
      );
    }
    final payload = jsonMap(envelope['payload']);
    if (migrationDigest(payload) != envelope['sha256']) {
      throw const FormatException(
        'Migration integrity check failed. Data was preserved.',
      );
    }
    return payload;
  }

  Future<void> _retain(String key, Map<String, dynamic> payload) async {
    final existing = await _readRecord(key);
    if (existing != null) {
      if (migrationDigest(existing) != migrationDigest(payload)) {
        throw StateError('Refusing to overwrite migration record $key.');
      }
      // An earlier failed acknowledgement may have left this in the Hive cache.
      // Flush again before treating a read-back as durable.
      await storage.flush();
      return;
    }
    final encoded = canonicalMigrationJson({
      'format': 'legacy-migration-record',
      'version': 1,
      'sha256': migrationDigest(payload),
      'payload': payload,
    });
    await storage.write(key, encoded);
    await storage.flush();
    final readBack = await _readRecord(key);
    if (readBack == null ||
        migrationDigest(readBack) != migrationDigest(payload)) {
      throw const FormatException('Migration write could not be verified.');
    }
  }
}

const _artworkFields = {
  'artworkUrl',
  'customArtworkUrl',
  'imageUrl',
  'lastUsedArtwork',
  'customArtworkPath',
  'onArtworkUrl',
  'offArtworkUrl',
  'url',
};

bool _isLocal(String value) =>
    value.startsWith('file://') || value.startsWith('/');

Set<String> _localReferences(dynamic value, [String? field]) {
  if (value is String && _artworkFields.contains(field) && _isLocal(value)) {
    return {value};
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        ..._localReferences(entry.value, entry.key as String),
    };
  }
  if (value is List) {
    return {for (final item in value) ..._localReferences(item, field)};
  }
  return {};
}

dynamic _remap(dynamic value, Map<String, String> manifest, [String? field]) {
  if (value is String &&
      _artworkFields.contains(field) &&
      manifest.containsKey(value)) {
    return 'tablet-art:${manifest[value]}';
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key as String: _remap(entry.value, manifest, entry.key as String),
    };
  }
  if (value is List) {
    return value.map((item) => _remap(item, manifest, field)).toList();
  }
  return value;
}
