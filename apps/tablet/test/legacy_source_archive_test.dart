import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:doubling_season/models/item.dart';
import 'package:doubling_season/models/token_counter.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_journal.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';
import 'package:tripling_table/migration/legacy_source_archive.dart';
import 'package:tripling_table/migration/legacy_source_reader.dart';

final _date = DateTime.utc(2026, 11, 10);
LegacySourceLayout _layout({String id = 'offline-fixture'}) =>
    LegacySourceLayout(
      sourceId: id,
      sourceVersion: 'repository fixture, not a shipped installation',
      copyEvidence: 'Private fixture Hive writers closed before capture.',
      capturedAt: _date,
      boxes: {
        for (final name in LegacyMigrationSnapshot.collections)
          name: name == 'items' ? 'items.hive' : null,
      },
      preferencesPath: 'preferences.xml',
      preferencesFormat: LegacyPreferencesFormat.androidXml,
      mediaPaths: const {'file:///original/art.png': 'art.png'},
    );

Future<void> _fixture(Directory source) async {
  final hive = HiveImpl()
    ..init(source.path)
    ..registerAdapter(ItemAdapter())
    ..registerAdapter(TokenCounterAdapter())
    ..registerAdapter(ArtworkVariantAdapter());
  final box = await hive.openBox<Item>('items');
  await box.put(
    'surviving',
    Item(name: 'Goblin', pt: '1/1', amount: 9, tapped: 3, createdAt: _date),
  );
  await hive.close();
  await File('${source.path}/preferences.xml').writeAsString(
    '<map><string name="flutter.unknown">keep this</string></map>',
    flush: true,
  );
  await File('${source.path}/art.png').writeAsBytes([1, 2, 3], flush: true);
  await File('${source.path}/unknown.backup').writeAsBytes([9, 8], flush: true);
}

Future<Map<String, String>> _hashes(Directory directory) async => {
  await for (final entry in directory.list(recursive: true, followLinks: false))
    if (entry is File)
      entry.path: sha256.convert(await entry.readAsBytes()).toString(),
};

class _Memory extends LegacyMigrationStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> flush() async {}
}

// Fault wrappers keep ordinary filesystem reads/writes real, but make the
// actual pending-record write/flush await fail with kernel ENOSPC. No production
// test writer or filesystem substitution is needed in the archive API.
class _FailingPendingFile implements File {
  final File file;
  final String phase;
  _FailingPendingFile(this.file, this.phase);
  @override
  String get path => file.path;
  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) =>
      file.create(recursive: recursive, exclusive: exclusive);
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      _FailingPendingHandle(await file.open(mode: mode), phase);
  @override
  Future<int> length() => file.length();
  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();
  @override
  Future<File> rename(String path) => file.rename(path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingPendingHandle implements RandomAccessFile {
  final RandomAccessFile file;
  final String phase;
  bool fail = false;
  _FailingPendingHandle(this.file, this.phase);
  Future<void> _enospc() async {
    final sink = await File('/dev/full').open(mode: FileMode.writeOnly);
    try {
      await sink.writeByte(1);
    } finally {
      await sink.close();
    }
  }

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) async {
    final record = jsonDecode(utf8.decode(buffer.sublist(start, end))) as Map;
    fail = record['key'] == LegacySourceReader.inventoryKey;
    if (fail && phase == 'write') {
      await file.writeFrom(buffer, start, start + 17);
      await _enospc();
    }
    await file.writeFrom(buffer, start, end);
    return this;
  }

  @override
  Future<RandomAccessFile> flush() async {
    if (fail && phase == 'flush') await _enospc();
    await file.flush();
    return this;
  }

  @override
  Future<void> close() => file.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final workerArchive = Platform.environment['TRIPLING_ARCHIVE_WORKER'];
  if (workerArchive != null) {
    test('archive subprocess worker', () async {
      final archive = await LegacySourceArchive.reopen(
        Directory(workerArchive),
      );
      await archive.captureCopiedDirectory(
        source: Directory(Platform.environment['TRIPLING_ARCHIVE_SOURCE']!),
        layout: _layout(),
        onBoundary: (boundary) async {
          if (boundary == Platform.environment['TRIPLING_ARCHIVE_BOUNDARY']) {
            await File(
              '${archive.directory.parent.path}/worker-reached',
            ).writeAsString(boundary, flush: true);
            // Abrupt Flutter tester process exit: no Dart finally/close handlers.
            exit(73);
          }
        },
      );
      fail('Requested process-exit boundary was not reached.');
    });
    return;
  }
  late Directory parent;
  late Directory source;
  late LegacySourceArchive archive;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('archive-test-');
    source = await Directory('${parent.path}/offline-copy').create();
    await _fixture(source);
    archive = await LegacySourceArchive.createIn(parent);
  });
  tearDown(() async => parent.delete(recursive: true));

  test(
    'retains real Hive, all raw files and media across close/reopen',
    () async {
      final original = await _hashes(source);
      final result = await archive.captureCopiedDirectory(
        source: source,
        layout: _layout(),
      );
      expect(await _hashes(source), original);
      final values = result.snapshot.toJson();
      expect(values['collections']['items'][0]['value']['amount'], 9);
      expect(values['collections']['items'][0]['value']['tapped'], 3);
      expect(values['preferences']['unknown'], 'keep this');
      expect(result.localMedia['file:///original/art.png'], [1, 2, 3]);
      expect(
        values['acquisition']['inventory']['files'],
        contains('unknown.backup'),
      );
      await source.rename('${source.path}-unavailable');
      final reopened = await LegacySourceArchive.reopen(archive.directory);
      final recovered = await reopened.openRetained(layout: _layout());
      expect(recovered!.snapshot.digest, result.snapshot.digest);
      expect(recovered.localMedia, result.localMedia);
      final repeated = await reopened.captureCopiedDirectory(
        source: source,
        layout: _layout(),
      );
      expect(repeated.snapshot.digest, result.snapshot.digest);
      final journal = LegacyMigrationJournal(_Memory());
      final prepared = await recovered.prepare(journal);
      expect(prepared.blockers, isEmpty);
    },
  );

  test(
    'all write, flush, verify, publication and decode boundaries resume',
    () async {
      final original = await _hashes(source);
      final boundaries = <String>[];
      await archive.captureCopiedDirectory(
        source: source,
        layout: _layout(),
        onBoundary: (boundary) async => boundaries.add(boundary),
      );
      expect(boundaries.where((b) => b.startsWith('archive_')), isNotEmpty);
      for (final boundary in boundaries) {
        final attempt = await LegacySourceArchive.createIn(parent);
        await expectLater(
          attempt.captureCopiedDirectory(
            source: source,
            layout: _layout(),
            onBoundary: (value) async {
              if (value == boundary) throw StateError('Interrupted at $value');
            },
          ),
          throwsStateError,
          reason: boundary,
        );
        final preserved = await _hashes(attempt.directory);
        final restarted = await LegacySourceArchive.reopen(attempt.directory);
        final result = await restarted.captureCopiedDirectory(
          source: source,
          layout: _layout(),
        );
        expect(result.snapshot.toJson()['collections']['items'], hasLength(1));
        final after = await _hashes(attempt.directory);
        for (final entry in preserved.entries) {
          expect(
            after[entry.key],
            entry.value,
            reason: '$boundary ${entry.key}',
          );
        }
        expect(await _hashes(source), original, reason: boundary);
      }
    },
  );

  test(
    'partial file never becomes authority and is retained on retry',
    () async {
      await expectLater(
        archive.captureCopiedDirectory(
          source: source,
          layout: _layout(),
          onBoundary: (boundary) async {
            if (boundary.startsWith('archive_before_write:raw_file_')) {
              final pending = (await archive.directory.list().toList())
                  .whereType<File>()
                  .singleWhere((f) => f.path.endsWith('.part'));
              await pending.writeAsString('{"partial":', flush: true);
              throw const FileSystemException(
                'No space',
                '',
                OSError('ENOSPC', 28),
              );
            }
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await archive.openRetained(layout: _layout()), isNull);
      final before = await _hashes(archive.directory);
      await archive.captureCopiedDirectory(source: source, layout: _layout());
      final after = await _hashes(archive.directory);
      for (final entry in before.entries) {
        expect(after[entry.key], entry.value);
      }
    },
  );

  test(
    'kernel ENOSPC at each write boundary fails closed and retries',
    () async {
      final original = await _hashes(source);
      for (final point in ['before_write', 'written', 'flushed', 'verified']) {
        final attempt = await LegacySourceArchive.createIn(parent);
        await expectLater(
          attempt.captureCopiedDirectory(
            source: source,
            layout: _layout(),
            onBoundary: (boundary) async {
              if (boundary ==
                  'archive_$point:${LegacySourceReader.inventoryKey}') {
                // /dev/full generates actual kernel ENOSPC without filling a
                // shared volume. Fault enters the production boundary hook;
                // this is not physical exhaustion of the destination device.
                final sink = await File(
                  '/dev/full',
                ).open(mode: FileMode.writeOnly);
                try {
                  await sink.writeByte(1);
                } finally {
                  await sink.close();
                }
              }
            },
          ),
          throwsA(
            isA<FileSystemException>().having(
              (e) => e.osError?.errorCode,
              'kernel error',
              28,
            ),
          ),
        );
        expect(await attempt.openRetained(layout: _layout()), isNull);
        final retained = await _hashes(attempt.directory);
        await attempt.captureCopiedDirectory(source: source, layout: _layout());
        final after = await _hashes(attempt.directory);
        for (final entry in retained.entries) {
          expect(after[entry.key], entry.value);
        }
        expect(await _hashes(source), original);
      }
    },
    skip: !Platform.isLinux,
  );

  test(
    'actual archive write and flush awaits fail closed on injected ENOSPC',
    () async {
      final original = await _hashes(source);
      final outside = Zone.current;
      for (final phase in ['write', 'flush']) {
        final attempt = await LegacySourceArchive.createIn(parent);
        await expectLater(
          IOOverrides.runZoned(
            () => attempt.captureCopiedDirectory(
              source: source,
              layout: _layout(),
            ),
            fseGetType: (path, followLinks) => outside.run(
              () => FileSystemEntity.type(path, followLinks: followLinks),
            ),
            createFile: (path) {
              final real = outside.run(() => File(path));
              return path.endsWith('.part')
                  ? _FailingPendingFile(real, phase)
                  : real;
            },
          ),
          throwsA(
            isA<FileSystemException>().having(
              (e) => e.osError?.errorCode,
              'kernel error',
              28,
            ),
          ),
        );
        expect(await attempt.openRetained(layout: _layout()), isNull);
        final before = await _hashes(attempt.directory);
        await attempt.captureCopiedDirectory(source: source, layout: _layout());
        final after = await _hashes(attempt.directory);
        for (final entry in before.entries) {
          expect(after[entry.key], entry.value);
        }
        expect(await _hashes(source), original);
      }
    },
    skip: !Platform.isLinux,
  );

  test('different source layout is refused without any overwrite', () async {
    await archive.captureCopiedDirectory(source: source, layout: _layout());
    final before = await _hashes(archive.directory);
    await expectLater(
      archive.captureCopiedDirectory(
        source: source,
        layout: _layout(id: 'other'),
      ),
      throwsFormatException,
    );
    await expectLater(
      archive.openRetained(layout: _layout(id: 'other')),
      throwsFormatException,
    );
    expect(await _hashes(archive.directory), before);
  });

  test(
    'corrupt retained record blocks reopen and prepare without repair',
    () async {
      final result = await archive.captureCopiedDirectory(
        source: source,
        layout: _layout(),
      );
      final records = await archive.directory.list().toList();
      final record = records.whereType<File>().firstWhere(
        (f) => f.path.contains('/raw_file_'),
      );
      await record.writeAsString('{"truncated":', flush: true);
      final before = await _hashes(archive.directory);
      await expectLater(
        archive.openRetained(layout: _layout()),
        throwsFormatException,
      );
      await expectLater(
        result.prepare(LegacyMigrationJournal(_Memory())),
        throwsFormatException,
      );
      expect(await _hashes(archive.directory), before);
    },
  );

  test(
    'an unreadable source remains wholly retained without source repair',
    () async {
      await File(
        '${source.path}/items.hive',
      ).writeAsBytes([1, 2, 3], flush: true);
      final original = await _hashes(source);
      await expectLater(
        archive.captureCopiedDirectory(source: source, layout: _layout()),
        throwsFormatException,
      );
      final inventory =
          jsonDecode(
                await File(
                  '${archive.directory.path}/${LegacySourceReader.inventoryKey}.record',
                ).readAsString(),
              )
              as Map;
      final value = jsonDecode(inventory['value'] as String) as Map;
      expect((value['files'] as Map).length, original.length);
      for (final hash in original.values) {
        expect(
          await File(
            '${archive.directory.path}/raw_file_$hash.record',
          ).exists(),
          isTrue,
        );
      }
      expect(await _hashes(source), original);
      await expectLater(
        archive.openRetained(layout: _layout()),
        throwsFormatException,
      );
    },
  );

  test(
    'valid JSON corruption and wrong envelope identity are rejected',
    () async {
      for (final field in ['sha256', 'length', 'key', 'version']) {
        final attempt = await LegacySourceArchive.createIn(parent);
        await attempt.captureCopiedDirectory(source: source, layout: _layout());
        final file = File(
          '${attempt.directory.path}/${LegacySourceReader.inventoryKey}.record',
        );
        final record = jsonDecode(await file.readAsString()) as Map;
        record[field] = 'wrong';
        await file.writeAsString(jsonEncode(record), flush: true);
        await expectLater(
          attempt.openRetained(layout: _layout()),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'unknown files, marker damage and aliases are refused and kept',
    () async {
      final extra = File('${archive.directory.path}/unknown.file');
      await extra.writeAsString('preserve');
      await expectLater(
        archive.openRetained(layout: _layout()),
        throwsStateError,
      );
      expect(await extra.readAsString(), 'preserve');
      final target = await LegacySourceArchive.createIn(parent);
      final link = Link('${parent.path}/alias');
      await link.create(target.directory.path);
      await expectLater(
        LegacySourceArchive.reopen(Directory(link.path)),
        throwsStateError,
      );
      final marker = File('${target.directory.path}/archive.txt');
      await marker.writeAsString('unknown version', flush: true);
      await expectLater(
        LegacySourceArchive.reopen(target.directory),
        throwsStateError,
      );
      expect(await marker.readAsString(), 'unknown version');
    },
  );

  test(
    'record, pending and lock symlinks never follow their targets',
    () async {
      final external = File('${parent.path}/do-not-touch');
      await external.writeAsString('keep');
      for (final name in [
        'capture_layout_v1.record',
        'pending_00000000-0000-4000-8000-000000000000.part',
        'archive.lock',
      ]) {
        final attempt = await LegacySourceArchive.createIn(parent);
        final path = '${attempt.directory.path}/$name';
        if (await File(path).exists()) await File(path).delete();
        await Link(path).create(external.path);
        await expectLater(
          attempt.openRetained(layout: _layout()),
          throwsStateError,
        );
        expect(await external.readAsString(), 'keep');
      }
    },
  );

  test('overlapping source and destination never get captured', () async {
    for (final location in [
      archive.directory,
      parent,
      Directory(archive.directory.absolute.uri.resolve("/").toFilePath()),
    ]) {
      final before = await _hashes(archive.directory);
      await expectLater(
        archive.captureCopiedDirectory(source: location, layout: _layout()),
        throwsStateError,
      );
      expect(await _hashes(archive.directory), before);
    }
  });

  test('same-process callers serialize across archive instances', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = archive.captureCopiedDirectory(
      source: source,
      layout: _layout(),
      onBoundary: (boundary) async {
        if (boundary == 'copied') {
          entered.complete();
          await release.future;
        }
      },
    );
    await entered.future;
    var secondFinished = false;
    final second = (await LegacySourceArchive.reopen(archive.directory))
        .openRetained(layout: _layout())
        .then((value) {
          secondFinished = true;
          return value;
        });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(secondFinished, isFalse);
    release.complete();
    expect((await second)!.snapshot.digest, (await first).snapshot.digest);
  });

  test(
    'an interrupted capture refuses changed, added or removed source files',
    () async {
      for (final change in ['changed', 'added', 'removed']) {
        final copy = await Directory('${parent.path}/source-$change').create();
        await _fixture(copy);
        final attempt = await LegacySourceArchive.createIn(parent);
        await expectLater(
          attempt.captureCopiedDirectory(
            source: copy,
            layout: _layout(),
            onBoundary: (boundary) async {
              if (boundary.startsWith('retained:')) {
                throw StateError('Interrupted');
              }
            },
          ),
          throwsStateError,
        );
        final before = await _hashes(attempt.directory);
        if (change == 'added') {
          await File(
            '${copy.path}/added.txt',
          ).writeAsString('new', flush: true);
        } else if (change == 'removed') {
          await File('${copy.path}/unknown.backup').delete();
        } else {
          await File(
            '${copy.path}/preferences.xml',
          ).writeAsString('<map/>', flush: true);
        }
        await expectLater(
          attempt.captureCopiedDirectory(source: copy, layout: _layout()),
          throwsFormatException,
        );
        expect(await _hashes(attempt.directory), before);
        expect(await attempt.openRetained(layout: _layout()), isNull);
      }
    },
  );

  test(
    'retained inventory requires the original immutable capture intent',
    () async {
      final acquired = await archive.captureCopiedDirectory(
        source: source,
        layout: _layout(),
      );
      await File(
        '${archive.directory.path}/${LegacySourceReader.captureIntentKey}.record',
      ).rename('${parent.path}/saved-intent');
      await expectLater(
        archive.openRetained(layout: _layout()),
        throwsFormatException,
      );
      await expectLater(
        acquired.prepare(LegacyMigrationJournal(_Memory())),
        throwsFormatException,
      );
    },
  );

  test(
    'cross-process lease excludes capture and survives holder exit',
    () async {
      final process = await Process.start('python3', [
        '-u',
        '-c',
        'import fcntl,sys; f=open(sys.argv[1], "a"); fcntl.lockf(f, fcntl.LOCK_EX); print("ready", flush=True); sys.stdin.readline()',
        '${archive.directory.path}/archive.lock',
      ]);
      final ready = Completer<void>();
      final output = process.stdout.transform(utf8.decoder).listen((text) {
        if (text.contains('ready') && !ready.isCompleted) ready.complete();
      });
      final errors = process.stderr.drain<void>();
      try {
        await ready.future.timeout(const Duration(seconds: 10));
        await expectLater(
          archive.captureCopiedDirectory(source: source, layout: _layout()),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        process.kill();
        await process.exitCode;
        await output.cancel();
        await errors;
      }
      final result = await archive.captureCopiedDirectory(
        source: source,
        layout: _layout(),
      );
      expect(result.snapshot.toJson()['collections']['items'], hasLength(1));
    },
    skip: !Platform.isLinux,
  );

  test(
    'abrupt writer process exits retain evidence and resume on disk',
    () async {
      final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
      final original = await _hashes(source);
      for (final boundary in [
        'archive_written:${LegacySourceReader.captureIntentKey}',
        'archive_written:${LegacySourceReader.inventoryKey}',
        'archive_published:${LegacySourceReader.inventoryKey}',
      ]) {
        final attempt = await LegacySourceArchive.createIn(parent);
        final result = await Process.run(
          '$flutterRoot/bin/flutter',
          [
            'test',
            '--no-pub',
            '--reporter',
            'expanded',
            'test/legacy_source_archive_test.dart',
            '--plain-name',
            'archive subprocess worker',
          ],
          environment: {
            'TRIPLING_ARCHIVE_WORKER': attempt.directory.path,
            'TRIPLING_ARCHIVE_SOURCE': source.path,
            'TRIPLING_ARCHIVE_BOUNDARY': boundary,
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
        final before = await _hashes(attempt.directory);
        final reopened = await LegacySourceArchive.reopen(attempt.directory);
        final acquired = await reopened.captureCopiedDirectory(
          source: source,
          layout: _layout(),
        );
        expect(
          acquired.snapshot.toJson()['collections']['items'],
          hasLength(1),
        );
        final after = await _hashes(attempt.directory);
        for (final entry in before.entries) {
          expect(after[entry.key], entry.value);
        }
        expect(await _hashes(source), original);
      }
    },
    skip: !Platform.isLinux || Platform.environment['FLUTTER_ROOT'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('non-root isolate cannot bypass the process-local lease', () async {
    final path = archive.directory.path;
    final refused = await Isolate.run(() async {
      try {
        await LegacySourceArchive.reopen(Directory(path));
        return false;
      } on StateError {
        return true;
      }
    });
    expect(refused, isTrue);
  });
}
