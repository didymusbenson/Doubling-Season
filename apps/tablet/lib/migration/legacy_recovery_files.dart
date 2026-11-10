import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'legacy_migration_recovery.dart';

/// Read-only physical evidence for explicitly supplied private recovery stores.
/// Unknown/corrupt files and literal link targets are retained without opening
/// Hive or following links. The caller owns writer exclusion; double reads can
/// detect changes but cannot establish a consistent live-installation snapshot.
class LegacyRecoveryFiles implements LegacyRecoveryRecordSource {
  // Legacy JSON diagnostics are deliberately small. Use the file-backed
  // streaming exporter for complete/large archives, including larger files.
  static const maxFileBytes = 1024 * 1024;
  final Directory directory;
  @override
  final String name;
  final Set<String> excludedTopLevelLockFiles;
  final Map<String, String> sharedCoordinationFiles;

  LegacyRecoveryFiles(
    Directory directory, {
    required this.name,
    Set<String> excludedTopLevelLockFiles = const {},
    Map<String, String> sharedCoordinationFiles = const {},
  }) : directory = _normalizedDirectory(directory),
       sharedCoordinationFiles = Map.unmodifiable(sharedCoordinationFiles),
       excludedTopLevelLockFiles = Set.unmodifiable(excludedTopLevelLockFiles) {
    if (name.isEmpty ||
        excludedTopLevelLockFiles.any(
          (key) =>
              !_validKey(key) || key.contains('/') || !key.endsWith('.lock'),
        )) {
      throw ArgumentError(
        'Provide a source name and exact top-level lock names.',
      );
    }
  }

  Map<String, String> get coordinationFiles => {
    ...sharedCoordinationFiles,
    for (final key in excludedTopLevelLockFiles)
      '$name/$key': '${directory.path}/$key',
  };

  /// Both sources are leased by the caller. Share lock identities so an alias
  /// in one physical store cannot release another store's process-wide lease.
  static List<LegacyRecoveryRecordSource> shareCoordination(
    List<LegacyRecoveryRecordSource> sources,
  ) {
    final locks = <String, String>{
      for (final source in sources.whereType<LegacyRecoveryFiles>())
        ...source.coordinationFiles,
    };
    return [
      for (final source in sources)
        if (source is LegacyRecoveryFiles)
          LegacyRecoveryFiles(
            source.directory,
            name: source.name,
            excludedTopLevelLockFiles: source.excludedTopLevelLockFiles,
            sharedCoordinationFiles: locks,
          )
        else
          source,
    ];
  }

  @override
  Future<List<String>> keys() => boundedKeys();

  /// Bound inventory metadata as well as payload memory.
  Future<List<String>> boundedKeys({
    int maxEntries = 10000,
    int maxKeyBytes = 4 * 1024 * 1024,
  }) async {
    var keyBytes = 0;
    await _requireRealRoot();
    final result = <String>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      var key = entity.path.substring(directory.path.length + 1);
      if (Platform.isWindows) {
        key = key.replaceAll('\\', '/');
      }
      if (!_validKey(key) || utf8.encode(key).length > 4096) {
        throw const FormatException('Invalid recovery path.');
      }
      if (_excluded(key) &&
          await FileSystemEntity.type(entity.path, followLinks: false) ==
              FileSystemEntityType.file) {
        continue;
      }
      keyBytes += utf8.encode(key).length;
      if (result.length >= maxEntries || keyBytes > maxKeyBytes) {
        throw const FormatException(
          'Recovery inventory exceeds its metadata bound.',
        );
      }
      result.add(key);
    }
    return result..sort();
  }

  bool _excluded(String key) =>
      !key.contains('/') && excludedTopLevelLockFiles.contains(key);

  /// Metadata only. Links are evidence, never dereferenced.
  Future<Map<String, Object>?> describe(
    String key, {
    Map<String, String> coordinationFiles = const {},
  }) async {
    final path = await _checkedPath(key);
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type == FileSystemEntityType.link) {
      final target = await Link(path).target();
      if (utf8.encode(target).length > 64 * 1024) {
        throw const FormatException('Recovery link target exceeds its bound.');
      }
      return {'kind': 'link', 'target': target};
    }
    if (type == FileSystemEntityType.directory) return {'kind': 'directory'};
    // Never open an excluded coordination inode. POSIX locks are process-wide.
    if (type == FileSystemEntityType.file && _excluded(key)) return null;
    if (type != FileSystemEntityType.file) {
      throw const FormatException('Unsupported recovery file type.');
    }
    // A foreign/unknown entry can be a hard link to a coordination inode.
    // Opening and closing that alias also releases process-wide POSIX locks.
    // Compare identity without opening a descriptor and retain the relationship
    // as metadata, not a read of the intentionally excluded coordination bytes.
    final locks = {
      for (final lock in excludedTopLevelLockFiles.toList()..sort())
        lock: '${directory.path}/$lock',
      ...sharedCoordinationFiles,
      ...coordinationFiles,
    };
    for (final lock in locks.entries) {
      if (await FileSystemEntity.type(lock.value, followLinks: false) ==
              FileSystemEntityType.file &&
          await FileSystemEntity.identical(path, lock.value)) {
        return {'kind': 'coordination-alias', 'target': lock.key};
      }
    }
    return {'kind': 'file', 'length': await File(path).length()};
  }

  /// Fixed-size reads with backpressure, including for files larger than the
  /// legacy string API allows. Caller holds writer exclusion and rechecks bytes.
  Stream<List<int>> readChunks(
    String key, {
    int chunkBytes = 48 * 1024,
    Map<String, String> coordinationFiles = const {},
  }) async* {
    if (chunkBytes < 1 || chunkBytes > 64 * 1024) {
      throw ArgumentError.value(chunkBytes, 'chunkBytes');
    }
    final description = await describe(
      key,
      coordinationFiles: coordinationFiles,
    );
    if (description?['kind'] != 'file') {
      throw const FormatException('Recovery file changed before reading.');
    }
    final file = await File(await _checkedPath(key)).open();
    try {
      var remaining = description!['length'] as int;
      while (remaining > 0) {
        final bytes = await file.read(
          remaining < chunkBytes ? remaining : chunkBytes,
        );
        if (bytes.isEmpty) {
          throw const FormatException('Recovery file shrank during reading.');
        }
        remaining -= bytes.length;
        yield bytes;
      }
      if (await file.length() != description['length']) {
        throw const FormatException('Recovery file grew during reading.');
      }
    } finally {
      await file.close();
    }
  }

  @override
  Future<String?> read(String key) async {
    final description = await describe(key);
    if (description == null) return null;
    if (description['kind'] != 'file') return jsonEncode(description);
    if ((description['length'] as int) > maxFileBytes) {
      throw const FormatException('Recovery file exceeds its read bound.');
    }
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in readChunks(key)) {
      if (chunk.length > maxFileBytes - buffer.length) {
        throw const FormatException('Recovery file exceeds its read bound.');
      }
      buffer.add(chunk);
    }
    return jsonEncode({
      'kind': 'file',
      'bytes': base64Encode(buffer.takeBytes()),
    });
  }

  Future<String> _checkedPath(String key) async {
    if (!_validKey(key)) {
      throw const FormatException('Invalid recovery path.');
    }
    await _requireRealRoot();
    final parts = key.split('/');
    var parent = directory.path;
    for (final part in parts.take(parts.length - 1)) {
      parent = '$parent/$part';
      if (await FileSystemEntity.type(parent, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FormatException('Recovery path changed.');
      }
    }
    return '${directory.path}/$key';
  }

  Future<bool> matches(Map<String, String> records) async {
    final finalKeys = await keys();
    if (jsonEncode(finalKeys) != jsonEncode(records.keys.toList()..sort())) {
      return false;
    }
    for (final entry in records.entries) {
      if (await read(entry.key) != entry.value) return false;
    }
    return true;
  }

  Future<void> _requireRealRoot() async {
    var current = directory;
    while (true) {
      if (await FileSystemEntity.type(current.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FormatException('Recovery paths must be real directories.');
      }
      final parent = current.parent;
      if (parent.path == current.path) return;
      current = parent;
    }
  }
}

bool _validKey(String key) =>
    key.isNotEmpty &&
    !key.contains('\\') &&
    !key.contains(':') &&
    !key.contains('\u0000') &&
    !key.split('/').any((part) => part.isEmpty || part == '.' || part == '..');

Directory _normalizedDirectory(Directory directory) {
  var path = Directory.fromUri(directory.absolute.uri.normalizePath()).path;
  // Directory URIs carry a trailing separator, which changes lstat behavior on
  // links and would also skew relative-key offsets. Keep filesystem roots only.
  while (path.endsWith(Platform.pathSeparator) &&
      path != Platform.pathSeparator &&
      !RegExp(r'^[A-Za-z]:[\\/]$').hasMatch(path)) {
    path = path.substring(0, path.length - 1);
  }
  return Directory(path);
}
