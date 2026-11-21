import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/table_screen.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  test('Speed is a durable seat-local singleton bounded to 1–4', () async {
    final f = TableFixture(stateWithTokens([sampleToken()]));
    await f.initialize();
    addTearDown(f.dispose);
    final seat = f.playerId;
    final other = f.controller.session.players.last.id;
    final otherBefore = cloneJson(f.controller.player(other).toJson());
    final tokensBefore = f.player.tokens
        .map((t) => cloneJson(t.toJson()))
        .toList();
    await f.board.addUtility(seat, UtilityState.speedKind);
    final speed = f.player.utilities.last;
    expect(speed.value, 1);
    expect(speed.displayedArtworkUrl, UtilityState.speedArtworkUrl);
    expect(
      speed.configuration['artworkOptions'].single['artist'],
      'Zezhou Chen',
    );
    await f.board.adjustUtility(seat, speed.id, -50);
    expect(f.board.utilityValue(seat, speed.id), 1);
    await Future.wait([
      for (var i = 0; i < 10; i++) f.board.adjustUtility(seat, speed.id, 1),
    ]);
    expect(f.board.utilityValue(seat, speed.id), 4);
    expect(speed.formatValue(4), 'Max Speed!');
    await f.board.setUtility(seat, speed.id, visible: false);
    await f.board.addUtility(seat, UtilityState.speedKind);
    expect(
      f.player.utilities
          .where((u) => u.kind == UtilityState.speedKind)
          .single
          .id,
      speed.id,
    );
    expect(f.controller.player(other).toJson(), otherBefore);
    expect(f.player.tokens.map((t) => t.toJson()).toList(), tokensBefore);
    final restored = TabletState.fromJson(
      jsonMap(jsonDecode(f.repository.encoded)),
    );
    expect(restored.session.player(seat).utilities.last.value, 4);
    await f.board.adjustUtility(seat, speed.id, -1);
    expect(f.board.utilityValue(seat, speed.id), 3);
    expect(speed.formatValue(3), '3');
    expect(await f.controller.resetGame(keepBoard: true), isTrue);
    expect(f.player.utilities.singleWhere((u) => u.id == speed.id).value, 1);
  });

  testWidgets('Speed reads Max Speed on the board and in expanded controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    state.session.players.first.utilities.clear();
    final f = TableFixture(state);
    await f.initialize();
    addTearDown(f.dispose);
    await f.board.addUtility(f.playerId, UtilityState.speedKind);
    final id = f.player.utilities.single.id;
    await tester.pumpWidget(
      MaterialApp(
        home: TableScreen(
          controller: f.controller,
          enablePhonePresentation: true,
          compactPlayerOne: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = find.byKey(ValueKey('$id-value-surface'));
    final boardStepper = find.descendant(
      of: surface,
      matching: find.byType(HalfStepper),
    );
    expect(tester.widget<HalfStepper>(boardStepper).value, '1');
    expect(tester.widget<HalfStepper>(boardStepper).onDecrease, isNull);
    for (var i = 0; i < 3; i++) {
      final increase = byControlLabel('Increase Speed');
      await tester.ensureVisible(increase);
      await tester.tap(increase);
      await tester.pumpAndSettle();
    }
    expect(
      find.descendant(of: surface, matching: find.text('Max Speed!')),
      findsOneWidget,
    );
    expect(tester.widget<HalfStepper>(boardStepper).onIncrease, isNull);
    final detail = find.byKey(ValueKey('utility-details-$id'));
    await tester.ensureVisible(detail);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: detail, matching: find.text('Speed')));

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('utility-detail-speed')), findsOneWidget);
    final expanded = find.byWidgetPredicate(
      (widget) => widget is HalfStepper && widget.label == 'Value',
    );
    expect(
      find.descendant(of: expanded, matching: find.text('Max Speed!')),
      findsOneWidget,
    );
    expect(find.text('Set value'), findsNothing);
    await tester.tap(byControlLabel('Decrease Value'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: expanded, matching: find.text('Max Speed!')),
      findsNothing,
    );
    expect(
      find.descendant(of: expanded, matching: find.text('3')),
      findsOneWidget,
    );
    expect(f.player.utilities.single.value, 3);
    expect(tester.takeException(), isNull);
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
