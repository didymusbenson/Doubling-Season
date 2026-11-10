import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'legacy_migration_recovery.dart';

/// Read-only physical evidence for explicitly supplied private recovery stores.
/// Unknown/corrupt files and literal link targets are retained without opening
/// Hive or following links. The caller owns writer exclusion; double reads can
/// detect changes but cannot establish a consistent live-installation snapshot.
class LegacyRecoveryFiles implements LegacyRecoveryRecordSource {
  static const maxFileBytes = 512 * 1024 * 1024;
  final Directory directory;
  @override
  final String name;
  final Set<String> excludedTopLevelLockFiles;

  LegacyRecoveryFiles(
    Directory directory, {
    required this.name,
    Set<String> excludedTopLevelLockFiles = const {},
  }) : directory = _normalizedDirectory(directory),
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

  @override
  Future<List<String>> keys() async {
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
      if (!_validKey(key)) {
        throw const FormatException('Invalid recovery path.');
      }
      if (_excluded(key) &&
          await FileSystemEntity.type(entity.path, followLinks: false) ==
              FileSystemEntityType.file) {
        continue;
      }
      result.add(key);
    }
    return result..sort();
  }

  bool _excluded(String key) =>
      !key.contains('/') && excludedTopLevelLockFiles.contains(key);

  @override
  Future<String?> read(String key) async {
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
    final path = '${directory.path}/$key';
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type == FileSystemEntityType.link) {
      return jsonEncode({'kind': 'link', 'target': await Link(path).target()});
    }
    if (type == FileSystemEntityType.directory) {
      return jsonEncode({'kind': 'directory'});
    }
    // Never open a known coordination inode, even on a direct read: closing a
    // second descriptor can release the caller's process-wide POSIX lock.
    if (type == FileSystemEntityType.file && _excluded(key)) return null;
    final file = File(path);
    if (type != FileSystemEntityType.file ||
        await file.length() > maxFileBytes) {
      throw const FormatException('Recovery file is unreadable or too large.');
    }
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, maxFileBytes + 1)) {
      buffer.add(chunk);
    }
    final bytes = buffer.takeBytes();
    if (bytes.length > maxFileBytes) {
      throw const FormatException('Recovery file exceeds its read bound.');
    }
    return jsonEncode({'kind': 'file', 'bytes': base64Encode(bytes)});
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
