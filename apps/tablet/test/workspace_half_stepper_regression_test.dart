import 'package:doubling_season/models/token_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    TableFixture fixture,
    WorkspacePage page,
    int turns, {
    String? itemId,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1133, 744);
    addTearDown(tester.view.reset);
    fixture.catalog.loaded = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTableWorkspace(
                context,
                fixture.controller,
                catalog: fixture.catalog,
                seatId: fixture.playerId,
                initialPage: page,
                itemId: itemId,
                quarterTurns: turns,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    addTearDown(() async {
      if (find.byTooltip('Close workspace').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      fixture.dispose();
    });
  }

  Future<void> tapLocal(
    WidgetTester tester,
    Finder target,
    double x,
    double y,
  ) async {
    final box = tester.renderObject<RenderBox>(target);
    await tester.tapAt(
      box.localToGlobal(Offset(box.size.width * x, box.size.height * y)),
    );
    await tester.pumpAndSettle();
  }

  for (final turns in [0, 2]) {
    testWidgets(
      'workspace mana uses full halves and repeat holds that stop on release at turns=$turns',
      (tester) async {
        final fixture = TableFixture();
        await fixture.initialize();
        final otherBefore = fixture.controller.session.players[1].toJson();
        final mana = fixture.player.utilities.firstWhere(
          (u) => u.kind == 'mana_pool',
        );
        await open(
          tester,
          fixture,
          WorkspacePage.utilities,
          turns,
          itemId: mana.id,
        );
        final add = find.byTooltip('Increase White mana');
        final spend = find.byTooltip('Decrease White mana');
        expect(tester.getSize(add).height, 48);
        expect(tester.getSize(add).width, greaterThanOrEqualTo(48));
        for (final point in [
          const Offset(.02, .05),
          const Offset(.98, .05),
          const Offset(.02, .95),
          const Offset(.98, .95),
        ]) {
          await tapLocal(tester, add, point.dx, point.dy);
        }
        expect(fixture.player.mana['W'], 4);
        for (final point in [
          const Offset(.02, .05),
          const Offset(.98, .05),
          const Offset(.02, .95),
          const Offset(.98, .95),
        ]) {
          await tapLocal(tester, spend, point.dx, point.dy);
        }
        expect(fixture.player.mana['W'], 0);
        final historyBefore = fixture.controller.session.history
            .map((e) => e.toJson())
            .toList();
        await tapLocal(tester, spend, .98, .5);
        expect(fixture.player.mana['W'], 0);
        expect(
          fixture.controller.session.history.map((e) => e.toJson()).toList(),
          historyBefore,
        );
        final box = tester.renderObject<RenderBox>(add);
        final gesture = await tester.startGesture(
          box.localToGlobal(Offset(box.size.width - 1, box.size.height - 1)),
        );
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pump();
        final heldTotal = fixture.player.mana['W']!;
        expect(
          heldTotal,
          greaterThan(10),
          reason:
              'Holding repeats, rather than stopping after the first configured increment.',
        );
        expect(
          fixture.controller.session.history.last.commands.length,
          greaterThan(1),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          fixture.player.mana['W'],
          heldTotal,
          reason: 'Release has no trailing tap.',
        );
        await tester.pump(const Duration(seconds: 3));
        expect(
          fixture.player.mana['W'],
          heldTotal,
          reason: 'All repeat timers stop on release.',
        );
        expect(await fixture.controller.undo(), isTrue);
        await tester.pumpAndSettle();
        expect(fixture.player.mana['W'], 0);
        expect(fixture.controller.session.players[1].toJson(), otherBefore);
        expect(find.byTooltip('Select all'), findsNothing);
        expect(
          find.byTooltip('Lock White mana for Empty').hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byTooltip('Convert all mana to White').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close workspace'), findsNothing);
      },
    );

    testWidgets(
      'creation quantity full halves preserve choice chips, exact entry and seat scope at turns=$turns',
      (tester) async {
        final fixture = TableFixture();
        await fixture.initialize();
        await fixture.catalog.saveCustom(
          TokenDefinition(
            name: 'Half-stepper Saproling',
            abilities: '',
            pt: '1/1',
            colors: 'G',
            type: 'Creature',
            popularity: 0,
          ),
        );
        final otherBefore = fixture.controller.session.players[1].toJson();
        await open(tester, fixture, WorkspacePage.tokens, turns);
        await tester.tap(find.text('Half-stepper Saproling · 1/1'));
        await tester.pumpAndSettle();
        final add = find.byTooltip('Increase creation quantity');
        final spend = find.byTooltip('Decrease creation quantity');
        PlayerField amountField() => tester.widget<PlayerField>(
          find.byWidgetPredicate(
            (w) => w is PlayerField && w.label == 'Quantity before modifiers',
          ),
        );
        for (final point in [
          const Offset(.02, .05),
          const Offset(.98, .05),
          const Offset(.02, .95),
          const Offset(.98, .95),
        ]) {
          await tapLocal(tester, add, point.dx, point.dy);
        }
        expect(amountField().controller.text, '5');
        for (var i = 0; i < 5; i++) {
          await tapLocal(tester, spend, .98, .95);
        }
        expect(amountField().controller.text, '1');
        expect(
          find.byTooltip('Select all'),
          findsNothing,
          reason: 'Stepping beside the value must not open the exact editor.',
        );
        await tester.tap(find.widgetWithText(ChoiceChip, '3'));
        await tester.pumpAndSettle();
        expect(amountField().controller.text, '3');
        await tester.tap(find.text('Create tokens'));
        await tester.pumpAndSettle();
        expect(fixture.player.tokens.single.name, 'Half-stepper Saproling');
        expect(fixture.player.tokens.single.amount, 3);
        expect(fixture.controller.session.players[1].toJson(), otherBefore);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
