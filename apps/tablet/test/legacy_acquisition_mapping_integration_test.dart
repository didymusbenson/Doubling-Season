import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:doubling_season/database/widget_database.dart';
import 'package:doubling_season/models/deck.dart';
import 'package:doubling_season/models/item.dart';
import 'package:doubling_season/models/rule_outcome.dart';
import 'package:doubling_season/models/rule_trigger.dart';
import 'package:doubling_season/models/token_artwork_preference.dart';
import 'package:doubling_season/models/token_counter.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/models/token_rule.dart';
import 'package:doubling_season/models/token_template.dart';
import 'package:doubling_season/models/toggle_widget.dart';
import 'package:doubling_season/models/toggle_widget_template.dart';
import 'package:doubling_season/models/tracker_widget.dart';
import 'package:doubling_season/models/tracker_widget_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// A private writer registry produces real copied fixtures without touching the
// application's global original boxes or invoking its recovery bootstrap.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_journal.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';
import 'package:tripling_table/migration/legacy_source_reader.dart';
import 'package:tripling_table/services/scoped_rules_calculator.dart';
import 'package:tripling_table/storage/storage_namespace.dart';

import 'support/table_fixture.dart';

final _date = DateTime.utc(2026, 11, 10);
const _art = 'file:///old-installation/token.png';
const _offArt = 'file:///old-installation/off.png';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6hAAAAABJRU5ErkJggg==',
);

HiveImpl _writer(Directory directory) => HiveImpl()
  ..init(directory.path)
  ..registerAdapter<Item>(ItemAdapter())
  ..registerAdapter<TokenCounter>(TokenCounterAdapter())
  ..registerAdapter<Deck>(DeckAdapter())
  ..registerAdapter<TokenTemplate>(TokenTemplateAdapter())
  ..registerAdapter<ArtworkVariant>(ArtworkVariantAdapter())
  ..registerAdapter<TokenArtworkPreference>(TokenArtworkPreferenceAdapter())
  ..registerAdapter<TrackerWidget>(TrackerWidgetAdapter())
  ..registerAdapter<ToggleWidget>(ToggleWidgetAdapter())
  ..registerAdapter<TrackerWidgetTemplate>(TrackerWidgetTemplateAdapter())
  ..registerAdapter<ToggleWidgetTemplate>(ToggleWidgetTemplateAdapter())
  ..registerAdapter<TokenRule>(TokenRuleAdapter())
  ..registerAdapter<RuleTrigger>(RuleTriggerAdapter())
  ..registerAdapter<RuleOutcome>(RuleOutcomeAdapter());

Future<void> _createSource(Directory directory, {String? problem}) async {
  final hive = _writer(directory);
  final database = WidgetDatabase();
  try {
    final items = await hive.openBox<Item>('items');
    await items.put(1, Item(name: 'Old record', pt: '1/1', createdAt: _date));
    final item = Item(
      name: 'Goblin',
      pt: '1/1',
      type: 'Creature — Goblin',
      colors: 'R',
      amount: 9,
      tapped: 3,
      summoningSick: 2,
      order: 1,
      createdAt: _date,
      plusOneCounters: 2,
      minusOneCounters: 1,
      plusOnePowerCounters: 3,
      plusOneToughnessCounters: 4,
      counters: [
        TokenCounter(
          name: problem == 'reserved_counter' ? '+1/+0' : 'charge',
          amount: 5,
        ),
      ],
      artworkUrl: _art,
      artworkOptions: [
        ArtworkVariant(set: 'CUSTOM', url: _art, artist: 'Original artist'),
      ],
    );
    await items.put(1, item);
    await items.put(
      '1',
      Item(
        name: 'Goblin',
        pt: '1/1',
        type: 'Creature — Goblin',
        amount: 2,
        order: problem == 'tied_positions' ? 1 : 2,
        createdAt: _date,
      ),
    );
    await items.put(
      'removed',
      Item(name: 'Removed', pt: '1/1', createdAt: _date),
    );
    await items.delete('removed');

    final trackers = await hive.openBox<TrackerWidget>('trackerWidgets');
    final passive =
        database.filteredWidgets
            .firstWhere((x) => x.id == 'life_total')
            .toTrackerWidget(order: 3)
          ..name = 'Old life tracker'
          ..createdAt = _date
          ..currentValue = 17
          ..defaultValue = 6
          ..tapIncrement = 2
          ..longPressIncrement = 7;
    final action =
        database.filteredWidgets
            .firstWhere((x) => x.id == 'krenko_mob_boss')
            .toTrackerWidget(order: 4)
          ..name = 'Renamed action'
          ..createdAt = _date
          ..currentValue = 3;
    if (problem == 'unknown_action') action.actionType = 'unrecognized_action';
    await trackers.put(3, passive);
    await trackers.put(4, action);
    final toggles = await hive.openBox<ToggleWidget>('toggleWidgets');
    final toggle = ToggleWidget(
      widgetId: 'arbitrary-original-uuid',
      name: 'Monarch',
      colorIdentity: '',
      order: 5,
      createdAt: _date,
      isActive: true,
      isCustom: false,
      onDescription: 'Original on',
      offDescription: 'Original off',
      onArtworkUrl: _art,
      offArtworkUrl: _offArt,
    );
    await toggles.put('toggle', toggle);

    final decks = await hive.openBox<Deck>('decks');
    for (final key in <Object>[1, '1']) {
      await decks.put(
        key,
        Deck(
          name: 'Same deck name',
          order: key is int ? 1 : 2,
          createdAt: _date,
          customArtworkUrl: _art,
          templates: [TokenTemplate.fromItem(item)],
          trackerWidgets: [
            TrackerWidgetTemplate.fromWidget(passive),
            TrackerWidgetTemplate.fromWidget(action),
          ],
          toggleWidgets: [ToggleWidgetTemplate.fromWidget(toggle)],
        ),
      );
    }
    final artwork = await hive.openBox<TokenArtworkPreference>(
      'artworkPreferences',
    );
    await artwork.put(
      'Goblin',
      TokenArtworkPreference(tokenIdentity: 'Goblin', customArtworkPath: _art),
    );
    final custom = await hive.openBox<String>('customTokens');
    await custom.put(
      'custom',
      jsonEncode({
        'name': 'Custom preserved',
        'pt': '2/3',
        'unknownField': {'retain': true},
      }),
    );
    final rules = await hive.openBox<TokenRule>('tokenRules');
    await rules.put(
      'rule',
      TokenRule(
        name: 'Custom double',
        enabled: problem != 'unknown_rule',
        order: 2,
        count: 2,
        trigger: RuleTrigger(triggerType: 'any_token'),
        outcomes: [
          RuleOutcome(
            outcomeType: problem == 'unknown_rule'
                ? 'future_effect'
                : 'multiply',
            multiplier: 2,
          ),
        ],
      ),
    );
    final orders = await hive.openBox<String>('boardOrderOperations');
    if (problem == 'pending_order') {
      await orders.put('pending', 'must not replay');
    }
  } finally {
    database.dispose();
    await hive.close();
  }
  await File('${directory.path}/preferences.xml').writeAsString('''<map>
    <boolean name="flutter.summoningSicknessEnabled" value="false"/>
    <string name="flutter.artworkDisplayStyle">fadeout</string>
    <int name="flutter.preset_doubling_season" value="2"/>
    <int name="flutter.preset_primal_vigor" value="1"/>
    <int name="flutter.preset_academy_manufactor_count" value="2"/>
    <boolean name="flutter.preset_academy_manufactor" value="false"/>
    <boolean name="flutter.purchased_collector" value="true"/>
    <string name="flutter.unknownPreference">Retained</string>
    ${problem == 'unknown_preference' ? '<int name="flutter.preset_future_rule" value="1"/>' : ''}
  </map>''', flush: true);
  await File('${directory.path}/token.png').writeAsBytes(_png, flush: true);
  await File('${directory.path}/off.png').writeAsBytes(_png, flush: true);
}

LegacySourceLayout _layout() => LegacySourceLayout(
  sourceId: 'end-to-end-generated-source',
  sourceVersion: 'repository-root-0273043-adapters-not-shipped-evidence',
  copyEvidence:
      'Generated temporary fixture; all seven Hive writers closed before acquisition',
  capturedAt: _date,
  boxes: {
    for (final name in LegacyMigrationSnapshot.collections)
      name: '${name.toLowerCase()}.hive',
  },
  preferencesPath: 'preferences.xml',
  preferencesFormat: LegacyPreferencesFormat.androidXml,
  mediaPaths: {_art: 'token.png', _offArt: 'off.png'},
);

Future<Map<String, String>> _hashes(Directory directory) async => {
  await for (final file in directory.list(recursive: true, followLinks: false))
    if (file is File)
      file.path: sha256.convert(await file.readAsBytes()).toString(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory source;
  late HiveLegacyMigrationStorage recovery;
  late HiveLegacyMigrationStorage destination;
  late LegacyMigrationJournal journal;
  late Box<String> aggregateSentinel;
  late Box<String> originalSentinel;

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'acquisition-mapping-integration-',
    );
    source = await Directory('${root.path}/source').create();
    final target = await Directory('${root.path}/isolated-target').create();
    Hive.init(target.path);
    recovery = await HiveLegacyMigrationStorage.openFixture('source_archive');
    destination = await HiveLegacyMigrationStorage.openFixture(
      'mapped_generation',
    );
    journal = LegacyMigrationJournal(destination);
    aggregateSentinel = await Hive.openBox<String>(TableStorageKeys.aggregate);
    originalSentinel = await Hive.openBox<String>('items');
    await aggregateSentinel.put('sentinel', 'Existing Table data');
    await originalSentinel.put(
      'sentinel',
      'Original global box must not be opened by capture',
    );
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  Future<LegacyAcquiredSource> acquire() =>
      LegacySourceReader().acquireCopiedDirectory(
        directory: source,
        layout: _layout(),
        recoveryStorage: recovery,
      );

  Future<void> expectSourceRetained(Map<String, String> before) async {
    expect(await _hashes(source), before);
    final inventory =
        jsonDecode((await recovery.read(LegacySourceReader.inventoryKey))!)
            as Map;
    expect(inventory['layout']['sourceVersion'], _layout().sourceVersion);
    for (final entry in before.entries) {
      final retained =
          jsonDecode((await recovery.read('raw_file_${entry.value}'))!) as Map;
      expect(
        base64Decode(retained['bytes'] as String),
        await File(entry.key).readAsBytes(),
      );
    }
    expect(aggregateSentinel.toMap(), {'sentinel': 'Existing Table data'});
    expect(originalSentinel.toMap(), {
      'sentinel': 'Original global box must not be opened by capture',
    });
  }

  test(
    'real Hive capture maps live utility/rule semantics and fresh presets through durable reopen',
    () async {
      await _createSource(source);
      final before = await _hashes(source);
      final acquired = await acquire();
      final snapshot = acquired.snapshot.toJson();
      final staged = await acquired.prepare(journal);
      expect(staged.blockers, isEmpty);
      expect(staged.warnings, contains(contains('boolean takes precedence')));
      await journal.commit(staged.transactionId);
      await recovery.close();
      await destination.close();
      recovery = await HiveLegacyMigrationStorage.openFixture('source_archive');
      destination = await HiveLegacyMigrationStorage.openFixture(
        'mapped_generation',
      );
      journal = LegacyMigrationJournal(destination);
      final reopened = (await journal.openCommitted())!;
      expect(
        reopened.state.library['legacyMigrationReceipt']['mappingVersion'],
        2,
      );
      final repeated = await acquire();
      expect(repeated.snapshot.digest, acquired.snapshot.digest);
      expect(
        (await repeated.prepare(journal)).transactionId,
        staged.transactionId,
      );
      expect(jsonEncode(acquired.snapshot.toJson()), jsonEncode(snapshot));
      final player = reopened.state.session.players.first;
      expect(player.tokens.map((t) => t.amount), [9, 2]);
      expect(player.tokens.map((t) => t.id).toSet(), hasLength(2));
      expect(
        [player.tokens.first.tapped, player.tokens.first.summoningSick],
        [3, 2],
      );
      expect(player.tokens.first.counters, {
        'charge': 5,
        '+1/+0': 3,
        '+0/+1': 4,
      });
      expect(
        player.tokens.first.artworkOptions.single['artist'],
        'Original artist',
      );
      expect(await journal.readMedia(player.tokens.first.artworkUrl!), _png);
      expect(player.summoningSicknessEnabled, isFalse);
      expect(player.life, 40);
      expect(reopened.state.session.monarchPlayerId, isNull);
      final passive = player.utilities.firstWhere(
        (x) => x.name == 'Old life tracker',
      );
      expect(passive.kind, 'legacy_tracker');
      expect(
        [
          passive.value,
          passive.configuration['tapIncrement'],
          passive.legacyHoldIncrement,
        ],
        [17, 2, 7],
      );
      expect(passive.legacySingleStepHold, isTrue);
      expect(
        player.utilities.firstWhere((x) => x.name == 'Renamed action').kind,
        'krenko_mob_boss',
      );
      final toggle = player.utilities.firstWhere((x) => x.name == 'Monarch');
      expect(toggle.kind, 'legacy_toggle');
      expect(toggle.displayedDescription, 'Original on');
      expect(await journal.readMedia(toggle.displayedArtworkUrl!), _png);
      expect(
        player.rules.every((r) => !r.global && r.ownerPlayerId == player.id),
        isTrue,
      );
      expect(
        player.rules
            .firstWhere((r) => r.definitionId == 'academy_manufactor')
            .enabled,
        isFalse,
      );
      expect(
        player.rules.firstWhere((r) => r.definitionId == 'custom').count,
        2,
      );
      expect(ScopedRulesCalculator(player.rules).doublingSeasonCount, 2);
      expect(
        reopened.state.session.players
            .skip(1)
            .every(
              (p) => p.rules.isEmpty && p.utilities.isEmpty && p.tokens.isEmpty,
            ),
        isTrue,
      );
      expect(
        reopened.state.library['legacyPreferences']['purchased_collector'],
        isTrue,
      );
      expect(reopened.state.library['customTokens'][0]['unknownField'], {
        'retain': true,
      });
      expect(reopened.state.decks, hasLength(2));
      expect(reopened.state.decks.map((d) => d['id']).toSet(), hasLength(2));
      expect(
        reopened.state.decks.map((d) => d['name']),
        everyElement('Same deck name'),
      );

      final fixture = TableFixture(reopened.state);
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final playerBefore = jsonEncode(fixture.player.toJson());
      final otherId = fixture.controller.session.players[1].id;
      await PresetService(
        fixture.controller,
        fixture.catalog,
      ).load(otherId, reopened.state.decks.first['id'] as String);
      final other = fixture.controller.player(otherId);
      expect(other.tokens.single.amount, 0);
      expect(other.tokens.single.counters, isEmpty);
      expect(other.rules, isEmpty);
      expect(other.life, 40);
      expect(
        other.utilities.firstWhere((x) => x.name == 'Old life tracker').value,
        6,
      );
      final freshToggle = other.utilities.firstWhere(
        (x) => x.name == 'Monarch',
      );
      expect(freshToggle.isActive, isFalse);
      expect(freshToggle.displayedDescription, 'Original off');
      expect(await journal.readMedia(freshToggle.displayedArtworkUrl!), _png);
      expect(jsonEncode(fixture.player.toJson()), playerBefore);
      final beforeAction = fixture.player.toJson()..remove('generation');
      final otherBeforeAction = jsonEncode(other.toJson());
      final actionId = fixture.player.utilities
          .firstWhere((u) => u.kind == 'krenko_mob_boss')
          .id;
      await fixture.board.utilityAction(fixture.playerId, actionId);
      // Eleven existing Goblins plus the source tracker's three, then two
      // Doubling Seasons, one local Primal Vigor and two custom double effects.
      expect(
        fixture.player.tokens.fold<int>(0, (n, t) => n + t.amount) - 11,
        448,
      );
      expect(
        jsonEncode(fixture.controller.player(otherId).toJson()),
        otherBeforeAction,
      );
      await fixture.controller.undo();
      expect(fixture.player.toJson()..remove('generation'), beforeAction);
      await expectSourceRetained(before);
    },
  );

  final blockers = {
    'reserved_counter': 'reserved counter',
    'unknown_action': 'counterpart mapping',
    'unknown_rule': 'outcome mapping',
    'tied_positions': 'ambiguous tied source positions',
    'unknown_preference': 'Unknown active legacy rule preference',
  };
  for (final entry in blockers.entries) {
    test('acquired ${entry.key} is retained but cannot activate', () async {
      await _createSource(source, problem: entry.key);
      final before = await _hashes(source);
      final acquired = await acquire();
      final staged = await acquired.prepare(journal);
      expect(staged.blockers, contains(contains(entry.value)));
      await expectLater(journal.commit(staged.transactionId), throwsStateError);
      expect(await journal.openCommitted(), isNull);
      expect(await destination.read('source'), isNotNull);
      expect(await destination.read('candidate'), isNotNull);
      expect(await destination.read('current'), isNull);
      await expectSourceRetained(before);
    });
  }

  test(
    'pending source board-order journal never reaches the semantic converter',
    () async {
      await _createSource(source, problem: 'pending_order');
      final before = await _hashes(source);
      await expectLater(
        acquire(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('board-order'),
          ),
        ),
      );
      expect(await destination.read('candidate'), isNull);
      expect(await destination.read('current'), isNull);
      await expectSourceRetained(before);
    },
  );

  test(
    'raw evidence is reverified between successful acquisition and staging',
    () async {
      await _createSource(source);
      final before = await _hashes(source);
      final acquired = await acquire();
      final hash = before.entries
          .firstWhere((entry) => entry.key.endsWith('/items.hive'))
          .value;
      final key = 'raw_file_$hash';
      final retained = (await recovery.read(key))!;
      await recovery.write(key, '{"invalid":"damaged retained source"}');
      await recovery.flush();
      await expectLater(acquired.prepare(journal), throwsA(anything));
      expect(await destination.read('candidate'), isNull);
      expect(await destination.read('current'), isNull);
      // Restore the deliberate fixture fault and verify that exact retry remains
      // possible without mutating or recapturing the caller's source directory.
      await recovery.write(key, retained);
      await recovery.flush();
      final staged = await acquired.prepare(journal);
      expect(staged.blockers, isEmpty);
      await journal.commit(staged.transactionId);
      await expectSourceRetained(before);
    },
  );
}
