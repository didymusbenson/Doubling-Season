import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/legacy_recovery_export.dart';
import 'package:tripling_table/migration/legacy_recovery_files.dart';
import 'package:tripling_table/migration/legacy_recovery_retention.dart';
import 'package:tripling_table/migration/legacy_recovery_validator.dart';

import 'legacy_recovery_validator_test.dart' as fixture;

void main() {
  if (Platform.environment['TRIPLING_RETENTION_WORKER'] != null) {
    test('retention subprocess worker', () async {
      final directory = Directory(
        Platform.environment['TRIPLING_RETENTION_WORKER']!,
      );
      await LegacyRecoveryRetention.retain(
        File('${directory.path}/input').openRead(),
        options: LegacyRecoveryRetentionOptions(
          parent: Directory('${directory.path}/retained'),
          budget: LegacyRecoveryExportBudget(
            availableBytes: (_) async => 1 << 40,
          ),
          onBoundary: (name) async {
            if (name == Platform.environment['TRIPLING_RETENTION_BOUNDARY']) {
              await File(
                '${directory.path}/reached',
              ).writeAsString(name, flush: true);
              exit(73);
            }
          },
        ),
      );
    });
    return;
  }

  late Directory root, parent, source;
  final bytes = fixture.seal(fixture.records());
  final failure = isA<LegacyRecoveryRetentionFailure>();
  LegacyRecoveryExportBudget budget({
    int? capacity = 1 << 40,
    int max = 1 << 30,
  }) => LegacyRecoveryExportBudget(
    availableBytes: (_) async => capacity,
    reserveBytes: 100,
    maxOutputBytes: max,
  );
  Directory? activeAttempt;
  Future<LegacyRecoveryRetention> retain(
    Stream<List<int>> stream, {
    LegacyRecoveryExportBudget? capacity,
    LegacyRecoveryRetentionCancellation? cancellation,
    LegacyRecoveryValidationLimits limits =
        const LegacyRecoveryValidationLimits(),
    Future<void> Function(String)? hook,
  }) async {
    final prior = (await parent.list().toList()).map((e) => e.path).toSet();
    return LegacyRecoveryRetention.retain(
      stream,
      options: LegacyRecoveryRetentionOptions(
        parent: parent,
        budget: capacity ?? budget(),
        cancellation: cancellation,
        limits: limits,
        onBoundary: (name) async {
          activeAttempt = (await parent.list().toList())
              .whereType<Directory>()
              .singleWhere((d) => !prior.contains(d.path));
          await hook?.call(name);
        },
      ),
    );
  }

  Future<File> attemptFile() async {
    final files = await activeAttempt!.list().toList();
    return files.whereType<File>().single;
  }

  setUp(() async {
    final temp = await Directory.systemTemp.createTemp('retainer-test-');
    root = Directory(await temp.resolveSymbolicLinks());
    parent = await Directory('${root.path}/retained').create();
    source = await Directory('${root.path}/source').create();
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'synchronous cancellation plus throwing callback remains handled',
    () async {
      final cancellation = LegacyRecoveryRetentionCancellation();
      await expectLater(
        retain(
          Stream.value(bytes),
          cancellation: cancellation,
          capacity: LegacyRecoveryExportBudget(
            availableBytes: (_) {
              cancellation.cancel();
              throw StateError('private');
            },
          ),
        ),
        throwsA(failure),
      );
      final boundaryCancel = LegacyRecoveryRetentionCancellation();
      await expectLater(
        LegacyRecoveryRetention.retain(
          Stream.value(bytes),
          options: LegacyRecoveryRetentionOptions(
            parent: parent,
            budget: budget(),
            cancellation: boundaryCancel,
            onBoundary: (_) {
              boundaryCancel.cancel();
              throw StateError('private');
            },
          ),
        ),
        throwsA(failure),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'abrupt process exits preserve attempts and input across retries',
    () async {
      final input = await File('${root.path}/input').writeAsBytes(bytes);
      for (final boundary in [
        'retention_written',
        'retention_flushed',
        'retention_published',
      ]) {
        final result = await Process.run(
          '${Platform.environment['FLUTTER_ROOT']!}/bin/flutter',
          [
            'test',
            '--no-pub',
            '--reporter',
            'expanded',
            'test/legacy_recovery_retention_test.dart',
            '--plain-name',
            'retention subprocess worker',
          ],
          environment: {
            'TRIPLING_RETENTION_WORKER': root.path,
            'TRIPLING_RETENTION_BOUNDARY': boundary,
            'BOT': 'true',
            'CI': 'true',
          },
        );
        expect(
          result.exitCode,
          isNot(0),
          reason: '${result.stdout} ${result.stderr}',
        );
        expect(await File('${root.path}/reached').readAsString(), boundary);
        final prior = <String, List<int>>{};
        await for (final file in parent.list(recursive: true)) {
          if (file is File) prior[file.path] = await file.readAsBytes();
        }
        expect((await retain(input.openRead())).complete, isTrue);
        for (final entry in prior.entries) {
          expect(await File(entry.key).readAsBytes(), entry.value);
        }
        expect(await input.readAsBytes(), bytes);
      }
    },
    skip: Platform.environment['FLUTTER_ROOT'] == null,
  );

  test('validation report is bound to the exact bytes validated', () async {
    final otherRecords = fixture.records();
    otherRecords[3]['data'] = 'AQIE';
    otherRecords[4]['sha256'] = sha256.convert([1, 2, 4]).toString();
    final other = fixture.seal(otherRecords);
    expect(other.length, bytes.length);
    var reachedValidated = false;
    await expectLater(
      retain(
        Stream.value(bytes),
        hook: (name) async {
          if (name == 'retention_before_validation') {
            await (await attemptFile()).writeAsBytes(other);
          }
          if (name == 'retention_validated') {
            reachedValidated = true;
            await (await attemptFile()).writeAsBytes(bytes);
          }
        },
      ),
      throwsA(failure),
    );
    expect(reachedValidated, isFalse);
  });
  test(
    'large source event uses bounded writes and cancellation retains prefix',
    () async {
      await File(
        '${source.path}/data',
      ).writeAsBytes(List.generate(150000, (i) => i % 256));
      final output = await Directory('${root.path}/exports').create();
      final artifact = await LegacyRecoveryExport.write(
        sources: [LegacyRecoveryFiles(source, name: 'large')],
        options: LegacyRecoveryExportOptions(parent: output, budget: budget()),
      );
      final large = await artifact.file.readAsBytes();
      var written = 0;
      var writes = 0;
      final result = await retain(
        Stream.value(large),
        hook: (name) async {
          if (name == 'retention_written') {
            final length = await (await attemptFile()).length();
            expect(length - written, lessThanOrEqualTo(48 * 1024));
            written = length;
            writes++;
          }
        },
      );
      expect(writes, greaterThan(3));
      expect(await result.file.readAsBytes(), large);
      final cancel = LegacyRecoveryRetentionCancellation();
      await expectLater(
        retain(
          Stream.value(large),
          cancellation: cancel,
          hook: (name) async {
            if (name == 'retention_written') cancel.cancel();
          },
        ),
        throwsA(failure),
      );
      expect(
        await (await attemptFile()).readAsBytes(),
        large.sublist(0, 48 * 1024),
      );
      expect(await artifact.file.readAsBytes(), large);
    },
  );

  test('mutable event growth cannot expand the accepted event', () async {
    final mutable = List<int>.of(bytes);
    final result = await retain(
      Stream.value(mutable),
      limits: LegacyRecoveryValidationLimits(maxStreamBytes: bytes.length),
      hook: (name) async {
        if (name == 'retention_written') mutable.addAll([1, 2, 3]);
      },
    );
    expect(await result.file.readAsBytes(), bytes);
  });
  test(
    'lost reserve after write, flush, validation or publication fails',
    () async {
      for (final boundary in [
        'retention_written',
        'retention_flushed',
        'retention_validated',
        'retention_published',
      ]) {
        var available = 1 << 40;
        await expectLater(
          retain(
            Stream.value(bytes),
            capacity: LegacyRecoveryExportBudget(
              availableBytes: (_) async => available,
            ),
            hook: (name) async {
              if (name == boundary) available = 0;
            },
          ),
          throwsA(failure),
        );
      }
    },
  );
  test(
    'invalid configuration and pre-cancel do not consume input or create children',
    () async {
      final cancel = LegacyRecoveryRetentionCancellation()..cancel();
      var listened = false;
      Stream<List<int>> input() async* {
        listened = true;
        yield bytes;
      }

      await expectLater(
        retain(input(), cancellation: cancel),
        throwsA(failure),
      );
      await expectLater(
        retain(
          input(),
          limits: const LegacyRecoveryValidationLimits(maxLineBytes: 0),
        ),
        throwsA(failure),
      );
      expect(listened, isFalse);
      expect(await parent.list().length, 0);
    },
  );
  test(
    'timeout at each stalled boundary retains attempt and rejects late completion',
    () async {
      for (final boundary in [
        'retention_created',
        'retention_written',
        'retention_flushed',
        'retention_validated',
        'retention_before_publish',
        'retention_published',
      ]) {
        final stall = Completer<void>();
        await expectLater(
          retain(
            Stream.value(bytes),
            limits: const LegacyRecoveryValidationLimits(
              timeout: Duration(milliseconds: 100),
            ),
            hook: (name) async {
              if (name == boundary) await stall.future;
            },
          ),
          throwsA(failure),
        );
        final file = await attemptFile();
        final before = await file.readAsBytes();
        stall.complete();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(await file.readAsBytes(), before);
      }
    },
  );
  for (final phase in ['write', 'flush']) {
    test(
      'actual ENOSPC during $phase preserves written bytes and prior success',
      () async {
        final prior = await retain(Stream.value(bytes));
        final outside = Zone.current;
        await expectLater(
          IOOverrides.runZoned(
            () => retain(Stream.value(bytes)),
            fseGetType: (path, followLinks) => outside.run(
              () => FileSystemEntity.type(path, followLinks: followLinks),
            ),
            createFile: (path) {
              final file = outside.run(() => File(path));
              return path.endsWith('/recovery.part')
                  ? _FaultFile(file, phase)
                  : file;
            },
          ),
          throwsA(failure),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(await prior.file.readAsBytes(), bytes);
        expect(await parent.list().length, 2);
        expect(
          await (await attemptFile()).readAsBytes(),
          phase == 'write' ? bytes.sublist(0, 17) : bytes,
        );
      },
      skip: !Platform.isLinux,
    );
    test(
      'late pending $phase closes handle only after operation settles',
      () async {
        final outside = Zone.current;
        final pending = Completer<void>();
        final closed = Completer<void>();
        final cancellation = LegacyRecoveryRetentionCancellation();
        await expectLater(
          IOOverrides.runZoned(
            () => retain(Stream.value(bytes), cancellation: cancellation),
            fseGetType: (path, followLinks) => outside.run(
              () => FileSystemEntity.type(path, followLinks: followLinks),
            ),
            createFile: (path) {
              final file = outside.run(() => File(path));
              return path.endsWith('/recovery.part')
                  ? _FaultFile(
                      file,
                      phase,
                      pending: pending,
                      closed: closed,
                      started: cancellation.cancel,
                    )
                  : file;
            },
          ),
          throwsA(failure),
        );
        expect(closed.isCompleted, isFalse);
        pending.complete();
        await closed.future.timeout(const Duration(seconds: 2));
        expect(await parent.list().length, 1);
      },
    );
  }

  test(
    'arbitrary framing preserves whole bytes, inert forged marker and source',
    () async {
      await File('${source.path}/marker.json').writeAsBytes(bytes);
      final result = await retain(
        Stream.fromIterable(bytes.map((byte) => [byte])),
      );
      expect(result.complete, isTrue);
      expect(result.sha256Digest, sha256.convert(bytes).toString());
      expect(result.sha256Digest, isNot(result.validation.sha256Digest));
      expect(result.byteLength, bytes.length);
      expect(await result.file.readAsBytes(), bytes);
      expect(await File('${source.path}/marker.json').readAsBytes(), bytes);
      expect(
        await parent.list(recursive: true).where((e) => e is File).length,
        1,
      );
    },
  );
  test('real exporter complete, partial and unstable roundtrips', () async {
    await File('${source.path}/data').writeAsBytes([1]);
    await File(
      '${source.path}/marker.json',
    ).writeAsString('{"phase":"committed","trusted":true}');
    final exports = await Directory('${root.path}/exports').create();
    for (final input in [
      LegacyRecoveryFiles(source, name: 'complete'),
      _Partial(source),
      _Unstable(source),
    ]) {
      final artifact = await LegacyRecoveryExport.write(
        sources: [input],
        options: LegacyRecoveryExportOptions(parent: exports, budget: budget()),
      );
      final result = await retain(artifact.file.openRead());
      expect(result.complete, artifact.complete);
      expect(
        await result.file.readAsBytes(),
        await artifact.file.readAsBytes(),
      );
      if (input is _Partial) expect(result.validation.incompleteFiles, 2);
      if (input is _Unstable) expect(result.validation.unstableSources, 1);
    }
  });
  test(
    'invalid truncated trailing and out of range inputs never succeed',
    () async {
      for (final input in [
        <int>[],
        [1, 2, 3],
        bytes.sublist(0, bytes.length - 1),
        [...bytes, 10],
        [-1],
        [256],
      ]) {
        await expectLater(retain(Stream.value(input)), throwsA(failure));
      }
      expect(await parent.list().length, 6);
    },
  );
  test(
    'unknown insufficient changing and output budgets fail closed',
    () async {
      var listened = false;
      Stream<List<int>> input() async* {
        listened = true;
        yield bytes;
      }

      for (final capacity in [null, 0, 99, -1]) {
        await expectLater(
          retain(input(), capacity: budget(capacity: capacity)),
          throwsA(failure),
        );
        expect(listened, isFalse);
      }
      var calls = 0;
      await expectLater(
        retain(
          input(),
          capacity: LegacyRecoveryExportBudget(
            availableBytes: (_) async => ++calls == 1 ? 1 << 40 : 0,
          ),
        ),
        throwsA(failure),
      );
      await expectLater(
        retain(Stream.value(bytes), capacity: budget(max: bytes.length - 1)),
        throwsA(failure),
      );
      await expectLater(
        retain(
          Stream.value(bytes),
          limits: LegacyRecoveryValidationLimits(
            maxStreamBytes: bytes.length - 1,
          ),
        ),
        throwsA(failure),
      );
      await expectLater(
        retain(
          Stream.fromIterable([[], [], bytes]),
          limits: const LegacyRecoveryValidationLimits(maxStreamEvents: 2),
        ),
        throwsA(failure),
      );
    },
  );
  test('producer errors are sanitized and retries preserve attempts', () async {
    Stream<List<int>> broken() async* {
      yield bytes.sublist(0, 80);
      throw StateError('PRIVATE INPUT');
    }

    await expectLater(
      retain(broken()),
      throwsA(
        predicate(
          (e) =>
              e is LegacyRecoveryRetentionFailure &&
              !e.toString().contains('PRIVATE'),
        ),
      ),
    );
    final old = await attemptFile();
    final result = await retain(Stream.value(bytes));
    expect(old.parent.path, isNot(result.file.parent.path));
    expect(await old.readAsBytes(), bytes.sublist(0, 80));
    expect(await parent.list().length, 2);
  });
  test('stalled producer and uncooperative cancellation are bounded', () async {
    for (final cancel in [false, true]) {
      final cancellation = LegacyRecoveryRetentionCancellation();
      final controller = StreamController<List<int>>(
        onCancel: () => Completer<void>().future,
      );
      final future = retain(
        controller.stream,
        cancellation: cancellation,
        limits: const LegacyRecoveryValidationLimits(
          timeout: Duration(milliseconds: 100),
        ),
      );
      if (cancel) Timer(const Duration(milliseconds: 20), cancellation.cancel);
      await expectLater(
        future.timeout(const Duration(seconds: 2)),
        throwsA(failure),
      );
    }
  });
  test(
    'cancelled stalled budget and boundary cannot issue subsequent writes',
    () async {
      for (final name in [
        'budget',
        'retention_written',
        'retention_flushed',
        'retention_validated',
        'retention_before_publish',
        'retention_published',
      ]) {
        final cancellation = LegacyRecoveryRetentionCancellation();
        final stall = Completer<void>();
        var probes = 0;
        final future = retain(
          Stream.value(bytes),
          cancellation: cancellation,
          capacity: name == 'budget'
              ? LegacyRecoveryExportBudget(
                  availableBytes: (_) async {
                    if (++probes == 2) {
                      cancellation.cancel();
                      await stall.future;
                    }
                    return 1 << 40;
                  },
                )
              : null,
          hook: (boundary) async {
            if (boundary == name) {
              cancellation.cancel();
              await stall.future;
            }
          },
        );
        await expectLater(
          future.timeout(const Duration(seconds: 2)),
          throwsA(failure),
        );
        final file = await attemptFile();
        final before = await file.readAsBytes();
        stall.complete();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(await file.readAsBytes(), before);
      }
    },
  );
  test(
    'write flush readback and publish faults retain failed attempts',
    () async {
      for (final name in [
        'retention_before_write',
        'retention_written',
        'retention_before_flush',
        'retention_flushed',
        'retention_before_validation',
        'retention_validated',
        'retention_before_publish',
        'retention_published',
      ]) {
        await expectLater(
          retain(
            Stream.value(bytes),
            hook: (boundary) async {
              if (boundary == name) throw StateError('fault');
            },
          ),
          throwsA(failure),
        );
      }
      expect(await parent.list().length, 8);
    },
  );
  test(
    'corruption after flush validation and publication cannot succeed',
    () async {
      for (final name in [
        'retention_flushed',
        'retention_validated',
        'retention_before_publish',
        'retention_published',
      ]) {
        await expectLater(
          retain(
            Stream.value(bytes),
            hook: (boundary) async {
              if (boundary == name) {
                final file = await attemptFile();
                await file.writeAsBytes([...bytes, 10]);
              }
            },
          ),
          throwsA(failure),
        );
      }
    },
  );
  test('existing publish target is never overwritten', () async {
    File? collision;
    await expectLater(
      retain(
        Stream.value(bytes),
        hook: (boundary) async {
          if (boundary == 'retention_before_publish') {
            final pending = await attemptFile();
            collision = File('${pending.parent.path}/recovery.v2.jsonl');
            await collision!.writeAsString('untouched');
          }
        },
      ),
      throwsA(failure),
    );
    expect(await collision!.readAsString(), 'untouched');
  });
  test(
    'symlink parent and ancestor rejected before consuming input',
    () async {
      final alias = Link('${root.path}/alias');
      await alias.create(parent.path);
      for (final path in [alias.path, '${alias.path}/child']) {
        if (path.endsWith('child')) {
          await Directory('${parent.path}/child').create();
        }
        var listened = false;
        Stream<List<int>> input() async* {
          listened = true;
          yield bytes;
        }

        await expectLater(
          LegacyRecoveryRetention.retain(
            input(),
            options: LegacyRecoveryRetentionOptions(
              parent: Directory(path),
              budget: budget(),
            ),
          ),
          throwsA(failure),
        );
        expect(listened, isFalse);
      }
    },
    skip: Platform.isWindows,
  );
}

class _Partial extends LegacyRecoveryFiles {
  _Partial(super.directory) : super(name: 'partial');
  @override
  Stream<List<int>> readChunks(
    String key, {
    int chunkBytes = 48 * 1024,
    Map<String, String> coordinationFiles = const {},
  }) async* {
    yield [9];
    throw const FileSystemException('unreadable');
  }
}

class _Unstable extends LegacyRecoveryFiles {
  int reads = 0;
  _Unstable(super.directory) : super(name: 'unstable');
  @override
  Stream<List<int>> readChunks(
    String key, {
    int chunkBytes = 48 * 1024,
    Map<String, String> coordinationFiles = const {},
  }) async* {
    yield [++reads];
  }
}

class _FaultFile implements File {
  final File file;
  final String phase;
  final Completer<void>? pending, closed;
  final void Function()? started;
  _FaultFile(this.file, this.phase, {this.pending, this.closed, this.started});
  @override
  String get path => file.path;
  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) =>
      file.create(recursive: recursive, exclusive: exclusive);
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      _FaultHandle(
        await file.open(mode: mode),
        phase,
        pending,
        closed,
        started,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FaultHandle implements RandomAccessFile {
  final RandomAccessFile file;
  final String phase;
  final Completer<void>? pending, closed;
  final void Function()? started;
  _FaultHandle(this.file, this.phase, this.pending, this.closed, this.started);
  Future<void> fault() async {
    if (pending != null) {
      started!();
      await pending!.future;
      return;
    }
    final full = await File('/dev/full').open(mode: FileMode.writeOnly);
    try {
      await full.writeByte(1);
    } finally {
      await full.close();
    }
  }

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> bytes, [
    int start = 0,
    int? end,
  ]) async {
    if (phase == 'write') {
      await file.writeFrom(bytes, start, start + 17);
      await fault();
    } else {
      await file.writeFrom(bytes, start, end);
    }
    return this;
  }

  @override
  Future<RandomAccessFile> flush() async {
    if (phase == 'flush') await fault();
    await file.flush();
    return this;
  }

  @override
  Future<void> close() async {
    await file.close();
    closed?.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
