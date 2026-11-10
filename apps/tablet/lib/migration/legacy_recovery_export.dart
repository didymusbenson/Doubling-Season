import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'legacy_migration_recovery.dart';
import 'legacy_recovery_files.dart';

/// Caller-provided capacity measurement for the actual destination filesystem.
/// Unknown capacity fails closed. A probe is not a reservation: writes/flushes
/// can still fail, and each write checks again to preserve the requested reserve.
class LegacyRecoveryExportBudget {
  final Future<int?> Function(Directory destination) availableBytes;
  final int reserveBytes;
  final int maxOutputBytes;

  const LegacyRecoveryExportBudget({
    required this.availableBytes,
    this.reserveBytes = 64 * 1024 * 1024,
    this.maxOutputBytes = 8 * 1024 * 1024 * 1024,
  });

  Future<void> check(Directory destination, int writeBytes, int written) async {
    if (reserveBytes < 0 || maxOutputBytes < 1) {
      throw ArgumentError('Invalid recovery export budget.');
    }
    if (writeBytes > maxOutputBytes - written) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.outputLimit,
      );
    }
    int? available;
    try {
      available = await availableBytes(destination);
    } catch (_) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.unknown,
      );
    }
    if (available == null || available < 0) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.unknown,
      );
    }
    if (available < reserveBytes || writeBytes > available - reserveBytes) {
      throw const LegacyRecoveryCapacityException(
        LegacyRecoveryCapacityFailure.insufficient,
      );
    }
  }
}

class LegacyRecoveryExportCancellation {
  bool _cancelled = false;
  void cancel() => _cancelled = true;
  void check() {
    if (_cancelled) throw const LegacyRecoveryCancelled();
  }
}

/// Explicit private destination and measured budget. No production directory or
/// free-space implementation is selected implicitly, and no evidence is deleted.
class LegacyRecoveryExportOptions {
  final Directory parent;
  final LegacyRecoveryExportBudget budget;
  final LegacyRecoveryExportCancellation? cancellation;
  final Future<void> Function(String boundary)? onBoundary;

  const LegacyRecoveryExportOptions({
    required this.parent,
    required this.budget,
    this.cancellation,
    this.onBoundary,
  });
}

class LegacyRecoveryExport {
  static const format = 'tripling-season-migration-recovery-stream';
  static const chunkBytes = 48 * 1024;
  static const maxEntries = 10000;
  static const maxMetadataBytes = 4 * 1024 * 1024;
  final File file;
  final int byteLength;
  final bool complete;
  final List<String> problems;
  final String sha256Digest;

  LegacyRecoveryExport._(
    this.file,
    this.byteLength,
    this.complete,
    List<String> problems,
    this.sha256Digest,
  ) : problems = List.unmodifiable(problems);

  LegacyRecoveryBackup get backup => LegacyRecoveryBackup.streamed(
    fileName: file.uri.pathSegments.last,
    byteLength: byteLength,
    complete: complete,
    problems: problems,
    openRead: file.openRead,
  );

  /// Version 2 is JSON Lines, with a header, named sources, entries and bounded
  /// base64 chunks. Each file has its original byte length and SHA-256. The last
  /// line hashes every preceding byte. It is a recovery artifact, not a restore
  /// command or a backup of unlisted original-installation stores.
  ///
  /// Callers hold all source writer leases for the entire operation. There is
  /// one pending file in a new private child, never an overwrite. Cancellation,
  /// I/O failure or interruption retains that attempt and all source evidence.
  /// Only a flushed, closed and independently re-read file is renamed, and the
  /// published file is rechecked before success. Directory fsync/power-loss
  /// durability is not available through Dart's portable filesystem API.
  static Future<LegacyRecoveryExport> write({
    required List<LegacyRecoveryFiles> sources,
    required LegacyRecoveryExportOptions options,
    DateTime? capturedAt,
  }) async {
    void check() => options.cancellation?.check();
    Future<void> boundary(String name) async {
      check();
      await options.onBoundary?.call(name);
      check();
    }

    check();
    if (sources.isEmpty ||
        sources.length > 32 ||
        sources.any(
          (s) => s.name.isEmpty || utf8.encode(s.name).length > 256,
        ) ||
        sources.map((s) => s.name).toSet().length != sources.length) {
      throw ArgumentError('Recovery requires bounded, uniquely named sources.');
    }
    final requestedParent = _normalized(options.parent);
    await _requireRealDirectory(requestedParent);
    final parent = _normalized(
      Directory(await requestedParent.resolveSymbolicLinks()),
    );
    for (final source in sources) {
      final canonicalSource = _normalized(
        Directory(await source.directory.resolveSymbolicLinks()),
      );
      if (_contains(canonicalSource.path, parent.path)) {
        throw ArgumentError('Export destination overlaps recovery evidence.');
      }
    }
    final coordinationFiles = <String, String>{
      for (final source in sources) ...source.coordinationFiles,
    };
    final inventories = <List<_Entry>>[];
    final problems = <String>[];
    var entryCount = 0;
    var metadataBytes = 0;
    var estimatedBytes = 8192 + sources.length * 8192;
    for (final source in sources) {
      check();
      final exclusionBytes = utf8
          .encode(jsonEncode(source.excludedTopLevelLockFiles.toList()))
          .length;
      if (source.excludedTopLevelLockFiles.length > 128 ||
          exclusionBytes > 16 * 1024) {
        throw const FormatException(
          'Recovery exclusion metadata exceeds its bound.',
        );
      }
      estimatedBytes += exclusionBytes;
      metadataBytes += exclusionBytes;
      final entries = <_Entry>[];
      // Inventory-limit errors abort before writing rather than misrepresent a
      // truncated inventory as the complete set. No recursive unbounded list.
      final keys = await source.boundedKeys(
        maxEntries: maxEntries - entryCount,
        maxKeyBytes: maxMetadataBytes - metadataBytes,
      );
      for (final key in keys) {
        check();
        Map<String, Object>? description;
        try {
          description = await source.describe(
            key,
            coordinationFiles: coordinationFiles,
          );
        } catch (_) {
          // An unavailable object still has its exact key in the artifact.
        }
        final entry = _Entry(key, description);
        entries.add(entry);
        entryCount++;
        final metadata = utf8.encode(jsonEncode(entry.metadata)).length;
        metadataBytes += metadata;
        if (metadataBytes > maxMetadataBytes) {
          throw const FormatException('Recovery metadata exceeds its bound.');
        }
        final length = description?['length'] as int? ?? 0;
        final chunks = (length + chunkBytes - 1) ~/ chunkBytes;
        // Conservative framing, escaping, footer/problem and directory overhead.
        estimatedBytes +=
            metadata * 2 + 1024 + ((length + 2) ~/ 3) * 4 + chunks * 64;
      }
      inventories.add(entries);
    }
    await options.budget.check(parent, estimatedBytes, 0);
    await boundary('export_preflight');
    final directory = await parent.createTemp('tripling-recovery-export-');
    final pending = File('${directory.path}/recovery.part');
    await pending.create(exclusive: true);
    final writer = await pending.open(mode: FileMode.writeOnly);
    final digest = _Hash();
    var written = 0;
    var payloadLength = 0;
    late List<int> trailer;
    late String checksum;
    Future<void> line(Map<String, Object?> value, {bool hash = true}) async {
      check();
      final bytes = utf8.encode('${jsonEncode(value)}\n');
      await options.budget.check(directory, bytes.length, written);
      check();
      await writer.writeFrom(bytes);
      written += bytes.length;
      if (hash) digest.addBytes(bytes);
      await boundary('export_written');
    }

    try {
      await line({
        'format': format,
        'version': 2,
        'capturedAt': (capturedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'scope':
            'Only the explicitly supplied physical migration stores; '
            'not an original-installation backup.',
        'chunkBytes': chunkBytes,
      });
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        final entries = inventories[i];
        var unavailable = 0;
        var unreadable = 0;
        await line({
          'type': 'source',
          'name': source.name,
          'excludedTopLevelLockFiles': source.excludedTopLevelLockFiles.toList()
            ..sort(),
          'coordinationAliases':
              'Metadata only; excluded coordination bytes are not opened.',
        });
        for (final entry in entries) {
          await line({'type': 'entry', ...entry.metadata});
          if (entry.description == null) {
            unavailable++;
            await line({'type': 'unavailable'});
            continue;
          }
          final fileHash = _Hash();
          var count = 0;
          var readable = true;
          if (entry.description!['kind'] == 'file') {
            // Catch source read errors only. Destination/cancellation failures
            // must propagate, never become a falsely successful partial save.
            final iterator = StreamIterator<List<int>>(
              source.readChunks(
                entry.key,
                coordinationFiles: coordinationFiles,
              ),
            );
            try {
              while (true) {
                check();
                bool more;
                try {
                  more = await iterator.moveNext();
                } catch (_) {
                  readable = false;
                  break;
                }
                if (!more) break;
                final bytes = iterator.current;
                fileHash.addBytes(bytes);
                count += bytes.length;
                await line({'type': 'chunk', 'data': base64Encode(bytes)});
              }
            } finally {
              await iterator.cancel();
            }
            if (count != entry.description!['length']) readable = false;
          }
          entry.hash = fileHash.finish();
          entry.readable = readable;
          if (!readable) {
            unreadable++;
          }
          await line({
            'type': 'end_entry',
            'bytes': count,
            'sha256': entry.hash,
            'readable': readable,
          });
        }
        await boundary('export_source_copied');
        var stable = true;
        try {
          final keys = await source.boundedKeys();
          if (jsonEncode(keys) !=
              jsonEncode(entries.map((e) => e.key).toList())) {
            stable = false;
          }
        } catch (_) {
          stable = false;
        }
        for (final entry in entries) {
          check();
          try {
            if (jsonEncode(
                  await source.describe(
                    entry.key,
                    coordinationFiles: coordinationFiles,
                  ),
                ) !=
                jsonEncode(entry.description)) {
              stable = false;
              continue;
            }
            if (entry.description?['kind'] == 'file' && entry.readable) {
              final hash = _Hash();
              await for (final bytes in source.readChunks(
                entry.key,
                coordinationFiles: coordinationFiles,
              )) {
                check();
                hash.addBytes(bytes);
              }
              if (hash.finish() != entry.hash) stable = false;
            }
          } on LegacyRecoveryCancelled {
            rethrow;
          } catch (_) {
            stable = false;
          }
        }
        if (!stable) {
          problems.add(
            '${source.name}: evidence changed or could not be rechecked.',
          );
        }
        if (unavailable > 0) {
          problems.add('${source.name}: $unavailable entries unavailable.');
        }
        if (unreadable > 0) {
          problems.add(
            '${source.name}: $unreadable entries incompletely read.',
          );
        }
        await line({'type': 'end_source', 'stableDuringRead': stable});
      }
      checksum = digest.finish();
      payloadLength = written;
      final footer = <String, Object?>{
        'type': 'complete',
        'complete': problems.isEmpty,
        'entries': entryCount,
        'sha256': checksum,
        'problems': problems,
      };
      trailer = utf8.encode('${jsonEncode(footer)}\n');
      await line(footer, hash: false);
      await writer.flush();
      await options.budget.check(directory, 0, written);
      await boundary('export_flushed');
    } finally {
      await writer.close();
    }
    await _verify(pending, payloadLength, trailer, checksum, check);
    await options.budget.check(directory, 0, written);
    await boundary('export_verified');
    final suffix = problems.isEmpty ? 'complete' : 'partial';
    final file = await pending.rename(
      '${directory.path}/recovery-$suffix.jsonl',
    );
    await boundary('export_published');
    await _verify(file, payloadLength, trailer, checksum, check);
    await options.budget.check(directory, 0, written);
    check();
    return LegacyRecoveryExport._(
      file,
      written,
      problems.isEmpty,
      problems,
      checksum,
    );
  }
}

class _Entry {
  final String key;
  final Map<String, Object>? description;
  String? hash;
  bool readable = false;
  _Entry(this.key, this.description);
  Map<String, Object?> get metadata => {
    'key': key,
    ...?description,
    if (description == null) 'kind': 'unavailable',
  };
}

class _Hash implements Sink<Digest> {
  late final ByteConversionSink _sink = sha256.startChunkedConversion(this);
  Digest? _digest;
  void addBytes(List<int> bytes) => _sink.add(bytes);
  @override
  void add(Digest digest) => _digest = digest;
  @override
  void close() {}
  String finish() {
    _sink.close();
    return _digest!.toString();
  }
}

Future<void> _verify(
  File file,
  int payloadLength,
  List<int> trailer,
  String expected,
  void Function() check,
) async {
  check();
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file ||
      await file.length() != payloadLength + trailer.length) {
    throw const FormatException('Recovery export length verification failed.');
  }
  final hash = _Hash();
  await for (final bytes in file.openRead(0, payloadLength)) {
    check();
    hash.addBytes(bytes);
  }
  if (hash.finish() != expected) {
    throw const FormatException(
      'Recovery export checksum verification failed.',
    );
  }
  final handle = await file.open();
  try {
    await handle.setPosition(payloadLength);
    final actual = await handle.read(trailer.length);
    if (base64Encode(actual) != base64Encode(trailer)) {
      throw const FormatException(
        'Recovery export completion verification failed.',
      );
    }
  } finally {
    await handle.close();
  }
  check();
}

bool _contains(String parent, String child) {
  // Resolve first, then conservatively fold case on platforms that commonly
  // expose case-insensitive volumes. Refusing distinct case-only paths is safer
  // than accidentally placing an export inside its own source inventory.
  if (Platform.isWindows || Platform.isIOS || Platform.isMacOS) {
    parent = parent.toLowerCase();
    child = child.toLowerCase();
  }
  return child == parent ||
      child.startsWith(
        parent.endsWith(Platform.pathSeparator)
            ? parent
            : '$parent${Platform.pathSeparator}',
      );
}

Directory _normalized(Directory directory) {
  var path = Directory.fromUri(directory.absolute.uri.normalizePath()).path;
  while (path.endsWith(Platform.pathSeparator) &&
      path != Platform.pathSeparator &&
      !RegExp(r'^[A-Za-z]:[\\/]$').hasMatch(path)) {
    path = path.substring(0, path.length - 1);
  }
  return Directory(path);
}

Future<void> _requireRealDirectory(Directory directory) async {
  var current = directory;
  while (true) {
    if (await FileSystemEntity.type(current.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FormatException('Export paths must be real directories.');
    }
    final parent = current.parent;
    if (parent.path == current.path) return;
    current = parent;
  }
}
