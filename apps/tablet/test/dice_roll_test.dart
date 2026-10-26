import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/workspace/dice_roll.dart';

class _RecordedRandom implements Random {
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return (bounds.length - 1) % max;
  }

  @override
  bool nextBool() => throw StateError('Unexpected boolean draw');
  @override
  double nextDouble() => throw StateError('Unexpected floating-point draw');
}

void main() {
  test('one bounded draw per selected die in insertion order; skips zero', () {
    final random = _RecordedRandom();
    final roll = DiceRoll.generate({
      20: 2,
      4: 1,
      6: 0,
      8: 2,
      10: 0,
      12: 1,
    }, random: random);
    expect(random.bounds, [20, 20, 4, 8, 8, 12]);
    expect(roll.groups.map((group) => group.sides), [20, 4, 8, 12]);
    expect(roll.groups.map((group) => group.faces), [
      [1, 2],
      [3],
      [4, 5],
      [6],
    ]);
    expect(roll.groups.map((group) => group.count), [2, 1, 2, 1]);
    expect(roll.groups.map((group) => group.total), [3, 3, 9, 6]);
    expect(roll.total, 21);
    // Reading summaries does not generate additional results.
    expect(random.bounds, hasLength(6));
  });

  test('groups and faces are immutable snapshots of caller collections', () {
    final faces = [2, 5];
    final group = DiceRollGroup(6, faces);
    final groups = [group];
    final roll = DiceRoll(groups);
    faces[0] = 6;
    groups.clear();
    expect(roll.groups.single.faces, [2, 5]);
    expect(roll.total, 7);
    expect(() => group.faces.add(1), throwsUnsupportedError);
    expect(() => roll.groups.clear(), throwsUnsupportedError);
  });

  test('zero selection retains empty groups and total zero with no draws', () {
    final random = _RecordedRandom();
    final roll = DiceRoll.generate({
      4: 0,
      6: 0,
      8: 0,
      10: 0,
      12: 0,
      20: 0,
    }, random: random);
    expect(roll.groups, isEmpty);
    expect(roll.total, 0);
    expect(random.bounds, isEmpty);
  });

  test(
    'maximum selection preserves all 120 faces and valid denomination ranges',
    () {
      final random = _RecordedRandom();
      final roll = DiceRoll.generate({
        4: 20,
        6: 20,
        8: 20,
        10: 20,
        12: 20,
        20: 20,
      }, random: random);
      expect(random.bounds, hasLength(120));
      expect(roll.groups, hasLength(6));
      var total = 0;
      for (final group in roll.groups) {
        expect(group.faces, hasLength(20));
        for (final face in group.faces) {
          expect(face, inInclusiveRange(1, group.sides));
          total += face;
        }
      }
      expect(roll.total, total);
    },
  );

  test('invalid counts or sides fail before any injected random draws', () {
    for (final counts in [
      {6: -1},
      {6: 21},
      {0: 1},
    ]) {
      final random = _RecordedRandom();
      expect(
        () => DiceRoll.generate(counts, random: random),
        throwsArgumentError,
      );
      expect(random.bounds, isEmpty);
    }
  });

  test('default secure path supports the existing one-d6 selection', () {
    final roll = DiceRoll.generate({4: 0, 6: 1, 8: 0, 10: 0, 12: 0, 20: 0});
    expect(roll.groups.single.sides, 6);
    expect(roll.groups.single.count, 1);
    expect(roll.groups.single.faces.single, inInclusiveRange(1, 6));
    expect(roll.total, roll.groups.single.faces.single);
  });
}
