import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/item.dart';
import '../models/tracker_widget.dart';
import '../models/toggle_widget.dart';
import '../utils/constants.dart';
import 'board_order_service.dart';

/// Order-only persistence over the existing board boxes. A retained plan makes
/// multi-box renumbering resumable; it never replaces models or emits events.
class BoardOrderPersistence {
  static const _pendingKey = 'pendingV1';
  static Future<Box<String>> _journal() =>
      Hive.openBox<String>(DatabaseConstants.boardOrderOperationsBox);
  static Future<void> _tail = Future<void>.value();

  static Future<void> _serialized(Future<void> Function() work) {
    final next = _tail.then((_) => work());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  static int _kind(HiveObject model) => switch (model) {
    Item() => 0,
    TrackerWidget() => 1,
    ToggleWidget() => 2,
    _ => throw ArgumentError('Not a board item'),
  };

  static double orderOf(HiveObject model) => switch (model) {
    Item() => model.order,
    TrackerWidget() => model.order,
    ToggleWidget() => model.order,
    _ => throw ArgumentError('Not a board item'),
  };

  static void _setOrder(HiveObject model, double order) {
    switch (model) {
      case Item():
        model.order = order;
      case TrackerWidget():
        model.order = order;
      case ToggleWidget():
        model.order = order;
      default:
        throw ArgumentError('Not a board item');
    }
  }

  /// Stable tie-break for legacy equal positions. Numeric Hive keys retain
  /// insertion order within each type, rather than relying on unstable sort.
  static int compareModels(HiveObject a, HiveObject b) {
    final ao = orderOf(a), bo = orderOf(b);
    final byOrder = ao.isFinite && bo.isFinite
        ? ao.compareTo(bo)
        : (ao.isFinite ? -1 : (bo.isFinite ? 1 : 0));
    if (byOrder != 0) return byOrder;
    final byKind = _kind(a).compareTo(_kind(b));
    if (byKind != 0) return byKind;
    final ak = a.key, bk = b.key;
    if (ak is int && bk is int) return ak.compareTo(bk);
    return ak.toString().compareTo(bk.toString());
  }

  static List<HiveObject> snapshot() => <HiveObject>[
    ...Hive.box<Item>(DatabaseConstants.itemsBox).values,
    ...Hive.box<TrackerWidget>(DatabaseConstants.trackerWidgetsBox).values,
    ...Hive.box<ToggleWidget>(DatabaseConstants.toggleWidgetsBox).values,
  ]..sort(compareModels);

  static double appendOrder() =>
      BoardOrderService.append(snapshot().map(orderOf));

  static HiveObject? _resolve(int kind, dynamic key) => switch (kind) {
    0 => Hive.box<Item>(DatabaseConstants.itemsBox).get(key),
    1 => Hive.box<TrackerWidget>(DatabaseConstants.trackerWidgetsBox).get(key),
    2 => Hive.box<ToggleWidget>(DatabaseConstants.toggleWidgetsBox).get(key),
    _ => throw const FormatException('Invalid board item kind'),
  };

  static Future<void> _recover(Box<String> journal) async {
    final pending = journal.get(_pendingKey);
    if (pending == null) return;
    final rows = (jsonDecode(pending) as List).cast<Map<String, dynamic>>();
    // Validate the whole journal before making any writes.
    for (final row in rows) {
      final kind = row['kind'];
      final key = row['key'];
      final order = row['order'];
      if (kind is! int ||
          kind < 0 ||
          kind > 2 ||
          (key is! int && key is! String) ||
          order is! num ||
          !order.isFinite) {
        throw const FormatException('Invalid board order plan');
      }
    }
    for (final row in rows) {
      final model = _resolve(row['kind'] as int, row['key']);
      // Never resurrect a deleted item.
      if (model == null) continue;
      final order = (row['order'] as num).toDouble();
      _setOrder(model, order);
      await model.save();
    }
    // Flush the board before discarding recovery information.
    await Hive.box<Item>(DatabaseConstants.itemsBox).flush();
    await Hive.box<TrackerWidget>(DatabaseConstants.trackerWidgetsBox).flush();
    await Hive.box<ToggleWidget>(DatabaseConstants.toggleWidgetsBox).flush();
    await journal.delete(_pendingKey);
    await journal.flush();
  }

  static Future<void> _persist(
    Box<String> journal,
    List<HiveObject> models,
    List<double> orders,
  ) async {
    final rows = [
      for (var i = 0; i < models.length; i++)
        {'kind': _kind(models[i]), 'key': models[i].key, 'order': orders[i]},
    ];
    await journal.put(_pendingKey, jsonEncode(rows));
    await journal.flush();
    await _recover(journal);
  }

  /// Run before providers expose the board. Valid zero/negative/fractional
  /// positions are untouched; only ambiguous or invalid positions need repair.
  static Future<void> initialize() => _serialized(() async {
    final journal = await _journal();
    await _recover(journal);
    final models = snapshot();
    if (BoardOrderService.needsNormalization(models.map(orderOf))) {
      await _persist(
        journal,
        models,
        List.generate(models.length, (i) => i + 1.0),
      );
    }
  });

  /// Uses the requested post-move sequence, never stale captured positions.
  static Future<void> move(HiveObject model, int destination) =>
      _serialized(() async {
        final journal = await _journal();
        await _recover(journal);
        final models = snapshot();
        final oldIndex = models.indexOf(model);
        if (oldIndex < 0) return;
        final target = destination.clamp(0, models.length - 1);
        if (oldIndex == target) return;
        models.removeAt(oldIndex);
        models.insert(target, model);
        final orders = BoardOrderService.afterMove(
          models.map(orderOf).toList(),
          target,
        );
        await _persist(journal, models, orders);
      });
}
