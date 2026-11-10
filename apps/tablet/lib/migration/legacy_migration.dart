import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:doubling_season/models/token_definition.dart';

import '../domain/table_state.dart';
import '../storage/table_repository.dart';

/// A copied, versioned inventory, not a handle to the original Hive installation.
/// Acquisition from a quiescent, backed-up installation is a separate release gate.
class LegacyMigrationSnapshot {
  static const format = 'tripling-season-legacy-snapshot';
  static const collections = [
    'items',
    'decks',
    'trackerWidgets',
    'toggleWidgets',
    'artworkPreferences',
    'customTokens',
    'tokenRules',
  ];
  final Map<String, dynamic> _json;

  LegacyMigrationSnapshot(Map<String, dynamic> json) : _json = cloneJson(json) {
    if (_json['format'] != format || _json['version'] != 1) {
      throw const FormatException('Unsupported legacy snapshot format.');
    }
    for (final key in ['sourceId', 'sourceVersion', 'capturedAt']) {
      if (_json[key] is! String || (_json[key] as String).isEmpty) {
        throw FormatException('Snapshot $key is missing.');
      }
    }
    DateTime.parse(_json['capturedAt'] as String);
    final all = jsonMap(_json['collections']);
    for (final collection in collections) {
      if (all[collection] is! List) {
        throw FormatException('Snapshot collection $collection is missing.');
      }
      final keys = <String>{};
      for (final raw in all[collection] as List) {
        final record = jsonMap(raw);
        final key = record['key'];
        if (key is! int && key is! String) {
          throw FormatException('Invalid $collection source key.');
        }
        if (!keys.add(jsonEncode(key))) {
          throw FormatException('Duplicate $collection source key.');
        }
        jsonMap(record['value']);
      }
    }
    jsonMap(_json['preferences']);
  }

  String get sourceId => _json['sourceId'] as String;
  String get digest => migrationDigest(_json);
  Map<String, dynamic> toJson() => cloneJson(_json);
}

/// Key ordering must not change snapshot identity or create duplicate migrations.
String canonicalMigrationJson(dynamic value) {
  dynamic canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  return jsonEncode(canonical(value));
}

String migrationDigest(dynamic value) =>
    sha256.convert(utf8.encode(canonicalMigrationJson(value))).toString();

void _stableOrder<T>(List<T> values, num Function(T) order) {
  final indexed = [for (var i = 0; i < values.length; i++) (values[i], i)];
  indexed.sort((a, b) {
    final comparison = order(a.$1).compareTo(order(b.$1));
    return comparison != 0 ? comparison : a.$2.compareTo(b.$2);
  });
  for (var i = 0; i < values.length; i++) {
    values[i] = indexed[i].$1;
  }
}

TokenDefinition _validateDefinition(
  Map<String, dynamic> value, {
  bool template = false,
}) {
  if (value['name'] is! String || (value['name'] as String).trim().isEmpty) {
    throw const FormatException('A legacy token definition has no valid name.');
  }
  for (final field in ['artworkUrl', 'artworkSet', 'artworkDisplayStyle']) {
    if (value[field] != null && value[field] is! String) {
      throw FormatException('Invalid legacy token $field.');
    }
  }
  return TokenDefinition.fromJson({
    ...value,
    if (template) 'artwork': value['artworkOptions'] ?? [],
  });
}

class LegacyMigrationPlan {
  final TabletState state;
  final List<String> blockers;
  final List<String> warnings;
  final Map<String, String> identities;
  LegacyMigrationPlan(
    this.state,
    this.blockers,
    this.warnings,
    this.identities,
  );
  bool get canCommit => blockers.isEmpty;
}

/// Deliberately conservative first slice. Unknown utility semantics, duplicate
/// custom counters and unsupported axis counters block activation, never vanish.
/// The complete unmodified inventory is retained separately by the journal.
class LegacyMigrationConverter {
  // Bump whenever mapping semantics or activation blockers change.
  static const mappingVersion = 1;

  LegacyMigrationPlan convert(LegacyMigrationSnapshot snapshot) {
    final raw = snapshot.toJson();
    final all = jsonMap(raw['collections']);
    final prefs = jsonMap(raw['preferences']);
    final blockers = <String>[];
    final warnings = <String>[];
    final identities = <String, String>{};
    String identity(String collection, dynamic key) {
      final source = canonicalMigrationJson([collection, key]);
      return identities.putIfAbsent(
        source,
        () => 'legacy-${migrationDigest([snapshot.sourceId, collection, key])}',
      );
    }

    List<Map<String, dynamic>> records(String collection) {
      final result = (all[collection] as List).map(jsonMap).toList();
      _stableOrder(
        result,
        (record) => (jsonMap(record['value'])['order'] as num?) ?? 0,
      );
      return result;
    }

    final profiles = List.generate(
      4,
      (i) => SeatProfile(
        id: identity('seat', i),
        name: 'Player ${i + 1}',
        color: TabletState.seatColors[i],
      ),
    );
    final state = TabletState(
      profiles: profiles,
      session: GameSession(
        id: identity('game', 0),
        startedAt: DateTime.parse(raw['capturedAt'] as String).toUtc(),
        players: List.generate(
          4,
          (i) => PlayerState(
            id: identity('player', i),
            seatId: profiles[i].id,
            slot: i,
          ),
        ),
      ),
    );
    final player = state.session.players.first;
    player.summoningSicknessEnabled =
        prefs['summoningSicknessEnabled'] as bool? ?? true;
    final style = prefs['artworkDisplayStyle'];
    if (style != null && style != 'fullView' && style != 'fadeout') {
      blockers.add('Unsupported legacy artwork display style: $style.');
    }
    String tokenDefinition(Map<String, dynamic> m) =>
        '${m['name']}|${m['pt'] ?? ''}|${m['colors'] ?? ''}|'
        '${m['type'] ?? ''}|${m['abilities'] ?? ''}';
    for (final record in records('items')) {
      final m = jsonMap(record['value']);
      _validateDefinition(m, template: true);
      final id = identity('items', record['key']);
      final counters = <String, int>{};
      for (final rawCounter in m['counters'] as List? ?? []) {
        final counter = jsonMap(rawCounter);
        final name = counter['name'] as String;
        if (counters.containsKey(name)) {
          blockers.add('Token $id has duplicate custom counter "$name".');
        } else {
          counters[name] = counter['amount'] as int;
        }
      }
      if ((m['plusOnePowerCounters'] as int? ?? 0) != 0 ||
          (m['plusOneToughnessCounters'] as int? ?? 0) != 0) {
        blockers.add(
          'Token $id needs independent power/toughness counter parity.',
        );
      }
      player.tokens.add(
        TokenState(
          id: id,
          definitionId: tokenDefinition(m),
          name: m['name'] as String,
          pt: m['pt'] as String? ?? '',
          abilities: m['abilities'] as String? ?? '',
          colors: m['colors'] as String? ?? '',
          type: m['type'] as String? ?? '',
          amount: m['amount'] as int,
          tapped: m['tapped'] as int,
          summoningSick: m['summoningSick'] as int,
          plusOneCounters: m['plusOneCounters'] as int,
          minusOneCounters: m['minusOneCounters'] as int,
          counters: counters,
          artworkUrl: m['artworkUrl'] as String?,
          artworkSet: m['artworkSet'] as String?,
          artworkOptions: (m['artworkOptions'] as List? ?? [])
              .map(jsonMap)
              .toList(),
          extra: {
            'artworkDisplayStyle': style == 'fadeout' ? 'fadeout' : 'full',
            'legacy': m,
          },
        ),
      );
    }

    Map<String, dynamic>? utility(
      Map<String, dynamic> m,
      bool toggle,
      String id,
    ) {
      if (m['name'] is! String || (m['name'] as String).trim().isEmpty) {
        throw const FormatException('A legacy utility has no valid name.');
      }
      for (final field in [
        'defaultValue',
        'tapIncrement',
        'longPressIncrement',
      ]) {
        if (m[field] != null && m[field] is! int) {
          throw FormatException('Invalid legacy utility $field.');
        }
      }
      // A mutable display name and random widgetId are not semantic identities.
      // Only explicit custom, non-action utilities are certified in this slice.
      if (m['isCustom'] != true ||
          m['hasAction'] == true ||
          m['actionOnly'] == true ||
          m['actionType'] != null) {
        blockers.add('Utility $id requires an explicit counterpart mapping.');
        return null;
      }
      if (toggle && (m['onArtworkUrl'] != null || m['offArtworkUrl'] != null)) {
        blockers.add('Utility $id requires state-specific artwork parity.');
      }
      if (!toggle &&
          (m['longPressIncrement'] as int? ?? 5) !=
              (m['tapIncrement'] as int? ?? 1)) {
        blockers.add(
          'Utility $id requires separate long-press increment parity.',
        );
      }
      return {
        'kind': toggle ? 'custom_toggle' : 'custom_tracker',
        'name': m['name'] as String,
        'description': m[toggle ? 'onDescription' : 'description'] ?? '',
        'colors': m['colorIdentity'] ?? '',
        'artworkUrl': m['artworkUrl'],
        'defaultValue': m['defaultValue'] ?? 0,
        'visible': true,
        'configuration': {...m, 'type': toggle ? 'toggle' : 'tracker'},
      };
    }

    for (final collection in ['trackerWidgets', 'toggleWidgets']) {
      final toggle = collection == 'toggleWidgets';
      for (final record in records(collection)) {
        final m = jsonMap(record['value']);
        final id = identity(collection, record['key']);
        final mapped = utility(m, toggle, id);
        if (mapped != null) {
          player.utilities.add(
            UtilityState.fromJson({
              ...mapped,
              'id': id,
              'value': toggle ? 0 : m['currentValue'] as int,
              'isActive': toggle ? m['isActive'] as bool : false,
            }),
          );
        }
      }
    }

    _stableOrder(
      player.utilities,
      (utility) => (utility.configuration['order'] as num?) ?? 0,
    );

    for (final record in records('decks')) {
      final m = jsonMap(record['value']);
      if (m['name'] is! String || (m['name'] as String).trim().isEmpty) {
        throw const FormatException('A legacy deck has no valid name.');
      }
      if (m['customArtworkUrl'] != null && m['customArtworkUrl'] is! String) {
        throw const FormatException(
          'A legacy deck cover has an invalid reference.',
        );
      }
      final id = identity('decks', record['key']);
      final tokens = (m['templates'] as List)
          .map(
            (raw) => <String, dynamic>{
              ...jsonMap(raw),
              'artworkDisplayStyle': style == 'fadeout' ? 'fadeout' : 'full',
            },
          )
          .toList();
      for (final token in tokens) {
        _validateDefinition(token, template: true);
      }
      _stableOrder(tokens, (token) => (token['order'] as num?) ?? 0);
      final utilities = <Map<String, dynamic>>[];
      for (final collection in ['trackerWidgets', 'toggleWidgets']) {
        final values = (m[collection] as List? ?? []).map(jsonMap).toList();
        for (var i = 0; i < values.length; i++) {
          final mapped = utility(
            values[i],
            collection == 'toggleWidgets',
            '$id/$collection/$i',
          );
          if (mapped != null) {
            utilities.add({...mapped, 'order': values[i]['order']});
          }
        }
      }
      _stableOrder(utilities, (utility) => (utility['order'] as num?) ?? 0);
      state.decks.add({
        'id': id,
        'name': m['name'] as String,
        'revision': 1,
        'createdAt': m['createdAt'] ?? raw['capturedAt'],
        'imageUrl': m['customArtworkUrl'],
        'tokens': tokens,
        'utilities': utilities,
        'legacy': m,
      });
    }
    final customTokens = records('customTokens');
    for (final record in customTokens) {
      final definition = _validateDefinition(jsonMap(record['value']));
      identities[canonicalMigrationJson(['customTokens', record['key']])] =
          definition.id;
    }
    state.library['customTokens'] = [
      for (final record in customTokens) record['value'],
    ];
    state.library['favorites'] = List<String>.from(
      prefs['favoriteTokens'] as List? ?? [],
    );
    state.library['recent'] = List<String>.from(
      prefs['recentTokens'] as List? ?? [],
    );
    state.library['legacyArtworkPreferences'] = records('artworkPreferences');
    state.library['legacyPreferences'] = prefs;
    state.library['legacyTokenRules'] = records('tokenRules');
    state.settings['theme'] = (prefs['useSystemTheme'] as bool? ?? true)
        ? 'system'
        : (prefs['isDarkMode'] as bool? ?? false)
        ? 'dark'
        : 'light';
    if ((all['tokenRules'] as List).isNotEmpty) {
      blockers.add('Legacy rules require explicit semantic mapping.');
    }
    if ((prefs['tokenMultiplier'] as int? ?? 1) != 1 ||
        (prefs['counterMultiplier'] as int? ?? 1) != 1) {
      blockers.add(
        'Legacy multiplier preferences require explicit rule mapping.',
      );
    }
    for (final key in const [
      'preset_token_doublers',
      'preset_doubling_season',
      'preset_primal_vigor',
      'preset_ojer_taq',
      'preset_academy_manufactor_count',
      'preset_chatterfang',
      'preset_plus_one_doublers',
      'preset_plus_one_extra',
      'preset_all_counter_doublers',
    ]) {
      if ((prefs[key] as int? ?? 0) != 0) {
        blockers.add(
          'Active legacy rule $key requires explicit semantic mapping.',
        );
      }
    }
    if (prefs['preset_academy_manufactor'] == true) {
      blockers.add(
        'Active legacy Academy Manufactor requires explicit semantic mapping.',
      );
    }
    if ((all['artworkPreferences'] as List).isNotEmpty) {
      warnings.add(
        'Global artwork defaults are retained separately; not applied to every seat.',
      );
    }
    warnings.add(
      'Four seats and 40 life are explicit fixture defaults, not recovered match data.',
    );
    warnings.add(
      'Unmapped preferences are retained; purchase ownership is not inferred from cached flags.',
    );
    validateTabletState(state);
    return LegacyMigrationPlan(state, blockers, warnings, identities);
  }
}
