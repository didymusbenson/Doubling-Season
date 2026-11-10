import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
// Private registry prevents any access to the original app's global Hive boxes.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../domain/table_state.dart';
import '../storage/storage_namespace.dart';
import '../storage/table_repository.dart';
import 'legacy_migration.dart';
import 'legacy_migration_journal.dart';
import 'legacy_migration_recovery.dart';
import 'legacy_source_reader.dart';
import 'legacy_source_archive.dart';
import 'legacy_recovery_files.dart';

class LegacyMigrationPromotion {
  final String transactionId;
  final bool alreadyPromoted;
  final TabletState state;
  final List<String> warnings;
  const LegacyMigrationPromotion(
    this.transactionId,
    this.alreadyPromoted,
    this.state,
    this.warnings,
  );
}

/// The migration engine is intentionally reachable only in an isolated native
/// rehearsal directory created by this class. There is no production factory,
/// environment switch, sandbox discovery, startup hook or original Hive writer.
///
/// A complete retained archive is the retry authority. Media is durable before
/// the single aggregate record (including its receipt) is promoted. No reset,
/// source repair, rollback of later gameplay, or automatic cleanup is exposed.
/// This does not certify process/device power-loss durability or provide an
/// exclusive writer lease for a live original installation.
class LegacyMigrationCoordinator {
  static const rawBoxName = 'legacy_rehearsal_raw_v1';
  static const journalBoxName = 'legacy_rehearsal_journal_v1';
  static const controlBoxName = 'legacy_rehearsal_control_v1';
  static const _marker = 'tripling-season-migration-rehearsal-v1';
  static final Map<String, Future<void>> _locks = {};
  final Directory directory;
  LegacyMigrationCoordinator._(this.directory);

  static Future<LegacyMigrationCoordinator> createRehearsal() async {
    final root = await Directory.systemTemp.createTemp(
      'tripling-migration-rehearsal-',
    );
    await File(
      '${root.path}/rehearsal.txt',
    ).writeAsString(_marker, flush: true);
    await File('${root.path}/coordinator.lock').writeAsBytes([], flush: true);
    return LegacyMigrationCoordinator._(
      Directory(await root.resolveSymbolicLinks()),
    );
  }

  /// Reopen only our marked, direct child of the system temporary directory.
  /// Original/live app destinations cannot accidentally be supplied here.
  static Future<LegacyMigrationCoordinator> reopenRehearsal(
    Directory root,
  ) async {
    final canonical = await root.resolveSymbolicLinks();
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    if (root.absolute.path != canonical ||
        Directory(canonical).parent.path != temp ||
        !root.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last
            .startsWith('tripling-migration-rehearsal-') ||
        await FileSystemEntity.type(
              '${root.path}/rehearsal.txt',
              followLinks: false,
            ) !=
            FileSystemEntityType.file ||
        await File('${root.path}/rehearsal.txt').readAsString() != _marker) {
      throw StateError('Only an isolated migration rehearsal can be reopened.');
    }
    return LegacyMigrationCoordinator._(Directory(canonical));
  }

  /// The source must be a caller-owned OFFLINE copy. Its explicit evidence is
  /// retained; repeated hashes detect change but cannot establish quiescence.
  /// Once the complete archive exists, retries do not read the source directory.
  Future<LegacyMigrationPromotion> rehearse({
    Directory? sourceDirectory,
    LegacySourceArchive? sourceArchive,
    required LegacySourceLayout layout,
    Future<void> Function(String boundary)? onBoundary,
    String? expectedTransactionId,
  }) async {
    if (sourceDirectory != null && sourceArchive != null) {
      throw ArgumentError(
        'Choose an offline copy or a retained archive, not both.',
      );
    }
    return _withLease(
      sourceDirectory ?? sourceArchive?.directory,
      () => _rehearseLocked(
        sourceDirectory: sourceDirectory,
        sourceArchive: sourceArchive,
        layout: layout,
        onBoundary: onBoundary,
        expectedTransactionId: expectedTransactionId,
      ),
    );
  }

  Future<LegacyMigrationPromotion> _rehearseLocked({
    Directory? sourceDirectory,
    LegacySourceArchive? sourceArchive,
    required LegacySourceLayout layout,
    Future<void> Function(String boundary)? onBoundary,
    String? expectedTransactionId,
  }) async {
    final hive = HiveImpl();
    try {
      final path = directory.path;
      hive.init(path);
      Future<Box<T>> open<T>(String name) async {
        // Hive 2.2.3 also completes an internal opening future with each error.
        // A concurrent observer drains that future, preventing an unhandled
        // duplicate error from crashing the recovery screen. Both opens share
        // one backend and both failures are awaited; neither enables recovery.
        Future<Box<T>> request() => hive.openBox<T>(
          name,
          crashRecovery: false,
          compactionStrategy: (_, _) => false,
        );
        return (await Future.wait([request(), request()])).first;
      }

      Future<Box<String>> strings(String name) => open<String>(name);
      final rawBox = await strings(rawBoxName);
      final journalBox = await strings(journalBoxName);
      final hash = RegExp(r'^[a-f0-9]{64}$');
      if (rawBox.keys.any(
            (key) =>
                key is! String ||
                (key != LegacySourceReader.inventoryKey &&
                    key != LegacySourceReader.captureIntentKey &&
                    !(key.startsWith('raw_file_') &&
                        hash.hasMatch(key.substring(9)))),
          ) ||
          journalBox.keys.any(
            (key) =>
                key is! String ||
                (!{'source', 'candidate', 'current'}.contains(key) &&
                    !(key.startsWith('media_') &&
                        hash.hasMatch(key.substring(6)))),
          )) {
        throw StateError('Unsupported retained records require review.');
      }
      final raw = _Storage(rawBox);
      final journal = LegacyMigrationJournal(_Storage(journalBox));
      final control = await strings(controlBoxName);
      if (control.keys.any((key) => key != 'intent')) {
        throw StateError('Unsupported coordinator records require review.');
      }
      final aggregate = await strings(TableStorageKeys.aggregate);
      final previousBox = await strings(
        '${TableStorageKeys.aggregate}_previous',
      );
      final recovery = await strings('${TableStorageKeys.aggregate}_recovery');
      final media = await open<dynamic>(TableStorageKeys.media);

      // Never allow the normal fresh-install initializer to run first. Even an
      // empty initial table or an unknown recovery record is a conflicting store.
      if (control.get('intent') == null &&
          [aggregate, previousBox, recovery].any((box) => box.isNotEmpty)) {
        throw StateError(
          'An existing table must not be replaced by migration.',
        );
      }
      final reader = LegacySourceReader();
      var source = sourceArchive == null
          ? await reader.openRetained(layout: layout, recoveryStorage: raw)
          : await sourceArchive.copyRetainedTo(
              layout: layout,
              recoveryStorage: raw,
              onBoundary: onBoundary,
            );
      if (source == null) {
        if (sourceDirectory == null) {
          throw StateError(
            'The incomplete capture requires its original offline copy.',
          );
        }
        source = await reader.acquireCopiedDirectory(
          directory: sourceDirectory,
          layout: layout,
          recoveryStorage: raw,
          onBoundary: onBoundary,
        );
      }
      await onBoundary?.call('captured');
      final staged = await source.prepare(journal);
      if (staged.blockers.isNotEmpty) {
        throw StateError(
          'Migration requires review: ${staged.blockers.join(' ')}',
        );
      }
      if (expectedTransactionId != null &&
          staged.transactionId != expectedTransactionId) {
        throw StateError('Source changed since recovery inspection.');
      }
      await onBoundary?.call('staged');
      final committed = await journal.commit(staged.transactionId);
      final state = committed.state;
      final receipt = <String, dynamic>{
        'version': 1,
        'transactionId': committed.transactionId,
        'sourceDigest': source.snapshot.digest,
        'inventoryDigest': source.inventoryDigest,
      };
      state.library['legacyPromotionReceipt'] = receipt;
      final encoded = TableRepository.encodeGeneration(state, sequence: 1);
      TableRepository.decodeGeneration(encoded);
      final intent = canonicalMigrationJson({
        ...receipt,
        'aggregateSha256': sha256.convert(utf8.encode(encoded)).toString(),
      });
      await _retain(control, 'intent', intent);
      await onBoundary?.call('intent');

      // Check any existing authority BEFORE touching production-format media.
      final current = aggregate.get('current');
      TabletState? existing;
      if (current != null) {
        existing = TableRepository.decodeGeneration(current);
        if (canonicalMigrationJson(
              existing.library['legacyPromotionReceipt'],
            ) !=
            canonicalMigrationJson(receipt)) {
          throw StateError('Another table owns the destination.');
        }
      } else if ([
        aggregate,
        previousBox,
        recovery,
      ].any((box) => box.isNotEmpty)) {
        throw StateError(
          'Incomplete or unknown table storage requires recovery.',
        );
      }
      // A recovery authority could contain later gameplay. Never overwrite or
      // choose between authorities here; the regular recovery flow owns that.
      if (recovery.isNotEmpty ||
          aggregate.keys.any((key) => key != 'current')) {
        throw StateError('Existing recovery records require separate review.');
      }
      if (previousBox.isNotEmpty) {
        if (previousBox.keys.any((key) => key != 'current')) {
          throw StateError('Unknown previous records require review.');
        }
        final previousEncoded = previousBox.get('current')!;
        final before = TableRepository.decodeGeneration(previousEncoded);
        final previousSequence =
            jsonMap(jsonDecode(previousEncoded))['sequence'] as int? ?? 0;
        final currentSequence =
            jsonMap(jsonDecode(current!))['sequence'] as int? ?? 0;
        if (previousSequence > currentSequence ||
            (previousSequence == currentSequence &&
                previousEncoded != current)) {
          throw StateError(
            'Conflicting table generations require separate review.',
          );
        }
        if (canonicalMigrationJson(before.library['legacyPromotionReceipt']) !=
            canonicalMigrationJson(receipt)) {
          throw StateError('Previous table belongs to another migration.');
        }
      }
      final copiedMedia = source.localMedia;
      for (final bytes in copiedMedia.values) {
        await _validateImage(bytes);
        final hash = sha256.convert(bytes).toString();
        final old = media.get(hash);
        if (old != null) {
          _verifyBytes(old, hash);
        } else {
          // If already promoted, missing media indicates damage, not permission
          // to silently repair an authoritative store during a retry.
          if (existing != null) {
            throw StateError(
              'Promoted artwork is missing; recovery is required.',
            );
          }
          await onBoundary?.call('media_before_write:$hash');
          await media.put(hash, bytes);
          await onBoundary?.call('media_written:$hash');
        }
        await media.flush();
        _verifyBytes(media.get(hash), hash);
        await onBoundary?.call('media:$hash');
      }
      // Every local artwork field, including preset/library metadata, must have
      // been resolved. Do not activate an otherwise successful missing-file map.
      _verifyReferences((existing ?? state).toJson(), media);
      await onBoundary?.call('validated');
      if (existing != null) {
        await aggregate.flush();
        return LegacyMigrationPromotion(
          committed.transactionId,
          true,
          existing,
          List.unmodifiable(staged.warnings),
        );
      }
      // Last fail-closed check immediately precedes the only authority write.
      if ([aggregate, previousBox, recovery].any((box) => box.isNotEmpty)) {
        throw StateError('The destination changed before promotion.');
      }
      await onBoundary?.call('promotion_before_write');
      await aggregate.put('current', encoded);
      await onBoundary?.call('promotion_written');
      await aggregate.flush();
      await onBoundary?.call('promotion_flushed');
      if (aggregate.get('current') != encoded) {
        throw StateError('Promotion readback failed.');
      }
      return LegacyMigrationPromotion(
        committed.transactionId,
        false,
        TableRepository.decodeGeneration(aggregate.get('current')!),
        List.unmodifiable(staged.warnings),
      );
    } finally {
      await hive.close();
    }
  }

  /// Inspection replays an exact, stable physical snapshot in a disposable
  /// rehearsal. It never opens retained Hive files or promotes their authority.
  /// A successful new promotion in the clone means ready, not completed.
  Future<LegacyMigrationPromotion> inspectRehearsal({
    Directory? sourceDirectory,
    LegacySourceArchive? sourceArchive,
    required LegacySourceLayout layout,
  }) async {
    if (sourceDirectory != null && sourceArchive != null) {
      throw ArgumentError(
        'Choose an offline copy or a retained archive, not both.',
      );
    }
    return _withLease(sourceDirectory ?? sourceArchive?.directory, () async {
      final files = _RehearsalFiles(directory);
      final keys = await files.keys();
      final records = <String, String>{};
      for (final key in keys) {
        records[key] = (await files.read(key))!;
      }
      if (!await files.matches(records)) {
        throw const FormatException(
          'Rehearsal files changed during inspection.',
        );
      }
      final clone = await createRehearsal();
      try {
        for (final entry in records.entries) {
          final record = jsonDecode(entry.value) as Map;
          if (record['kind'] != 'file' || entry.key.contains('/')) {
            throw StateError('Unexpected rehearsal entries require review.');
          }
          await File(
            '${clone.directory.path}/${entry.key}',
          ).writeAsBytes(base64Decode(record['bytes'] as String), flush: true);
        }
        return await clone.rehearse(
          sourceDirectory: sourceDirectory,
          sourceArchive: sourceArchive,
          layout: layout,
        );
      } finally {
        // Only this new disposable clone is removed, never retained/user data.
        await clone.directory.delete(recursive: true);
      }
    }, allowUnknownFiles: true);
  }

  /// Physical bytes preserve unknown/corrupt Hive records and all media without
  /// opening a box. This is not an original-installation backup or restore API.
  Future<LegacyRecoveryBackup> createRecoveryBackup({
    LegacySourceArchive? sourceArchive,
  }) => _withLease(
    sourceArchive?.directory,
    () => sourceArchive == null
        ? LegacyRecoveryBackup.capture([_RehearsalFiles(directory)])
        : sourceArchive.createRecoveryBackup(
            additionalSources: [_RehearsalFiles(directory)],
          ),
    allowUnknownFiles: true,
  );

  Future<T> _withLease<T>(
    Directory? sourceDirectory,
    Future<T> Function() operation, {
    bool allowUnknownFiles = false,
  }) async {
    // POSIX file locks are process-wide, not isolate-wide. Restrict Hive
    // writers to Flutter's root isolate; this map then covers every in-process
    // coordinator, and the file lock covers separate processes.
    if (ui.RootIsolateToken.instance == null) {
      throw StateError('Migration rehearsals must run on the root isolate.');
    }
    final path = await directory.resolveSymbolicLinks();
    final previous = _locks[path] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[path] = done.future;
    await previous;
    RandomAccessFile? lease;
    try {
      await reopenRehearsal(directory);
      // Reject links and foreign entries before Hive can follow any file path.
      const boxes = [
        rawBoxName,
        journalBoxName,
        controlBoxName,
        TableStorageKeys.aggregate,
        '${TableStorageKeys.aggregate}_previous',
        '${TableStorageKeys.aggregate}_recovery',
        TableStorageKeys.media,
      ];
      await for (final entity in directory.list(followLinks: false)) {
        final name = entity.uri.pathSegments.last;
        final allowed =
            name == 'rehearsal.txt' ||
            name == 'coordinator.lock' ||
            boxes.any((box) => name == '$box.hive' || name == '$box.lock');
        if ((!allowUnknownFiles && !allowed) ||
            (!allowUnknownFiles &&
                await FileSystemEntity.type(entity.path, followLinks: false) !=
                    FileSystemEntityType.file)) {
          throw StateError(
            'Unexpected rehearsal files were preserved without opening storage.',
          );
        }
      }
      if (sourceDirectory != null) {
        void requireSeparate(String source) {
          if (path == source ||
              path.startsWith('$source${Platform.pathSeparator}') ||
              source.startsWith('$path${Platform.pathSeparator}')) {
            throw StateError(
              'Source and destination must be separate directories.',
            );
          }
        }

        requireSeparate(
          Directory.fromUri(sourceDirectory.absolute.uri.normalizePath()).path,
        );
        // A missing old copy must not prevent a retained-archive retry. Existing
        // aliases are still checked before any destination file is opened.
        if (await sourceDirectory.exists()) {
          requireSeparate(await sourceDirectory.resolveSymbolicLinks());
        }
      }
      // A separate inode is essential: closing ANY descriptor for a locked
      // file can release POSIX process-wide locks. Never read this lease file
      // while capturing evidence. Older rehearsals may acquire this empty
      // coordination file here; retained record files are never changed.
      final leaseType = await FileSystemEntity.type(
        '$path/coordinator.lock',
        followLinks: false,
      );
      if (leaseType != FileSystemEntityType.notFound &&
          leaseType != FileSystemEntityType.file) {
        throw StateError('The rehearsal lease must not follow a link.');
      }
      lease = await File('$path/coordinator.lock').open(mode: FileMode.append);
      await lease.lock(FileLock.exclusive);
      return await operation();
    } finally {
      try {
        await lease?.close();
      } finally {
        done.complete();
        if (identical(_locks[path], done.future)) _locks.remove(path);
      }
    }
  }
}

class _Storage extends LegacyMigrationStorage {
  final Box<String> box;
  _Storage(this.box);
  @override
  Object get lockIdentity => box;
  @override
  Future<String?> read(String key) async => box.get(key);
  @override
  Future<void> write(String key, String value) => box.put(key, value);
  @override
  Future<void> flush() => box.flush();
}

Future<void> _retain(Box<String> box, String key, String value) async {
  final prior = box.get(key);
  if (prior != null && prior != value) {
    throw StateError('Conflicting migration intent was preserved.');
  }
  if (prior == null) await box.put(key, value);
  await box.flush();
  if (box.get(key) != value) {
    throw StateError('Migration intent readback failed.');
  }
}

void _verifyBytes(dynamic value, String hash) {
  if (value is! List<int> || sha256.convert(value).toString() != hash) {
    throw const FormatException('Artwork integrity validation failed.');
  }
}

Future<void> _validateImage(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
    throw const FormatException('Invalid artwork size.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width < 1 ||
        descriptor.height < 1 ||
        descriptor.width > 8192 ||
        descriptor.height > 8192 ||
        descriptor.width * descriptor.height > 16 * 1024 * 1024) {
      throw const FormatException(
        'Artwork dimensions exceed migration limits.',
      );
    }
    codec = await descriptor.instantiateCodec();
    if (codec.frameCount != 1) {
      throw const FormatException('Animated artwork requires review.');
    }
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
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
void _verifyReferences(dynamic value, Box<dynamic> media, [String? field]) {
  if (value is String && _artworkFields.contains(field)) {
    if (value.startsWith('/') || value.startsWith('file://')) {
      throw const FormatException(
        'Unresolved local artwork requires recovery.',
      );
    }
    if (value.startsWith('tablet-art:')) {
      final hash = value.substring('tablet-art:'.length);
      _verifyBytes(media.get(hash), hash);
    }
  } else if (value is Map) {
    for (final entry in value.entries) {
      _verifyReferences(entry.value, media, entry.key as String);
    }
  } else if (value is List) {
    for (final entry in value) {
      _verifyReferences(entry, media, field);
    }
  }
}

/// Exact filesystem records, including entries the coordinator cannot interpret.
/// Lock files are process coordination, not retained content. No symlink is read
/// as a file; its literal target is retained without opening the target.
class _RehearsalFiles extends LegacyRecoveryFiles {
  _RehearsalFiles(super.directory)
    : super(
        name: 'rehearsal_files_base64_v1',
        excludedTopLevelLockFiles: {
          'coordinator.lock',
          for (final box in [
            LegacyMigrationCoordinator.rawBoxName,
            LegacyMigrationCoordinator.journalBoxName,
            LegacyMigrationCoordinator.controlBoxName,
            TableStorageKeys.aggregate,
            '${TableStorageKeys.aggregate}_previous',
            '${TableStorageKeys.aggregate}_recovery',
            TableStorageKeys.media,
          ])
            '$box.lock',
        },
      );
}
