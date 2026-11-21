import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

void main() {
  test(
    'manual taxes track existing identities independently and reset for a new game',
    () async {
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      final owner = f.playerId;
      final other = f.controller.session.players.last.id;
      final beforeOther = cloneJson(f.controller.player(other).toJson());
      final primaryId = 'default-commander:$owner';
      int tax(String id) => f.controller.session.commanderTrackingSources
          .singleWhere((source) => source.id == id)
          .tax;
      expect(tax(primaryId), 0);
      expect(
        await f.controller.adjustCommanderTax(
          owner,
          primaryId,
          increase: false,
        ),
        isTrue,
      );
      expect(f.controller.session.commanders, isEmpty);
      expect(
        await f.controller.adjustCommanderTax(owner, primaryId, increase: true),
        isTrue,
      );
      expect(tax(primaryId), 2);
      expect(await f.controller.setHasPartner(owner, true), isTrue);
      final partnerId = f.controller.session.commanders.last.id;
      expect(tax(partnerId), 0);
      expect(
        await f.controller.adjustCommanderTax(other, partnerId, increase: true),
        isFalse,
      );
      expect(tax(partnerId), 0);
      for (var i = 0; i < 2; i++) {
        expect(
          await f.controller.adjustCommanderTax(
            owner,
            partnerId,
            increase: true,
          ),
          isTrue,
        );
      }
      expect(tax(partnerId), 4);
      expect(tax(primaryId), 2);
      expect(await f.controller.undo(), isTrue);
      expect(tax(partnerId), 2);
      expect(tax(primaryId), 2);
      expect(await f.controller.setHasPartner(owner, false), isTrue);
      expect(
        f.controller.session.commanderTrackingSources.any(
          (s) => s.id == partnerId,
        ),
        isFalse,
      );
      expect(
        await f.controller.adjustCommanderTax(
          owner,
          partnerId,
          increase: false,
        ),
        isFalse,
      );
      expect(await f.controller.setHasPartner(owner, true), isTrue);
      expect(tax(partnerId), 2);
      final restored = TabletState.fromJson(
        jsonMap(jsonDecode(f.repository.encoded)),
      );
      expect(restored.session.commanders.map((s) => s.tax), [2, 2]);
      expect(f.controller.player(other).toJson(), beforeOther);
      expect(f.player.life, 40);
      expect(f.player.commanderDamage, isEmpty);
      expect(
        await f.controller.adjustCommanderTax(
          owner,
          partnerId,
          increase: false,
        ),
        isTrue,
      );
      expect(tax(partnerId), 0);
      expect(await f.controller.resetGame(keepBoard: true), isTrue);
      expect(
        f.controller.session.commanders.map((s) => s.tax),
        everyElement(0),
      );
      expect(f.controller.session.hasPartner(f.playerId), isTrue);
      final oldSource = CommanderSource.fromJson({
        'id': 'legacy',
        'ownerPlayerId': owner,
        'name': 'Legacy commander',
      });
      expect(oldSource.tax, 0);
      expect(oldSource.toJson().containsKey('tax'), isFalse);
    },
  );

  for (final (size, turns, scale) in [
    (const Size(744, 1133), 0, 1.0),
    (const Size(1133, 744), 2, 1.0),
    (const Size(320, 640), 2, 1.5),
  ]) {
    testWidgets(
      'one ordered scales chip and independent tax controls at $size, $turns turns',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final f = TableFixture();
        await f.initialize();
        f.catalog.loaded = true;
        addTearDown(f.dispose);
        final owner = f.playerId;
        await f.controller.setHasPartner(owner, true);
        await tester.pumpWidget(
          MaterialApp(
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
                    f.controller,
                    catalog: f.catalog,
                    seatId: owner,
                    initialPage: WorkspacePage.counters,
                    quarterTurns: turns,
                  ),
                  child: const Text('Open player counters'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open player counters'));
        await tester.pumpAndSettle();
        final tax = byControlLabel('Commander tax');
        await tester.ensureVisible(tax);
        await tester.pumpAndSettle();
        final chips = [
          byControlLabel('Monarch, Off'),
          byControlLabel('City’s blessing, Off'),
          byControlLabel('Initiative, Off'),
          tax,
        ];
        expect(
          find.descendant(of: tax, matching: find.byIcon(Icons.balance)),
          findsOneWidget,
        );
        final centers = chips.map(tester.getCenter).toList();
        for (var i = 1; i < centers.length; i++) {
          expect(centers[i].dy, closeTo(centers.first.dy, .01));
          expect(
            turns == 0
                ? centers[i].dx > centers[i - 1].dx
                : centers[i].dx < centers[i - 1].dx,
            isTrue,
          );
        }
        await tester.tap(tax);
        await tester.pumpAndSettle();
        final taxRows = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(HalfStepper),
        );
        expect(taxRows, findsNWidgets(2));
        expect(tester.widgetList<HalfStepper>(taxRows).map((s) => s.value), [
          '+0',
          '+0',
        ]);
        await tester.tap(byControlLabel('Increase Partner #2 tax by 2'));
        await tester.pumpAndSettle();
        expect(tester.widgetList<HalfStepper>(taxRows).map((s) => s.value), [
          '+0',
          '+2',
        ]);
        await tester.tap(byControlLabel('Decrease Partner #2 tax by 2'));
        await tester.pumpAndSettle();
        expect(tester.widgetList<HalfStepper>(taxRows).map((s) => s.value), [
          '+0',
          '+0',
        ]);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await tester.tap(byControlLabel('Close workspace'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
