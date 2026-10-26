import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    TextEditingController controller, {
    TextEditingController? number,
    int turns = 0,
    bool enabled = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1133, 744));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RotatedBox(
            quarterTurns: turns,
            child: PlayerKeyboardHost(
              enabled: enabled,
              child: ListView(
                children: [
                  PlayerField(controller: controller, label: 'Name'),
                  if (number != null)
                    PlayerField(
                      controller: number,
                      label: 'Quantity',
                      numeric: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'one-shot Shift is separate from selection and resets across fields',
    (tester) async {
      final c = TextEditingController(text: 'ab')
        ..selection = const TextSelection.collapsed(offset: 2);
      final n = TextEditingController(text: '12')
        ..selection = const TextSelection.collapsed(offset: 2);
      await open(tester, c, number: n);
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_left));
      expect(c.selection, const TextSelection.collapsed(offset: 1));
      await tester.tap(find.text('Q'));
      await tester.pump();
      await tester.tap(find.text('a'));
      expect(c.text, 'aQab');
      final semantics = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Extend selection'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_left));
      expect(c.selection.isCollapsed, isFalse);
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_left));
      expect(n.selection.isCollapsed, isTrue);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(find.text('q'), findsOneWidget);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      n.dispose();
    },
  );

  testWidgets(
    'clipboard unavailable and denied show inline errors without losing draft',
    (tester) async {
      final c = TextEditingController(text: 'keep');
      await open(tester, c);
      var denied = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              if (denied) throw PlatformException(code: 'denied');
              return null;
            }
            return null;
          });
      await tester.tap(find.byTooltip('Paste'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No text is available'), findsOneWidget);
      denied = true;
      await tester.tap(find.byTooltip('Paste'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Paste is unavailable'), findsOneWidget);
      expect(c.text, 'keep');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  for (final turns in [0, 1, 2, 3]) {
    testWidgets(
      'adaptive selection menu and cut/paste stay in rotated host $turns',
      (tester) async {
        final c = TextEditingController(text: 'keep')
          ..selection = const TextSelection(baseOffset: 0, extentOffset: 4);
        String? clipboard;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboard = (call.arguments as Map)['text'] as String;
              }
              if (call.method == 'Clipboard.getData') {
                return {'text': clipboard};
              }
              return null;
            });
        await open(tester, c, turns: turns);
        c.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.keyboardType, TextInputType.none);
        await tester.longPress(find.byType(TextField));
        await tester.pumpAndSettle();
        await tester.pump();
        final menu = find.byKey(const ValueKey('player-editing-toolbar'));
        expect(menu, findsOneWidget);
        expect(
          find.ancestor(of: menu, matching: find.byType(RotatedBox)),
          findsOneWidget,
        );
        await tester.tap(find.text('Select all'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cut'));
        await tester.pumpAndSettle();
        expect(c.text, '');
        expect(clipboard, 'keep');
        await tester.tap(find.text('Paste'));
        await tester.pumpAndSettle();
        expect(c.text, 'keep');
        await tester.tap(find.byTooltip('Text editing actions'));
        await tester.pumpAndSettle();
        expect(menu, findsNothing);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }

  testWidgets('async Cut never deletes newer text', (tester) async {
    final c = TextEditingController(text: 'original')
      ..selection = const TextSelection(baseOffset: 0, extentOffset: 8);
    final pending = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') await pending.future;
          return null;
        });
    await open(tester, c);
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
    await tester.tap(find.byTooltip('Text editing actions'));
    await tester.pump();
    await tester.tap(find.text('Cut'));
    await tester.pump();
    c.text = 'new draft';
    pending.complete();
    await tester.pumpAndSettle();
    expect(c.text, 'new draft');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    'backspace holds delete graphemes and cancel on release and disposal',
    (tester) async {
      final c = TextEditingController(text: 'abcdefgh👨‍👩‍👦')
        ..selection = const TextSelection.collapsed(offset: 16);
      c.selection = TextSelection.collapsed(offset: c.text.length);
      await open(tester, c);
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(c.text, 'abcdefgh');
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.backspace_outlined)),
      );
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.text.length, lessThan(8));
      await gesture.up();
      await tester.pump();
      final stopped = c.text;
      await tester.pump(const Duration(seconds: 1));
      expect(c.text, stopped);
      final again = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.backspace_outlined)),
      );
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpWidget(const SizedBox());
      await again.up();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
  for (final numeric in [false, true]) {
    for (final multiline in [false, true]) {
      testWidgets(
        'short focused keyboard has full 44px keys and restores form numeric=$numeric multiline=$multiline',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1133, 744));
          final c = TextEditingController(text: 'draft')
            ..selection = const TextSelection.collapsed(offset: 5);
          var closed = 0;
          String? saved;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(1.5),
                    ),
                    child: SizedBox(
                      key: const ValueKey('test-shell'),
                      width: 633,
                      height: 292.5,
                      child: PlayerKeyboardHost(
                        onClose: () => closed++,
                        showValue: true,
                        child: ListView(
                          children: [
                            const Text('Artwork editor'),
                            PlayerField(
                              controller: c,
                              label: 'Artwork URL',
                              numeric: numeric,
                              maxLines: multiline ? 3 : 1,
                            ),
                            const SizedBox(height: 120),
                            FilledButton(
                              onPressed: () => saved = c.text,
                              child: const Text('Use artwork'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();
          expect(find.text('Artwork editor'), findsNothing);
          expect(find.byTooltip('Close'), findsOneWidget);
          final shell = tester.getRect(
            find.byKey(const ValueKey('test-shell')),
          );
          final keys = find.descendant(
            of: find.byType(PlayerKeyboardHost),
            matching: find.byType(FilledButton),
          );
          for (final element in keys.evaluate()) {
            final rect = tester.getRect(find.byWidget(element.widget));
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(shell.contains(rect.topLeft), isTrue);
            expect(shell.contains(rect.bottomRight), isTrue);
          }
          final value = tester.widget<EditableText>(find.byType(EditableText));
          expect(identical(value.controller, c), isTrue);
          await tester.tap(find.text(numeric ? '1' : 'q'));
          await tester.pump();
          await tester.tap(find.text(numeric ? '2' : 'a'));
          await tester.pump();
          expect(c.text, numeric ? 'draft12' : 'draftqa');
          await tester.tap(find.byTooltip('Close'));
          await tester.pump();
          expect(closed, 1);
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          expect(find.text('Artwork editor'), findsOneWidget);
          expect(c.text, numeric ? 'draft12' : 'draftqa');
          await tester.ensureVisible(find.text('Use artwork'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Use artwork'));
          await tester.pump();
          expect(saved, c.text);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          c.dispose();
        },
      );
    }
  }
  testWidgets('backspace repeat stops on lifecycle pause and input lock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1133, 744));
    final c = TextEditingController(text: 'abcdefghijklmnopqrstuvwxyz')
      ..selection = const TextSelection.collapsed(offset: 26);
    var enabled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerKeyboardHost(
            canEdit: () => enabled,
            child: PlayerField(controller: c, label: 'Name'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    var gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.backspace_outlined)),
    );
    await tester.pump(const Duration(milliseconds: 650));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final paused = c.text;
    await tester.pump(const Duration(seconds: 1));
    expect(c.text, paused);
    await gesture.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.backspace_outlined)),
    );
    await tester.pump(const Duration(milliseconds: 650));
    enabled = false;
    final locked = c.text;
    await tester.pump(const Duration(seconds: 1));
    expect(c.text, locked);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
