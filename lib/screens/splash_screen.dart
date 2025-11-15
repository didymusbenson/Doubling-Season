import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

class SplashScreen extends StatelessWidget {
  final VoidCallback? onComplete;

  const SplashScreen({super.key, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = MediaQuery.of(context).padding;

    // Calculate optimal font size - test against longest text
    // Account for safe area insets (notches, rounded corners) plus explicit padding
    final availableWidth = screenWidth - padding.left - padding.right - 48.0; // Extra margin for safety
    final fontSize = _calculateFontSize(availableWidth);

    return GestureDetector(
      onTap: onComplete,
      child: Scaffold(
        body: Column(
          children: [
            _buildColorBar(
              text: 'angels&',
              color: ColorUtils.getColorsForIdentity('W').first,
              fontSize: fontSize,
            ),
            _buildColorBar(
              text: 'merfolk&',
              color: ColorUtils.getColorsForIdentity('U').first,
              fontSize: fontSize,
            ),
            _buildColorBar(
              text: 'zombies&',
              color: ColorUtils.getColorsForIdentity('B').first,
              fontSize: fontSize,
            ),
            _buildColorBar(
              text: 'goblins&',
              color: ColorUtils.getColorsForIdentity('R').first,
              fontSize: fontSize,
            ),
            _buildColorBar(
              text: 'elves&',
              color: ColorUtils.getColorsForIdentity('G').first,
              fontSize: fontSize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorBar({
    required String text,
    required Color color,
    required double fontSize,
  }) {
    return Expanded(
      child: Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.only(right: 4.0),
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  double _calculateFontSize(double availableWidth) {
    // Test against longest strings: "merfolk&" and "zombies&" (both 8 chars)
    const testText = 'merfolk&';

    // Start with a large font size and work down
    double fontSize = 200.0;

    while (fontSize > 20.0) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: testText,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      if (textPainter.width <= availableWidth) {
        return fontSize;
      }

      fontSize -= 2.0;
    }

    return fontSize;
  }
}
