import 'package:flutter/widgets.dart';

/// Codepoints from the pinned Mana 1.18 font by Andrew Gioia.
///
/// Font SHA-256:
/// a23809f7c0af7f9866734216bdd73bce2cfedd67333f5cde86a9ee066fa69819
///
/// Mana 1.18 uses P for Pawprint and H for Phyrexian. Neither is exposed until
/// its brace-code behavior is deliberately scoped.
class ManaIcons {
  ManaIcons._();

  static const String fontFamily = 'Mana';

  static const IconData white = IconData(0xe600, fontFamily: fontFamily);
  static const IconData blue = IconData(0xe601, fontFamily: fontFamily);
  static const IconData black = IconData(0xe602, fontFamily: fontFamily);
  static const IconData red = IconData(0xe603, fontFamily: fontFamily);
  static const IconData green = IconData(0xe604, fontFamily: fontFamily);
  static const IconData generic0 = IconData(0xe605, fontFamily: fontFamily);
  static const IconData generic1 = IconData(0xe606, fontFamily: fontFamily);
  static const IconData generic2 = IconData(0xe607, fontFamily: fontFamily);
  static const IconData generic3 = IconData(0xe608, fontFamily: fontFamily);
  static const IconData tap = IconData(0xe61a, fontFamily: fontFamily);
  static const IconData untap = IconData(0xe61b, fontFamily: fontFamily);
  static const IconData artistNib = IconData(0xe924, fontFamily: fontFamily);
  static const IconData power = IconData(0xe921, fontFamily: fontFamily);
  static const IconData toughness = IconData(0xe922, fontFamily: fontFamily);
  static const IconData summoningSickness =
      IconData(0xe96a, fontFamily: fontFamily);
  static const IconData colorless = IconData(0xe904, fontFamily: fontFamily);
}
