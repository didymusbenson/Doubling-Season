import 'package:flutter/material.dart';
import '../models/item.dart';

class StatusSheet extends StatelessWidget {
  final List<Item> items;

  const StatusSheet({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Board Status',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Total Tokens Card
                  _buildStatCard(
                    context: context,
                    title: 'Total Tokens',
                    content: Text(
                      '${stats.totalTokens}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Creatures Card
                  if (stats.totalCreatures > 0)
                    _buildStatCard(
                      context: context,
                      title: 'Creatures',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stats.totalCreatures} total',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          _buildStatRow(
                            context,
                            'Untapped',
                            '${stats.creaturesUntapped}',
                          ),
                          _buildStatRow(
                            context,
                            'Tapped',
                            '${stats.creaturesTapped}',
                          ),
                          if (stats.creaturesSummoningSick > 0)
                            _buildStatRow(
                              context,
                              'Summoning Sick',
                              '${stats.creaturesSummoningSick}',
                            ),
                        ],
                      ),
                    ),

                  if (stats.totalCreatures > 0) const SizedBox(height: 16),

                  // Power Card
                  if (stats.totalCreatures > 0)
                    _buildStatCard(
                      context: context,
                      title: 'Power',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatRow(
                            context,
                            'Total Power',
                            stats.totalPower > 0 ? '${stats.totalPower}' : '—',
                          ),
                          _buildStatRow(
                            context,
                            'Total Untapped Power',
                            stats.totalUntappedPower > 0 ? '${stats.totalUntappedPower}' : '—',
                          ),
                          if (stats.variablePowerTokens.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'untracked',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: stats.variablePowerTokens.entries.map((entry) {
                                      final parts = entry.key.split('|');
                                      final basePT = parts[0];
                                      final name = parts[1];
                                      final count = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '• $count $basePT $name',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                  if (stats.totalCreatures > 0) const SizedBox(height: 16),

                  // Artifacts Card
                  if (stats.totalArtifacts > 0)
                    _buildStatCard(
                      context: context,
                      title: 'Artifacts',
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stats.totalArtifacts} total',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          _buildStatRow(
                            context,
                            'Untapped',
                            '${stats.artifactsUntapped}',
                          ),
                          _buildStatRow(
                            context,
                            'Tapped',
                            '${stats.artifactsTapped}',
                          ),
                        ],
                      ),
                    ),

                  if (stats.totalArtifacts > 0) const SizedBox(height: 16),

                  // Enchantments Card
                  if (stats.totalEnchantments > 0)
                    _buildStatCard(
                      context: context,
                      title: 'Enchantments',
                      content: Text(
                        '${stats.totalEnchantments}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required Widget content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  _BoardStats _calculateStats() {
    int totalTokens = 0;
    int totalCreatures = 0;
    int creaturesUntapped = 0;
    int creaturesTapped = 0;
    int creaturesSummoningSick = 0;
    int totalPower = 0;
    int totalUntappedPower = 0;
    int totalArtifacts = 0;
    int artifactsUntapped = 0;
    int artifactsTapped = 0;
    int totalEnchantments = 0;

    // Map for variable power deduplication: "basePT|name" -> count
    final Map<String, int> variablePowerTokens = {};

    // Single pass iteration through all items
    for (final item in items) {
      // Skip zero-amount stacks
      if (item.amount <= 0) continue;

      // Skip emblems from all calculations
      if (item.isEmblem) continue;

      // Count total tokens
      totalTokens += item.amount;

      // Detect creatures (by P/T presence)
      if (item.hasPowerToughness) {
        totalCreatures += item.amount;
        creaturesUntapped += (item.amount - item.tapped);
        creaturesTapped += item.tapped;
        creaturesSummoningSick += item.summoningSick;

        // Parse power/toughness
        final parts = item.pt.split('/');
        if (parts.length == 2) {
          final basePowerStr = parts[0].trim();
          final basePower = int.tryParse(basePowerStr);

          if (basePower != null) {
            // Calculable power - include counter bonuses
            final modifiedPower = basePower + item.netPlusOneCounters;
            totalPower += modifiedPower * item.amount;
            totalUntappedPower += modifiedPower * (item.amount - item.tapped);
          } else {
            // Variable power - track for untracked display
            final key = '${item.pt}|${item.name}';
            variablePowerTokens[key] = (variablePowerTokens[key] ?? 0) + item.amount;
          }
        }
      }

      // Detect artifacts (by type line)
      final typeLower = item.type.toLowerCase();
      if (typeLower.contains('artifact')) {
        totalArtifacts += item.amount;
        artifactsUntapped += (item.amount - item.tapped);
        artifactsTapped += item.tapped;
      }

      // Detect enchantments (by type line)
      if (typeLower.contains('enchantment')) {
        totalEnchantments += item.amount;
      }
    }

    return _BoardStats(
      totalTokens: totalTokens,
      totalCreatures: totalCreatures,
      creaturesUntapped: creaturesUntapped,
      creaturesTapped: creaturesTapped,
      creaturesSummoningSick: creaturesSummoningSick,
      totalPower: totalPower,
      totalUntappedPower: totalUntappedPower,
      totalArtifacts: totalArtifacts,
      artifactsUntapped: artifactsUntapped,
      artifactsTapped: artifactsTapped,
      totalEnchantments: totalEnchantments,
      variablePowerTokens: variablePowerTokens,
    );
  }
}

class _BoardStats {
  final int totalTokens;
  final int totalCreatures;
  final int creaturesUntapped;
  final int creaturesTapped;
  final int creaturesSummoningSick;
  final int totalPower;
  final int totalUntappedPower;
  final int totalArtifacts;
  final int artifactsUntapped;
  final int artifactsTapped;
  final int totalEnchantments;
  final Map<String, int> variablePowerTokens;

  _BoardStats({
    required this.totalTokens,
    required this.totalCreatures,
    required this.creaturesUntapped,
    required this.creaturesTapped,
    required this.creaturesSummoningSick,
    required this.totalPower,
    required this.totalUntappedPower,
    required this.totalArtifacts,
    required this.artifactsUntapped,
    required this.artifactsTapped,
    required this.totalEnchantments,
    required this.variablePowerTokens,
  });
}
