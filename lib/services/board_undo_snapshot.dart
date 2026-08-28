import 'package:hive/hive.dart';

import '../models/item.dart';
import '../models/token_counter.dart';
import '../models/token_definition.dart' show ArtworkVariant;
import '../models/toggle_widget.dart';
import '../models/tracker_widget.dart';
import '../utils/constants.dart';

/// Typed in-memory snapshot of the unified board for immediate action undo.
/// Restore writes directly to Hive and deliberately emits no game events.
class BoardUndoSnapshot {
  final Map<dynamic, Item> _items;
  final Map<dynamic, TrackerWidget> _trackers;
  final Map<dynamic, ToggleWidget> _toggles;

  BoardUndoSnapshot._(this._items, this._trackers, this._toggles);

  factory BoardUndoSnapshot.capture() {
    final items = Hive.box<Item>(DatabaseConstants.itemsBox);
    final trackers =
        Hive.box<TrackerWidget>(DatabaseConstants.trackerWidgetsBox);
    final toggles = Hive.box<ToggleWidget>(DatabaseConstants.toggleWidgetsBox);
    return BoardUndoSnapshot._(
      {for (final key in items.keys) key: _cloneItem(items.get(key)!)},
      {for (final key in trackers.keys) key: _cloneTracker(trackers.get(key)!)},
      {for (final key in toggles.keys) key: _cloneToggle(toggles.get(key)!)},
    );
  }

  Future<void> restore() async {
    final items = Hive.box<Item>(DatabaseConstants.itemsBox);
    final trackers =
        Hive.box<TrackerWidget>(DatabaseConstants.trackerWidgetsBox);
    final toggles = Hive.box<ToggleWidget>(DatabaseConstants.toggleWidgetsBox);
    await items.clear();
    await trackers.clear();
    await toggles.clear();
    await items
        .putAll({for (final e in _items.entries) e.key: _cloneItem(e.value)});
    await trackers.putAll(
        {for (final e in _trackers.entries) e.key: _cloneTracker(e.value)});
    await toggles.putAll(
        {for (final e in _toggles.entries) e.key: _cloneToggle(e.value)});
  }

  static Item _cloneItem(Item item) => Item(
        name: item.name,
        pt: item.pt,
        abilities: item.abilities,
        colors: item.colors,
        type: item.type,
        amount: item.amount,
        tapped: item.tapped,
        summoningSick: item.summoningSick,
        counters: [
          for (final c in item.counters)
            TokenCounter(name: c.name, amount: c.amount)
        ],
        createdAt: item.createdAt,
        order: item.order,
        artworkUrl: item.artworkUrl,
        artworkSet: item.artworkSet,
        artworkOptions: item.artworkOptions == null
            ? null
            : List<ArtworkVariant>.from(item.artworkOptions!),
        plusOneCounters: item.plusOneCounters,
        minusOneCounters: item.minusOneCounters,
        plusOnePowerCounters: item.plusOnePowerCounters,
        plusOneToughnessCounters: item.plusOneToughnessCounters,
      );

  static TrackerWidget _cloneTracker(TrackerWidget t) => TrackerWidget(
        widgetId: t.widgetId,
        name: t.name,
        description: t.description,
        colorIdentity: t.colorIdentity,
        artworkUrl: t.artworkUrl,
        order: t.order,
        createdAt: t.createdAt,
        currentValue: t.currentValue,
        defaultValue: t.defaultValue,
        tapIncrement: t.tapIncrement,
        longPressIncrement: t.longPressIncrement,
        isCustom: t.isCustom,
        hasAction: t.hasAction,
        actionButtonText: t.actionButtonText,
        actionType: t.actionType,
        artworkSet: t.artworkSet,
        artworkOptions: t.artworkOptions == null
            ? null
            : List<ArtworkVariant>.from(t.artworkOptions!),
        actionOnly: t.actionOnly,
      );

  static ToggleWidget _cloneToggle(ToggleWidget t) => ToggleWidget(
        widgetId: t.widgetId,
        name: t.name,
        colorIdentity: t.colorIdentity,
        artworkUrl: t.artworkUrl,
        order: t.order,
        createdAt: t.createdAt,
        isActive: t.isActive,
        onDescription: t.onDescription,
        offDescription: t.offDescription,
        onArtworkUrl: t.onArtworkUrl,
        offArtworkUrl: t.offArtworkUrl,
        isCustom: t.isCustom,
        artworkSet: t.artworkSet,
        artworkOptions: t.artworkOptions == null
            ? null
            : List<ArtworkVariant>.from(t.artworkOptions!),
      );
}
