import 'package:doubling_season/widgets/mana/mana_symbol.dart';
import 'package:flutter/material.dart';

/// The persisted identity stays WUBRG text; colorless is an empty identity.
class CustomTokenColorPicker extends StatelessWidget {
  const CustomTokenColorPicker({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  static const _colors = <String, String>{
    'W': 'White',
    'U': 'Blue',
    'B': 'Black',
    'R': 'Red',
    'G': 'Green',
    'C': 'Colorless',
  };

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final identity = value.text.toUpperCase();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Color identity',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in _colors.entries)
                    _colorButton(
                      context,
                      color.key,
                      color.value,
                      color.key == 'C'
                          ? identity.isEmpty
                          : identity.contains(color.key),
                      () {
                        if (color.key == 'C') {
                          controller.clear();
                          return;
                        }
                        final selected = identity.split('').toSet();
                        selected.contains(color.key)
                            ? selected.remove(color.key)
                            : selected.add(color.key);
                        controller.text = 'WUBRG'
                            .split('')
                            .where(selected.contains)
                            .join();
                      },
                    ),
                ],
              ),
            ],
          );
        },
      );

  Widget _colorButton(
    BuildContext context,
    String code,
    String name,
    bool selected,
    VoidCallback select,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: ValueKey('custom-token-color-$code'),
      label: '$name color identity',
      button: true,
      enabled: enabled,
      toggled: selected,
      onTap: enabled ? select : null,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: enabled ? select : null,
          excludeFromSemantics: true,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: enabled ? 1 : .45,
                  child: ManaSymbol(code: code, size: 32),
                ),
                if (selected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 15,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
