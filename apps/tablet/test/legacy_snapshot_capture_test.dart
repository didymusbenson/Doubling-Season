import 'dart:convert';

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
import 'package:tripling_table/migration/legacy_snapshot_capture.dart';

final _instant = DateTime.utc(2026, 11, 10, 12, 34, 56, 789);
const _iso = '2026-11-10T12:34:56.789Z';
const _artworkJson = [
  {
    'set': 'ABC',
    'url': 'https://example.test/token.jpg',
    'artist': 'Artist One',
  },
  {
    'set': 'CUSTOM',
    'url': 'file:///original/art.png',
    'artist': 'user uploaded',
  },
];

List<ArtworkVariant> _artwork() => [
  for (final variant in _artworkJson) ArtworkVariant.fromJson(variant),
];

Map<String, dynamic> _capture({
  String sourceId = 'installation-123',
  String sourceVersion = '1.11.0+19',
  DateTime? capturedAt,
  Map<Object, Item> items = const {},
  Map<Object, Deck> decks = const {},
  Map<Object, TrackerWidget> trackerWidgets = const {},
  Map<Object, ToggleWidget> toggleWidgets = const {},
  Map<Object, TokenArtworkPreference> artworkPreferences = const {},
  Map<Object, String> customTokens = const {},
  Map<Object, TokenRule> tokenRules = const {},
  Map<String, dynamic> preferences = const {},
}) => LegacySnapshotCapture.capture(
  sourceId: sourceId,
  sourceVersion: sourceVersion,
  capturedAt: capturedAt ?? _instant,
  items: items,
  decks: decks,
  trackerWidgets: trackerWidgets,
  toggleWidgets: toggleWidgets,
  artworkPreferences: artworkPreferences,
  customTokens: customTokens,
  tokenRules: tokenRules,
  preferences: preferences,
);

List<dynamic> _collection(Map<String, dynamic> snapshot, String name) =>
    (snapshot['collections'] as Map<String, dynamic>)[name] as List<dynamic>;

Map<String, dynamic> _value(Map<String, dynamic> snapshot, String name) =>
    (_collection(snapshot, name).single as Map<String, dynamic>)['value']
        as Map<String, dynamic>;

TrackerWidget _tracker() => TrackerWidget(
  widgetId: 'tracker-id',
  name: 'A renamed tracker',
  description: 'Custom action description',
  colorIdentity: 'RG',
  artworkUrl: 'file:///original/tracker.png',
  order: 4.25,
  createdAt: _instant,
  currentValue: 9,
  defaultValue: 3,
  tapIncrement: 2,
  longPressIncrement: 7,
  isCustom: true,
  hasAction: true,
  actionButtonText: 'Perform action',
  actionType: 'future_unknown_action',
  artworkSet: 'CUSTOM',
  artworkOptions: _artwork(),
  actionOnly: true,
);

ToggleWidget _toggle() => ToggleWidget(
  widgetId: 'toggle-id',
  name: 'A renamed toggle',
  colorIdentity: 'WU',
  artworkUrl: 'file:///original/toggle.png',
  order: 5.75,
  createdAt: _instant,
  isActive: true,
  onDescription: 'On description',
  offDescription: 'Off description',
  onArtworkUrl: 'file:///original/on.png',
  offArtworkUrl: 'file:///original/off.png',
  isCustom: true,
  artworkSet: 'CUSTOM',
  artworkOptions: _artwork(),
);

TokenRule _rule() => TokenRule(
  name: 'An uninterpreted rule',
  enabled: false,
  order: 6.5,
  count: 4,
  trigger: RuleTrigger(
    triggerType: 'future_trigger',
    targetTokenId: 'Token|1/1|G|Creature|Reach',
    targetType: 'Creature',
    targetColor: 'G',
  ),
  outcomes: [
    RuleOutcome(
      outcomeType: 'future_outcome',
      multiplier: 3,
      targetTokenId: 'Other|2/2|R|Creature|Haste',
      quantity: 7,
    ),
    RuleOutcome(),
  ],
);

class _UnexpectedJsonObject {
  bool invoked = false;

  Map<String, dynamic> toJson() {
    invoked = true;
    return {'unexpected': true};
  }
}

void main() {
  // Deliberately no Hive init, adapter registration, boxes or plugin setup.
  test(
    'captures required empty collections and caller evidence synchronously',
    () {
      final snapshot = _capture();
      expect(snapshot, {
        'format': 'tripling-season-legacy-snapshot',
        'version': 1,
        'sourceId': 'installation-123',
        'sourceVersion': '1.11.0+19',
        'capturedAt': _iso,
        'collections': {
          'items': [],
          'decks': [],
          'trackerWidgets': [],
          'toggleWidgets': [],
          'artworkPreferences': [],
          'customTokens': [],
          'tokenRules': [],
        },
        'preferences': {},
      });
      expect(jsonDecode(jsonEncode(snapshot)), snapshot);
      expect(_capture(), snapshot);
    },
  );

  test(
    'preserves every item field, duplicate counters and typed Hive keys',
    () {
      final item = Item(
        name: 'Original token',
        pt: '*/2',
        abilities: 'Reach',
        colors: 'GU',
        type: 'Token Creature',
        amount: 11,
        tapped: 2,
        summoningSick: 3,
        plusOneCounters: 5,
        minusOneCounters: 4,
        plusOnePowerCounters: 6,
        plusOneToughnessCounters: 7,
        counters: [
          TokenCounter(name: 'charge', amount: 2),
          TokenCounter(name: 'charge', amount: 3),
        ],
        createdAt: _instant,
        order: 1.25,
        artworkUrl: 'file:///original/art.png',
        artworkSet: 'CUSTOM',
        artworkOptions: _artwork(),
      );
      final snapshot = _capture(items: {7: item, '7': item});
      final entries = _collection(snapshot, 'items');
      expect(entries.map((entry) => entry['key']), [7, '7']);
      expect(entries[0]['key'], isA<int>());
      expect(entries[1]['key'], isA<String>());
      expect(entries[0]['value'], {
        'abilities': 'Reach',
        'name': 'Original token',
        'pt': '*/2',
        'colors': 'GU',
        'amount': 11,
        'tapped': 2,
        'summoningSick': 3,
        'plusOneCounters': 5,
        'minusOneCounters': 4,
        'counters': [
          {'name': 'charge', 'amount': 2},
          {'name': 'charge', 'amount': 3},
        ],
        'createdAt': _iso,
        'order': 1.25,
        'type': 'Token Creature',
        'artworkUrl': 'file:///original/art.png',
        'artworkSet': 'CUSTOM',
        'artworkOptions': _artworkJson,
        'plusOnePowerCounters': 6,
        'plusOneToughnessCounters': 7,
      });
      expect(item.plusOneCounters, 5);
      expect(item.minusOneCounters, 4);
      expect(item.isInBox, isFalse);
      expect(jsonDecode(jsonEncode(snapshot)), snapshot);
    },
  );

  test(
    'captures all live utility flags, state and artwork without dispatch',
    () {
      final snapshot = _capture(
        trackerWidgets: {'tracker-key': _tracker()},
        toggleWidgets: {42: _toggle()},
      );
      expect(_value(snapshot, 'trackerWidgets'), {
        'widgetId': 'tracker-id',
        'name': 'A renamed tracker',
        'description': 'Custom action description',
        'colorIdentity': 'RG',
        'artworkUrl': 'file:///original/tracker.png',
        'order': 4.25,
        'createdAt': _iso,
        'currentValue': 9,
        'defaultValue': 3,
        'tapIncrement': 2,
        'longPressIncrement': 7,
        'isCustom': true,
        'hasAction': true,
        'actionButtonText': 'Perform action',
        'actionType': 'future_unknown_action',
        'artworkSet': 'CUSTOM',
        'artworkOptions': _artworkJson,
        'actionOnly': true,
      });
      expect(_value(snapshot, 'toggleWidgets'), {
        'widgetId': 'toggle-id',
        'name': 'A renamed toggle',
        'colorIdentity': 'WU',
        'artworkUrl': 'file:///original/toggle.png',
        'order': 5.75,
        'createdAt': _iso,
        'isActive': true,
        'onDescription': 'On description',
        'offDescription': 'Off description',
        'onArtworkUrl': 'file:///original/on.png',
        'offArtworkUrl': 'file:///original/off.png',
        'isCustom': true,
        'artworkSet': 'CUSTOM',
        'artworkOptions': _artworkJson,
      });
    },
  );

  test('captures every deck field and all three template types', () {
    final deck = Deck(
      name: 'Saved setup',
      templates: [
        TokenTemplate(
          name: 'Template token',
          pt: '1/*',
          abilities: 'Trample',
          colors: 'BR',
          type: 'Creature',
          order: 2.5,
          artworkUrl: 'file:///original/token.png',
          artworkSet: 'CUSTOM',
          artworkOptions: _artwork(),
        ),
      ],
      trackerWidgets: [TrackerWidgetTemplate.fromWidget(_tracker())],
      toggleWidgets: [ToggleWidgetTemplate.fromWidget(_toggle())],
      colorIdentity: 'WUBRG',
      order: 11.25,
      createdAt: _instant,
      lastModifiedAt: _instant.add(const Duration(days: 1)),
      customArtworkUrl: 'file:///original/cover.png',
    );
    expect(_value(_capture(decks: {'deck-key': deck}), 'decks'), {
      'name': 'Saved setup',
      'templates': [
        {
          'name': 'Template token',
          'pt': '1/*',
          'abilities': 'Trample',
          'colors': 'BR',
          'order': 2.5,
          'type': 'Creature',
          'artworkUrl': 'file:///original/token.png',
          'artworkSet': 'CUSTOM',
          'artworkOptions': _artworkJson,
        },
      ],
      'trackerWidgets': [
        {
          'name': 'A renamed tracker',
          'description': 'Custom action description',
          'colorIdentity': 'RG',
          'artworkUrl': 'file:///original/tracker.png',
          'artworkSet': 'CUSTOM',
          'artworkOptions': _artworkJson,
          'defaultValue': 3,
          'tapIncrement': 2,
          'longPressIncrement': 7,
          'hasAction': true,
          'actionButtonText': 'Perform action',
          'actionType': 'future_unknown_action',
          'isCustom': true,
          'order': 4.25,
          'actionOnly': true,
        },
      ],
      'toggleWidgets': [
        {
          'name': 'A renamed toggle',
          'colorIdentity': 'WU',
          'artworkUrl': 'file:///original/toggle.png',
          'artworkSet': 'CUSTOM',
          'artworkOptions': _artworkJson,
          'onDescription': 'On description',
          'offDescription': 'Off description',
          'onArtworkUrl': 'file:///original/on.png',
          'offArtworkUrl': 'file:///original/off.png',
          'isCustom': true,
          'order': 5.75,
        },
      ],
      'colorIdentity': 'WUBRG',
      'order': 11.25,
      'createdAt': _iso,
      'lastModifiedAt': '2026-11-11T12:34:56.789Z',
      'customArtworkUrl': 'file:///original/cover.png',
    });
  });

  test('preserves absent optional data instead of inventing defaults', () {
    final snapshot = _capture(
      items: {0: Item(name: 'No artwork', pt: '', createdAt: _instant)},
      decks: {0: Deck(name: 'Old deck')},
      artworkPreferences: {
        0: TokenArtworkPreference(tokenIdentity: 'identity'),
      },
    );
    expect(_value(snapshot, 'items')['artworkOptions'], isNull);
    expect(_value(snapshot, 'decks'), {
      'name': 'Old deck',
      'templates': [],
      'trackerWidgets': null,
      'toggleWidgets': null,
      'colorIdentity': null,
      'order': 0.0,
      'createdAt': null,
      'lastModifiedAt': null,
      'customArtworkUrl': null,
    });
    expect(_value(snapshot, 'artworkPreferences'), {
      'tokenIdentity': 'identity',
      'lastUsedArtwork': null,
      'customArtworkPath': null,
    });
  });

  test(
    'preserves artwork preferences and all rule JSON without interpretation',
    () {
      final snapshot = _capture(
        artworkPreferences: {
          'art-key': TokenArtworkPreference(
            tokenIdentity: 'Token|1/1|G|Creature|Reach',
            lastUsedArtwork: 'https://example.test/chosen.jpg',
            customArtworkPath: 'file:///original/upload.png',
          ),
        },
        tokenRules: {'rule-key': _rule()},
      );
      expect(_value(snapshot, 'artworkPreferences'), {
        'tokenIdentity': 'Token|1/1|G|Creature|Reach',
        'lastUsedArtwork': 'https://example.test/chosen.jpg',
        'customArtworkPath': 'file:///original/upload.png',
      });
      expect(_value(snapshot, 'tokenRules'), {
        'name': 'An uninterpreted rule',
        'enabled': false,
        'order': 6.5,
        'count': 4,
        'trigger': {
          'triggerType': 'future_trigger',
          'targetTokenId': 'Token|1/1|G|Creature|Reach',
          'targetType': 'Creature',
          'targetColor': 'G',
        },
        'outcomes': [
          {
            'outcomeType': 'future_outcome',
            'multiplier': 3,
            'targetTokenId': 'Other|2/2|R|Creature|Haste',
            'quantity': 7,
          },
          {
            'outcomeType': 'multiply',
            'multiplier': 2,
            'targetTokenId': null,
            'quantity': 1,
          },
        ],
      });
    },
  );

  test(
    'retains unknown custom-token and preference fields without filtering',
    () {
      final customToken = {
        'name': 'Custom token',
        'artwork': _artworkJson,
        'reverse_related': ['Original source'],
        'future_field': {
          'value': [1, 2.5, true, null],
        },
      };
      final preferences = {
        'tokenMultiplier': 7,
        'favoriteTokens': ['id1', 'id2'],
        'artworkDisplayStyle': 'future-style',
        'unknown': {
          'nested': [null, false, 0.25],
        },
      };
      final snapshot = _capture(
        customTokens: {'original-key': jsonEncode(customToken)},
        preferences: preferences,
      );
      expect(_value(snapshot, 'customTokens'), customToken);
      expect(snapshot['preferences'], preferences);
      expect(jsonDecode(jsonEncode(snapshot)), snapshot);
    },
  );

  test(
    'later mutations cannot cross the snapshot boundary in either direction',
    () {
      final item = Item(
        name: 'Before',
        pt: '1/1',
        createdAt: _instant,
        counters: [TokenCounter(name: 'charge', amount: 2)],
        artworkOptions: _artwork(),
      );
      final deck = Deck(
        name: 'Before',
        templates: [TokenTemplate.fromItem(item)],
        trackerWidgets: [TrackerWidgetTemplate.fromWidget(_tracker())],
        toggleWidgets: [ToggleWidgetTemplate.fromWidget(_toggle())],
      );
      final tracker = _tracker();
      final toggle = _toggle();
      final rule = _rule();
      final artworkPreference = TokenArtworkPreference(tokenIdentity: 'Before');
      final nested = <String, dynamic>{
        'list': <dynamic>['before'],
      };
      final preferences = <String, dynamic>{'first': nested, 'second': nested};
      final items = <Object, Item>{1: item};
      final customTokens = <Object, String>{1: '{"name":"Before"}'};
      final snapshot = _capture(
        items: items,
        decks: {1: deck},
        trackerWidgets: {1: tracker},
        toggleWidgets: {1: toggle},
        tokenRules: {1: rule},
        artworkPreferences: {1: artworkPreference},
        customTokens: customTokens,
        preferences: preferences,
      );
      final originalJson = jsonEncode(snapshot);

      item.name = 'After';
      item.counters.single.amount = 99;
      item.artworkOptions!.clear();
      deck.templates.single.name = 'After';
      deck.trackerWidgets!.single.actionOnly = false;
      deck.toggleWidgets!.single.onDescription = 'After';
      tracker.currentValue = 99;
      toggle.isActive = false;
      rule.trigger.triggerType = 'After';
      rule.outcomes.first.quantity = 99;
      artworkPreference.tokenIdentity = 'After';
      (nested['list'] as List).add('after');
      items.clear();
      customTokens.clear();
      expect(jsonEncode(snapshot), originalJson);

      (_value(snapshot, 'items')['counters'] as List).clear();
      (snapshot['preferences']['first']['list'] as List).add('snapshot-only');
      expect(item.counters.single.amount, 99);
      expect(nested['list'], ['before', 'after']);
      expect(snapshot['preferences']['second']['list'], ['before']);
    },
  );

  test('normalizes capture and model dates to the same UTC instant', () {
    final localDate = DateTime(2026, 11, 10, 12, 34, 56, 789);
    final snapshot = _capture(
      capturedAt: localDate,
      items: {1: Item(name: 'Date', pt: '', createdAt: localDate)},
    );
    expect(snapshot['capturedAt'], localDate.toUtc().toIso8601String());
    expect(_value(snapshot, 'items')['createdAt'], snapshot['capturedAt']);
    expect(snapshot['capturedAt'], endsWith('Z'));
  });

  test(
    'rejects malformed and non-object custom tokens without dropping entries',
    () {
      for (final invalid in ['{', '[]', 'null', '1', 'true', '"token"']) {
        expect(
          () => _capture(customTokens: {'valid': '{}', 'invalid': invalid}),
          throwsFormatException,
          reason: invalid,
        );
      }
    },
  );

  test('rejects invalid source evidence and unsupported key types', () {
    expect(() => _capture(sourceId: ' '), throwsFormatException);
    expect(() => _capture(sourceVersion: ''), throwsFormatException);
    expect(() => _capture(customTokens: {1.5: '{}'}), throwsFormatException);
    expect(
      () => _capture(
        items: {true: Item(name: 'Invalid key', pt: '')},
      ),
      throwsFormatException,
    );
  });

  test('rejects non-JSON preferences and never invokes arbitrary toJson', () {
    final object = _UnexpectedJsonObject();
    final cyclic = <dynamic>[];
    cyclic.add(cyclic);
    for (final value in [
      double.nan,
      double.infinity,
      DateTime.utc(2026),
      {1: 'non-string key'},
      {'a', 'set'},
      object,
      cyclic,
    ]) {
      expect(
        () => _capture(preferences: {'unsupported': value}),
        throwsFormatException,
      );
    }
    expect(object.invoked, isFalse);
    expect(
      () => _capture(
        decks: {1: Deck(name: 'Invalid order', order: double.nan)},
      ),
      throwsFormatException,
    );
  });
}
