import 'dart:convert';
import 'dart:io';
import 'dart:async';

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
import 'package:tripling_table/migration/legacy_migration_recovery.dart';
import 'package:tripling_table/migration/legacy_rehearsal_recovery_actions.dart';
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

Map<String, List<int>> _backupFiles(LegacyRecoveryBackup backup) {
  final envelope = jsonDecode(utf8.decode(backup.bytes)) as Map;
  final payload = envelope['payload'] as String;
  expect(envelope['sha256'], sha256.convert(utf8.encode(payload)).toString());
  final decoded = jsonDecode(payload) as Map;
  final records =
      decoded['sources']['rehearsal_files_base64_v1']['records'] as Map;
  return {
    for (final entry in records.entries)
      entry.key as String: base64Decode(
        (jsonDecode(entry.value as String) as Map)['bytes'] as String,
      ),
  };
}

Future<void> _expectExactBackup(
  LegacyMigrationCoordinator coordinator,
  LegacyRecoveryBackup backup,
) async {
  expect(backup.complete, isTrue);
  expect(backup.problems, isEmpty);
  final files = _backupFiles(backup);
  final retained = <String, List<int>>{};
  await for (final entity in coordinator.directory.list()) {
    if (entity is File && !entity.path.endsWith('.lock')) {
      retained[entity.uri.pathSegments.last] = await entity.readAsBytes();
    }
  }
  expect(files, retained);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory source;
  late LegacyMigrationCoordinator coordinator;
  late LegacyRehearsalRecoveryActions actions;

  setUp(() async {
    source = await Directory.systemTemp.createTemp('recovery-actions-source-');
    coordinator = await LegacyMigrationCoordinator.createRehearsal();
    actions = LegacyRehearsalRecoveryActions(
      coordinator: coordinator,
      sourceDirectory: source,
      layout: _layout(),
    );
    await _fixture(source);
  });
  tearDown(() async {
    await Hive.close();
    await source.delete(recursive: true);
    await coordinator.directory.delete(recursive: true);
  });

  for (final boundary in <String?>[
    null,
    'copied',
    'retained',
    'inventory',
    'captured',
    'staged',
    'intent',
  ]) {
    test(
      '${boundary ?? 'empty'} inspection reports ready without promoting or changing any files',
      () async {
        if (boundary != null) {
          await expectLater(
            coordinator.rehearse(
              sourceDirectory: source,
              layout: _layout(),
              onBoundary: (value) async {
                if (value == boundary ||
                    (boundary == 'retained' && value.startsWith('retained:'))) {
                  throw StateError('Interrupted fixture');
                }
              },
            ),
            throwsStateError,
          );
        }
        final sourceBefore = await _hashes(source);
        final rehearsalBefore = await _hashes(coordinator.directory);
        final report = await actions.inspect();
        expect(report.phase, LegacyRecoveryPhase.ready);
        expect(report.canRetry, isTrue);
        expect(report.transactionId, isNotNull);
        expect(await _hashes(source), sourceBefore);
        expect(await _hashes(coordinator.directory), rehearsalBefore);
        final backup = await actions.createBackup();
        await _expectExactBackup(coordinator, backup);
        expect(await _hashes(source), sourceBefore);
        expect(await _hashes(coordinator.directory), rehearsalBefore);
      },
    );
  }

  test('retry without inspection only checks readiness', () async {
    final before = await _hashes(coordinator.directory);
    expect((await actions.retry()).phase, LegacyRecoveryPhase.ready);
    expect(await _hashes(coordinator.directory), before);
  });

  test(
    'successful retry and completed inspection retain later gameplay',
    () async {
      final sourceBefore = await _hashes(source);
      final checked = await actions.inspect();
      final promoted = await actions.retry();
      expect(promoted.phase, LegacyRecoveryPhase.completed);
      expect(promoted.canRetry, isFalse);
      expect(promoted.transactionId, checked.transactionId);
      await _destination(coordinator, (hive) async {
        final repo = TableRepository.forTesting(
          openBox: (name) => hive.openBox<String>(name, crashRecovery: false),
        );
        final state = (await repo.open()).state;
        state.session.players.first.life = 17;
        state.session.players.first.tokens.single.amount = 19;
        await repo.save(state);
      });
      final before = await _hashes(coordinator.directory);
      expect((await actions.inspect()).phase, LegacyRecoveryPhase.completed);
      expect((await actions.retry()).phase, LegacyRecoveryPhase.completed);
      await _expectExactBackup(coordinator, await actions.createBackup());
      expect(await _hashes(coordinator.directory), before);
      expect(await _hashes(source), sourceBefore);
      final state = TableRepository.decodeGeneration(
        (await _current(coordinator))!,
      );
      expect(state.session.players.first.life, 17);
      expect(state.session.players.first.tokens.single.amount, 19);
    },
  );

  for (final damage in ['hive_tail', 'raw_key', 'journal_key']) {
    test(
      '$damage blocks inspection and retry but remains exactly exportable',
      () async {
        await coordinator.rehearse(sourceDirectory: source, layout: _layout());
        if (damage == 'hive_tail') {
          await File(
            '${coordinator.directory.path}/${TableStorageKeys.aggregate}.hive',
          ).writeAsBytes([1, 2, 3], mode: FileMode.append, flush: true);
        } else {
          await _destination(coordinator, (hive) async {
            final box = await hive.openBox<String>(
              damage == 'raw_key'
                  ? LegacyMigrationCoordinator.rawBoxName
                  : LegacyMigrationCoordinator.journalBoxName,
            );
            await box.put('future_private_record', 'opaque future payload');
          });
        }
        final before = await _hashes(coordinator.directory);
        final original = await _hashes(source);
        final report = await actions.inspect();
        expect(report.phase, LegacyRecoveryPhase.blocked);
        expect(report.canRetry, isFalse);
        expect(report.issues, isNotEmpty);
        expect((await actions.retry()).phase, LegacyRecoveryPhase.blocked);
        await _expectExactBackup(coordinator, await actions.createBackup());
        expect(await _hashes(coordinator.directory), before);
        expect(await _hashes(source), original);
        await expectLater(
          coordinator.rehearse(layout: _layout()),
          throwsA(anything),
        );
      },
    );
  }

  test(
    'backup includes original media and later gameplay artwork bytes',
    () async {
      await coordinator.rehearse(sourceDirectory: source, layout: _layout());
      final later = [..._png, 0];
      final laterHash = sha256.convert(later).toString();
      await _destination(coordinator, (hive) async {
        final media = await hive.openBox<dynamic>(TableStorageKeys.media);
        await media.put(laterHash, later);
        final repo = TableRepository.forTesting(
          openBox: (name) => hive.openBox<String>(name),
        );
        final state = (await repo.open()).state;
        state.session.players.first.tokens.single.artworkUrl =
            'tablet-art:$laterHash';
        await repo.save(state);
      });
      final before = await _hashes(coordinator.directory);
      final backup = await actions.createBackup();
      await _expectExactBackup(coordinator, backup);
      final copy = await Directory.systemTemp.createTemp('backup-media-check-');
      final hive = HiveImpl()..init(copy.path);
      try {
        await File(
          '${copy.path}/${TableStorageKeys.media}.hive',
        ).writeAsBytes(_backupFiles(backup)['${TableStorageKeys.media}.hive']!);
        final media = await hive.openBox<dynamic>(
          TableStorageKeys.media,
          crashRecovery: false,
        );
        expect(media.get(sha256.convert(_png).toString()), _png);
        expect(media.get(laterHash), later);
      } finally {
        await hive.close();
        await copy.delete(recursive: true);
      }
      expect(await _hashes(coordinator.directory), before);
    },
  );

  test(
    'source changed after inspection is blocked before destination writes',
    () async {
      expect((await actions.inspect()).phase, LegacyRecoveryPhase.ready);
      await File(
        '${source.path}/retained-unknown.txt',
      ).writeAsString('Changed after check');
      final before = await _hashes(coordinator.directory);
      final changedSource = await _hashes(source);
      final report = await actions.retry();
      expect(report.phase, LegacyRecoveryPhase.blocked);
      expect(report.canRetry, isFalse);
      expect(await _hashes(coordinator.directory), before);
      expect(await _hashes(source), changedSource);
    },
  );

  for (final scenario in [
    'newer_previous',
    'divergent_equal',
    'identical_equal',
  ]) {
    test(
      '$scenario generations are checked without replacing authority',
      () async {
        await coordinator.rehearse(sourceDirectory: source, layout: _layout());
        final current = (await _current(coordinator))!;
        final state = TableRepository.decodeGeneration(current);
        final sequence = (jsonDecode(current) as Map)['sequence'] as int;
        if (scenario == 'divergent_equal')
          state.session.players.first.life = 13;
        await _destination(coordinator, (hive) async {
          await (await hive.openBox<String>(
            '${TableStorageKeys.aggregate}_previous',
          )).put(
            'current',
            scenario == 'identical_equal'
                ? current
                : TableRepository.encodeGeneration(
                    state,
                    sequence: sequence + (scenario == 'newer_previous' ? 1 : 0),
                  ),
          );
        });
        final before = await _hashes(coordinator.directory);
        final report = await actions.inspect();
        expect(
          report.phase,
          scenario == 'identical_equal'
              ? LegacyRecoveryPhase.completed
              : LegacyRecoveryPhase.blocked,
        );
        expect(await _hashes(coordinator.directory), before);
        if (scenario == 'identical_equal') {
          expect(
            (await coordinator.rehearse(layout: _layout())).alreadyPromoted,
            isTrue,
          );
        } else {
          await expectLater(
            coordinator.rehearse(layout: _layout()),
            throwsStateError,
          );
        }
        expect(await _current(coordinator), current);
      },
    );
  }

  test(
    'simultaneous inspection export and retry wait for the shared coordinator lease',
    () async {
      await actions.inspect();
      final reached = Completer<void>();
      final release = Completer<void>();
      final promotion = coordinator.rehearse(
        sourceDirectory: source,
        layout: _layout(),
        onBoundary: (boundary) async {
          if (boundary == 'captured') {
            reached.complete();
            await release.future;
          }
        },
      );
      await reached.future;
      final second = await LegacyMigrationCoordinator.reopenRehearsal(
        coordinator.directory,
      );
      final secondActions = LegacyRehearsalRecoveryActions(
        coordinator: second,
        sourceDirectory: source,
        layout: _layout(),
      );
      var completed = 0;
      final inspect = secondActions.inspect().then((value) {
        completed++;
        return value;
      });
      final backup = secondActions.createBackup().then((value) {
        completed++;
        return value;
      });
      final retry = actions.retry().then((value) {
        completed++;
        return value;
      });
      try {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(completed, 0);
      } finally {
        release.complete();
      }
      final result = await promotion;
      expect((await inspect).phase, LegacyRecoveryPhase.completed);
      expect((await retry).transactionId, result.transactionId);
      await _expectExactBackup(coordinator, await backup);
      expect(completed, 3);
    },
  );

  test(
    'snapshot marker reads do not release the cross-process lease',
    () async {
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      expect(
        flutterRoot,
        isNotNull,
        reason: 'Use the matching Flutter Dart SDK.',
      );
      final scriptDirectory = await Directory.systemTemp.createTemp(
        'lease-probe-',
      );
      final script = File('${scriptDirectory.path}/probe.dart');
      await script.writeAsString(r"""
import 'dart:io';
Future<void> main(List<String> args) async {
  final file = await File(args.single).open(mode: FileMode.append);
  try {
    await file.lock(FileLock.exclusive);
    stdout.write('acquired');
  } on FileSystemException {
    stdout.write('blocked');
  } finally {
    await file.close();
  }
}
""");
      Future<String> probe() async {
        final result = await Process.run(
          '$flutterRoot/bin/cache/dart-sdk/bin/dart',
          [script.path, '${coordinator.directory.path}/coordinator.lock'],
        ).timeout(const Duration(seconds: 15));
        expect(result.exitCode, 0, reason: '${result.stderr}');
        return (result.stdout as String).trim();
      }

      try {
        await coordinator.rehearse(
          sourceDirectory: source,
          layout: _layout(),
          onBoundary: (boundary) async {
            if (boundary == 'captured') {
              // POSIX record locks are released if any descriptor to the same
              // inode closes. Reading the marker must not close the lease inode.
              await File(
                '${coordinator.directory.path}/rehearsal.txt',
              ).readAsBytes();
              expect(await probe(), 'blocked');
            }
          },
        );
        expect(await probe(), 'acquired');
      } finally {
        await scriptDirectory.delete(recursive: true);
      }
    },
    skip: Platform.isWindows,
  );
}
