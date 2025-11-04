/// Game mechanics constants
class GameConstants {
  static const int minMultiplier = 1;
  static const int maxMultiplier = 1024;
  static const int defaultTokenAmount = 1;
  static const int defaultTapped = 0;
  static const int defaultSummoningSick = 0;
}

/// Hive type IDs (must be unique and never change)
class HiveTypeIds {
  static const int item = 0;
  static const int tokenCounter = 1;
  static const int deck = 2;
  static const int tokenTemplate = 3;
}

/// UI constants
class UIConstants {
  static const double tokenCardHeight = 120.0;
  static const double tokenCardPadding = 8.0;
  static const double counterPillHeight = 24.0;

  // Animation constants
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration sheetDismissDelay = Duration(milliseconds: 100);

  // MTG color strings
  static const String colorWhite = 'W';
  static const String colorBlue = 'U';
  static const String colorBlack = 'B';
  static const String colorRed = 'R';
  static const String colorGreen = 'G';
}

/// SharedPreferences keys
class PreferenceKeys {
  static const String tokenMultiplier = 'tokenMultiplier';
  static const String summoningSicknessEnabled = 'summoningSicknessEnabled';
  static const String favoriteTokens = 'favoriteTokens';
  static const String recentTokens = 'recentTokens';
}

/// Asset paths
class AssetPaths {
  static const String tokenDatabase = 'assets/token_database.json';
}
