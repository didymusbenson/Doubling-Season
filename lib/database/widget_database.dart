import 'package:flutter/foundation.dart';
import '../models/widget_definition.dart';
// Note: ArtworkVariant import will be needed when actual artwork URLs are added

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
          // TODO: Add real Scryfall artwork URLs for Monarch-related cards
          // Example format:
          // ArtworkVariant(set: 'CN2', url: 'https://cards.scryfall.io/art_crop/...'),
        ],
      ),
      WidgetDefinition(
        id: 'day_night',
        type: WidgetType.toggle,
        name: 'Day/Night',
        description: 'It is Day.',
        offDescription: 'It is Night.',
        colorIdentity: 'WG', // White/Green
      ),
      WidgetDefinition(
        id: 'citys_blessing',
        type: WidgetType.toggle,
        name: "City's Blessing",
        description: "You have the City's Blessing.",
        offDescription: "You do not have the City's Blessing.",
        colorIdentity: 'W', // White
      ),
      WidgetDefinition(
        id: 'initiative',
        type: WidgetType.toggle,
        name: 'The Initiative',
        description: 'You have the Initiative.',
        offDescription: 'You do not have the Initiative.',
        colorIdentity: '', // Colorless
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
          // TODO: Add real Scryfall artwork URLs for Krenko, Mob Boss
          // Example format:
          // ArtworkVariant(set: 'M13', url: 'https://cards.scryfall.io/art_crop/...'),
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
          // TODO: Add real Scryfall artwork URLs for Krenko, Tin Street Kingpin
          // Example format:
          // ArtworkVariant(set: 'GRN', url: 'https://cards.scryfall.io/art_crop/...'),
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
