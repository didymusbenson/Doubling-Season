import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/krenko_utility.dart';
import '../utils/constants.dart';

class KrenkoProvider extends ChangeNotifier {
  late Box<KrenkoUtility> _krenkoBox;
  bool _initialized = false;
  String? _errorMessage;

  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;

  // Expose Hive's listenable for reactive updates
  ValueListenable<Box<KrenkoUtility>> get listenable => _krenkoBox.listenable();

  Future<void> init() async {
    _krenkoBox = await Hive.openBox<KrenkoUtility>(DatabaseConstants.krenkoUtilityBox);
    _ensureOrdersAssigned(); // Silent migration for order field
    _initialized = true;
    notifyListeners();
  }

  void _ensureOrdersAssigned() {
    final utilities = _krenkoBox.values.toList();
    bool needsReorder = utilities.any((utility) => utility.order == 0);

    if (needsReorder) {
      // Assign sequential orders based on current position
      for (int i = 0; i < utilities.length; i++) {
        utilities[i].order = i.toDouble();
        utilities[i].save();
      }
      debugPrint('KrenkoProvider: Migrated ${utilities.length} Krenko utilities to use order field');
    }
  }

  List<KrenkoUtility> get krenkos {
    final allKrenkos = _krenkoBox.values.toList();
    allKrenkos.sort((a, b) => a.order.compareTo(b.order));
    return allKrenkos;
  }

  Future<void> insertKrenko(KrenkoUtility krenko) async {
    try {
      // Assign order to new utility if not already set
      if (krenko.order == 0.0) {
        final utilities = _krenkoBox.values.toList();
        if (utilities.isEmpty) {
          krenko.order = 0.0;
        } else {
          // Find max order and add 1.0 (whole number for new items)
          final maxOrder = utilities.map((k) => k.order).reduce(max);
          krenko.order = maxOrder.floor() + 1.0;
        }
      }

      await _krenkoBox.add(krenko);
      _errorMessage = null;
      notifyListeners();
      debugPrint('KrenkoProvider: Successfully created Krenko utility "${krenko.name}"');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while creating Krenko utility: Unable to save to storage.';
      debugPrint('KrenkoProvider.insertKrenko: HiveError while adding utility "${krenko.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while creating Krenko utility. Please try again.';
      debugPrint('KrenkoProvider.insertKrenko: Unexpected error while adding utility "${krenko.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> insertKrenkoWithExplicitOrder(KrenkoUtility krenko) async {
    // Order is already set - don't override it
    await _krenkoBox.add(krenko);
    _errorMessage = null;
    notifyListeners();
    debugPrint('KrenkoProvider: Successfully created Krenko utility "${krenko.name}" with explicit order ${krenko.order}');
  }

  Future<void> updateKrenko(KrenkoUtility krenko) async {
    try {
      await krenko.save();
      _errorMessage = null;
      notifyListeners();
      debugPrint('KrenkoProvider: Successfully updated Krenko utility "${krenko.name}"');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while updating Krenko utility.';
      debugPrint('KrenkoProvider.updateKrenko: HiveError while updating utility "${krenko.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Unexpected error while updating Krenko utility.';
      debugPrint('KrenkoProvider.updateKrenko: Unexpected error while updating utility "${krenko.name}". Error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteKrenko(KrenkoUtility krenko) async {
    try {
      await krenko.delete();
      _errorMessage = null;
      notifyListeners();
      debugPrint('KrenkoProvider: Successfully deleted Krenko utility "${krenko.name}"');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while deleting Krenko utility.';
      debugPrint('KrenkoProvider.deleteKrenko: HiveError while deleting utility "${krenko.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = 'Unexpected error while deleting Krenko utility.';
      debugPrint('KrenkoProvider.deleteKrenko: Unexpected error while deleting utility "${krenko.name}". Error: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Reorder utilities when user drags and drops
  Future<void> reorderKrenkos(int oldIndex, int newIndex) async {
    final utilities = krenkos;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final krenko = utilities.removeAt(oldIndex);
    utilities.insert(newIndex, krenko);

    // Update order values
    for (int i = 0; i < utilities.length; i++) {
      utilities[i].order = i.toDouble();
      await utilities[i].save();
    }

    notifyListeners();
    debugPrint('KrenkoProvider: Reordered utilities, moved "${krenko.name}" from index $oldIndex to $newIndex');
  }

  /// Update order for drag-and-drop between different item types
  Future<void> updateOrder(KrenkoUtility krenko, double newOrder) async {
    krenko.order = newOrder;
    await krenko.save();
    notifyListeners();
    debugPrint('KrenkoProvider: Updated order for "${krenko.name}" to $newOrder');
  }

  void dispose() {
    _krenkoBox.close();
    super.dispose();
  }
}
