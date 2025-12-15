import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/toggle_widget.dart';
import '../utils/constants.dart';

class ToggleProvider extends ChangeNotifier {
  late Box<ToggleWidget> _togglesBox;
  bool _initialized = false;
  String? _errorMessage;

  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;

  // Expose Hive's listenable for reactive updates
  ValueListenable<Box<ToggleWidget>> get listenable => _togglesBox.listenable();

  Future<void> init() async {
    _togglesBox = await Hive.openBox<ToggleWidget>(DatabaseConstants.toggleWidgetsBox);
    _ensureOrdersAssigned(); // Silent migration for order field
    _initialized = true;
    notifyListeners();
  }

  void _ensureOrdersAssigned() {
    final toggles = _togglesBox.values.toList();
    bool needsReorder = toggles.any((toggle) => toggle.order == 0);

    if (needsReorder) {
      // Assign sequential orders based on current position
      for (int i = 0; i < toggles.length; i++) {
        toggles[i].order = i.toDouble();
        toggles[i].save();
      }
      debugPrint('ToggleProvider: Migrated ${toggles.length} toggles to use order field');
    }
  }

  List<ToggleWidget> get toggles {
    final allToggles = _togglesBox.values.toList();
    allToggles.sort((a, b) => a.order.compareTo(b.order));
    return allToggles;
  }

  Future<void> insertToggle(ToggleWidget toggle) async {
    try {
      // Assign order to new toggle if not already set
      if (toggle.order == 0.0) {
        final toggles = _togglesBox.values.toList();
        if (toggles.isEmpty) {
          toggle.order = 0.0;
        } else {
          // Find max order and add 1.0 (whole number for new items)
          final maxOrder = toggles.map((t) => t.order).reduce(max);
          toggle.order = maxOrder.floor() + 1.0;
        }
      }

      await _togglesBox.add(toggle);
      _errorMessage = null;
      notifyListeners();
      debugPrint('ToggleProvider: Successfully created toggle "${toggle.name}" (active: ${toggle.isActive})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while creating toggle: Unable to save to storage.';
      debugPrint('ToggleProvider.insertToggle: HiveError while adding toggle "${toggle.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while creating toggle. Please try again.';
      debugPrint('ToggleProvider.insertToggle: Unexpected error while adding toggle "${toggle.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> insertToggleWithExplicitOrder(ToggleWidget toggle) async {
    // Toggle.order is already set - don't override it
    await _togglesBox.add(toggle);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> updateToggle(ToggleWidget toggle) async {
    try {
      await toggle.save();
      _errorMessage = null;
      notifyListeners();
      debugPrint('ToggleProvider: Successfully updated toggle "${toggle.name}" (active: ${toggle.isActive})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while updating toggle: Changes could not be saved.';
      debugPrint('ToggleProvider.updateToggle: HiveError while saving toggle "${toggle.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while updating toggle. Changes may not have been saved.';
      debugPrint('ToggleProvider.updateToggle: Unexpected error while saving toggle "${toggle.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteToggle(ToggleWidget toggle) async {
    try {
      await toggle.delete();
      _errorMessage = null;
      notifyListeners();
      debugPrint('ToggleProvider: Deleted toggle "${toggle.name}"');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while deleting toggle.';
      debugPrint('ToggleProvider.deleteToggle: HiveError while deleting toggle "${toggle.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while deleting toggle.';
      debugPrint('ToggleProvider.deleteToggle: Unexpected error while deleting toggle "${toggle.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAll() async {
    await _togglesBox.clear();
    _errorMessage = null;
    notifyListeners();
    debugPrint('ToggleProvider: Cleared all toggles');
  }

  Future<void> updateOrder(ToggleWidget toggle, double newOrder) async {
    toggle.order = newOrder;
    await toggle.save();
    notifyListeners();
  }
}
