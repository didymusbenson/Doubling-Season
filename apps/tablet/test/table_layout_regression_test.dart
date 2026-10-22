import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory isolatedCatalog;
  setUpAll(() async {
    isolatedCatalog = await Directory.systemTemp.createTemp(
      'tablet-layout-catalog-',
    );
    Hive.init(isolatedCatalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await isolatedCatalog.delete(recursive: true);
  });

  TabletState tableFor(int seats) {
    final state = TabletState.initial();
    if (seats == 2) {
      state.session.players = state.session.players.take(2).toList();
    }
    if (seats == 3) state.session.players.removeAt(0);
    return state;
  }

  Future<TableFixture> showTable(
    WidgetTester tester,
    Size size,
    TabletState state,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    // Include iPad safe-area space: fitting only edge-to-edge web content
    // would miss the original mini-landscape clipping regression.
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    final fixture = TableFixture(state);
    await fixture.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        home: TableScreen(controller: fixture.controller),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      fixture.dispose();
    });
    return fixture;
  }

  for (final size in [
    const Size(1133, 744),
    const Size(744, 1133),
    const Size(1366, 1024),
  ]) {
    for (final seats in [2, 3, 4]) {
      testWidgets(
        '$seats seats at $size expose every default mana control without scrolling',
        (tester) async {
          final fixture = await showTable(tester, size, tableFor(seats));
          expect(tester.takeException(), isNull);
          expect(find.byTooltip('Storm').hitTestable(), findsNWidgets(seats));
          expect(find.text('Mana pool').hitTestable(), findsNWidgets(seats));
          for (final player in fixture.controller.session.players) {
            final name = fixture.controller.profile(player.seatId).name;
            expect(
              find.text(name),
              findsOneWidget,
              reason: 'Seat identity belongs in the life counter.',
            );
            for (final type in PlayerState.manaColors) {
              for (final action in ['add', 'spend']) {
                final target = find.byKey(
                  ValueKey('${player.id}-mana-$type-$action'),
                );
                expect(
                  target.hitTestable(),
                  findsOneWidget,
                  reason:
                      '$name $type $action must be visible without moving the lane.',
                );
                final bounds = tester.getRect(target);
                expect(bounds.top, greaterThanOrEqualTo(24));
                expect(bounds.bottom, lessThanOrEqualTo(size.height - 20));
              }
            }
          }
        },
      );
    }
  }

  testWidgets(
    'mini landscape mana spending stays on board and preserves other seats',
    (tester) async {
      final fixture = await showTable(
        tester,
        const Size(1133, 744),
        tableFor(4),
      );
      final player = fixture.controller.session.players.first;
      final add = find.byKey(ValueKey('${player.id}-mana-W-add'));
      final spend = find.byKey(ValueKey('${player.id}-mana-W-spend'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 1);
      await tester.longPress(add);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 11);
      await tester.tap(spend);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 10);
      await tester.longPress(spend);
      await tester.pumpAndSettle();
      expect(fixture.controller.player(player.id).mana['W'], 0);
      for (final other in fixture.controller.session.players.skip(1)) {
        expect(other.mana['W'] ?? 0, 0);
      }
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byTooltip('Storm').hitTestable(), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'portrait Storm uses a named icon and exposes its full title when expanded',
    (tester) async {
      await showTable(tester, const Size(744, 1133), tableFor(4));
      final storm = find.byTooltip('Storm');
      expect(storm.hitTestable(), findsNWidgets(4));
      expect(
        find.descendant(of: storm, matching: find.byIcon(Icons.bolt_outlined)),
        findsNWidgets(4),
      );
      expect(find.text('Storm'), findsNothing);
      await tester.tap(storm.last);
      await tester.pumpAndSettle();
      expect(find.text('Storm').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow portrait lane bounds large utility and mana values', (
    tester,
  ) async {
    final state = tableFor(4);
    for (final player in state.session.players) {
      player.utilities.first.value = 999999;
      player.counters['poison'] = 999999;
      for (final type in PlayerState.manaColors) {
        player.mana[type] = 999999;
      }
    }
    await showTable(tester, const Size(744, 1133), state);
    expect(find.byTooltip('Storm').hitTestable(), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
