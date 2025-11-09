import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class MultiplierView extends StatelessWidget {
  const MultiplierView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;

    return FloatingActionButton.extended(
      onPressed: () => _showMultiplierSheet(context),
      heroTag: 'multiplier_fab',
      icon: const Icon(Icons.calculate, size: 24),
      label: Text(
        'x$multiplier',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _showMultiplierSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _MultiplierBottomSheet(),
    );
  }
}

class _MultiplierBottomSheet extends StatefulWidget {
  const _MultiplierBottomSheet();

  @override
  State<_MultiplierBottomSheet> createState() => _MultiplierBottomSheetState();
}

class _MultiplierBottomSheetState extends State<_MultiplierBottomSheet> {
  final TextEditingController _manualInputController = TextEditingController();
  final List<int> _presets = [1, 2, 3, 4, 6, 8];

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.calculate, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Token Multiplier',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set custom multiplier for newly created tokens.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
            const SizedBox(height: 24),

            // Current value display with steppers
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: multiplier > GameConstants.minMultiplier
                          ? () => settings.setTokenMultiplier(multiplier - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      iconSize: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'x$multiplier',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => settings.setTokenMultiplier(multiplier + 1),
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Preset values
            Center(
              child: Text(
                'Quick Presets',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _presets.map((preset) {
                  final isSelected = preset == multiplier;
                  return FilterChip(
                    label: Text('x$preset'),
                    selected: isSelected,
                    onSelected: (_) => settings.setTokenMultiplier(preset),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Manual input button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showManualInput(context, settings, multiplier),
                icon: const Icon(Icons.edit),
                label: const Text('Enter Custom Value'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInput(BuildContext context, SettingsProvider settings, int multiplier) {
    _manualInputController.text = multiplier.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Multiplier'),
        content: TextField(
          controller: _manualInputController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter multiplier value',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(_manualInputController.text);
              if (value != null && value >= GameConstants.minMultiplier) {
                settings.setTokenMultiplier(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
