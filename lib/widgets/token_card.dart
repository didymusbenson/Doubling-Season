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
    final settings = context.watch<SettingsProvider>();
    final summoningSicknessEnabled = settings.summoningSicknessEnabled;

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
                    const Icon(Icons.hexagon_outlined, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${item.summoningSick}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.crop_portrait, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${item.amount - item.tapped}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.crop_landscape, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${item.tapped}',
                    style: Theme.of(context).textTheme.titleMedium,
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

            // P/T display
            if (!item.isEmblem && item.pt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: item.isPowerToughnessModified
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.formattedPowerToughness,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      )
                    : Text(
                        item.formattedPowerToughness,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
              ),
            ],

            // Quick action buttons
            const SizedBox(height: 12),
            _buildActionButtons(context, settings),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SettingsProvider settings) {
    final tokenProvider = context.read<TokenProvider>();
    final multiplier = settings.tokenMultiplier;
    final summoningSicknessEnabled = settings.summoningSicknessEnabled;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Remove button
        _buildActionButton(
          context,
          icon: Icons.remove,
          onTap: () => tokenProvider.removeTokens(item, multiplier),
          onLongPress: () => tokenProvider.removeTokens(item, item.amount),
          color: Colors.red,
        ),

        // Add button
        _buildActionButton(
          context,
          icon: Icons.add,
          onTap: () => tokenProvider.addTokens(item, multiplier, summoningSicknessEnabled),
          onLongPress: () => tokenProvider.addTokens(item, multiplier * 10, summoningSicknessEnabled),
          color: Colors.green,
        ),

        if (!item.isEmblem) ...[
          // Untap button
          _buildActionButton(
            context,
            icon: Icons.crop_portrait,
            onTap: () => tokenProvider.untapTokens(item, multiplier),
            onLongPress: () => tokenProvider.untapTokens(item, item.tapped),
            color: Colors.blue,
          ),

          // Tap button
          _buildActionButton(
            context,
            icon: Icons.crop_landscape,
            onTap: () => tokenProvider.tapTokens(item, multiplier),
            onLongPress: () => tokenProvider.tapTokens(item, item.amount - item.tapped),
            color: Colors.orange,
          ),
        ],

        // Copy button
        _buildActionButton(
          context,
          icon: Icons.content_copy,
          onTap: () => tokenProvider.copyToken(item, summoningSicknessEnabled),
          onLongPress: null,
          color: Colors.purple,
        ),

        // Scute Swarm special button
        if (item.name.toLowerCase().contains('scute swarm')) ...[
          _buildActionButton(
            context,
            icon: Icons.bug_report,
            onTap: () => tokenProvider.addTokens(item, item.amount, summoningSicknessEnabled),
            onLongPress: null,
            color: Colors.green.shade700,
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
    return GestureDetector(
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
    );
  }
}
