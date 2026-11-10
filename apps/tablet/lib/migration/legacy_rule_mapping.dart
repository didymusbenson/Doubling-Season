import '../domain/table_state.dart';

/// Maps the persisted phone calculator, not its display labels. All sources
/// stay local: importing a single-player rule must not affect the new seats.
/// Unknown or malformed rules remain in the source inventory and block commit.
void mapLegacyRules({
  required PlayerState player,
  required Map<String, dynamic> preferences,
  required List<Map<String, dynamic>> records,
  required String Function(String collection, dynamic key) identity,
  required List<String> blockers,
  required List<String> warnings,
}) {
  const presets = {
    'preset_token_doublers': ('token_doubler', 'Token Doubler'),
    'preset_doubling_season': ('doubling_season', 'Doubling Season'),
    'preset_primal_vigor': ('primal_vigor', 'Primal Vigor'),
    'preset_ojer_taq': ('ojer_taq', 'Ojer Taq'),
    'preset_academy_manufactor_count': (
      'academy_manufactor',
      'Academy Manufactor',
    ),
    'preset_chatterfang': ('chatterfang', 'Chatterfang'),
    'preset_plus_one_doublers': ('plus_one_doubler', '+1/+1 Counter Doubler'),
    'preset_plus_one_extra': ('plus_one_extra', 'Extra +1/+1 Counter'),
    'preset_all_counter_doublers': (
      'all_counter_doubler',
      'All Counter Doubler',
    ),
  };
  for (final entry in preferences.entries) {
    if (entry.key.startsWith('preset_') &&
        !presets.containsKey(entry.key) &&
        entry.key != 'preset_academy_manufactor' &&
        entry.value != null &&
        entry.value != false &&
        entry.value != 0) {
      blockers.add('Unknown active legacy rule preference ${entry.key}.');
    }
  }
  final oldAcademy = preferences['preset_academy_manufactor'];
  if (oldAcademy != null && oldAcademy is! bool) {
    blockers.add('Legacy Academy Manufactor enabled state is not a boolean.');
  }
  for (final entry in presets.entries) {
    final raw = preferences[entry.key];
    if (raw != null && (raw is! int || raw < 0 || raw > 20)) {
      blockers.add('Legacy rule ${entry.key} has an unsupported count.');
      continue;
    }
    var count = raw as int? ?? 0;
    if (entry.key == 'preset_academy_manufactor_count' && oldAcademy is bool) {
      // Matches RulesProvider._loadPresetState: the older bool key takes
      // precedence, even when false and a newer nonzero count is also present.
      count = oldAcademy ? 1 : 0;
      if (raw != null && raw != count) {
        warnings.add(
          'Legacy Academy Manufactor boolean takes precedence over '
          'its stored count, matching the original app. Both are retained.',
        );
      }
    }
    if (raw == null &&
        !(entry.key == 'preset_academy_manufactor_count' &&
            oldAcademy is bool)) {
      continue;
    }
    player.rules.add(
      ModifierSource(
        id: identity('rulePreferences', entry.key),
        ownerPlayerId: player.id,
        definitionId: entry.value.$1,
        name: entry.value.$2,
        enabled: count > 0,
        count: count,
        global: false,
        configuration: {'legacyPreference': entry.key},
      ),
    );
  }

  // The original engine groups companion effects by the stringified Hive key.
  // Integer 1 and string "1" are distinct records but share that source group.
  // Do not silently turn them into independent replacement effects.
  final groupKeys = <String>{};
  final orders = <num>{};
  for (final record in records) {
    if (!groupKeys.add('${record['key']}')) {
      blockers.add('Legacy rules have ambiguous stringified source keys.');
    }
    final order = jsonMap(record['value'])['order'] as num? ?? 0;
    if (!orders.add(order)) {
      blockers.add(
        'Legacy rules have tied ordering; source evaluation order '
        'must be resolved before activation.',
      );
    }
  }

  for (final record in records) {
    final id = identity('tokenRules', record['key']);
    final rule = jsonMap(record['value']);
    final problem = _unsupportedRule(rule);
    if (problem != null) {
      blockers.add('Legacy rule $id $problem.');
      continue;
    }
    final trigger = jsonMap(rule['trigger']);
    player.rules.add(
      ModifierSource(
        id: id,
        ownerPlayerId: player.id,
        definitionId: 'custom',
        name: rule['name'] as String,
        enabled: rule['enabled'] as bool,
        count: rule['count'] as int,
        global: false,
        configuration: {
          ...trigger,
          'outcomes': rule['outcomes'],
          'legacy': rule,
        },
      ),
    );
  }
  for (final key in ['tokenMultiplier', 'counterMultiplier']) {
    if (preferences[key] != null && preferences[key] != 1) {
      blockers.add(
        'Legacy multiplier preference $key requires explicit '
        'source-version semantics.',
      );
    }
  }
}

String? _unsupportedRule(Map<String, dynamic> rule) {
  if (rule['name'] is! String ||
      rule['enabled'] is! bool ||
      rule['count'] is! int ||
      (rule['count'] as int) < 1 ||
      (rule['count'] as int) > 20) {
    return 'has unsupported name, enabled state or copy count';
  }
  if (rule['trigger'] is! Map) return 'has no recognized trigger';
  final trigger = jsonMap(rule['trigger']);
  for (final key in ['targetTokenId', 'targetType', 'targetColor']) {
    if (trigger[key] != null && trigger[key] is! String) {
      return 'has an invalid trigger target';
    }
  }
  bool text(dynamic value) => value is String && value.trim().isNotEmpty;
  bool tokenId(dynamic value) =>
      value is String &&
      value.split('|').length == 5 &&
      value.split('|').first.trim().isNotEmpty;
  switch (trigger['triggerType']) {
    case 'any_token':
    case 'has_pt':
      break;
    case 'token_type':
      if (!text(trigger['targetType'])) return 'has an invalid subtype trigger';
      break;
    case 'color':
      if (!text(trigger['targetColor'])) return 'has an invalid color trigger';
      break;
    case 'specific_token':
      if (!tokenId(trigger['targetTokenId'])) {
        return 'has an invalid token trigger';
      }
      break;
    default:
      return 'requires explicit trigger mapping';
  }
  if (rule['outcomes'] is! List || (rule['outcomes'] as List).isEmpty) {
    return 'has no recognized outcomes';
  }
  for (final raw in rule['outcomes'] as List) {
    if (raw is! Map) return 'has an invalid outcome';
    final outcome = jsonMap(raw);
    if (outcome['multiplier'] is! int ||
        outcome['quantity'] is! int ||
        (outcome['multiplier'] as int) < 1 ||
        (outcome['multiplier'] as int) > 1000000 ||
        (outcome['quantity'] as int) < 1 ||
        (outcome['quantity'] as int) > 1000000) {
      return 'has an unsupported outcome quantity';
    }
    switch (outcome['outcomeType']) {
      case 'multiply':
        break;
      case 'replace':
      case 'also_create':
        if (!tokenId(outcome['targetTokenId'])) {
          return 'has an invalid outcome token';
        }
        break;
      default:
        return 'requires explicit outcome mapping';
    }
  }
  return null;
}
