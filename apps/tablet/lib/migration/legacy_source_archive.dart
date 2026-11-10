import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'legacy_archive_capacity.dart';
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
  static const _budgetedMarker = 'tripling-season-retained-source-budgeted-v1';
  static const _policyFile = 'capacity-policy.json';
  static const _layoutKey = 'capture_layout_v1';
  static final Map<String, Future<void>> _locks = {};
  final Directory directory;
  final LegacyArchiveCapacity? _capacity;
  final bool _requiresCapacity;
  final bool _recoveryOnly;
  LegacySourceArchive._(
    this.directory,
    this._capacity,
    this._requiresCapacity,
    this._recoveryOnly,
  );

  /// Create only a new child, never adopt or modify an existing directory.
  /// A failed creation is retained for review, not automatically removed.
  static Future<LegacySourceArchive> createIn(
    Directory parent, {
    LegacyArchiveCapacity? capacity,
  }) async {
    _requireRootIsolate();
    await _requireRealDirectory(parent);
    final marker = capacity == null ? _marker : _budgetedMarker;
    final policy = capacity == null
        ? null
        : canonicalMigrationJson(capacity.toJson());
    await capacity?.checkCreation(
      parent,
      utf8.encode(marker).length +
          (policy == null ? 0 : utf8.encode(policy).length),
    );
    final root = await parent.createTemp('tripling-retained-source-');
    await File('${root.path}/archive.lock').writeAsBytes([], flush: true);
    if (policy != null) {
      await capacity!.checkWrite(root, utf8.encode(policy).length);
      await File(
        '${root.path}/$_policyFile',
      ).writeAsString(policy, flush: true);
    }
    await capacity?.checkWrite(root, utf8.encode(marker).length);
    await File('${root.path}/archive.txt').writeAsString(marker, flush: true);
    await capacity?.checkWrite(root, 0);
    return reopen(root, capacity: capacity);
  }

  /// Dormant native entry point. Uses this app's private Application Support
  /// location, never cache/documents/shared storage or another app's sandbox.
  /// The caller supplies measured budgets and owns source/writer authorization.
  /// No startup path invokes this; no release or live migration is enabled.
  static Future<LegacySourceArchive> createInApplicationSupport({
    required LegacyArchiveCapacity capacity,
  }) async {
    _requireRootIsolate();
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError('Native mobile application support is required.');
    }
    final supplied = await getApplicationSupportDirectory();
    final normalized = _normalizedDirectory(supplied);
    if (!supplied.isAbsolute ||
        await FileSystemEntity.type(normalized.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw StateError(
        'Application support must be a real absolute directory.',
      );
    }
    // The OS may legitimately use ancestor aliases such as iOS /var. Resolve
    // only the trusted platform-provided root, not a caller-supplied source.
    final parent = Directory(await normalized.resolveSymbolicLinks());
    return createIn(parent, capacity: capacity);
  }

  static Future<LegacySourceArchive> reopen(
    Directory directory, {
    Iterable<String> heldCoordinationPaths = const [],
    LegacyArchiveCapacity? capacity,
  }) => _open(
    directory,
    capacity: capacity,
    heldCoordinationPaths: heldCoordinationPaths,
  );

  /// Physical evidence only. A damaged/missing policy must not prevent exporting
  /// surviving bytes, but cannot authorize capture, decoding or promotion.
  /// Recognized archive identity and safe coordination files remain mandatory.
  static Future<LegacySourceArchive> reopenForRecovery(
    Directory directory, {
    Iterable<String> heldCoordinationPaths = const [],
  }) => _open(
    directory,
    recoveryOnly: true,
    heldCoordinationPaths: heldCoordinationPaths,
  );

  static Future<LegacySourceArchive> _open(
    Directory directory, {
    Iterable<String> heldCoordinationPaths = const [],
    LegacyArchiveCapacity? capacity,
    bool recoveryOnly = false,
  }) async {
    _requireRootIsolate();
    await _requireRealDirectory(directory);
    final root = _normalizedDirectory(directory);
    if (!root.uri.pathSegments
        .where((part) => part.isNotEmpty)
        .last
        .startsWith('tripling-retained-source-')) {
      throw StateError('Only a marked retained-source archive can be opened.');
    }
    // A marker read closes a descriptor too. Screen identities before reading
    // markers or opening this store's lease while another store is leased.
    await _rejectCoordinationAlias(
      '${root.path}/archive.lock',
      heldCoordinationPaths,
    );
    await _rejectCoordinationAlias('${root.path}/archive.txt', [
      '${root.path}/archive.lock',
      ...heldCoordinationPaths,
    ]);
    await _requireFile('${root.path}/archive.txt');
    final markerFile = File('${root.path}/archive.txt');
    if (await markerFile.length() > 128) {
      throw StateError('Unknown archive marker was preserved.');
    }
    final marker = await markerFile.readAsString();
    if (marker != _marker && marker != _budgetedMarker) {
      throw StateError('Unknown archive marker was preserved.');
    }
    final budgeted = marker == _budgetedMarker;
    if (budgeted && !recoveryOnly) {
      final policyPath = '${root.path}/$_policyFile';
      await _rejectCoordinationAlias(policyPath, [
        '${root.path}/archive.lock',
        ...heldCoordinationPaths,
      ]);
      await _requireFile(policyPath);
      final file = File(policyPath);
      if (await file.length() > 1024) {
        throw StateError('Invalid archive capacity policy was preserved.');
      }
      final encoded = await file.readAsString();
      final policy = jsonDecode(encoded);
      if (policy is! Map<String, dynamic> ||
          policy['maxArchiveBytes'] is! int ||
          policy['conversionReserveBytes'] is! int ||
          policy['safetyReserveBytes'] is! int) {
        throw StateError('Invalid archive capacity policy was preserved.');
      }
      final declared = LegacyArchiveCapacity(
        availableBytes: (_) async => null,
        maxArchiveBytes: policy['maxArchiveBytes'] as int,
        conversionReserveBytes: policy['conversionReserveBytes'] as int,
        safetyReserveBytes: policy['safetyReserveBytes'] as int,
      );
      if (canonicalMigrationJson(declared.toJson()) != encoded ||
          (capacity != null &&
              canonicalMigrationJson(capacity.toJson()) != encoded)) {
        throw StateError(
          'Archive capacity policy conflicts; evidence was kept.',
        );
      }
    } else if (capacity != null) {
      throw StateError(
        'Existing unbudgeted archives cannot adopt a new policy.',
      );
    }
    await _requireFile('${root.path}/archive.lock');
    return LegacySourceArchive._(root, capacity, budgeted, recoveryOnly);
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
    if (_requiresCapacity && _capacity == null) {
      throw StateError(
        'The retained capacity policy and a fresh probe are required.',
      );
    }
    final storage = _ArchiveRecords(directory, onBoundary, capacity: _capacity);
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
    Iterable<String> heldCoordinationPaths = const [],
  }) => _withLease(() async {
    final storage = _ArchiveRecords(
      directory,
      null,
      heldCoordinationPaths: heldCoordinationPaths,
    );
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
  }, heldCoordinationPaths: heldCoordinationPaths);

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
    heldCoordinationPaths: additionalSources
        .whereType<LegacyRecoveryFiles>()
        .expand((source) => source.coordinationFiles.values),
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
    heldCoordinationPaths: additionalSources
        .whereType<LegacyRecoveryFiles>()
        .expand((source) => source.coordinationFiles.values),
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
    Iterable<String> heldCoordinationPaths = const [],
  }) async {
    _requireRootIsolate();
    if (_recoveryOnly && !allowUnknownFiles) {
      throw StateError(
        'This archive is open for physical recovery export only.',
      );
    }
    final path = directory.path;
    final previous = _locks[path] ?? Future<void>.value();
    final done = Completer<void>();
    _locks[path] = done.future;
    await previous;
    RandomAccessFile? lease;
    try {
      await _open(
        directory,
        heldCoordinationPaths: heldCoordinationPaths,
        capacity: allowUnknownFiles ? null : _capacity,
        recoveryOnly: allowUnknownFiles,
      );
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
              (_requiresCapacity && name == _policyFile) ||
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
  final Iterable<String> heldCoordinationPaths;
  final LegacyArchiveCapacity? capacity;
  _ArchiveRecords(
    this.directory,
    this.onBoundary, {
    this.heldCoordinationPaths = const [],
    this.capacity,
  });

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
    await _rejectCoordinationAlias(file.path, [
      '${directory.path}/archive.lock',
      ...heldCoordinationPaths,
    ]);
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
    await capacity?.checkWrite(directory, encoded.length);
    // Random, exclusive attempt files are never overwritten or cleaned up.
    // A short write/full disk leaves only this attempt, not a corrupt authority.
    final pending = File('${directory.path}/pending_${const Uuid().v4()}.part');
    await pending.create(exclusive: true);
    await onBoundary?.call('archive_before_write:$key');
    await capacity?.checkWrite(directory, encoded.length);
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
    await capacity?.checkWrite(directory, 0);
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

// stat/identity checks never open a descriptor for the compared inode.
Future<void> _rejectCoordinationAlias(
  String path,
  Iterable<String> coordinationPaths,
) async {
  if (await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.file) {
    return;
  }
  for (final coordination in coordinationPaths) {
    if (await FileSystemEntity.type(coordination, followLinks: false) ==
            FileSystemEntityType.file &&
        await FileSystemEntity.identical(path, coordination)) {
      throw StateError(
        'Recovery control or record aliases a coordination file.',
      );
    }
  }
}
