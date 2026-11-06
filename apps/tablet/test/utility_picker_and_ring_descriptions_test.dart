import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
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
        expect(find.textContaining(RegExp(r'^\d+ temptations?$')), findsNothing);
        expect(find.text('Next temptation'), findsOneWidget);
        final tempt = find.byKey(const ValueKey('ring-tempt-ring'));
        await tester.ensureVisible(tempt);
        await tester.tap(tempt);
        expect(tester.takeException(), isNull);
      }
      expect(taps, 8);
    },
  );

  Future<TableFixture> open(WidgetTester tester, {Size size = const Size(1133, 744), double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final f = TableFixture();
    await f.initialize();
    f.catalog.loaded = true;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      f.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      theme: tableTheme(Brightness.dark),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => showTableWorkspace(context, f.controller,
          catalog: f.catalog, seatId: f.playerId, initialPage: WorkspacePage.utilities),
        child: const Text('Open utilities'),
      ))),
    ));
    await tester.tap(find.text('Open utilities'));
    await tester.pumpAndSettle();
    return f;
  }

  Finder toggle(String id) => find.byKey(ValueKey('utility-toggle-$id'));
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }
  void search(WidgetTester tester, String query) {
    tester.widget<PlayerField>(find.byKey(const ValueKey('utility-picker-search')))
        .controller.text = query;
  }

  testWidgets('one toggle list keeps hidden configuration and seat state through reload', (tester) async {
    final f = await open(tester);
    final otherId = f.controller.session.players.last.id;
    await f.board.addUtility(otherId, RingService.kind);
    final other = f.controller.player(otherId).toJson();
    expect(find.text('Add a utility'), findsNothing);
    expect(toggle('the_ring'), findsOneWidget);
    search(tester, 'ring');
    await tester.pumpAndSettle();
    final beforeY = tester.getTopLeft(toggle('the_ring')).dy;
    await tap(tester, toggle('the_ring'));
    final ringId = f.player.utilities.last.id;
    expect(tester.getTopLeft(toggle(ringId)).dy, beforeY);
    expect(tester.widget<SwitchListTile>(toggle(ringId)).value, isTrue);
    await RingService(f.controller).tempt(f.playerId, ringId, bearer: 'Frodo');
    await f.board.setUtility(f.playerId, ringId,
      name: 'My precious', description: 'Saved notes',
      configuration: {'custom': {'keep': true}});
    await tester.pumpAndSettle();
    final before = f.player.utilities.last.toJson();
    await tap(tester, toggle(ringId));
    expect(f.player.utilities.last.toJson(), {...before, 'visible': false});
    expect(f.board.isUtilityVisible(f.player.utilities.last), isFalse);
    expect(tester.widget<SwitchListTile>(toggle(ringId)).value, isFalse);
    await tap(tester, toggle(ringId));
    expect(f.player.utilities.last.toJson(), before);
    expect(f.controller.player(otherId).toJson(), other);
    final reopened = TableController(repository: f.repository);
    await reopened.initialize();
    addTearDown(reopened.dispose);
    expect(reopened.player(f.playerId).utilities.last.toJson(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search applies to every saved or available utility without changing order', (tester) async {
    final f = await open(tester);
    await f.board.addUtility(f.playerId, 'krenko_mob_boss');
    final id = f.player.utilities.last.id;
    await f.board.setUtility(f.playerId, id, name: 'Renamed utility', description: 'Personal note');
    await tester.pumpAndSettle();
    for (final query in ['Krenko', 'renamed', 'personal note']) {
      search(tester, query);
      await tester.pumpAndSettle();
      expect(toggle(id), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    }
    search(tester, ' no such utility ');
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('No utilities match your search.'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(toggle(id), findsOneWidget);
    expect(toggle('the_ring'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggle failures keep saved state and duplicates remain independently editable', (tester) async {
    final f = await open(tester);
    await f.board.addUtility(f.playerId, 'krenko_mob_boss');
    await f.board.addUtility(f.playerId, 'krenko_mob_boss');
    search(tester, 'Krenko');
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    final ids = f.player.utilities.where((u) => u.kind == 'krenko_mob_boss').map((u) => u.id).toList();
    final before = f.player.utilities.map((u) => u.toJson()).toList();
    f.repository.failSave = true;
    await tap(tester, toggle(ids.first));
    expect(f.player.utilities.map((u) => u.toJson()).toList(), before);
    expect(tester.widget<SwitchListTile>(toggle(ids.first)).value, isTrue);
    f.repository.failSave = false;
    await tap(tester, toggle(ids.first));
    expect(f.player.utilities.firstWhere((u) => u.id == ids.first).visible, isFalse);
    expect(f.player.utilities.firstWhere((u) => u.id == ids.last).visible, isTrue);
    expect(find.byKey(ValueKey('utility-edit-${ids.first}')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 700), const Size(744, 1133), const Size(1133, 744)]) {
    testWidgets('header and full-width search have separate space at $size', (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      final f = await open(tester, size: size, scale: size.width == 320 ? 1.5 : 1);
      final heading = tester.getRect(find.byKey(const ValueKey('utility-picker-heading')));
      final searchBox = tester.getRect(find.byKey(const ValueKey('utility-picker-search')));
      expect(searchBox.top - heading.bottom, greaterThanOrEqualTo(12));
      final modal = tester.getRect(find.byKey(const ValueKey('context-workspace')));
      expect(searchBox.width, closeTo(modal.width - 40, .01));
      search(tester, 'Storm');
      await tester.pumpAndSettle();
      final storm = f.player.utilities.firstWhere((u) => u.kind == 'storm_count');
      final target = toggle(storm.id);
      await tap(tester, target);
      expect(f.player.utilities.firstWhere((u) => u.id == storm.id).visible, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
