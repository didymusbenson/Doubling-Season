import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'support/table_fixture.dart';

void main() {
  test(
    'start turn changes only target status, persists and undoes atomically',
    () async {
      final state = stateWithTokens([
        sampleToken(plusOne: 2, counters: {'shield': 1}),
      ]);
      state.session.players[1].tokens = [sampleToken(id: 'opponent')];
      final f = TableFixture(state);
      await f.initialize();
      addTearDown(f.dispose);
      final before = f.player.toJson();
      final opponent = f.controller.session.players[1].toJson();
      await f.board.startTurn(f.playerId);
      expect(f.token('source').tapped, 0);
      expect(f.token('source').summoningSick, 0);
      expect(f.token('source').amount, 3);
      expect(f.token('source').plusOneCounters, 2);
      expect(f.player.life, before['life']);
      expect(f.player.mana, before['mana']);
      expect(f.controller.session.players[1].toJson(), opponent);
      expect(f.controller.session.history.length, 1);
      final reopened = TableController(repository: f.repository);
      await reopened.initialize();
      addTearDown(reopened.dispose);
      expect(reopened.session.players.first.tokens.first.tapped, 0);
      expect(await f.controller.undo(), isTrue);
      // Undo deliberately advances the invalidation generation.
      final restored = f.player.toJson()..remove('generation');
      expect(restored, Map.of(before)..remove('generation'));
    },
  );

  test(
    'complete reset provisions default tools without old utility setup',
    () async {
      final f = TableFixture(stateWithTokens([sampleToken()]));
      await f.initialize();
      addTearDown(f.dispose);
      final oldIds = f.player.utilities.map((u) => u.id).toSet();
      f.player.utilities.first.visible = false;
      f.player.utilities.first.value = 9;
      await f.controller.resetGame(keepBoard: false, playerCount: 3);
      for (final player in f.controller.session.players) {
        expect(player.tokens, isEmpty);
        expect(player.utilities.map((u) => u.kind), [
          'storm_count',
          'mana_pool',
        ]);
        expect(
          player.utilities.every(
            (u) => u.visible && u.value == 0 && !oldIds.contains(u.id),
          ),
          isTrue,
        );
        expect(player.mana.values, everyElement(0));
      }
      expect(f.controller.state.archives.length, 1);
    },
  );

  test('failed start turn leaves all target status unchanged', () async {
    final f = TableFixture(stateWithTokens([sampleToken()]));
    await f.initialize();
    addTearDown(f.dispose);
    f.repository.failSave = true;
    await expectLater(f.board.startTurn(f.playerId), throwsStateError);
    expect(f.token('source').tapped, 1);
    expect(f.token('source').summoningSick, 1);
    expect(f.controller.session.history, isEmpty);
  });

  testWidgets(
    'numeric hold ramps magnitude and cadence, releases without late ticks',
    (tester) async {
      final steps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HalfStepper(
              label: 'Life',
              value: '40',
              onDecrease: () {},
              onIncrease: () {},
              onIncreaseHoldStep: (amount) {
                steps.add(amount);
              },
              increaseKey: const ValueKey('plus'),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('plus'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(steps, [5]);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(steps, contains(10));
      final count = steps.length;
      await tester.pump(const Duration(milliseconds: 150));
      expect(steps.length, greaterThan(count));
      for (var i = 0; i < 22; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(steps, contains(25));
      await gesture.up();
      final stopped = steps.length;
      await tester.pump(const Duration(seconds: 3));
      expect(steps.length, stopped);
    },
  );

  testWidgets(
    'pending persistence has no backlog and cancel prevents continuation',
    (tester) async {
      final gate = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HalfStepper(
              label: 'Life',
              value: '40',
              onDecrease: () {},
              onIncrease: () {},
              onIncreaseHoldStep: (_) {
                calls++;
                return gate.future;
              },
              increaseKey: const ValueKey('plus'),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('plus'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 6));
      expect(calls, 1);
      await gesture.cancel();
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 1);
    },
  );
  testWidgets('epoch changes cancel an accelerated hold', (tester) async {
    var epoch = 0;
    var calls = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: HalfStepper(
                label: 'Life',
                value: '40',
                onDecrease: () {},
                onIncrease: () {},
                interactionEpoch: epoch,
                onIncreaseHoldStep: (_) {
                  calls++;
                },
                increaseKey: const ValueKey('plus'),
              ),
            );
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('plus'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    rebuild(() => epoch++);
    await tester.pump();
    final stopped = calls;
    await tester.pump(const Duration(seconds: 3));
    expect(calls, stopped);
    await gesture.up();
  });
}
