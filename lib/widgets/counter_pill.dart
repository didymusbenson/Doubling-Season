import 'package:flutter/material.dart';

/// Simple counter display pill (for TokenCard)
class CounterPillView extends StatelessWidget {
  final String name;
  final int amount;

  const CounterPillView({
    super.key,
    required this.name,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey, // Solid background for high contrast
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white, // Inverted color scheme
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (amount > 1) ...[
            const SizedBox(width: 4),
            Text(
              '$amount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
