import 'support/control_finders.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/commander_ledger.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cache;
  setUpAll(() async {
    cache = await Directory.systemTemp.createTemp('combined-popup-test-');
    Hive.init(cache.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await cache.delete(recursive: true);
  });

  Future<TableFixture> mount(
    WidgetTester tester, {
    int seats = 4,
    int turns = 0,
    Size size = const Size(1133, 744),
    bool partners = false,
    bool table = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    state.session.players = state.session.players.take(seats).toList();
    final f = TableFixture(state);
    await f.initialize();
    f.catalog.loaded = true;
    if (partners) {
      for (final player in f.controller.session.players.toList()) {
        await f.controller.setHasPartner(player.id, true);
      }
    }
    addTearDown(f.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        home: table
            ? TableScreen(controller: f.controller)
            : Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      for (final page in [
                        WorkspacePage.commanderDamage,
                        WorkspacePage.counters,
                        WorkspacePage.history,
                        WorkspacePage.reset,
                      ])
                        TextButton(
                          onPressed: () => showTableWorkspace(
                            context,
                            f.controller,
                            catalog: f.catalog,
                            seatId: f.playerId,
                            quarterTurns: turns,
                            initialPage: page,
                          ),
                          child: Text(page.name),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
    return f;
  }

  Future<void> open(WidgetTester tester, String route) async {
    await tester.tap(find.text(route));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(1133, 744), const Size(600, 1024)]) {
    for (final seats in [2, 3, 4]) {
      for (final turns in [0, 1, 2, 3]) {
        testWidgets(
          'combined popup preserves seats and partners $seats/$turns at $size',
          (tester) async {
            final f = await mount(
              tester,
              size: size,
              seats: seats,
              turns: turns,
              partners: true,
            );
            await open(tester, 'commanderDamage');
            expect(find.text('Add counter'), findsOneWidget);
            expect(find.text('Monarch'), findsOneWidget);
            expect(byControlLabel('Undo latest action'), findsNothing);
            expect(find.text('Set damage total'), findsNothing);
            expect(find.text('Correct life'), findsNothing);
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                      'commander-edit-',
                    ),
              ),
              findsNothing,
            );
            final surface = tester.getRect(
              find.byKey(const ValueKey('commander-workspace')),
            );
            expect(surface.left, greaterThanOrEqualTo(15.99));
            expect(surface.top, greaterThanOrEqualTo(15.99));
            expect(surface.right, lessThanOrEqualTo(size.width - 15.99));
            expect(surface.bottom, lessThanOrEqualTo(size.height - 15.99));
            final grid = tester.renderObject<RenderBox>(
              find.byKey(const ValueKey('focused-commander-grid')),
            );
            final rows = CommanderSeatLayout.rowsFor(
              f.controller.session.players,
              turns,
            );
            for (var r = 0; r < rows.length; r++) {
              for (var col = 0; col < rows[r].length; col++) {
                final owner = rows[r][col];
                if (owner == null) continue;
                final position = grid.globalToLocal(
                  tester.getCenter(
                    find.byKey(ValueKey('commander-owner-${owner.id}')),
                  ),
                );
                if (col > 0 && rows[r][col - 1] != null) {
                  final previous = grid.globalToLocal(
                    tester.getCenter(
                      find.byKey(
                        ValueKey('commander-owner-${rows[r][col - 1]!.id}'),
                      ),
                    ),
                  );
                  expect(position.dx, greaterThan(previous.dx));
                }
                for (final source
                    in f.controller.session.commanderTrackingSources.where(
                      (s) => s.ownerPlayerId == owner.id,
                    )) {
                  final plus = find.byKey(
                    ValueKey('commander-increase-${source.id}'),
                  );
                  await tester.ensureVisible(plus);
                  await tester.pumpAndSettle();
                  final target = tester.getSize(plus);
                  expect(target.width, greaterThanOrEqualTo(44));
                  expect(target.height, greaterThanOrEqualTo(44));
                  expect(plus.hitTestable(), findsOneWidget);
                  final before = f.player.life;
                  await tester.tap(plus);
                  await tester.pumpAndSettle();
                  expect(f.player.commanderDamage[source.id], 1);
                  expect(f.player.life, before - 1);
                }
              }
            }
            expect(tester.takeException(), isNull);
            await close(tester);
          },
        );
      }
    }
  }

  testWidgets(
    'counter choices grow compact popup; Undo exists only in History',
    (tester) async {
      final f = await mount(tester);
      await open(tester, 'counters');
      expect(
        find.byKey(const ValueKey('focused-commander-grid')),
        findsOneWidget,
      );
      final initialHeight = tester
          .getSize(find.byKey(const ValueKey('commander-workspace')))
          .height;
      expect(initialHeight, lessThan(500));
      expect(find.text('Change life by'), findsNothing);
      expect(find.text('Set life total to'), findsNothing);
      expect(find.text('Reset life to 40'), findsNothing);
      await tester.tap(find.text('Add counter'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enable energy'));
      await tester.tap(find.text('Enable energy'));
      await tester.pumpAndSettle();
      expect(f.player.counters['energy'], 0);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('commander-workspace')))
            .height,
        greaterThan(initialHeight),
      );
      final increase = find.bySemanticsLabel(RegExp('Increase energy'));
      final semantics = tester.ensureSemantics();
      await tester.pump();
      await tester.ensureVisible(increase);
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(f.player.counters['energy'], 1);
      await close(tester);
      await open(tester, 'history');
      final undo = byActionNamePrefix('Undo latest:');
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(f.player.counters['energy'], 0);
      expect(find.text('Latest action undone.'), findsNothing);
      await close(tester);
      await open(tester, 'reset');
      expect(find.widgetWithText(TextField, 'Starting life'), findsOneWidget);
      await close(tester);
      semantics.dispose();
    },
  );

  testWidgets(
    'empty life chip has no counter target; active badges sit beside ledger',
    (tester) async {
      final f = await mount(tester, table: true);
      final summary = find.byKey(
        ValueKey('${f.playerId}-life-counter-summary'),
      );
      final ledger = find.byKey(ValueKey('${f.playerId}-commander-ledger'));
      expect(summary, findsNothing);
      expect(ledger.hitTestable(), findsOneWidget);
      await tester.tap(ledger);
      await tester.pumpAndSettle();
      expect(find.text('Add counter'), findsOneWidget);
      await close(tester);
      await f.controller.setPlayerCounter(f.playerId, 'energy', 2);
      await tester.pumpAndSettle();
      expect(summary.hitTestable(), findsOneWidget);
      final a = tester.getRect(ledger), b = tester.getRect(summary);
      expect((b.left - a.right).abs(), lessThanOrEqualTo(5));
      expect(b.height, closeTo(44, .001));
      expect(b.width, closeTo(44, .001));
      await f.controller.setPlayerCounter(f.playerId, 'energy', 0);
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
