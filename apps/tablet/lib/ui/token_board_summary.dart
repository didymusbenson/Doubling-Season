import 'package:flutter/material.dart';
import '../domain/table_state.dart';

/// Mirrors the original board summary in one seat's scope. Independent power
/// counters are included; variable power remains explicit instead of guessed.
class TokenBoardSummary extends StatelessWidget {
  final PlayerState player;
  final bool showHeading;
  const TokenBoardSummary({
    super.key,
    required this.player,
    this.showHeading = true,
  });
  @override
  Widget build(BuildContext context) {
    final tokens = player.tokens
        .where((t) => t.amount > 0 && !t.isEmblem)
        .toList();
    final creatures = tokens.where((t) => t.hasPowerToughness).toList();
    final artifacts = tokens
        .where((t) => t.type.toLowerCase().contains('artifact'))
        .toList();
    BigInt sum(Iterable<TokenState> list, int Function(TokenState) count) =>
        list.fold(BigInt.zero, (a, b) => a + BigInt.from(count(b)));
    var power = BigInt.zero, readyPower = BigInt.zero;
    final variable = <String, int>{};
    for (final token in creatures) {
      final parsed = BigInt.tryParse(token.pt.split('/').first.trim());
      if (parsed == null) {
        final key = '${token.name} (${token.pt})';
        variable[key] = (variable[key] ?? 0) + token.amount;
      } else {
        final modified =
            parsed +
            BigInt.from(token.netPlusOneCounters) +
            BigInt.from(token.counters['+1/+0'] ?? 0);
        power += modified * BigInt.from(token.amount);
        readyPower += modified * BigInt.from(token.untapped);
      }
    }
    final rows = {
      'Tokens': sum(tokens, (t) => t.amount),
      'Creatures': sum(creatures, (t) => t.amount),
      'Untapped creatures': sum(creatures, (t) => t.untapped),
      'Tapped creatures': sum(creatures, (t) => t.tapped),
      'Summoning sick creatures': sum(creatures, (t) => t.summoningSick),
      'Known total power': power,
      'Known untapped power': readyPower,
      'Artifacts': sum(artifacts, (t) => t.amount),
      'Untapped artifacts': sum(artifacts, (t) => t.untapped),
      'Tapped artifacts': sum(artifacts, (t) => t.tapped),
      'Enchantments': sum(
        tokens.where((t) => t.type.toLowerCase().contains('enchantment')),
        (t) => t.amount,
      ),
    };
    final theme = Theme.of(context);
    Widget section(String title, List<String> labels) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: Text(label)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${rows[label]}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    final sections = [
      section('Token totals', [
        'Tokens',
        'Creatures',
        'Artifacts',
        'Enchantments',
      ]),
      section('Creature status', [
        'Untapped creatures',
        'Tapped creatures',
        'Summoning sick creatures',
      ]),
      section('Power', ['Known total power', 'Known untapped power']),
      section('Artifact status', ['Untapped artifacts', 'Tapped artifacts']),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) ...[
          Text('Board summary', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
        ],
        Text(
          'Only this player’s tokens. Zero stacks and emblems are excluded.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 480 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18;
            return Column(
              children: [
                for (var i = 0; i < sections.length; i += wide ? 2 : 1) ...[
                  if (i > 0) const SizedBox(height: 12),
                  if (wide)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: sections[i]),
                          const SizedBox(width: 12),
                          Expanded(child: sections[i + 1]),
                        ],
                      ),
                    )
                  else
                    sections[i],
                ],
              ],
            );
          },
        ),
        if (variable.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Variable power — excluded from known power totals',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          for (final entry in variable.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${entry.value} × ${entry.key}'),
            ),
        ],
      ],
    );
  }
}
