import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/token_definition.dart' as token_models;
import '../utils/constants.dart';

class TokenDatabase extends ChangeNotifier {
  List<token_models.TokenDefinition> _allTokens = [];
  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = '';
  token_models.Category? _selectedCategory;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  List<token_models.TokenDefinition> get allTokens => _allTokens;

  // Filtered tokens based on search and category
  List<token_models.TokenDefinition> get filteredTokens {
    return _allTokens.where((token) {
      final matchesSearch = token.matches(searchQuery: _searchQuery);
      final matchesCategory =
          _selectedCategory == null || token.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  String get searchQuery => _searchQuery;
  set searchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  token_models.Category? get selectedCategory => _selectedCategory;
  set selectedCategory(token_models.Category? value) {
    _selectedCategory = value;
    notifyListeners();
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
    notifyListeners();
  }

  // Recent and favorites logic (uses SettingsProvider)
  List<token_models.TokenDefinition> recentTokens = [];
  Set<String> _favoriteIds = {};

  bool isFavorite(token_models.TokenDefinition token) => _favoriteIds.contains(token.id);

  void toggleFavorite(token_models.TokenDefinition token) {
    if (_favoriteIds.contains(token.id)) {
      _favoriteIds.remove(token.id);
    } else {
      _favoriteIds.add(token.id);
    }
    notifyListeners();
  }

  void addToRecent(token_models.TokenDefinition token) {
    recentTokens.remove(token);
    recentTokens.insert(0, token);
    if (recentTokens.length > 20) recentTokens.removeLast();
    notifyListeners();
  }

  List<token_models.TokenDefinition> getFavoriteTokens() {
    return _allTokens.where((t) => _favoriteIds.contains(t.id)).toList();
  }
}
