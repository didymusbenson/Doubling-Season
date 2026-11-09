import 'package:flutter/foundation.dart';

import '../domain/table_state.dart';
import '../domain/input_validation.dart';
import '../state/table_controller.dart';

/// Immediate, seat-local acknowledgement of accepted life taps.
///
/// This is presentation state only. The controller remains the sole durable
/// writer, and history/undo continue to observe acknowledged saves. Exact
/// command receipts avoid a double-count frame when the controller publishes a
/// save before its returned Future resumes. Failed receipts are removed on their
/// own; they never restore a stale whole-player snapshot over newer taps.
class LifeTapFeedback extends ChangeNotifier {
  final TableController controller;
  final String playerId;
  final List<_LifeReceipt> _pending = [];
  bool _disposed = false;
  String? error;
  _LifeReceipt? _errorScope;

  LifeTapFeedback(this.controller, {required this.playerId}) {
    controller.addListener(_refresh);
  }

  PlayerState? get _player => controller.session.players
      .where((player) => player.id == playerId)
      .firstOrNull;

  bool _current(_LifeReceipt receipt) {
    final session = controller.session;
    // Match adjustLife's command scope. Player generation intentionally is not
    // a tap lifetime: Undo and preset loads increment it while retaining this
    // player. Already accepted deltas rebase onto that newly committed life in
    // queue order. New games/archive restores change session scope or identity.
    return receipt.sessionId == session.id &&
        receipt.generation == session.generation &&
        _player != null;
  }

  bool _unacknowledged(_LifeReceipt receipt) =>
      _current(receipt) &&
      !controller.session.completedCommandIds.contains(receipt.commandId);

  int get pendingDelta => _pending
      .where(_unacknowledged)
      .fold(0, (total, receipt) => total + receipt.delta);

  bool get hasPending => _pending.any(_unacknowledged);

  int get life => (_player?.life ?? 0) + pendingDelta;

  /// A signed display delta can include the already-durable current gesture,
  /// but each acknowledged receipt is excluded from the pending side exactly
  /// once. The caller owns expiry of its durable gesture display.
  int? displayDelta(int? durableDelta) =>
      hasPending ? (durableDelta ?? 0) + pendingDelta : durableDelta;

  Future<bool> adjust(int delta) async {
    final player = _player;
    if (_disposed || player == null || !controller.ready) return false;
    final receipt = _LifeReceipt(
      commandId: newEntityId(),
      sessionId: controller.session.id,
      generation: controller.session.generation,
      playerGeneration: player.generation,
      delta: delta,
    );
    _pending.add(receipt);
    // Notify before entering the durable queue, not after storage acknowledges.
    notifyListeners();
    try {
      final saved = await controller.adjustLife(
        playerId,
        delta,
        commandId: receipt.commandId,
      );
      if (!saved && !_disposed && _samePlayerSession(receipt)) {
        _captureErrorScope(receipt);
        error =
            'A life change was not saved. Check the displayed total before retrying. '
            '${controller.error ?? 'Storage did not acknowledge the change.'}';
      }
      return saved;
    } catch (failure) {
      if (!_disposed && _samePlayerSession(receipt)) {
        _captureErrorScope(receipt);
        error =
            'A life change was not saved. Check the displayed total before retrying. ${inputErrorMessage(failure)}';
      }
      return false;
    } finally {
      _pending.remove(receipt);
      if (!_disposed) notifyListeners();
    }
  }

  bool _samePlayerSession(_LifeReceipt receipt) =>
      receipt.sessionId == controller.session.id &&
      receipt.generation == controller.session.generation &&
      _player != null;

  void _captureErrorScope(_LifeReceipt receipt) {
    _errorScope = _LifeReceipt(
      commandId: receipt.commandId,
      sessionId: controller.session.id,
      generation: controller.session.generation,
      playerGeneration: _player!.generation,
      delta: receipt.delta,
    );
  }

  void clearError() {
    if (_disposed || error == null) return;
    error = null;
    _errorScope = null;
    notifyListeners();
  }

  void _refresh() {
    if (_disposed) return;
    _pending.removeWhere((receipt) => !_unacknowledged(receipt));
    // A removed/replaced seat must not carry an old save warning into a new game.
    if (_player == null ||
        (_errorScope != null &&
            (!_current(_errorScope!) ||
                _errorScope!.playerGeneration != _player?.generation))) {
      error = null;
      _errorScope = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_refresh);
    _pending.clear();
    // Accepted commands still finish in the controller's durable queue. Closing
    // a widget or backgrounding the app must not cancel an accepted life tap.
    super.dispose();
  }
}

class _LifeReceipt {
  final String commandId, sessionId;
  final int generation, playerGeneration, delta;
  const _LifeReceipt({
    required this.commandId,
    required this.sessionId,
    required this.generation,
    required this.playerGeneration,
    required this.delta,
  });
}
