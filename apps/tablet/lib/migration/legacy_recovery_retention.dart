import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'legacy_recovery_export.dart';
import 'legacy_recovery_validator.dart';

class LegacyRecoveryRetentionCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners.toList()) {
      listener();
    }
    _listeners.clear();
  }
}

/// Deliberately generic: input names, contents and producer exception text must
/// never become diagnostics or authority over the destination.
class LegacyRecoveryRetentionFailure implements Exception {
  const LegacyRecoveryRetentionFailure();
  @override
  String toString() => 'Recovery evidence retention did not complete.';
}

class LegacyRecoveryRetentionOptions {
  final Directory parent;
  final LegacyRecoveryExportBudget budget;
  final LegacyRecoveryValidationLimits limits;
  final LegacyRecoveryRetentionCancellation? cancellation;

  /// Test-only fault boundary. Production callers should omit this callback.
  final Future<void> Function(String boundary)? onBoundary;
  const LegacyRecoveryRetentionOptions({
    required this.parent,
    required this.budget,
    this.limits = const LegacyRecoveryValidationLimits(),
    this.cancellation,
    this.onBoundary,
  });
}

/// Retained bytes are inert evidence, not a restore, receipt, trusted marker,
/// authenticity assertion or durable/power-loss guarantee. Even complete
/// validation does not authorize migration. Partial evidence stays partial.
class LegacyRecoveryRetention {
  final File file;
  final int byteLength;

  /// SHA-256 of ALL copied bytes, including the format's checksum footer.
  final String sha256Digest;
  final LegacyRecoveryValidationResult validation;
  bool get complete => validation.complete;
  const LegacyRecoveryRetention._(
    this.file,
    this.byteLength,
    this.sha256Digest,
    this.validation,
  );

  /// Caller supplies a real, private parent and owns exclusive access to it.
  /// Ancestors and file types are checked, but portable Dart cannot prevent a
  /// hostile process racing filesystem replacement. The upstream owns its own
  /// allocation and pause/cancel behavior; retained buffers/writes are bounded.
  /// Failures retain every created attempt, including published-but-unverified
  /// files. No existing child is adopted, cleaned up, or used on retry.
  static Future<LegacyRecoveryRetention> retain(
    Stream<List<int>> input, {
    required LegacyRecoveryRetentionOptions options,
  }) async {
    final guard = _Guard(options);
    StreamIterator<List<int>>? iterator;
    RandomAccessFile? writer;
    Future<Object?>? writerOperation;
    final validationCancellation = LegacyRecoveryValidationCancellation();
    try {
      if ([
            options.limits.maxStreamBytes,
            options.limits.maxStreamEvents,
            options.limits.maxLineBytes,
            options.limits.maxEntries,
            options.limits.maxSources,
            options.limits.maxMetadataBytes,
            options.limits.maxFileBytes,
            options.limits.maxPayloadBytes,
          ].any((n) => n < 1) ||
          options.limits.timeout <= Duration.zero) {
        throw const LegacyRecoveryRetentionFailure();
      }
      final parent = _normalized(options.parent);
      await guard.wait(() => _realDirectory(parent));
      await guard.wait(() => options.budget.check(parent, 0, 0));
      final child = await guard.wait(
        () => parent.createTemp('retained-recovery-'),
      );
      final pending = File('${child.path}/recovery.part');
      final published = File('${child.path}/recovery.v2.jsonl');
      await guard.wait(() => pending.create(exclusive: true));
      Future<RandomAccessFile>? opening;
      try {
        writer = await guard.wait(
          () => opening = pending.open(mode: FileMode.writeOnly),
        );
      } catch (_) {
        if (opening != null) {
          unawaited(
            opening!
                .then<void>((handle) async {
                  await handle.close();
                })
                .catchError((Object _) {}),
          );
        }
        rethrow;
      }
      await guard.boundary('retention_created');
      iterator = StreamIterator(input);
      final incoming = _Hash();
      var length = 0;
      var events = 0;
      while (await guard.wait(() => iterator!.moveNext())) {
        if (++events > options.limits.maxStreamEvents) {
          throw const LegacyRecoveryRetentionFailure();
        }
        final event = iterator.current;
        final eventLength = event.length;
        if (eventLength > options.limits.maxStreamBytes - length) {
          throw const LegacyRecoveryRetentionFailure();
        }
        for (var offset = 0; offset < eventLength;) {
          guard.check();
          final count = (eventLength - offset).clamp(0, 48 * 1024);
          // Snapshot before an await: do not hash a producer's mutable buffer
          // after writing it. Invalid integer bytes must not silently truncate.
          final bytes = Uint8List(count);
          for (var i = 0; i < count; i++) {
            final byte = event[offset + i];
            if (byte < 0 || byte > 255) {
              throw const LegacyRecoveryRetentionFailure();
            }
            bytes[i] = byte;
          }
          await guard.wait(() => options.budget.check(child, count, length));
          await guard.boundary('retention_before_write');
          await guard.wait(() => writerOperation = writer!.writeFrom(bytes));
          incoming.sink.add(bytes);
          length += count;
          offset += count;
          await guard.boundary('retention_written');
        }
      }
      await guard.boundary('retention_before_flush');
      await guard.wait(() => writerOperation = writer!.flush());
      await guard.boundary('retention_flushed');
      await guard.wait(() => options.budget.check(child, 0, length));
      await guard.wait(() => writerOperation = writer!.close());
      writer = null;
      final digest = incoming.finish();
      await guard.boundary('retention_before_validation');
      await guard.wait(() => _realFile(pending));
      final validatedHash = _Hash();
      var validatedLength = 0;
      final validation = await guard.wait(
        () => LegacyRecoveryValidator.validate(
          pending.openRead().map((chunk) {
            validatedLength += chunk.length;
            if (validatedLength > length) {
              throw const LegacyRecoveryRetentionFailure();
            }
            validatedHash.sink.add(chunk);
            return chunk;
          }),
          limits: options.limits,
          cancellation: validationCancellation,
        ),
      );
      if (validatedLength != length || validatedHash.finish() != digest) {
        throw const LegacyRecoveryRetentionFailure();
      }
      await guard.boundary('retention_validated');
      await _verify(pending, length, digest, guard);
      await guard.boundary('retention_before_publish');
      await guard.wait(() => options.budget.check(child, 0, length));
      // Hooks can perturb the filesystem; check again after the boundary.
      await _verify(pending, length, digest, guard);
      if (await guard.wait(
            () => FileSystemEntity.type(published.path, followLinks: false),
          ) !=
          FileSystemEntityType.notFound) {
        throw const LegacyRecoveryRetentionFailure();
      }
      final file = await guard.wait(() => pending.rename(published.path));
      await guard.boundary('retention_published');
      await _verify(file, length, digest, guard);
      await guard.wait(() => options.budget.check(child, 0, length));
      guard.check();
      return LegacyRecoveryRetention._(file, length, digest, validation);
    } catch (_) {
      throw const LegacyRecoveryRetentionFailure();
    } finally {
      validationCancellation.cancel();
      // Cleanup must not let hostile onCancel defeat the bounded deadline.
      // An already issued OS operation may finish later; nothing is deleted.
      if (iterator != null) {
        unawaited(iterator.cancel().catchError((Object _) {}));
      }
      final handle = writer;
      if (handle != null) {
        // Dart rejects concurrent operations on a RandomAccessFile. Close only
        // after the outstanding write/flush settles, without awaiting it here.
        unawaited(
          (writerOperation ?? Future<Object?>.value())
              .then<void>((_) {}, onError: (Object _) {})
              .then<void>((_) async {
                await handle.close();
              })
              .catchError((Object _) {}),
        );
      }
      guard.stop();
    }
  }
}

class _Guard {
  final LegacyRecoveryRetentionOptions options;
  final Stopwatch watch = Stopwatch()..start();
  bool stopped = false;
  _Guard(this.options);
  void check() {
    if (stopped ||
        (options.cancellation?._cancelled ?? false) ||
        watch.elapsed >= options.limits.timeout) {
      throw const LegacyRecoveryRetentionFailure();
    }
  }

  Future<T> wait<T>(Future<T> Function() operation) async {
    check();
    final cancelled = Completer<T>();
    void cancel() {
      if (!cancelled.isCompleted) {
        cancelled.completeError(const LegacyRecoveryRetentionFailure());
      }
    }

    options.cancellation?._listeners.add(cancel);
    try {
      // Check before issuing each operation. A timeout cannot revoke an OS
      // operation already issued; retain its failure handler and cleanup.
      final pending = Future.any<T>([
        Future<T>.sync(operation),
        cancelled.future,
      ]);
      if (stopped || (options.cancellation?._cancelled ?? false)) cancel();
      final remaining = options.limits.timeout - watch.elapsed;
      final result = await pending.timeout(
        remaining > Duration.zero ? remaining : Duration.zero,
      );
      check();
      return result;
    } finally {
      options.cancellation?._listeners.remove(cancel);
    }
  }

  Future<void> boundary(String name) async {
    check();
    if (options.onBoundary != null) await wait(() => options.onBoundary!(name));
    check();
  }

  void stop() {
    stopped = true;
    watch.stop();
  }
}

Future<void> _realDirectory(Directory directory) async {
  var current = directory;
  while (true) {
    if (await FileSystemEntity.type(current.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const LegacyRecoveryRetentionFailure();
    }
    final parent = current.parent;
    if (parent.path == current.path) return;
    current = parent;
  }
}

Future<void> _realFile(File file) async {
  await _realDirectory(file.parent);
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const LegacyRecoveryRetentionFailure();
  }
}

Future<void> _verify(File file, int length, String digest, _Guard guard) async {
  await guard.wait(() => _realFile(file));
  final iterator = StreamIterator(file.openRead());
  final hash = _Hash();
  var count = 0;
  try {
    while (await guard.wait(() => iterator.moveNext())) {
      count += iterator.current.length;
      if (count > length) throw const LegacyRecoveryRetentionFailure();
      hash.sink.add(iterator.current);
    }
    if (count != length || hash.finish() != digest) {
      throw const LegacyRecoveryRetentionFailure();
    }
  } finally {
    unawaited(iterator.cancel().catchError((Object _) {}));
  }
}

class _Hash implements Sink<Digest> {
  late final ByteConversionSink sink = sha256.startChunkedConversion(this);
  Digest? digest;
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
  String finish() {
    sink.close();
    return digest.toString();
  }
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
