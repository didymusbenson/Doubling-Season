import 'package:flutter/material.dart';

import '../utils/color_utils.dart';
import 'mana/mana_icons.dart';

class InlineColorIdentityBar extends StatelessWidget {
  const InlineColorIdentityBar({
    super.key,
    required this.colorIdentity,
    required this.onToggle,
  });

  final String colorIdentity;
  final ValueChanged<String> onToggle;

  static const _choices = [
    ('W', 'White', ManaIcons.white),
    ('U', 'Blue', ManaIcons.blue),
    ('B', 'Black', ManaIcons.black),
    ('R', 'Red', ManaIcons.red),
    ('G', 'Green', ManaIcons.green),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = colorIdentity.characters.toSet();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: selected.isEmpty ? 'Colorless identity' : 'Color identity',
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in _choices)
              Semantics(
                button: true,
                toggled: selected.contains(choice.$1),
                label: '${choice.$2} color identity',
                child: InkWell(
                  onTap: () => onToggle(choice.$1),
                  child: Container(
                    width: 31,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected.contains(choice.$1)
                          ? ColorUtils.mtgColorMap[choice.$1]
                          : Colors.transparent,
                      border: choice.$1 == 'W'
                          ? null
                          : Border(
                              left: BorderSide(color: scheme.outlineVariant),
                            ),
                    ),
                    child: Icon(
                      choice.$3,
                      size: 19,
                      color: selected.contains(choice.$1)
                          ? _selectedForeground(
                              ColorUtils.mtgColorMap[choice.$1]!,
                            )
                          : scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _selectedForeground(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.light
          ? Colors.black87
          : Colors.white;
}
