import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/token_definition.dart' as token_models;
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class TokenDatabase extends ChangeNotifier {
  List<token_models.TokenDefinition> _allTokens = [];
  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = '';
  token_models.Category? _selectedCategory;
  Set<String> _selectedColors = {};

  // Cache for filtered tokens to avoid recomputation
  List<token_models.TokenDefinition>? _cachedFilteredTokens;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  List<token_models.TokenDefinition> get allTokens => _allTokens;

  // Filtered tokens based on search, category, and color
  List<token_models.TokenDefinition> get filteredTokens {
    // Return cached result if available
    if (_cachedFilteredTokens != null) {
      return _cachedFilteredTokens!;
    }

    // Compute and cache
    final filtered = _allTokens.where((token) {
      final matchesSearch = token.matches(searchQuery: _searchQuery);
      final matchesCategory =
          _selectedCategory == null || token.category == _selectedCategory;
      final matchesColor = _matchesColorFilter(token);
      return matchesSearch && matchesCategory && matchesColor;
    }).toList();

    // Sort: popularity DESC (highest first), then name ASC (alphabetical)
    // This automatically creates bracket-based sorting
    filtered.sort((a, b) {
      // Higher popularity first
      final popularityCompare = b.popularity.compareTo(a.popularity);
      if (popularityCompare != 0) return popularityCompare;

      // Same popularity: alphabetical
      return a.name.compareTo(b.name);
    });

    _cachedFilteredTokens = filtered;
    return filtered;
  }

  String get searchQuery => _searchQuery;
  set searchQuery(String value) {
    _searchQuery = value;
    _cachedFilteredTokens = null; // Invalidate cache
    notifyListeners();
  }

  token_models.Category? get selectedCategory => _selectedCategory;
  set selectedCategory(token_models.Category? value) {
    _selectedCategory = value;
    _cachedFilteredTokens = null; // Invalidate cache
    notifyListeners();
  }

  Set<String> get selectedColors => _selectedColors;
  set selectedColors(Set<String> value) {
    _selectedColors = value;
    _cachedFilteredTokens = null; // Invalidate cache
    notifyListeners();
  }

  // Helper method to check if token matches color filter
  bool _matchesColorFilter(token_models.TokenDefinition token) {
    if (_selectedColors.isEmpty) return true; // No filter = show all

    // Handle colorless filter (C selected)
    if (_selectedColors.contains('C')) {
      return token.colors.isEmpty;
    }

    // Exact color match for WUBRG
    final tokenColors = token.colors.split('').toSet();
    return tokenColors.length == _selectedColors.length &&
        tokenColors.containsAll(_selectedColors);
  }

  Future<void> loadTokens() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final jsonString = await rootBundle.loadString(AssetPaths.tokenDatabase);

      // For large files (>100KB), parse in background isolate
      _allTokens = await compute(_parseTokens, jsonString);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _loadError = 'Failed to load tokens: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  static List<token_models.TokenDefinition> _parseTokens(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((json) => token_models.TokenDefinition.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedColors = {};
    _cachedFilteredTokens = null; // Invalidate cache
    notifyListeners();
  }

  // Recent and favorites logic - delegates to SettingsProvider for persistence

  void addToRecent(token_models.TokenDefinition token, SettingsProvider settingsProvider) {
    settingsProvider.addRecent(token.id); // Persist to SharedPreferences
    notifyListeners(); // Trigger UI update
  }

  // Reconstruct recent tokens from IDs stored in SettingsProvider
  List<token_models.TokenDefinition> getRecentTokens(SettingsProvider settingsProvider) {
    final recentIds = settingsProvider.recentTokens;
    return recentIds
        .map((id) {
          try {
            return _allTokens.firstWhere((t) => t.id == id);
          } catch (e) {
            return null;
          }
        })
        .whereType<token_models.TokenDefinition>()
        .toList();
  }

  bool isFavorite(token_models.TokenDefinition token, SettingsProvider settingsProvider) {
    return settingsProvider.favoriteTokens.contains(token.id);
  }

  void toggleFavorite(token_models.TokenDefinition token, SettingsProvider settingsProvider) {
    if (settingsProvider.favoriteTokens.contains(token.id)) {
      settingsProvider.removeFavorite(token.id);
    } else {
      settingsProvider.addFavorite(token.id);
    }
    notifyListeners();
  }

  List<token_models.TokenDefinition> getFavoriteTokens(SettingsProvider settingsProvider) {
    final favoriteIds = settingsProvider.favoriteTokens;
    return _allTokens.where((t) => favoriteIds.contains(t.id)).toList();
  }
}
