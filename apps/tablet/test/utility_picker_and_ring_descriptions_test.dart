import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/ring_service.dart';
import 'package:tripling_table/ui/ring_inline.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

void main() {
  testWidgets(
    'Ring shows cumulative rules through and beyond four temptations',
    (tester) async {
      final utility = UtilityState(
        id: 'ring',
        kind: 'the_ring',
        name: 'The Ring',
      );
      var taps = 0;
      for (final count in [0, 1, 2, 3, 4, 5, 2, 0]) {
        utility.value = count;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 180,
                  child: RingInline(utility: utility, onTempt: () => taps++),
                ),
              ),
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('ring-next-ability-ring')),
          count == 0 ? findsOneWidget : findsNothing,
        );
        for (var i = 0; i < 4; i++) {
          expect(
            find.byKey(ValueKey('ring-active-ability-ring-$i')),
            i < count.clamp(0, 4) ? findsOneWidget : findsNothing,
          );
          if (i < count.clamp(0, 4)) {
            expect(
              find.text('${i + 1}. ${RingService.reminders[i]}'),
              findsOneWidget,
            );
          }
        }
        final tempt = find.byKey(const ValueKey('ring-tempt-ring'));
        await tester.ensureVisible(tempt);
        await tester.tap(tempt);
        expect(tester.takeException(), isNull);
      }
      expect(taps, 8);
    },
  );

  testWidgets('picker excludes only this seat’s enabled kinds and refreshes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1133, 744);
    addTearDown(tester.view.reset);
    final f = TableFixture();
    await f.initialize();
    f.catalog.loaded = true;
    final otherId = f.controller.session.players.last.id;
    await f.board.addUtility(otherId, RingService.kind);
    await f.board.addUtility(f.playerId, 'krenko_mob_boss');
    final krenko = f.player.utilities.last;
    await f.board.setUtility(f.playerId, krenko.id, name: 'Renamed utility');
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      f.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTableWorkspace(
                context,
                f.controller,
                catalog: f.catalog,
                seatId: f.playerId,
                initialPage: WorkspacePage.utilities,
              ),
              child: const Text('Open utilities'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open utilities'));
    await tester.pumpAndSettle();
    Finder add(String kind) => find.byKey(ValueKey('add-utility-$kind'));
    expect(add('storm_count'), findsNothing);
    expect(add('mana_pool'), findsNothing);
    expect(add('krenko_mob_boss'), findsNothing);
    expect(add('the_ring'), findsOneWidget);
    await tester.ensureVisible(add('the_ring'));
    await tester.tap(add('the_ring'));
    await tester.pumpAndSettle();
    expect(add('the_ring'), findsNothing);
    final ringId = f.player.utilities.last.id;
    await f.board.removeUtility(f.playerId, ringId);
    await tester.pumpAndSettle();
    expect(add('the_ring'), findsOneWidget);
    await f.controller.undo();
    await tester.pumpAndSettle();
    expect(add('the_ring'), findsNothing);
    await f.board.setUtility(f.playerId, ringId, visible: false);
    await tester.pumpAndSettle();
    expect(add('the_ring'), findsOneWidget);
    expect(
      f.controller.player(otherId).utilities.where((u) => u.kind == 'the_ring'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });
}
