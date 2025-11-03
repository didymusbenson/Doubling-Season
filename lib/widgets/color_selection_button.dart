import 'package:flutter/material.dart';

/// Color selection button for MTG color identity (WUBRG)
/// Used in NewTokenSheet and ExpandedTokenView
class ColorSelectionButton extends StatelessWidget {
  final String symbol; // W, U, B, R, or G
  final bool isSelected;
  final Color color; // The MTG color (yellow for W, blue for U, etc.)
  final String label; // "White", "Blue", etc.
  final ValueChanged<bool> onChanged;

  const ColorSelectionButton({
    super.key,
    required this.symbol,
    required this.isSelected,
    required this.color,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Special case: White (W) uses custom colors
    final effectiveColor = symbol == 'W' ? const Color(0xFFE8DDB5) : color;

    // Use desaturated/faded color when not selected
    final displayColor = isSelected
        ? effectiveColor
        : effectiveColor.withOpacity(0.3);

    // Border colors:
    // When DISABLED: use the same desaturated color as the circle
    // When ENABLED: use a darker version of the enabled color
    final borderColor = isSelected
        ? _darkenColor(effectiveColor, 0.3)      // Darken by 30% when selected
        : effectiveColor.withOpacity(0.3);       // Match the desaturated circle when not selected

    // Text color:
    // When ENABLED: use a lightened/desaturated version (simulating disabled circle appearance)
    // When DISABLED: use grey
    // Special case: White (W) uses white text
    final textColor = isSelected
        ? (symbol == 'W' ? Colors.white : _lightenColor(effectiveColor, 0.6))
        : Colors.grey.shade400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!isSelected),
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Circle background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: displayColor,
                ),
              ),

              // Symbol text with conditional vertical adjustment
              // NOTE: The 'R' glyph in this font (w900 weight) has irregular vertical metrics
              // that cause it to appear lower than other letters. We apply a -1.5px vertical
              // offset specifically to the R to align it properly with W, U, B, and G.
              Transform.translate(
                offset: Offset(0, symbol == 'R' ? -1.5 : 0),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    height: 1.0,
                    shadows: (symbol == 'W' && isSelected) ? [
                      Shadow(
                        offset: Offset.zero,
                        blurRadius: 6.0,
                        color: _darkenColor(const Color(0xFFF0E8DC), 0.8),
                      ),
                    ] : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Border ring (always shown, color changes based on selection)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Darken a color by reducing its lightness
  /// [amount] should be between 0.0 (no change) and 1.0 (black)
  Color _darkenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness((hsl.lightness * (1 - amount)).clamp(0.0, 1.0));

    return darkened.toColor();
  }

  /// Lighten a color by increasing its lightness
  /// [amount] should be between 0.0 (no change) and 1.0 (white)
  Color _lightenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(color);
    final lightened = hsl.withLightness((hsl.lightness + (1 - hsl.lightness) * amount).clamp(0.0, 1.0));

    return lightened.toColor();
  }
}
