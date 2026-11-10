import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:doubling_season/models/item.dart';
import 'package:doubling_season/models/token_counter.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_coordinator.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';
import 'package:tripling_table/migration/legacy_source_reader.dart';
import 'package:tripling_table/migration/legacy_source_archive.dart';
import 'package:tripling_table/migration/legacy_migration_recovery.dart';
import 'package:tripling_table/migration/legacy_recovery_export.dart';
import 'package:tripling_table/migration/legacy_rehearsal_recovery_actions.dart';
import 'package:tripling_table/services/tablet_media_store.dart';
import 'package:tripling_table/storage/storage_namespace.dart';
import 'package:tripling_table/storage/table_repository.dart';

const _art = 'file:///original/token.png';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP476DwHwAGAAJfNM1AwAAAAABJRU5ErkJggg==',
);
final _date = DateTime.utc(2026, 11, 10);
LegacySourceLayout _layout({String id = 'offline-copy'}) => LegacySourceLayout(
  sourceId: id,
  sourceVersion: 'repository fixture',
  copyEvidence:
      'All private fixture Hive writers closed before capture. No concurrent writers.',
  capturedAt: _date,
  boxes: {
    for (final name in LegacyMigrationSnapshot.collections)
      name: name == 'items' ? 'items.hive' : null,
  },
  preferencesPath: 'prefs.xml',
  preferencesFormat: LegacyPreferencesFormat.androidXml,
  mediaPaths: {_art: 'token.png'},
);

Future<void> _fixture(
  Directory source, {
  String preferences = '<map/>',
  bool media = true,
  bool invalidImage = false,
}) async {
  final hive = HiveImpl()
    ..init(source.path)
    ..registerAdapter(ItemAdapter())
    ..registerAdapter(TokenCounterAdapter())
    ..registerAdapter(ArtworkVariantAdapter());
  final items = await hive.openBox<Item>('items');
  await items.put(
    7,
    Item(
      name: 'Goblin',
      pt: '1/1',
      amount: 12,
      tapped: 4,
      summoningSick: 2,
      createdAt: _date,
      artworkUrl: _art,
      counters: [TokenCounter(name: 'shield', amount: 3)],
    ),
  );
  await hive.close();
  await File(
    '${source.path}/prefs.xml',
  ).writeAsString(preferences, flush: true);
  if (media) {
    await File(
      '${source.path}/token.png',
    ).writeAsBytes(invalidImage ? [1, 2, 3] : _png, flush: true);
  }
  await File(
    '${source.path}/retained-unknown.txt',
  ).writeAsString('Never discard me', flush: true);
}

Future<Map<String, String>> _hashes(Directory dir) async => {
  await for (final file in dir.list(recursive: true))
    if (file is File)
      file.path: sha256.convert(await file.readAsBytes()).toString(),
};

Future<T> _destination<T>(
  LegacyMigrationCoordinator coordinator,
  Future<T> Function(HiveImpl hive) action,
) async {
  final hive = HiveImpl()..init(coordinator.directory.path);
  try {
    return await action(hive);
  } finally {
    await hive.close();
  }
}

Future<String?> _current(LegacyMigrationCoordinator coordinator) =>
    _destination(
      coordinator,
      (hive) async => (await hive.openBox<String>(
        TableStorageKeys.aggregate,
        crashRecovery: false,
      )).get('current'),
    );

// Independent fixture consumer: validate the exact stream trailer and every
// file's framing/digest, then compare physical bytes rather than decoded records.
Future<Map<String, Map<String, List<int>>>> _streamFiles(File file) async {
  final bytes = await file.readAsBytes();
  final lines = const LineSplitter().convert(utf8.decode(bytes));
  final records = lines.map((line) => jsonDecode(line) as Map).toList();
  expect(records.first['format'], LegacyRecoveryExport.format);
  expect(records.first['version'], 2);
  final trailerBytes = utf8.encode('${lines.last}\n');
  expect(records.last['type'], 'checksum');
  expect(
    records.last['sha256'],
    sha256
        .convert(bytes.sublist(0, bytes.length - trailerBytes.length))
        .toString(),
  );
  final result = <String, Map<String, List<int>>>{};
  Map<String, List<int>>? source;
  Map? entry;
  var chunks = <int>[];
  for (final record in records) {
    switch (record['type']) {
      case 'source':
        source = result[record['name'] as String] = {};
      case 'entry':
        entry = record;
        chunks = [];
      case 'chunk':
        final chunk = base64Decode(record['data'] as String);
        expect(
          chunk.length,
          lessThanOrEqualTo(LegacyRecoveryExport.chunkBytes),
        );
        chunks.addAll(chunk);
      case 'end_entry':
        expect(record['readable'], isTrue);
        expect(record['bytes'], chunks.length);
        expect(record['sha256'], sha256.convert(chunks).toString());
        if (entry!['kind'] == 'file') {
          expect(entry['length'], chunks.length);
          source![entry['key'] as String] = chunks;
        }
    }
  }
  expect(
    records.singleWhere((r) => r['type'] == 'summary')['entries'],
    records.where((r) => r['type'] == 'entry').length,
  );
  return result;
}

Future<Map<String, List<int>>> _physicalFiles(Directory directory) async => {
  await for (final file in directory.list(recursive: true, followLinks: false))
    if (file is File &&
        !{
          'archive.lock',
          'coordinator.lock',
        }.contains(file.path.substring(directory.path.length + 1)))
      file.path.substring(directory.path.length + 1): await file.readAsBytes(),
};

Future<List<File>> _exportFiles(Directory directory) async => [
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  ))
    if (entity is File) entity,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;
  late Directory source;
  late LegacySourceArchive archive;
  late LegacyMigrationCoordinator coordinator;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('archive-integration-');
    source = await Directory('${parent.path}/source').create();
    await _fixture(source);
    archive = await LegacySourceArchive.createIn(parent);
    coordinator = await LegacyMigrationCoordinator.createRehearsal();
  });
  tearDown(() async {
    await Hive.close();
    await parent.delete(recursive: true);
    await coordinator.directory.delete(recursive: true);
  });

  Future<void> capture() =>
      archive.captureCopiedDirectory(source: source, layout: _layout());

  LegacyRehearsalRecoveryActions streamedActions(
    Directory output, {
    Future<int?> Function(Directory)? available,
    Future<void> Function(String)? onBoundary,
  }) => LegacyRehearsalRecoveryActions(
    coordinator: coordinator,
    sourceArchive: archive,
    layout: _layout(),
    exportOptions: LegacyRecoveryExportOptions(
      parent: output,
      budget: LegacyRecoveryExportBudget(
        availableBytes: available ?? (_) async => 1 << 40,
        reserveBytes: 4096,
      ),
      onBoundary: onBoundary,
    ),
  );

  for (final stage in ['interrupted', 'promoted', 'corrupt']) {
    test(
      'controller streams exact $stage archive and rehearsal evidence',
      () async {
        await capture();
        if (stage == 'interrupted') {
          await expectLater(
            coordinator.rehearse(
              sourceArchive: archive,
              layout: _layout(),
              onBoundary: (boundary) async {
                if (boundary == 'staged') throw StateError('Interrupted');
              },
            ),
            throwsStateError,
          );
        } else {
          await coordinator.rehearse(sourceArchive: archive, layout: _layout());
          await _destination(coordinator, (hive) async {
            final repo = TableRepository.forTesting(
              openBox: (name) => hive.openBox<String>(name),
            );
            final state = (await repo.open()).state;
            state.session.players.first.life = 13;
            state.session.players.first.tokens.single.amount = 27;
            await repo.save(state);
          });
        }
        if (stage == 'corrupt') {
          await File(
            '${archive.directory.path}/capture_layout_v1.record',
          ).writeAsBytes([0, 255, 128]);
          await File(
            '${archive.directory.path}/pending_unknown.part',
          ).writeAsString('Opaque pending evidence');
        }
        final output = await Directory('${parent.path}/exports').create();
        final actions = streamedActions(output);
        final controller = LegacyRecoveryController(actions);
        addTearDown(controller.dispose);
        await controller.inspect();
        expect(controller.report!.phase, switch (stage) {
          'interrupted' => LegacyRecoveryPhase.ready,
          'corrupt' => LegacyRecoveryPhase.blocked,
          _ => LegacyRecoveryPhase.completed,
        });
        final priorReport = controller.report;
        final sourceBefore = await _hashes(source);
        final archiveBefore = await _hashes(archive.directory);
        final rehearsalBefore = await _hashes(coordinator.directory);
        final currentBefore = await _current(coordinator);
        // Close the repository before comparing/exporting physical Hive bytes.
        final rehearsalAfterRead = await _hashes(coordinator.directory);
        expect(rehearsalAfterRead, rehearsalBefore);
        final saved = File('${parent.path}/user-selected-recovery.jsonl');
        await controller.saveBackup((backup) async {
          expect(backup.isStreamed, isTrue);
          expect(
            backup.complete,
            isTrue,
          ); // Complete physical evidence, not approval.
          expect(() => backup.bytes, throwsUnsupportedError);
          final sink = saved.openWrite();
          await sink.addStream(backup.openRead());
          await sink.flush();
          await sink.close();
          expect(await saved.length(), backup.byteLength);
          return true;
        });
        expect(controller.actionMessage, startsWith('Recovery copy saved'));
        expect(controller.report, same(priorReport));
        final files = await _streamFiles(saved);
        expect(
          files.keys,
          unorderedEquals([
            'rehearsal_files_base64_v1',
            'retained_source_files_base64_v1',
          ]),
        );
        expect(
          files['rehearsal_files_base64_v1'],
          await _physicalFiles(coordinator.directory),
        );
        expect(
          files['retained_source_files_base64_v1'],
          await _physicalFiles(archive.directory),
        );
        expect(await _hashes(source), sourceBefore);
        expect(await _hashes(archive.directory), archiveBefore);
        expect(await _hashes(coordinator.directory), rehearsalBefore);
        expect(await _current(coordinator), currentBefore);
        expect(await _exportFiles(output), hasLength(1));
      },
    );
  }

  test(
    'capacity loss keeps the pending export and retry preserves both stores',
    () async {
      await capture();
      await coordinator.rehearse(sourceArchive: archive, layout: _layout());
      final sourceBefore = await _hashes(source);
      final archiveBefore = await _hashes(archive.directory);
      final rehearsalBefore = await _hashes(coordinator.directory);
      final output = await Directory('${parent.path}/exports').create();
      var capacity = 1 << 40;
      var inject = true;
      final controller = LegacyRecoveryController(
        streamedActions(
          output,
          available: (_) async => capacity,
          onBoundary: (boundary) async {
            if (inject && boundary == 'export_written') capacity = 0;
          },
        ),
      );
      addTearDown(controller.dispose);
      var delivered = false;
      await controller.saveBackup((_) async => delivered = true);
      expect(delivered, isFalse);
      expect(controller.actionMessage, startsWith('Not enough storage'));
      expect(controller.busy, isFalse);
      final pending = (await _exportFiles(output)).single;
      expect(pending.path, endsWith('recovery.part'));
      final pendingBefore = await pending.readAsBytes();
      expect(pendingBefore, isNotEmpty);
      inject = false;
      capacity = 1 << 40;
      await controller.saveBackup((backup) async {
        delivered = true;
        expect(
          await backup.openRead().fold<int>(0, (n, b) => n + b.length),
          backup.byteLength,
        );
        return true;
      });
      expect(delivered, isTrue);
      expect(controller.actionMessage, startsWith('Recovery copy saved'));
      expect(await _exportFiles(output), hasLength(2));
      expect(await pending.readAsBytes(), pendingBefore);
      expect(await _hashes(source), sourceBefore);
      expect(await _hashes(archive.directory), archiveBefore);
      expect(await _hashes(coordinator.directory), rehearsalBefore);
    },
  );

  for (final hostThrows in [false, true]) {
    test(
      'host ${hostThrows ? 'failure' : 'cancellation'} retains verified export for a new retry',
      () async {
        await capture();
        final output = await Directory('${parent.path}/exports').create();
        final controller = LegacyRecoveryController(streamedActions(output));
        addTearDown(controller.dispose);
        await controller.inspect();
        final priorReport = controller.report;
        final archiveBefore = await _hashes(archive.directory);
        final rehearsalBefore = await _hashes(coordinator.directory);
        await controller.saveBackup((backup) async {
          expect(backup.complete, isTrue);
          if (hostThrows)
            throw const FileSystemException('Private host failure');
          return false;
        });
        expect(
          controller.actionMessage,
          startsWith(
            hostThrows
                ? 'Recovery copy could not be saved'
                : 'Recovery copy was not saved',
          ),
        );
        expect(
          controller.actionMessage,
          isNot(contains('Private host failure')),
        );
        expect(controller.report, same(priorReport));
        final first = (await _exportFiles(output)).single;
        expect(first.path, endsWith('recovery-complete.jsonl'));
        final firstBefore = await first.readAsBytes();
        await controller.saveBackup((backup) async {
          await backup.openRead().drain<void>();
          return true;
        });
        expect(controller.actionMessage, startsWith('Recovery copy saved'));
        expect(await _exportFiles(output), hasLength(2));
        expect(await first.readAsBytes(), firstBefore);
        expect(await _hashes(archive.directory), archiveBefore);
        expect(await _hashes(coordinator.directory), rehearsalBefore);
      },
    );
  }

  test(
    'changed physical evidence is saved only as an explicitly partial copy',
    () async {
      await capture();
      await coordinator.rehearse(sourceArchive: archive, layout: _layout());
      final changed = File('${archive.directory.path}/opaque.future');
      await changed.writeAsString('before');
      final sourceBefore = await _hashes(source);
      final rehearsalBefore = await _hashes(coordinator.directory);
      final currentBefore = await _current(coordinator);
      final output = await Directory('${parent.path}/exports').create();
      var copied = 0;
      final controller = LegacyRecoveryController(
        streamedActions(
          output,
          onBoundary: (boundary) async {
            if (boundary == 'export_source_copied' && ++copied == 2) {
              // Simulate an uncooperative writer. Leases only cover our writers.
              await changed.writeAsString('after');
            }
          },
        ),
      );
      addTearDown(controller.dispose);
      await controller.saveBackup((backup) async {
        expect(backup.complete, isFalse);
        expect(backup.problems, isNotEmpty);
        expect(backup.fileName, 'recovery-partial.jsonl');
        await backup.openRead().drain<void>();
        return true;
      });
      expect(
        controller.actionMessage,
        startsWith('Partial recovery copy saved'),
      );
      expect(controller.actionMessage, contains('this copy is incomplete'));
      final file = (await _exportFiles(output)).single;
      final files = await _streamFiles(file);
      expect(
        files['retained_source_files_base64_v1']!['opaque.future'],
        utf8.encode('before'),
      );
      expect(await changed.readAsString(), 'after');
      expect(await _hashes(source), sourceBefore);
      expect(await _hashes(coordinator.directory), rehearsalBefore);
      expect(await _current(coordinator), currentBefore);
    },
  );

  for (final inspect in [false, true]) {
    for (final key in ['capture_layout_v1', LegacySourceReader.inventoryKey]) {
      test(
        '${inspect ? 'inspection' : 'rehearsal'} refuses $key alias to outer coordinator lease',
        () async {
          await capture();
          final record = File('${archive.directory.path}/$key.record');
          final lock = File('${coordinator.directory.path}/coordinator.lock');
          await lock.writeAsBytes(await record.readAsBytes(), flush: true);
          await record.delete();
          expect(
            (await Process.run('ln', [lock.path, record.path])).exitCode,
            0,
          );
          final archiveBefore = await _hashes(archive.directory);
          final sourceBefore = await _hashes(source);
          await expectLater(
            inspect
                ? coordinator.inspectRehearsal(
                    sourceArchive: archive,
                    layout: _layout(),
                  )
                : coordinator.rehearse(
                    sourceArchive: archive,
                    layout: _layout(),
                  ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'guard',
                contains('aliases a coordination file'),
              ),
            ),
          );
          expect(await _current(coordinator), isNull);
          expect(await _hashes(archive.directory), archiveBefore);
          expect(await _hashes(source), sourceBefore);
          expect(
            await FileSystemEntity.identical(lock.path, record.path),
            isTrue,
          );
        },
        skip: !Platform.isLinux,
      );
    }
  }

  test(
    'retained source feeds real repository and media without offline copy',
    () async {
      await capture();
      final before = await _hashes(archive.directory);
      await source.rename('${source.path}-moved');
      final result = await coordinator.rehearse(
        sourceArchive: archive,
        layout: _layout(),
      );
      expect(result.alreadyPromoted, isFalse);
      expect(result.state.session.players.first.tokens.single.amount, 12);
      expect(result.state.session.players.first.tokens.single.tapped, 4);
      await _destination(coordinator, (hive) async {
        final repo = TableRepository.forTesting(
          openBox: (name) => hive.openBox<String>(name),
        );
        expect((await repo.open()).state.toJson(), result.state.toJson());
      });
      Hive.init(coordinator.directory.path);
      expect(
        await TabletMediaStore.read(
          result.state.session.players.first.tokens.single.artworkUrl!,
        ),
        _png,
      );
      await Hive.close();
      final reopened = await LegacyMigrationCoordinator.reopenRehearsal(
        coordinator.directory,
      );
      // The mirrored raw evidence is self-contained after a successful transfer.
      final repeated = await reopened.rehearse(layout: _layout());
      expect(repeated.alreadyPromoted, isTrue);
      expect(repeated.transactionId, result.transactionId);
      expect(await _hashes(archive.directory), before);
    },
  );

  test(
    'every archive-copy and promotion boundary retries with unchanged archive',
    () async {
      await capture();
      final original = await _hashes(archive.directory);
      final boundaries = <String>[];
      final complete = await coordinator.rehearse(
        sourceArchive: archive,
        layout: _layout(),
        onBoundary: (value) async => boundaries.add(value),
      );
      expect(
        boundaries,
        containsAll([
          'archive_copy_intent',
          'archive_copy_inventory',
          'captured',
          'staged',
          'intent',
          'validated',
          'promotion_written',
          'promotion_flushed',
        ]),
      );
      for (var stop = 0; stop < boundaries.length; stop++) {
        final trial = await LegacyMigrationCoordinator.createRehearsal();
        var index = 0;
        try {
          await expectLater(
            trial.rehearse(
              sourceArchive: archive,
              layout: _layout(),
              onBoundary: (_) async {
                if (index++ == stop) throw StateError('Interrupted');
              },
            ),
            throwsStateError,
          );
          final reopened = await LegacyMigrationCoordinator.reopenRehearsal(
            trial.directory,
          );
          final retried = await reopened.rehearse(
            sourceArchive: archive,
            layout: _layout(),
          );
          expect(
            retried.state.toJson(),
            complete.state.toJson(),
            reason: boundaries[stop],
          );
          expect(
            await _hashes(archive.directory),
            original,
            reason: boundaries[stop],
          );
        } finally {
          await trial.directory.delete(recursive: true);
        }
      }
    },
  );

  test(
    'retained retry preserves later gameplay and previous generation exactly',
    () async {
      await capture();
      await coordinator.rehearse(sourceArchive: archive, layout: _layout());
      late String current;
      late String previous;
      await _destination(coordinator, (hive) async {
        final repo = TableRepository.forTesting(
          openBox: (name) => hive.openBox<String>(name),
        );
        final state = (await repo.open()).state;
        state.session.players.first.life = 13;
        state.session.players.first.tokens.single.amount = 27;
        await repo.save(state);
        current = hive.box<String>(TableStorageKeys.aggregate).get('current')!;
        previous = hive
            .box<String>('${TableStorageKeys.aggregate}_previous')
            .get('current')!;
      });
      final before = await _hashes(archive.directory);
      final result = await coordinator.rehearse(
        sourceArchive: archive,
        layout: _layout(),
      );
      expect(result.alreadyPromoted, isTrue);
      expect(result.state.session.players.first.life, 13);
      expect(result.state.session.players.first.tokens.single.amount, 27);
      expect(await _current(coordinator), current);
      await _destination(coordinator, (hive) async {
        expect(
          (await hive.openBox<String>(
            '${TableStorageKeys.aggregate}_previous',
          )).get('current'),
          previous,
        );
      });
      expect(await _hashes(archive.directory), before);
    },
  );

  test(
    'inspection changes neither rehearsal nor archive then guarded retry succeeds',
    () async {
      await capture();
      final archiveBefore = await _hashes(archive.directory);
      final rehearsalBefore = await _hashes(coordinator.directory);
      final actions = LegacyRehearsalRecoveryActions(
        coordinator: coordinator,
        sourceArchive: archive,
        layout: _layout(),
      );
      final report = await actions.inspect();
      expect(report.phase, LegacyRecoveryPhase.ready);
      expect(report.canRetry, isTrue);
      expect(await _hashes(archive.directory), archiveBefore);
      expect(await _hashes(coordinator.directory), rehearsalBefore);
      final done = await actions.retry();
      expect(done.phase, LegacyRecoveryPhase.completed);
      expect(done.transactionId, report.transactionId);
      expect(await _hashes(archive.directory), archiveBefore);
    },
  );

  test(
    'incomplete capture refuses promotion and keeps every retained byte',
    () async {
      await expectLater(
        archive.captureCopiedDirectory(
          source: source,
          layout: _layout(),
          onBoundary: (value) async {
            if (value == 'capture_intent') throw StateError('Interrupted');
          },
        ),
        throwsStateError,
      );
      final before = await _hashes(archive.directory);
      await expectLater(
        coordinator.rehearse(sourceArchive: archive, layout: _layout()),
        throwsStateError,
      );
      expect(await _current(coordinator), isNull);
      expect(await _hashes(archive.directory), before);
    },
  );

  for (final damaged in [
    'capture_layout_v1',
    LegacySourceReader.inventoryKey,
    LegacySourceReader.captureIntentKey,
  ]) {
    test('corrupt $damaged blocks even after successful promotion', () async {
      await capture();
      await coordinator.rehearse(sourceArchive: archive, layout: _layout());
      final current = await _current(coordinator);
      await File(
        '${archive.directory.path}/$damaged.record',
      ).writeAsString('corrupt evidence', flush: true);
      final before = await _hashes(archive.directory);
      await expectLater(
        coordinator.rehearse(sourceArchive: archive, layout: _layout()),
        throwsA(anything),
      );
      expect(await _current(coordinator), current);
      expect(await _hashes(archive.directory), before);
    });
  }

  test(
    'a different archive cannot replace complete internal retention',
    () async {
      await coordinator.rehearse(sourceDirectory: source, layout: _layout());
      final current = await _current(coordinator);
      await File(
        '${source.path}/retained-unknown.txt',
      ).writeAsString('different source');
      await capture();
      final before = await _hashes(archive.directory);
      await expectLater(
        coordinator.rehearse(sourceArchive: archive, layout: _layout()),
        throwsFormatException,
      );
      expect(await _current(coordinator), current);
      expect(await _hashes(archive.directory), before);
    },
  );

  test(
    'partial archive transfer pins source across both acquisition routes',
    () async {
      await capture();
      await expectLater(
        coordinator.rehearse(
          sourceArchive: archive,
          layout: _layout(),
          onBoundary: (value) async {
            if (value == 'archive_copy_intent') throw StateError('Interrupted');
          },
        ),
        throwsStateError,
      );
      await File(
        '${source.path}/retained-unknown.txt',
      ).writeAsString('different source');
      final other = await LegacySourceArchive.createIn(parent);
      await other.captureCopiedDirectory(source: source, layout: _layout());
      await expectLater(
        coordinator.rehearse(sourceArchive: other, layout: _layout()),
        throwsFormatException,
      );
      await expectLater(
        coordinator.rehearse(sourceDirectory: source, layout: _layout()),
        throwsFormatException,
      );
      expect(await _current(coordinator), isNull);
      final result = await coordinator.rehearse(
        sourceArchive: archive,
        layout: _layout(),
      );
      expect(result.alreadyPromoted, isFalse);
    },
  );

  test(
    'wrong layout and simultaneous source routes are refused before promotion',
    () async {
      await capture();
      await expectLater(
        coordinator.rehearse(
          sourceArchive: archive,
          layout: _layout(id: 'wrong'),
        ),
        throwsFormatException,
      );
      final before = await _hashes(coordinator.directory);
      await expectLater(
        coordinator.rehearse(
          sourceArchive: archive,
          sourceDirectory: source,
          layout: _layout(),
        ),
        throwsArgumentError,
      );
      await expectLater(
        coordinator.inspectRehearsal(
          sourceArchive: archive,
          sourceDirectory: source,
          layout: _layout(),
        ),
        throwsArgumentError,
      );
      expect(await _hashes(coordinator.directory), before);
      expect(await _current(coordinator), isNull);
    },
  );
  for (final complete in [false, true]) {
    test(
      'combined backup retains $complete archive and pending unknown evidence',
      () async {
        if (complete) {
          await capture();
          await coordinator.rehearse(sourceArchive: archive, layout: _layout());
        } else {
          await expectLater(
            archive.captureCopiedDirectory(
              source: source,
              layout: _layout(),
              onBoundary: (value) async {
                if (value == 'capture_intent') throw StateError('Interrupted');
              },
            ),
            throwsStateError,
          );
        }
        await File(
          '${archive.directory.path}/pending_11111111-1111-1111-1111-111111111111.part',
        ).writeAsBytes([0, 1, 2]);
        await File(
          '${archive.directory.path}/unknown.future',
        ).writeAsString('opaque recovery evidence');
        final archiveBefore = await _hashes(archive.directory);
        final rehearsalBefore = await _hashes(coordinator.directory);
        final actions = LegacyRehearsalRecoveryActions(
          coordinator: coordinator,
          sourceArchive: archive,
          layout: _layout(),
        );
        final backup = await actions.createBackup();
        expect(backup.complete, isTrue);
        final envelope = jsonDecode(utf8.decode(backup.bytes)) as Map;
        expect(
          envelope['sha256'],
          sha256.convert(utf8.encode(envelope['payload'] as String)).toString(),
        );
        final payload = jsonDecode(envelope['payload'] as String) as Map;
        final sources = payload['sources'] as Map;
        expect(
          sources.keys,
          unorderedEquals([
            'rehearsal_files_base64_v1',
            'retained_source_files_base64_v1',
          ]),
        );
        for (final pair in [
          (archive.directory, 'retained_source_files_base64_v1'),
          (coordinator.directory, 'rehearsal_files_base64_v1'),
        ]) {
          final records = sources[pair.$2]['records'] as Map;
          final expected = <String, List<int>>{};
          await for (final entry in pair.$1.list()) {
            if (entry is File && !entry.path.endsWith('.lock')) {
              expected[entry.uri.pathSegments.last] = await entry.readAsBytes();
            }
          }
          expect({
            for (final entry in records.entries)
              entry.key: base64Decode(
                (jsonDecode(entry.value as String) as Map)['bytes'] as String,
              ),
          }, expected);
        }
        expect(await _hashes(archive.directory), archiveBefore);
        expect(await _hashes(coordinator.directory), rehearsalBefore);
        // Opaque files stay exportable but block conversion rather than ignored.
        expect((await actions.inspect()).phase, LegacyRecoveryPhase.blocked);
      },
    );
  }
}
