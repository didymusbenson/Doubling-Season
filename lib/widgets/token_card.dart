import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/settings_provider.dart';
import '../providers/token_provider.dart';
import '../screens/expanded_token_screen.dart';
import 'counter_pill.dart';
import 'split_stack_sheet.dart';

class TokenCard extends StatelessWidget {
  final Item item;

  const TokenCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when summoningSicknessEnabled changes
    // This prevents rebuilds when multiplier changes
    return Selector<SettingsProvider, bool>(
      selector: (context, settings) => settings.summoningSicknessEnabled,
      builder: (context, summoningSicknessEnabled, child) {
        return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ExpandedTokenScreen(item: item),
          ),
        );
      },
      child: Opacity(
      opacity: item.amount == 0 ? 0.5 : 1.0,
      child: Container(
        color: Colors.transparent, // Background handled by parent Container in ContentScreen
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row - name, summoning sickness, tapped/untapped
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: item.isEmblem ? TextAlign.center : TextAlign.left,
                  ),
                ),
                if (!item.isEmblem) ...[
                  if (item.summoningSick > 0 && summoningSicknessEnabled) ...[
                    const Icon(Icons.adjust, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${item.summoningSick}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.screenshot, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${item.amount - item.tapped}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.screen_rotation, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${item.tapped}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ],
            ),

            // Type
            if (item.type.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.type,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                textAlign: item.isEmblem ? TextAlign.center : TextAlign.left,
              ),
            ],

            // Counter pills
            if (item.counters.isNotEmpty ||
                item.plusOneCounters > 0 ||
                item.minusOneCounters > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ...item.counters.map(
                    (c) => CounterPillView(name: c.name, amount: c.amount),
                  ),
                  if (item.plusOneCounters > 0)
                    CounterPillView(
                      name: '+1/+1',
                      amount: item.plusOneCounters,
                    ),
                  if (item.minusOneCounters > 0)
                    CounterPillView(
                      name: '-1/-1',
                      amount: item.minusOneCounters,
                    ),
                ],
              ),
            ],

            // Abilities
            if (item.abilities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.abilities,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: item.isEmblem ? TextAlign.center : TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // P/T Row (new dedicated row)
            if (!item.isEmblem && item.pt.isNotEmpty) ...[
              Container(
                width: double.infinity,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(bottom: 8),
                child: item.isPowerToughnessModified
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.formattedPowerToughness,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      )
                    : Text(
                        item.formattedPowerToughness,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
              ),
            ],

            // Button Row (centered)
            _buildActionButtons(context, context.read<SettingsProvider>()),
          ],
        ),
      ),
      ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, SettingsProvider settings) {
    final tokenProvider = context.read<TokenProvider>();
    final summoningSicknessEnabled = settings.summoningSicknessEnabled;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Count how many buttons will be displayed
    int buttonCount = 2; // Remove and Add are always present

    if (!item.isEmblem) {
      buttonCount += 2; // Untap and Tap
      if (summoningSicknessEnabled) {
        buttonCount += 1; // Clear SS (always shown when enabled)
      }
    }

    buttonCount += 1; // Copy is always present
    buttonCount += 1; // Split (always shown)

    if (item.name.toLowerCase().contains('scute swarm')) {
      buttonCount += 1; // Scute Swarm
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive spacing
        // Button internal padding: 8px on all sides = 16px total width overhead per button
        // Icon size: 20px
        // Border width: 1.5px on each side = 3px total
        // Total button width: 8 + 20 + 8 + 3 = 39px
        const double buttonInternalWidth = 39.0;

        // Calculate total width needed for all buttons without spacing
        final double totalButtonWidth = buttonCount * buttonInternalWidth;

        // Available width for spacing between buttons
        final double availableSpacingWidth = constraints.maxWidth - totalButtonWidth;

        // Spacing between buttons (n buttons need n-1 spaces)
        final double spacing = buttonCount > 1
            ? (availableSpacingWidth / (buttonCount - 1)).clamp(4.0, 8.0)
            : 0.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Remove button
            _buildActionButton(
              context,
              icon: Icons.remove,
              onTap: () => tokenProvider.removeTokens(item, 1),
              onLongPress: () => tokenProvider.removeTokens(item, item.amount),
              color: primaryColor,
              spacing: spacing,
            ),

            // Add button
            _buildActionButton(
              context,
              icon: Icons.add,
              onTap: () {
                final multiplier = context.read<SettingsProvider>().tokenMultiplier;
                final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                tokenProvider.addTokens(item, multiplier, summoningSick);
              },
              onLongPress: () {
                final multiplier = context.read<SettingsProvider>().tokenMultiplier;
                final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                tokenProvider.addTokens(item, multiplier * 10, summoningSick);
              },
              color: primaryColor,
              spacing: spacing,
            ),

            if (!item.isEmblem) ...[
              // Untap button
              _buildActionButton(
                context,
                icon: Icons.screenshot,
                onTap: () => tokenProvider.untapTokens(item, 1),
                onLongPress: () => tokenProvider.untapTokens(item, item.tapped),
                color: primaryColor,
                spacing: spacing,
              ),

              // Tap button
              _buildActionButton(
                context,
                icon: Icons.screen_rotation,
                onTap: () => tokenProvider.tapTokens(item, 1),
                onLongPress: () => tokenProvider.tapTokens(item, item.amount - item.tapped),
                color: primaryColor,
                spacing: spacing,
              ),

              // Clear Summoning Sickness button (always shown when enabled, disabled if nothing to clear)
              if (summoningSicknessEnabled)
                _buildActionButton(
                  context,
                  icon: Icons.adjust,
                  onTap: item.summoningSick > 0 ? () {
                    item.summoningSick = 0;
                    tokenProvider.updateItem(item);
                  } : null,
                  onLongPress: null,
                  color: primaryColor,
                  spacing: spacing,
                  disabled: item.summoningSick == 0,
                ),
            ],

            // Copy button
            _buildActionButton(
              context,
              icon: Icons.content_copy,
              onTap: () {
                final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                tokenProvider.copyToken(item, summoningSick);
              },
              onLongPress: null,
              color: primaryColor,
              spacing: spacing,
            ),

            // Split Stack button (always shown, disabled if 1 or fewer tokens)
            _buildActionButton(
              context,
              icon: Icons.call_split,
              onTap: item.amount > 1 ? () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => SplitStackSheet(
                    item: item,
                    onSplitCompleted: () {
                      Navigator.of(context).pop();
                    },
                  ),
                );
              } : null,
              onLongPress: null,
              color: primaryColor,
              spacing: spacing,
              disabled: item.amount <= 1,
            ),

            // Scute Swarm special button (last button gets 0 spacing)
            if (item.name.toLowerCase().contains('scute swarm'))
              _buildActionButton(
                context,
                icon: Icons.bug_report,
                onTap: () {
                  final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
                  tokenProvider.addTokens(item, item.amount, summoningSick);
                },
                onLongPress: null,
                color: primaryColor,
                spacing: 0, // Last button gets no trailing space
              ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    required Color color,
    required double spacing,
    bool disabled = false,
  }) {
    final effectiveColor = disabled ? color.withOpacity(0.3) : color;

    return Padding(
      padding: EdgeInsets.only(right: spacing),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        onLongPress: disabled ? null : onLongPress,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: effectiveColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: effectiveColor, width: 1.5),
          ),
          child: Icon(
            icon,
            color: effectiveColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}
