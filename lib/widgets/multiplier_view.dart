import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rules_provider.dart';
import 'rules_sheet.dart';

class MultiplierView extends StatelessWidget {
  const MultiplierView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RulesProvider>(
      builder: (context, rulesProvider, child) {
        final hasActive = rulesProvider.hasActiveRules;
        final label = _buildLabel(rulesProvider);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            FloatingActionButton.extended(
              onPressed: () => RulesSheet.show(context),
              heroTag: 'multiplier_fab',
              icon: const Icon(Icons.calculate, size: 24),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              extendedPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            if (hasActive)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _buildLabel(RulesProvider rulesProvider) {
    if (!rulesProvider.hasActiveRules) return 'Rules';

    // Calculate effective multiplier for a generic token
    final results = rulesProvider.evaluateRules('Generic', '1/1', '', 'Token Creature', '', 1);

    // If only quantity change (no companion tokens), show multiplier
    if (results.length == 1 && results.first.quantity > 1) {
      return '\u00d7${results.first.quantity}';
    }

    return 'Rules';
  }
}
