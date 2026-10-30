import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/table_modal_frame.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

class _HeldRepository extends MemoryTableRepository {
  _HeldRepository() : super(TabletState.initial());
  Completer<void>? hold;

  @override
  Future<void> save(TabletState state) async {
    await hold?.future;
    await super.save(state);
  }
}

Finder _control(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    TableController table,
    TabletCatalog catalog,
    GameDrawerController drawer, {
    double width = 300,
    double height = 700,
    WorkspacePage page = WorkspacePage.tableHub,
    VoidCallback? onClose,
  }) async {
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    catalog.loaded = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: GameDrawerWorkspace(
                controller: table,
                catalog: catalog,
                drawerController: drawer,
                initialPage: page,
                onClose: onClose ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final width in [248.0, 300.0, 440.0]) {
    testWidgets('game workflows stay in the $width px drawer', (tester) async {
      final fixture = TableFixture(stateWithTokens([sampleToken()]));
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final drawer = GameDrawerController();
      await mount(
        tester,
        fixture.controller,
        fixture.catalog,
        drawer,
        width: width,
      );
      for (final label in [
        'Dice',
        'History',
        'New game',
        'Archives',
        'Board wipes',
        'Settings',
      ]) {
        await tapText(tester, label);
        expect(
          find.byKey(const ValueKey('game-drawer-workspace')),
          findsOneWidget,
        );
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(TableModalFrame), findsNothing);
        expect(tester.takeException(), isNull, reason: label);
        if (label == 'Dice') {
          await tapText(tester, 'Roll 1 die');
          expect(find.byKey(const ValueKey('dice-results')), findsOneWidget);
          await tester.tap(_control('Back'));
          await tester.pumpAndSettle();
        }
        if (label == 'Settings') {
          await tapText(tester, 'Support');
          expect(find.text('Always free to play'), findsOneWidget);
          expect(find.byType(Dialog), findsNothing);
          expect(tester.takeException(), isNull, reason: 'embedded support');
          await tester.tap(_control('Back'));
          await tester.pumpAndSettle();
        }
        await tester.tap(_control('Back'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Table tools'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final height in [480.0, 380.0]) {
    testWidgets('starting life keyboard fits a 248 by $height channel', (
      tester,
    ) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await mount(
        tester,
        fixture.controller,
        fixture.catalog,
        GameDrawerController(),
        width: 248,
        height: height,
        page: WorkspacePage.reset,
      );
      final field = find.byWidgetPredicate(
        (widget) => widget is PlayerField && widget.label == 'Starting life',
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(_control('Select all'));
      await tester.tap(find.text('2').last);
      await tester.tap(find.text('0').last);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(tester.widget<PlayerField>(field).controller.text, '20');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('direct Dice opens a back path to tools inside the channel', (
    tester,
  ) async {
    final fixture = TableFixture();
    await fixture.initialize();
    addTearDown(fixture.dispose);
    await mount(
      tester,
      fixture.controller,
      fixture.catalog,
      GameDrawerController(),
      page: WorkspacePage.dice,
    );
    expect(_control('Back'), findsOneWidget);
    await tester.tap(_control('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Table tools'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
    'archive restoration uses channel confirmation and preserves the host',
    (tester) async {
      final fixture = TableFixture(stateWithTokens([sampleToken()]));
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await fixture.controller.adjustLife(fixture.playerId, -7);
      final archivedLife = fixture.player.life;
      final archivedSession = fixture.controller.session.id;
      await fixture.controller.resetGame(keepBoard: false);
      final currentSession = fixture.controller.session.id;
      final drawer = GameDrawerController();
      var closes = 0;
      await mount(
        tester,
        fixture.controller,
        fixture.catalog,
        drawer,
        page: WorkspacePage.archives,
        onClose: () => closes++,
      );
      await tapText(tester, fixture.controller.state.archives.single.label);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tapText(tester, 'Restore');
      expect(closes, 1);
      expect(fixture.controller.session.id, archivedSession);
      expect(fixture.controller.session.id, isNot(currentSession));
      expect(fixture.player.life, archivedLife);
      expect(fixture.player.tokens.single.name, 'Saproling');
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wipe and History undo operate in place without a new route', (
    tester,
  ) async {
    final fixture = TableFixture(stateWithTokens([sampleToken()]));
    await fixture.initialize();
    addTearDown(fixture.dispose);
    final drawer = GameDrawerController();
    await mount(tester, fixture.controller, fixture.catalog, drawer);
    await tapText(tester, 'Board wipes');
    await tester.tap(_control('Everyone, Wipe creatures'));
    await tester.pumpAndSettle();
    expect(find.text('Wipe all creatures for everyone?'), findsOneWidget);
    await tapText(tester, 'Wipe');
    expect(fixture.player.tokens, isEmpty);
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(_control('Back'));
    await tester.pumpAndSettle();
    await tapText(tester, 'History');
    final undo = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label ?? '').startsWith('Undo latest:'),
    );
    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(fixture.player.tokens.single.name, 'Saproling');
    expect(find.byType(TableModalFrame), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'edge navigation preserves dice state and failed actions remain visible',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final drawer = GameDrawerController();
      var closes = 0;
      await mount(
        tester,
        fixture.controller,
        fixture.catalog,
        drawer,
        onClose: () => closes++,
      );
      await drawer.open(WorkspacePage.dice);
      await tester.pumpAndSettle();
      await tapText(tester, 'Roll 1 die');
      await drawer.open(WorkspacePage.history);
      await tester.pumpAndSettle();
      await drawer.open(WorkspacePage.diceResults);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dice-result-d6-0')), findsOneWidget);
      await drawer.open(WorkspacePage.reset);
      await tester.pumpAndSettle();
      await tapText(tester, 'Clear board');
      fixture.repository.failSave = true;
      await tapText(tester, 'Start game');
      expect(closes, 0);
      expect(find.textContaining('Simulated storage failure'), findsWidgets);
      expect(find.text('Clear boards & restart?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'close cannot hide a pending reset and success closes without popping host',
    (tester) async {
      final repository = _HeldRepository();
      final table = TableController(repository: repository);
      await table.initialize();
      final catalog = TabletCatalog(table);
      addTearDown(catalog.dispose);
      addTearDown(table.dispose);
      final drawer = GameDrawerController();
      var closes = 0;
      final original = table.session.id;
      await mount(
        tester,
        table,
        catalog,
        drawer,
        page: WorkspacePage.reset,
        onClose: () => closes++,
      );
      await tapText(tester, 'Clear board');
      repository.hold = Completer<void>();
      await tester.tap(find.text('Start game'));
      await tester.pump();
      expect(await drawer.close(), isFalse);
      expect(closes, 0);
      expect(table.session.id, original);
      repository.hold!.complete();
      await tester.pumpAndSettle();
      expect(closes, 1);
      expect(table.session.id, isNot(original));
      expect(table.state.archives, hasLength(1));
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
