import 'package:flutter/material.dart';

class CounterDatabase extends ChangeNotifier {
  // COMPLETE list from CounterDatabase.swift (lines 74-93)
  static const List<String> predefinedCounters = [
    "+1/+1", "-1/-1", "Acorn", "Aegis", "Age", "Aim", "Arrow", "Arrowhead", "Art", "Awakening",
    "Bait", "Blaze", "Blessing", "Blight", "Blood", "Bloodline", "Bloodstain", "Book", "Bore", "Bounty",
    "Brain", "Bribery", "Brick", "Burden", "Cage", "Carrion", "Charge", "Chip", "Chorus", "Coin",
    "Collection", "Component", "Contested", "Corpse", "Corruption", "CRANK!", "Credit", "Croak", "Crystal", "Cube",
    "Currency", "Day", "Death", "Defense", "Delay", "Depletion", "Descent", "Despair", "Devotion", "Discovery",
    "Divinity", "Doom", "Dread", "Dream", "Duty", "Echo", "Egg", "Elixir", "Ember", "Energy",
    "Enlightened", "Eon", "Eruption", "Everything", "Experience", "Eyeball", "Eyestalk", "Fade", "Fate", "Feather",
    "Feeding", "Fellowship", "Fetch", "Filibuster", "Finality", "Flame", "Flood", "Foreshadow", "Fungus", "Funk",
    "Fury", "Fuse", "Gem", "Ghostform", "Glass", "Globe", "Glyph", "Gold", "Growth", "Hack",
    "Harmony", "Hatching", "Hatchling", "Healing", "Hit", "Hole", "Hone", "Hoofprint", "Hope", "Hour",
    "Hourglass", "Hunger", "Husk", "Ice", "Impostor", "Incarnation", "Incubation", "Infection", "Influence", "Ingenuity",
    "Intel", "Intervention", "Invitation", "Isolation", "Javelin", "Judgment", "Ki", "Kick", "Knickknack", "Knowledge",
    "Landmark", "Level", "Loot", "Lore", "Loyalty", "Luck", "Magnet", "Manabond", "Manifestation", "Mannequin",
    "Matrix", "Memory", "Midway", "Milk", "Mine", "Mining", "Mire", "Music", "Muster", "Necrodermis",
    "Nest", "Net", "Night", "Oil", "Omen", "Ore", "Page", "Pain", "Palliation", "Paralyzation",
    "Pause", "Petal", "Petrification", "Phylactery", "Phyresis", "Pin", "Plague", "Plot", "Point", "Poison",
    "Polyp", "Pop!", "Possession", "Pressure", "Prey", "Primeval", "Punch card", "Pupa", "Quest", "Rad",
    "Rebuilding", "Rejection", "Release", "Reprieve", "Resonance", "Rev", "Revival", "Ribbon", "Ritual", "Rope",
    "Rust", "Scream", "Scroll", "Shell", "Shield", "Shoe", "Shred", "Shy", "Silver", "Skewer"
  ];

  List<String> _filteredCounters = predefinedCounters;
  String _searchQuery = '';
  Set<String> _favoriteCounters = {};
  List<String> _recentCounters = [];

  bool _showFavoritesOnly = false;
  bool _showRecentsOnly = false;

  List<String> get filteredCounters => _filteredCounters;
  String get searchQuery => _searchQuery;
  Set<String> get favoriteCounters => _favoriteCounters;
  List<String> get recentCounters => _recentCounters;
  bool get showFavoritesOnly => _showFavoritesOnly;
  bool get showRecentsOnly => _showRecentsOnly;

  set searchQuery(String value) {
    _searchQuery = value;
    _filterCounters();
    notifyListeners();
  }

  set showFavoritesOnly(bool value) {
    _showFavoritesOnly = value;
    _filterCounters();
    notifyListeners();
  }

  set showRecentsOnly(bool value) {
    _showRecentsOnly = value;
    _filterCounters();
    notifyListeners();
  }

  void _filterCounters() {
    var result = predefinedCounters.toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((counter) =>
        counter.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply favorites filter
    if (_showFavoritesOnly) {
      result = result.where((counter) =>
        _favoriteCounters.contains(counter)
      ).toList();
    }

    // Apply recents filter
    if (_showRecentsOnly) {
      result = _recentCounters.where((counter) =>
        result.contains(counter)
      ).toList();
    }

    _filteredCounters = result;
  }

  void markAsRecent(String counterName) {
    _recentCounters.remove(counterName);
    _recentCounters.insert(0, counterName);
    if (_recentCounters.length > 10) {
      _recentCounters = _recentCounters.sublist(0, 10);
    }
    _filterCounters();
    notifyListeners();
  }

  void toggleFavorite(String counterName) {
    if (_favoriteCounters.contains(counterName)) {
      _favoriteCounters.remove(counterName);
    } else {
      _favoriteCounters.add(counterName);
    }
    _filterCounters();
    notifyListeners();
  }

  String? createCustomCounter(String name) {
    if (name.trim().isEmpty) return null;
    // Custom counters can be created on-the-fly
    return name.trim();
  }

  List<String> searchCounters(String query) {
    if (query.isEmpty) return predefinedCounters;
    final lowerQuery = query.toLowerCase();
    return predefinedCounters
        .where((counter) => counter.toLowerCase().contains(lowerQuery))
        .toList();
  }
}
