import 'package:flutter/material.dart';
import '../domain/table_state.dart';
import '../features/ring_service.dart';

/// Ring progress is independent of an optional bearer label in its details.
class RingInline extends StatelessWidget {
  final UtilityState utility;
  final VoidCallback onTempt;
  final Widget? trailing;
  const RingInline({
    super.key,
    required this.utility,
    required this.onTempt,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (RingService.stage(utility) == 0)
        Text(
          'Next temptation: ${RingService.reminders.first}',
          key: ValueKey('ring-next-ability-${utility.id}'),
          style: const TextStyle(fontSize: 12),
        )
      else
        for (var i = 0; i < RingService.stage(utility); i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${i + 1}. ${RingService.reminders[i]}',
              key: ValueKey('ring-active-ability-${utility.id}-$i'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      if (RingService.bearer(utility).isNotEmpty)
        Text(
          'Bearer: ${RingService.bearer(utility)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonal(
            key: ValueKey('ring-tempt-${utility.id}'),
            onPressed: onTempt,
            child: const Text('Next temptation'),
          ),
          ?trailing,
        ],
      ),
    ],
  );
}
