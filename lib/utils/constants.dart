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
  static const int artworkVariant = 4;
}

/// UI constants
class UIConstants {
  static const double tokenCardHeight = 120.0;
  static const double tokenCardPadding = 8.0;
  static const double counterPillHeight = 24.0;

  // Spacing and padding
  static const double standardPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 20.0;
  static const double cardPadding = 10.0;
  static const double verticalSpacing = 4.0;
  static const double mediumSpacing = 8.0;
  static const double largeSpacing = 12.0;
  
  // Border and corner radius
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 7.0; // 12 - 5 = 7 (to fit inside border)
  static const double counterPillBorderRadius = 12.0;
  static const double actionButtonBorderRadius = 8.0;
  static const double borderWidth = 5.0;
  static const double actionButtonBorderWidth = 1.5;
  
  // Icon and button sizes
  static const double iconSize = 20.0;
  static const double actionButtonPadding = 8.0;
  static const double actionButtonInternalWidth = 39.0;
  static const double minButtonSpacing = 4.0;
  static const double maxButtonSpacing = 8.0;
  
  // Counter pill specific
  static const double counterPillHorizontalPadding = 8.0;
  static const double counterPillVerticalPadding = 5.0;
  static const double counterPillSpacing = 4.0;
  static const double counterPillFontSize = 14.0;
  static const double counterPillAmountFontSize = 12.0;
  
  // List padding
  static const double listTopPadding = 8.0;
  static const double listBottomPadding = 120.0;
  
  // Shadow and elevation
  static const double shadowBlurRadius = 2.0;        // Stark shadow with minimal blur
  static const double shadowOffsetY = 5.0;           // Vertical offset (bottom)
  static const double shadowOffsetX = 0.0;           // Centered horizontally
  static const double lightShadowBlurRadius = 1.0;   // Sharp secondary shadow
  static const double lightShadowOffsetY = 2.0;      // Vertical offset
  static const double lightShadowOffsetX = 0.0;      // Centered horizontally
  static const double dragElevation = 8.0;
  static const double dragScaleFactor = 1.03;

  // Opacity values
  static const double disabledOpacity = 0.3;
  static const double actionButtonBackgroundOpacity = 0.15; // Used only when no artwork
  static const double shadowOpacity = 0.35;          // High contrast shadow
  static const double lightShadowOpacity = 0.15;     // Visible secondary shadow
  static const double dragShadowOpacity = 0.3;
  static const double darkModeGlowOpacity = 0.40;    // Strong glow in dark mode

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

/// Database box names
class DatabaseConstants {
  static const String countersBox = 'counters';
  static const String decksBox = 'decks';
  static const String templatesBox = 'templates';
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
