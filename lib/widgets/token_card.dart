import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/settings_provider.dart';
import '../providers/token_provider.dart';
import '../screens/expanded_token_screen.dart';
import 'counter_pill.dart';

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
        color: Theme.of(context).cardColor,
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
                  const Icon(Icons.aod_outlined, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${item.amount - item.tapped}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.rotate_90_degrees_cw, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${item.tapped}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ],
            ),

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

            // Action buttons and P/T in same row
            const SizedBox(height: 12),
            Row(
              children: [
                // Action buttons on the left
                Expanded(
                  child: _buildActionButtons(context, context.read<SettingsProvider>()),
                ),
                // P/T display on the right
                if (!item.isEmblem && item.pt.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  item.isPowerToughnessModified
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
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
                ],
              ],
            ),
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Remove button
        _buildActionButton(
          context,
          icon: Icons.remove,
          onTap: () => tokenProvider.removeTokens(item, 1),
          onLongPress: () => tokenProvider.removeTokens(item, item.amount),
          color: primaryColor,
        ),

        // Add button
        _buildActionButton(
          context,
          icon: Icons.add,
          onTap: () {
            // Read multiplier at callback time to get current value
            final multiplier = context.read<SettingsProvider>().tokenMultiplier;
            final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
            tokenProvider.addTokens(item, multiplier, summoningSick);
          },
          onLongPress: () {
            // Read multiplier at callback time to get current value
            final multiplier = context.read<SettingsProvider>().tokenMultiplier;
            final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
            tokenProvider.addTokens(item, multiplier * 10, summoningSick);
          },
          color: primaryColor,
        ),

        if (!item.isEmblem) ...[
          // Untap button
          _buildActionButton(
            context,
            icon: Icons.aod_outlined,
            onTap: () => tokenProvider.untapTokens(item, 1),
            onLongPress: () => tokenProvider.untapTokens(item, item.tapped),
            color: primaryColor,
          ),

          // Tap button
          _buildActionButton(
            context,
            icon: Icons.rotate_90_degrees_cw,
            onTap: () => tokenProvider.tapTokens(item, 1),
            onLongPress: () => tokenProvider.tapTokens(item, item.amount - item.tapped),
            color: primaryColor,
          ),
        ],

        // Copy button
        _buildActionButton(
          context,
          icon: Icons.content_copy,
          onTap: () {
            // Read summoningSickness at callback time to get current value
            final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
            tokenProvider.copyToken(item, summoningSick);
          },
          onLongPress: null,
          color: primaryColor,
        ),

        // Scute Swarm special button
        if (item.name.toLowerCase().contains('scute swarm')) ...[
          _buildActionButton(
            context,
            icon: Icons.bug_report,
            onTap: () {
              // Read summoningSickness at callback time to get current value
              final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
              tokenProvider.addTokens(item, item.amount, summoningSick);
            },
            onLongPress: null,
            color: primaryColor,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }
}
