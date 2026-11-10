import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'legacy_migration.dart';
import 'legacy_migration_journal.dart';
import 'legacy_source_reader.dart';
import 'legacy_recovery_files.dart';
import 'legacy_recovery_export.dart';
import 'legacy_migration_recovery.dart';

/// Retains an offline installation copy in a caller-selected recovery location.
///
/// The caller must choose durable, private app-owned storage with sufficient
/// capacity. This class does not discover production storage, grant access to
/// another sandbox, delete evidence, or activate migration. It never chooses
/// system temporary storage: tests may explicitly supply a temporary parent.
/// A separate file per immutable record keeps a torn write from damaging any
/// previously retained record. Pending files are evidence, never authority.
/// File flush/readback is required; directory fsync and device power-loss
/// guarantees are not provided by Dart's portable filesystem API.
class LegacySourceArchive {
  static const _marker = 'tripling-season-retained-source-v1';
  static const _layoutKey = 'capture_layout_v1';
  static final Map<String, Future<void>> _locks = {};
  final Directory directory;
  LegacySourceArchive._(this.directory);

  /// Create only a new child, never adopt or modify an existing directory.
  /// A failed creation is retained for review, not automatically removed.
  static Future<LegacySourceArchive> createIn(Directory parent) async {
    _requireRootIsolate();
    await _requireRealDirectory(parent);
    final root = await parent.createTemp('tripling-retained-source-');
    await File('${root.path}/archive.lock').writeAsBytes([], flush: true);
    await File('${root.path}/archive.txt').writeAsString(_marker, flush: true);
    return reopen(root);
  }

  static Future<LegacySourceArchive> reopen(Directory directory) async {
    _requireRootIsolate();
    await _requireRealDirectory(directory);
    final root = _normalizedDirectory(directory);
    if (!root.uri.pathSegments
        .where((part) => part.isNotEmpty)
        .last
        .startsWith('tripling-retained-source-')) {
      throw StateError('Only a marked retained-source archive can be opened.');
    }
    await _requireFile('${root.path}/archive.txt');
    if (await File('${root.path}/archive.txt').length() != _marker.length ||
        await File('${root.path}/archive.txt').readAsString() != _marker) {
      throw StateError('Unknown archive marker was preserved.');
    }
    await _requireFile('${root.path}/archive.lock');
    return LegacySourceArchive._(root);
  }

  /// Each archive belongs to exactly one declared source layout. A completed
  /// capture always resumes from its retained bytes, even if the source moved
  /// or disappeared. An incomplete capture requires the same offline copy.
  Future<LegacyAcquiredSource> captureCopiedDirectory({
    required Directory source,
    required LegacySourceLayout layout,
    Future<void> Function(String boundary)? onBoundary,
  }) => _withLease(() async {
    await _requireSeparate(source);
    final storage = _ArchiveRecords(directory, onBoundary);
    await storage.write(_layoutKey, canonicalMigrationJson(layout.toJson()));
    final reader = LegacySourceReader();
    final retained = await reader.openRetained(
      layout: layout,
      recoveryStorage: storage,
    );
    if (retained != null) return retained;
    return reader.acquireCopiedDirectory(
      directory: source,
      layout: layout,
      recoveryStorage: storage,
      retainInventoryIntent: true,
      onBoundary: onBoundary,
    );
  });

  Future<LegacyAcquiredSource?> openRetained({
    required LegacySourceLayout layout,
  }) => _withLease(() async {
    final storage = _ArchiveRecords(directory, null);
    final existing = await storage.read(_layoutKey);
    if (existing == null) return null;
    if (existing != canonicalMigrationJson(layout.toJson())) {
      throw const FormatException('The retained source layout conflicts.');
    }
    return LegacySourceReader().openRetained(
      layout: layout,
      recoveryStorage: storage,
    );
  });

  /// Copy complete, verified records while holding the archive's writer lease.
  /// The destination is caller-owned rehearsal storage, never selected here.
  Future<LegacyAcquiredSource> copyRetainedTo({
    required LegacySourceLayout layout,
    required LegacyMigrationStorage recoveryStorage,
    Future<void> Function(String boundary)? onBoundary,
  }) => _withLease(() async {
    final storage = _ArchiveRecords(directory, null);
    if (await storage.read(_layoutKey) !=
        canonicalMigrationJson(layout.toJson())) {
      throw const FormatException('The retained source layout conflicts.');
    }
    final source = await LegacySourceReader().openRetained(
      layout: layout,
      recoveryStorage: storage,
    );
    if (source == null) {
      throw StateError(
        'Complete the retained source capture before rehearsal.',
      );
    }
    return source.copyRetainedTo(recoveryStorage, onBoundary: onBoundary);
  });

  /// Exact physical archive evidence, including incomplete, corrupt and unknown
  /// files, without decoding or repair. The caller leases any additional stores
  /// first. Only the coordination inode is excluded from the retained archive.
  Future<LegacyRecoveryBackup> createRecoveryBackup({
    List<LegacyRecoveryRecordSource> additionalSources = const [],
  }) => _withLease(
    () => LegacyRecoveryBackup.capture(
      LegacyRecoveryFiles.shareCoordination([
        ...additionalSources,
        LegacyRecoveryFiles(
          directory,
          name: 'retained_source_files_base64_v1',
          excludedTopLevelLockFiles: const {'archive.lock'},
        ),
      ]),
    ),
    allowUnknownFiles: true,
  );

  /// Bounded file-backed export under the same whole-archive writer lease.
  Future<LegacyRecoveryExport> exportRecoveryBackup({
    required LegacyRecoveryExportOptions options,
    List<LegacyRecoveryFiles> additionalSources = const [],
  }) => _withLease(
    () => LegacyRecoveryExport.write(
      options: options,
      sources: [
        ...additionalSources,
        LegacyRecoveryFiles(
          directory,
          name: 'retained_source_files_base64_v1',
          excludedTopLevelLockFiles: const {'archive.lock'},
        ),
      ],
    ),
    allowUnknownFiles: true,
  );

  Future<void> _requireSeparate(Directory source) async {
    void check(String path) {
      final destination = directory.path;
      bool contains(String parent, String child) =>
          child == parent ||
          child.startsWith(
            parent.endsWith(Platform.pathSeparator)
                ? parent
                : '$parent${Platform.pathSeparator}',
          );
      if (contains(path, destination) || contains(destination, path)) {
        throw StateError('Source and recovery archive must be separate.');
      }
    }

    check(_normalizedDirectory(source).path);
    if (await source.exists()) check(await source.resolveSymbolicLinks());
  }

  Future<T> _withLease<T>(
    Future<T> Function() operation, {
    bool allowUnknownFiles = false,
  }) async {
    _requireRootIsolate();
    final path = directory.path;
    final previous = _locks[path] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[path] = done.future;
    await previous;
    RandomAccessFile? lease;
    try {
      await reopen(directory);
      // This inode is exclusively for the process lock. Do not read/close
      // another descriptor for it while locked: POSIX locks are process-wide.
      lease = await File('$path/archive.lock').open(mode: FileMode.append);
      await lease.lock(FileLock.exclusive);
      if (!allowUnknownFiles) await _validateEntries();
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

  Future<void> _validateEntries() async {
    await for (final entry in directory.list(followLinks: false)) {
      final name = entry.uri.pathSegments.last;
      if (await FileSystemEntity.type(entry.path, followLinks: false) !=
              FileSystemEntityType.file ||
          !(name == 'archive.txt' ||
              name == 'archive.lock' ||
              _pendingName.hasMatch(name) ||
              (name.endsWith('.record') &&
                  _validKey(name.substring(0, name.length - 7))))) {
        throw StateError('Unexpected archive entries were preserved.');
      }
    }
  }
}

final _pendingName = RegExp(r'^pending_[a-f0-9-]{36}\.part$');
bool _validKey(String key) =>
    key == LegacySourceArchive._layoutKey ||
    key == LegacySourceReader.inventoryKey ||
    key == LegacySourceReader.captureIntentKey ||
    RegExp(r'^raw_file_[a-f0-9]{64}$').hasMatch(key);

/// Only handed to the existing raw acquisition reader. It cannot be used as a
/// mutable journal, and no public writer bypasses the archive's whole-capture
/// lease. The reader's later prepare step can recheck immutable records safely.
class _ArchiveRecords extends LegacyMigrationStorage {
  // Base64 raw data plus JSON escaping/envelope; bound reads before allocation.
  static const _maxRecordBytes = 192 * 1024 * 1024;
  final Directory directory;
  final Future<void> Function(String boundary)? onBoundary;
  _ArchiveRecords(this.directory, this.onBoundary);

  @override
  Object get lockIdentity => directory.path;

  File _file(String key) {
    if (!_validKey(key)) throw const FormatException('Invalid archive key.');
    return File('${directory.path}/$key.record');
  }

  @override
  Future<String?> read(String key) async {
    await _requireRealDirectory(directory);
    final file = _file(key);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file ||
        await file.length() > _maxRecordBytes) {
      throw const FormatException('Invalid retained record file.');
    }
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, _maxRecordBytes + 1)) {
      buffer.add(chunk);
    }
    final bytes = buffer.takeBytes();
    if (bytes.length > _maxRecordBytes) {
      throw const FormatException('Retained record exceeds its bound.');
    }
    final record = jsonDecode(utf8.decode(bytes));
    if (record is! Map<String, dynamic> ||
        record.length != 5 ||
        record['version'] != 1 ||
        record['key'] != key ||
        record['value'] is! String) {
      throw const FormatException('Invalid retained record envelope.');
    }
    final value = record['value'] as String;
    final payload = utf8.encode(value);
    if (record['length'] != payload.length ||
        record['sha256'] != sha256.convert(payload).toString()) {
      throw const FormatException('Retained record failed integrity checks.');
    }
    if (key == LegacySourceReader.inventoryKey &&
        await read(LegacySourceReader.captureIntentKey) != value) {
      throw const FormatException(
        'Retained inventory conflicts with its intent.',
      );
    }
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    final target = _file(key);
    final existing = await read(key);
    if (existing != null) {
      if (existing != value) {
        throw const FormatException('Conflicting retained record preserved.');
      }
      return;
    }
    final bytes = utf8.encode(value);
    final encoded = utf8.encode(
      jsonEncode({
        'version': 1,
        'key': key,
        'length': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
        'value': value,
      }),
    );
    if (encoded.length > _maxRecordBytes) {
      throw const FormatException('Retained record exceeds its bound.');
    }
    // Random, exclusive attempt files are never overwritten or cleaned up.
    // A short write/full disk leaves only this attempt, not a corrupt authority.
    final pending = File('${directory.path}/pending_${const Uuid().v4()}.part');
    await pending.create(exclusive: true);
    await onBoundary?.call('archive_before_write:$key');
    final handle = await pending.open(mode: FileMode.writeOnly);
    try {
      await handle.writeFrom(encoded);
      await onBoundary?.call('archive_written:$key');
      await handle.flush();
      await onBoundary?.call('archive_flushed:$key');
    } finally {
      await handle.close();
    }
    if (await pending.length() != encoded.length ||
        sha256.convert(await pending.readAsBytes()).toString() !=
            sha256.convert(encoded).toString()) {
      throw const FormatException('Pending archive record readback failed.');
    }
    await onBoundary?.call('archive_verified:$key');
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Archive changed before record publication.');
    }
    await pending.rename(target.path);
    await onBoundary?.call('archive_published:$key');
    if (await read(key) != value) {
      throw const FormatException('Published archive record readback failed.');
    }
  }

  // Every write flushes/closes its descriptor before publication. There is no
  // cached handle or in-memory-only value for flush() to acknowledge.
  @override
  Future<void> flush() async {}
}

void _requireRootIsolate() {
  if (ui.RootIsolateToken.instance == null) {
    throw StateError('Source archives must be used on the root isolate.');
  }
}

Future<void> _requireFile(String path) async {
  if (await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw StateError('Archive files must not follow links.');
  }
}

Future<void> _requireRealDirectory(Directory directory) async {
  var current = _normalizedDirectory(directory);
  while (true) {
    if (await FileSystemEntity.type(current.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('Archive paths must contain only real directories.');
    }
    final parent = current.parent;
    if (parent.path == current.path) return;
    current = parent;
  }
}

Directory _normalizedDirectory(Directory directory) {
  var path = Directory.fromUri(directory.absolute.uri.normalizePath()).path;
  // A trailing separator makes native lstat follow a directory symlink even
  // when followLinks is false. Preserve only filesystem root separators.
  while (path.endsWith(Platform.pathSeparator) &&
      path != Platform.pathSeparator &&
      !RegExp(r'^[A-Za-z]:[\\/]$').hasMatch(path)) {
    path = path.substring(0, path.length - 1);
  }
  return Directory(path);
}
