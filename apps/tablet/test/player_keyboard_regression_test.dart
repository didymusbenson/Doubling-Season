import 'support/control_finders.dart';
import 'dart:ui' show PointerDeviceKind;

import 'package:doubling_season/utils/mana_symbol_parser.dart';
import 'package:doubling_season/widgets/mana/mana_text.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';

void main() {
  Future<void> tabletSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1133, 744));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('command keys use bundled Material icons, not text font glyphs', (
    tester,
  ) async {
    await tabletSize(tester);
    final controller = TextEditingController(text: 'ab');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerKeyboardHost(
            child: PlayerField(
              controller: controller,
              label: 'Artwork search',
              maxLines: 3,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PlayerField));
    await tester.pumpAndSettle();
    for (final icon in [
      Icons.arrow_upward,
      Icons.keyboard_arrow_left,
      Icons.keyboard_arrow_right,
      Icons.keyboard_return,
      Icons.backspace_outlined,
    ]) {
      expect(find.byIcon(icon), findsOneWidget);
      expect(icon.fontFamily, 'MaterialIcons');
    }
    for (final glyph in ['⇧', '⌫', '←', '→', '↵']) {
      expect(find.text(glyph), findsNothing);
    }
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Shift'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete previous character'), findsOneWidget);
    expect(find.bySemanticsLabel('Move cursor left'), findsOneWidget);
    expect(find.bySemanticsLabel('Return'), findsOneWidget);
    semantics.dispose();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Q'));
    await tester.pumpAndSettle();
    expect(controller.text, contains('Q'));
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pumpAndSettle();
    expect(controller.text, isNot(contains('Q')));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'multiline fields insert hardware and visible Return until Done',
    (tester) async {
      await tabletSize(tester);
      final controller = TextEditingController(text: 'First');
      var commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerKeyboardHost(
              child: Align(
                alignment: Alignment.topCenter,
                child: PlayerField(
                  controller: controller,
                  label: 'Abilities',
                  maxLines: 3,
                  onExit: () async {
                    commits++;
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.text, 'First\n');
      expect(commits, 0);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pump();
      expect(controller.text, 'First\n\n');
      expect(commits, 0);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(find.text('Done'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'inline field and keyboard share caller-owned controller and selection',
    (tester) async {
      await tabletSize(tester);
      final controller = TextEditingController(text: 'Inline');
      controller.selection = const TextSelection.collapsed(offset: 2);
      String? draft;
      String? saved;
      await tester.pumpWidget(
        _EditorHarness(
          controller: controller,
          value: () => 'Ignored when a controller is supplied',
          onChanged: (value) => draft = value,
          onCommit: (value) async => saved = value,
          onResult: (_) {},
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final inline = tester.widget<TextField>(
        find.byKey(const ValueKey('inline-field')),
      );
      final preview = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(PlayerKeyboardHost),
          matching: find.byType(EditableText),
        ),
      );
      expect(identical(inline.controller, preview.controller), isTrue);
      expect(identical(controller, preview.controller), isTrue);
      expect(controller.text, 'Inline');
      expect(controller.selection, const TextSelection.collapsed(offset: 2));

      await tester.tap(find.text('z'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Inzline');
      expect(draft, 'Inzline');
      expect(inline.controller!.text, 'Inzline');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(saved, 'Inzline');
      // Disposing the keyboard route must leave the card's controller usable.
      controller.text = 'Still owned by the token';
      await tester.pump();
      expect(find.text('Still owned by the token'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    for (final turns in [0, 2]) {
      testWidgets(
        'explicit selection survives keyboard focus changes on $platform at $turns turns',
        (tester) async {
          await tabletSize(tester);
          final controller = TextEditingController(text: 'Original name')
            ..selection = const TextSelection.collapsed(offset: 13);
          String? saved;
          await tester.pumpWidget(
            _EditorHarness(
              controller: controller,
              value: () => controller.text,
              onChanged: (_) {},
              onCommit: (value) async => saved = value,
              onResult: (_) {},
              quarterTurns: turns,
            ),
          );
          await tester.tap(find.text('Edit'));
          await tester.pumpAndSettle();
          expect(
            controller.selection,
            const TextSelection.collapsed(offset: 13),
          );
          Future<void> tap(Finder target) async {
            // A browser/desktop keyboard button can take focus before onPressed.
            // Model that focus transfer explicitly; touch-only tests omit it.
            Focus.of(tester.element(target)).requestFocus();
            await tester.pump();
            await tester.tap(target, kind: PointerDeviceKind.mouse);
            await tester.pumpAndSettle();
          }

          await tap(byControlLabel('Select all'));
          expect(
            controller.selection,
            const TextSelection(baseOffset: 0, extentOffset: 13),
          );
          await tap(find.text('q'));
          final afterQ = controller.selection;
          await tap(find.text('a'));
          expect(controller.text, 'qa');
          expect(afterQ, const TextSelection.collapsed(offset: 1));
          await tap(find.text('a'));
          expect(controller.text, 'qaa');
          await tap(byControlLabel('Move cursor left'));
          await tap(find.text('q'));
          expect(controller.text, 'qaqa');
          controller.selection = const TextSelection(
            baseOffset: 1,
            extentOffset: 3,
          );
          await tap(find.text('z'));
          expect(controller.text, 'qza');
          await tap(byControlLabel('Delete previous character'));
          expect(controller.text, 'qa');
          await tap(byControlLabel('Select all'));
          await tap(find.text('z'));
          expect(controller.text, 'z');
          await tap(find.text('Done'));
          expect(saved, 'z');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets(
      'Apple keyboards use native-style command symbols on $platform',
      (tester) async {
        await tabletSize(tester);
        final controller = TextEditingController(text: 'ab');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlayerKeyboardHost(
                child: PlayerField(
                  controller: controller,
                  label: 'Abilities',
                  maxLines: 2,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(PlayerField));
        await tester.pumpAndSettle();
        for (final icon in [
          CupertinoIcons.shift,
          CupertinoIcons.arrow_left,
          CupertinoIcons.arrow_right,
          CupertinoIcons.return_icon,
          CupertinoIcons.delete_left,
          CupertinoIcons.doc_on_clipboard,
        ]) {
          expect(find.byIcon(icon), findsOneWidget);
        }
        expect(find.byIcon(Icons.backspace_outlined), findsNothing);
        await tester.tap(byControlLabel('Shift'));
        await tester.pumpAndSettle();
        expect(find.byIcon(CupertinoIcons.shift_fill), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets(
    'mana row replaces selected text and parses as rendered symbols',
    (tester) async {
      await tabletSize(tester);
      final controller = TextEditingController(text: 'Cost 🔥 and draw')
        ..selection = const TextSelection(baseOffset: 7, extentOffset: 5);
      addTearDown(controller.dispose);
      String? saved;
      await tester.pumpWidget(
        _EditorHarness(
          controller: controller,
          value: () => controller.text,
          onChanged: (_) {},
          onCommit: (value) async => saved = value,
          onResult: (_) {},
          multiline: true,
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      final strip = find.byKey(
        const ValueKey('player-keyboard-mana-shortcuts'),
      );
      expect(strip, findsOneWidget);
      expect(
        find.descendant(
          of: strip,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'mana-shortcut-',
                ),
          ),
        ),
        findsNWidgets(16),
      );
      for (final (key, label) in [
        ('W', 'Insert one white mana'),
        ('9', 'Insert nine generic mana'),
        ('T', 'Insert tap'),
      ]) {
        final keyFinder = find.byKey(ValueKey('mana-shortcut-$key'));
        await tester.ensureVisible(keyFinder);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(label), findsOneWidget);
        await tester.tap(keyFinder);
        await tester.pumpAndSettle();
      }
      expect(controller.text, 'Cost {W}{9}{T} and draw');
      expect(controller.selection, const TextSelection.collapsed(offset: 14));
      final spans = ManaSymbolParser.buildSpans(
        text: controller.text,
        symbolSize: 20,
        textColor: null,
      );
      expect(spans.whereType<WidgetSpan>(), hasLength(3));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(saved, controller.text);
      await tester.pumpWidget(MaterialApp(home: ManaText(saved!)));
      expect(
        find.bySemanticsLabel(
          'Cost one white mananine generic manatap and draw',
        ),
        findsOneWidget,
      );
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final turns in [0, 1]) {
    testWidgets(
      'mana shortcuts scroll on a small tablet view at $turns turns',
      (tester) async {
        // Constrain only the window: this is a tablet viewport, not a phone.
        await tester.binding.setSurfaceSize(const Size(320, 490));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = TextEditingController(text: 'A' * 1200);
        final number = TextEditingController(text: '12');
        addTearDown(controller.dispose);
        addTearDown(number.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RotatedBox(
                quarterTurns: turns,
                child: PlayerKeyboardHost(
                  focusTextEntry: true,
                  child: ListView(
                    children: [
                      PlayerField(controller: controller, label: 'Rules text'),
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
        await tester.tap(find.byType(PlayerField).first);
        await tester.pumpAndSettle();
        final strip = find.byKey(
          const ValueKey('player-keyboard-mana-shortcuts'),
        );
        final scroll = tester.state<ScrollableState>(
          find.descendant(of: strip, matching: find.byType(Scrollable)),
        );
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        final last = find.byKey(const ValueKey('mana-shortcut-T'));
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(controller.text, '${'A' * 1200}{T}');
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PlayerField).last);
        await tester.pumpAndSettle();
        expect(strip, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('failed save keeps draft and supports close then resume', (
    tester,
  ) async {
    await tabletSize(tester);
    var draft = 'A';
    var reject = true;
    var commits = 0;
    bool? result;
    await tester.pumpWidget(
      _EditorHarness(
        value: () => draft,
        onChanged: (value) => draft = value,
        onCommit: (_) async {
          commits++;
          if (reject) throw StateError('Storage unavailable');
        },
        onResult: (value) => result = value,
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ, character: 'z');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(commits, 1);
    expect(draft, 'Az');
    expect(result, isNull);
    expect(find.textContaining('Storage unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(draft, 'Az');
    expect(find.byType(PlayerKeyboardHost), findsNothing);

    reject = false;
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Az'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(commits, 2);
    expect(draft, 'Az');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long inline drafts scroll with the visible caret and selection',
    (tester) async {
      await tabletSize(tester);
      const lastCharacter = '👨‍👩‍👦';
      var draft =
          '${List.filled(80, 'Saproling ability ').join()}$lastCharacter';
      final originalLength = draft.length;
      await tester.pumpWidget(
        _EditorHarness(
          value: () => draft,
          onChanged: (value) => draft = value,
          onCommit: (_) async {},
          onResult: (_) {},
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final fieldFinder = find.byType(EditableText);
      final field = tester.widget<EditableText>(fieldFinder);
      expect(field.readOnly, isTrue);
      expect(field.keyboardType, TextInputType.none);
      expect(field.showCursor, isTrue);
      expect(field.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: fieldFinder, matching: find.byType(Scrollable)),
      );
      expect(scroll.position.pixels, greaterThan(0));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        field.controller.selection.extentOffset,
        originalLength - lastCharacter.length,
      );
      expect(field.focusNode.hasFocus, isTrue);

      await tester.tap(byControlLabel('Select all'));
      await tester.pump();
      final editable = tester.state<EditableTextState>(fieldFinder);
      expect(
        editable.renderEditable.selection,
        TextSelection(baseOffset: 0, extentOffset: originalLength),
      );
      await tester.tap(find.text('z'));
      await tester.pumpAndSettle();
      expect(draft, 'z');
      expect(
        field.controller.selection,
        const TextSelection.collapsed(offset: 1),
      );
      expect(scroll.position.pixels, 0);
      expect(field.focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('top-seat overlay rotates keys and still commits multiline input', (
    tester,
  ) async {
    await tabletSize(tester);
    var draft = 'Tap';
    String? saved;
    bool? result;
    await tester.pumpWidget(
      _EditorHarness(
        value: () => draft,
        onChanged: (value) => draft = value,
        onCommit: (value) async => saved = value,
        onResult: (value) => result = value,
        quarterTurns: 2,
        multiline: true,
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final rotation = tester.widget<RotatedBox>(
      find.ancestor(
        of: find.byType(PlayerKeyboardHost),
        matching: find.byType(RotatedBox),
      ),
    );
    expect(rotation.quarterTurns, 2);
    // Rotating the complete host puts the software keys at the top player's edge.
    expect(tester.getCenter(find.text('q')).dy, lessThan(372));
    await tester.tap(find.byIcon(Icons.keyboard_return));
    await tester.pump();
    expect(draft, 'Tap\n');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(saved, 'Tap\n');
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _EditorHarness extends StatelessWidget {
  const _EditorHarness({
    required this.value,
    required this.onChanged,
    required this.onCommit,
    required this.onResult,
    this.controller,
    this.quarterTurns = 0,
    this.multiline = false,
  });

  final String Function() value;
  final ValueChanged<String> onChanged;
  final Future<void> Function(String) onCommit;
  final ValueChanged<bool> onResult;
  final TextEditingController? controller;
  final int quarterTurns;
  final bool multiline;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(behavior: HitTestBehavior.opaque),
            if (controller != null)
              Positioned(
                left: 40,
                right: 40,
                top: 40,
                child: TextField(
                  key: const ValueKey('inline-field'),
                  controller: controller,
                  readOnly: true,
                  showCursor: true,
                  keyboardType: TextInputType.none,
                ),
              ),
            Center(
              child: FilledButton(
                onPressed: () async {
                  onResult(
                    await showPlayerKeyboardEditor(
                      context,
                      title: 'Token abilities',
                      value: value(),
                      controller: controller,
                      multiline: multiline,
                      quarterTurns: quarterTurns,
                      onChanged: onChanged,
                      onCommit: onCommit,
                    ),
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
