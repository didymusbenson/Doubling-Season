import 'package:flutter/foundation.dart';
import '../models/widget_definition.dart';
import '../models/token_definition.dart'; // For ArtworkVariant

class WidgetDatabase extends ChangeNotifier {
  List<WidgetDefinition> _widgets = [];
  List<WidgetDefinition> _filteredWidgets = [];
  String _searchQuery = '';
  WidgetType? _selectedType;

  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<WidgetDefinition> get filteredWidgets => _filteredWidgets;

  String get searchQuery => _searchQuery;
  set searchQuery(String value) {
    _searchQuery = value;
    _applyFilters();
    notifyListeners();
  }

  WidgetType? get selectedType => _selectedType;
  set selectedType(WidgetType? value) {
    _selectedType = value;
    _applyFilters();
    notifyListeners();
  }

  WidgetDatabase() {
    loadWidgets();
  }

  /// Load predefined widget definitions
  void loadWidgets() {
    _widgets = [
      // Tracker Widgets
      WidgetDefinition(
        id: 'life_total',
        type: WidgetType.tracker,
        name: 'Life Total',
        description: '', // No description needed - players know what life totals are
        colorIdentity: '', // Colorless
        defaultValue: 40,
        tapIncrement: 1,
        longPressIncrement: 5,
        artwork: [
          ArtworkVariant(set: 'KLD', url: 'https://cards.scryfall.io/large/front/8/5/8542d37d-99cd-4b64-a524-94d2b2a4d9c3.jpg?1573516060'),
        ],
      ),
      WidgetDefinition(
        id: 'poison_counters',
        type: WidgetType.tracker,
        name: 'Poison Counters',
        description: '', // No description needed - players know what poison counters are
        colorIdentity: 'BG', // Black/Green
        defaultValue: 0,
        tapIncrement: 1,
        longPressIncrement: 5,
        artwork: [
          ArtworkVariant(set: 'ONE', url: 'https://cards.scryfall.io/large/front/4/0/40255bfa-0004-45f1-a31b-17d385f09a95.jpg?1675957570'),
        ],
      ),
      WidgetDefinition(
        id: 'radiation_counters',
        type: WidgetType.tracker,
        name: 'Radiation Counters',
        description: '',
        colorIdentity: 'UGB', // Blue/Green/Black
        defaultValue: 0,
        tapIncrement: 1,
        longPressIncrement: 5,
        artwork: [
          ArtworkVariant(set: 'PIP', url: 'https://cards.scryfall.io/large/front/0/8/0886657d-afb0-4f1f-9af7-960724793077.jpg?1707358335'),
        ],
      ),
      WidgetDefinition(
        id: 'energy_counters',
        type: WidgetType.tracker,
        name: 'Energy Counters',
        description: '',
        colorIdentity: 'GUR', // Green/Blue/Red
        defaultValue: 0,
        tapIncrement: 1,
        longPressIncrement: 5,
        artwork: [
          ArtworkVariant(set: 'PIP', url: 'https://cards.scryfall.io/large/front/2/a/2a794202-875f-4397-a8de-9722c8d78448.jpg?1708711465'),
          ArtworkVariant(set: 'NA', url: 'https://cards.scryfall.io/large/front/a/4/a446b9f8-cb22-408a-93ff-bee44a0dccc0.jpg?1717192462'),
        ],
      ),
      WidgetDefinition(
        id: 'experience_counters',
        type: WidgetType.tracker,
        name: 'Experience Counters',
        description: '',
        colorIdentity: 'WUBRG', // All colors
        defaultValue: 0,
        tapIncrement: 1,
        longPressIncrement: 5,
        artwork: [
          ArtworkVariant(set: 'CM2', url: 'https://cards.scryfall.io/large/front/1/3/1374bfa2-9714-486d-90aa-7a9b8d8ef3a8.jpg?1562871544'),
        ],
      ),
      WidgetDefinition(
        id: 'storm_count',
        type: WidgetType.tracker,
        name: 'Storm Count',
        description: '',
        colorIdentity: 'UR', // Blue/Red
        defaultValue: 0,
        tapIncrement: 1,
        longPressIncrement: 5,
        artwork: [
          ArtworkVariant(set: '2X2', url: 'https://cards.scryfall.io/large/front/e/c/ec17fa3c-9033-4eab-a236-3f0068595536.jpg?1674097527'),
        ],
      ),
      WidgetDefinition(
        id: 'commander_tax',
        type: WidgetType.tracker,
        name: 'Commander Tax',
        description: '',
        colorIdentity: 'WUBRG', // All colors
        defaultValue: 0,
        tapIncrement: 1,
        longPressIncrement: 5,
        artwork: [
          ArtworkVariant(set: 'CMM', url: 'https://cards.scryfall.io/large/front/4/6/46ca0b66-a000-4483-b916-f5b89e710244.jpg?1689999818'),
        ],
      ),

      // Toggle Widgets
      WidgetDefinition(
        id: 'monarch',
        type: WidgetType.toggle,
        name: 'The Monarch',
        description: 'You are the Monarch. Draw an extra card at end of turn.',
        offDescription: 'You are not the Monarch.',
        colorIdentity: 'WBR', // White/Black/Red
        artwork: [
          ArtworkVariant(set: 'CN2', url: 'https://cards.scryfall.io/large/front/4/0/40b79918-22a7-4fff-82a6-8ebfe6e87185.jpg?1680498245'),
          ArtworkVariant(set: 'FIC', url: 'https://cards.scryfall.io/large/front/6/6/66f569e1-5a37-4801-be01-9c5d44a82427.jpg?1749245701'),
          ArtworkVariant(set: 'OTC', url: 'https://cards.scryfall.io/large/front/9/7/97793b27-54d1-4870-9a86-680741ca8730.jpg?1712320267'),
          ArtworkVariant(set: 'LTC', url: 'https://cards.scryfall.io/large/front/6/3/63455c28-3e53-45b1-8d0b-a5045dab1fb9.jpg?1686264959'),
        ],
      ),
      WidgetDefinition(
        id: 'day_night',
        type: WidgetType.toggle,
        name: 'Day/Night',
        description: 'It is Day.',
        offDescription: 'It is Night.',
        colorIdentity: 'WG', // White/Green
        artwork: [
          ArtworkVariant(set: 'VOW', url: 'https://cards.scryfall.io/large/front/d/c/dc26e13b-7a0f-4e7f-8593-4f22234f4517.jpg?1675457589'),
        ],
      ),
      WidgetDefinition(
        id: 'citys_blessing',
        type: WidgetType.toggle,
        name: "City's Blessing",
        description: "You have the City's Blessing.",
        offDescription: "You do not have the City's Blessing.",
        colorIdentity: 'W', // White
        artwork: [
          ArtworkVariant(set: 'RIX', url: 'https://cards.scryfall.io/large/front/b/a/ba64ed3e-93c5-406f-a38d-65cc68472122.jpg?1691108010'),
        ],
      ),
      WidgetDefinition(
        id: 'initiative',
        type: WidgetType.toggle,
        name: 'The Initiative',
        description: 'You have the Initiative.',
        offDescription: 'You do not have the Initiative.',
        colorIdentity: '', // Colorless
        artwork: [
          ArtworkVariant(set: 'CLB', url: 'https://cards.scryfall.io/large/back/2/c/2c65185b-6cf0-451d-985e-56aa45d9a57d.jpg?1707897435'),
        ],
      ),

      // Special Utilities (Action Trackers)
      WidgetDefinition(
        id: 'krenko_mob_boss',
        type: WidgetType.special,
        name: 'Krenko, Mob Boss',
        description: 'Nontoken goblins you control',
        colorIdentity: 'R', // Red
        defaultValue: 1, // Start with Krenko himself
        hasAction: true,
        actionButtonText: 'Make Goblins',
        actionType: 'krenko_mob_boss',
        artwork: [
          ArtworkVariant(set: 'FDN', url: 'https://cards.scryfall.io/large/front/8/2/824b2d73-2151-4e5e-9f05-8f63e2bdcaa9.jpg?1730632010'),
          ArtworkVariant(set: 'RVR', url: 'https://cards.scryfall.io/large/front/8/0/8056ff64-1bd3-46ae-a0aa-c22305c2b654.jpg?1702429876'),
          ArtworkVariant(set: 'DDN', url: 'https://cards.scryfall.io/large/front/5/a/5a04a833-0ccf-4f59-9d94-2018e2f220e0.jpg?1592754664'),
        ],
      ),
      WidgetDefinition(
        id: 'krenko_tin_street',
        type: WidgetType.special,
        name: 'Krenko, Tin Street Kingpin',
        description: "Krenko's power",
        colorIdentity: 'R', // Red
        defaultValue: 1, // Krenko starts as a 1/1
        hasAction: true,
        actionButtonText: 'Make Goblins',
        actionType: 'krenko_tin_street',
        artwork: [
          ArtworkVariant(set: 'J25', url: 'https://cards.scryfall.io/large/front/0/c/0c7d8714-a0ef-4ae8-909b-60f3319c646c.jpg?1730487786'),
          ArtworkVariant(set: 'SLD', url: 'https://cards.scryfall.io/large/front/a/7/a762a954-1166-4c6c-bf87-0f68a5a24f3e.jpg?1759413223'),
          ArtworkVariant(set: 'WAR', url: 'https://cards.scryfall.io/large/front/3/7/37ed04d3-cfa1-4778-aea6-b4c2c29e6e0a.jpg?1559959382'),
        ],
      ),
      WidgetDefinition(
        id: 'cathars_crusade',
        type: WidgetType.special,
        name: "Cathar's Crusade",
        description: 'Creature ETB triggers',
        colorIdentity: 'W', // White enchantment
        defaultValue: 0, // Starts at 0 (no creatures entered yet)
        hasAction: true,
        actionButtonText: 'Add Counters',
        actionType: 'cathars_crusade',
        artwork: [
          ArtworkVariant(set: 'INR', url: 'https://cards.scryfall.io/large/front/5/2/5296e353-2efc-4d72-a877-7957eff630b9.jpg?1736467489'),
          ArtworkVariant(set: 'SLD', url: 'https://cards.scryfall.io/large/front/3/e/3ebdc35c-019d-41d9-aff7-b317246aefb1.jpg?1744789847'),
        ],
      ),
    ];

    _isLoaded = true;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    var filtered = _widgets;

    // Apply type filter
    if (_selectedType != null) {
      filtered = filtered.where((w) => w.type == _selectedType).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((w) => w.matches(searchQuery: _searchQuery))
          .toList();
    }

    _filteredWidgets = filtered;
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedType = null;
    _applyFilters();
    notifyListeners();
  }
}
