import 'package:flutter/material.dart';
import '../domain/table_state.dart';

/// Mirrors the original board summary in one seat's scope. Independent power
/// counters are included; variable power remains explicit instead of guessed.
class TokenBoardSummary extends StatelessWidget {
  final PlayerState player;
  const TokenBoardSummary({super.key, required this.player});
  @override
  Widget build(BuildContext context) {
    final tokens = player.tokens
        .where((t) => t.amount > 0 && !t.isEmblem)
        .toList();
    final creatures = tokens.where((t) => t.hasPowerToughness).toList();
    final artifacts = tokens
        .where((t) => t.type.toLowerCase().contains('artifact'))
        .toList();
    int sum(Iterable<TokenState> list, int Function(TokenState) count) =>
        list.fold(0, (a, b) => a + count(b));
    var power = 0, readyPower = 0;
    final variable = <String, int>{};
    for (final token in creatures) {
      final parsed = int.tryParse(token.pt.split('/').first.trim());
      if (parsed == null) {
        final key = '${token.name} (${token.pt})';
        variable[key] = (variable[key] ?? 0) + token.amount;
      } else {
        final modified =
            parsed + token.netPlusOneCounters + (token.counters['+1/+0'] ?? 0);
        power += modified * token.amount;
        readyPower += modified * token.untapped;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Board summary', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'Only this player’s tokens. Zero stacks and emblems are excluded.',
        ),
        for (final row in rows.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(child: Text(row.key)),
                Text(
                  '${row.value}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        if (variable.isNotEmpty) ...[
          const Divider(),
          const Text('Variable power — excluded from known power totals'),
          for (final entry in variable.entries)
            Text('${entry.value} × ${entry.key}'),
        ],
      ],
    );
  }
}
