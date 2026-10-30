import 'dart:ui' show PointerDeviceKind, SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/custom_token_fields.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  Future<void> hoverWithoutBubble(WidgetTester tester, Finder control) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(control));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(Tooltip), findsNothing);
    await mouse.removePointer();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'color controls retain selected and disabled semantics without hover or hold bubbles',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final identity = TextEditingController();
      addTearDown(identity.dispose);
      var enabled = true;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return CustomTokenColorPicker(
                  controller: identity,
                  enabled: enabled,
                );
              },
            ),
          ),
        ),
      );
      final white = find.byKey(const ValueKey('custom-token-color-W'));
      final colorless = find.byKey(const ValueKey('custom-token-color-C'));
      expect(tester.getSemantics(white).label, 'White color identity');
      expect(tester.getSemantics(white).flagsCollection.isButton, isTrue);
      expect(
        tester.getSemantics(white).flagsCollection.isEnabled.toBoolOrNull(),
        isTrue,
      );
      expect(
        tester.getSemantics(colorless).flagsCollection.isToggled.toBoolOrNull(),
        isTrue,
      );
      expect(
        tester
            .getSemantics(white)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await hoverWithoutBubble(tester, white);
      final hold = await tester.startGesture(tester.getCenter(white));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Tooltip), findsNothing);
      await hold.cancel();
      await tester.pumpAndSettle();
      await tester.tap(white);
      await tester.pumpAndSettle();
      expect(identity.text, 'W');
      expect(
        tester.getSemantics(white).flagsCollection.isToggled.toBoolOrNull(),
        isTrue,
      );
      expect(
        tester.getSemantics(colorless).flagsCollection.isToggled.toBoolOrNull(),
        isFalse,
      );
      rebuild(() => enabled = false);
      await tester.pump();
      expect(
        tester.getSemantics(white).flagsCollection.isEnabled.toBoolOrNull(),
        isFalse,
      );
      expect(
        tester
            .getSemantics(white)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'token hold remains functional and named without a tooltip overlay',
    (tester) async {
      final fixture = TableFixture(
        stateWithTokens([sampleToken(amount: 7, tapped: 4)]),
      );
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: ListenableBuilder(
                  listenable: fixture.controller,
                  builder: (context, _) => TabletTokenCard(
                    token: fixture.token('source'),
                    player: fixture.player,
                    board: fixture.board,
                    playerName: 'Player 1',
                    quarterTurns: 0,
                    expanded: false,
                    onExpand: () {},
                    onOpenDetailed: (_) {},
                    onInputLock: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final untap = byControlLabel('Untap one; hold to untap all');
      final node = tester.getSemantics(untap);
      expect(node.label, 'Player 1, Saproling, Untap one; hold to untap all');
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        node.getSemanticsData().flagsCollection.isEnabled.toBoolOrNull(),
        isTrue,
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.longPress),
        isTrue,
      );
      await hoverWithoutBubble(tester, untap);
      final hold = await tester.startGesture(tester.getCenter(untap));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(fixture.token('source').tapped, 0);
      expect(find.byType(Tooltip), findsNothing);
      expect(find.text('Untap one; hold to untap all'), findsNothing);
      await hold.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'keyboard Paste retains its named action and editing menu without hover bubbles',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final draft = TextEditingController(text: 'draft');
      addTearDown(draft.dispose);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async => call.method == 'Clipboard.getData'
                ? {'text': ' preserved'}
                : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.binding.setSurfaceSize(const Size(1133, 744));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerKeyboardHost(
              child: PlayerField(controller: draft, label: 'Token name'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final paste = byControlLabel('Paste');
      var node = tester.getSemantics(paste);
      while (node.isMergedIntoParent) {
        node = node.parent!;
      }
      expect(node.label, 'Paste');
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await hoverWithoutBubble(tester, paste);
      await tester.tap(paste);
      await tester.pumpAndSettle();
      expect(draft.text, contains('preserved'));
      await tester.tap(byControlLabel('Select all'));
      await tester.pumpAndSettle();
      await tester.tap(byControlLabel('Text editing actions'));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
      semantics.dispose();
    },
  );
}
