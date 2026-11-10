import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:doubling_season/models/deck.dart';
import 'package:doubling_season/models/item.dart';
import 'package:doubling_season/models/rule_outcome.dart';
import 'package:doubling_season/models/rule_trigger.dart';
import 'package:doubling_season/models/token_artwork_preference.dart';
import 'package:doubling_season/models/token_counter.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/models/token_rule.dart';
import 'package:doubling_season/models/token_template.dart';
import 'package:doubling_season/models/toggle_widget.dart';
import 'package:doubling_season/models/toggle_widget_template.dart';
import 'package:doubling_season/models/tracker_widget.dart';
import 'package:doubling_season/models/tracker_widget_template.dart';
import 'package:hive/hive.dart';
// Hive 2.2.3 has no public, isolated read-only frame decoder. Keep these two
// internal uses scoped here and covered by real serialized adapter fixtures.
// ignore: implementation_imports
import 'package:hive/src/binary/binary_reader_impl.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import 'legacy_migration.dart';
import 'legacy_migration_journal.dart';
import 'legacy_preferences_decode.dart';
import 'legacy_snapshot_capture.dart';

/// Explicit paths inside a caller-owned, already quiescent installation copy.
/// No platform sandbox discovery, live-source capture or startup cutover occurs.
class LegacySourceLayout {
  final String sourceId;
  final String sourceVersion;
  final String copyEvidence;
  final DateTime capturedAt;

  /// All seven keys are mandatory. null means explicitly absent in this source,
  /// not "failed to read". A specified missing file is always an error.
  final Map<String, String?> boxes;
  final String preferencesPath;
  final LegacyPreferencesFormat preferencesFormat;

  /// Exact old reference -> path inside the copy. Never follow old file URLs.
  final Map<String, String> mediaPaths;

  LegacySourceLayout({
    required this.sourceId,
    required this.sourceVersion,
    required this.copyEvidence,
    required this.capturedAt,
    required Map<String, String?> boxes,
    required this.preferencesPath,
    required this.preferencesFormat,
    Map<String, String> mediaPaths = const {},
  }) : boxes = Map.unmodifiable(boxes),
       mediaPaths = Map.unmodifiable(mediaPaths) {
    if ([sourceId, sourceVersion, copyEvidence].any((s) => s.trim().isEmpty) ||
        boxes.length != LegacyMigrationSnapshot.collections.length ||
        !LegacyMigrationSnapshot.collections.every(boxes.containsKey)) {
      throw const FormatException(
        'Complete source and copy evidence required.',
      );
    }
    final declared = boxes.values.whereType<String>().toList();
    if (declared.toSet().length != declared.length ||
        declared.contains(preferencesPath)) {
      throw const FormatException('Source files cannot serve multiple stores.');
    }
    for (final path in [...declared, preferencesPath, ...mediaPaths.values]) {
      _validateRelative(path);
    }
    for (final reference in mediaPaths.keys) {
      if (!reference.startsWith('/') && !reference.startsWith('file://')) {
        throw const FormatException(
          'Media must have an original local reference.',
        );
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'sourceVersion': sourceVersion,
    'copyEvidence': copyEvidence,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'boxes': boxes,
    'preferencesPath': preferencesPath,
    'preferencesFormat': preferencesFormat.name,
    'mediaPaths': mediaPaths,
    'adapterSchema': 'root-0273043-types-0-12',
  };
}

/// Decoded only after exact raw files and inventory have been durably retained.
/// Keep the supplied recovery store alongside the journal for recovery. Neither
/// store is the production TableRepository or the original Hive installation.
class LegacyAcquiredSource {
  final LegacyMigrationSnapshot snapshot;
  final Map<String, Uint8List> _media;
  final String inventoryDigest;
  final LegacyMigrationStorage _recovery;
  final Map<String, dynamic> _inventory;
  LegacyAcquiredSource._(
    this.snapshot,
    this._media,
    this.inventoryDigest,
    this._recovery,
    this._inventory,
  );

  Map<String, Uint8List> get localMedia => {
    for (final e in _media.entries) e.key: Uint8List.fromList(e.value),
  };

  /// Recheck retained originals immediately before letting the journal stage.
  Future<LegacyMigrationResult> prepare(LegacyMigrationJournal journal) async {
    await _verifyRetained(_recovery, _inventory);
    return journal.prepare(snapshot, localMedia: localMedia);
  }
}

/// Native copied-file acquisition only. Every file, including backups, unknown
/// files and unreferenced artwork, is retained verbatim before any decode.
/// Hash equality across two reads catches concurrent changes but cannot prove a
/// live multi-store transaction: [LegacySourceLayout.copyEvidence] must describe
/// how the caller obtained a quiescent copy. No source handles are ever opened
/// through Hive, so recovery, compaction, locks and source writes cannot happen.
class LegacySourceReader {
  static const maxFileBytes = 64 * 1024 * 1024;
  static const maxTotalBytes = 256 * 1024 * 1024;
  static const maxFiles = 4096;
  static const inventoryKey = 'raw_source_inventory_v1';

  static final Map<Object, Future<void>> _locks = {};

  Future<LegacyAcquiredSource> acquireCopiedDirectory({
    required Directory directory,
    required LegacySourceLayout layout,
    required LegacyMigrationStorage recoveryStorage,
    Future<void> Function(String boundary)? onBoundary,
  }) async {
    final identity = recoveryStorage.lockIdentity;
    final previous = _locks[identity] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[identity] = done.future;
    await previous;
    try {
      return await _acquire(
        directory: directory,
        layout: layout,
        recoveryStorage: recoveryStorage,
        onBoundary: onBoundary,
      );
    } finally {
      done.complete();
      if (identical(_locks[identity], done.future)) _locks.remove(identity);
    }
  }

  Future<LegacyAcquiredSource> _acquire({
    required Directory directory,
    required LegacySourceLayout layout,
    required LegacyMigrationStorage recoveryStorage,
    Future<void> Function(String boundary)? onBoundary,
  }) async {
    final files = await _readDirectory(directory);
    await onBoundary?.call('copied');
    final second = await _readDirectory(directory);
    final manifest = _manifest(files);
    if (canonicalMigrationJson(manifest) !=
        canonicalMigrationJson(_manifest(second))) {
      throw const FormatException('Source copy changed during acquisition.');
    }
    final inventory = <String, dynamic>{
      'version': 1,
      'layout': layout.toJson(),
      'files': manifest,
    };
    // Retain before inspecting the schema, preferences or checksums. Even a
    // corrupt/unknown source remains available without destructive recovery.
    for (final entry in files.entries) {
      final hash = (manifest[entry.key] as Map)['sha256'] as String;
      await _retain(recoveryStorage, 'raw_file_$hash', {
        'sha256': hash,
        'bytes': base64Encode(entry.value),
      });
      await onBoundary?.call('retained:${entry.key}');
    }
    await _retain(recoveryStorage, inventoryKey, inventory);
    await _verifyRetained(recoveryStorage, inventory);
    await onBoundary?.call('inventory');

    Uint8List requireFile(String path) {
      final value = files[path];
      if (value == null) {
        throw FormatException('Missing copied source file: $path');
      }
      return value;
    }

    final hiveParents = layout.boxes.values.whereType<String>().map((path) {
      final slash = path.lastIndexOf('/');
      return slash < 0 ? '' : path.substring(0, slash + 1);
    }).toSet();
    final backupPrefixes = hiveParents
        .map((parent) => '${parent}hive_backups/')
        .toSet();
    final orderJournals = {
      for (final parent in hiveParents) '${parent}boardorderoperations.hive',
    };
    for (final path in files.keys) {
      final lower = path.toLowerCase();
      if ((lower.endsWith('.hive') || lower.endsWith('.hivec')) &&
          !layout.boxes.values.contains(path) &&
          !orderJournals.contains(path) &&
          !backupPrefixes.any(path.startsWith)) {
        throw FormatException(
          'Uninventoried Hive store retained but not decoded: $path',
        );
      }
    }
    for (final path in orderJournals.where(files.containsKey)) {
      if (_decodeBox(files[path]!).isNotEmpty) {
        throw FormatException(
          'Pending or unknown board-order recovery retained: $path',
        );
      }
    }
    final boxes = <String, Map<Object, dynamic>>{};
    for (final name in LegacyMigrationSnapshot.collections) {
      final path = layout.boxes[name];
      boxes[name] = path == null ? {} : _decodeBox(requireFile(path));
      await onBoundary?.call('decoded:$name');
    }
    Map<Object, T> typed<T>(String name) => boxes[name]!.cast<Object, T>();
    final json = LegacySnapshotCapture.capture(
      sourceId: layout.sourceId,
      sourceVersion: layout.sourceVersion,
      capturedAt: layout.capturedAt,
      items: typed<Item>('items'),
      decks: typed<Deck>('decks'),
      trackerWidgets: typed<TrackerWidget>('trackerWidgets'),
      toggleWidgets: typed<ToggleWidget>('toggleWidgets'),
      artworkPreferences: typed<TokenArtworkPreference>('artworkPreferences'),
      customTokens: typed<String>('customTokens'),
      tokenRules: typed<TokenRule>('tokenRules'),
      preferences: decodeLegacyPreferences(
        requireFile(layout.preferencesPath),
        layout.preferencesFormat,
      ),
    );
    final digest = migrationDigest(inventory);
    json['acquisition'] = {
      'version': 1,
      'inventoryDigest': digest,
      'inventory': inventory,
    };
    final media = <String, Uint8List>{};
    for (final entry in layout.mediaPaths.entries) {
      final bytes = files[entry.value];
      // Missing media is not fabricated. Existing journal reports missing refs.
      if (bytes != null) media[entry.key] = Uint8List.fromList(bytes);
    }
    await onBoundary?.call('decoded');
    return LegacyAcquiredSource._(
      LegacyMigrationSnapshot(json),
      media,
      digest,
      recoveryStorage,
      inventory,
    );
  }

  Future<Map<String, Uint8List>> _readDirectory(Directory directory) async {
    directory = Directory.fromUri(directory.absolute.uri.normalizePath());
    final root = directory.path.endsWith(Platform.pathSeparator)
        ? directory.path.substring(0, directory.path.length - 1)
        : directory.path;
    // Reject links at every ancestor too: a lexical path must not hide a jump
    // outside the explicitly supplied copy.
    var ancestor = directory.absolute;
    while (true) {
      if (await FileSystemEntity.type(ancestor.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FormatException(
          'Copied source root must be a real directory.',
        );
      }
      final parent = ancestor.parent;
      if (parent.path == ancestor.path) break;
      ancestor = parent;
    }
    final result = SplayTreeMap<String, Uint8List>();
    var total = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) continue;
      if (type != FileSystemEntityType.file) {
        throw const FormatException(
          'Links and non-files are not supported in source copies.',
        );
      }
      final relative = entity.absolute.path.substring(root.length + 1);
      final path = Platform.isWindows
          ? relative.replaceAll('\\', '/')
          : relative;
      _validateRelative(path);
      if (result.containsKey(path)) {
        throw const FormatException('Duplicate copied source path.');
      }
      final file = File(entity.path);
      final length = await file.length();
      if (length > maxFileBytes ||
          total + length > maxTotalBytes ||
          result.length >= maxFiles) {
        throw const FormatException(
          'Copied source exceeds acquisition limits.',
        );
      }
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in file.openRead(0, length + 1)) {
        buffer.add(chunk);
      }
      final bytes = buffer.takeBytes();
      if (bytes.length != length) {
        throw const FormatException('Copied source changed while reading.');
      }
      total += bytes.length;
      result[path] = Uint8List.fromList(bytes);
    }
    return result;
  }
}

void _validateRelative(String path) {
  if (path.isEmpty ||
      path.contains('\\') ||
      path.contains(':') ||
      path.contains('\u0000') ||
      path.split('/').any((s) => s.isEmpty || s == '.' || s == '..')) {
    throw const FormatException(
      'Source paths must remain inside the copied directory.',
    );
  }
}

Map<String, dynamic> _manifest(Map<String, Uint8List> files) => {
  for (final entry in files.entries)
    entry.key: {
      'sha256': sha256.convert(entry.value).toString(),
      'length': entry.value.length,
    },
};

Future<void> _retain(
  LegacyMigrationStorage storage,
  String key,
  Map<String, dynamic> value,
) async {
  final encoded = canonicalMigrationJson(value);
  final existing = await storage.read(key);
  if (existing != null && existing != encoded) {
    throw const FormatException(
      'Retained source conflicts with this acquisition.',
    );
  }
  if (existing == null) await storage.write(key, encoded);
  await storage.flush();
  if (await storage.read(key) != encoded) {
    throw const FormatException(
      'Retained source failed readback verification.',
    );
  }
}

Future<void> _verifyRetained(
  LegacyMigrationStorage storage,
  Map<String, dynamic> inventory,
) async {
  if (await storage.read(LegacySourceReader.inventoryKey) !=
      canonicalMigrationJson(inventory)) {
    throw const FormatException(
      'Retained source inventory is missing or changed.',
    );
  }
  for (final metadata in (inventory['files'] as Map).values) {
    final hash = metadata['sha256'] as String;
    final encoded = await storage.read('raw_file_$hash');
    if (encoded == null) {
      throw const FormatException('Retained source file is missing.');
    }
    final record = jsonDecode(encoded) as Map;
    final bytes = base64Decode(record['bytes'] as String);
    if (bytes.length != metadata['length'] ||
        record['sha256'] != hash ||
        sha256.convert(bytes).toString() != hash) {
      throw const FormatException(
        'Retained source file failed hash verification.',
      );
    }
  }
}

HiveImpl _registry({required bool audit}) {
  final registry = HiveImpl();
  if (audit) {
    const fieldCounts = [18, 2, 9, 9, 3, 3, 18, 14, 15, 11, 6, 4, 4];
    for (var id = 0; id < fieldCounts.length; id++) {
      registry.registerAdapter<Map<int, dynamic>>(
        _SchemaAuditAdapter(id, fieldCounts[id]),
      );
    }
  } else {
    registry.registerAdapter<Item>(ItemAdapter());
    registry.registerAdapter<TokenCounter>(TokenCounterAdapter());
    registry.registerAdapter<Deck>(DeckAdapter());
    registry.registerAdapter<TokenTemplate>(TokenTemplateAdapter());
    registry.registerAdapter<ArtworkVariant>(ArtworkVariantAdapter());
    registry.registerAdapter<TokenArtworkPreference>(
      TokenArtworkPreferenceAdapter(),
    );
    registry.registerAdapter<TrackerWidget>(TrackerWidgetAdapter());
    registry.registerAdapter<ToggleWidget>(ToggleWidgetAdapter());
    registry.registerAdapter<TrackerWidgetTemplate>(
      TrackerWidgetTemplateAdapter(),
    );
    registry.registerAdapter<ToggleWidgetTemplate>(
      ToggleWidgetTemplateAdapter(),
    );
    registry.registerAdapter<TokenRule>(TokenRuleAdapter());
    registry.registerAdapter<RuleTrigger>(RuleTriggerAdapter());
    registry.registerAdapter<RuleOutcome>(RuleOutcomeAdapter());
  }
  return registry;
}

/// Reject unknown and duplicated field indices before generated adapters can
/// silently discard them. Raw bytes have already been durably retained.
class _SchemaAuditAdapter extends TypeAdapter<Map<int, dynamic>> {
  @override
  final int typeId;
  final int fieldCount;
  _SchemaAuditAdapter(this.typeId, this.fieldCount);
  @override
  Map<int, dynamic> read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < count; i++) {
      final index = reader.readByte();
      if (index >= fieldCount || fields.containsKey(index)) {
        throw const FormatException('Unknown or duplicate legacy Hive field.');
      }
      fields[index] = reader.read();
    }
    // Current constructors synthesize DateTime.now for these missing fields.
    // Do not fabricate a historical timestamp or a nondeterministic snapshot.
    final dateField = {0: 10, 6: 6, 7: 5}[typeId];
    if (dateField != null && fields[dateField] is! DateTime) {
      throw const FormatException(
        'Legacy creation date needs explicit compatibility handling.',
      );
    }
    return fields;
  }

  @override
  void write(BinaryWriter writer, Map<int, dynamic> obj) =>
      throw UnsupportedError('Read only');
}

Map<Object, dynamic> _decodeBox(Uint8List bytes) {
  Map<Object, dynamic> decode(HiveImpl registry) {
    final result = SplayTreeMap<Object, dynamic>((a, b) {
      if (a is int) return b is int ? a.compareTo(b) : -1;
      return b is int ? 1 : (a as String).compareTo(b as String);
    });
    final reader = _BoundedHiveReader(bytes, registry);
    while (reader.availableBytes > 0) {
      final offset = reader.usedBytes;
      final frame = reader.readFrame(frameOffset: offset);
      if (frame == null || reader.usedBytes <= offset) {
        throw const FormatException('Corrupt or truncated legacy Hive frame.');
      }
      if (frame.deleted) {
        result.remove(frame.key);
      } else {
        result[frame.key as Object] = frame.value;
      }
    }
    return result;
  }

  decode(_registry(audit: true));
  return decode(_registry(audit: false));
}

// Old Hive decoders allocate variable-length lists before checking the payload.
// Bound container sizes/depth before allocation and reject cross-box references.
class _BoundedHiveReader extends BinaryReaderImpl {
  _BoundedHiveReader(super.bytes, super.registry);
  int _depth = 0;
  int _length(int? length, int minimumBytes) {
    final count = length ?? readUint32();
    if (count > 100000 || count * minimumBytes > availableBytes) {
      throw const FormatException(
        'Oversized or truncated legacy Hive collection.',
      );
    }
    return count;
  }

  @override
  dynamic read([int? typeId]) {
    if (++_depth > 64) {
      --_depth;
      throw const FormatException('Legacy Hive nesting limit exceeded.');
    }
    try {
      final value = super.read(typeId);
      if (_depth == 1 && availableBytes != 0) {
        throw const FormatException('Trailing bytes in legacy Hive record.');
      }
      return value;
    } finally {
      --_depth;
    }
  }

  @override
  double readDouble() {
    final value = super.readDouble();
    if (!value.isFinite) {
      throw const FormatException('Non-finite legacy Hive number.');
    }
    return value;
  }

  @override
  int readInt() {
    final value = readDouble();
    if (value != value.truncateToDouble() ||
        value < -9223372036854775808.0 ||
        value >= 9223372036854775808.0) {
      throw const FormatException('Invalid legacy Hive integer encoding.');
    }
    return value.toInt();
  }

  @override
  bool readBool() {
    final value = readByte();
    if (value > 1) {
      throw const FormatException('Invalid legacy Hive boolean encoding.');
    }
    return value == 1;
  }

  @override
  List readList([int? length]) => super.readList(_length(length, 1));
  @override
  List<String> readStringList([
    int? length,
    Converter<List<int>, String> decoder = BinaryReader.utf8Decoder,
  ]) => super.readStringList(_length(length, 4), decoder);
  @override
  List<int> readIntList([int? length]) => [
    for (var i = _length(length, 8); i > 0; i--) readInt(),
  ];
  @override
  List<double> readDoubleList([int? length]) => [
    for (var i = _length(length, 8); i > 0; i--) readDouble(),
  ];
  @override
  List<bool> readBoolList([int? length]) => [
    for (var i = _length(length, 1); i > 0; i--) readBool(),
  ];
  @override
  Map readMap([int? length]) {
    final count = _length(length, 2);
    final map = <dynamic, dynamic>{};
    for (var i = 0; i < count; i++) {
      final key = read();
      if (map.containsKey(key)) {
        throw const FormatException('Duplicate legacy Hive map key.');
      }
      map[key] = read();
    }
    return map;
  }

  @override
  // ignore: experimental_member_use
  HiveList readHiveList([int? length]) => throw const FormatException(
    'Cross-box Hive references require compatibility handling.',
  );
}
