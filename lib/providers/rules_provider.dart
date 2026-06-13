import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/token_rule.dart';
import '../models/rule_trigger.dart';
import '../models/rule_outcome.dart';
import '../utils/constants.dart';

/// Result of evaluating rules against a token creation intent.
class TokenCreationResult {
  final String name;
  final String pt;
  final String colors;
  final String type;
  final String abilities;

  /// Composite ID to look up artwork in the token database.
  final String? tokenDatabaseId;

  final int quantity;

  /// True if the quantity was clamped to [GameConstants.maxTokenQuantity].
  final bool wasCapped;

  TokenCreationResult({
    required this.name,
    required this.pt,
    required this.colors,
    required this.type,
    required this.abilities,
    this.tokenDatabaseId,
    required this.quantity,
    this.wasCapped = false,
  });

  String get compositeId => '$name|$pt|$colors|$type|$abilities';

  /// Aggregates a rules-engine result list by token identity for DISPLAY only.
  ///
  /// The engine intentionally emits one [TokenCreationResult] per trigger event
  /// (e.g. Academy Manufactor + Chatterfang spawns a Squirrel for each of Clue,
  /// Food, Treasure independently). The TOTALS are correct, but rendering each
  /// fragment separately reads as
  /// `2 Clue + 2 Food + 2 Squirrel + 2 Treasure + 2 Squirrel + 2 Squirrel`.
  ///
  /// This collapses entries that share the exact same composite ID
  /// (`name|pt|colors|type|abilities`) into one consolidated entry, summing
  /// quantities, so it instead reads `2 Clue + 2 Food + 6 Squirrel + 2 Treasure`.
  ///
  /// Distinct tokens stay separate (Food and Treasure never merge). The order
  /// of the FIRST occurrence of each distinct token is preserved so the
  /// breakdown is not reshuffled. [wasCapped] is OR-ed across merged entries.
  ///
  /// This is display-only and must NOT be used on the token-creation path —
  /// the engine's per-event output is what the board-creation logic relies on.
  static List<TokenCreationResult> aggregateForDisplay(
    List<TokenCreationResult> results,
  ) {
    final order = <String>[];
    final byId = <String, TokenCreationResult>{};

    for (final r in results) {
      final id = r.compositeId;
      final existing = byId[id];
      if (existing == null) {
        order.add(id);
        byId[id] = r;
      } else {
        byId[id] = TokenCreationResult(
          name: existing.name,
          pt: existing.pt,
          colors: existing.colors,
          type: existing.type,
          abilities: existing.abilities,
          tokenDatabaseId: existing.tokenDatabaseId,
          quantity: existing.quantity + r.quantity,
          wasCapped: existing.wasCapped || r.wasCapped,
        );
      }
    }

    return [for (final id in order) byId[id]!];
  }

  /// Builds the consolidated "2 Clue + 2 Food + 6 Squirrel + 2 Treasure"
  /// breakdown string used by every preview surface. Aggregates by composite
  /// ID first (see [aggregateForDisplay]).
  static String breakdownString(List<TokenCreationResult> results) {
    return aggregateForDisplay(results)
        .map((r) => '${r.quantity} ${r.name}')
        .join(' + ');
  }
}

/// Internal representation of a rule during evaluation.
class _EvalRule {
  final String name;
  final RuleTrigger trigger;
  final List<RuleOutcome> outcomes;

  /// Rules with the same groupId are considered the same effect (MTG 614.5).
  /// Companion tokens created by a rule skip all other rules in the same group.
  /// Null means no grouping (each rule is independent).
  final String? groupId;

  _EvalRule({
    required this.name,
    required this.trigger,
    required this.outcomes,
    this.groupId,
  });
}

/// Rules engine for the Advanced Token Calculator.
///
/// Manages preset multipliers (persisted via SharedPreferences) and custom
/// rules (persisted via Hive). Evaluates rules to determine final token
/// creation results including multiplied quantities and companion tokens.
class RulesProvider extends ChangeNotifier {
  late Box<TokenRule> _rulesBox;
  late SharedPreferences _prefs;
  bool _initialized = false;
  bool _needsMigrationNotification = false;

  bool get initialized => _initialized;
  bool get needsMigrationNotification => _needsMigrationNotification;

  void clearMigrationNotification() {
    _needsMigrationNotification = false;
  }

  // Token presets
  int tokenDoublerCount = 0;
  int doublingSeasonCount = 0;
  int primalVigorCount = 0;
  int ojerTaqCount = 0;
  int academyManufactorCount = 0;
  int chatterfangCount = 0;

  // Counter presets
  int plusOneDoublerCount = 0;
  int plusOneExtraCount = 0;
  int allCounterDoublerCount = 0;

  /// Custom rules from Hive box, sorted by order.
  List<TokenRule> get customRules =>
      _rulesBox.values.toList()..sort((a, b) => a.order.compareTo(b.order));

  Future<void> init() async {
    _rulesBox = Hive.box<TokenRule>(DatabaseConstants.tokenRulesBox);
    _prefs = await SharedPreferences.getInstance();
    _loadPresetState();
    await _removeOldMultiplier();
    _initialized = true;
    notifyListeners();
  }

  // --- Preset persistence ---

  void _loadPresetState() {
    tokenDoublerCount =
        _prefs.getInt(PreferenceKeys.presetTokenDoublers) ?? 0;
    doublingSeasonCount =
        _prefs.getInt(PreferenceKeys.presetDoublingSeason) ?? 0;
    primalVigorCount =
        _prefs.getInt(PreferenceKeys.presetPrimalVigor) ?? 0;
    ojerTaqCount =
        _prefs.getInt(PreferenceKeys.presetOjerTaq) ?? 0;
    // Migrate old bool key to int (update-safe)
    final oldBool = _prefs.getBool(PreferenceKeys.presetAcademyManufactor);
    if (oldBool != null) {
      academyManufactorCount = oldBool ? 1 : 0;
      _prefs.remove(PreferenceKeys.presetAcademyManufactor);
      _prefs.setInt(PreferenceKeys.presetAcademyManufactorCount, academyManufactorCount);
    } else {
      academyManufactorCount =
          _prefs.getInt(PreferenceKeys.presetAcademyManufactorCount) ?? 0;
    }
    chatterfangCount =
        _prefs.getInt(PreferenceKeys.presetChatterfang) ?? 0;
    plusOneDoublerCount =
        _prefs.getInt(PreferenceKeys.presetPlusOneDoublers) ?? 0;
    plusOneExtraCount =
        _prefs.getInt(PreferenceKeys.presetPlusOneExtra) ?? 0;
    allCounterDoublerCount =
        _prefs.getInt(PreferenceKeys.presetAllCounterDoublers) ?? 0;
  }

  Future<void> _savePresetState() async {
    await _prefs.setInt(
        PreferenceKeys.presetTokenDoublers, tokenDoublerCount);
    await _prefs.setInt(
        PreferenceKeys.presetDoublingSeason, doublingSeasonCount);
    await _prefs.setInt(
        PreferenceKeys.presetPrimalVigor, primalVigorCount);
    await _prefs.setInt(PreferenceKeys.presetOjerTaq, ojerTaqCount);
    await _prefs.setInt(
        PreferenceKeys.presetAcademyManufactorCount, academyManufactorCount);
    await _prefs.setInt(
        PreferenceKeys.presetChatterfang, chatterfangCount);
    await _prefs.setInt(
        PreferenceKeys.presetPlusOneDoublers, plusOneDoublerCount);
    await _prefs.setInt(
        PreferenceKeys.presetPlusOneExtra, plusOneExtraCount);
    await _prefs.setInt(
        PreferenceKeys.presetAllCounterDoublers, allCounterDoublerCount);
    notifyListeners();
  }

  // --- Preset setters (each persists and notifies) ---

  Future<void> setTokenDoublerCount(int value) async {
    tokenDoublerCount = value.clamp(0, 20);
    await _savePresetState();
  }

  Future<void> setDoublingSeasonCount(int value) async {
    doublingSeasonCount = value.clamp(0, 20);
    await _savePresetState();
  }

  Future<void> setPrimalVigorCount(int value) async {
    primalVigorCount = value.clamp(0, 20);
    await _savePresetState();
  }

  Future<void> setOjerTaqCount(int value) async {
    ojerTaqCount = value.clamp(0, 20);
    await _savePresetState();
  }

  Future<void> setAcademyManufactorCount(int value) async {
    academyManufactorCount = value.clamp(0, 20);
    await _savePresetState();
  }

  Future<void> setChatterfangCount(int value) async {
    chatterfangCount = value.clamp(0, 20);
    await _savePresetState();
  }

  Future<void> setPlusOneDoublerCount(int value) async {
    plusOneDoublerCount = value.clamp(0, 20);
    await _savePresetState();
  }

  Future<void> setPlusOneExtraCount(int value) async {
    plusOneExtraCount = value.clamp(0, 20);
    await _savePresetState();
  }

  Future<void> setAllCounterDoublerCount(int value) async {
    allCounterDoublerCount = value.clamp(0, 20);
    await _savePresetState();
  }

  // --- Old multiplier removal ---

  /// One-time clean removal of the legacy token/counter multiplier mechanism.
  ///
  /// The old multiplier is intentionally NOT carried forward — no preset is
  /// auto-set and no custom rule is created from it. Silently maintaining a
  /// hidden multiplier is worse than a clean break; affected users are an
  /// edge case and can re-set effects in the rules calculator.
  ///
  /// Behavior:
  /// - Deletes the legacy [PreferenceKeys.tokenMultiplier] and
  ///   [PreferenceKeys.counterMultiplier] keys if present.
  /// - Shows the one-time removal notice (SnackBar) only if either old value
  ///   was a non-default value (> 1).
  /// - Runs exactly once, gated by [PreferenceKeys.rulesMigrationDone].
  /// - Resilient: absent or corrupt old keys must not crash boot. Any failure
  ///   is swallowed so resilient boot is preserved.
  Future<void> _removeOldMultiplier() async {
    try {
      final done =
          _prefs.getBool(PreferenceKeys.rulesMigrationDone) ?? false;
      if (done) return;

      // getInt returns null if the key is absent OR stored as a different
      // type (corrupt), so a missing/corrupt key falls back to the default 1.
      int oldMultiplier = 1;
      int oldCounterMult = 1;
      try {
        oldMultiplier = _prefs.getInt(PreferenceKeys.tokenMultiplier) ?? 1;
      } catch (_) {
        oldMultiplier = 1;
      }
      try {
        oldCounterMult =
            _prefs.getInt(PreferenceKeys.counterMultiplier) ?? 1;
      } catch (_) {
        oldCounterMult = 1;
      }

      if (oldMultiplier > 1 || oldCounterMult > 1) {
        _needsMigrationNotification = true;
      }

      // Safely delete the legacy keys. No presets or rules are created.
      await _prefs.remove(PreferenceKeys.tokenMultiplier);
      await _prefs.remove(PreferenceKeys.counterMultiplier);

      await _prefs.setBool(PreferenceKeys.rulesMigrationDone, true);
    } catch (e) {
      // Resilient boot: never throw. If anything goes wrong, leave prefs as-is
      // (the gate flag may not be set, so this retries next launch — harmless,
      // it only ever deletes keys and shows an optional one-time notice).
      debugPrint('RulesProvider: old multiplier removal skipped: $e');
    }
  }

  // --- Rule evaluation ---

  /// Builds the unified evaluation list: replacement rules first, then multipliers.
  ///
  /// [forceAcademyManufactorCount] forces the Academy Manufactor expansion at
  /// the given count even when the AM *preset* is off. Used by the Academy
  /// Manufactor board *utility* card, which represents physical AM copies on
  /// the battlefield and must always produce the full Food + Treasure + Clue
  /// set scaled by its own count — independent of the rules-calculator preset.
  /// The effective AM count is `max(preset, forced)` so the two never
  /// double-stack and the utility never under-produces.
  List<_EvalRule> _buildEvaluationOrder({int forceAcademyManufactorCount = 0}) {
    final rules = <_EvalRule>[];

    // 1. Custom "also_create" rules (user-reorderable)
    // Each copy of the rule is an independent effect (like having multiple copies of a card).
    for (final rule in customRules) {
      if (!rule.enabled) continue;
      final alsoCreateOutcomes = rule.outcomes
          .where((o) => o.outcomeType == 'also_create')
          .toList();
      if (alsoCreateOutcomes.isNotEmpty) {
        for (int i = 0; i < rule.count; i++) {
          rules.add(_EvalRule(
            name: rule.count > 1 ? '${rule.name} ${i + 1}' : rule.name,
            trigger: rule.trigger,
            outcomes: alsoCreateOutcomes,
            groupId: 'custom_${rule.key}',
          ));
        }
      }
    }

    // 2. Academy Manufactor (preset OR forced by the AM utility card).
    // Active at the effective count = max(preset, forced). The utility card
    // forces the expansion at its own count even when the preset is 0; the
    // preset path is unchanged when nothing is forced (forced defaults to 0).
    // See [_buildAcademyManufactorRules] for the 3^(N-1) per-trigger math.
    final effectiveAmCount =
        academyManufactorCount > forceAcademyManufactorCount
            ? academyManufactorCount
            : forceAcademyManufactorCount;
    if (effectiveAmCount > 0) {
      rules.addAll(_buildAcademyManufactorRules(effectiveAmCount));
    }

    // 3. Chatterfang preset (if enabled)
    // Any token creation also creates that many 1/1 green Squirrel creature tokens.
    // Multiple Chatterfangs each trigger independently.
    if (chatterfangCount > 0) {
      for (int i = 0; i < chatterfangCount; i++) {
        rules.add(_EvalRule(
          name: 'Chatterfang${chatterfangCount > 1 ? ' ${i + 1}' : ''}',
          trigger: RuleTrigger(triggerType: 'any_token'),
          outcomes: [
            RuleOutcome(
              outcomeType: 'also_create',
              targetTokenId: GameConstants.squirrelCompositeId,
              quantity: 1,
            ),
          ],
          groupId: 'chatterfang',
        ));
      }
    }

    // 4. Custom "replace" rules (user-reorderable)
    for (final rule in customRules) {
      if (!rule.enabled) continue;
      final replaceOutcomes = rule.outcomes
          .where((o) => o.outcomeType == 'replace')
          .toList();
      if (replaceOutcomes.isNotEmpty) {
        rules.add(_EvalRule(
          name: rule.name,
          trigger: rule.trigger,
          outcomes: replaceOutcomes,
        ));
      }
    }

    // 5. Custom "multiply" rules
    for (final rule in customRules) {
      if (!rule.enabled) continue;
      final multiplyOutcomes =
          rule.outcomes.where((o) => o.outcomeType == 'multiply').toList();
      if (multiplyOutcomes.isNotEmpty) {
        for (int i = 0; i < rule.count; i++) {
          rules.add(_EvalRule(
            name: rule.count > 1 ? '${rule.name} ${i + 1}' : rule.name,
            trigger: rule.trigger,
            outcomes: multiplyOutcomes,
          ));
        }
      }
    }

    // 6. Preset multipliers
    // Token doublers: ×2 per count (Parallel Lives, Anointed Procession, etc.)
    for (int i = 0; i < tokenDoublerCount; i++) {
      rules.add(_EvalRule(
        name: 'Token Doubler ${i + 1}',
        trigger: RuleTrigger(triggerType: 'any_token'),
        outcomes: [RuleOutcome(outcomeType: 'multiply', multiplier: 2)],
      ));
    }

    // Doubling Season: ×2 per count (affects tokens AND counters)
    for (int i = 0; i < doublingSeasonCount; i++) {
      rules.add(_EvalRule(
        name: 'Doubling Season ${i + 1}',
        trigger: RuleTrigger(triggerType: 'any_token'),
        outcomes: [RuleOutcome(outcomeType: 'multiply', multiplier: 2)],
      ));
    }

    // Primal Vigor: ×2 per count (affects tokens AND +1/+1 counters)
    for (int i = 0; i < primalVigorCount; i++) {
      rules.add(_EvalRule(
        name: 'Primal Vigor ${i + 1}',
        trigger: RuleTrigger(triggerType: 'any_token'),
        outcomes: [RuleOutcome(outcomeType: 'multiply', multiplier: 2)],
      ));
    }

    // Ojer Taq: ×3 per count (creature tokens only)
    for (int i = 0; i < ojerTaqCount; i++) {
      rules.add(_EvalRule(
        name: 'Ojer Taq ${i + 1}',
        trigger: RuleTrigger(triggerType: 'has_pt'),
        outcomes: [RuleOutcome(outcomeType: 'multiply', multiplier: 3)],
      ));
    }

    return rules;
  }

  /// Builds the Academy Manufactor eval rules for a given AM [count].
  ///
  /// When you create a Food, Treasure, or Clue token, also create the other
  /// two. Uses token_type trigger with subtype matching (.contains()) for
  /// robustness. Outcome composite IDs match real database entries for correct
  /// metadata/artwork.
  ///
  /// Academy Manufactor: N copies = 3^(N-1) of each type per trigger. Per
  /// official rulings, each AM triples the total (1 AM = 3 tokens, 2 AMs = 9,
  /// 3 AMs = 27, N AMs = 3^N total / 3^(N-1) of each type). Modeled as:
  /// multiply triggering type by 3^(N-1), then also_create the other two types
  /// (which inherit the multiplied quantity).
  ///
  /// Shared by the AM *preset* path and the AM board *utility* card so both
  /// produce identical, rules-accurate output.
  List<_EvalRule> _buildAcademyManufactorRules(int count) {
    final amMultiplier = pow(3, count - 1).toInt();
    return [
      // Food triggers: multiply Food × 3^(N-1), also create Treasure + Clue
      _EvalRule(
        name: 'Academy Manufactor (Food)',
        trigger: RuleTrigger(
          triggerType: 'token_type',
          targetType: 'Food',
        ),
        outcomes: [
          if (amMultiplier > 1)
            RuleOutcome(outcomeType: 'multiply', multiplier: amMultiplier),
          RuleOutcome(
            outcomeType: 'also_create',
            targetTokenId: GameConstants.treasureCompositeId,
            quantity: 1,
          ),
          RuleOutcome(
            outcomeType: 'also_create',
            targetTokenId: GameConstants.clueCompositeId,
            quantity: 1,
          ),
        ],
        groupId: 'academy_manufactor',
      ),
      // Treasure triggers: multiply Treasure × 3^(N-1), also create Food + Clue
      _EvalRule(
        name: 'Academy Manufactor (Treasure)',
        trigger: RuleTrigger(
          triggerType: 'token_type',
          targetType: 'Treasure',
        ),
        outcomes: [
          if (amMultiplier > 1)
            RuleOutcome(outcomeType: 'multiply', multiplier: amMultiplier),
          RuleOutcome(
            outcomeType: 'also_create',
            targetTokenId: GameConstants.foodCompositeId,
            quantity: 1,
          ),
          RuleOutcome(
            outcomeType: 'also_create',
            targetTokenId: GameConstants.clueCompositeId,
            quantity: 1,
          ),
        ],
        groupId: 'academy_manufactor',
      ),
      // Clue triggers: multiply Clue × 3^(N-1), also create Food + Treasure
      _EvalRule(
        name: 'Academy Manufactor (Clue)',
        trigger: RuleTrigger(
          triggerType: 'token_type',
          targetType: 'Clue',
        ),
        outcomes: [
          if (amMultiplier > 1)
            RuleOutcome(outcomeType: 'multiply', multiplier: amMultiplier),
          RuleOutcome(
            outcomeType: 'also_create',
            targetTokenId: GameConstants.foodCompositeId,
            quantity: 1,
          ),
          RuleOutcome(
            outcomeType: 'also_create',
            targetTokenId: GameConstants.treasureCompositeId,
            quantity: 1,
          ),
        ],
        groupId: 'academy_manufactor',
      ),
    ];
  }

  /// Evaluates all enabled rules against a token creation intent.
  ///
  /// Per MTG 614.16: companion tokens from "also_create" continue evaluation
  /// from the NEXT rule down, never re-entering from the top.
  ///
  /// Returns a list of [TokenCreationResult] with final quantities.
  ///
  /// [forceAcademyManufactorCount] forces the Academy Manufactor expansion at
  /// the given count even when the AM preset is off (used by the AM board
  /// utility card). See [_buildEvaluationOrder].
  List<TokenCreationResult> evaluateRules(
    String tokenName,
    String tokenPt,
    String tokenColors,
    String tokenType,
    String tokenAbilities,
    int quantity, {
    int forceAcademyManufactorCount = 0,
  }) {
    final rules = _buildEvaluationOrder(
      forceAcademyManufactorCount: forceAcademyManufactorCount,
    );
    if (rules.isEmpty) {
      return [
        TokenCreationResult(
          name: tokenName,
          pt: tokenPt,
          colors: tokenColors,
          type: tokenType,
          abilities: tokenAbilities,
          tokenDatabaseId: '$tokenName|$tokenPt|$tokenColors|$tokenType|$tokenAbilities',
          quantity: quantity,
        ),
      ];
    }

    return _evaluateFromIndex(
      tokenName,
      tokenPt,
      tokenColors,
      tokenType,
      tokenAbilities,
      quantity,
      rules,
      0,
    );
  }

  /// Recursively evaluates rules starting from [startIndex].
  /// Companion tokens from "also_create" continue from the next rule down.
  /// [skipGroupId] implements MTG 614.5: a replacement effect doesn't invoke
  /// itself repeatedly. Companion tokens skip rules with the same groupId
  /// as the rule that created them.
  List<TokenCreationResult> _evaluateFromIndex(
    String name,
    String pt,
    String colors,
    String type,
    String abilities,
    int quantity,
    List<_EvalRule> rules,
    int startIndex, {
    String? skipGroupId,
  }) {
    final results = <TokenCreationResult>[];
    int currentQuantity = quantity;

    for (int i = startIndex; i < rules.length; i++) {
      final rule = rules[i];

      // MTG 614.5: skip rules from the same effect that created this token
      if (skipGroupId != null &&
          rule.groupId != null &&
          rule.groupId == skipGroupId) {
        continue;
      }

      if (!_matchesTrigger(rule.trigger, name, pt, colors, type, abilities)) {
        continue;
      }

      for (final outcome in rule.outcomes) {
        if (outcome.outcomeType == 'multiply') {
          currentQuantity *= outcome.multiplier;
        } else if (outcome.outcomeType == 'replace') {
          // "Instead" effect — swap the token identity, continue down the list
          final parts = outcome.targetTokenId?.split('|');
          if (parts != null && parts.length == 5) {
            name = parts[0];
            pt = parts[1];
            colors = parts[2];
            type = parts[3];
            abilities = parts[4];
          }
        } else if (outcome.outcomeType == 'also_create') {
          // Parse the companion token from composite ID
          final parts = outcome.targetTokenId?.split('|');
          if (parts != null && parts.length == 5) {
            final companionName = parts[0];
            final companionPt = parts[1];
            final companionColors = parts[2];
            final companionType = parts[3];
            final companionAbilities = parts[4];

            // Companion continues from next rule, skipping the creating effect's group
            final companionResults = _evaluateFromIndex(
              companionName,
              companionPt,
              companionColors,
              companionType,
              companionAbilities,
              outcome.quantity * currentQuantity,
              rules,
              i + 1,
              skipGroupId: rule.groupId,
            );
            results.addAll(companionResults);
          }
        }
      }
    }

    // Clamp primary token quantity and track capping
    final bool primaryCapped = currentQuantity > GameConstants.maxTokenQuantity;
    final int clampedPrimaryQuantity = primaryCapped
        ? GameConstants.maxTokenQuantity
        : currentQuantity;

    // Add the primary token with its final quantity
    results.insert(
      0,
      TokenCreationResult(
        name: name,
        pt: pt,
        colors: colors,
        type: type,
        abilities: abilities,
        tokenDatabaseId: '$name|$pt|$colors|$type|$abilities',
        quantity: clampedPrimaryQuantity,
        wasCapped: primaryCapped,
      ),
    );

    // Clamp companion token quantities
    for (int i = 1; i < results.length; i++) {
      final r = results[i];
      if (r.quantity > GameConstants.maxTokenQuantity) {
        results[i] = TokenCreationResult(
          name: r.name,
          pt: r.pt,
          colors: r.colors,
          type: r.type,
          abilities: r.abilities,
          tokenDatabaseId: r.tokenDatabaseId,
          quantity: GameConstants.maxTokenQuantity,
          wasCapped: true,
        );
      }
    }

    return results;
  }

  /// Checks whether a trigger matches the given token properties.
  bool _matchesTrigger(
    RuleTrigger trigger,
    String name,
    String pt,
    String colors,
    String type,
    String abilities,
  ) {
    switch (trigger.triggerType) {
      case 'any_token':
        return true;
      case 'has_pt':
        return pt.isNotEmpty;
      case 'token_type':
        return type.toLowerCase().contains(trigger.targetType!.toLowerCase());
      case 'color':
        return colors.contains(trigger.targetColor!);
      case 'specific_token':
        return '$name|$pt|$colors|$type|$abilities' == trigger.targetTokenId;
      default:
        return false;
    }
  }

  // --- Counter modifier ---

  /// Calculates the final counter amount after applying all counter modifiers.
  ///
  /// [base] is the number of counters being placed.
  /// [isPlusOne] indicates +1/+1 counters (both scopes apply) vs other counters.
  int calculateCounterAmount(int base, {bool isPlusOne = true}) {
    if (isPlusOne) {
      int extra = plusOneExtraCount; // Hardened Scales family
      int plusOneDoublers = plusOneDoublerCount; // Branching Evolution family
      int allDoublers =
          allCounterDoublerCount + doublingSeasonCount; // Vorinclex + DS
      // Primal Vigor doubles +1/+1 only
      plusOneDoublers += primalVigorCount;
      return (base + extra) *
          pow(2, plusOneDoublers).toInt() *
          pow(2, allDoublers).toInt();
    } else {
      int allDoublers = allCounterDoublerCount + doublingSeasonCount;
      return base * pow(2, allDoublers).toInt();
    }
  }

  // --- Preview / query methods ---

  /// Returns what would happen if you created [quantity] of the given token.
  List<TokenCreationResult> preview(
    String name,
    String pt,
    String colors,
    String type,
    String abilities,
    int quantity,
  ) {
    return evaluateRules(name, pt, colors, type, abilities, quantity);
  }

  /// Returns a human-readable summary for a generic "1 token" preview.
  ///
  /// When companion tokens are produced, shows the consolidated per-token
  /// breakdown (identical token identities merged — see
  /// [TokenCreationResult.aggregateForDisplay]); otherwise the simple total.
  String get genericPreviewSummary {
    final results =
        evaluateRules('Generic', '1/1', '', 'Token Creature', '', 1);
    final total = results.fold<int>(0, (sum, r) => sum + r.quantity);
    if (total == 1 && results.length == 1) return 'No active rules';
    final aggregated = TokenCreationResult.aggregateForDisplay(results);
    if (aggregated.length > 1) {
      return '1 token → ${TokenCreationResult.breakdownString(results)}';
    }
    return '1 token → $total tokens';
  }

  /// Whether any rules are currently active (for FAB badge).
  bool get hasActiveRules {
    return tokenDoublerCount > 0 ||
        doublingSeasonCount > 0 ||
        primalVigorCount > 0 ||
        ojerTaqCount > 0 ||
        academyManufactorCount > 0 ||
        chatterfangCount > 0 ||
        plusOneDoublerCount > 0 ||
        plusOneExtraCount > 0 ||
        allCounterDoublerCount > 0 ||
        customRules.any((r) => r.enabled);
  }

  // --- CRUD for custom rules ---

  Future<void> addRule(TokenRule rule) async {
    await _rulesBox.add(rule);
    notifyListeners();
  }

  Future<void> updateRule(TokenRule rule) async {
    await rule.save();
    notifyListeners();
  }

  Future<void> deleteRule(TokenRule rule) async {
    await rule.delete();
    notifyListeners();
  }

  /// Clears ALL custom rules from the [tokenRules] box, with no exceptions.
  ///
  /// Called when the experimental-features flag is turned OFF — the custom
  /// rule authoring machinery is gated behind that flag, so leftover custom
  /// rules must not keep affecting token creation while it is hidden.
  ///
  /// There is no longer any preservation special-case: the legacy multiplier
  /// migration was removed entirely, so every rule in the box is a
  /// user-created custom rule and all of them are deleted. Presets are
  /// computed at runtime and are unaffected.
  Future<void> clearUserCustomRules() async {
    if (!_initialized) return;
    final toDelete = _rulesBox.values.toList();
    for (final rule in toDelete) {
      await rule.delete();
    }
    notifyListeners();
  }

  /// Disables all presets and custom rules at once.
  Future<void> disableAllRules() async {
    tokenDoublerCount = 0;
    doublingSeasonCount = 0;
    primalVigorCount = 0;
    ojerTaqCount = 0;
    academyManufactorCount = 0;
    chatterfangCount = 0;
    plusOneDoublerCount = 0;
    plusOneExtraCount = 0;
    allCounterDoublerCount = 0;
    await _savePresetState();

    for (final rule in customRules) {
      rule.enabled = false;
      await rule.save();
    }
    notifyListeners();
  }

  Future<void> reorderRules(int oldIndex, int newIndex) async {
    final rules = customRules;
    if (oldIndex < 0 ||
        oldIndex >= rules.length ||
        newIndex < 0 ||
        newIndex >= rules.length) {
      return;
    }

    // Recalculate order values based on new positions
    final movedRule = rules.removeAt(oldIndex);
    rules.insert(newIndex, movedRule);

    for (int i = 0; i < rules.length; i++) {
      rules[i].order = i.toDouble();
      await rules[i].save();
    }
    notifyListeners();
  }
}
