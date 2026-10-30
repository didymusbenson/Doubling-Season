import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

Finder identified(String id) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == id,
);
Finder named(String name) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == name,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameDrawerController> mount(
    WidgetTester tester,
    TableFixture fixture, {
    double width = 440,
    double height = 700,
    double textScale = 1,
    WorkspacePage page = WorkspacePage.tableHub,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fixture.catalog.loaded = true;
    final drawer = GameDrawerController();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
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
    );
    await tester.pumpAndSettle();
    return drawer;
  }

  void expectSafe(WidgetTester tester, Finder finder) {
    final channel = tester.getRect(
      find.byKey(const ValueKey('game-drawer-workspace')),
    );
    for (final element in finder.evaluate()) {
      final bounds = tester.getRect(
        find.byElementPredicate((candidate) => candidate == element),
      );
      expect(bounds.left, greaterThanOrEqualTo(channel.left + 32 - .001));
      expect(bounds.right, lessThanOrEqualTo(channel.right - 32 + .001));
    }
  }

  for (final width in [248.0, 300.0, 440.0]) {
    testWidgets(
      'menu balances natural content and clears curved walls at $width',
      (tester) async {
        final fixture = TableFixture();
        await fixture.initialize();
        addTearDown(fixture.dispose);
        await mount(tester, fixture, width: width);
        final viewport = tester.getRect(
          identified('game-drawer-body-viewport'),
        );
        final content = tester.getRect(identified('game-drawer-body-content'));
        expect(content.center.dx, closeTo(viewport.center.dx, .001));
        expect(
          tester.getCenter(identified('game-drawer-attached-group')).dy,
          closeTo(
            tester.getCenter(identified('game-drawer-page-viewport')).dy,
            .001,
          ),
        );
        expect(
          tester.getCenter(find.byKey(const ValueKey('game-drawer-title'))).dx,
          closeTo(viewport.center.dx, .001),
        );
        final tiles = find.byWidgetPredicate(
          (widget) =>
              widget is OutlinedButton &&
              widget.key.toString().contains('drawer-menu-'),
        );
        expect(tiles, findsNWidgets(6));
        expectSafe(tester, tiles);
        final dice = tester.getRect(
          find.byKey(const ValueKey('drawer-menu-dice')),
        );
        final history = tester.getRect(
          find.byKey(const ValueKey('drawer-menu-history')),
        );
        if (width >= 320) {
          expect(dice.top, history.top);
          expect(dice.right, lessThan(history.left));
        } else {
          expect(dice.left, history.left);
          expect(dice.bottom, lessThan(history.top));
        }
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        expect(scroll.position.maxScrollExtent, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('dice halves stay44px and short results balance at $width', (
      tester,
    ) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await mount(tester, fixture, width: width, page: WorkspacePage.dice);
      final halves = find.byType(NumericHoldRegion);
      expect(halves, findsNWidgets(12));
      for (final element in halves.evaluate()) {
        final rect = tester.getRect(
          find.byElementPredicate((candidate) => candidate == element),
        );
        expect(rect.width, greaterThanOrEqualTo(44 - .001));
        expect(rect.height, greaterThanOrEqualTo(44));
      }
      expectSafe(tester, halves);
      await tester.tap(find.text('Roll 1 die'));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(identified('game-drawer-body-viewport'));
      final content = tester.getRect(identified('game-drawer-body-content'));
      expect(content.center.dx, viewport.center.dx);
      expect(
        tester.getCenter(identified('game-drawer-attached-group')),
        tester.getCenter(identified('game-drawer-page-viewport')),
      );
      expectSafe(tester, find.byKey(const ValueKey('dice-reroll-button')));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'large text and long names scroll without crossing drawer gutters',
    (tester) async {
      final state = TabletState.initial();
      state.profiles.first.name =
          'A very long player name that wraps over several lines';
      final fixture = TableFixture(state);
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final drawer = await mount(
        tester,
        fixture,
        width: 248,
        height: 500,
        textScale: 1.6,
      );
      for (final page in [
        WorkspacePage.tableHub,
        WorkspacePage.reset,
        WorkspacePage.boardWipes,
        WorkspacePage.settings,
        WorkspacePage.support,
      ]) {
        await drawer.open(page);
        await tester.pumpAndSettle();
        expectSafe(tester, identified('game-drawer-body-content'));
        expect(tester.takeException(), isNull, reason: page.name);
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        if (scroll.position.maxScrollExtent > 0) {
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expectSafe(tester, identified('game-drawer-body-content'));
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.name} scrolled',
          );
        }
      }
    },
  );

  testWidgets(
    'empty seat choices map physical corners and preserve reset semantics',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final semantics = tester.ensureSemantics();

      await mount(tester, fixture, width: 300, page: WorkspacePage.reset);
      await tester.tap(named('3 players'));
      await tester.pumpAndSettle();
      final tl = tester.getCenter(named('Top left'));
      final tr = tester.getCenter(named('Top right'));
      final bl = tester.getCenter(named('Bottom left'));
      final br = tester.getCenter(named('Bottom right'));
      expect(tl.dx, bl.dx);
      expect(tr.dx, br.dx);
      expect(tl.dy, tr.dy);
      expect(bl.dy, br.dy);
      expect(tl.dx, lessThan(tr.dx));
      expect(tl.dy, lessThan(bl.dy));
      await tester.tap(named('Top right'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(named('Top right')).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      final reset = named('Complete reset');
      await tester.ensureVisible(reset);
      expect(
        tester
            .getSemantics(reset)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(reset);
      await tester.pumpAndSettle();
      final start = named('Archive & complete reset');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(fixture.controller.session.players, hasLength(3));
      expect(
        fixture.controller.session.players.map((player) => player.slot),
        isNot(contains(2)),
      );
      expect(fixture.controller.state.archives, hasLength(1));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('populated history and archives stay top-aligned and lazy', (
    tester,
  ) async {
    final state = TabletState.initial();
    final now = DateTime.utc(2026, 10, 30);
    for (var index = 0; index < 100; index++) {
      state.session.history.add(
        HistoryEntry(
          id: 'history-$index',
          label: 'Action $index',
          createdAt: now,
          updatedAt: now,
          affectedPlayerIds: [],
          commands: [],
          undone: true,
        ),
      );
      state.archives.add(
        GameArchive(
          id: 'archive-$index',
          label: 'Archive $index',
          savedAt: now,
          session: state.session.copy(),
        ),
      );
    }
    final fixture = TableFixture(state);
    await fixture.initialize();
    addTearDown(fixture.dispose);
    final drawer = await mount(
      tester,
      fixture,
      width: 300,
      height: 500,
      page: WorkspacePage.history,
    );
    for (final page in [WorkspacePage.history, WorkspacePage.archives]) {
      await drawer.open(page);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(identified('game-drawer-body-viewport'));
      final row = tester.getRect(identified('game-drawer-list-row-0'));
      expect(row.top, closeTo(viewport.top + 8, .001));
      expect(identified('game-drawer-list-row-99'), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
      expectSafe(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.identifier ?? '').startsWith(
                'game-drawer-list-row-',
              ),
        ),
      );
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      scroll.position.jumpTo(600);
      await tester.pumpAndSettle();
      expectSafe(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.identifier ?? '').startsWith(
                'game-drawer-list-row-',
              ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('empty views center their content without reserving list space', (
    tester,
  ) async {
    final fixture = TableFixture();
    await fixture.initialize();
    addTearDown(fixture.dispose);
    final drawer = await mount(tester, fixture, width: 300);
    for (final page in [
      WorkspacePage.history,
      WorkspacePage.archives,
      WorkspacePage.support,
    ]) {
      await drawer.open(page);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(identified('game-drawer-attached-group')),
        tester.getCenter(identified('game-drawer-page-viewport')),
      );
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'dense mixed dice scroll inside safe walls and remain rerollable',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await mount(
        tester,
        fixture,
        width: 248,
        height: 500,
        page: WorkspacePage.dice,
      );
      for (final sides in [4, 6, 8, 10, 12, 20]) {
        final plus = find.byWidgetPredicate(
          (widget) =>
              widget is NumericHoldRegion && widget.label == 'Increase d$sides',
        );
        await tester.ensureVisible(plus);
        for (var count = 0; count < 3; count++) {
          await tester.tap(plus);
          await tester.pump();
        }
      }
      final roll = find.byKey(const ValueKey('dice-roll-button'));
      await tester.ensureVisible(roll);
      await tester.tap(roll);
      await tester.pumpAndSettle();
      expect(find.text('19 dice rolled'), findsOneWidget);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(500));
      expectSafe(tester, identified('game-drawer-body-content'));
      final reroll = find.byKey(const ValueKey('dice-reroll-button'));
      await tester.ensureVisible(reroll);
      await tester.tap(reroll);
      await tester.pumpAndSettle();
      expect(find.text('19 dice rolled'), findsOneWidget);
      expectSafe(tester, reroll);
      expect(tester.takeException(), isNull);
    },
  );
}
