import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'support/table_fixture.dart';
import 'six_player_commander_layout_test.dart' show multiplayerState;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalog;
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('adaptive-interruption-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });
  Future<TableFixture> show(
    WidgetTester tester, {
    ValueNotifier<double>? scale,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1133, 1000);
    addTearDown(tester.view.reset);
    final state = multiplayerState(6);
    state.session.players.first.tokens = [
      sampleToken(id: 'held-token', name: 'Review token', amount: 10),
      sampleToken(id: 'other-token', name: 'Other token'),
    ];
    for (final player in state.session.players.skip(1)) {
      player.tokens = [
        sampleToken(
          id: 'seat-${player.slot}-token',
          name: 'Seat ${player.slot} token',
        ),
      ];
    }
    final f = TableFixture(state);
    await f.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        builder: scale == null
            ? null
            : (context, child) => ValueListenableBuilder<double>(
                valueListenable: scale,
                builder: (context, value, _) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(value)),
                  child: child!,
                ),
              ),
        home: TableScreen(controller: f.controller),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    });
    return f;
  }

  for (final interruption in ['switch', 'resize', 'lifecycle']) {
    testWidgets('token hold stops on $interruption without hidden late ticks', (
      tester,
    ) async {
      final f = await show(tester);
      if (interruption == 'resize') {
        await tester.tap(find.byKey(ValueKey('${f.playerId}-utilities-tab')));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(1800, 1000);
        await tester.pumpAndSettle();
      }
      final target = find.byKey(const ValueKey('held-token-quantity-increase'));
      expect(target.hitTestable(), findsOneWidget);
      final gesture = await tester.startGesture(
        tester.getCenter(target),
        pointer: 1,
      );
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expect(f.token('held-token').amount, greaterThan(10));
      if (interruption == 'switch') {
        await tester.tap(
          find.byKey(ValueKey('${f.playerId}-utilities-tab')),
          pointer: 2,
        );
      } else if (interruption == 'resize') {
        tester.view.physicalSize = const Size(1133, 1000);
      } else {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final stopped = f.token('held-token').amount;
      await tester.pump(const Duration(seconds: 3));
      expect(f.token('held-token').amount, stopped);
      await gesture.up();
      if (interruption == 'lifecycle') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pumpAndSettle();
      expect(f.token('held-token').amount, stopped);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'tab switch cancels active reorder proxy without reordering hidden lane',
    (tester) async {
      final f = await show(tester);
      final original = f.player.tokens.map((t) => t.id).toList();
      final drag = await tester.startGesture(
        tester.getCenter(find.text('Review token')),
        pointer: 1,
      );
      await tester.pump(const Duration(milliseconds: 650));
      await drag.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 100));
      final proxy = find.byWidgetPredicate(
        (widget) => widget is Material && widget.elevation == 5,
      );
      expect(proxy, findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('${f.playerId}-utilities-tab')),
        pointer: 2,
      );
      await tester.pumpAndSettle();
      expect(proxy, findsNothing);
      await drag.up();
      await tester.pumpAndSettle();
      expect(f.player.tokens.map((t) => t.id), original);
      expect(f.controller.session.history, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('minimum seat keeps save failure and recovery reachable', (
    tester,
  ) async {
    final f = await show(tester);
    tester.view.physicalSize = const Size(650, 480);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    f.repository.failSave = true;
    await tester.tap(find.byKey(ValueKey('${f.playerId}-life-increase')));
    await tester.pumpAndSettle();
    expect(f.player.life, 40);
    expect(tester.takeException(), isNull);
    final dismiss = find.byKey(
      ValueKey('${f.playerId}-acknowledge-life-error'),
    );
    await tester.ensureVisible(dismiss);
    await tester.pumpAndSettle();
    expect(dismiss.hitTestable(), findsOneWidget);
    f.repository.failSave = false;
    await tester.tap(dismiss);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('${f.playerId}-life-increase')));
    await tester.pumpAndSettle();
    expect(f.player.life, 41);
    expect(tester.takeException(), isNull);
  });
  for (final transition in ['text scaling', 'resize', 'resize minimum']) {
    testWidgets('$transition cancels reorder when split seat becomes tabbed', (
      tester,
    ) async {
      final scale = ValueNotifier(1.0);
      addTearDown(scale.dispose);
      final f = await show(tester, scale: scale);
      tester.view.physicalSize = const Size(1800, 1000);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('${f.playerId}-local-view-tabs')),
        findsNothing,
      );
      final original = f.player.tokens.map((t) => t.id).toList();
      final drag = await tester.startGesture(
        tester.getCenter(find.text('Review token')),
        pointer: 1,
      );
      await tester.pump(const Duration(milliseconds: 650));
      await drag.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 100));
      final proxy = find.byWidgetPredicate(
        (widget) => widget is Material && widget.elevation == 5,
      );
      expect(proxy, findsOneWidget);
      if (transition == 'text scaling') {
        scale.value = 1.3;
      } else {
        tester.view.physicalSize = transition == 'resize minimum'
            ? const Size(650, 480)
            : const Size(1133, 1000);
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('${f.playerId}-local-view-tabs')),
        findsOneWidget,
      );
      expect(proxy, findsNothing);
      await drag.up();
      await tester.pumpAndSettle();
      expect(f.player.tokens.map((t) => t.id), original);
      expect(f.controller.session.history, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wide six-player token headers clear centered shared controls', (
    tester,
  ) async {
    final f = await show(tester);
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pumpAndSettle();
    for (final slot in [4, 5]) {
      final owner = f.controller.session.players.firstWhere(
        (p) => p.slot == slot,
      );
      expect(find.byKey(ValueKey('${owner.id}-local-view-tabs')), findsNothing);
      final card = find
          .descendant(
            of: find.byKey(ValueKey('${owner.id}-token-lane')),
            matching: find.byType(TabletTokenCard),
          )
          .first;
      expect(
        tester.widget<TabletTokenCard>(card).topContentInset,
        greaterThanOrEqualTo(28),
      );
      final header = tester.getRect(find.text('Seat $slot token'));
      for (final control in [
        'table-menu-layer',
        'table-dice-layer',
        'table-day-night-layer',
      ]) {
        expect(
          header.overlaps(tester.getRect(find.byKey(ValueKey(control)))),
          isFalse,
        );
      }
    }
    expect(tester.takeException(), isNull);
  });
}
