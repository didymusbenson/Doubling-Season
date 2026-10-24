import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'support/table_fixture.dart';

void main() {
  late Directory catalog;
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('turn-layout-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });
  for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
    for (final count in [2, 4]) {
      testWidgets(
        '$count seats $size Start Turn cluster clears content and life',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
          addTearDown(tester.view.reset);
          final state = TabletState.initial();
          state.session.players = state.session.players.take(count).toList();
          if (count == 2) state.session.players[1].slot = 2;
          for (final p in state.session.players) {
            p.tokens = [
              for (var n = 0; n < 6; n++) sampleToken(id: '${p.id}-$n'),
            ];
          }
          final f = TableFixture(state);
          await f.initialize();
          await tester.pumpWidget(
            MaterialApp(home: TableScreen(controller: f.controller)),
          );
          await tester.pumpAndSettle();
          for (final original in state.session.players) {
            final id = original.id;
            final lane = find.byKey(ValueKey('$id-token-lane'));
            final start = find.byKey(ValueKey('$id-start-turn'));
            final add = find.byKey(ValueKey('$id-add-token'));
            final summary = find.byKey(ValueKey('$id-board-summary'));
            final life = find.byKey(ValueKey('$id-life-surface'));
            expect(start.hitTestable(), findsOneWidget);
            expect(tester.getSize(start), const Size(40, 44));
            final bounds = tester.getRect(start);
            expect(tester.getRect(lane).contains(bounds.topLeft), isTrue);
            expect(tester.getRect(lane).contains(bounds.bottomRight), isTrue);
            expect(bounds.overlaps(tester.getRect(add)), isFalse);
            expect(bounds.overlaps(tester.getRect(summary)), isFalse);
            expect(bounds.overlaps(tester.getRect(life)), isFalse);
            final list = tester.widget<ReorderableListView>(
              find.descendant(
                of: lane,
                matching: find.byType(ReorderableListView),
              ),
            );
            list.scrollController!.jumpTo(
              list.scrollController!.position.maxScrollExtent,
            );
            await tester.pumpAndSettle();
            final last = find.byKey(ValueKey('$id-5'));
            expect(
              tester.getRect(last).overlaps(bounds),
              isFalse,
              reason:
                  'Bottom scroll clearance must include the Start Turn cluster.',
            );
            await tester.tap(start);
            await tester.pumpAndSettle();
            expect(
              f.controller
                  .player(id)
                  .tokens
                  .every((t) => t.tapped == 0 && t.summoningSick == 0),
              isTrue,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          f.dispose();
        },
      );
    }
  }
}
