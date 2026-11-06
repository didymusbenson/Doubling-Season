import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/token_modifier_button.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  late Directory catalog;
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('token-modifiers-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });

  Future<TableFixture> mount(WidgetTester tester, int count, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = TableFixture();
    await fixture.initialize();
    await fixture.controller.resetGame(keepBoard: false, playerCount: count);
    for (final player in fixture.controller.session.players) {
      player.tokens = [
        for (var n = 0; n < 8; n++)
          sampleToken(id: '${player.id}-token-$n', name: 'Saproling ${n + 1}'),
      ];
    }
    await tester.pumpWidget(
      MaterialApp(home: TableScreen(controller: fixture.controller)),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      fixture.dispose();
    });
    return fixture;
  }

  Rect localBounds(WidgetTester tester, Finder child, Finder parent) {
    final box = tester.renderObject<RenderBox>(child);
    final ancestor = tester.renderObject<RenderBox>(parent);
    return Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: ancestor),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: ancestor),
    );
  }

  for (final count in [2, 3, 4, 5, 6]) {
    for (final size in [
      const Size(650, 480),
      const Size(1133, 744),
      const Size(1700, 1100),
    ]) {
      testWidgets('$count players $size keep modifiers in token lane', (
        tester,
      ) async {
        final fixture = await mount(tester, count, size);
        for (final player in fixture.controller.session.players) {
          final lane = find.byKey(ValueKey('${player.id}-token-lane'));
          final modifiers = find.byKey(
            ValueKey('${player.id}-token-modifiers'),
          );
          expect(modifiers.hitTestable(), findsOneWidget);
          expect(
            find.descendant(of: lane, matching: modifiers),
            findsOneWidget,
          );
          final bounds = localBounds(tester, modifiers, lane);
          expect(bounds.left, 12);
          expect(bounds.width, greaterThanOrEqualTo(44));
          expect(bounds.height, 44);
          expect(bounds.bottom, closeTo(tester.getSize(lane).height - 12, .01));
          final controls = [
            modifiers,
            for (final suffix in ['board-summary', 'start-turn', 'add-token'])
              find.byKey(ValueKey('${player.id}-$suffix')),
          ];
          for (var index = 0; index < controls.length; index++) {
            final control = controls[index];
            expect(control.hitTestable(), findsOneWidget);
            final rect = localBounds(tester, control, lane);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(tester.getSize(lane).width));
            for (final other in controls.skip(index + 1)) {
              expect(rect.overlaps(localBounds(tester, other, lane)), isFalse);
            }
          }
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
          final last = find.byKey(ValueKey('${player.id}-token-7'));
          if (tester.getSize(lane).height > 88) {
            expect(localBounds(tester, last, lane).overlaps(bounds), isFalse);
          } else {
            // Minimum-height local views can scroll entirely into the trailing
            // control clearance; verify its extent without requiring an
            // offscreen virtualized card to remain mounted.
            expect(
              list.padding,
              list.reverse
                  ? const EdgeInsets.only(top: 88)
                  : const EdgeInsets.only(bottom: 88),
            );
          }

          final tabs = find.byKey(ValueKey('${player.id}-local-view-tabs'));
          if (tabs.evaluate().isNotEmpty) {
            await tester.tap(
              find.byKey(ValueKey('${player.id}-utilities-tab')),
            );
            await tester.pumpAndSettle();
            expect(modifiers.hitTestable(), findsNothing);
            await tester.tap(find.byKey(ValueKey('${player.id}-tokens-tab')));
            await tester.pumpAndSettle();
            expect(modifiers.hitTestable(), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'calculator previews owned and global rules without changing token state',
    (tester) async {
      final fixture = await mount(tester, 4, const Size(1133, 744));
      final players = fixture.controller.session.players;
      final owner = players.first.id;
      final other = players.last.id;
      Finder button(String id) => find.byKey(ValueKey('$id-token-modifiers'));
      Finder text(String id, String label) =>
          find.descendant(of: button(id), matching: find.text(label));
      expect(text(owner, 'Rules'), findsNothing);
      await fixture.board.setModifier(owner, 'token_doubler', 1);
      await tester.pumpAndSettle();
      expect(text(owner, '×2'), findsOneWidget);
      expect(text(other, 'Rules'), findsNothing);
      await fixture.board.setModifier(other, 'primal_vigor', 1);
      await tester.pumpAndSettle();
      expect(text(owner, '×4'), findsOneWidget);
      expect(text(other, '×2'), findsOneWidget);
      expect(
        find.descendant(
          of: button(owner),
          matching: find.byKey(const ValueKey('active-token-modifiers')),
        ),
        findsOneWidget,
      );
      await fixture.board.setModifier(owner, 'chatterfang', 1);
      await tester.pumpAndSettle();
      expect(text(owner, 'Rules'), findsNothing);
      expect(fixture.controller.player(owner).tokens.first.amount, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opposite player opens their own modifiers with correct orientation and no tap-through',
    (tester) async {
      final fixture = await mount(tester, 4, const Size(1133, 744));
      final player = fixture.controller.session.players.firstWhere(
        (p) => fixture.controller.session.quarterTurnsFor(p) == 2,
      );
      final id = player.id;
      final name = fixture.controller.profile(player.seatId).name;
      final button = find.byKey(ValueKey('$id-token-modifiers'));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Your modifier sources'), findsOneWidget);
      final headingBox = tester.renderObject<RenderBox>(
        find.text('Your modifier sources'),
      );
      expect(
        (headingBox.localToGlobal(const Offset(10, 0)) -
                headingBox.localToGlobal(Offset.zero))
            .dx,
        lessThan(0),
      );
      expect(button.hitTestable(), findsNothing);
      expect(
        byControlLabel('$name, token modifiers').hitTestable(),
        findsNothing,
      );
      await tester.tap(byControlLabel('Increase Token doubler'));
      await tester.pumpAndSettle();
      expect(fixture.controller.player(id).rules.single.count, 1);
      expect(
        fixture.controller.session.players
            .where((p) => p.id != id)
            .every((p) => p.rules.isEmpty),
        isTrue,
      );
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: button, matching: find.text('×2')),
        findsOneWidget,
      );
      final history = fixture.controller.session.history.length;
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Your modifier sources'), findsNothing);
      expect(fixture.controller.session.history.length, history);
      expect(find.byType(TokenModifierButton), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );
}
