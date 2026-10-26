import 'dart:math';

/// One denomination's individual results, in their generated order.
class DiceRollGroup {
  DiceRollGroup(this.sides, Iterable<int> faces)
    : faces = List<int>.unmodifiable(faces);

  final int sides;
  final List<int> faces;

  int get count => faces.length;
  int get total => faces.fold(0, (sum, face) => sum + face);
}

/// Ephemeral presentation data; never persisted to the table or its history.
class DiceRoll {
  DiceRoll(Iterable<DiceRollGroup> groups)
    : groups = List<DiceRollGroup>.unmodifiable(groups);

  final List<DiceRollGroup> groups;

  int get total => groups.fold(0, (sum, group) => sum + group.total);

  /// Uses one secure generator per roll unless a test supplies its generator.
  /// Map insertion order and each denomination's individual draw order are kept.
  factory DiceRoll.generate(Map<int, int> counts, {Random? random}) {
    for (final entry in counts.entries) {
      if (entry.key <= 0) {
        throw ArgumentError.value(entry.key, 'sides', 'Must be positive');
      }
      RangeError.checkValueInInterval(entry.value, 0, 20, 'count');
    }
    final generator = random ?? Random.secure();
    return DiceRoll([
      for (final entry in counts.entries)
        if (entry.value != 0)
          DiceRollGroup(
            entry.key,
            List.generate(entry.value, (_) => generator.nextInt(entry.key) + 1),
          ),
    ]);
  }
}
