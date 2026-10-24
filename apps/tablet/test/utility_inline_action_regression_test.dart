import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/utility_inline_actions.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalogDirectory;
  setUpAll(() async {
    catalogDirectory = await Directory.systemTemp.createTemp(
      'inline-utilities-',
    );
    Hive.init(catalogDirectory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await catalogDirectory.delete(recursive: true);
  });

  Future<(TableFixture, String)> showUtility(
    WidgetTester tester,
    String kind, {
    bool table = true,
    int turns = 0,
    double width = 220,
    int seats = 2,
  }) async {
    final state = stateWithTokens([sampleToken(tapped: 0, sick: 0)]);
    state.session.players = state.session.players.take(seats).toList();
    state.session.players.first.utilities.clear();
    final fixture = TableFixture(state);
    await fixture.initialize();
    if (kind == 'custom_toggle') {
      await fixture.board.createCustomUtility(
        fixture.playerId,
        name: 'Custom toggle',
        toggle: true,
      );
    } else {
      await fixture.board.addUtility(fixture.playerId, kind);
    }
    final utility = fixture.player.utilities.single;
    utility.artworkUrl = null;
    utility.configuration['artworkOptions'] = [];
    await fixture.board.setUtility(fixture.playerId, utility.id, value: 3);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1133, 744);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        home: table
            ? TableScreen(controller: fixture.controller)
            : Scaffold(
                body: Center(
                  child: SizedBox(
                    width: turns.isOdd ? 500 : width,
                    height: turns.isOdd ? width : 500,
                    child: RotatedBox(
                      quarterTurns: turns,
                      child: AnimatedBuilder(
                        animation: fixture.controller,
                        builder: (context, _) => SingleChildScrollView(
                          child: UtilityInlineActions(
                            board: fixture.board,
                            playerId: fixture.playerId,
                            utility: fixture.player.utilities.single,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.dispose();
    });
    return (fixture, utility.id);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final kind in ['storm_count', 'mana_pool', 'custom_toggle']) {
    for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
      testWidgets('$kind management shares its header at $size', (
        tester,
      ) async {
        final (f, id) = await showUtility(tester, kind, seats: 4);
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final seat = find.byKey(ValueKey(f.playerId));
        final utility = f.player.utilities.single;
        await tester.tap(
          find.descendant(of: seat, matching: find.byTooltip(utility.name)),
        );
        await tester.pumpAndSettle();
        final edit = find.descendant(
          of: seat,
          matching: find.byTooltip(
            kind == 'mana_pool'
                ? 'Manage ${utility.name}'
                : '${utility.name}, details and actions',
          ),
        );
        final hide = find.descendant(
          of: seat,
          matching: find.byTooltip('Hide ${utility.name}'),
        );
        expect(edit.hitTestable(), findsOneWidget);
        expect(hide.hitTestable(), findsOneWidget);
        expect(
          (tester.getCenter(edit).dy - tester.getCenter(hide).dy).abs(),
          lessThan(1),
        );
        final header = find.descendant(
          of: seat,
          matching: find.byTooltip(utility.name),
        );
        expect(
          (tester.getCenter(header).dy - tester.getCenter(edit).dy).abs(),
          lessThan(12),
        );
        final inline = tester.widget<UtilityInlineActions>(
          find.byKey(ValueKey('inline-actions-$id')),
        );
        expect(
          inline.management,
          isEmpty,
          reason: 'No trailing management-only row.',
        );
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: edit, matching: find.byType(Icon)),
              )
              .icon,
          Icons.edit_outlined,
        );
        if (kind == 'custom_toggle') {
          final switchControl = find.descendant(
            of: seat,
            matching: find.byType(Switch),
          );
          expect(switchControl.hitTestable(), findsOneWidget);
          expect(
            tester.getSize(header).width,
            greaterThan(53),
            reason: 'Keep a readable name width.',
          );
          expect(
            tester.getSize(switchControl).height,
            greaterThanOrEqualTo(44),
          );
          expect(find.byTooltip('Increase Custom toggle'), findsNothing);
          await tester.tap(switchControl);
          await tester.pumpAndSettle();
          expect(f.board.utilityActive(f.playerId, id), isTrue);
          await f.controller.undo();
          await tester.pumpAndSettle();
          expect(f.board.utilityActive(f.playerId, id), isFalse);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final kind in UtilityInlineActions.labels.keys.where(
    (k) => k != 'brudiclad_telchor_engineer',
  )) {
    testWidgets('$kind resolves directly from table, scoped and undoable', (
      tester,
    ) async {
      final (f, id) = await showUtility(tester, kind);
      final before = f.player.toJson();
      final other = f.controller.session.players.last.toJson();
      final history = f.controller.session.history.length;
      await tap(tester, 'utility-action-$id');
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(ValueKey('utility-detail-$kind')), findsNothing);
      expect(f.controller.session.history.length, history + 1);
      expect(f.player.toJson(), isNot(equals(before)));
      expect(f.controller.session.players.last.toJson(), equals(other));
      if (kind == 'cathars_crusade') {
        expect(f.token('source').plusOneCounters, 3);
        expect(f.player.utilities.single.value, 0);
      }
      if (kind == 'rhys_the_redeemed') {
        expect(f.player.tokens.fold<int>(0, (n, t) => n + t.amount), 6);
      }
      await f.controller.undo();
      expect(f.player.tokens.map((t) => t.toJson()).toList(), before['tokens']);
      expect(
        f.player.utilities.map((u) => u.toJson()).toList(),
        before['utilities'],
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Crusade quick action preserves count and works expanded', (
    tester,
  ) async {
    final (f, id) = await showUtility(tester, 'cathars_crusade');
    await tester.tap(find.text("Cathar's Crusade").first);
    await tester.pumpAndSettle();
    await tap(tester, 'utility-quick-$id');
    expect(f.token('source').plusOneCounters, 1);
    expect(f.player.utilities.single.value, 3);
    await tap(tester, 'utility-action-$id');
    expect(f.token('source').plusOneCounters, 4);
    expect(f.player.utilities.single.value, 0);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
    'Brudiclad selects on card, cancels, rejects stale choice, and skips',
    (tester) async {
      final (f, id) = await showUtility(tester, 'brudiclad_telchor_engineer');
      final initial = f.player.tokens.map((t) => t.toJson()).toList();
      await tap(tester, 'utility-action-$id');
      expect(f.player.tokens.map((t) => t.toJson()).toList(), initial);
      await tester.ensureVisible(find.text('Cancel selection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel selection'));
      await tester.pumpAndSettle();
      expect(f.player.tokens.map((t) => t.toJson()).toList(), initial);
      await tap(tester, 'utility-action-$id');
      await f.controller.adjustLife(f.playerId, -1);
      await tester.pumpAndSettle();
      await tap(tester, 'utility-target-$id-source');
      expect(f.player.tokens.map((t) => t.toJson()).toList(), initial);
      expect(find.byKey(ValueKey('utility-feedback-$id')), findsOneWidget);
      await tap(tester, 'utility-action-$id');
      expect(find.text('Create Myr only'), findsOneWidget);
      expect(
        find.byTooltip('Create the Myr and skip transformation'),
        findsOneWidget,
      );
      await tap(tester, 'utility-skip-$id');
      expect(f.player.tokens.any((t) => t.name.contains('Myr')), isTrue);
      expect(find.byType(Dialog), findsNothing);
      await f.controller.undo();
      await tester.pumpAndSettle();
      await tap(tester, 'utility-action-$id');
      await tap(tester, 'utility-target-$id-source');
      expect(f.player.tokens.every((t) => t.name == 'Saproling'), isTrue);
      expect(f.player.tokens.fold<int>(0, (n, t) => n + t.amount), 4);
    },
  );

  testWidgets('Failed Rhys save reports inline error and permits safe retry', (
    tester,
  ) async {
    final (f, id) = await showUtility(tester, 'rhys_the_redeemed');
    f.repository.failSave = true;
    await tap(tester, 'utility-action-$id');
    expect(f.player.tokens.fold<int>(0, (n, t) => n + t.amount), 3);
    expect(find.byKey(ValueKey('utility-feedback-$id')), findsOneWidget);
    expect(find.textContaining('Simulated storage failure'), findsWidgets);
    f.repository.failSave = false;
    await tap(tester, 'utility-action-$id');
    expect(f.player.tokens.fold<int>(0, (n, t) => n + t.amount), 6);
    await tap(tester, 'utility-action-$id');
    expect(f.player.tokens.fold<int>(0, (n, t) => n + t.amount), 12);
  });

  testWidgets(
    'Utility numeric hold repeats, accelerates and stops on release',
    (tester) async {
      final (f, _) = await showUtility(tester, 'krenko_tin_street');
      final target = find.byTooltip('Increase Krenko, Tin Street Kingpin');
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(target));
      for (var i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(f.player.utilities.single.value, greaterThan(20));
      expect(f.player.tokens.fold<int>(0, (n, t) => n + t.amount), 3);
      await gesture.up();
      await tester.pumpAndSettle();
      final stopped = f.player.utilities.single.value;
      await tester.pump(const Duration(seconds: 3));
      expect(f.player.utilities.single.value, stopped);
    },
  );

  testWidgets('Holding action button never repeats Rhys', (tester) async {
    final (f, id) = await showUtility(
      tester,
      'rhys_the_redeemed',
      table: false,
    );
    final button = find.byKey(ValueKey('utility-action-$id'));
    await tester.ensureVisible(button);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(seconds: 6));
    expect(f.player.tokens.fold<int>(0, (n, t) => n + t.amount), 3);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(f.player.tokens.fold<int>(0, (n, t) => n + t.amount), 6);
    await tester.pump(const Duration(seconds: 2));
    expect(f.player.tokens.fold<int>(0, (n, t) => n + t.amount), 6);
  });

  for (final label in ['Increase White mana', 'Increase White mana by ten']) {
    testWidgets('Mana hold stops after failed save: $label', (tester) async {
      final state = TabletState.initial();
      state.session.players = state.session.players.take(2).toList();
      final repository = _CountingRepository(state);
      final controller = TableController(repository: repository);
      await controller.initialize();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1133, 744);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Manage Mana pool').first);
      await tester.pumpAndSettle();
      repository.failSave = true;
      repository.attempts = 0;
      final target = find.byTooltip(label);

      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(target));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repository.attempts, 1);
      expect(controller.session.players.first.mana['W'], 0);
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));
      expect(repository.attempts, 1);
      repository.failSave = false;
      for (var i = 0; i < 2; i++) {
        if (find.byTooltip('Close workspace').evaluate().isNotEmpty) {
          await tester.tap(find.byTooltip('Close workspace'));
          await tester.pumpAndSettle();
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      controller.dispose();
    });
  }

  for (final turns in [0, 1, 2, 3]) {
    testWidgets('Inline buttons fit narrow rotated seat $turns', (
      tester,
    ) async {
      final (f, id) = await showUtility(
        tester,
        'cathars_crusade',
        table: false,
        turns: turns,
        width: 170,
      );
      await tap(tester, 'utility-quick-$id');
      expect(f.token('source').plusOneCounters, 1);
      await tap(tester, 'utility-action-$id');
      expect(f.token('source').plusOneCounters, 4);
      expect(tester.takeException(), isNull);
    });
  }
}

class _CountingRepository extends MemoryTableRepository {
  int attempts = 0;
  _CountingRepository(super.state);
  @override
  Future<void> save(TabletState state) {
    attempts++;
    return super.save(state);
  }
}
