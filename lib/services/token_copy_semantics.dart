import '../models/item.dart';

/// Shared copiable-value heuristics for token-copying utilities.
class TokenCopySemantics {
  const TokenCopySemantics._();

  static bool isToken(Item item) => !item.isEmblem && item.amount > 0;

  static bool isCreatureToken(Item item) =>
      isToken(item) && item.hasPowerToughness;

  /// Temporary animation is not copiable. A stored P/T is copied only when
  /// the stored base type line itself contains Creature.
  static String copiablePtFor(Item item) =>
      item.type.toLowerCase().contains('creature') ? item.pt : '';
}
