import 'package:flutter/material.dart';

class ColorUtils {
  /// Map of MTG color identity characters to their corresponding Flutter colors
  static const Map<String, Color> mtgColorMap = {
    'W': Color(0xFFE8DDB5),  // White (cream)
    'U': Colors.blue,         // Blue
    'B': Colors.purple,       // Black
    'R': Colors.red,          // Red
    'G': Colors.green,        // Green
  };

  /// Converts an MTG color identity string to a list of colors.
  ///
  /// Processes each character in [colorString] and returns colors for valid
  /// MTG color codes (W, U, B, R, G). Invalid characters are ignored.
  /// Returns grey as a fallback if no valid colors are found.
  ///
  /// Example:
  /// ```dart
  /// getColorsForIdentity('WU')     // Returns [cream, blue]
  /// getColorsForIdentity('WUBRGXYZ') // Returns [cream, blue, purple, red, green]
  /// getColorsForIdentity('XYZ')    // Returns [grey]
  /// ```
  static List<Color> getColorsForIdentity(String colorString) {
    final colors = <Color>[];

    // Iterate through each character in the string
    for (int i = 0; i < colorString.length; i++) {
      final char = colorString[i];
      // Only add color if it exists in our map (ignores invalid characters)
      if (mtgColorMap.containsKey(char)) {
        colors.add(mtgColorMap[char]!);
      }
    }

    // Return grey as fallback if no valid colors found
    return colors.isEmpty ? [Colors.grey] : colors;
  }

  static LinearGradient gradientForColors(String colorString, {bool isEmblem = false}) {
    if (isEmblem) {
      return const LinearGradient(colors: [Colors.orange, Colors.orange]);
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
