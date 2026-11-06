import 'package:flutter/foundation.dart';

import '../domain/table_state.dart';
import '../features/board_service.dart';

/// Keeps the dropped row in its requested position while storage acknowledges
/// the command. Only IDs are projected: token data, history and undo still come
/// from the controller's durable state. Shared by tablet and phone views.
class BoardReorderFeedback extends ChangeNotifier {
  final BoardService board;
  final String playerId;
  final List<_OrderReceipt> _pending = [];
  bool _disposed = false;

  BoardReorderFeedback(this.board, {required this.playerId}) {
    board.controller.addListener(_refresh);
  }

  PlayerState? get _player => board.controller.session.players
      .where((p) => p.id == playerId)
      .firstOrNull;

  bool _unacknowledged(_OrderReceipt receipt) {
    final session = board.controller.session;
    return session.id == receipt.sessionId &&
        session.generation == receipt.generation &&
        _player?.generation == receipt.playerGeneration &&
        !session.completedCommandIds.contains(receipt.commandId);
  }

  List<T> _ordered<T>(List<T> current, String Function(T) id, bool utilities) {
    final receipt = _pending
        .where((r) => r.utilities == utilities && _unacknowledged(r))
        .lastOrNull;
    if (receipt == null) return current;
    final byId = {for (final item in current) id(item): item};
    return [
      for (final key in receipt.ids)
        if (byId.containsKey(key)) byId.remove(key) as T,
      ...byId.values,
    ];
  }

  List<TokenState> get tokens =>
      _ordered(_player?.tokens ?? [], (t) => t.id, false);
  List<UtilityState> get utilities => _ordered(
    _player?.utilities.where(board.isUtilityVisible).toList() ?? [],
    (u) => u.id,
    true,
  );

  Future<void> reorderTokens(int oldIndex, int newIndex) =>
      _reorder(tokens.map((t) => t.id).toList(), oldIndex, newIndex, false);
  Future<void> reorderUtilities(int oldIndex, int newIndex) =>
      _reorder(utilities.map((u) => u.id).toList(), oldIndex, newIndex, true);

  Future<void> _reorder(
    List<String> ids,
    int oldIndex,
    int newIndex,
    bool utilities,
  ) async {
    final player = _player;
    if (_disposed || player == null) return;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex) return;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    final receipt = _OrderReceipt(
      commandId: newEntityId(),
      sessionId: board.controller.session.id,
      generation: board.controller.session.generation,
      playerGeneration: player.generation,
      utilities: utilities,
      ids: ids,
    );
    _pending.add(receipt);
    // Flutter removes the drag proxy immediately after onReorder. Publish the
    // displayed order synchronously, before entering the asynchronous save.
    notifyListeners();
    try {
      if (utilities) {
        await board.reorderVisibleUtilities(
          playerId,
          ids,
          commandId: receipt.commandId,
        );
      } else {
        await board.reorderTokens(playerId, ids, commandId: receipt.commandId);
      }
    } finally {
      // Remove this receipt only. A newer pending drag must not snap back when
      // an older save succeeds/fails. Errors continue to the existing UI guard.
      _pending.remove(receipt);
      if (!_disposed) notifyListeners();
    }
  }

  void _refresh() {
    if (_disposed) return;
    _pending.removeWhere((r) => !_unacknowledged(r));
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    board.controller.removeListener(_refresh);
    _pending.clear();
    // Accepted commands still finish in the controller's serialized writer.
    super.dispose();
  }
}

class _OrderReceipt {
  final String commandId, sessionId;
  final int generation, playerGeneration;
  final bool utilities;
  final List<String> ids;
  const _OrderReceipt({
    required this.commandId,
    required this.sessionId,
    required this.generation,
    required this.playerGeneration,
    required this.utilities,
    required this.ids,
  });
}
