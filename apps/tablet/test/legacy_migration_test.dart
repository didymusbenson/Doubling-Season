import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/features/preset_service.dart';

import 'support/table_fixture.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_journal.dart';

Map<String, dynamic> fixture() => {
  'format': LegacyMigrationSnapshot.format,
  'version': 1,
  'sourceId': 'installation-fixture-a',
  'sourceVersion': 'repository-0273043-fixture-not-shipped-evidence',
  'capturedAt': '2026-11-10T00:00:00.000Z',
  'collections': {
    'items': [
      {
        'key': 8,
        'value': {
          'name': 'Custom token',
          'pt': '*/2',
          'colors': 'UG',
          'type': 'Creature — Test',
          'abilities': 'A custom ability',
          'amount': 7,
          'tapped': 3,
          'summoningSick': 2,
          'plusOneCounters': 4,
          'minusOneCounters': 1,
          'plusOnePowerCounters': 0,
          'plusOneToughnessCounters': 0,
          'counters': [
            {'name': 'shield', 'amount': 5},
          ],
          'order': 12.5,
          'createdAt': '2026-11-09T12:00:00Z',
          'artworkUrl': 'file:///fixture/token.png',
          'artworkSet': 'CUSTOM',
          'artworkOptions': [
            {
              'url': 'file:///fixture/token.png',
              'set': 'CUSTOM',
              'artist': 'user uploaded',
            },
            {
              'url': 'https://example.org/never-download.png',
              'set': 'SET',
              'artist': 'Artist',
            },
          ],
        },
      },
    ],
    'decks': [
      for (final key in [1, '1'])
        {
          'key': key,
          'value': {
            'name': 'Same deck name',
            'order': key is int ? 2.0 : 1.0,
            'colorIdentity': 'UG',
            'createdAt': '2020-01-01T00:00:00Z',
            'lastModifiedAt': '2026-11-09T12:00:00Z',
            'customArtworkUrl': 'file:///fixture/cover.png',
            'templates': [
              {
                'name': 'Template token',
                'pt': '1/1',
                'colors': 'G',
                'abilities': '',
                'type': 'Creature',
                'order': 1.5,
                'artworkUrl': 'file:///fixture/token.png',
              },
            ],
            'trackerWidgets': [],
            'toggleWidgets': [],
          },
        },
    ],
    'trackerWidgets': [
      {
        'key': 5,
        'value': {
          'widgetId': 'original-custom-uuid',
          'isCustom': true,
          'name': 'Life total',
          'description': 'Actually a custom tracker',
          'colorIdentity': 'U',
          'order': 2.0,
          'currentValue': 19,
          'defaultValue': 2,
          'tapIncrement': 3,
          'longPressIncrement': 3,
          'hasAction': false,
          'actionOnly': false,
          'actionType': null,
        },
      },
    ],
    'toggleWidgets': [
      {
        'key': 'toggle',
        'value': {
          'widgetId': 'custom-toggle-uuid',
          'isCustom': true,
          'name': 'Ready',
          'colorIdentity': 'G',
          'order': 1.0,
          'isActive': true,
          'onDescription': 'Ready now',
          'offDescription': 'Not ready',
          'onArtworkUrl': null,
          'offArtworkUrl': null,
        },
      },
    ],
    'artworkPreferences': [
      {
        'key': 'custom-definition',
        'value': {
          'tokenIdentity': 'custom-definition',
          'lastUsedArtwork': 'file:///fixture/token.png',
          'customArtworkPath': 'file:///fixture/token.png',
        },
      },
    ],
    'customTokens': [
      {
        'key': 'custom-definition',
        'value': {
          'name': 'Custom token',
          'pt': '*/2',
          'colors': 'UG',
          'abilities': 'A custom ability',
          'type': 'Creature — Test',
          'artwork': [
            {'url': 'file:///fixture/token.png', 'artist': 'User credit'},
          ],
          'futureMetadata': {'keep': true},
        },
      },
    ],
    'tokenRules': [],
  },
  'preferences': {
    'summoningSicknessEnabled': false,
    'artworkDisplayStyle': 'fadeout',
    'favoriteTokens': ['one', 'two'],
    'recentTokens': ['two', 'one'],
    'useSystemTheme': false,
    'isDarkMode': true,
    'purchased_collector': true,
    'collector_heart_style': 123,
    'futurePreference': ['retain', 'exactly'],
  },
};

Map<String, Uint8List> media() => {
  'file:///fixture/token.png': Uint8List.fromList([1, 2, 3, 4]),
  'file:///fixture/cover.png': Uint8List.fromList([9, 8, 7]),
};

/// Simulated acknowledged disk and volatile Hive cache. A crash loses only
/// unflushed writes; errors can happen before or after every read/write/flush.
class CrashStorage extends LegacyMigrationStorage {
  Map<String, String> cache = {};
  Map<String, String> disk = {};
  int operations = 0;
  int? failAt;
  bool after = false;

  Future<T> operation<T>(T Function() action) async {
    operations++;
    final fail = operations == failAt;
    if (fail && !after) throw StateError('Simulated interruption');
    final result = action();
    if (fail && after) throw StateError('Uncertain acknowledgement');
    return result;
  }

  @override
  Future<String?> read(String key) => operation(() => cache[key]);
  @override
  Future<void> write(String key, String value) => operation(() {
    cache[key] = value;
  });
  @override
  Future<void> flush() => operation(() {
    disk = Map.of(cache);
  });
  void crash() {
    cache = Map.of(disk);
    failAt = null;
  }
}

Future<LegacyMigrationResult> migrate(CrashStorage storage) async {
  final journal = LegacyMigrationJournal(storage);
  final staged = await journal.prepare(
    LegacyMigrationSnapshot(fixture()),
    localMedia: media(),
  );
  return journal.commit(staged.transactionId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'copies live board independently from zero-state duplicate-name presets',
    () {
      final input = fixture();
      final before = jsonEncode(input);
      final plan = LegacyMigrationConverter().convert(
        LegacyMigrationSnapshot(input),
      );
      expect(plan.blockers, isEmpty);
      final player = plan.state.session.players.first;
      expect(plan.state.session.players, hasLength(4));
      expect(player.tokens, hasLength(1));
      final token = player.tokens.single;
      expect(
        [
          token.amount,
          token.tapped,
          token.summoningSick,
          token.plusOneCounters,
          token.minusOneCounters,
        ],
        [7, 3, 2, 4, 1],
      );
      expect(token.counters, {'shield': 5});
      expect(token.pt, '*/2');
      expect(token.artworkOptions.last['artist'], 'Artist');
      expect(token.extra['artworkDisplayStyle'], 'fadeout');
      expect(player.summoningSicknessEnabled, isFalse);
      expect(
        player.life,
        40,
      ); // Custom "Life total" must never become canonical life.
      expect(
        player.utilities.firstWhere((u) => u.kind == 'custom_tracker').value,
        19,
      );
      expect(
        player.utilities
            .firstWhere((u) => u.kind == 'custom_tracker')
            .defaultValue,
        2,
      );
      expect(
        player.utilities.firstWhere((u) => u.kind == 'custom_toggle').isActive,
        isTrue,
      );
      expect(plan.state.decks, hasLength(2));
      expect(plan.state.decks.map((d) => d['id']).toSet(), hasLength(2));
      expect(
        plan.state.decks.map((d) => d['name']),
        everyElement('Same deck name'),
      );
      expect((plan.state.decks.first['legacy'] as Map)['order'], 1.0);
      expect(
        (plan.state.decks.first['tokens'] as List).single,
        isNot(contains('amount')),
      );
      expect(plan.state.decks.first['imageUrl'], 'file:///fixture/cover.png');
      expect(plan.state.library['favorites'], ['one', 'two']);
      expect(plan.state.library['recent'], ['two', 'one']);
      expect(plan.state.library['legacyPreferences'], input['preferences']);
      expect(player.artPreferences, isEmpty);
      expect(plan.state.settings['theme'], 'dark');
      expect(jsonEncode(input), before);
      expect(plan.state.session.history, isEmpty);
    },
  );

  test(
    'migrated presets load fresh on either seat without replaying live state',
    () async {
      final state = LegacyMigrationConverter()
          .convert(LegacyMigrationSnapshot(fixture()))
          .state;
      final f = TableFixture(state);
      await f.initialize();
      try {
        final presets = PresetService(f.controller, f.catalog);
        final other = f.controller.session.players[1].id;
        final liveId = f.player.tokens.single.id;
        await presets.load(other, state.decks.first['id'] as String);
        expect(f.player.tokens.single.id, liveId);
        expect(f.player.tokens.single.amount, 7);
        final fresh = f.controller.player(other).tokens.single;
        expect([fresh.amount, fresh.tapped, fresh.summoningSick], [0, 0, 0]);
        expect(fresh.extra['artworkDisplayStyle'], 'fadeout');
        expect(fresh.artworkUrl, 'file:///fixture/token.png');
        await presets.load(f.playerId, state.decks.first['id'] as String);
        expect(f.player.tokens.single.amount, 0);
        expect(f.player.tokens.single.extra['artworkDisplayStyle'], 'fadeout');
        final saved = await presets.save(f.playerId, 'Saved again');
        expect(
          (saved['tokens'] as List).single['artworkDisplayStyle'],
          'fadeout',
        );
      } finally {
        f.dispose();
      }
    },
  );

  test(
    'equal ordering is stable across large token and utility collections',
    () {
      final input = fixture();
      final templates = [
        for (var i = 0; i < 60; i++)
          <String, dynamic>{'name': 'Token $i', 'pt': '1/1', 'order': 0.0},
      ];
      final utilities = [
        for (var i = 0; i < 60; i++)
          <String, dynamic>{
            'name': 'Utility $i',
            'isCustom': true,
            'order': 0.0,
            'tapIncrement': 1,
            'longPressIncrement': 1,
          },
      ];
      input['collections']['decks'][0]['value']['templates'] = templates;
      input['collections']['decks'][0]['value']['trackerWidgets'] = utilities;
      final plan = LegacyMigrationConverter().convert(
        LegacyMigrationSnapshot(input),
      );
      final deck = plan.state.decks.last;
      expect(
        (deck['tokens'] as List).map((t) => t['name']),
        templates.map((t) => t['name']),
      );
      expect(
        (deck['utilities'] as List).map((u) => u['name']),
        utilities.map((u) => u['name']),
      );
    },
  );

  test(
    'active current/older rule preferences and unsupported custom behavior block activation',
    () {
      final prefs = {
        for (final key in [
          'preset_token_doublers',
          'preset_doubling_season',
          'preset_primal_vigor',
          'preset_ojer_taq',
          'preset_academy_manufactor_count',
          'preset_chatterfang',
          'preset_plus_one_doublers',
          'preset_plus_one_extra',
          'preset_all_counter_doublers',
        ])
          key: 1,
        'preset_academy_manufactor': true,
      };
      for (final entry in prefs.entries) {
        final input = fixture();
        input['preferences'][entry.key] = entry.value;
        final plan = LegacyMigrationConverter().convert(
          LegacyMigrationSnapshot(input),
        );
        expect(plan.canCommit, isFalse, reason: entry.key);
        expect(plan.state.library['legacyPreferences'][entry.key], entry.value);
      }
      final input = fixture();
      input['collections']['trackerWidgets'][0]['value']['longPressIncrement'] =
          7;
      input['collections']['toggleWidgets'][0]['value']['onArtworkUrl'] =
          'file:///fixture/on.png';
      final plan = LegacyMigrationConverter().convert(
        LegacyMigrationSnapshot(input),
      );
      expect(plan.blockers, hasLength(2));
      expect(plan.blockers.join(), contains('state-specific artwork'));
      expect(plan.blockers.join(), contains('long-press increment'));
    },
  );

  test(
    'JSON-valid malformed library and preset definitions cannot be committed',
    () async {
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (m) => m['collections']['customTokens'][0]['value']['name'] = 42,
        (m) => m['collections']['customTokens'][0]['value']['artwork'] = 'bad',
        (m) => m['collections']['decks'][0]['value']['templates'][0]['pt'] = 42,
        (m) =>
            m['collections']['decks'][0]['value']['templates'][0]['artworkUrl'] =
                false,
        (m) => m['collections']['decks'][0]['value']['name'] = '',
      ]) {
        final input = jsonDecode(jsonEncode(fixture())) as Map<String, dynamic>;
        mutation(input);
        final storage = CrashStorage();
        await expectLater(
          LegacyMigrationJournal(
            storage,
          ).prepare(LegacyMigrationSnapshot(input), localMedia: media()),
          throwsA(anything),
        );
        expect(storage.disk.containsKey('current'), isFalse);
        expect(storage.disk.containsKey('source'), isTrue);
      }
    },
  );

  test(
    'older mapping verdicts cannot activate after converter rules change',
    () async {
      final storage = CrashStorage();
      final journal = LegacyMigrationJournal(storage);
      final staged = await journal.prepare(
        LegacyMigrationSnapshot(fixture()),
        localMedia: media(),
      );
      final envelope =
          jsonDecode(storage.cache['candidate']!) as Map<String, dynamic>;
      envelope['payload']['mappingVersion'] = 0;
      envelope['payload']['state']['library']['legacyMigrationReceipt']['mappingVersion'] =
          0;
      envelope['sha256'] = migrationDigest(envelope['payload']);
      storage.cache['candidate'] = jsonEncode(envelope);
      storage.disk = Map.of(storage.cache);
      final before = Map.of(storage.disk);
      await expectLater(
        journal.commit(staged.transactionId),
        throwsFormatException,
      );
      expect(storage.disk, before);
      expect(storage.disk.containsKey('current'), isFalse);
    },
  );

  test(
    'canonical snapshot, stable typed identities and deep copies survive retry',
    () {
      final input = fixture();
      final snapshot = LegacyMigrationSnapshot(input);
      final reversed = {
        for (final key in input.keys.toList().reversed) key: input[key],
      };
      expect(LegacyMigrationSnapshot(reversed).digest, snapshot.digest);
      final first = LegacyMigrationConverter().convert(snapshot);
      final second = LegacyMigrationConverter().convert(snapshot);
      expect(second.state.toJson(), first.state.toJson());
      (input['preferences'] as Map)['futurePreference'] = ['mutated'];
      expect(snapshot.toJson()['preferences']['futurePreference'], [
        'retain',
        'exactly',
      ]);
    },
  );

  test(
    'invalid/newer source and incomplete inventory refuse without writing',
    () async {
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (m) => m['version'] = 999,
        (m) => (m['collections'] as Map).remove('decks'),
        (m) => (m['collections']['items'] as List).add(
          m['collections']['items'][0],
        ),
        (m) => m['collections']['items'][0]['key'] = false,
        (m) => m['sourceId'] = '',
      ]) {
        final input = fixture();
        mutation(input);
        expect(() => LegacyMigrationSnapshot(input), throwsA(anything));
      }
    },
  );

  test(
    'invalid board bounds refuse rather than normalize acknowledged values',
    () {
      final input = fixture();
      input['collections']['items'][0]['value']['tapped'] = 99;
      expect(
        () =>
            LegacyMigrationConverter().convert(LegacyMigrationSnapshot(input)),
        throwsFormatException,
      );
    },
  );

  test(
    'unmapped utilities/rules/axis and duplicate counters stage recovery but block commit',
    () async {
      final input = fixture();
      final token = input['collections']['items'][0]['value'] as Map;
      token['plusOnePowerCounters'] = 3;
      (token['counters'] as List).add({'name': 'shield', 'amount': 2});
      input['collections']['trackerWidgets'][0]['value']['isCustom'] = false;
      input['collections']['tokenRules'] = [
        {
          'key': 'rule',
          'value': {'enabled': true},
        },
      ];
      final storage = CrashStorage();
      final journal = LegacyMigrationJournal(storage);
      final result = await journal.prepare(
        LegacyMigrationSnapshot(input),
        localMedia: media(),
      );
      expect(result.blockers, hasLength(4));
      await expectLater(journal.commit(result.transactionId), throwsStateError);
      expect(storage.disk.containsKey('source'), isTrue);
      expect(storage.disk.containsKey('candidate'), isTrue);
      expect(storage.disk.containsKey('current'), isFalse);
      expect(await journal.openCommitted(), isNull);
      expect(jsonDecode(storage.disk['source']!)['payload']['snapshot'], input);
    },
  );

  test(
    'copies/hash-verifies/remaps local artwork while retaining raw source and remote credits',
    () async {
      final storage = CrashStorage();
      final journal = LegacyMigrationJournal(storage);
      final staged = await journal.prepare(
        LegacyMigrationSnapshot(fixture()),
        localMedia: media(),
      );
      expect(staged.committed, isFalse);
      final token = staged.state.session.players.first.tokens.single;
      expect(token.artworkUrl, startsWith('tablet-art:'));
      expect(await journal.readMedia(token.artworkUrl!), media().values.first);
      expect(token.artworkOptions.first['url'], token.artworkUrl);
      expect(
        token.artworkOptions.last['url'],
        'https://example.org/never-download.png',
      );
      expect(token.artworkOptions.last['artist'], 'Artist');
      final original = jsonDecode(
        storage.disk['source']!,
      )['payload']['snapshot'];
      expect(original, fixture());
      final committed = await journal.commit(staged.transactionId);
      expect(committed.committed, isTrue);
      expect(
        committed.state.library['legacyMigrationReceipt']['transactionId'],
        staged.transactionId,
      );
      expect(
        await journal.readMedia(
          committed.state.decks.first['imageUrl'] as String,
        ),
        media().values.last,
      );
    },
  );

  test(
    'missing artwork preserves metadata and provides a recoverable warning',
    () async {
      final storage = CrashStorage();
      final result = await LegacyMigrationJournal(
        storage,
      ).prepare(LegacyMigrationSnapshot(fixture()), localMedia: {});
      expect(
        result.state.session.players.first.tokens.single.artworkUrl,
        'file:///fixture/token.png',
      );
      expect(result.state.decks.first['imageUrl'], 'file:///fixture/cover.png');
      expect(
        result.warnings.where((w) => w.startsWith('Missing local artwork')),
        hasLength(2),
      );
      expect(result.blockers, isEmpty);
    },
  );

  test(
    'media caller mutations during an await do not change captured bytes',
    () async {
      final input = media();
      final storage = CrashStorage();
      final journal = LegacyMigrationJournal(storage);
      final future = journal.prepare(
        LegacyMigrationSnapshot(fixture()),
        localMedia: input,
      );
      input.values.first[0] = 99;
      final result = await future;
      expect(
        await journal.readMedia(
          result.state.session.players.first.tokens.single.artworkUrl!,
        ),
        Uint8List.fromList([1, 2, 3, 4]),
      );
    },
  );

  test(
    'reopening and repeated/concurrent migration never duplicate or replace a committed generation',
    () async {
      final storage = CrashStorage();
      final first = await migrate(storage);
      final before = Map.of(storage.disk);
      final results = await Future.wait(
        List.generate(3, (_) => migrate(storage)),
      );
      expect(
        results.map((r) => r.state.toJson()),
        everyElement(first.state.toJson()),
      );
      expect(storage.disk, before);
      storage.crash();
      final reopened = await LegacyMigrationJournal(storage).openCommitted();
      expect(reopened!.state.toJson(), first.state.toJson());
      final changed = fixture()..['sourceId'] = 'another-installation';
      await expectLater(
        LegacyMigrationJournal(
          storage,
        ).prepare(LegacyMigrationSnapshot(changed), localMedia: media()),
        throwsStateError,
      );
      expect(storage.disk, before);
    },
  );

  test('changed source bytes cannot replace a partial journal', () async {
    final storage = CrashStorage();
    final journal = LegacyMigrationJournal(storage);
    await journal.prepare(
      LegacyMigrationSnapshot(fixture()),
      localMedia: media(),
    );
    final before = Map.of(storage.disk);
    final changed = media()..values.first[0] = 9;
    await expectLater(
      journal.prepare(LegacyMigrationSnapshot(fixture()), localMedia: changed),
      throwsStateError,
    );
    expect(storage.disk, before);
  });

  test(
    'interruption before/after EVERY storage operation is recoverable without duplicates',
    () async {
      final baseline = CrashStorage();
      final expected = await migrate(baseline);
      final boundaries = baseline.operations;
      expect(boundaries, greaterThan(20));
      for (final after in [false, true]) {
        for (var failure = 1; failure <= boundaries; failure++) {
          final storage = CrashStorage()
            ..failAt = failure
            ..after = after;
          try {
            await migrate(storage);
          } catch (_) {
            /* simulated crash */
          }
          storage.crash();
          final recovered = await migrate(storage);
          expect(
            recovered.state.toJson(),
            expected.state.toJson(),
            reason: 'boundary $failure, after=$after',
          );
          expect(
            storage.disk,
            baseline.disk,
            reason: 'boundary $failure, after=$after',
          );
        }
      }
    },
  );

  test(
    'corrupt/unknown records and missing copied media never reset storage',
    () async {
      for (final key in ['source', 'candidate', 'current', 'media']) {
        final storage = CrashStorage();
        final first = await migrate(storage);
        final actualKey = key == 'media'
            ? storage.cache.keys.firstWhere((k) => k.startsWith('media_'))
            : key;
        storage.cache[actualKey] = '{"format":"future-record","version":999}';
        storage.disk = Map.of(storage.cache);
        final before = Map.of(storage.disk);
        if (key == 'candidate') {
          // Already committed data does not depend on a discarded staging copy.
          expect(
            (await LegacyMigrationJournal(
              storage,
            ).openCommitted())!.state.toJson(),
            first.state.toJson(),
          );
        } else {
          await expectLater(
            LegacyMigrationJournal(storage).openCommitted(),
            throwsA(anything),
          );
        }
        expect(storage.disk, before);
      }
      final storage = CrashStorage();
      await migrate(storage);
      final key = storage.cache.keys.firstWhere((k) => k.startsWith('media_'));
      storage.cache.remove(key);
      storage.disk = Map.of(storage.cache);
      await expectLater(
        LegacyMigrationJournal(storage).openCommitted(),
        throwsFormatException,
      );
      expect(storage.disk.containsKey('current'), isTrue);
    },
  );

  test(
    'checksums detect changed payload and markers cannot split from board',
    () async {
      final storage = CrashStorage();
      await migrate(storage);
      final current =
          jsonDecode(storage.cache['current']!) as Map<String, dynamic>;
      current['payload']['state']['session']['players'][0]['tokens'][0]['amount'] =
          1;
      storage.cache['current'] = jsonEncode(current);
      storage.disk = Map.of(storage.cache);
      await expectLater(
        LegacyMigrationJournal(storage).openCommitted(),
        throwsFormatException,
      );
    },
  );

  test(
    'real Hive close/reopen preserves staged data, media and atomic commit receipt',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'migration-fixture-',
      );
      Hive.init(directory.path);
      final legacy = await Hive.openBox<String>('items');
      await legacy.put('sentinel', 'original installation unchanged');
      final production = await Hive.openBox<String>(
        'tripling_season_tablet_aggregate_v1',
      );
      await production.put('current', 'existing game unchanged');
      try {
        var storage = await HiveLegacyMigrationStorage.openFixture('reopen');
        var journal = LegacyMigrationJournal(storage);
        final staged = await journal.prepare(
          LegacyMigrationSnapshot(fixture()),
          localMedia: media(),
        );
        await storage.close();
        storage = await HiveLegacyMigrationStorage.openFixture('reopen');
        journal = LegacyMigrationJournal(storage);
        await journal.commit(staged.transactionId);
        await storage.close();
        storage = await HiveLegacyMigrationStorage.openFixture('reopen');
        journal = LegacyMigrationJournal(storage);
        final reopened = await journal.openCommitted();
        expect(reopened!.state.toJson(), staged.state.toJson());
        expect(
          await journal.readMedia(
            reopened.state.session.players.first.tokens.single.artworkUrl!,
          ),
          media().values.first,
        );
        expect(legacy.toMap(), {'sentinel': 'original installation unchanged'});
        expect(production.toMap(), {'current': 'existing game unchanged'});
        await storage.close();
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
