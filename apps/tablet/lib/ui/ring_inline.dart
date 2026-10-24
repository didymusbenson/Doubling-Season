import 'package:flutter/material.dart';
import '../domain/table_state.dart';
import '../features/ring_service.dart';

/// A temptation chooses a bearer before committing; no silent default choice.
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
      Text(
        'Stage ${RingService.stage(utility)}/4 · ${utility.value} ${utility.value == 1 ? 'temptation' : 'temptations'}',
        style: const TextStyle(fontSize: 12),
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
            child: const Text('Tempt'),
          ),
          ?trailing,
        ],
      ),
    ],
  );
}
