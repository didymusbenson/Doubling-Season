import 'package:flutter/material.dart';
import '../utils/constants.dart';

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
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.counterPillHorizontalPadding,
        vertical: UIConstants.counterPillVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(UIConstants.counterPillBorderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: UIConstants.counterPillFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (amount > 1) ...[
            const SizedBox(width: UIConstants.counterPillSpacing),
            Text(
              '$amount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: UIConstants.counterPillAmountFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
