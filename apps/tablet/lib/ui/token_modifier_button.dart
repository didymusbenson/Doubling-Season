import 'package:flutter/material.dart';

import '../domain/table_state.dart';
import '../services/scoped_rules_calculator.dart';

/// The original board's calculator entry, scoped to one table player. This
/// preview is descriptive only; creation still uses the full scoped rules.
class TokenModifierButton extends StatelessWidget {
  final String playerName;
  final List<ModifierSource> sources;
  final bool extended;
  final VoidCallback onPressed;

  const TokenModifierButton({
    super.key,
    required this.playerName,
    required this.sources,
    required this.extended,
    required this.onPressed,
  });

  String _label(List<ModifierSource> active) {
    if (active.isEmpty) return 'Rules';
    // Complex custom outcomes and companion-token trees are not a single
    // multiplier. Avoid evaluating those graphs on each board repaint.
    if (active.any(
      (source) => {'custom', 'chatterfang'}.contains(source.definitionId),
    )) {
      return 'Rules';
    }
    final results = ScopedRulesCalculator(active).evaluateRules(
      'Generic', '1/1', '', 'Token Creature', '', 1,
    );
    return results.length == 1 &&
        !results.first.wasCapped &&
        results.first.quantity > 1
        ? '×${results.first.quantity}'
        : 'Rules';
  }

  @override
  Widget build(BuildContext context) {
    final active = sources.where((s) => s.enabled && s.count > 0).toList();
    final label = _label(active);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '$playerName, token modifiers',
      value: '${active.length} active modifier sources'
          '${label.startsWith('×') ? ', creature token preview $label' : ''}',
      button: true,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        elevation: 3,
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calculate, size: 22,
                        color: colors.onPrimaryContainer),
                      if (extended) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.onPrimaryContainer,
                              )),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (active.isNotEmpty)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    key: const ValueKey('active-token-modifiers'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
