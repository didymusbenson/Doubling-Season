import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/token_definition.dart' as token_models;
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class TokenDatabase extends ChangeNotifier {
  List<token_models.TokenDefinition> _allTokens = [];
  List<token_models.TokenDefinition> _customTokens = [];
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
  List<token_models.TokenDefinition> get customTokens => _customTokens;

  // Filtered tokens based on search, category, and color
  List<token_models.TokenDefinition> get filteredTokens {
    // Return cached result if available
    if (_cachedFilteredTokens != null) {
      return _cachedFilteredTokens!;
    }

    // Compute and cache — include both database and custom tokens
    final allSources = [..._allTokens, ..._customTokens];
    final filtered = allSources.where((token) {
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
        .map((id) => findTokenById(id))
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
    final results = <token_models.TokenDefinition>[];
    for (final t in _allTokens) {
      if (favoriteIds.contains(t.id)) results.add(t);
    }
    for (final t in _customTokens) {
      if (favoriteIds.contains(t.id) && !results.any((r) => r.id == t.id)) {
        results.add(t);
      }
    }
    return results;
  }

  // --- Custom Token Management ---

  /// Load custom tokens from the Hive 'customTokens' box.
  void loadCustomTokens() {
    try {
      final box = Hive.box<String>('customTokens');
      final databaseIds = _allTokens.map((t) => t.id).toSet();
      _customTokens = box.keys
          .map((key) {
            try {
              final json = jsonDecode(box.get(key)!) as Map<String, dynamic>;
              return token_models.TokenDefinition.fromJson(json);
            } catch (e) {
              debugPrint('Failed to parse custom token "$key": $e');
              return null;
            }
          })
          .whereType<token_models.TokenDefinition>()
          .where((t) => !databaseIds.contains(t.id)) // DB version wins on collision
          .toList();
      _cachedFilteredTokens = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load custom tokens: $e');
    }
  }

  /// Save a custom token. Skips if an identical database token exists.
  void saveCustomToken(token_models.TokenDefinition token) {
    // Database version wins — don't save duplicates
    if (_allTokens.any((t) => t.id == token.id)) return;

    try {
      final box = Hive.box<String>('customTokens');
      box.put(token.id, jsonEncode(token.toJson()));
      // Update in-memory list
      _customTokens.removeWhere((t) => t.id == token.id);
      _customTokens.add(token);
      _cachedFilteredTokens = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save custom token: $e');
    }
  }

  /// Delete a custom token by composite ID.
  void deleteCustomToken(String id) {
    try {
      final box = Hive.box<String>('customTokens');
      box.delete(id);
      _customTokens.removeWhere((t) => t.id == id);
      _cachedFilteredTokens = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete custom token: $e');
    }
  }

  /// Find a token by composite ID across both database and custom tokens.
  token_models.TokenDefinition? findTokenById(String id) {
    for (final t in _allTokens) {
      if (t.id == id) return t;
    }
    for (final t in _customTokens) {
      if (t.id == id) return t;
    }
    return null;
  }
}
