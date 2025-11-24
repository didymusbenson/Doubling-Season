import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _initialized = false;

  bool get initialized => _initialized;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    notifyListeners();
  }

  int get tokenMultiplier =>
      _prefs.getInt(PreferenceKeys.tokenMultiplier) ?? GameConstants.minMultiplier;

  Future<void> setTokenMultiplier(int value) async {
    final clamped = value.clamp(GameConstants.minMultiplier, GameConstants.maxMultiplier);
    await _prefs.setInt(PreferenceKeys.tokenMultiplier, clamped);
    notifyListeners();
  }

  bool get summoningSicknessEnabled =>
      _prefs.getBool(PreferenceKeys.summoningSicknessEnabled) ?? true;

  Future<void> setSummoningSicknessEnabled(bool value) async {
    await _prefs.setBool(PreferenceKeys.summoningSicknessEnabled, value);
    notifyListeners();
  }

  // Artwork display style: 'fullView' or 'fadeout'
  String get artworkDisplayStyle => _prefs.getString('artworkDisplayStyle') ?? 'fullView';

  Future<void> setArtworkDisplayStyle(String style) async {
    await _prefs.setString('artworkDisplayStyle', style);
    notifyListeners();
  }

  // Theme mode settings
  bool get useSystemTheme => _prefs.getBool('useSystemTheme') ?? true;

  Future<void> setUseSystemTheme(bool value) async {
    await _prefs.setBool('useSystemTheme', value);
    notifyListeners();
  }

  // Manual theme preference (only used when useSystemTheme is false)
  bool get isDarkMode => _prefs.getBool('isDarkMode') ?? false;

  Future<void> setIsDarkMode(bool value) async {
    await _prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Set<String> get favoriteTokens {
    final list = _prefs.getStringList(PreferenceKeys.favoriteTokens) ?? [];
    return Set.from(list);
  }

  Future<void> addFavorite(String tokenId) async {
    final favorites = favoriteTokens;
    favorites.add(tokenId);
    await _prefs.setStringList(PreferenceKeys.favoriteTokens, favorites.toList());
    notifyListeners();
  }

  Future<void> removeFavorite(String tokenId) async {
    final favorites = favoriteTokens;
    favorites.remove(tokenId);
    await _prefs.setStringList(PreferenceKeys.favoriteTokens, favorites.toList());
    notifyListeners();
  }

  List<String> get recentTokens {
    return _prefs.getStringList(PreferenceKeys.recentTokens) ?? [];
  }

  Future<void> addRecent(String tokenId) async {
    final recent = recentTokens;
    recent.remove(tokenId); // Remove if exists
    recent.insert(0, tokenId); // Add to front
    if (recent.length > 20) recent.removeLast(); // Cap at 20
    await _prefs.setStringList(PreferenceKeys.recentTokens, recent);
    notifyListeners();
  }
}
