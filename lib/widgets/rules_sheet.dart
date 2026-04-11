import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rules_provider.dart';
import '../models/token_rule.dart';
import '../screens/rule_creator_screen.dart';
import '../utils/constants.dart';
import 'rules_preview_modal.dart';

class RulesSheet extends StatelessWidget {
  const RulesSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RulesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHeader(context),
              _buildStickyPreview(context),
              Expanded(
                child: _RulesBody(scrollController: scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
      child: Row(
        children: [
          const Icon(Icons.auto_fix_high, size: 28),
          const SizedBox(width: 12),
          Text(
            'Token Rules',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyPreview(BuildContext context) {
    final rules = context.watch<RulesProvider>();
    final summary = rules.genericPreviewSummary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(UIConstants.borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          onTap: () => RulesPreviewModal.show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rules.hasActiveRules ? summary : 'No active rules',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RulesBody extends StatelessWidget {
  final ScrollController scrollController;

  const _RulesBody({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final rules = context.watch<RulesProvider>();

    // Split custom rules by outcome type
    final alsoCreateRules = rules.customRules
        .where((r) => r.outcomes.any((o) => o.outcomeType == 'also_create'))
        .toList();
    final multiplyRules = rules.customRules
        .where((r) =>
            r.outcomes.any((o) => o.outcomeType == 'multiply') &&
            !r.outcomes.any((o) => o.outcomeType == 'also_create'))
        .toList();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        // Replacements section
        _buildSectionHeader(context, 'REPLACEMENTS'),
        const SizedBox(height: 8),
        _AcademyManufactorRow(
          enabled: rules.academyManufactorEnabled,
          onChanged: (val) => rules.setAcademyManufactorEnabled(val),
        ),
        if (alsoCreateRules.isNotEmpty) ...[
          const SizedBox(height: 4),
          _CustomRulesList(rules: alsoCreateRules),
        ],

        const SizedBox(height: 20),

        // Multipliers section
        _buildSectionHeader(context, 'MULTIPLIERS'),
        const SizedBox(height: 8),
        _PresetStepperRow(
          title: 'Token Doublers',
          subtitle:
              'Parallel Lives, Anointed Procession, Mondrak, Adrix and Nev, Elspeth Storm Slayer, Exalted Sunborn',
          count: rules.tokenDoublerCount,
          onChanged: (val) => rules.setTokenDoublerCount(val),
        ),
        const SizedBox(height: 4),
        _PresetStepperRow(
          title: 'Doubling Season',
          subtitle: 'Tokens x2 + All counters x2',
          count: rules.doublingSeasonCount,
          onChanged: (val) => rules.setDoublingSeasonCount(val),
        ),
        const SizedBox(height: 4),
        _PresetStepperRow(
          title: 'Primal Vigor',
          subtitle: 'Tokens x2 + +1/+1 counters x2',
          count: rules.primalVigorCount,
          onChanged: (val) => rules.setPrimalVigorCount(val),
        ),
        const SizedBox(height: 4),
        _PresetStepperRow(
          title: 'Ojer Taq',
          subtitle: 'Creature tokens x3',
          count: rules.ojerTaqCount,
          onChanged: (val) => rules.setOjerTaqCount(val),
        ),
        if (multiplyRules.isNotEmpty) ...[
          const SizedBox(height: 4),
          _CustomMultiplyRulesList(rules: multiplyRules),
        ],

        const SizedBox(height: 20),

        // Counter Modifiers section
        _buildCounterModifiersSection(context, rules),

        const SizedBox(height: 20),

        // Add custom rule button
        OutlinedButton.icon(
          onPressed: () => _openRuleCreator(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Custom Rule'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
            letterSpacing: 1.2,
          ),
    );
  }

  Widget _buildCounterModifiersSection(
      BuildContext context, RulesProvider rules) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        'Counter Modifiers',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      children: [
        _PresetStepperRow(
          title: '+1/+1 Doublers',
          subtitle: 'Branching Evolution, Corpsejack Menace, The Earth Crystal',
          count: rules.plusOneDoublerCount,
          onChanged: (val) => rules.setPlusOneDoublerCount(val),
        ),
        const SizedBox(height: 4),
        _PresetStepperRow(
          title: '+1/+1 Extra',
          subtitle:
              'Hardened Scales, Conclave Mentor, High Score, Ozolith, Michelangelo',
          count: rules.plusOneExtraCount,
          onChanged: (val) => rules.setPlusOneExtraCount(val),
        ),
        const SizedBox(height: 4),
        _PresetStepperRow(
          title: 'All-Counter Doublers',
          subtitle: "Vorinclex, Innkeeper's Talent L3, Loading Zone",
          count: rules.allCounterDoublerCount,
          onChanged: (val) => rules.setAllCounterDoublerCount(val),
        ),
      ],
    );
  }

  void _openRuleCreator(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const RuleCreatorScreen(),
      ),
    );
  }
}

class _AcademyManufactorRow extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _AcademyManufactorRow({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(UIConstants.borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UIConstants.standardPadding, vertical: UIConstants.smallPadding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academy Manufactor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Food, Treasure, or Clue → also create the other two',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetStepperRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final ValueChanged<int> onChanged;

  const _PresetStepperRow({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(UIConstants.borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UIConstants.standardPadding, vertical: UIConstants.smallPadding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _QuantityStepper(
              value: count,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int maxValue;

  const _QuantityStepper({
    required this.value,
    required this.onChanged,
    this.maxValue = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(UIConstants.actionButtonBorderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepButton(
            context,
            Icons.remove,
            value > 0 ? () => onChanged(value - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 20,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          _stepButton(
            context,
            Icons.add,
            value >= maxValue ? null : () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(
      BuildContext context, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
        color: onPressed == null
            ? Theme.of(context).disabledColor
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _CustomRulesList extends StatelessWidget {
  final List<TokenRule> rules;

  const _CustomRulesList({required this.rules});

  @override
  Widget build(BuildContext context) {
    final rulesProvider = context.read<RulesProvider>();

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rules.length,
      onReorder: (oldIndex, newIndex) {
        rulesProvider.reorderRules(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _CustomRuleRow(
          key: ValueKey(rule.key ?? index),
          rule: rule,
          index: index,
          onToggle: (enabled) {
            rule.enabled = enabled;
            rulesProvider.updateRule(rule);
          },
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) =>
                    RuleCreatorScreen(existingRule: rule),
              ),
            );
          },
          onDelete: () => rulesProvider.deleteRule(rule),
        );
      },
    );
  }
}

class _CustomRuleRow extends StatelessWidget {
  final TokenRule rule;
  final int index;
  final bool reorderable;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CustomRuleRow({
    super.key,
    required this.rule,
    required this.index,
    this.reorderable = true,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${rule.key}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Rule'),
                content: Text('Remove "${rule.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(UIConstants.borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                if (reorderable) ...[
                  ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                ] else
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                Switch(
                  value: rule.enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomMultiplyRulesList extends StatelessWidget {
  final List<TokenRule> rules;

  const _CustomMultiplyRulesList({required this.rules});

  @override
  Widget build(BuildContext context) {
    final rulesProvider = context.read<RulesProvider>();

    return Column(
      children: rules.map((rule) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _CustomRuleRow(
            key: ValueKey(rule.key),
            rule: rule,
            index: 0,
            reorderable: false,
            onToggle: (enabled) {
              rule.enabled = enabled;
              rulesProvider.updateRule(rule);
            },
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (context) =>
                      RuleCreatorScreen(existingRule: rule),
                ),
              );
            },
            onDelete: () => rulesProvider.deleteRule(rule),
          ),
        );
      }).toList(),
    );
  }
}
