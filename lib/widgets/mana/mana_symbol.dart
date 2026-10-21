import 'package:flutter/material.dart';

import 'mana_icons.dart';

class ManaSymbol extends StatelessWidget {
  final String code;
  final double size;
  final Color? textColor;

  const ManaSymbol({
    super.key,
    required this.code,
    required this.size,
    this.textColor,
  });

  static const supportedCodes = <String>{
    'T',
    'W',
    'U',
    'B',
    'R',
    'G',
    'C',
    '0',
    '1',
    '2',
    '3',
  };

  static bool supports(String code) => supportedCodes.contains(code);

  static String spokenLabel(String code) => switch (code) {
        'T' => 'tap',
        'W' => 'one white mana',
        'U' => 'one blue mana',
        'B' => 'one black mana',
        'R' => 'one red mana',
        'G' => 'one green mana',
        'C' => 'one colorless mana',
        '0' => 'zero generic mana',
        '1' => 'one generic mana',
        '2' => 'two generic mana',
        '3' => 'three generic mana',
        _ => '{$code}',
      };

  static IconData _iconFor(String code) => switch (code) {
        'T' => ManaIcons.tap,
        'W' => ManaIcons.white,
        'U' => ManaIcons.blue,
        'B' => ManaIcons.black,
        'R' => ManaIcons.red,
        'G' => ManaIcons.green,
        'C' => ManaIcons.colorless,
        '0' => ManaIcons.generic0,
        '1' => ManaIcons.generic1,
        '2' => ManaIcons.generic2,
        '3' => ManaIcons.generic3,
        _ => throw ArgumentError.value(code, 'code', 'Unsupported Mana symbol'),
      };

  static Color _backgroundFor(String code, Brightness brightness) =>
      switch (code) {
        'W' => const Color(0xfff0e6c0),
        'U' => const Color(0xff0e68ab),
        'B' => const Color(0xff211b18),
        'R' => const Color(0xffd3202a),
        'G' => const Color(0xff00733e),
        _ => brightness == Brightness.dark
            ? const Color(0xffd0d0d0)
            : const Color(0xffc6c1bf),
      };

  static Color _foregroundFor(String code) => switch (code) {
        'W' || 'C' || '0' || '1' || '2' || '3' => Colors.black87,
        _ => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(code);
    if (code == 'T') {
      return Icon(icon, size: size, color: textColor);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _backgroundFor(code, Theme.of(context).brightness),
        border: Border.all(color: Colors.black54, width: size * 0.055),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.76,
        color: _foregroundFor(code),
      ),
    );
  }
}
