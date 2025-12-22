import '../models/item.dart';

/// Singleton event bus for game-wide trigger events.
///
/// Allows utilities to listen to token lifecycle events without creating
/// circular dependencies between providers.
///
/// Mirrors Magic's rules engine: actions generate events → permanents with
/// triggered abilities listen for matching events.
class GameEvents {
  static final GameEvents instance = GameEvents._();
  GameEvents._();

  // ===== Creature Entered Battlefield =====

  final _creatureEnteredListeners = <void Function(Item item, int count)>[];

  /// Register a listener for creature ETB events.
  ///
  /// Callback receives:
  /// - [item]: The token that entered (for future filtering by type/color)
  /// - [count]: Number of tokens that entered (item.amount)
  void onCreatureEntered(void Function(Item item, int count) callback) {
    _creatureEnteredListeners.add(callback);
  }

  /// Notify all listeners that creature(s) entered the battlefield.
  ///
  /// Called by TokenProvider when tokens with P/T are created/copied.
  void notifyCreatureEntered(Item item, int count) {
    for (var listener in _creatureEnteredListeners) {
      listener(item, count);
    }
  }

  // ===== Board Wipe Event =====

  final _boardWipedListeners = <void Function()>[];

  /// Register a listener for board wipe events.
  void onBoardWiped(void Function() callback) {
    _boardWipedListeners.add(callback);
  }

  /// Notify all listeners that board was wiped.
  ///
  /// Called by TokenProvider when user triggers board wipe action.
  void notifyBoardWiped() {
    for (var listener in _boardWipedListeners) {
      listener();
    }
  }
}
