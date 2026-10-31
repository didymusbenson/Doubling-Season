import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_modal_frame.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.display.size = size;
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
  }

  Future<void> form(
    WidgetTester tester,
    TextEditingController controller, {
    bool numeric = false,
    bool multiline = false,
    Future<bool> Function()? onExit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: TableModalFrame(
            child: PlayerKeyboardHost(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PlayerField(
                    controller: controller,
                    label: 'Value',
                    numeric: numeric,
                    maxLines: multiline ? 3 : 1,
                    onExit: onExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
  }

  testWidgets('phone uses system text input and Done commits exactly once', (
    tester,
  ) async {
    phone(tester);
    final controller = TextEditingController(text: 'Before');
    addTearDown(controller.dispose);
    final save = Completer<bool>();
    var commits = 0;
    await form(
      tester,
      controller,
      onExit: () {
        commits++;
        return save.future;
      },
    );
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    expect(find.byKey(const ValueKey('player-keyboard-scroll')), findsNothing);
    await tester.enterText(find.byType(TextField), 'After paste 🌱');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.byKey(const ValueKey('native-keyboard-done')));
    expect(commits, 1);
    save.complete(true);
    await tester.pumpAndSettle();
    expect(controller.text, 'After paste 🌱');
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byKey(const ValueKey('native-keyboard-done')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('numeric Done stays above native IME at $size', (tester) async {
      phone(tester, size: size);
      final controller = TextEditingController(text: '12');
      addTearDown(controller.dispose);
      var commits = 0;
      await form(
        tester,
        controller,
        numeric: true,
        onExit: () async {
          commits++;
          return true;
        },
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.keyboardType,
        const TextInputType.numberWithOptions(signed: true),
      );
      final inset = size.height > 500 ? 350.0 : 210.0;
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pumpAndSettle();
      final done = find.byKey(const ValueKey('native-keyboard-done'));
      expect(
        tester.getRect(done).bottom,
        lessThanOrEqualTo(size.height - inset),
      );
      expect(done.hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextField), '-15');
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(controller.text, '-15');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('multiline native input keeps Return and explicit Done', (
    tester,
  ) async {
    phone(tester);
    final controller = TextEditingController(text: 'First');
    addTearDown(controller.dispose);
    var commits = 0;
    await form(
      tester,
      controller,
      multiline: true,
      onExit: () async {
        commits++;
        return true;
      },
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).textInputAction,
      TextInputAction.newline,
    );
    await tester.enterText(find.byType(TextField), 'First\nSecond');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
    expect(commits, 0);
    await tester.tap(find.byKey(const ValueKey('native-keyboard-done')));
    await tester.pumpAndSettle();
    expect(commits, 1);
    expect(controller.text, 'First\nSecond');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'inline native draft survives a presentation dismissal without save',
    (tester) async {
      phone(tester);
      final controller = TextEditingController(text: 'Saved');
      addTearDown(controller.dispose);
      var commits = 0;
      String? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showPlayerKeyboardEditor(
                    context,
                    title: 'Token name',
                    value: controller.text,
                    controller: controller,
                    onChanged: (text) => draft = text,
                    onCommit: (_) async {
                      commits++;
                    },
                  ),
                  child: const Text('Edit'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 350);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('native-inline-editor'));
      expect(input.hitTestable(), findsOneWidget);
      expect(tester.getRect(input).bottom, lessThan(494));
      await tester.enterText(input, 'Unfinished draft');
      final closing = dismissPlayerKeyboardForPresentationChange();
      await tester.pumpAndSettle();
      await closing;
      expect(commits, 0);
      expect(draft, 'Unfinished draft');
      expect(controller.text, 'Unfinished draft');
      expect(input, findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('narrow tablet window retains its player-facing keyboard', (
    tester,
  ) async {
    phone(tester);
    tester.view.display.size = const Size(1133, 744);
    final controller = TextEditingController(text: 'Tablet');
    addTearDown(controller.dispose);
    await form(tester, controller);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(find.byKey(const ValueKey('native-keyboard-done')), findsNothing);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed native field save keeps focus and draft before moving on',
    (tester) async {
      phone(tester);
      final first = TextEditingController(text: 'Draft');
      final second = TextEditingController(text: 'Other');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      var allowSave = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerKeyboardHost(
              child: ListView(
                children: [
                  PlayerField(
                    controller: first,
                    label: 'First',
                    onExit: () async => allowSave,
                  ),
                  PlayerField(controller: second, label: 'Second'),
                ],
              ),
            ),
          ),
        ),
      );
      final fields = find.byType(TextField);
      await tester.tap(fields.at(0));
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(0), 'Unfinished');
      await tester.tap(fields.at(1));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(fields.at(0)).focusNode!.hasFocus,
        isTrue,
      );
      expect(first.text, 'Unfinished');
      allowSave = true;
      await tester.tap(fields.at(1));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(fields.at(1)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(fields.at(1), 'Next draft');
      expect(first.text, 'Unfinished');
      expect(second.text, 'Next draft');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'inline phone power/toughness accepts symbols and Done saves once',
    (tester) async {
      phone(tester);
      final fixture = TableFixture(stateWithTokens([sampleToken()]));
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                TabletTokenCard(
                  token: fixture.token('source'),
                  player: fixture.player,
                  board: fixture.board,
                  playerName: 'Player 1',
                  quarterTurns: 0,
                  expanded: true,
                  onExpand: () {},
                  onOpenDetailed: (_) {},
                  onInputLock: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        byControlLabel('Player 1, Saproling, Base power and toughness'),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('native-inline-editor'));
      expect(tester.widget<TextField>(input).keyboardType, TextInputType.text);
      await tester.enterText(input, '*/1+*');
      await tester.tap(find.byKey(const ValueKey('native-keyboard-done')));
      await tester.pumpAndSettle();
      expect(fixture.token('source').pt, '*/1+*');
      expect(fixture.controller.session.history.length, 1);
      expect(input, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'landscape multiline inline draft and save error fit above native IME',
    (tester) async {
      phone(tester, size: const Size(844, 390));
      final controller = TextEditingController(text: 'First\nSecond\nThird');
      addTearDown(controller.dispose);
      var reject = true;
      var commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showPlayerKeyboardEditor(
                    context,
                    title: 'Abilities',
                    value: controller.text,
                    controller: controller,
                    multiline: true,
                    onChanged: (_) {},
                    onCommit: (_) async {
                      commits++;
                      if (reject) throw StateError('Storage unavailable');
                    },
                  ),
                  child: const Text('Edit'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 216);
      await tester.pumpAndSettle();
      final done = find.byKey(const ValueKey('native-keyboard-done'));
      expect(done.hitTestable(), findsOneWidget);
      expect(tester.getRect(done).bottom, lessThanOrEqualTo(174));
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(find.text('Retry').hitTestable(), findsOneWidget);
      expect(find.text('Close').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      reject = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(commits, 2);
      expect(find.byKey(const ValueKey('native-inline-editor')), findsNothing);
      expect(controller.text, 'First\nSecond\nThird');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
