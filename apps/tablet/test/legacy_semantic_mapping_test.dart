import 'dart:convert';

import 'package:doubling_season/database/widget_database.dart';
import 'package:doubling_season/models/deck.dart';
import 'package:doubling_season/models/item.dart';
import 'package:doubling_season/models/rule_outcome.dart';
import 'package:doubling_season/models/rule_trigger.dart';
import 'package:doubling_season/models/token_counter.dart';
import 'package:doubling_season/models/token_rule.dart';
import 'package:doubling_season/models/toggle_widget.dart';
import 'package:doubling_season/models/toggle_widget_template.dart';
import 'package:doubling_season/models/tracker_widget.dart';
import 'package:doubling_season/models/tracker_widget_template.dart';
import 'package:doubling_season/models/widget_definition.dart';
import 'package:doubling_season/providers/rules_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_snapshot_capture.dart';
import 'package:tripling_table/services/scoped_rules_calculator.dart';

import 'support/table_fixture.dart';

final instant = DateTime.utc(2026, 11, 10);

/// Real phone-model fixtures, including database-created built-ins and actual
/// template constructors. These are repository fixtures, not shipped-build data.
LegacyMigrationSnapshot captureModels({
  Map<Object, Item> items = const {},
  Map<Object, Deck> decks = const {},
  Map<Object, TrackerWidget> trackers = const {},
  Map<Object, ToggleWidget> toggles = const {},
  Map<Object, TokenRule> rules = const {},
  Map<String, dynamic> preferences = const {},
}) => LegacyMigrationSnapshot(
  LegacySnapshotCapture.capture(
    sourceId: 'semantic-fixture',
    sourceVersion: 'repository-17af6ef-not-shipped-evidence',
    capturedAt: instant,
    items: items,
    decks: decks,
    trackerWidgets: trackers,
    toggleWidgets: toggles,
    artworkPreferences: {},
    customTokens: {},
    tokenRules: rules,
    preferences: preferences,
  ),
);

TrackerWidget tracker(String kind) {
  final db = WidgetDatabase();
  final result = db.filteredWidgets
      .firstWhere((d) => d.id == kind)
      .toTrackerWidget(order: 2);
  db.dispose();
  result.widgetId = 'fixture-$kind';
  result.createdAt = instant;
  return result;
}

class PhoneRules extends RulesProvider {
  final List<TokenRule> models;
  PhoneRules(this.models);
  @override
  List<TokenRule> get customRules =>
      [...models]..sort((a, b) => a.order.compareTo(b.order));
}

List<Object> output(List<TokenCreationResult> results) => [
  for (final result in results)
    [result.compositeId, result.quantity, result.wasCapped],
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all real built-ins retain independent passive or explicit action semantics',
    () {
      final db = WidgetDatabase();
      final trackers = <Object, TrackerWidget>{};
      final toggles = <Object, ToggleWidget>{};
      for (final definition in db.filteredWidgets) {
        if (definition.type == WidgetType.toggle) {
          toggles[definition.id] = definition.toToggleWidget(order: 1)
            ..name = 'Renamed ${definition.id}'
            ..isActive = true;
        } else {
          trackers[definition.id] = definition.toTrackerWidget(order: 2)
            ..name = 'Renamed ${definition.id}'
            ..currentValue = 7;
        }
      }
      db.dispose();
      final snapshot = captureModels(trackers: trackers, toggles: toggles);
      final before = jsonEncode(snapshot.toJson());
      final plan = LegacyMigrationConverter().convert(snapshot);
      expect(plan.blockers, isEmpty);
      final player = plan.state.session.players.first;
      expect(player.utilities.length, trackers.length + toggles.length);
      for (final utility in player.utilities) {
        final source = utility.configuration;
        expect(utility.name, source['name']);
        expect(utility.legacySingleStepHold, isTrue);
        expect(source['isCustom'], isFalse);
        expect(source['widgetId'], isNotEmpty);
        expect(
          utility.kind,
          source['actionType'] ??
              (source['type'] == 'toggle' ? 'legacy_toggle' : 'legacy_tracker'),
        );
        expect(utility.value, source['type'] == 'toggle' ? 0 : 7);
      }
      expect(player.life, 40);
      expect(player.counters.values, everyElement(0));
      expect(plan.state.session.monarchPlayerId, isNull);
      expect(plan.state.session.dayNight, 'neither');
      expect(player.citysBlessing, isFalse);
      expect(jsonEncode(snapshot.toJson()), before);
    },
  );

  test(
    'axis counters map to functional counters without changing raw source',
    () {
      final item = Item(
        name: 'Bear',
        pt: '2/3',
        amount: 4,
        plusOneCounters: 2,
        minusOneCounters: 1,
        plusOnePowerCounters: 3,
        plusOneToughnessCounters: 4,
        counters: [TokenCounter(name: 'shield', amount: 2)],
      );
      final plan = LegacyMigrationConverter().convert(
        captureModels(items: {1: item}),
      );
      expect(plan.blockers, isEmpty);
      final token = plan.state.session.players.first.tokens.single;
      expect(token.counters, {'shield': 2, '+1/+0': 3, '+0/+1': 4});
      expect(token.extra['legacy']['plusOnePowerCounters'], 3);
      expect(token.plusOneCounters, 2);
      expect(token.minusOneCounters, 1);
      expect(token.pt, item.pt);
      expect(
        TabletState.fromJson(
          plan.state.toJson(),
        ).session.players.first.tokens.single.toJson(),
        token.toJson(),
      );
    },
  );

  test(
    'reserved custom counters and unknown actions cannot silently change meaning',
    () {
      for (final name in ['+1/+1', '-1/-1', '+1/+0', '+0/+1']) {
        final plan = LegacyMigrationConverter().convert(
          captureModels(
            items: {
              1: Item(
                name: 'Bear',
                pt: '2/2',
                counters: [TokenCounter(name: name, amount: 3)],
              ),
            },
          ),
        );
        expect(plan.canCommit, isFalse, reason: name);
        expect(plan.blockers.single, contains('reserved counter'));
      }
      final action = tracker('krenko_mob_boss')..actionType = 'future_action';
      final plan = LegacyMigrationConverter().convert(
        captureModels(trackers: {1: action}),
      );
      expect(plan.canCommit, isFalse);
      expect(plan.blockers.single, contains('counterpart mapping'));
    },
  );

  test(
    'real utility templates load fresh on other seats and preserve compatibility',
    () async {
      final action = tracker('krenko_mob_boss')..currentValue = 9;
      final toggle = ToggleWidget(
        widgetId: 'toggle',
        name: 'Renamed Monarch',
        colorIdentity: '',
        order: 1,
        createdAt: instant,
        isActive: true,
        onDescription: 'On text',
        offDescription: 'Off text',
        onArtworkUrl: 'file:///fixture/on.png',
        offArtworkUrl: 'file:///fixture/off.png',
      );
      final plan = LegacyMigrationConverter().convert(
        captureModels(
          trackers: {1: action},
          toggles: {2: toggle},
          decks: {
            3: Deck(
              name: 'Original deck',
              templates: [],
              trackerWidgets: [TrackerWidgetTemplate.fromWidget(action)],
              toggleWidgets: [ToggleWidgetTemplate.fromWidget(toggle)],
            ),
          },
        ),
      );
      expect(plan.blockers, isEmpty);
      final f = TableFixture(plan.state);
      await f.initialize();
      try {
        final before = f.player.toJson();
        final other = f.controller.session.players[1].id;
        await PresetService(
          f.controller,
          f.catalog,
        ).load(other, plan.state.decks.single['id'] as String);
        expect(f.player.toJson(), before);
        final fresh = f.controller.player(other).utilities;
        expect(fresh.first.isActive, isFalse);
        expect(fresh.first.displayedArtworkUrl, toggle.offArtworkUrl);
        expect(fresh.first.displayedDescription, 'Off text');
        expect(fresh.last.value, action.defaultValue);
        expect(fresh.last.legacyHoldIncrement, action.longPressIncrement);
        expect(fresh.last.kind, action.actionType);
        expect(
          f.player.utilities.first.displayedArtworkUrl,
          toggle.onArtworkUrl,
        );
        final saved = await PresetService(
          f.controller,
          f.catalog,
        ).save(other, 'Again');
        expect(
          (saved['utilities'] as List)
              .last['configuration']['legacyInteractionVersion'],
          1,
        );
      } finally {
        f.dispose();
      }
    },
  );

  test(
    'each active preset matches phone token and counter arithmetic without cross-seat effects',
    () {
      final setters = <String, void Function(PhoneRules)>{
        'preset_token_doublers': (r) => r.tokenDoublerCount = 2,
        'preset_doubling_season': (r) => r.doublingSeasonCount = 2,
        'preset_primal_vigor': (r) => r.primalVigorCount = 2,
        'preset_ojer_taq': (r) => r.ojerTaqCount = 2,
        'preset_academy_manufactor_count': (r) => r.academyManufactorCount = 2,
        'preset_chatterfang': (r) => r.chatterfangCount = 2,
        'preset_plus_one_doublers': (r) => r.plusOneDoublerCount = 2,
        'preset_plus_one_extra': (r) => r.plusOneExtraCount = 2,
        'preset_all_counter_doublers': (r) => r.allCounterDoublerCount = 2,
      };
      for (final entry in setters.entries) {
        final phone = PhoneRules([]);
        entry.value(phone);
        final plan = LegacyMigrationConverter().convert(
          captureModels(preferences: {entry.key: 2}),
        );
        expect(plan.blockers, isEmpty, reason: entry.key);
        final player = plan.state.session.players.first;
        final mapped = ScopedRulesCalculator(player.rules);
        expect(player.rules.single.global, isFalse);
        expect(
          plan.state.session.players.skip(1).every((p) => p.rules.isEmpty),
          isTrue,
        );
        for (final input in [
          ('Bear', '2/2', 'G', 'Creature — Bear'),
          ('Food', '', '', 'Artifact — Food'),
        ]) {
          expect(
            output(
              mapped.evaluateRules(
                input.$1,
                input.$2,
                input.$3,
                input.$4,
                '',
                3,
              ),
            ),
            output(
              phone.evaluateRules(
                input.$1,
                input.$2,
                input.$3,
                input.$4,
                '',
                3,
              ),
            ),
            reason: entry.key,
          );
        }
        for (final plus in [true, false]) {
          expect(
            mapped.calculateCounterAmount(3, isPlusOne: plus),
            phone.calculateCounterAmount(3, isPlusOne: plus),
            reason: entry.key,
          );
        }
        phone.dispose();
      }
    },
  );

  test(
    'custom trigger/outcome phases and copy counts preserve exact phone outputs',
    () {
      final triggers = [
        RuleTrigger(triggerType: 'any_token'),
        RuleTrigger(triggerType: 'has_pt'),
        RuleTrigger(triggerType: 'token_type', targetType: 'Bear'),
        RuleTrigger(triggerType: 'color', targetColor: 'G'),
        RuleTrigger(
          triggerType: 'specific_token',
          targetTokenId: 'Bear|2/2|G|Creature — Bear|',
        ),
      ];
      for (final trigger in triggers) {
        final rule = TokenRule(
          name: 'Mixed custom rule',
          trigger: trigger,
          count: 2,
          order: 4,
          outcomes: [
            RuleOutcome(outcomeType: 'multiply', multiplier: 3),
            RuleOutcome(
              outcomeType: 'also_create',
              targetTokenId: 'Bird|1/1|W|Creature — Bird|Flying',
              quantity: 2,
            ),
            RuleOutcome(
              outcomeType: 'replace',
              targetTokenId: 'Wolf|2/2|G|Creature — Wolf|',
            ),
          ],
        );
        final disabled = TokenRule(
          name: 'Disabled',
          enabled: false,
          order: 1,
          trigger: RuleTrigger(triggerType: 'any_token'),
          outcomes: [RuleOutcome(multiplier: 9)],
        );
        final phone = PhoneRules([rule, disabled])..doublingSeasonCount = 1;
        final plan = LegacyMigrationConverter().convert(
          captureModels(
            rules: {'a': rule, 1: disabled},
            preferences: {'preset_doubling_season': 1},
          ),
        );
        expect(plan.blockers, isEmpty);
        final custom = plan.state.session.players.first.rules
            .where((r) => r.definitionId == 'custom')
            .toList();
        expect(custom.map((r) => r.name), ['Disabled', 'Mixed custom rule']);
        expect(custom.first.enabled, isFalse);
        expect(custom.last.count, 2);
        final mapped = ScopedRulesCalculator(
          plan.state.session.players.first.rules,
        );
        for (final input in [
          ('Bear', '2/2', 'G', 'Creature — Bear'),
          ('Food', '', '', 'Artifact — Food'),
        ]) {
          expect(
            output(
              mapped.evaluateRules(
                input.$1,
                input.$2,
                input.$3,
                input.$4,
                '',
                2,
              ),
            ),
            output(
              phone.evaluateRules(
                input.$1,
                input.$2,
                input.$3,
                input.$4,
                '',
                2,
              ),
            ),
          );
        }
        phone.dispose();
      }
    },
  );

  test('old Academy boolean precedence matches original even when false', () {
    for (final old in [false, true]) {
      final plan = LegacyMigrationConverter().convert(
        captureModels(
          preferences: {
            'preset_academy_manufactor': old,
            'preset_academy_manufactor_count': 3,
          },
        ),
      );
      expect(plan.blockers, isEmpty);
      expect(plan.state.session.players.first.rules.single.count, old ? 1 : 0);
      expect(plan.warnings.join(), contains('boolean takes precedence'));
      expect(
        plan
            .state
            .library['legacyPreferences']['preset_academy_manufactor_count'],
        3,
      );
    }
  });

  test(
    'unsupported rule states are retained and blocked, including disabled rules',
    () {
      for (final rule in [
        TokenRule(
          name: 'Future',
          enabled: false,
          trigger: RuleTrigger(triggerType: 'unknown'),
          outcomes: [RuleOutcome()],
        ),
        TokenRule(
          name: 'Bad target',
          trigger: RuleTrigger(triggerType: 'specific_token'),
          outcomes: [RuleOutcome()],
        ),
        TokenRule(
          name: 'Future outcome',
          trigger: RuleTrigger(triggerType: 'any_token'),
          outcomes: [RuleOutcome(outcomeType: 'unknown')],
        ),
        TokenRule(
          name: 'Zero replace',
          count: 0,
          trigger: RuleTrigger(triggerType: 'any_token'),
          outcomes: [
            RuleOutcome(
              outcomeType: 'replace',
              targetTokenId: 'Bird|1/1|W|Creature — Bird|',
            ),
          ],
        ),
      ]) {
        final plan = LegacyMigrationConverter().convert(
          captureModels(rules: {1: rule}),
        );
        expect(plan.canCommit, isFalse);
        expect(plan.state.library['legacyTokenRules'], hasLength(1));
      }
      for (final prefs in [
        {'preset_chatterfang': -1},
        {'preset_ojer_taq': 21},
        {'preset_academy_manufactor': 'yes'},
        {'tokenMultiplier': 3},
        {'counterMultiplier': 2},
        {'preset_future_active_rule': 1},
      ]) {
        expect(
          LegacyMigrationConverter()
              .convert(captureModels(preferences: prefs))
              .canCommit,
          isFalse,
        );
      }
    },
  );
  test('ambiguous source grouping and tied custom order block activation', () {
    TokenRule rule(double order) => TokenRule(
      name: 'Companion',
      order: order,
      trigger: RuleTrigger(triggerType: 'any_token'),
      outcomes: [
        RuleOutcome(
          outcomeType: 'also_create',
          targetTokenId: 'Bird|1/1|W|Creature — Bird|',
        ),
      ],
    );
    final grouped = LegacyMigrationConverter().convert(
      captureModels(rules: {1: rule(0), '1': rule(1)}),
    );
    expect(grouped.blockers.single, contains('stringified source keys'));
    final tied = LegacyMigrationConverter().convert(
      captureModels(rules: {1: rule(0), 2: rule(0)}),
    );
    expect(tied.blockers.single, contains('tied ordering'));
  });

  test(
    'mapped real actions execute with their original values and undo exactly',
    () async {
      for (final kind in [
        'krenko_mob_boss',
        'krenko_tin_street',
        'hare_apparent',
        'academy_manufactor',
        'rhys_the_redeemed',
        'brudiclad_telchor_engineer',
        'cathars_crusade',
      ]) {
        final utility = tracker(kind)
          ..name = 'Renamed action'
          ..currentValue = 2;
        final snapshot = captureModels(
          trackers: {1: utility},
          items: {
            1: Item(
              name: 'Goblin',
              pt: '1/1',
              colors: 'R',
              type: 'Creature — Goblin',
              amount: 3,
            ),
          },
        );
        final plan = LegacyMigrationConverter().convert(snapshot);
        expect(plan.blockers, isEmpty);
        final f = TableFixture(plan.state);
        await f.initialize();
        try {
          final before = f.player.toJson();
          final id = f.player.utilities.single.id;
          await f.board.utilityAction(
            f.playerId,
            id,
            skip: kind == 'brudiclad_telchor_engineer',
          );
          final created =
              f.player.tokens.fold<int>(0, (n, token) => n + token.amount) - 3;
          expect(created, switch (kind) {
            'krenko_mob_boss' => 5,
            'krenko_tin_street' => 2,
            'hare_apparent' => 1,
            'academy_manufactor' => 9,
            'rhys_the_redeemed' => 3,
            'brudiclad_telchor_engineer' => 1,
            _ => 0,
          }, reason: kind);
          if (kind == 'cathars_crusade') {
            expect(f.player.tokens.single.plusOneCounters, 2);
            expect(f.player.utilities.single.value, 0);
          }
          expect(
            f.controller.session.players.skip(1).every((p) => p.tokens.isEmpty),
            isTrue,
          );
          await f.controller.undo();
          final afterUndo = f.player.toJson()..remove('generation');
          before.remove('generation');
          expect(afterUndo, before, reason: kind);
        } finally {
          f.dispose();
        }
      }
    },
  );
  test(
    'live ties retain source key order and mixed-key ties block activation',
    () {
      final plan = LegacyMigrationConverter().convert(
        captureModels(
          items: {
            '2': Item(name: 'String two', pt: '1/1'),
            '10': Item(name: 'String ten', pt: '1/1'),
            '3': Item(name: 'String three', pt: '1/1'),
          },
        ),
      );
      expect(plan.blockers, isEmpty);
      expect(plan.state.session.players.first.tokens.map((t) => t.name), [
        'String ten',
        'String two',
        'String three',
      ]);
      final ambiguous = LegacyMigrationConverter().convert(
        captureModels(
          items: {
            1: Item(name: 'Integer', pt: '1/1'),
            '1': Item(name: 'String', pt: '1/1'),
          },
        ),
      );
      expect(
        ambiguous.blockers.single,
        contains('ambiguous tied source positions'),
      );
    },
  );
}
