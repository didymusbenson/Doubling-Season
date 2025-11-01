import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradient_borders/gradient_borders.dart';
import '../models/item.dart';
import '../providers/settings_provider.dart';
import '../utils/color_utils.dart';
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
          border: GradientBoxBorder(
            gradient: LinearGradient(
              colors: ColorUtils.getColorsForIdentity(item.colors),
            ),
            width: 3,
          ),
        ),
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
          ],
        ),
      ),
      ),
    );
  }
}
