import 'package:flutter/material.dart';

class ColorUtils {
  static List<Color> getColorsForIdentity(String colorString) {
    final colors = <Color>[];

    if (colorString.contains('W')) colors.add(Colors.yellow);
    if (colorString.contains('U')) colors.add(Colors.blue);
    if (colorString.contains('B')) colors.add(Colors.purple);
    if (colorString.contains('R')) colors.add(Colors.red);
    if (colorString.contains('G')) colors.add(Colors.green);

    return colors.isEmpty ? [Colors.grey] : colors;
  }

  static LinearGradient gradientForColors(String colorString, {bool isEmblem = false}) {
    if (isEmblem) {
      return const LinearGradient(colors: [Colors.transparent, Colors.transparent]);
    }

    final colors = getColorsForIdentity(colorString);
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
