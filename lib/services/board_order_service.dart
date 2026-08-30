/// Central ordering rules for the unified token/utility board.
///
/// Persistence stays with the existing Hive models. Callers provide a unified
/// snapshot of every board order so placement can never accidentally become
/// token-only or utility-only.
class BoardOrderService {
  BoardOrderService._();

  /// Places a new item or contiguous block at the absolute board bottom.
  ///
  /// Empty boards begin at 1.0 so 0.0 is not reused as an insertion sentinel.
  static double append(Iterable<double> boardOrders) {
    final orders = boardOrders.toList(growable: false);
    if (orders.isEmpty) return 1.0;
    final maximum = orders.reduce((a, b) => a > b ? a : b);
    return maximum.floor() + 1.0;
  }

  /// Allocates [count] stable positions immediately after [sourceOrder].
  ///
  /// Positions share the gap to the next unified-board neighbor. If the source
  /// is last, whole-number positions are returned. Callers must pass orders for
  /// tokens and every utility type, not a type-local subset.
  static List<double> immediatelyAfter({
    required double sourceOrder,
    required Iterable<double> boardOrders,
    int count = 1,
  }) {
    if (count < 1) return const [];

    double? nextOrder;
    for (final order in boardOrders) {
      if (order > sourceOrder && (nextOrder == null || order < nextOrder)) {
        nextOrder = order;
      }
    }

    if (nextOrder == null) {
      return List.generate(count, (index) => sourceOrder + index + 1.0);
    }

    final step = (nextOrder - sourceOrder) / (count + 1);
    if (step <= 0 || sourceOrder + step == sourceOrder) {
      throw StateError(
          'Board order gap is too small; normalize before insert.');
    }
    return List.generate(count, (index) => sourceOrder + step * (index + 1));
  }
}
