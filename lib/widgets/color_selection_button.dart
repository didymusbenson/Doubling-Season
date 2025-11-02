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
    // Use desaturated/faded color when not selected
    final displayColor = isSelected
        ? color
        : color.withOpacity(0.3);

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

              // Symbol text
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                ),
              ),

              // Selection ring
              if (isSelected)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade700,
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
}
