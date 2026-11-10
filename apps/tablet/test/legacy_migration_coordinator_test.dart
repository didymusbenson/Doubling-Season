import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory source;
  late LegacyMigrationCoordinator coordinator;
  setUp(() async {
    source = await Directory.systemTemp.createTemp('coordinator-source-');
    coordinator = await LegacyMigrationCoordinator.createRehearsal();
  });
  tearDown(() async {
    await Hive.close();
    if (await source.exists()) await source.delete(recursive: true);
    await coordinator.directory.delete(recursive: true);
  });

  test(
    'real Hive promotion opens through the real repository and media reader',
    () async {
      await _fixture(source);
      final original = await _hashes(source);
      final result = await coordinator.rehearse(
        sourceDirectory: source,
        layout: _layout(),
      );
      expect(result.alreadyPromoted, false);
      expect(result.warnings, isNotEmpty); // Fixture defaults are disclosed.
      expect(result.state.session.players.first.tokens.single.amount, 12);
      final encoded = (await _current(coordinator))!;
      await _destination(coordinator, (hive) async {
        final repo = TableRepository.forTesting(
          openBox: (name) => hive.openBox<String>(name, crashRecovery: false),
        );
        final opened = await repo.open();
        expect(opened.state.toJson(), result.state.toJson());
        expect(opened.recoveryMessage, null);
      });
      Hive.init(coordinator.directory.path);
      final reference =
          result.state.session.players.first.tokens.single.artworkUrl!;
      expect(await TabletMediaStore.read(reference), _png);
      await Hive.close();
      final reopened = await LegacyMigrationCoordinator.reopenRehearsal(
        coordinator.directory,
      );
      final retry = await reopened.rehearse(layout: _layout());
      expect(retry.alreadyPromoted, true);
      expect(retry.transactionId, result.transactionId);
      expect(await _current(coordinator), encoded);
      expect(await _hashes(source), original);
    },
  );

  test(
    'retry retains later gameplay and its previous generation without rewriting',
    () async {
      await _fixture(source);
      await coordinator.rehearse(sourceDirectory: source, layout: _layout());
      late String current;
      late String previous;
      await _destination(coordinator, (hive) async {
        final repo = TableRepository.forTesting(
          openBox: (name) => hive.openBox<String>(name),
        );
        final state = (await repo.open()).state;
        state.session.players.first.life = 17;
        state.session.players.first.tokens.single.amount = 19;
        await repo.save(state);
        current = hive.box<String>(TableStorageKeys.aggregate).get('current')!;
        previous = hive
            .box<String>('${TableStorageKeys.aggregate}_previous')
            .get('current')!;
      });
      await source.rename('${source.path}-moved');
      final moved = Directory('${source.path}-moved');
      try {
        final result = await coordinator.rehearse(
          sourceDirectory: source,
          layout: _layout(),
        );
        expect(result.alreadyPromoted, true);
        expect(result.state.session.players.first.life, 17);
        expect(result.state.session.players.first.tokens.single.amount, 19);
        expect(await _current(coordinator), current);
        await _destination(coordinator, (hive) async {
          expect(
            (await hive.openBox<String>(
              '${TableStorageKeys.aggregate}_previous',
            )).get('current'),
            previous,
          );
        });
      } finally {
        await moved.rename(source.path);
      }
    },
  );

  test(
    'every reported interruption boundary retries without source or authority loss',
    () async {
      await _fixture(source);
      final original = await _hashes(source);
      final boundaries = <String>[];
      final completed = await coordinator.rehearse(
        sourceDirectory: source,
        layout: _layout(),
        onBoundary: (value) async {
          boundaries.add(value);
        },
      );
      final expected = completed.state.toJson();
      expect(
        boundaries,
        containsAll([
          'copied',
          'inventory',
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
              sourceDirectory: source,
              layout: _layout(),
              onBoundary: (_) async {
                if (index++ == stop) {
                  throw StateError('Injected interrupted acknowledgement');
                }
              },
            ),
            throwsStateError,
          );
          final reopened = await LegacyMigrationCoordinator.reopenRehearsal(
            trial.directory,
          );
          final retried = await reopened.rehearse(
            sourceDirectory: source,
            layout: _layout(),
          );
          expect(retried.state.toJson(), expected, reason: boundaries[stop]);
          expect(await _hashes(source), original, reason: boundaries[stop]);
          expect(await _current(trial), isNotNull);
        } finally {
          await trial.directory.delete(recursive: true);
        }
      }
    },
  );

  for (final problem in ['missing_image', 'invalid_image', 'unknown_rule']) {
    test('$problem retains raw source and refuses authority', () async {
      await _fixture(
        source,
        media: problem != 'missing_image',
        invalidImage: problem == 'invalid_image',
        preferences: problem == 'unknown_rule'
            ? '<map><int name="flutter.preset_future_rule" value="1"/></map>'
            : '<map/>',
      );
      final before = await _hashes(source);
      await expectLater(
        coordinator.rehearse(sourceDirectory: source, layout: _layout()),
        throwsA(anything),
      );
      expect(await _current(coordinator), null);
      expect(await _hashes(source), before);
      await _destination(coordinator, (hive) async {
        final raw = await hive.openBox<String>(
          LegacyMigrationCoordinator.rawBoxName,
        );
        expect(raw.get(LegacySourceReader.inventoryKey), isNotNull);
        expect(
          raw.values.any(
            (value) =>
                value.contains(base64Encode(utf8.encode('Never discard me'))),
          ),
          true,
        );
      });
    });
  }

  test(
    'existing fresh table is never mistaken for an empty migration destination',
    () async {
      await _fixture(source);
      await _destination(coordinator, (hive) async {
        final repo = TableRepository.forTesting(
          openBox: (name) => hive.openBox<String>(name),
        );
        await repo.open();
      });
      final original = await _current(coordinator);
      await expectLater(
        coordinator.rehearse(sourceDirectory: source, layout: _layout()),
        throwsStateError,
      );
      expect(await _current(coordinator), original);
    },
  );

  test(
    'concurrent clients serialize and second observes the same promotion',
    () async {
      await _fixture(source);
      final other = await LegacyMigrationCoordinator.reopenRehearsal(
        coordinator.directory,
      );
      final results = await Future.wait([
        coordinator.rehearse(sourceDirectory: source, layout: _layout()),
        other.rehearse(sourceDirectory: source, layout: _layout()),
      ]);
      expect(results.map((r) => r.alreadyPromoted), [false, true]);
      expect(results.first.transactionId, results.last.transactionId);
    },
  );

  test(
    'retained source damage blocks retry without replacing promoted authority',
    () async {
      await _fixture(source);
      await coordinator.rehearse(sourceDirectory: source, layout: _layout());
      final current = await _current(coordinator);
      await _destination(coordinator, (hive) async {
        final raw = await hive.openBox<String>(
          LegacyMigrationCoordinator.rawBoxName,
        );
        await raw.put(raw.keys.first, 'corrupted retained evidence');
      });
      await expectLater(
        coordinator.rehearse(layout: _layout()),
        throwsA(anything),
      );
      expect(await _current(coordinator), current);
    },
  );

  test(
    'source identity conflict and conflicting intent never replace authority',
    () async {
      await _fixture(source);
      await coordinator.rehearse(sourceDirectory: source, layout: _layout());
      final current = await _current(coordinator);
      await expectLater(
        coordinator.rehearse(layout: _layout(id: 'another-source')),
        throwsFormatException,
      );
      await _destination(coordinator, (hive) async {
        await (await hive.openBox<String>(
          LegacyMigrationCoordinator.controlBoxName,
        )).put('intent', 'another intent');
      });
      await expectLater(
        coordinator.rehearse(layout: _layout()),
        throwsStateError,
      );
      expect(await _current(coordinator), current);
    },
  );

  test(
    'overlapping source and destination are rejected before any file writes',
    () async {
      final before = await _hashes(coordinator.directory);
      await expectLater(
        coordinator.rehearse(
          sourceDirectory: coordinator.directory,
          layout: _layout(),
        ),
        throwsStateError,
      );
      expect(await _hashes(coordinator.directory), before);
    },
  );

  for (final corrupt in [false, true]) {
    test(
      'promoted media ${corrupt ? 'corruption' : 'loss'} blocks retry without silent repair',
      () async {
        await _fixture(source);
        await coordinator.rehearse(sourceDirectory: source, layout: _layout());
        final current = await _current(coordinator);
        final hash = sha256.convert(_png).toString();
        await _destination(coordinator, (hive) async {
          final media = await hive.openBox<dynamic>(TableStorageKeys.media);
          if (corrupt) {
            await media.put(hash, [9, 8, 7]);
          } else {
            await media.delete(hash);
          }
        });
        await expectLater(
          coordinator.rehearse(layout: _layout()),
          throwsA(anything),
        );
        expect(await _current(coordinator), current);
        await _destination(coordinator, (hive) async {
          expect(
            (await hive.openBox<dynamic>(TableStorageKeys.media)).get(hash),
            corrupt ? [9, 8, 7] : null,
          );
        });
      },
    );
  }

  test(
    'unknown coordinator records and recovery authorities are preserved and block',
    () async {
      await _fixture(source);
      await coordinator.rehearse(sourceDirectory: source, layout: _layout());
      final current = await _current(coordinator);
      await _destination(coordinator, (hive) async {
        await (await hive.openBox<String>(
          '${TableStorageKeys.aggregate}_recovery',
        )).put('future', 'unknown authority');
      });
      await expectLater(
        coordinator.rehearse(layout: _layout()),
        throwsStateError,
      );
      await _destination(coordinator, (hive) async {
        expect(
          (await hive.openBox<String>(
            '${TableStorageKeys.aggregate}_recovery',
          )).get('future'),
          'unknown authority',
        );
        await (await hive.openBox<String>(
          LegacyMigrationCoordinator.controlBoxName,
        )).put('future', 'unknown coordinator');
      });
      await expectLater(
        coordinator.rehearse(layout: _layout()),
        throwsStateError,
      );
      expect(await _current(coordinator), current);
    },
  );

  test(
    'symlinked destination box is rejected without opening its target',
    () async {
      final target = File('${source.path}/untouched.bin');
      await target.writeAsString('untouched');
      await Link(
        '${coordinator.directory.path}/${LegacyMigrationCoordinator.rawBoxName}.hive',
      ).create(target.path);
      await expectLater(
        coordinator.rehearse(layout: _layout()),
        throwsStateError,
      );
      expect(await target.readAsString(), 'untouched');
    },
  );

  test('worker isolates cannot open competing Hive writers', () async {
    final path = coordinator.directory.path;
    final message = await Isolate.run(() async {
      final other = await LegacyMigrationCoordinator.reopenRehearsal(
        Directory(path),
      );
      try {
        await other.rehearse(layout: _layout());
        return 'unexpected success';
      } catch (error) {
        return error.toString();
      }
    });
    expect(message, contains('root isolate'));
    expect(await coordinator.directory.list().length, 1);
  });

  test(
    'damaged native Hive tail is not automatically truncated on open',
    () async {
      await _fixture(source);
      await coordinator.rehearse(sourceDirectory: source, layout: _layout());
      final file = File(
        '${coordinator.directory.path}/${TableStorageKeys.aggregate}.hive',
      );
      await file.writeAsBytes([1, 2, 3], mode: FileMode.append, flush: true);
      final broken = await file.readAsBytes();
      await expectLater(
        coordinator.rehearse(layout: _layout()),
        throwsA(anything),
      );
      expect(await file.readAsBytes(), broken);
    },
  );

  test(
    'a later game with missing new artwork does not pass validation',
    () async {
      await _fixture(source);
      await coordinator.rehearse(sourceDirectory: source, layout: _layout());
      await _destination(coordinator, (hive) async {
        final repo = TableRepository.forTesting(
          openBox: (name) => hive.openBox<String>(name),
        );
        final state = (await repo.open()).state;
        state.session.players.first.tokens.single.artworkUrl =
            'tablet-art:missing-later-image';
        await repo.save(state);
      });
      final current = await _current(coordinator);
      await expectLater(
        coordinator.rehearse(layout: _layout()),
        throwsFormatException,
      );
      expect(await _current(coordinator), current);
    },
  );

  test(
    'rehearsal guard rejects arbitrary directories, links and unknown files',
    () async {
      await _fixture(source);
      await expectLater(
        LegacyMigrationCoordinator.reopenRehearsal(source),
        throwsA(anything),
      );
      await File(
        '${coordinator.directory.path}/unrecognized.hive',
      ).writeAsString('preserve');
      await expectLater(
        coordinator.rehearse(sourceDirectory: source, layout: _layout()),
        throwsStateError,
      );
      expect(
        await File(
          '${coordinator.directory.path}/unrecognized.hive',
        ).readAsString(),
        'preserve',
      );
    },
  );
}
