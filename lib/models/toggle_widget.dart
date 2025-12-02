import 'package:hive/hive.dart';
import '../utils/constants.dart';

part 'toggle_widget.g.dart';

@HiveType(typeId: HiveTypeIds.toggleWidget)
class ToggleWidget extends HiveObject {
  @HiveField(0)
  String widgetId; // Unique ID (UUID)

  @HiveField(1)
  String name; // Display name (user can edit for custom toggles)

  @HiveField(2)
  String colorIdentity; // Color(s) for border gradient

  @HiveField(3)
  String? artworkUrl; // Optional custom artwork (used for both states if no per-state artwork)

  @HiveField(4)
  double order; // Sort order for reordering

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  bool isActive; // Current state (true = ON, false = OFF)

  @HiveField(7)
  String onDescription; // Text to show when active

  @HiveField(8)
  String offDescription; // Text to show when inactive

  @HiveField(9)
  String? onArtworkUrl; // Optional: Different artwork for ON state

  @HiveField(10)
  String? offArtworkUrl; // Optional: Different artwork for OFF state

  @HiveField(11)
  bool isCustom; // True if user-created, false if predefined

  ToggleWidget({
    required this.widgetId,
    required this.name,
    required this.colorIdentity,
    this.artworkUrl,
    required this.order,
    required this.createdAt,
    required this.isActive,
    required this.onDescription,
    required this.offDescription,
    this.onArtworkUrl,
    this.offArtworkUrl,
    this.isCustom = false,
  });

  /// Toggle the state (ON ↔ OFF)
  void toggle() {
    isActive = !isActive;
    save();
  }

  /// Get the current description based on active state
  String get currentDescription => isActive ? onDescription : offDescription;

  /// Get the current artwork URL based on active state
  /// Falls back to artworkUrl if state-specific artwork not set
  String? get currentArtworkUrl {
    if (isActive && onArtworkUrl != null) return onArtworkUrl;
    if (!isActive && offArtworkUrl != null) return offArtworkUrl;
    return artworkUrl;
  }

  /// Reset toggle to OFF state
  void reset() {
    isActive = false;
    save();
  }
}
