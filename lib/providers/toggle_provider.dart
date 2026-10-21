import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/toggle_widget.dart';
import '../utils/constants.dart';
import '../services/board_order_persistence.dart';

class ToggleProvider extends ChangeNotifier {
  late Box<ToggleWidget> _togglesBox;
  bool _initialized = false;
  String? _errorMessage;

  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;

  /// Re-resolves a utility captured by delayed UI work after snapshot restore.
  /// Returns null when the utility was genuinely deleted.
  ToggleWidget? resolveCurrentToggle(
    ToggleWidget captured, {
    dynamic capturedKey,
  }) {
    if (captured.isInBox) return captured;
    final key = capturedKey ?? captured.key;
    return key == null ? null : _togglesBox.get(key);
  }

  // Expose Hive's listenable for reactive updates
  ValueListenable<Box<ToggleWidget>> get listenable => _togglesBox.listenable();

  Future<void> init() async {
    try {
      debugPrint('ToggleProvider.init: Opening toggles box...');
      _togglesBox = await Hive.openBox<ToggleWidget>(
        DatabaseConstants.toggleWidgetsBox,
      );
      debugPrint(
        'ToggleProvider.init: Box opened, has ${_togglesBox.length} toggles',
      );

      _initialized = true;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('ToggleProvider.init: ERROR during initialization');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      _errorMessage = 'Failed to load toggle utilities: $e';
      rethrow;
    }
  }

  List<ToggleWidget> get toggles {
    final allToggles = _togglesBox.values.toList();
    allToggles.sort(BoardOrderPersistence.compareModels);
    return allToggles;
  }

  Future<void> insertToggle(ToggleWidget toggle) async {
    try {
      await _togglesBox.add(toggle);
      _errorMessage = null;
      notifyListeners();
      debugPrint(
        'ToggleProvider: Successfully created toggle "${toggle.name}" (active: ${toggle.isActive})',
      );
    } on HiveError catch (e) {
      _errorMessage =
          'Database error while creating toggle: Unable to save to storage.';
      debugPrint(
        'ToggleProvider.insertToggle: HiveError while adding toggle "${toggle.name}". Error: ${e.message}',
      );
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage =
          'Unexpected error while creating toggle. Please try again.';
      debugPrint(
        'ToggleProvider.insertToggle: Unexpected error while adding toggle "${toggle.name}". Error: $e',
      );
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
      debugPrint(
          'ToggleProvider: Successfully updated toggle "${toggle.name}" (active: ${toggle.isActive})');
    } on HiveError catch (e) {
      _errorMessage =
          'Database error while updating toggle: Changes could not be saved.';
      debugPrint(
          'ToggleProvider.updateToggle: HiveError while saving toggle "${toggle.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage =
          'Unexpected error while updating toggle. Changes may not have been saved.';
      debugPrint(
          'ToggleProvider.updateToggle: Unexpected error while saving toggle "${toggle.name}". Error: $e');
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
      debugPrint(
          'ToggleProvider.deleteToggle: HiveError while deleting toggle "${toggle.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while deleting toggle.';
      debugPrint(
          'ToggleProvider.deleteToggle: Unexpected error while deleting toggle "${toggle.name}". Error: $e');
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
