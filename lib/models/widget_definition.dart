import 'package:uuid/uuid.dart';
import 'tracker_widget.dart';
import 'toggle_widget.dart';
import 'token_definition.dart'; // For ArtworkVariant

enum WidgetType { tracker, toggle }

class WidgetDefinition {
  final String id; // Unique identifier (e.g., "life_total", "monarch")
  final WidgetType type; // tracker or toggle
  final String name;
  final String description; // Or onDescription for toggles
  final String? offDescription; // For toggles only
  final String colorIdentity;
  final int? defaultValue; // For trackers
  final int tapIncrement; // For trackers (default: 1)
  final int longPressIncrement; // For trackers (default: 5)
  // Action tracker fields
  final bool hasAction; // True if this tracker has an action button
  final String? actionButtonText; // Text for action button
  final String? actionType; // Type of action (e.g., "krenko_goblins")
  // Artwork fields (same as tokens)
  final List<ArtworkVariant> artwork; // Available artwork options

  WidgetDefinition({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    this.offDescription,
    required this.colorIdentity,
    this.defaultValue,
    this.tapIncrement = 1,
    this.longPressIncrement = 5,
    this.hasAction = false,
    this.actionButtonText,
    this.actionType,
    this.artwork = const [], // Default to empty list
  });

  /// Check if widget matches search query
  bool matches({required String searchQuery}) {
    if (searchQuery.isEmpty) return true;
    final query = searchQuery.toLowerCase();
    return name.toLowerCase().contains(query) ||
        description.toLowerCase().contains(query) ||
        (offDescription?.toLowerCase().contains(query) ?? false);
  }

  /// Convert definition to TrackerWidget instance
  TrackerWidget toTrackerWidget({required double order}) {
    assert(type == WidgetType.tracker, 'Can only convert tracker definitions to TrackerWidget');

    return TrackerWidget(
      widgetId: const Uuid().v4(),
      name: name,
      description: description,
      colorIdentity: colorIdentity,
      order: order,
      createdAt: DateTime.now(),
      currentValue: defaultValue ?? 0,
      defaultValue: defaultValue ?? 0,
      tapIncrement: tapIncrement,
      longPressIncrement: longPressIncrement,
      isCustom: false, // Predefined widget
      hasAction: hasAction, // Action tracker fields
      actionButtonText: actionButtonText,
      actionType: actionType,
      artworkOptions: artwork.isNotEmpty ? List.from(artwork) : null,
    );
  }

  /// Convert definition to ToggleWidget instance
  ToggleWidget toToggleWidget({required double order}) {
    assert(type == WidgetType.toggle, 'Can only convert toggle definitions to ToggleWidget');
    assert(offDescription != null, 'Toggle widget must have offDescription');

    return ToggleWidget(
      widgetId: const Uuid().v4(),
      name: name,
      colorIdentity: colorIdentity,
      order: order,
      createdAt: DateTime.now(),
      isActive: false, // Always start in OFF state
      onDescription: description, // description field is ON description
      offDescription: offDescription!,
      isCustom: false, // Predefined widget
      artworkOptions: artwork.isNotEmpty ? List.from(artwork) : null,
    );
  }
}
