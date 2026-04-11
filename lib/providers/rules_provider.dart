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
}

/// Internal representation of a rule during evaluation.
class _EvalRule {
  final String name;
  final RuleTrigger trigger;
  final List<RuleOutcome> outcomes;

  _EvalRule({
    required this.name,
    required this.trigger,
    required this.outcomes,
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
  bool academyManufactorEnabled = false;

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
    await _migrateOldMultiplier();
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
    academyManufactorEnabled =
        _prefs.getBool(PreferenceKeys.presetAcademyManufactor) ?? false;
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
    await _prefs.setBool(
        PreferenceKeys.presetAcademyManufactor, academyManufactorEnabled);
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
    tokenDoublerCount = value.clamp(0, 10);
    await _savePresetState();
  }

  Future<void> setDoublingSeasonCount(int value) async {
    doublingSeasonCount = value.clamp(0, 10);
    await _savePresetState();
  }

  Future<void> setPrimalVigorCount(int value) async {
    primalVigorCount = value.clamp(0, 10);
    await _savePresetState();
  }

  Future<void> setOjerTaqCount(int value) async {
    ojerTaqCount = value.clamp(0, 10);
    await _savePresetState();
  }

  Future<void> setAcademyManufactorEnabled(bool value) async {
    academyManufactorEnabled = value;
    await _savePresetState();
  }

  Future<void> setPlusOneDoublerCount(int value) async {
    plusOneDoublerCount = value.clamp(0, 10);
    await _savePresetState();
  }

  Future<void> setPlusOneExtraCount(int value) async {
    plusOneExtraCount = value.clamp(0, 10);
    await _savePresetState();
  }

  Future<void> setAllCounterDoublerCount(int value) async {
    allCounterDoublerCount = value.clamp(0, 10);
    await _savePresetState();
  }

  // --- Migration ---

  Future<void> _migrateOldMultiplier() async {
    final migrated =
        _prefs.getBool(PreferenceKeys.rulesMigrationDone) ?? false;
    if (migrated) return;

    final oldMultiplier =
        _prefs.getInt(PreferenceKeys.tokenMultiplier) ?? 1;
    if (oldMultiplier > 1) {
      if (_isPowerOfTwo(oldMultiplier)) {
        final doublerCount = (log(oldMultiplier) / log(2)).round();
        tokenDoublerCount = doublerCount;
      } else {
        final rule = TokenRule(
          name: 'Migrated ×$oldMultiplier',
          enabled: true,
          order: 0,
          trigger: RuleTrigger(triggerType: 'any_token'),
          outcomes: [
            RuleOutcome(outcomeType: 'multiply', multiplier: oldMultiplier)
          ],
        );
        await _rulesBox.add(rule);
      }
      _needsMigrationNotification = true;
    }

    final oldCounterMult =
        _prefs.getInt(PreferenceKeys.counterMultiplier) ?? 1;
    if (oldCounterMult > 1) {
      if (_isPowerOfTwo(oldCounterMult)) {
        final doublerCount = (log(oldCounterMult) / log(2)).round();
        allCounterDoublerCount = doublerCount;
      }
      _needsMigrationNotification = true;
    }

    // Clear old keys now that migration is complete (safe — SettingsProvider getters use ?? defaults)
    await _prefs.remove(PreferenceKeys.tokenMultiplier);
    await _prefs.remove(PreferenceKeys.counterMultiplier);

    await _prefs.setBool(PreferenceKeys.rulesMigrationDone, true);
    await _savePresetState();
  }

  bool _isPowerOfTwo(int n) => n > 0 && (n & (n - 1)) == 0;

  // --- Rule evaluation ---

  /// Builds the unified evaluation list: replacement rules first, then multipliers.
  List<_EvalRule> get _evaluationOrder {
    final rules = <_EvalRule>[];

    // 1. Custom "also_create" rules (user-reorderable)
    for (final rule in customRules) {
      if (!rule.enabled) continue;
      final alsoCreateOutcomes =
          rule.outcomes.where((o) => o.outcomeType == 'also_create').toList();
      if (alsoCreateOutcomes.isNotEmpty) {
        rules.add(_EvalRule(
          name: rule.name,
          trigger: rule.trigger,
          outcomes: alsoCreateOutcomes,
        ));
      }
    }

    // 2. Academy Manufactor preset (if enabled)
    // When you create a Food, Treasure, or Clue token, also create the other two.
    // Uses token_type trigger with subtype matching (.contains()) for robustness.
    // Outcome composite IDs match real database entries for correct metadata/artwork.
    if (academyManufactorEnabled) {
      // Food triggers Treasure + Clue
      rules.add(_EvalRule(
        name: 'Academy Manufactor (Food)',
        trigger: RuleTrigger(
          triggerType: 'token_type',
          targetType: 'Food',
        ),
        outcomes: [
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
      ));
      // Treasure triggers Food + Clue
      rules.add(_EvalRule(
        name: 'Academy Manufactor (Treasure)',
        trigger: RuleTrigger(
          triggerType: 'token_type',
          targetType: 'Treasure',
        ),
        outcomes: [
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
      ));
      // Clue triggers Food + Treasure
      rules.add(_EvalRule(
        name: 'Academy Manufactor (Clue)',
        trigger: RuleTrigger(
          triggerType: 'token_type',
          targetType: 'Clue',
        ),
        outcomes: [
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
      ));
    }

    // 3. Custom "multiply" rules
    for (final rule in customRules) {
      if (!rule.enabled) continue;
      final multiplyOutcomes =
          rule.outcomes.where((o) => o.outcomeType == 'multiply').toList();
      if (multiplyOutcomes.isNotEmpty) {
        rules.add(_EvalRule(
          name: rule.name,
          trigger: rule.trigger,
          outcomes: multiplyOutcomes,
        ));
      }
    }

    // 4. Preset multipliers
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

  /// Evaluates all enabled rules against a token creation intent.
  ///
  /// Per MTG 614.16: companion tokens from "also_create" continue evaluation
  /// from the NEXT rule down, never re-entering from the top.
  ///
  /// Returns a list of [TokenCreationResult] with final quantities.
  List<TokenCreationResult> evaluateRules(
    String tokenName,
    String tokenPt,
    String tokenColors,
    String tokenType,
    String tokenAbilities,
    int quantity,
  ) {
    final rules = _evaluationOrder;
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
  /// Companion tokens from "also_create" start from startIndex + 1.
  List<TokenCreationResult> _evaluateFromIndex(
    String name,
    String pt,
    String colors,
    String type,
    String abilities,
    int quantity,
    List<_EvalRule> rules,
    int startIndex,
  ) {
    final results = <TokenCreationResult>[];
    int currentQuantity = quantity;

    for (int i = startIndex; i < rules.length; i++) {
      final rule = rules[i];
      if (!_matchesTrigger(rule.trigger, name, pt, colors, type, abilities)) {
        continue;
      }

      for (final outcome in rule.outcomes) {
        if (outcome.outcomeType == 'multiply') {
          currentQuantity *= outcome.multiplier;
        } else if (outcome.outcomeType == 'also_create') {
          // Parse the companion token from composite ID
          final parts = outcome.targetTokenId?.split('|');
          if (parts != null && parts.length == 5) {
            final companionName = parts[0];
            final companionPt = parts[1];
            final companionColors = parts[2];
            final companionType = parts[3];
            final companionAbilities = parts[4];

            // Companion starts evaluation from the NEXT rule
            final companionResults = _evaluateFromIndex(
              companionName,
              companionPt,
              companionColors,
              companionType,
              companionAbilities,
              outcome.quantity * currentQuantity,
              rules,
              i + 1,
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
  String get genericPreviewSummary {
    final results =
        evaluateRules('Generic', '1/1', '', 'Token Creature', '', 1);
    final total = results.fold<int>(0, (sum, r) => sum + r.quantity);
    if (total == 1 && results.length == 1) return 'No active rules';
    return '1 token → $total tokens';
  }

  /// Whether any rules are currently active (for FAB badge).
  bool get hasActiveRules {
    return tokenDoublerCount > 0 ||
        doublingSeasonCount > 0 ||
        primalVigorCount > 0 ||
        ojerTaqCount > 0 ||
        academyManufactorEnabled ||
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

  /// Disables all presets and custom rules at once.
  Future<void> disableAllRules() async {
    tokenDoublerCount = 0;
    doublingSeasonCount = 0;
    primalVigorCount = 0;
    ojerTaqCount = 0;
    academyManufactorEnabled = false;
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
