import 'package:hive/hive.dart';
import '../utils/constants.dart';

part 'tracker_widget.g.dart';

@HiveType(typeId: HiveTypeIds.trackerWidget)
class TrackerWidget extends HiveObject {
  @HiveField(0)
  String widgetId; // Unique ID (UUID)

  @HiveField(1)
  String name; // Display name (user can edit for custom trackers)

  @HiveField(2)
  String description; // Explanation text (user can edit for custom trackers)

  @HiveField(3)
  String colorIdentity; // Color(s) for border gradient

  @HiveField(4)
  String? artworkUrl; // Optional custom artwork

  @HiveField(5)
  double order; // Sort order for reordering

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  int currentValue; // Current numeric value

  @HiveField(8)
  int defaultValue; // Starting value (user-settable, for reset functionality)

  @HiveField(9)
  int tapIncrement; // Amount to change on tap (default: 1)

  @HiveField(10)
  int longPressIncrement; // Amount to change on long-press (default: 5)

  @HiveField(11)
  bool isCustom; // True if user-created, false if predefined

  TrackerWidget({
    required this.widgetId,
    required this.name,
    required this.description,
    required this.colorIdentity,
    this.artworkUrl,
    required this.order,
    required this.createdAt,
    required this.currentValue,
    required this.defaultValue,
    this.tapIncrement = 1,
    this.longPressIncrement = 5,
    this.isCustom = false,
  });

  /// Increment the current value by the specified amount
  void increment(int amount) {
    currentValue = (currentValue + amount).clamp(0, double.maxFinite.toInt());
    save();
  }

  /// Decrement the current value by the specified amount (minimum 0)
  void decrement(int amount) {
    currentValue = (currentValue - amount).clamp(0, double.maxFinite.toInt());
    save();
  }

  /// Reset the tracker to its default value
  void reset() {
    currentValue = defaultValue;
    save();
  }
}
