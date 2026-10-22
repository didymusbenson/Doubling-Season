// Copyright © 2025 Didymus Benson. All Rights Reserved.
// Adapted from lib/providers/rules_provider.dart in this repository under the
// same repository LICENSE; arithmetic phases and per-event results retained.
import 'dart:math';
import 'package:doubling_season/models/rule_trigger.dart';
import 'package:doubling_season/models/rule_outcome.dart';
import 'package:doubling_season/providers/rules_provider.dart'
    show TokenCreationResult;
import 'package:doubling_season/utils/constants.dart';
import '../domain/table_state.dart';

/// Deterministic extraction of the phone calculator. Never opens Hive or preferences.
/// Source identity replaces Hive keys; applicability is resolved before evaluation.
class ScopedRule {
  final String key, name;
  final bool enabled;
  final int count;
  final RuleTrigger trigger;
  final List<RuleOutcome> outcomes;
  ScopedRule(ModifierSource source)
    : key = source.id,
      name = source.name,
      enabled = source.enabled,
      count = source.count,
      trigger = RuleTrigger(
        triggerType:
            source.configuration['triggerType'] as String? ?? 'any_token',
        targetTokenId: source.configuration['targetTokenId'] as String?,
        targetType: source.configuration['targetType'] as String?,
        targetColor: source.configuration['targetColor'] as String?,
      ),
      outcomes = ((source.configuration['outcomes'] as List?) ?? []).map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return RuleOutcome(
          outcomeType: m['outcomeType'] as String? ?? 'multiply',
          multiplier: (m['multiplier'] as num?)?.toInt() ?? 2,
          targetTokenId: m['targetTokenId'] as String?,
          quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        );
      }).toList();
}

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

class ScopedRulesCalculator {
  // Saturation preserves the existing nonnegative multiplication phases while
  // preventing native integer overflow or loss of precision in web builds.
  int _multiply(int a, int b) {
    if (a <= 0 || b <= 0) return 0;
    if (a > GameConstants.maxTokenQuantity ~/ b) {
      return GameConstants.maxTokenQuantity + 1;
    }
    return a * b;
  }

  int _power(int base, int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result = _multiply(result, base);
      if (result > GameConstants.maxTokenQuantity) return result;
    }
    return result;
  }

  int _remainingEvents = 10000;
  final List<ModifierSource> sources;
  ScopedRulesCalculator(Iterable<ModifierSource> sources)
    : sources = List.unmodifiable(
        sources.where((s) => s.enabled && s.count > 0),
      );
  int _count(String kind) => sources
      .where((s) => s.definitionId == kind)
      .fold(0, (n, s) => n + s.count);
  int get tokenDoublerCount => _count('token_doubler');
  int get doublingSeasonCount => _count('doubling_season');
  int get primalVigorCount => _count('primal_vigor');
  int get ojerTaqCount => _count('ojer_taq');
  int get academyManufactorCount => _count('academy_manufactor');
  int get chatterfangCount => _count('chatterfang');
  int get plusOneDoublerCount => _count('plus_one_doubler');
  int get plusOneExtraCount => _count('plus_one_extra');
  int get allCounterDoublerCount => _count('all_counter_doubler');
  List<ScopedRule> get customRules => sources
      .where((s) => s.definitionId == 'custom')
      .map(ScopedRule.new)
      .toList();
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
          rules.add(
            _EvalRule(
              name: rule.count > 1 ? '${rule.name} ${i + 1}' : rule.name,
              trigger: rule.trigger,
              outcomes: alsoCreateOutcomes,
              groupId: 'custom_${rule.key}',
            ),
          );
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
        rules.add(
          _EvalRule(
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
          ),
        );
      }
    }

    // 4. Custom "replace" rules (user-reorderable)
    for (final rule in customRules) {
      if (!rule.enabled) continue;
      final replaceOutcomes = rule.outcomes
          .where((o) => o.outcomeType == 'replace')
          .toList();
      if (replaceOutcomes.isNotEmpty) {
        rules.add(
          _EvalRule(
            name: rule.name,
            trigger: rule.trigger,
            outcomes: replaceOutcomes,
          ),
        );
      }
    }

    // 5. Custom "multiply" rules
    for (final rule in customRules) {
      if (!rule.enabled) continue;
      final multiplyOutcomes = rule.outcomes
          .where((o) => o.outcomeType == 'multiply')
          .toList();
      if (multiplyOutcomes.isNotEmpty) {
        for (int i = 0; i < rule.count; i++) {
          rules.add(
            _EvalRule(
              name: rule.count > 1 ? '${rule.name} ${i + 1}' : rule.name,
              trigger: rule.trigger,
              outcomes: multiplyOutcomes,
            ),
          );
        }
      }
    }

    // 6. Preset multipliers
    // Token doublers: ×2 per count (Parallel Lives, Anointed Procession, etc.)
    for (int i = 0; i < tokenDoublerCount; i++) {
      rules.add(
        _EvalRule(
          name: 'Token Doubler ${i + 1}',
          trigger: RuleTrigger(triggerType: 'any_token'),
          outcomes: [RuleOutcome(outcomeType: 'multiply', multiplier: 2)],
        ),
      );
    }

    // Doubling Season: ×2 per count (affects tokens AND counters)
    for (int i = 0; i < doublingSeasonCount; i++) {
      rules.add(
        _EvalRule(
          name: 'Doubling Season ${i + 1}',
          trigger: RuleTrigger(triggerType: 'any_token'),
          outcomes: [RuleOutcome(outcomeType: 'multiply', multiplier: 2)],
        ),
      );
    }

    // Primal Vigor: ×2 per count (affects tokens AND +1/+1 counters)
    for (int i = 0; i < primalVigorCount; i++) {
      rules.add(
        _EvalRule(
          name: 'Primal Vigor ${i + 1}',
          trigger: RuleTrigger(triggerType: 'any_token'),
          outcomes: [RuleOutcome(outcomeType: 'multiply', multiplier: 2)],
        ),
      );
    }

    // Ojer Taq: ×3 per count (creature tokens only)
    for (int i = 0; i < ojerTaqCount; i++) {
      rules.add(
        _EvalRule(
          name: 'Ojer Taq ${i + 1}',
          trigger: RuleTrigger(triggerType: 'has_pt'),
          outcomes: [RuleOutcome(outcomeType: 'multiply', multiplier: 3)],
        ),
      );
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
    final amMultiplier = _power(3, count - 1);
    return [
      // Food triggers: multiply Food × 3^(N-1), also create Treasure + Clue
      _EvalRule(
        name: 'Academy Manufactor (Food)',
        trigger: RuleTrigger(triggerType: 'token_type', targetType: 'Food'),
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
        trigger: RuleTrigger(triggerType: 'token_type', targetType: 'Treasure'),
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
        trigger: RuleTrigger(triggerType: 'token_type', targetType: 'Clue'),
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
    _remainingEvents = 10000;
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
          tokenDatabaseId:
              '$tokenName|$tokenPt|$tokenColors|$tokenType|$tokenAbilities',
          quantity: min(quantity, GameConstants.maxTokenQuantity),
          wasCapped: quantity > GameConstants.maxTokenQuantity,
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
    if (--_remainingEvents < 0) {
      throw StateError(
        'These custom rules generate too many separate creation events. Reduce the active rule copies. No tokens were changed.',
      );
    }
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
          currentQuantity = _multiply(currentQuantity, outcome.multiplier);
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
              _multiply(outcome.quantity, currentQuantity),
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
      return min(
        GameConstants.maxTokenQuantity,
        _multiply(
          _multiply(base + extra, _power(2, plusOneDoublers)),
          _power(2, allDoublers),
        ),
      );
    } else {
      int allDoublers = allCounterDoublerCount + doublingSeasonCount;
      return min(
        GameConstants.maxTokenQuantity,
        _multiply(base, _power(2, allDoublers)),
      );
    }
  }
}
