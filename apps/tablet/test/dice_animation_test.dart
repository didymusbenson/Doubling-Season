import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/die_outline.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  Finder key(String value) => find.byKey(ValueKey(value));
  late TableFixture fixture;
  late StateSetter rebuild;
  bool reducedMotion = false;

  Future<void> open(WidgetTester tester, {bool reduced = false}) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fixture = TableFixture();
    await fixture.initialize();
    fixture.catalog.loaded = true;
    addTearDown(fixture.dispose);
    addTearDown(() async {
      final close = byControlLabel('Close workspace');
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    reducedMotion = reduced;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reducedMotion),
              child: child!,
            );
          },
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTableWorkspace(
                context,
                fixture.controller,
                catalog: fixture.catalog,
                initialPage: WorkspacePage.dice,
              ),
              child: const Text('Open dice'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dice'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    final closeButton = byControlLabel('Close workspace');
    if (closeButton.evaluate().isNotEmpty) {
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    final roll = key('dice-roll-button');
    await tester.ensureVisible(roll);
    await tester.pumpAndSettle();
    await tester.tap(roll);
    await tester.pump();
  }

  testWidgets(
    'roll animates for 750ms, ignores repeats, and reveals one stable result',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await open(tester);
      final before = fixture.controller.state.toJson();
      final roll = key('dice-roll-button');
      await tester.ensureVisible(roll);
      await tester.pumpAndSettle();
      final repeat = tester.widget<FilledButton>(roll).onPressed!;
      repeat();
      repeat();
      repeat();
      await tester.pump();
      expect(key('dice-animation-1'), findsOneWidget);
      expect(key('dice-animation-2'), findsNothing);
      expect(
        tester.widget<FilledButton>(key('dice-reroll-button')).onPressed,
        isNull,
      );
      expect(find.bySemanticsLabel(RegExp(r'D6 result 1:')), findsNothing);
      expect(tester.widget<Text>(key('dice-summary')).data, 'Rolling…');
      final finalLabel = tester
          .widget<DieOutline>(key('dice-result-d6-0'))
          .semanticsLabel!;
      final expected = int.parse(finalLabel.split(': ').last);
      final firstFrame = tester
          .widget<DieOutline>(key('dice-result-d6-0'))
          .value;
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        tester.widget<DieOutline>(key('dice-result-d6-0')).value,
        isNot(firstFrame),
      );
      await tester.pump(const Duration(milliseconds: 529));
      expect(tester.widget<Text>(key('dice-summary')).data, 'Rolling…');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(tester.widget<Text>(key('dice-summary')).data, 'Total: $expected');
      expect(
        tester.widget<DieOutline>(key('dice-result-d6-0')).value,
        expected,
      );
      expect(find.bySemanticsLabel(finalLabel), findsOneWidget);
      expect(
        tester.widget<FilledButton>(key('dice-reroll-button')).onPressed,
        isNotNull,
      );
      rebuild(() {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<DieOutline>(key('dice-result-d6-0')).value,
        expected,
      );
      expect(fixture.controller.state.toJson(), before);
      expect(tester.takeException(), isNull);
      await close(tester);
      semantics.dispose();
    },
  );

  testWidgets(
    'reduced motion skips animation and delay including mid-roll changes',
    (tester) async {
      await open(tester, reduced: true);
      final before = fixture.controller.state.toJson();
      await start(tester);
      expect(
        tester.widget<Text>(key('dice-summary')).data,
        startsWith('Total:'),
      );
      expect(
        tester.widget<FilledButton>(key('dice-reroll-button')).onPressed,
        isNotNull,
      );
      rebuild(() => reducedMotion = false);
      await tester.pump();
      await tester.tap(key('dice-reroll-button'));
      await tester.pump();
      expect(tester.widget<Text>(key('dice-summary')).data, 'Rolling…');
      final expected = int.parse(
        tester
            .widget<DieOutline>(key('dice-result-d6-0'))
            .semanticsLabel!
            .split(': ')
            .last,
      );
      await tester.pump(const Duration(milliseconds: 100));
      rebuild(() => reducedMotion = true);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<Text>(key('dice-summary')).data, 'Total: $expected');
      expect(
        tester.widget<FilledButton>(key('dice-reroll-button')).onPressed,
        isNotNull,
      );
      rebuild(() => reducedMotion = false);
      await tester.pump();
      expect(tester.widget<Text>(key('dice-summary')).data, 'Total: $expected');
      expect(fixture.controller.state.toJson(), before);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets(
    'back and close interrupt motion without locking subsequent rolls',
    (tester) async {
      await open(tester);
      final before = fixture.controller.state.toJson();
      await start(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(byControlLabel('Back'));
      await tester.pumpAndSettle();
      expect(key('dice-selector'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(key('dice-roll-button')).onPressed,
        isNotNull,
      );
      await start(tester);
      expect(key('dice-animation-2'), findsOneWidget);
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Open dice'), findsOneWidget);
      await tester.tap(find.text('Open dice'));
      await tester.pumpAndSettle();
      await start(tester);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(key('dice-summary')).data,
        startsWith('Total:'),
      );
      expect(fixture.controller.state.toJson(), before);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets('backgrounding settles animation without replacing its result', (
    tester,
  ) async {
    await open(tester);
    await start(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final expected = int.parse(
      tester
          .widget<DieOutline>(key('dice-result-d6-0'))
          .semanticsLabel!
          .split(': ')
          .last,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<Text>(key('dice-summary')).data, 'Total: $expected');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      tester.widget<FilledButton>(key('dice-reroll-button')).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
    'zero selected dice completes immediately without an animation lock',
    (tester) async {
      await open(tester);
      await tester.tap(byControlLabel('Decrease d6'));
      await tester.pump();
      await start(tester);
      expect(find.text('Select at least one die.'), findsOneWidget);
      expect(tester.widget<Text>(key('dice-summary')).data, 'Total: 0');
      expect(
        tester.widget<FilledButton>(key('dice-reroll-button')).onPressed,
        isNotNull,
      );
      await tester.tap(byControlLabel('Back'));
      await tester.pumpAndSettle();
      await tester.tap(byControlLabel('Increase d4'));
      await tester.pump();
      await start(tester);
      expect(tester.widget<Text>(key('dice-summary')).data, 'Rolling…');
      await tester.pumpAndSettle();
      expect(key('dice-result-d4-0'), findsOneWidget);
      expect(key('dice-result-d6-0'), findsNothing);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );
}
