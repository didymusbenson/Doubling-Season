import 'support/control_finders.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('utility-remove-tests-');
    Hive.init(directory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<TableFixture> show(WidgetTester tester, Size size, int seats) async {
    final state = TabletState.initial();
    state.session.players = state.session.players.take(seats).toList();
    for (final player in state.session.players) {
      player.utilities = [
        UtilityState(
          id: 'storm-${player.id}',
          kind: 'storm_count',
          name: 'Storm',
          value: 9,
          description: 'Existing state',
          configuration: {'tapIncrement': 2},
        ),
      ];
    }
    final f = TableFixture(state);
    await f.initialize();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      f.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        home: TableScreen(controller: f.controller),
      ),
    );
    await tester.pumpAndSettle();
    return f;
  }

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    for (final seats in [2, 3, 4]) {
      testWidgets(
        'Direct Remove and History restore every seat at $size/$seats',
        (tester) async {
          final f = await show(tester, size, seats);
          List<Map<String, dynamic>> gameplay() => f.controller.session.players
              .map((p) => p.toJson()..remove('generation'))
              .toList();
          final before = gameplay();
          final ids = f.controller.session.players.map((p) => p.id).toList();
          for (final id in ids) {
            final target = find.byKey(ValueKey('remove-utility-storm-$id'));
            expect(target.hitTestable(), findsOneWidget);
            expect(tester.getSize(target), const Size(44, 44));
            expect(
              find.descendant(
                of: target,
                matching: byControlLabel('Remove Storm'),
              ),
              findsOneWidget,
            );
            await tester.tap(target);
            await tester.pumpAndSettle();
            expect(f.controller.player(id).utilities, isEmpty);
            expect(f.controller.player(id).life, 40);
            expect(byControlLabel('Close workspace'), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            expect(find.text('Remove Storm?'), findsNothing);

            await tester.tap(byControlLabel('Game controls'));
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(OutlinedButton, 'History'));
            await tester.pumpAndSettle();
            final undo = find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  (widget.properties.label ?? '').startsWith(
                    'Undo latest: Remove utility',
                  ),
            );
            expect(undo.hitTestable(), findsOneWidget);
            await tester.tap(undo);
            await tester.pumpAndSettle();
            await tester.tap(byControlLabel('Close workspace'));
            await tester.pumpAndSettle();
            // Undo intentionally advances the generation to cancel stale input.
            expect(gameplay(), before);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  testWidgets('A drag beginning on Remove does not remove or change values', (
    tester,
  ) async {
    final f = await show(tester, const Size(1133, 744), 2);
    final before = f.player.toJson();
    final target = find.byKey(ValueKey('remove-utility-storm-${f.playerId}'));
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(f.player.toJson(), before);
    expect(byControlLabel('Close workspace'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A failed Remove shows an error and retains the utility', (
    tester,
  ) async {
    final f = await show(tester, const Size(1133, 744), 2);
    final before = f.player.toJson();
    f.repository.failSave = true;
    await tester.tap(
      find.byKey(ValueKey('remove-utility-storm-${f.playerId}')),
    );
    await tester.pumpAndSettle();
    expect(f.player.toJson(), before);
    expect(find.textContaining('Simulated storage failure'), findsWidgets);
    expect(byControlLabel('Close workspace'), findsNothing);
  });
}
