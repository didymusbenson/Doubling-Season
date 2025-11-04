import 'package:flutter/material.dart';

class ColorUtils {
  static List<Color> getColorsForIdentity(String colorString) {
    final colors = <Color>[];

    if (colorString.contains('W')) colors.add(const Color(0xFFE8DDB5)); // Cream color for white
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
    // Flutter LinearGradient requires at least 2 colors
    final gradientColors = colors.length == 1 ? [colors[0], colors[0]] : colors;
    return LinearGradient(
      colors: gradientColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
