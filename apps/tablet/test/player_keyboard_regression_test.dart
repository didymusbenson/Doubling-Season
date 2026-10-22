import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';

void main() {
  Future<void> tabletSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1133, 744));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

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

      await tester.tap(find.text('↵'));
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

      await tester.tap(find.byTooltip('Select all'));
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
    await tester.tap(find.text('↵'));
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
