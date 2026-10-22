import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';

import 'support/table_fixture.dart';

void main() {
  testWidgets(
    'real inline token field shares the keyboard controller and commits scoped text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1133, 744));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = TableFixture(stateWithTokens([sampleToken()]));
      await fixture.initialize();
      var locked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 290,
                child: ListenableBuilder(
                  listenable: fixture.controller,
                  builder: (context, _) => TabletTokenCard(
                    token: fixture.token('source'),
                    player: fixture.player,
                    board: fixture.board,
                    playerName: 'Player 1',
                    quarterTurns: 0,
                    expanded: true,
                    onExpand: () {},
                    onOpenDetailed: (_) {},
                    onInputLock: (value) => locked = value,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final otherSeat = fixture.controller.session.players[1].toJson();
      await tester.tap(find.text('Saproling'));
      await tester.pumpAndSettle();
      expect(locked, isTrue);
      final inline = tester.widget<TextField>(
        find.byKey(const ValueKey('inline:source:name'), skipOffstage: false),
      );
      final keyboard = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(PlayerKeyboardHost),
          matching: find.byType(EditableText),
        ),
      );
      expect(identical(inline.controller, keyboard.controller), isTrue);
      expect(inline.readOnly, isTrue);
      expect(inline.keyboardType, TextInputType.none);
      expect(inline.showCursor, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.text('z'));
      await tester.pumpAndSettle();
      expect(inline.controller!.text, 'Saprolingz');
      expect(keyboard.controller.selection.extentOffset, 10);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(locked, isFalse);
      expect(fixture.token('source').name, 'Saprolingz');
      expect(fixture.controller.session.players[1].toJson(), otherSeat);
      expect(fixture.controller.session.history.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    },
  );
}
