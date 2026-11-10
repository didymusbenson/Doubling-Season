import 'dart:collection';
import 'dart:convert';

import 'package:doubling_season/models/deck.dart';
import 'package:doubling_season/models/item.dart';
import 'package:doubling_season/models/token_artwork_preference.dart';
import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/models/token_rule.dart';
import 'package:doubling_season/models/token_template.dart';
import 'package:doubling_season/models/toggle_widget.dart';
import 'package:doubling_season/models/toggle_widget_template.dart';
import 'package:doubling_season/models/tracker_widget.dart';
import 'package:doubling_season/models/tracker_widget_template.dart';

/// Serializes a caller-owned, consistent copy of the original app's data.
///
/// The caller must supply detached models and all seven collections, including
/// empty ones. This adapter does not open storage, obtain a transaction, read
/// live boxes or preferences, or mutate any models. Taking a consistent source
/// copy and retaining the original storage are separate caller responsibilities.
///
/// Hive keys retain their integer/string type. Dates represent the same instant
/// in UTC. Preferences and custom-token JSON retain all supplied JSON fields,
/// including unknown ones. Only plain JSON values are accepted; arbitrary
/// objects' `toJson` methods are never invoked. Rule actions are data only and
/// are not interpreted or executed.
abstract final class LegacySnapshotCapture {
  static Map<String, dynamic> capture({
    required String sourceId,
    required String sourceVersion,
    required DateTime capturedAt,
    required Map<Object, Item> items,
    required Map<Object, Deck> decks,
    required Map<Object, TrackerWidget> trackerWidgets,
    required Map<Object, ToggleWidget> toggleWidgets,
    required Map<Object, TokenArtworkPreference> artworkPreferences,
    required Map<Object, String> customTokens,
    required Map<Object, TokenRule> tokenRules,
    required Map<String, dynamic> preferences,
  }) {
    if (sourceId.trim().isEmpty || sourceVersion.trim().isEmpty) {
      throw const FormatException(
        'A stable sourceId and sourceVersion evidence are required.',
      );
    }
    final snapshot = <String, dynamic>{
      'format': 'tripling-season-legacy-snapshot',
      'version': 1,
      'sourceId': sourceId,
      'sourceVersion': sourceVersion,
      'capturedAt': _date(capturedAt),
      'collections': <String, dynamic>{
        'items': _entries(items, _item),
        'decks': _entries(decks, _deck),
        'trackerWidgets': _entries(trackerWidgets, _tracker),
        'toggleWidgets': _entries(toggleWidgets, _toggle),
        'artworkPreferences': _entries(
          artworkPreferences,
          (preference) => {
            'tokenIdentity': preference.tokenIdentity,
            'lastUsedArtwork': preference.lastUsedArtwork,
            'customArtworkPath': preference.customArtworkPath,
          },
        ),
        'customTokens': _entries(customTokens, (encoded) {
          final value = jsonDecode(encoded);
          if (value is! Map<String, dynamic>) {
            throw const FormatException(
              'Each customTokens value must encode a JSON object.',
            );
          }
          return value;
        }),
        'tokenRules': _entries(tokenRules, _rule),
      },
      'preferences': preferences,
    };

    // A final recursive copy both detaches every nested collection and rejects
    // data that could not survive serialization, rather than silently losing it.
    return _copyJson(snapshot, r'$', HashSet<Object>.identity())
        as Map<String, dynamic>;
  }

  static List<Map<String, dynamic>> _entries<T>(
    Map<Object, T> source,
    Map<String, dynamic> Function(T) serialize,
  ) => [
    for (final entry in source.entries)
      {'key': _key(entry.key), 'value': serialize(entry.value)},
  ];

  static Object _key(Object key) {
    if (key is! int && key is! String) {
      throw const FormatException('Legacy keys must be integers or strings.');
    }
    return key;
  }

  static String? _date(DateTime? value) => value?.toUtc().toIso8601String();

  static List<Map<String, dynamic>>? _artwork(List<ArtworkVariant>? variants) =>
      variants
          ?.map(
            (variant) => <String, dynamic>{
              'set': variant.set,
              'url': variant.url,
              'artist': variant.artist,
            },
          )
          .toList();

  static Map<String, dynamic> _item(Item item) => {
    'abilities': item.abilities,
    'name': item.name,
    'pt': item.pt,
    'colors': item.colors,
    'amount': item.amount,
    'tapped': item.tapped,
    'summoningSick': item.summoningSick,
    'plusOneCounters': item.plusOneCounters,
    'minusOneCounters': item.minusOneCounters,
    'counters': [
      for (final counter in item.counters)
        {'name': counter.name, 'amount': counter.amount},
    ],
    'createdAt': _date(item.createdAt),
    'order': item.order,
    'type': item.type,
    'artworkUrl': item.artworkUrl,
    'artworkSet': item.artworkSet,
    'artworkOptions': _artwork(item.artworkOptions),
    'plusOnePowerCounters': item.plusOnePowerCounters,
    'plusOneToughnessCounters': item.plusOneToughnessCounters,
  };

  static Map<String, dynamic> _deck(Deck deck) => {
    'name': deck.name,
    'templates': deck.templates.map(_tokenTemplate).toList(),
    'trackerWidgets': deck.trackerWidgets?.map(_trackerTemplate).toList(),
    'toggleWidgets': deck.toggleWidgets?.map(_toggleTemplate).toList(),
    'colorIdentity': deck.colorIdentity,
    'order': deck.order,
    'createdAt': _date(deck.createdAt),
    'lastModifiedAt': _date(deck.lastModifiedAt),
    'customArtworkUrl': deck.customArtworkUrl,
  };

  static Map<String, dynamic> _tokenTemplate(TokenTemplate template) => {
    'name': template.name,
    'pt': template.pt,
    'abilities': template.abilities,
    'colors': template.colors,
    'order': template.order,
    'type': template.type,
    'artworkUrl': template.artworkUrl,
    'artworkSet': template.artworkSet,
    'artworkOptions': _artwork(template.artworkOptions),
  };

  static Map<String, dynamic> _tracker(TrackerWidget tracker) => {
    'widgetId': tracker.widgetId,
    'name': tracker.name,
    'description': tracker.description,
    'colorIdentity': tracker.colorIdentity,
    'artworkUrl': tracker.artworkUrl,
    'order': tracker.order,
    'createdAt': _date(tracker.createdAt),
    'currentValue': tracker.currentValue,
    'defaultValue': tracker.defaultValue,
    'tapIncrement': tracker.tapIncrement,
    'longPressIncrement': tracker.longPressIncrement,
    'isCustom': tracker.isCustom,
    'hasAction': tracker.hasAction,
    'actionButtonText': tracker.actionButtonText,
    'actionType': tracker.actionType,
    'artworkSet': tracker.artworkSet,
    'artworkOptions': _artwork(tracker.artworkOptions),
    'actionOnly': tracker.actionOnly,
  };

  static Map<String, dynamic> _trackerTemplate(TrackerWidgetTemplate tracker) =>
      {
        'name': tracker.name,
        'description': tracker.description,
        'colorIdentity': tracker.colorIdentity,
        'artworkUrl': tracker.artworkUrl,
        'artworkSet': tracker.artworkSet,
        'artworkOptions': _artwork(tracker.artworkOptions),
        'defaultValue': tracker.defaultValue,
        'tapIncrement': tracker.tapIncrement,
        'longPressIncrement': tracker.longPressIncrement,
        'hasAction': tracker.hasAction,
        'actionButtonText': tracker.actionButtonText,
        'actionType': tracker.actionType,
        'isCustom': tracker.isCustom,
        'order': tracker.order,
        'actionOnly': tracker.actionOnly,
      };

  static Map<String, dynamic> _toggle(ToggleWidget toggle) => {
    'widgetId': toggle.widgetId,
    'name': toggle.name,
    'colorIdentity': toggle.colorIdentity,
    'artworkUrl': toggle.artworkUrl,
    'order': toggle.order,
    'createdAt': _date(toggle.createdAt),
    'isActive': toggle.isActive,
    'onDescription': toggle.onDescription,
    'offDescription': toggle.offDescription,
    'onArtworkUrl': toggle.onArtworkUrl,
    'offArtworkUrl': toggle.offArtworkUrl,
    'isCustom': toggle.isCustom,
    'artworkSet': toggle.artworkSet,
    'artworkOptions': _artwork(toggle.artworkOptions),
  };

  static Map<String, dynamic> _toggleTemplate(ToggleWidgetTemplate toggle) => {
    'name': toggle.name,
    'colorIdentity': toggle.colorIdentity,
    'artworkUrl': toggle.artworkUrl,
    'artworkSet': toggle.artworkSet,
    'artworkOptions': _artwork(toggle.artworkOptions),
    'onDescription': toggle.onDescription,
    'offDescription': toggle.offDescription,
    'onArtworkUrl': toggle.onArtworkUrl,
    'offArtworkUrl': toggle.offArtworkUrl,
    'isCustom': toggle.isCustom,
    'order': toggle.order,
  };

  static Map<String, dynamic> _rule(TokenRule rule) => {
    'name': rule.name,
    'enabled': rule.enabled,
    'order': rule.order,
    'trigger': {
      'triggerType': rule.trigger.triggerType,
      'targetTokenId': rule.trigger.targetTokenId,
      'targetType': rule.trigger.targetType,
      'targetColor': rule.trigger.targetColor,
    },
    'outcomes': [
      for (final outcome in rule.outcomes)
        {
          'outcomeType': outcome.outcomeType,
          'multiplier': outcome.multiplier,
          'targetTokenId': outcome.targetTokenId,
          'quantity': outcome.quantity,
        },
    ],
    'count': rule.count,
  };

  static dynamic _copyJson(Object? value, String path, Set<Object> ancestors) {
    if (value == null || value is String || value is bool || value is int) {
      return value;
    }
    if (value is double && value.isFinite) return value;
    if (value is! Map && value is! List) {
      throw FormatException('Non-JSON value at $path.');
    }
    if (!ancestors.add(value)) {
      throw FormatException('Cyclic JSON collection at $path.');
    }
    try {
      if (value is List) {
        return [
          for (var index = 0; index < value.length; index++)
            _copyJson(value[index], '$path[$index]', ancestors),
        ];
      }
      final result = <String, dynamic>{};
      for (final entry in (value as Map).entries) {
        if (entry.key is! String) {
          throw FormatException('Non-string JSON property at $path.');
        }
        final key = entry.key as String;
        result[key] = _copyJson(entry.value, '$path.$key', ancestors);
      }
      return result;
    } finally {
      ancestors.remove(value);
    }
  }
}
