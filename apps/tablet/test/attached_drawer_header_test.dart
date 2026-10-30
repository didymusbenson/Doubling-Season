import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripling_table/ui/game_drawer_body.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

Finder identified(String id) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == id,
);
Finder verticalScroll() => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable &&
      (widget.axisDirection == AxisDirection.down ||
          widget.axisDirection == AxisDirection.up),
);

Finder named(String name) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == name,
);

void main() {
  const captureKey = ValueKey('attached-header-capture');
  final captureDir = Platform.environment['TABLET_CAPTURE_DIR'];
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (captureDir == null) return;
    await Directory(captureDir).create(recursive: true);
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
    if (captureDir == null) return;
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
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$captureDir/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  void expectAttached(WidgetTester tester, {required bool overflowing}) {
    final page = tester.getRect(identified('game-drawer-page-viewport'));
    final group = tester.getRect(identified('game-drawer-attached-group'));
    final header = tester.getRect(identified('game-drawer-header'));
    final body = tester.getRect(identified('game-drawer-body-viewport'));
    expect(header.bottom, closeTo(body.top, .001));
    expect(group.center.dy, closeTo(page.center.dy, .001));
    expect(header.left, greaterThanOrEqualTo(page.left + 32 - .001));
    expect(header.right, lessThanOrEqualTo(page.right - 32 + .001));
    expect(verticalScroll(), findsOneWidget);
    if (overflowing) {
      expect(header.top, closeTo(page.top, .001));
      expect(group.height, closeTo(page.height, .001));
    } else {
      expect(header.top, greaterThan(page.top + 8));
      final scroll = tester.state<ScrollableState>(verticalScroll());
      expect(scroll.position.maxScrollExtent, 0);
    }
    for (final name in ['Back', 'Close workspace']) {
      if (named(name).evaluate().isEmpty) continue;
      final bounds = tester.getRect(named(name));
      expect(bounds.width, greaterThanOrEqualTo(44 - .001));
      expect(bounds.height, greaterThanOrEqualTo(44 - .001));
      expect(bounds.left, greaterThanOrEqualTo(page.left + 32 - .001));
      expect(bounds.right, lessThanOrEqualTo(page.right - 32 + .001));
    }
  }

  Future<GameDrawerController> mount(
    WidgetTester tester,
    TableFixture fixture, {
    required ValueNotifier<Size> size,
    double scale = 1,
    WorkspacePage page = WorkspacePage.tableHub,
  }) async {
    tester.view.physicalSize = const Size(1133, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fixture.catalog.loaded = true;
    final drawer = GameDrawerController();
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
            body: Center(
              child: ValueListenableBuilder<Size>(
                valueListenable: size,
                builder: (context, value, _) => SizedBox(
                  width: value.width,
                  height: value.height,
                  child: GameDrawerWorkspace(
                    controller: fixture.controller,
                    catalog: fixture.catalog,
                    drawerController: drawer,
                    initialPage: page,
                    onClose: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return drawer;
  }

  testWidgets(
    'bounded lazy lists measure short groups without building a long history',
    (tester) async {
      var built = 0;
      final count = ValueNotifier(5000);
      addTearDown(count.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: GameDrawerHeaderScope(
                header: const SizedBox(height: 44, child: Text('Header')),
                child: ValueListenableBuilder<int>(
                  valueListenable: count,
                  builder: (context, value, _) => GameDrawerLayout(
                    body: ListView.builder(
                      shrinkWrap: true,
                      itemCount: value,
                      itemBuilder: (context, index) {
                        built++;
                        return SizedBox(
                          height: 44,
                          child: Text('Entry $index'),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        built,
        lessThan(40),
        reason: 'finite viewport must retain lazy sliver construction',
      );
      final scroll = tester.state<ScrollableState>(verticalScroll());
      scroll.position.jumpTo(400);
      await tester.pump();
      expect(built, lessThan(80));
      expect(
        tester.getSize(identified('game-drawer-attached-group')).height,
        400,
      );
      count.value = 3;
      await tester.pump();
      expect(
        tester.getSize(identified('game-drawer-attached-group')).height,
        44 + 3 * 44,
      );
      expect(
        tester.getCenter(identified('game-drawer-attached-group')),
        tester.getCenter(identified('game-drawer-page-viewport')),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every short workflow attaches header in its first layout', (
    tester,
  ) async {
    final fixture = TableFixture();
    await fixture.initialize();
    addTearDown(fixture.dispose);
    final size = ValueNotifier(const Size(440, 1100));
    addTearDown(size.dispose);
    final drawer = await mount(tester, fixture, size: size);
    for (final page in [
      WorkspacePage.tableHub,
      WorkspacePage.dice,
      WorkspacePage.diceResults,
      WorkspacePage.history,
      WorkspacePage.archives,
      WorkspacePage.boardWipes,
      WorkspacePage.reset,
      WorkspacePage.settings,
      WorkspacePage.support,
    ]) {
      await drawer.open(page);
      await tester.pump();
      // Store availability is asynchronous content, not layout measurement.
      if (page == WorkspacePage.support) await tester.pumpAndSettle();
      expectAttached(tester, overflowing: false);
      final first = tester.getRect(identified('game-drawer-attached-group'));
      await tester.pump();
      expect(
        tester.getRect(identified('game-drawer-attached-group')),
        first,
        reason: '${page.name} must not reposition after measuring',
      );
      await capture(tester, 'short-${page.name}');
      expect(tester.takeException(), isNull, reason: page.name);
    }
  });

  testWidgets(
    'short populated history and archive rows stay attached and centered',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await fixture.controller.adjustLife(fixture.playerId, -1);
      final size = ValueNotifier(const Size(300, 900));
      addTearDown(size.dispose);
      final drawer = await mount(
        tester,
        fixture,
        size: size,
        page: WorkspacePage.history,
      );
      expectAttached(tester, overflowing: false);
      final header = tester.getRect(identified('game-drawer-header'));
      expect(
        tester.getTopLeft(identified('game-drawer-list-row-0')).dy,
        closeTo(header.bottom + 8, .001),
      );
      await fixture.controller.resetGame(keepBoard: true);
      await tester.pumpAndSettle();
      // A new session invalidates its old workspace; remount the actual host.
      await tester.pumpWidget(const SizedBox.shrink());
      await mount(tester, fixture, size: size, page: WorkspacePage.archives);
      expectAttached(tester, overflowing: false);
      expect(identified('game-drawer-list-row-0'), findsOneWidget);
      expect(await drawer.close(), isFalse);
      await capture(tester, 'short-populated-archives');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resize pins overflow header immediately and restores centered group',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final size = ValueNotifier(const Size(300, 900));
      addTearDown(size.dispose);
      final drawer = await mount(
        tester,
        fixture,
        size: size,
        page: WorkspacePage.dice,
      );
      for (final height in [900.0, 700.0, 500.0, 360.0, 500.0, 700.0, 900.0]) {
        size.value = Size(300, height);
        await tester.pump();
        final scroll = tester.state<ScrollableState>(verticalScroll());
        final overflow = scroll.position.maxScrollExtent > .001;
        expectAttached(tester, overflowing: overflow);
        final first = tester.getRect(identified('game-drawer-header'));
        await tester.pump();
        expect(tester.getRect(identified('game-drawer-header')), first);
        if (overflow) {
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pump();
          expect(tester.getRect(identified('game-drawer-header')), first);
        }
        await capture(tester, 'resize-dice-${height.toInt()}');
        expect(tester.takeException(), isNull);
      }
      for (var repeat = 0; repeat < 3; repeat++) {
        await drawer.open(WorkspacePage.tableHub);
        await tester.pumpAndSettle();
        expectAttached(tester, overflowing: false);
        await drawer.open(WorkspacePage.dice);
        await tester.pumpAndSettle();
        expectAttached(tester, overflowing: false);
      }
    },
  );

  testWidgets(
    'large text and confirmations share attached safe header targets',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final size = ValueNotifier(const Size(248, 500));
      addTearDown(size.dispose);
      final drawer = await mount(
        tester,
        fixture,
        size: size,
        scale: 1.6,
        page: WorkspacePage.reset,
      );
      for (final page in [
        WorkspacePage.reset,
        WorkspacePage.boardWipes,
        WorkspacePage.settings,
      ]) {
        await drawer.open(page);
        await tester.pumpAndSettle();
        final scroll = tester.state<ScrollableState>(verticalScroll());
        expectAttached(
          tester,
          overflowing: scroll.position.maxScrollExtent > .001,
        );
        expect(tester.takeException(), isNull);
      }
      await drawer.open(WorkspacePage.boardWipes);
      await tester.pumpAndSettle();
      await tester.ensureVisible(named('Everyone, Wipe creatures'));
      await tester.tap(named('Everyone, Wipe creatures'));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(verticalScroll());
      expectAttached(
        tester,
        overflowing: scroll.position.maxScrollExtent > .001,
      );
      await capture(tester, 'large-text-wipe-confirmation');
      expect(tester.takeException(), isNull);
    },
  );
  for (final dimensions in [
    const Size(1133, 341),
    const Size(744, 440),
    const Size(650, 140),
  ]) {
    testWidgets(
      'wide shallow Menu and Dice use measured horizontal space at $dimensions',
      (tester) async {
        final fixture = TableFixture();
        await fixture.initialize();
        addTearDown(fixture.dispose);
        final size = ValueNotifier(dimensions);
        addTearDown(size.dispose);
        final drawer = await mount(tester, fixture, size: size);
        final tiles = [
          for (final page in [
            'dice',
            'history',
            'reset',
            'archives',
            'boardWipes',
            'settings',
          ])
            tester.getRect(find.byKey(ValueKey('drawer-menu-$page'))),
        ];
        expect(tiles[0].top, tiles[1].top);
        expect(tiles[1].top, tiles[2].top);
        expect(tiles[3].top, greaterThan(tiles[0].bottom));
        final header = tester.getRect(identified('game-drawer-header'));
        final content = tester.getRect(identified('game-drawer-body-content'));
        expect(header.left, content.left);
        expect(header.right, content.right);
        expect(content.width, greaterThan(384));
        expectAttached(tester, overflowing: dimensions.height < 300);
        await capture(
          tester,
          'wide-menu-${dimensions.width.toInt()}x${dimensions.height.toInt()}',
        );
        await drawer.open(WorkspacePage.dice);
        await tester.pumpAndSettle();
        final diceRects = [
          for (final sides in [4, 6, 8, 10, 12, 20])
            tester.getRect(find.byKey(ValueKey('dice-selection-d$sides'))),
        ];
        expect(diceRects.map((rect) => rect.top).toSet(), hasLength(1));
        for (final half in find.byType(NumericHoldRegion).evaluate()) {
          final bounds = tester.getSize(
            find.byElementPredicate((element) => element == half),
          );
          expect(bounds.width, greaterThanOrEqualTo(44));
          expect(bounds.height, greaterThanOrEqualTo(44));
        }
        expectAttached(tester, overflowing: dimensions.height < 300);
        await capture(
          tester,
          'wide-dice-${dimensions.width.toInt()}x${dimensions.height.toInt()}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
