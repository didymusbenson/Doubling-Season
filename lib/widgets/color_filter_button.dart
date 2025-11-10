import 'package:flutter/material.dart';

/// Color filter button for token search (WUBRGC)
/// Used in TokenSearchScreen to filter tokens by exact color identity
class ColorFilterButton extends StatelessWidget {
  final String symbol; // W, U, B, R, G, or C
  final bool isSelected;
  final VoidCallback onTap;

  const ColorFilterButton({
    super.key,
    required this.symbol,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorData = _getColorData(symbol);

    // Use full color when selected, desaturated when not
    final displayColor = isSelected
        ? colorData.color
        : colorData.color.withValues(alpha: 0.3);

    final borderColor = isSelected
        ? _darkenColor(colorData.color, 0.3)
        : colorData.color.withValues(alpha: 0.3);

    final textColor = isSelected
        ? colorData.textColor
        : Colors.grey.shade400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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

              // Symbol text with conditional vertical adjustment for R
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

              // Border ring
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

  _ColorData _getColorData(String symbol) {
    switch (symbol) {
      case 'W':
        return _ColorData(
          color: const Color(0xFFE8DDB5),
          textColor: Colors.white,
        );
      case 'U':
        return _ColorData(
          color: Colors.blue,
          textColor: _lightenColor(Colors.blue, 0.6),
        );
      case 'B':
        return _ColorData(
          color: Colors.purple,
          textColor: _lightenColor(Colors.purple, 0.6),
        );
      case 'R':
        return _ColorData(
          color: Colors.red,
          textColor: _lightenColor(Colors.red, 0.6),
        );
      case 'G':
        return _ColorData(
          color: Colors.green,
          textColor: _lightenColor(Colors.green, 0.6),
        );
      case 'C':
        return _ColorData(
          color: Colors.grey.shade600,
          textColor: _lightenColor(Colors.grey.shade600, 0.6),
        );
      default:
        return _ColorData(
          color: Colors.grey,
          textColor: Colors.white,
        );
    }
  }

  Color _darkenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness((hsl.lightness * (1 - amount)).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  Color _lightenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final lightened = hsl.withLightness((hsl.lightness + (1 - hsl.lightness) * amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }
}

class _ColorData {
  final Color color;
  final Color textColor;

  _ColorData({required this.color, required this.textColor});
}
