import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/legacy_migration_coordinator.dart';
import 'package:tripling_table/migration/legacy_migration_recovery.dart';
import 'package:tripling_table/migration/legacy_recovery_export.dart';
import 'package:tripling_table/migration/legacy_recovery_files.dart';
import 'package:tripling_table/migration/legacy_source_archive.dart';

class _StreamingOnlyFiles extends LegacyRecoveryFiles {
  _StreamingOnlyFiles(super.directory) : super(name: 'exact-files');
  @override
  Future<String?> read(String key) =>
      throw StateError('Whole-file read forbidden');
}

class _ChangingFiles extends _StreamingOnlyFiles {
  bool change = false;
  _ChangingFiles(super.directory);
  @override
  Stream<List<int>> readChunks(
    String key, {
    int chunkBytes = 48 * 1024,
    Map<String, String> coordinationFiles = const {},
  }) async* {
    if (change) {
      yield [8, 9, 10];
    } else {
      yield* super.readChunks(
        key,
        chunkBytes: chunkBytes,
        coordinationFiles: coordinationFiles,
      );
      change = true;
    }
  }
}

class _FailingRead extends _StreamingOnlyFiles {
  _FailingRead(super.directory);
  @override
  Stream<List<int>> readChunks(
    String key, {
    int chunkBytes = 48 * 1024,
    Map<String, String> coordinationFiles = const {},
  }) async* {
    yield [0, 255];
    throw const FileSystemException('Private source details must not escape.');
  }
}

Future<int?> _unlimited(Directory _) async => 1 << 40;
LegacyRecoveryExportOptions _options(
  Directory parent, {
  Future<int?> Function(Directory)? available,
  LegacyRecoveryExportCancellation? cancellation,
  Future<void> Function(String)? onBoundary,
  int maxOutputBytes = 1 << 30,
}) => LegacyRecoveryExportOptions(
  parent: parent,
  budget: LegacyRecoveryExportBudget(
    availableBytes: available ?? _unlimited,
    reserveBytes: 4096,
    maxOutputBytes: maxOutputBytes,
  ),
  cancellation: cancellation,
  onBoundary: onBoundary,
);

Future<Map<String, String>> _hashes(Directory directory) async => {
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  ))
    if (entity is File)
      entity.path: (await sha256.bind(entity.openRead()).single).toString(),
};

Future<List<File>> _outputs(Directory directory) async => [
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  ))
    if (entity is File) entity,
];

Future<List<Map<String, dynamic>>> _lines(File file) async => [
  await for (final line
      in file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter()))
    jsonDecode(line) as Map<String, dynamic>,
];

class _FailingFile implements File {
  final File file;
  final String phase;
  _FailingFile(this.file, this.phase);
  @override
  String get path => file.path;
  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) =>
      file.create(recursive: recursive, exclusive: exclusive);
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      _FailingHandle(await file.open(mode: mode), phase);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingHandle implements RandomAccessFile {
  final RandomAccessFile file;
  final String phase;
  _FailingHandle(this.file, this.phase);
  Future<void> _enospc() async {
    final full = await File('/dev/full').open(mode: FileMode.writeOnly);
    try {
      await full.writeByte(1);
    } finally {
      await full.close();
    }
  }

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) async {
    if (phase == 'write') {
      await file.writeFrom(buffer, start, start + 17);
      await _enospc();
    }
    await file.writeFrom(buffer, start, end);
    return this;
  }

  @override
  Future<RandomAccessFile> flush() async {
    if (phase == 'flush') await _enospc();
    await file.flush();
    return this;
  }

  @override
  Future<void> close() => file.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Strings implements LegacyRecoveryRecordSource {
  @override
  String get name => 'strings';
  @override
  Future<List<String>> keys() async => ['one', 'two'];
  @override
  Future<String?> read(String key) async => 'x' * (3 * 1024 * 1024);
}

class _ThrowingActions implements LegacyRecoveryActions {
  final Exception exception;
  _ThrowingActions(this.exception);
  @override
  Future<LegacyRecoveryBackup> createBackup() async => throw exception;
  @override
  Future<LegacyRecoveryReport> inspect() => throw UnimplementedError();
  @override
  Future<LegacyRecoveryReport> retry() => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final worker = Platform.environment['TRIPLING_EXPORT_WORKER'];
  if (worker != null) {
    test('export subprocess worker', () async {
      final archive = await LegacySourceArchive.reopen(Directory(worker));
      await archive.exportRecoveryBackup(
        options: _options(
          Directory(Platform.environment['TRIPLING_EXPORT_OUTPUT']!),
          onBoundary: (boundary) async {
            if (boundary == Platform.environment['TRIPLING_EXPORT_BOUNDARY']) {
              await File(
                '${archive.directory.parent.path}/worker-reached',
              ).writeAsString(boundary, flush: true);
              exit(
                73,
              ); // No Dart cleanup; the next process must acquire the lease.
            }
          },
        ),
      );
      fail('Requested abrupt exit did not happen.');
    });
    return;
  }
  late Directory parent;
  late Directory source;
  late Directory output;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('bounded-export-test-');
    source = await Directory('${parent.path}/source').create();
    output = await Directory('${parent.path}/output').create();
    await File('${source.path}/opaque.bin').writeAsBytes([0, 255, 128, 2, 4]);
  });
  tearDown(() async => parent.delete(recursive: true));

  Future<LegacyRecoveryExport> export({
    LegacyRecoveryExportOptions? options,
    LegacyRecoveryFiles? files,
  }) => LegacyRecoveryExport.write(
    sources: [files ?? _StreamingOnlyFiles(source)],
    options: options ?? _options(output),
    capturedAt: DateTime.utc(2026, 11, 10),
  );

  test(
    'streams exact binary, unknown, nested and literal link evidence',
    () async {
      await Directory('${source.path}/empty').create();
      await Directory('${source.path}/nested').create();
      await File(
        '${source.path}/nested/pending.part',
      ).writeAsString('bad\u0000 Ω');
      await Link('${source.path}/link').create('../outside-must-not-be-read');
      final original = await _hashes(source);
      final result = await export();
      expect(result.complete, isTrue);
      expect(result.problems, isEmpty);
      expect(result.file.path, endsWith('recovery-complete.jsonl'));
      expect(result.byteLength, await result.file.length());
      final lines = await _lines(result.file);
      expect(lines.first['format'], LegacyRecoveryExport.format);
      expect(lines.first['version'], 2);
      expect(lines.last['complete'], isTrue);
      expect(lines.last['sha256'], result.sha256Digest);
      final entries = lines.where((e) => e['type'] == 'entry').toList();
      expect(entries.map((e) => e['key']), [
        'empty',
        'link',
        'nested',
        'nested/pending.part',
        'opaque.bin',
      ]);
      expect(entries[1]['target'], '../outside-must-not-be-read');
      expect(entries[1]['kind'], 'link');
      final chunks = lines.where((e) => e['type'] == 'chunk').toList();
      expect(base64Decode(chunks.last['data'] as String), [0, 255, 128, 2, 4]);
      expect(await _hashes(source), original);
      final backup = result.backup;
      expect(backup.isStreamed, isTrue);
      expect(() => backup.bytes, throwsUnsupportedError);
      expect(
        await backup.openRead().fold<int>(0, (n, chunk) => n + chunk.length),
        result.byteLength,
      );
      final bytes = await result.file.readAsBytes();
      final footerLength = utf8.encode('${jsonEncode(lines.last)}\n').length;
      expect(
        sha256
            .convert(bytes.sublist(0, bytes.length - footerLength))
            .toString(),
        result.sha256Digest,
      );
    },
  );

  test(
    'large archive uses fixed chunks and never invokes whole-file API',
    () async {
      final large = File('${source.path}/large.bin');
      final handle = await large.open(mode: FileMode.writeOnly);
      final block = Uint8List.fromList(List.generate(65536, (i) => i % 251));
      for (var i = 0; i < 160; i++) {
        await handle.writeFrom(block);
      }
      await handle.close();
      final expected = (await sha256.bind(large.openRead()).single).toString();
      final result = await export();
      var bytes = 0;
      var chunks = 0;
      String? key;
      await for (final line
          in result.file
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        expect(line.length, lessThan(66 * 1024));
        final value = jsonDecode(line) as Map;
        if (value['type'] == 'entry') key = value['key'] as String;
        if (value['type'] == 'chunk' && key == 'large.bin') {
          final data = base64Decode(value['data'] as String);
          expect(
            data.length,
            lessThanOrEqualTo(LegacyRecoveryExport.chunkBytes),
          );
          bytes += data.length;
          chunks++;
        }
        if (value['type'] == 'end_entry' && key == 'large.bin') {
          expect(value['sha256'], expected);
        }
      }
      expect(chunks, greaterThan(200));
      expect(bytes, await large.length());
      expect(result.complete, isTrue);
      expect(
        (await LegacyRecoveryBackup.capture([
          LegacyRecoveryFiles(source, name: 'small'),
        ])).complete,
        isFalse,
      );
    },
  );

  for (final failure in LegacyRecoveryCapacityFailure.values) {
    test(
      'preflight $failure leaves destination and source untouched',
      () async {
        final original = await _hashes(source);
        await expectLater(
          export(
            options: _options(
              output,
              available: (_) async =>
                  failure == LegacyRecoveryCapacityFailure.unknown
                  ? null
                  : failure == LegacyRecoveryCapacityFailure.insufficient
                  ? 4096
                  : 1 << 40,
              maxOutputBytes:
                  failure == LegacyRecoveryCapacityFailure.outputLimit
                  ? 1
                  : 1 << 30,
            ),
          ),
          throwsA(
            isA<LegacyRecoveryCapacityException>().having(
              (e) => e.reason,
              'reason',
              failure,
            ),
          ),
        );
        expect(await output.list().toList(), isEmpty);
        expect(await _hashes(source), original);
      },
    );
  }

  test('capacity probe errors fail closed before writing', () async {
    await expectLater(
      export(
        options: _options(
          output,
          available: (_) async => throw StateError('private path'),
        ),
      ),
      throwsA(
        isA<LegacyRecoveryCapacityException>().having(
          (e) => e.reason,
          'reason',
          LegacyRecoveryCapacityFailure.unknown,
        ),
      ),
    );
    expect(await output.list().toList(), isEmpty);
  });

  test(
    'mid-export reserve loss retains pending bytes and retry uses a new file',
    () async {
      var probes = 0;
      final original = await _hashes(source);
      await expectLater(
        export(
          options: _options(
            output,
            available: (_) async => ++probes < 4 ? 1 << 40 : 4096,
          ),
        ),
        throwsA(isA<LegacyRecoveryCapacityException>()),
      );
      final prior = await _hashes(output);
      expect(prior.keys.single, endsWith('recovery.part'));
      expect(await (await _outputs(output)).single.length(), greaterThan(0));
      expect((await export()).complete, isTrue);
      final after = await _hashes(output);
      for (final entry in prior.entries) {
        expect(after[entry.key], entry.value);
      }
      expect(await _hashes(source), original);
    },
  );

  for (final boundary in [
    'export_preflight',
    'export_written',
    'export_source_copied',
    'export_flushed',
    'export_verified',
    'export_published',
  ]) {
    test(
      'cancellation at $boundary reports no success and preserves attempts',
      () async {
        final cancellation = LegacyRecoveryExportCancellation();
        final original = await _hashes(source);
        await expectLater(
          export(
            options: _options(
              output,
              cancellation: cancellation,
              onBoundary: (name) async {
                if (name == boundary) cancellation.cancel();
              },
            ),
          ),
          throwsA(isA<LegacyRecoveryCancelled>()),
        );
        final before = await _hashes(output);
        if (boundary == 'export_preflight') {
          expect(before, isEmpty);
        } else {
          expect(before, isNotEmpty);
        }
        expect((await export()).complete, isTrue);
        final after = await _hashes(output);
        for (final entry in before.entries) {
          expect(after[entry.key], entry.value);
        }
        expect(await _hashes(source), original);
      },
    );
  }

  test(
    'changed or unreadable sources yield explicitly partial exports',
    () async {
      for (final files in [_ChangingFiles(source), _FailingRead(source)]) {
        final result = await export(files: files);
        expect(result.complete, isFalse);
        expect(result.file.path, endsWith('recovery-partial.jsonl'));
        expect(result.problems, isNotEmpty);
        expect(result.problems.join(), isNot(contains('Private source')));
        expect((await _lines(result.file)).last['complete'], isFalse);
      }
    },
  );

  test(
    'changed inventory is incomplete, and copied original bytes survive',
    () async {
      final result = await export(
        options: _options(
          output,
          onBoundary: (boundary) async {
            if (boundary == 'export_source_copied') {
              await File('${source.path}/later').writeAsString('later');
            }
          },
        ),
      );
      expect(result.complete, isFalse);
      expect(result.problems.join(), contains('changed'));
      expect(
        (await _lines(
          result.file,
        )).where((e) => e['type'] == 'entry').map((e) => e['key']),
        ['opaque.bin'],
      );
    },
  );

  test('readback corruption is refused without publishing', () async {
    await expectLater(
      export(
        options: _options(
          output,
          onBoundary: (boundary) async {
            if (boundary == 'export_flushed') {
              final file = (await _outputs(output)).single;
              final handle = await file.open(mode: FileMode.append);
              await handle.setPosition(0);
              await handle.writeByte(0);
              await handle.close();
            }
          },
        ),
      ),
      throwsFormatException,
    );
    expect((await _outputs(output)).single.path, endsWith('recovery.part'));
  });

  test(
    'symlink and overlapping destinations fail without source mutation',
    () async {
      final original = await _hashes(source);
      await Link('${parent.path}/alias').create(output.path);
      for (final destination in [
        source,
        await Directory('${source.path}/nested').create(),
        Directory('${parent.path}/alias'),
      ]) {
        await expectLater(
          export(options: _options(destination)),
          throwsA(anyOf(isA<ArgumentError>(), isA<FormatException>())),
        );
      }
      expect(await _hashes(source), original);
      expect(await output.list().toList(), isEmpty);
    },
  );

  test(
    'metadata limits abort rather than truncate a complete inventory',
    () async {
      await expectLater(
        _StreamingOnlyFiles(source).boundedKeys(maxEntries: 0),
        throwsFormatException,
      );
      await expectLater(
        _StreamingOnlyFiles(source).boundedKeys(maxKeyBytes: 1),
        throwsFormatException,
      );
      expect(await output.list().toList(), isEmpty);
    },
  );

  for (final phase in ['write', 'flush']) {
    test(
      'actual pending $phase ENOSPC leaves source and prior export intact',
      () async {
        await export();
        final original = await _hashes(source);
        final prior = await _hashes(output);
        final outside = Zone.current;
        late FileSystemException failure;
        try {
          await IOOverrides.runZoned(
            () => export(),
            fseGetType: (path, followLinks) => outside.run(
              () => FileSystemEntity.type(path, followLinks: followLinks),
            ),
            createFile: (path) {
              final file = outside.run(() => File(path));
              return path.endsWith('/recovery.part')
                  ? _FailingFile(file, phase)
                  : file;
            },
          );
          fail('Expected actual kernel ENOSPC.');
        } on FileSystemException catch (error) {
          failure = error;
        }
        expect(failure.osError?.errorCode, 28);
        final after = await _hashes(output);
        for (final entry in prior.entries) {
          expect(after[entry.key], entry.value);
        }
        expect(after.length, prior.length + 1);
        expect(
          after.keys.where((e) => e.endsWith('recovery.part')),
          hasLength(1),
        );
        expect(await _hashes(source), original);
        expect((await export()).complete, isTrue);
      },
      skip: !Platform.isLinux,
    );
  }

  test(
    'combined archive export excludes lock inodes and holds both leases',
    () async {
      final archive = await LegacySourceArchive.createIn(parent);
      final coordinator = await LegacyMigrationCoordinator.createRehearsal();
      try {
        await File(
          '${archive.directory.path}/pending_unknown.part',
        ).writeAsBytes([0, 255]);
        await File(
          '${coordinator.directory.path}/opaque.backup',
        ).writeAsString('future data');
        final originalArchive = await _hashes(archive.directory);
        final originalRehearsal = await _hashes(coordinator.directory);
        final entered = Completer<void>();
        final release = Completer<void>();
        final first = coordinator.exportRecoveryBackup(
          sourceArchive: archive,
          options: _options(
            output,
            onBoundary: (boundary) async {
              if (boundary == 'export_source_copied' && !entered.isCompleted) {
                entered.complete();
                await release.future;
              }
            },
          ),
        );
        await entered.future;
        var secondFinished = false;
        final second = archive.createRecoveryBackup().then((value) {
          secondFinished = true;
          return value;
        });
        var coordinatorFinished = false;
        final coordinatorRead = coordinator.createRecoveryBackup().then((
          value,
        ) {
          coordinatorFinished = true;
          return value;
        });
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(secondFinished, isFalse);
        expect(coordinatorFinished, isFalse);
        release.complete();
        final result = await first;
        await second;
        await coordinatorRead;
        final lines = await _lines(result.file);
        expect(
          lines.where((e) => e['type'] == 'source').map((e) => e['name']),
          ['rehearsal_files_base64_v1', 'retained_source_files_base64_v1'],
        );
        final keys = lines
            .where((e) => e['type'] == 'entry')
            .map((e) => e['key']);
        expect(keys, containsAll(['pending_unknown.part', 'opaque.backup']));
        expect(keys, isNot(contains('archive.lock')));
        expect(keys, isNot(contains('coordinator.lock')));
        expect(await _hashes(archive.directory), originalArchive);
        expect(await _hashes(coordinator.directory), originalRehearsal);
        expect(result.complete, isTrue);
      } finally {
        await coordinator.directory.delete(recursive: true);
      }
    },
  );

  test(
    'hard-linked lock aliases preserve metadata without releasing the lease',
    () async {
      final archive = await LegacySourceArchive.createIn(parent);
      final lock = '${archive.directory.path}/archive.lock';
      final alias = '${archive.directory.path}/foreign-record';
      final linked = await Process.run('ln', [lock, alias]);
      expect(linked.exitCode, 0, reason: '${linked.stderr}');
      expect(await FileSystemEntity.identical(lock, alias), isTrue);
      final result = await archive.exportRecoveryBackup(
        options: _options(
          output,
          onBoundary: (boundary) async {
            if (boundary == 'export_source_copied') {
              final probe = await Process.run('python3', [
                '-c',
                'import fcntl,sys; f=open(sys.argv[1], "a")\ntry: fcntl.lockf(f, fcntl.LOCK_EX | fcntl.LOCK_NB)\nexcept BlockingIOError: sys.exit(0)\nsys.exit(3)',
                lock,
              ]);
              expect(
                probe.exitCode,
                0,
                reason: 'Export must retain its POSIX lease: ${probe.stderr}',
              );
            }
          },
        ),
      );
      expect(result.complete, isTrue);
      final lines = await _lines(result.file);
      final manifest = lines.singleWhere((e) => e['type'] == 'source');
      expect(manifest['excludedTopLevelLockFiles'], ['archive.lock']);
      final entry = lines.singleWhere(
        (e) => e['type'] == 'entry' && e['key'] == 'foreign-record',
      );
      expect(entry['kind'], 'coordination-alias');
      expect(entry['target'], 'archive.lock');
      expect(await FileSystemEntity.identical(lock, alias), isTrue);
    },
    skip: !Platform.isLinux,
  );

  test(
    'cross-store hard-link aliases cannot release either combined lease',
    () async {
      final archive = await LegacySourceArchive.createIn(parent);
      final coordinator = await LegacyMigrationCoordinator.createRehearsal();
      final archiveLock = '${archive.directory.path}/archive.lock';
      final coordinatorLock = '${coordinator.directory.path}/coordinator.lock';
      try {
        for (final pair in [
          [archiveLock, '${coordinator.directory.path}/foreign-archive-lock'],
          [
            coordinatorLock,
            '${archive.directory.path}/foreign-coordinator-lock',
          ],
        ]) {
          expect((await Process.run('ln', pair)).exitCode, 0);
        }
        final result = await coordinator.exportRecoveryBackup(
          sourceArchive: archive,
          options: _options(
            output,
            onBoundary: (boundary) async {
              if (boundary == 'export_source_copied') {
                for (final lock in [archiveLock, coordinatorLock]) {
                  final probe = await Process.run('python3', [
                    '-c',
                    'import fcntl,sys; f=open(sys.argv[1], "a")\ntry: fcntl.lockf(f, fcntl.LOCK_EX | fcntl.LOCK_NB)\nexcept BlockingIOError: sys.exit(0)\nsys.exit(3)',
                    lock,
                  ]);
                  expect(
                    probe.exitCode,
                    0,
                    reason: 'Both store leases must remain held.',
                  );
                }
              }
            },
          ),
        );
        expect(result.complete, isTrue);
        final lines = await _lines(result.file);
        expect(
          lines.where(
            (e) => e['type'] == 'entry' && e['kind'] == 'coordination-alias',
          ),
          hasLength(2),
        );
        final small = await coordinator.createRecoveryBackup(
          sourceArchive: archive,
        );
        expect(small.complete, isTrue);
        expect(utf8.decode(small.bytes), contains('coordination-alias'));
      } finally {
        await coordinator.directory.delete(recursive: true);
      }
    },
    skip: !Platform.isLinux,
  );

  test(
    'legacy in-memory backup fails before aggregate serialization exceeds its bound',
    () async {
      await expectLater(
        LegacyRecoveryBackup.capture([_Strings()]),
        throwsA(
          isA<LegacyRecoveryCapacityException>().having(
            (e) => e.reason,
            'reason',
            LegacyRecoveryCapacityFailure.outputLimit,
          ),
        ),
      );
    },
  );

  test(
    'abrupt process exit keeps attempts, releases lease and permits new export',
    () async {
      final archive = await LegacySourceArchive.createIn(parent);
      await File(
        '${archive.directory.path}/unknown.part',
      ).writeAsBytes([255, 0, 1]);
      final original = await _hashes(archive.directory);
      for (final boundary in [
        'export_written',
        'export_flushed',
        'export_published',
      ]) {
        final result = await Process.run(
          '${Platform.environment['FLUTTER_ROOT']!}/bin/flutter',
          [
            'test',
            '--no-pub',
            '--reporter',
            'expanded',
            'test/legacy_recovery_export_test.dart',
            '--plain-name',
            'export subprocess worker',
          ],
          environment: {
            'TRIPLING_EXPORT_WORKER': archive.directory.path,
            'TRIPLING_EXPORT_OUTPUT': output.path,
            'TRIPLING_EXPORT_BOUNDARY': boundary,
            'BOT': 'true',
            'CI': 'true',
          },
        );
        expect(
          result.exitCode,
          isNot(0),
          reason: '${result.stdout} ${result.stderr}',
        );
        expect(
          await File('${parent.path}/worker-reached').readAsString(),
          boundary,
        );
        final before = await _hashes(output);
        expect(
          (await archive.exportRecoveryBackup(
            options: _options(output),
          )).complete,
          isTrue,
        );
        final after = await _hashes(output);
        for (final entry in before.entries) {
          expect(after[entry.key], entry.value);
        }
        expect(await _hashes(archive.directory), original);
      }
    },
    skip: !Platform.isLinux || Platform.environment['FLUTTER_ROOT'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'controller distinguishes cancellation and capacity failures without leaking paths',
    () async {
      final cases = <Exception, String>{
        const LegacyRecoveryCancelled(): 'cancelled',
        const LegacyRecoveryCapacityException(
          LegacyRecoveryCapacityFailure.unknown,
        ): 'could not be verified',
        const LegacyRecoveryCapacityException(
          LegacyRecoveryCapacityFailure.insufficient,
        ): 'safety reserve',
        const LegacyRecoveryCapacityException(
          LegacyRecoveryCapacityFailure.outputLimit,
        ): 'size limit',
      };
      for (final entry in cases.entries) {
        final controller = LegacyRecoveryController(
          _ThrowingActions(entry.key),
        );
        var called = false;
        await controller.saveBackup((_) async {
          called = true;
          return true;
        });
        expect(called, isFalse);
        expect(controller.busy, isFalse);
        expect(controller.actionMessage, contains(entry.value));
        controller.dispose();
      }
    },
  );
}
