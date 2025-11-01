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
    return InkWell(
      onTap: () => onChanged(!isSelected),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Circle background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color : Colors.grey.withOpacity(0.3),
                ),
              ),

              // Symbol text
              Text(
                symbol,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                      color: Colors.blue,
                      width: 3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? null : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
