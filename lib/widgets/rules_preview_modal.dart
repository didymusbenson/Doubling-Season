import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rules_provider.dart';
import '../utils/constants.dart';

class RulesPreviewModal extends StatelessWidget {
  const RulesPreviewModal({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RulesPreviewModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = context.watch<RulesProvider>();

    // Build preview categories dynamically from all enabled rules
    final categories = <_PreviewCategory>[];

    // Always include generic "any token" preview
    final genericResults = rules.evaluateRules(
        'Token', '1/1', '', 'Token Creature', '', 1);
    if (genericResults.isNotEmpty) {
      categories.add(_PreviewCategory(
        label: 'Any token:',
        results: genericResults,
      ));
    }

    // Collect unique trigger categories from all enabled rules
    final seenLabels = <String>{'Any token:'};
    final triggerCategories = _collectTriggerCategories(rules);

    for (final triggerCat in triggerCategories) {
      final results = rules.evaluateRules(
        triggerCat.name,
        triggerCat.pt,
        triggerCat.colors,
        triggerCat.type,
        triggerCat.abilities,
        1,
      );
      if (results.isNotEmpty &&
          !_sameAs(results, genericResults) &&
          !seenLabels.contains(triggerCat.label)) {
        seenLabels.add(triggerCat.label);
        categories.add(_PreviewCategory(
          label: triggerCat.label,
          results: results,
        ));
      }
    }

    return AlertDialog(
      title: Row(
        children: [
          const Text('Rules Preview'),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: categories.isEmpty
            ? const Text('No active rules.')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: UIConstants.standardPadding),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return _buildCategory(context, cat);
                },
              ),
      ),
    );
  }

  Widget _buildCategory(BuildContext context, _PreviewCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: UIConstants.verticalSpacing),
        ...category.results.map((result) {
          return Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '${result.quantity} ${result.name}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }),
      ],
    );
  }

  /// Collect unique trigger categories from all enabled rules (presets + custom).
  List<_TriggerCategory> _collectTriggerCategories(RulesProvider rules) {
    final categories = <_TriggerCategory>[];
    final seen = <String>{};

    void addIfNew(_TriggerCategory cat) {
      if (seen.add(cat.label)) {
        categories.add(cat);
      }
    }

    // Check preset triggers
    if (rules.ojerTaqCount > 0) {
      addIfNew(_TriggerCategory(
        label: 'Creature with P/T:',
        name: 'Creature',
        pt: '1/1',
        colors: '',
        type: 'Token Creature',
        abilities: '',
      ));
    }

    if (rules.academyManufactorEnabled) {
      addIfNew(_TriggerCategory(
        label: 'Food:',
        name: 'Food',
        pt: '',
        colors: '',
        type: 'Artifact — Food',
        abilities: '{2}, {T}, Sacrifice this artifact: You gain 3 life.',
      ));
      addIfNew(_TriggerCategory(
        label: 'Treasure:',
        name: 'Treasure',
        pt: '',
        colors: '',
        type: 'Artifact — Treasure',
        abilities: '{T}, Sacrifice this artifact: Add one mana of any color.',
      ));
      addIfNew(_TriggerCategory(
        label: 'Clue:',
        name: 'Clue',
        pt: '',
        colors: '',
        type: 'Artifact — Clue',
        abilities: '{2}, Sacrifice this artifact: Draw a card.',
      ));
    }

    // Check custom rules for additional trigger types
    for (final rule in rules.customRules) {
      if (!rule.enabled) continue;

      switch (rule.trigger.triggerType) {
        case 'has_pt':
          addIfNew(_TriggerCategory(
            label: 'Creature with P/T:',
            name: 'Creature',
            pt: '1/1',
            colors: '',
            type: 'Token Creature',
            abilities: '',
          ));
          break;
        case 'token_type':
          final targetType = rule.trigger.targetType ?? 'Token';
          addIfNew(_TriggerCategory(
            label: '$targetType:',
            name: targetType,
            pt: '',
            colors: '',
            type: 'Token $targetType',
            abilities: '',
          ));
          break;
        case 'color':
          final targetColor = rule.trigger.targetColor ?? '';
          final colorNames = {
            'W': 'White',
            'U': 'Blue',
            'B': 'Black',
            'R': 'Red',
            'G': 'Green',
          };
          final colorName = colorNames[targetColor] ?? targetColor;
          addIfNew(_TriggerCategory(
            label: '$colorName token:',
            name: 'Token',
            pt: '1/1',
            colors: targetColor,
            type: 'Token Creature',
            abilities: '',
          ));
          break;
        case 'specific_token':
          final compositeId = rule.trigger.targetTokenId ?? '';
          final parts = compositeId.split('|');
          if (parts.length == 5) {
            addIfNew(_TriggerCategory(
              label: '${parts[0]}:',
              name: parts[0],
              pt: parts[1],
              colors: parts[2],
              type: parts[3],
              abilities: parts[4],
            ));
          }
          break;
      }
    }

    return categories;
  }

  bool _sameAs(
      List<TokenCreationResult> a, List<TokenCreationResult> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name || a[i].quantity != b[i].quantity) {
        return false;
      }
    }
    return true;
  }
}

class _TriggerCategory {
  final String label;
  final String name;
  final String pt;
  final String colors;
  final String type;
  final String abilities;

  _TriggerCategory({
    required this.label,
    required this.name,
    required this.pt,
    required this.colors,
    required this.type,
    required this.abilities,
  });
}

class _PreviewCategory {
  final String label;
  final List<TokenCreationResult> results;

  _PreviewCategory({required this.label, required this.results});
}
