import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/die_outline.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final directory = Platform.environment['TABLET_CAPTURE_DIR'];
  const captureKey = ValueKey('dice-flow-capture');
  const sides = [4, 6, 8, 10, 12, 20];
  Finder key(String value) => find.byKey(ValueKey(value));

  setUpAll(() async {
    if (directory == null) return;
    await Directory(directory).create(recursive: true);
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${font.value}',
      );
      await (FontLoader(
        font.key,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (directory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(boundary);
    await tester.pump();
    final pending = boundary.toImage(pixelRatio: 1);
    await tester.runAsync(() async {
      final image = await pending;
      try {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$directory/dice-$name.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void expectCornerClear(WidgetTester tester, Finder die) {
    final dieBounds = tester.getRect(die);
    for (final label in ['Back', 'Close workspace']) {
      final control = find.byTooltip(label);
      expect(control, findsOneWidget);
      expect(
        dieBounds.overlaps(tester.getRect(control)),
        isFalse,
        reason: 'The first result die must not overlap $label.',
      );
      expect(tester.getSize(control).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
    }
  }

  Future<void> scrollToStart(WidgetTester tester, Finder target) async {
    final scrollable = find
        .ancestor(of: target, matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
  }

  Future<TableFixture> open(
    WidgetTester tester,
    Size size,
    double scale, {
    int quarterTurns = 0,
    bool safeInsets = false,
  }) async {
    tester.view.physicalSize = size;
    if (safeInsets) {
      tester.view.padding = const FakeViewPadding(
        left: 23,
        top: 12,
        right: 7,
        bottom: 18,
      );
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = TableFixture();
    await fixture.initialize();
    fixture.catalog.loaded = true;
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTableWorkspace(
                  context,
                  fixture.controller,
                  catalog: fixture.catalog,
                  initialPage: WorkspacePage.dice,
                  quarterTurns: quarterTurns,
                ),
                child: const Text('Open dice'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dice'));
    await tester.pumpAndSettle();
    return fixture;
  }

  for (final size in [
    const Size(600, 1024),
    const Size(1133, 744),
    const Size(650, 480),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('dice selector and focused results $size scale $scale', (
        tester,
      ) async {
        final fixture = await open(tester, size, scale);
        final before = fixture.controller.state.toJson();
        final persisted = fixture.repository.encoded;
        final tag = '${size.width.toInt()}x${size.height.toInt()}-scale$scale';
        expect(key('dice-selector'), findsOneWidget);
        for (final die in sides) {
          expect(key('dice-selection-d$die'), findsOneWidget);
          expect(key('dice-count-d$die'), findsOneWidget);
          final outline = tester.widget<DieOutline>(key('dice-count-d$die'));
          expect(outline.sides, die);
          expect(outline.value, die == 6 ? 1 : 0);
          for (final direction in ['Increase', 'Decrease']) {
            final action = find.byTooltip('$direction d$die');
            expect(action, findsOneWidget);
            final bounds = tester.getSize(action);
            expect(bounds.width, greaterThanOrEqualTo(44));
            expect(bounds.height, greaterThanOrEqualTo(44));
          }
        }
        final roll = key('dice-roll-button');
        expect(roll, findsOneWidget);
        final rollTop = tester.getTopLeft(roll).dy;
        for (final die in sides) {
          expect(
            tester.getBottomRight(key('dice-selection-d$die')).dy,
            lessThanOrEqualTo(rollTop),
          );
        }
        await capture(tester, '$tag-selector');
        // One of every die plus the default d6: a focused result must retain
        // each individual outcome, not only a sum or the latest die.
        for (final die in sides.where((value) => value != 6)) {
          await tap(tester, find.byTooltip('Increase d$die'));
        }
        await scrollToStart(tester, key('dice-count-d4'));
        await capture(tester, '$tag-populated-selector');
        await tester.ensureVisible(roll);
        await tester.pumpAndSettle();
        final selectorScroll = find
            .ancestor(of: roll, matching: find.byType(Scrollable))
            .first;
        final savedOffset = tester
            .state<ScrollableState>(selectorScroll)
            .position
            .pixels;
        if (size.height == 480) {
          expect(savedOffset, greaterThan(0));
        }
        await tap(tester, roll);
        expect(key('dice-results'), findsOneWidget);
        expect(key('dice-selector'), findsNothing);
        for (final die in sides) {
          final result = key('dice-result-d$die-0');
          await tester.ensureVisible(result);
          await tester.pumpAndSettle();
          expect(result.hitTestable(), findsOneWidget);
          final outcome = tester.widget<DieOutline>(result);
          expect(outcome.sides, die);
          expect(outcome.showDenomination, isFalse);
          expect(
            find.descendant(
              of: result,
              matching: find.byKey(const ValueKey('die-denomination')),
            ),
            findsNothing,
          );
          expect(find.text('1 × D$die'), findsOneWidget);
          expect(outcome.value, inInclusiveRange(1, die));
        }
        expect(key('dice-summary'), findsOneWidget);
        expect(find.text('6 dice rolled'), findsOneWidget);
        expect(find.textContaining('Subtotal:'), findsNothing);
        await tap(tester, key('dice-reroll-button'));
        for (final die in sides) {
          expect(key('dice-result-d$die-0'), findsOneWidget);
        }
        await scrollToStart(tester, key('dice-result-d4-0'));
        expectCornerClear(tester, key('dice-result-d4-0'));
        await capture(tester, '$tag-results');
        await tap(tester, find.byTooltip('Back'));
        expect(key('dice-selector'), findsOneWidget);
        final restoredScroll = find
            .ancestor(
              of: key('dice-roll-button'),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(
          tester.state<ScrollableState>(restoredScroll).position.pixels,
          closeTo(savedOffset, .1),
        );
        for (final die in sides) {
          expect(tester.widget<DieOutline>(key('dice-count-d$die')).value, 1);
        }
        await tap(tester, key('dice-roll-button'));
        for (final die in sides) {
          expect(key('dice-result-d$die-0'), findsOneWidget);
        }
        expect(fixture.controller.state.toJson(), before);
        expect(fixture.repository.encoded, persisted);
        expect(tester.takeException(), isNull);
        await tap(tester, find.byTooltip('Close workspace'));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final size in [
    const Size(600, 1024),
    const Size(1133, 744),
    const Size(650, 480),
  ]) {
    testWidgets('mixed and maximum dice result density $size', (tester) async {
      final fixture = await open(tester, size, 1.3);
      final before = fixture.controller.state.toJson();
      final tag = '${size.width.toInt()}x${size.height.toInt()}-scale1.3';
      await tap(tester, find.byTooltip('Increase d4'));
      await tap(tester, find.byTooltip('Increase d4'));
      await tap(tester, find.byTooltip('Increase d20'));
      await tap(tester, key('dice-roll-button'));
      expect(key('dice-result-d4-1'), findsOneWidget);
      expect(key('dice-result-d6-0'), findsOneWidget);
      expect(key('dice-result-d20-0'), findsOneWidget);
      expect(key('dice-result-d4-2'), findsNothing);
      expectCornerClear(tester, key('dice-result-d4-0'));
      await capture(tester, '$tag-mixed-results');
      await tap(tester, find.byTooltip('Back'));
      await tap(tester, find.byTooltip('Decrease d6'));
      await tap(tester, find.byTooltip('Decrease d20'));
      for (var i = 0; i < 18; i++) {
        await tap(tester, find.byTooltip('Increase d4'));
      }
      await tap(tester, key('dice-roll-button'));
      expectCornerClear(tester, key('dice-result-d4-0'));
      await capture(tester, '$tag-20d4-results');
      for (var i = 0; i < 20; i++) {
        await tester.ensureVisible(key('dice-result-d4-$i'));
        await tester.pumpAndSettle();
        expect(key('dice-result-d4-$i').hitTestable(), findsOneWidget);
      }
      expect(key('dice-result-d4-20'), findsNothing);
      expect(fixture.controller.state.toJson(), before);
      expect(tester.takeException(), isNull);
      await tap(tester, find.byTooltip('Close workspace'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'facing dice flow preserves full shell with asymmetric safe insets',
    (tester) async {
      const size = Size(1133, 744);
      final fixture = await open(
        tester,
        size,
        1.3,
        quarterTurns: 2,
        safeInsets: true,
      );
      final before = fixture.controller.state.toJson();
      final rect = tester.getRect(key('context-workspace'));
      expect(rect.width, closeTo(size.width * .75, .01));
      expect(rect.height, closeTo(size.height * .75, .01));
      expect(rect.center.dx, closeTo(size.width / 2, .01));
      expect(rect.center.dy, closeTo(size.height / 2, .01));
      await tap(tester, find.byTooltip('Increase d4'));
      await tap(tester, find.byTooltip('Increase d4'));
      await tap(tester, find.byTooltip('Decrease d4'));
      expect(tester.widget<DieOutline>(key('dice-count-d4')).value, 1);
      await tap(tester, key('dice-roll-button'));
      expect(key('dice-result-d4-0'), findsOneWidget);
      expect(key('dice-result-d6-0'), findsOneWidget);
      expect(find.text('2 dice rolled'), findsOneWidget);
      expectCornerClear(tester, key('dice-result-d4-0'));
      await tap(tester, find.byTooltip('Back'));
      expect(tester.widget<DieOutline>(key('dice-count-d4')).value, 1);
      expect(fixture.controller.state.toJson(), before);
      await tap(tester, find.byTooltip('Close workspace'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'dice hold starts at five, repeats to clamp and cancels cleanly',
    (tester) async {
      await open(tester, const Size(1133, 744), 1);
      final plus = find.byTooltip('Increase d4');
      final gesture = await tester.startGesture(tester.getCenter(plus));
      await tester.pump(const Duration(milliseconds: 650));
      expect(tester.widget<DieOutline>(key('dice-count-d4')).value, 5);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<DieOutline>(key('dice-count-d4')).value, 20);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<DieOutline>(key('dice-count-d4')).value, 20);
      await tap(tester, find.byTooltip('Decrease d4'));
      final cancelled = await tester.startGesture(tester.getCenter(plus));
      await tester.pump(const Duration(milliseconds: 100));
      await cancelled.cancel();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<DieOutline>(key('dice-count-d4')).value, 19);
      await tap(tester, key('dice-roll-button'));
      expect(key('dice-result-d4-18'), findsOneWidget);
      expect(key('dice-result-d4-19'), findsNothing);
      expect(tester.takeException(), isNull);
      await tap(tester, find.byTooltip('Close workspace'));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'dice count clamps and every selected outcome survives focused flow',
    (tester) async {
      final fixture = await open(tester, const Size(1133, 744), 1);
      final before = fixture.controller.state.toJson();
      for (var i = 0; i < 22; i++) {
        await tap(tester, find.byTooltip('Increase d4'));
      }
      // Repeated decrements at zero must not create negative dice.
      for (var i = 0; i < 3; i++) {
        await tap(tester, find.byTooltip('Decrease d6'));
      }
      await tap(tester, key('dice-roll-button'));
      for (var i = 0; i < 20; i++) {
        final result = key('dice-result-d4-$i');
        await tester.ensureVisible(result);
        await tester.pumpAndSettle();
        expect(result.hitTestable(), findsOneWidget);
      }
      expect(key('dice-result-d4-20'), findsNothing);
      expect(key('dice-result-d6-0'), findsNothing);
      expect(fixture.controller.state.toJson(), before);
      await tap(tester, find.byTooltip('Back'));
      await tap(tester, key('dice-roll-button'));
      expect(key('dice-result-d4-19'), findsOneWidget);
      expect(key('dice-result-d4-20'), findsNothing);
      expect(tester.takeException(), isNull);
      await tap(tester, find.byTooltip('Close workspace'));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
