import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/tracker_widget.dart';
import '../models/item.dart';
import '../utils/constants.dart';
import '../utils/game_events.dart';

class TrackerProvider extends ChangeNotifier {
  late Box<TrackerWidget> _trackersBox;
  bool _initialized = false;
  String? _errorMessage;

  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;

  // Expose Hive's listenable for reactive updates
  ValueListenable<Box<TrackerWidget>> get listenable => _trackersBox.listenable();

  Future<void> init() async {
    try {
      debugPrint('TrackerProvider.init: Opening trackers box...');
      _trackersBox = await Hive.openBox<TrackerWidget>(DatabaseConstants.trackerWidgetsBox);
      debugPrint('TrackerProvider.init: Box opened, has ${_trackersBox.length} trackers');

      debugPrint('TrackerProvider.init: Running migration...');
      _ensureOrdersAssigned(); // Silent migration for order field
      debugPrint('TrackerProvider.init: Migration complete');

      debugPrint('TrackerProvider.init: Registering event listeners...');
      // Register listener for creature ETBs (Cathar's Crusade)
      GameEvents.instance.onCreatureEntered((item, count) {
        _onCreatureEntered(item, count);
      });

      // Register listener for board wipes (Cathar's Crusade reset)
      GameEvents.instance.onBoardWiped(() {
        _onBoardWiped();
      });
      debugPrint('TrackerProvider.init: Event listeners registered');

      _initialized = true;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('TrackerProvider.init: ERROR during initialization');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      _errorMessage = 'Failed to load tracker utilities: $e';
      rethrow;
    }
  }

  void _ensureOrdersAssigned() {
    try {
      debugPrint('TrackerProvider._ensureOrdersAssigned: Reading trackers...');
      final trackers = _trackersBox.values.toList();
      debugPrint('TrackerProvider._ensureOrdersAssigned: Got ${trackers.length} trackers');

      bool needsReorder = trackers.any((tracker) => tracker.order == 0);

      if (needsReorder) {
        debugPrint('TrackerProvider._ensureOrdersAssigned: Migrating ${trackers.length} trackers');
        // Assign sequential orders based on current position
        for (int i = 0; i < trackers.length; i++) {
          trackers[i].order = i.toDouble();
          trackers[i].save();
        }
        debugPrint('TrackerProvider: Migrated ${trackers.length} trackers to use order field');
      } else {
        debugPrint('TrackerProvider._ensureOrdersAssigned: All trackers already have order');
      }
    } catch (e, stackTrace) {
      debugPrint('TrackerProvider._ensureOrdersAssigned: ERROR during migration');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  List<TrackerWidget> get trackers {
    final allTrackers = _trackersBox.values.toList();
    allTrackers.sort((a, b) => a.order.compareTo(b.order));
    return allTrackers;
  }

  Future<void> insertTracker(TrackerWidget tracker) async {
    try {
      // Assign order to new tracker if not already set
      if (tracker.order == 0.0) {
        final trackers = _trackersBox.values.toList();
        if (trackers.isEmpty) {
          tracker.order = 0.0;
        } else {
          // Find max order and add 1.0 (whole number for new items)
          final maxOrder = trackers.map((t) => t.order).reduce(max);
          tracker.order = maxOrder.floor() + 1.0;
        }
      }

      await _trackersBox.add(tracker);
      _errorMessage = null;
      notifyListeners();
      debugPrint('TrackerProvider: Successfully created tracker "${tracker.name}" with value ${tracker.currentValue}');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while creating tracker: Unable to save to storage.';
      debugPrint('TrackerProvider.insertTracker: HiveError while adding tracker "${tracker.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while creating tracker. Please try again.';
      debugPrint('TrackerProvider.insertTracker: Unexpected error while adding tracker "${tracker.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> insertTrackerWithExplicitOrder(TrackerWidget tracker) async {
    // Tracker.order is already set - don't override it
    await _trackersBox.add(tracker);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> updateTracker(TrackerWidget tracker) async {
    try {
      await tracker.save();
      _errorMessage = null;
      notifyListeners();
      debugPrint('TrackerProvider: Successfully updated tracker "${tracker.name}" (value: ${tracker.currentValue})');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while updating tracker: Changes could not be saved.';
      debugPrint('TrackerProvider.updateTracker: HiveError while saving tracker "${tracker.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while updating tracker. Changes may not have been saved.';
      debugPrint('TrackerProvider.updateTracker: Unexpected error while saving tracker "${tracker.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTracker(TrackerWidget tracker) async {
    try {
      await tracker.delete();
      _errorMessage = null;
      notifyListeners();
      debugPrint('TrackerProvider: Deleted tracker "${tracker.name}"');
    } on HiveError catch (e) {
      _errorMessage = 'Database error while deleting tracker.';
      debugPrint('TrackerProvider.deleteTracker: HiveError while deleting tracker "${tracker.name}". Error: ${e.message}');
      notifyListeners();
      rethrow;
    } catch (e, stackTrace) {
      _errorMessage = 'Unexpected error while deleting tracker.';
      debugPrint('TrackerProvider.deleteTracker: Unexpected error while deleting tracker "${tracker.name}". Error: $e');
      debugPrint('Stack trace: $stackTrace');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAll() async {
    await _trackersBox.clear();
    _errorMessage = null;
    notifyListeners();
    debugPrint('TrackerProvider: Cleared all trackers');
  }

  Future<void> updateOrder(TrackerWidget tracker, double newOrder) async {
    tracker.order = newOrder;
    await tracker.save();
    notifyListeners();
  }

  // ===== Event Listeners =====

  void _onCreatureEntered(Item item, int count) {
    // Find all Cathar's Crusade utilities on board
    final catharsUtilities = _trackersBox.values.where((tracker) =>
      tracker.actionType == 'cathars_crusade'
    );

    // Increment each Cathar's counter
    for (var cathar in catharsUtilities) {
      cathar.currentValue += count;
      cathar.save();
    }

    // Notify UI to rebuild
    if (catharsUtilities.isNotEmpty) {
      notifyListeners();
      debugPrint('TrackerProvider: Incremented ${catharsUtilities.length} Cathar\'s Crusade tracker(s) by $count');
    }
  }

  void _onBoardWiped() {
    // Find all Cathar's Crusade utilities on board
    final catharsUtilities = _trackersBox.values.where((tracker) =>
      tracker.actionType == 'cathars_crusade'
    );

    // Reset each Cathar's counter to 0
    for (var cathar in catharsUtilities) {
      cathar.currentValue = 0;
      cathar.save();
    }

    // Notify UI to rebuild
    if (catharsUtilities.isNotEmpty) {
      notifyListeners();
      debugPrint('TrackerProvider: Reset ${catharsUtilities.length} Cathar\'s Crusade tracker(s) to 0');
    }
  }
}
