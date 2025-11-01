## PHASE 1: FOUNDATION & DATA LAYER

**Objective:** Set up project structure, data models, persistence layer, and state management. All UI-independent code.

**Estimated Time:** Week 1 (10-15 hours)

### 1.1 Constants Definition

Create `lib/utils/constants.dart`:

```dart
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
```

**Checklist:**
- [ ] Constants file created
- [ ] All magic numbers replaced with constants
- [ ] No hardcoded strings in models

---

### 1.2 Data Models with Hive

#### TokenCounter Model

Create `lib/models/token_counter.dart`:

```dart
import 'package:hive/hive.dart';
import '../utils/constants.dart';

part 'token_counter.g.dart';

@HiveType(typeId: HiveTypeIds.tokenCounter)
class TokenCounter extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int amount;

  TokenCounter({
    required this.name,
    this.amount = 1,
  });
}
```

**Checklist:**
- [ ] HiveType annotation with correct typeId
- [ ] HiveField annotations for all properties
- [ ] Extends HiveObject
- [ ] Constructor with named parameters

---

#### Item Model (Critical - Complex Validation Logic)

Create `lib/models/item.dart`:

**CRITICAL PATTERN:** SwiftUI uses `didSet` for property validation. Dart requires explicit setters.

```dart
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'token_counter.dart';
import '../utils/constants.dart';

part 'item.g.dart';

@HiveType(typeId: HiveTypeIds.item)
class Item extends HiveObject {
  // Basic properties (no validation needed)
  @HiveField(0)
  String abilities;

  @HiveField(1)
  String name;

  @HiveField(2)
  String pt;

  // Colors with validation
  @HiveField(3)
  String _colors = '';

  String get colors => _colors;
  set colors(String value) {
    _colors = value.toUpperCase();
    save(); // HiveObject method to persist changes
  }

  // Amount with dependent validation (CRITICAL)
  @HiveField(4)
  int _amount = 0;

  int get amount => _amount;
  set amount(int value) {
    _amount = value < 0 ? 0 : value;

    // Auto-correct dependent values
    if (_tapped > _amount) _tapped = _amount;
    if (_summoningSick > _amount) _summoningSick = _amount;

    save();
  }

  // Tapped with validation
  @HiveField(5)
  int _tapped = 0;

  int get tapped => _tapped;
  set tapped(int value) {
    if (value < 0) {
      _tapped = 0;
    } else if (value > _amount) {
      _tapped = _amount;
    } else {
      _tapped = value;
    }
    save();
  }

  // Summoning sickness with validation
  @HiveField(6)
  int _summoningSick = 0;

  int get summoningSick => _summoningSick;
  set summoningSick(int value) {
    if (value < 0) {
      _summoningSick = 0;
    } else if (value > _amount) {
      _summoningSick = _amount;
    } else {
      _summoningSick = value;
    }
    save();
  }

  // Counters
  @HiveField(7)
  int _plusOneCounters = 0;

  int get plusOneCounters => _plusOneCounters;
  set plusOneCounters(int value) {
    _plusOneCounters = value < 0 ? 0 : value;
    save();
  }

  @HiveField(8)
  int _minusOneCounters = 0;

  int get minusOneCounters => _minusOneCounters;
  set minusOneCounters(int value) {
    _minusOneCounters = value < 0 ? 0 : value;
    save();
  }

  @HiveField(9)
  List<TokenCounter> counters;

  @HiveField(10)
  DateTime createdAt;

  // Constructor
  Item({
    required this.name,
    required this.pt,
    this.abilities = '',
    String colors = '',
    int amount = 1,
    int tapped = 0,
    int summoningSick = 0,
    this.counters = const [],
    DateTime? createdAt,
  })  : _colors = colors.toUpperCase(),
        _amount = amount < 0 ? 0 : amount,
        _tapped = tapped < 0 ? 0 : tapped,
        _summoningSick = summoningSick < 0 ? 0 : summoningSick,
        createdAt = createdAt ?? DateTime.now();

  // Computed properties
  bool get isEmblem =>
      name.toLowerCase().contains('emblem') ||
      abilities.toLowerCase().contains('emblem');

  int get netPlusOneCounters => plusOneCounters - minusOneCounters;

  bool get isPowerToughnessModified => netPlusOneCounters != 0;

  bool get canBeModifiedByCounters {
    final parts = pt.split('/');
    return parts.length == 2 &&
        int.tryParse(parts[0]) != null &&
        int.tryParse(parts[1]) != null;
  }

  String get formattedPowerToughness {
    final net = netPlusOneCounters;
    if (net == 0) return pt;

    if (canBeModifiedByCounters) {
      final parts = pt.split('/');
      final power = int.parse(parts[0]) + net;
      final toughness = int.parse(parts[1]) + net;
      return '$power/$toughness';
    }

    // Non-integer P/T
    return net > 0 ? '$pt (+$net/+$net)' : '$pt ($net/$net)';
  }

  // CRITICAL: Counter interaction logic (from Item.swift:149-173)
  void addPowerToughnessCounters(int amount) {
    if (amount > 0) {
      // Adding +1/+1 counters
      if (_minusOneCounters > 0) {
        final reduction = amount < _minusOneCounters ? amount : _minusOneCounters;
        _minusOneCounters -= reduction;
        final remaining = amount - reduction;
        _plusOneCounters += remaining;
      } else {
        _plusOneCounters += amount;
      }
    } else if (amount < 0) {
      // Adding -1/-1 counters
      final absAmount = amount.abs();
      if (_plusOneCounters > 0) {
        final reduction = absAmount < _plusOneCounters ? absAmount : _plusOneCounters;
        _plusOneCounters -= reduction;
        final remaining = absAmount - reduction;
        _minusOneCounters += remaining;
      } else {
        _minusOneCounters += absAmount;
      }
    }
    save();
  }

  bool addCounter({required String name, int amount = 1}) {
    if (name.isEmpty || amount <= 0) return false;

    final existing = counters.where((c) => c.name == name).firstOrNull;
    if (existing != null) {
      existing.amount += amount;
    } else {
      counters.add(TokenCounter(name: name, amount: amount));
    }
    save();
    return true;
  }

  bool removeCounter({required String name, int amount = 1}) {
    final existing = counters.where((c) => c.name == name).firstOrNull;
    if (existing == null) return false;

    existing.amount -= amount;
    if (existing.amount <= 0) {
      counters.removeWhere((c) => c.name == name);
    }
    save();
    return true;
  }

  Item createDuplicate() {
    return Item(
      name: name,
      pt: pt,
      abilities: abilities,
      colors: colors,
      amount: 0,
      tapped: 0,
      summoningSick: 0,
    )
      ..plusOneCounters = plusOneCounters
      ..minusOneCounters = minusOneCounters
      ..counters = counters.map((c) => TokenCounter(name: c.name, amount: c.amount)).toList();
  }
}
```

**CRITICAL VALIDATION NOTES:**
1. Use private backing fields (`_amount`) with public getters/setters
2. **ALWAYS call `save()` after modifying fields** (HiveObject persistence)
3. Dependent validation: when `amount` changes, cap `tapped` and `summoningSick`
4. Counter interaction logic must match SwiftUI exactly (lines 149-173 of Item.swift)

**Checklist:**
- [ ] All fields have HiveField annotations
- [ ] Private backing fields with validation setters
- [ ] `save()` called in every setter
- [ ] Counter interaction logic matches SwiftUI
- [ ] Computed properties don't have HiveField
- [ ] Constructor handles validation

---

#### Deck & TokenTemplate Models

Create `lib/models/token_template.dart`:

```dart
import 'package:hive/hive.dart';
import 'item.dart';
import '../utils/constants.dart';

part 'token_template.g.dart';

@HiveType(typeId: HiveTypeIds.tokenTemplate)
class TokenTemplate extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String pt;

  @HiveField(2)
  String abilities;

  @HiveField(3)
  String colors;

  TokenTemplate({
    required this.name,
    required this.pt,
    required this.abilities,
    required this.colors,
  });

  factory TokenTemplate.fromItem(Item item) {
    return TokenTemplate(
      name: item.name,
      pt: item.pt,
      abilities: item.abilities,
      colors: item.colors,
    );
  }

  Item toItem({int amount = 1, bool createTapped = false}) {
    return Item(
      name: name,
      pt: pt,
      abilities: abilities,
      colors: colors,
      amount: amount,
      tapped: createTapped ? amount : 0,
      summoningSick: 0,
    );
  }
}
```

Create `lib/models/deck.dart`:

```dart
import 'package:hive/hive.dart';
import 'token_template.dart';
import '../utils/constants.dart';

part 'deck.g.dart';

@HiveType(typeId: HiveTypeIds.deck)
class Deck extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<TokenTemplate> templates;

  Deck({
    required this.name,
    List<TokenTemplate>? templates,
  }) : templates = templates ?? [];
}
```

**Checklist:**
- [ ] TokenTemplate has fromItem and toItem methods
- [ ] Deck stores templates as List (not JSON encoded)
- [ ] Both models have proper Hive annotations

---

#### TokenDefinition Model (Non-Hive)

Create `lib/models/token_definition.dart`:

```dart
import 'item.dart';

class TokenDefinition {
  final String name;
  final String abilities;
  final String pt;
  final String colors;
  final String type;

  TokenDefinition({
    required this.name,
    required this.abilities,
    required this.pt,
    required this.colors,
    required this.type,
  });

  // CRITICAL: Composite ID must match deduplication logic in process_tokens.py
  String get id => '$name|$pt|$colors|$type|$abilities';

  factory TokenDefinition.fromJson(Map<String, dynamic> json) {
    return TokenDefinition(
      name: json['name'] as String? ?? '',
      abilities: json['abilities'] as String? ?? '',
      pt: json['pt'] as String? ?? '',
      colors: json['colors'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }

  bool matches({required String searchQuery}) {
    if (searchQuery.isEmpty) return true;
    final query = searchQuery.toLowerCase();
    return name.toLowerCase().contains(query) ||
        abilities.toLowerCase().contains(query) ||
        pt.toLowerCase().contains(query) ||
        type.toLowerCase().contains(query);
  }

  Item toItem({required int amount, required bool createTapped}) {
    return Item(
      name: name,
      pt: pt,
      abilities: abilities,
      colors: colors,
      amount: amount,
      tapped: createTapped ? amount : 0,
      summoningSick: amount, // Always apply summoning sickness to new tokens
    );
  }

  String get cleanType {
    // Remove "Token" suffix if present
    return type.replaceAll(RegExp(r'\s+Token$', caseSensitive: false), '');
  }

  // Category for filtering
  Category get category {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('creature')) return Category.creature;
    if (lowerType.contains('artifact')) return Category.artifact;
    if (lowerType.contains('enchantment')) return Category.enchantment;
    if (lowerType.contains('emblem')) return Category.emblem;
    if (lowerType.contains('dungeon')) return Category.dungeon;
    if (name.toLowerCase().contains('counter')) return Category.counter;
    return Category.other;
  }
}

enum Category {
  creature,
  artifact,
  enchantment,
  emblem,
  dungeon,
  counter,
  other;

  String get displayName {
    switch (this) {
      case Category.creature:
        return 'Creature';
      case Category.artifact:
        return 'Artifact';
      case Category.enchantment:
        return 'Enchantment';
      case Category.emblem:
        return 'Emblem';
      case Category.dungeon:
        return 'Dungeon';
      case Category.counter:
        return 'Counter';
      case Category.other:
        return 'Other';
    }
  }
}
```

**Checklist:**
- [ ] Composite ID includes abilities (matches process_tokens.py)
- [ ] fromJson handles null values gracefully
- [ ] toItem applies summoning sickness by default
- [ ] Category enum for filtering

---

### 1.3 Generate TypeAdapters

```bash
# Run build_runner to generate .g.dart files
flutter packages pub run build_runner build --delete-conflicting-outputs
```

**Verify generated files:**
- [ ] `item.g.dart` exists
- [ ] `token_counter.g.dart` exists
- [ ] `deck.g.dart` exists
- [ ] `token_template.g.dart` exists
- [ ] No build errors

---

### 1.4 Hive Setup

Create `lib/database/hive_setup.dart`:

```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';
import '../models/token_counter.dart';
import '../models/deck.dart';
import '../models/token_template.dart';

Future<void> initHive() async {
  await Hive.initFlutter();

  // Register all TypeAdapters
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(TokenCounterAdapter());
  Hive.registerAdapter(DeckAdapter());
  Hive.registerAdapter(TokenTemplateAdapter());
}
```

**Checklist:**
- [ ] Hive.initFlutter() called
- [ ] All adapters registered
- [ ] Function is async

---

### 1.5 Provider Classes

#### TokenProvider

Create `lib/providers/token_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/item.dart';

class TokenProvider extends ChangeNotifier {
  late Box<Item> _itemsBox;
  bool _initialized = false;

  bool get initialized => _initialized;

  // Expose Hive's listenable for reactive updates (OPTIMIZATION)
  ValueListenable<Box<Item>> get listenable => _itemsBox.listenable();

  Future<void> init() async {
    _itemsBox = await Hive.openBox<Item>('items');
    _initialized = true;
    notifyListeners();
  }

  List<Item> get items {
    final allItems = _itemsBox.values.toList();
    allItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return allItems;
  }

  Future<void> insertItem(Item item) async {
    await _itemsBox.add(item);
    notifyListeners();
  }

  Future<void> updateItem(Item item) async {
    await item.save(); // HiveObject method
    notifyListeners();
  }

  Future<void> deleteItem(Item item) async {
    await item.delete(); // HiveObject method
    notifyListeners();
  }

  Future<void> untapAll() async {
    for (final item in items) {
      item.tapped = 0;
    }
    notifyListeners();
  }

  Future<void> clearSummoningSickness() async {
    for (final item in items) {
      item.summoningSick = 0;
    }
    notifyListeners();
  }

  Future<void> boardWipeZero() async {
    for (final item in items) {
      item.amount = 0;
      item.tapped = 0;
      item.summoningSick = 0;
    }
    notifyListeners();
  }

  Future<void> boardWipeDelete() async {
    await _itemsBox.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _itemsBox.close();
    super.dispose();
  }
}
```

**Checklist:**
- [ ] Extends ChangeNotifier
- [ ] Exposes listenable for optimization
- [ ] init() opens box
- [ ] All methods call notifyListeners()
- [ ] dispose() closes box
- [ ] items getter returns sorted list

---

#### DeckProvider

Create `lib/providers/deck_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/deck.dart';

class DeckProvider extends ChangeNotifier {
  late LazyBox<Deck> _decksBox; // Use LazyBox for memory optimization
  bool _initialized = false;

  bool get initialized => _initialized;

  Future<void> init() async {
    _decksBox = await Hive.openLazyBox<Deck>('decks');
    _initialized = true;
    notifyListeners();
  }

  Future<List<Deck>> get decks async {
    final keys = _decksBox.keys.toList();
    final deckList = <Deck>[];

    for (final key in keys) {
      final deck = await _decksBox.get(key);
      if (deck != null) deckList.add(deck);
    }

    return deckList;
  }

  Future<void> saveDeck(Deck deck) async {
    await _decksBox.add(deck);
    notifyListeners();
  }

  Future<void> deleteDeck(Deck deck) async {
    await deck.delete();
    notifyListeners();
  }

  @override
  void dispose() {
    _decksBox.close();
    super.dispose();
  }
}
```

**Checklist:**
- [ ] Uses LazyBox for memory optimization
- [ ] Async decks getter
- [ ] All methods call notifyListeners()

---

#### SettingsProvider

Create `lib/providers/settings_provider.dart`:

```dart
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
```

**Checklist:**
- [ ] Uses SharedPreferences
- [ ] All getters have fallback defaults
- [ ] Value clamping in setters
- [ ] Favorites and recents tracked

---

### 1.6 Database Loaders

Create `lib/database/token_database.dart`:

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/token_definition.dart';
import '../utils/constants.dart';

class TokenDatabase extends ChangeNotifier {
  List<TokenDefinition> _allTokens = [];
  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = '';
  Category? _selectedCategory;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  List<TokenDefinition> get allTokens => _allTokens;

  // Filtered tokens based on search and category
  List<TokenDefinition> get filteredTokens {
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

  Category? get selectedCategory => _selectedCategory;
  set selectedCategory(Category? value) {
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

  static List<TokenDefinition> _parseTokens(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((json) => TokenDefinition.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    notifyListeners();
  }

  // Recent and favorites logic (uses SettingsProvider)
  List<TokenDefinition> recentTokens = [];
  Set<String> _favoriteIds = {};

  bool isFavorite(TokenDefinition token) => _favoriteIds.contains(token.id);

  void toggleFavorite(TokenDefinition token) {
    if (_favoriteIds.contains(token.id)) {
      _favoriteIds.remove(token.id);
    } else {
      _favoriteIds.add(token.id);
    }
    notifyListeners();
  }

  void addToRecent(TokenDefinition token) {
    recentTokens.remove(token);
    recentTokens.insert(0, token);
    if (recentTokens.length > 20) recentTokens.removeLast();
    notifyListeners();
  }

  List<TokenDefinition> getFavoriteTokens() {
    return _allTokens.where((t) => _favoriteIds.contains(t.id)).toList();
  }
}
```

**Checklist:**
- [ ] Uses compute() for JSON parsing (performance)
- [ ] Error handling with user-friendly messages
- [ ] Loading state tracked
- [ ] Search and category filtering
- [ ] Recent and favorites logic

---

**CRITICAL**: CounterDatabase.swift has ~180 hardcoded counter names (NOT loaded from JSON).

Create `lib/database/counter_database.dart`:

```dart
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
}
```

**Checklist:**
- [ ] All 180+ counters from SwiftUI version included
- [ ] Search, favorites, and recents functionality
- [ ] Custom counter creation support

---

### 1.7 Main App Setup

Create `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'database/hive_setup.dart';
import 'providers/token_provider.dart';
import 'providers/deck_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/content_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await initHive();

  // Initialize providers
  final tokenProvider = TokenProvider();
  await tokenProvider.init();

  final deckProvider = DeckProvider();
  await deckProvider.init();

  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  runApp(MyApp(
    tokenProvider: tokenProvider,
    deckProvider: deckProvider,
    settingsProvider: settingsProvider,
  ));
}

class MyApp extends StatefulWidget {
  final TokenProvider tokenProvider;
  final DeckProvider deckProvider;
  final SettingsProvider settingsProvider;

  const MyApp({
    Key? key,
    required this.tokenProvider,
    required this.deckProvider,
    required this.settingsProvider,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _disableScreenTimeout();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _disableScreenTimeout() {
    // Keep screen awake during gameplay (matches SwiftUI behavior)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    // TODO: Use wakelock package for proper screen timeout control
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Close Hive boxes on app pause/close
      widget.tokenProvider.dispose();
      widget.deckProvider.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.tokenProvider),
        ChangeNotifierProvider.value(value: widget.deckProvider),
        ChangeNotifierProvider.value(value: widget.settingsProvider),
      ],
      child: MaterialApp(
        title: 'Doubling Season',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const ContentScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

**CRITICAL NOTES:**
- Screen timeout disable (matches SwiftUI `disableViewTimer()`)
- Hive cleanup on app lifecycle changes
- MultiProvider setup with pre-initialized providers

**Checklist:**
- [ ] Hive initialized before providers
- [ ] All providers initialized in main()
- [ ] MultiProvider wraps MaterialApp
- [ ] Screen timeout disabled
- [ ] App lifecycle observer configured
- [ ] Dark mode support

---

### 1.8 Asset Setup

1. Copy `TokenDatabase.json` to `assets/token_database.json`
2. Update `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/token_database.json
```

**Checklist:**
- [ ] TokenDatabase.json copied to assets/
- [ ] pubspec.yaml updated
- [ ] flutter pub get run
- [ ] Asset loads without errors

---

### Phase 1 Validation

Run these tests before proceeding to Phase 2:

```dart
// Create test in lib/main.dart (temporary)
void _testPhase1() async {
  // Test Hive initialization
  await initHive();
  print('✓ Hive initialized');

  // Test TokenProvider
  final tokenProvider = TokenProvider();
  await tokenProvider.init();
  print('✓ TokenProvider initialized');

  // Test item creation
  final item = Item(name: 'Test', pt: '1/1', colors: 'W', amount: 5);
  await tokenProvider.insertItem(item);
  assert(tokenProvider.items.length == 1);
  print('✓ Item creation and persistence');

  // Test validation
  item.amount = -1;
  assert(item.amount == 0); // Should auto-correct to 0
  print('✓ Property validation');

  // Test counter logic
  item.addPowerToughnessCounters(3);
  assert(item.plusOneCounters == 3);
  item.addPowerToughnessCounters(-2);
  assert(item.plusOneCounters == 1); // 3-2 cancellation
  assert(item.minusOneCounters == 0);
  print('✓ Counter interaction logic');

  // Test settings
  final settings = SettingsProvider();
  await settings.init();
  await settings.setTokenMultiplier(10);
  assert(settings.tokenMultiplier == 10);
  print('✓ Settings persistence');

  // Test token database
  final tokenDb = TokenDatabase();
  await tokenDb.loadTokens();
  assert(tokenDb.allTokens.length > 300);
  print('✓ Token database loaded');

  print('✅ Phase 1 Complete - All tests passed');
}
```

**Phase 1 Checklist:**
- [ ] All models compile without errors
- [ ] TypeAdapters generated successfully
- [ ] Hive boxes open and close properly
- [ ] Property validation works correctly
- [ ] Counter logic matches SwiftUI behavior
- [ ] Token database loads successfully
- [ ] Settings persist across app restarts

---

