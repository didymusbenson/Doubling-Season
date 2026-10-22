import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory isolatedCatalog;

  setUpAll(() async {
    isolatedCatalog = await Directory.systemTemp.createTemp(
      'board-half-stepper-',
    );
    Hive.init(isolatedCatalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });

  tearDownAll(() async {
    await Hive.close();
    await isolatedCatalog.delete(recursive: true);
  });

  Future<TableFixture> showTable(
    WidgetTester tester, {
    bool commanders = false,
    TabletState? persistedState,
  }) async {
    final state = persistedState ?? TabletState.initial();
    state.session.players = state.session.players.take(2).toList();
    if (commanders) {
      state.session.commanders = [
        CommanderSource(
          id: 'partner-a',
          ownerPlayerId: state.session.players.last.id,
          name: 'Partner A',
        ),
        CommanderSource(
          id: 'partner-b',
          ownerPlayerId: state.session.players.last.id,
          name: 'Partner B',
        ),
        CommanderSource(
          id: 'self',
          ownerPlayerId: state.session.players.first.id,
          name: 'Self commander',
        ),
      ];
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1133, 744);
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
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      fixture.dispose();
    });
    return fixture;
  }

  // Local coordinates preserve the seated player's left/right meaning under
  // RotatedBox; screen-left would reverse these actions for the upper seat.
  Offset localPoint(WidgetTester tester, Finder target, Offset fraction) {
    final box = tester.renderObject<RenderBox>(target);
    return box.localToGlobal(
      Offset(box.size.width * fraction.dx, box.size.height * fraction.dy),
    );
  }

  Future<void> tapAtFraction(
    WidgetTester tester,
    Finder target,
    Offset fraction,
  ) async {
    await tester.tapAt(localPoint(tester, target, fraction));
    await tester.pumpAndSettle();
  }

  Finder stepper(String label) => find.byWidgetPredicate(
    (widget) => widget is HalfStepper && widget.label == label,
  );

  Finder half(Finder control, {required bool increase}) => find
      .descendant(of: control, matching: find.byType(InkWell))
      .at(increase ? 1 : 0);

  void expectLifeDelta(WidgetTester tester, String playerId, String? value) {
    final content = find.descendant(
      of: find.byKey(ValueKey('$playerId-life-delta')),
      matching: find.byType(Text),
    );
    if (value == null) {
      expect(content, findsNothing);
    } else {
      expect(content, findsOneWidget);
      expect(tester.widget<Text>(content).data, value);
    }
  }

  const edgePoints = [Offset(.02, .1), Offset(.5, .9), Offset(.98, .5)];

  Future<void> tapEntireHalf(WidgetTester tester, Finder target) async {
    for (final point in edgePoints) {
      await tapAtFraction(tester, target, point);
    }
  }

  testWidgets(
    'cold load preserves old life history without replaying its delta feedback',
    (tester) async {
      final initial = TabletState.initial();
      initial.session.players = initial.session.players.take(2).toList();
      final seed = TableFixture(initial);
      await seed.initialize();
      final playerId = seed.playerId;
      expect(await seed.controller.adjustLife(playerId, -7), isTrue);
      final saved = seed.controller.state.copy();
      final old = DateTime.now().toUtc().subtract(const Duration(seconds: 10));
      saved.session.history.last.createdAt = old;
      saved.session.history.last.updatedAt = old;
      seed.dispose();
      final persisted = saved.session.toJson();
      final fixture = await showTable(tester, persistedState: saved);
      expect(fixture.controller.player(playerId).life, 33);
      expectLifeDelta(tester, playerId, null);
      expect(
        fixture.controller.session.toJson(),
        persisted,
        reason: 'Rendering must not rewrite stored history or totals.',
      );

      await tapAtFraction(
        tester,
        find.byKey(ValueKey('$playerId-life-increase')),
        const Offset(.02, .5),
      );
      expect(fixture.controller.player(playerId).life, 34);
      expectLifeDelta(tester, playerId, '+1');
      expect(fixture.controller.session.history, hasLength(2));
      expect(
        fixture.controller.session.history.first.toJson(),
        persisted['history'].first,
      );
      expect(fixture.controller.session.history.last.totalDelta, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'life row interior changes life instead of opening the player editor',
    (tester) async {
      final fixture = await showTable(tester);
      final seat = find.byKey(ValueKey(fixture.playerId));
      final life = find.descendant(
        of: seat,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_LifePanel',
        ),
      );
      final row = find
          .descendant(
            of: life,
            matching: find.byWidgetPredicate(
              (widget) => widget is SizedBox && widget.height == 48,
            ),
          )
          .first;
      await tapAtFraction(tester, row, const Offset(.25, .5));
      expect(fixture.player.life, 39);
      expect(find.byTooltip('Close workspace'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      '$platform life entire local halves step through center text and preserve separate details',
      (tester) async {
        final fixture = await showTable(tester);
        for (final player in fixture.controller.session.players) {
          final decrease = find.byKey(ValueKey('${player.id}-life-decrease'));
          final increase = find.byKey(ValueKey('${player.id}-life-increase'));
          expect(decrease.hitTestable(), findsOneWidget);
          expect(increase.hitTestable(), findsOneWidget);
          expect(
            tester.getSize(decrease).width,
            closeTo(tester.getSize(increase).width, .01),
          );
          expect(tester.getSize(decrease).height, 48);
          await tapEntireHalf(tester, decrease);
          expect(fixture.controller.player(player.id).life, 37);
          expectLifeDelta(tester, player.id, '-3');
          expect(fixture.controller.session.history.last.commands.length, 3);
          expect(fixture.controller.session.history.last.playerId, player.id);
          expect(
            find.byTooltip('Close workspace'),
            findsNothing,
            reason: 'The number must not intercept center-adjacent half taps.',
          );
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).life, 40);
          expectLifeDelta(tester, player.id, null);
          await tapEntireHalf(tester, increase);
          expect(fixture.controller.player(player.id).life, 43);
          expectLifeDelta(tester, player.id, '+3');
          await tapAtFraction(tester, decrease, const Offset(.98, .5));
          expect(fixture.controller.player(player.id).life, 42);
          expectLifeDelta(tester, player.id, '+2');
          expect(fixture.controller.session.history.last.commands.length, 4);
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).life, 40);
          expectLifeDelta(tester, player.id, null);

          final held = await tester.startGesture(
            localPoint(tester, increase, const Offset(.02, .5)),
          );
          await tester.pump(const Duration(milliseconds: 550));
          await tester.pump(const Duration(milliseconds: 350));
          expect(fixture.controller.player(player.id).life, 50);
          expectLifeDelta(tester, player.id, '+10');
          await held.up();
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            fixture.controller.player(player.id).life,
            50,
            reason: 'A released pointer must stop repeat.',
          );
          await tester.pump(const Duration(milliseconds: 1501));
          expectLifeDelta(tester, player.id, null);
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).life, 40);

          await tapAtFraction(tester, increase, const Offset(.02, .5));
          expectLifeDelta(tester, player.id, '+1');
          final other = fixture.controller.session.players.firstWhere(
            (p) => p.id != player.id,
          );
          await tapAtFraction(
            tester,
            find.byKey(ValueKey('${other.id}-mana-W-add')),
            const Offset(.98, .5),
          );
          expectLifeDelta(tester, player.id, null);
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expectLifeDelta(tester, player.id, null);
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).life, 40);

          final beforeDetails = fixture.controller.session.toJson();
          await tester.tap(find.byKey(ValueKey('${player.id}-player-details')));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Close workspace'), findsOneWidget);
          expect(fixture.controller.session.toJson(), beforeDetails);
          await tester.tap(find.byTooltip('Close workspace'));
          await tester.pumpAndSettle();

          final heldWhileOpening = await tester.startGesture(
            localPoint(tester, increase, const Offset(.98, .5)),
            pointer: 99,
          );
          await tester.pump(const Duration(milliseconds: 550));
          expect(fixture.controller.player(player.id).life, 45);
          await tester.tap(find.byKey(ValueKey('${player.id}-player-details')));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Close workspace'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 900));
          expect(
            fixture.controller.player(player.id).life,
            45,
            reason:
                'Opening the full-table workspace must stop the held board action.',
          );
          await heldWhileOpening.up();
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).life, 45);
          await tester.tap(find.byTooltip('Close workspace'));
          await tester.pumpAndSettle();
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          for (final other in fixture.controller.session.players) {
            expect(other.life, 40);
          }
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );

    testWidgets(
      '$platform numeric utility uses both full halves without expanding or opening the editor',
      (tester) async {
        final fixture = await showTable(tester);
        for (final player in fixture.controller.session.players) {
          final seat = find.byKey(ValueKey(player.id));
          final storm = find.descendant(of: seat, matching: stepper('Storm'));
          expect(storm, findsOneWidget);
          final decrease = half(storm, increase: false);
          final increase = half(storm, increase: true);
          int getStorm() => fixture.controller
              .player(player.id)
              .utilities
              .firstWhere((u) => u.kind == 'storm_count')
              .value;
          final historyBefore = fixture.controller.session.history.length;
          await tapEntireHalf(tester, decrease);
          expect(getStorm(), 0);
          expect(fixture.controller.session.history.length, historyBefore);
          await tapEntireHalf(tester, increase);
          expect(getStorm(), 3);
          expect(fixture.controller.session.history.last.commands.length, 3);
          expect(fixture.controller.session.history.last.playerId, player.id);
          expect(find.byTooltip('Close workspace'), findsNothing);
          expect(
            find.byTooltip('Hide Storm'),
            findsNothing,
            reason: 'Stepping must not expand the utility.',
          );
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(getStorm(), 0);
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );

    testWidgets(
      '$platform partner and self source halves keep direct damage, life coupling and undo',
      (tester) async {
        final fixture = await showTable(tester, commanders: true);
        for (final player in fixture.controller.session.players) {
          final ownerUnchanged = fixture.controller.session.players
              .firstWhere((p) => p.id != player.id)
              .toJson();
          for (final source in fixture.controller.session.commanders) {
            final tracker = find.byKey(
              ValueKey('${player.id}-commander-trackers'),
            );
            final scroll = tester
                .widget<ListView>(
                  find.descendant(of: tracker, matching: find.byType(ListView)),
                )
                .controller!;
            final sourceIndex = fixture.controller.session.commanders.indexOf(
              source,
            );
            scroll.jumpTo(
              (sourceIndex * 144.0).clamp(0, scroll.position.maxScrollExtent),
            );
            await tester.pumpAndSettle();
            final chip = find.byKey(
              ValueKey('${player.id}-commander-${source.id}'),
            );
            final control = find.descendant(
              of: chip,
              matching: find.byType(HalfStepper),
            );
            expect(control, findsOneWidget);
            final decrease = half(control, increase: false);
            final increase = half(control, increase: true);
            expect(tester.getSize(decrease).width, greaterThanOrEqualTo(44));
            expect(tester.getSize(decrease).height, greaterThanOrEqualTo(44));
            await tapEntireHalf(tester, decrease);
            expect(
              fixture.controller.player(player.id).commanderDamage[source.id] ??
                  0,
              0,
            );
            expect(fixture.controller.player(player.id).life, 40);
            await tapEntireHalf(tester, increase);
            expect(
              fixture.controller.player(player.id).commanderDamage[source.id],
              3,
            );
            expect(fixture.controller.player(player.id).life, 37);
            expect(fixture.controller.session.history.last.commands.length, 3);
            expect(fixture.controller.session.history.last.playerId, player.id);
            expect(find.byTooltip('Close workspace'), findsNothing);
            expect(await fixture.controller.undo(), isTrue);
            await tester.pumpAndSettle();
            expect(
              fixture.controller.player(player.id).commanderDamage[source.id] ??
                  0,
              0,
            );
            expect(fixture.controller.player(player.id).life, 40);
            expect(
              fixture.controller.session.players
                  .firstWhere((p) => p.id != player.id)
                  .toJson(),
              ownerUnchanged,
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );

    testWidgets(
      '$platform counter modal keeps full local halves, zero clamp and recipient-only history',
      (tester) async {
        final fixture = await showTable(tester);
        for (final player in fixture.controller.session.players) {
          final name = fixture.controller.profile(player.seatId).name;
          await tester.tap(find.byTooltip('$name, player counters'));
          await tester.pumpAndSettle();
          final poison = stepper('poison');
          expect(poison.hitTestable(), findsOneWidget);
          final decrease = half(poison, increase: false);
          final increase = half(poison, increase: true);
          final historyBefore = fixture.controller.session.history.length;
          await tapEntireHalf(tester, decrease);
          expect(
            fixture.controller.player(player.id).counters['poison'] ?? 0,
            0,
          );
          expect(fixture.controller.session.history.length, historyBefore);
          await tapEntireHalf(tester, increase);
          expect(fixture.controller.player(player.id).counters['poison'], 3);
          expect(fixture.controller.session.history.last.playerId, player.id);
          expect(fixture.controller.session.history.last.commands.length, 3);
          expect(fixture.controller.player(player.id).life, 40);
          for (final other in fixture.controller.session.players) {
            if (other.id != player.id) expect(other.counters['poison'] ?? 0, 0);
          }
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(
            fixture.controller.player(player.id).counters['poison'] ?? 0,
            0,
          );
          await tester.tap(find.byTooltip('Close workspace'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );

    testWidgets(
      '$platform mana uses full local halves at edges, preserves hold/clamp and seat-only undo',
      (tester) async {
        final fixture = await showTable(tester);
        for (final player in fixture.controller.session.players) {
          final spend = find.byKey(ValueKey('${player.id}-mana-W-spend'));
          final add = find.byKey(ValueKey('${player.id}-mana-W-add'));
          expect(spend.hitTestable(), findsOneWidget);
          expect(add.hitTestable(), findsOneWidget);
          final spendBox = tester.renderObject<RenderBox>(spend);
          final addBox = tester.renderObject<RenderBox>(add);
          expect(spendBox.size.width, closeTo(addBox.size.width, .01));
          expect(spendBox.size.height, 48);
          expect(addBox.size.height, 48);
          final historyBefore = fixture.controller.session.history.length;
          await tapAtFraction(tester, spend, const Offset(.02, .1));
          expect(fixture.controller.player(player.id).mana['W'] ?? 0, 0);
          expect(fixture.controller.session.history.length, historyBefore);
          for (final point in const [
            Offset(.02, .1),
            Offset(.5, .5),
            Offset(.98, .9),
          ]) {
            await tapAtFraction(tester, add, point);
          }
          expect(fixture.controller.player(player.id).mana['W'], 3);
          expect(fixture.controller.session.history.last.playerId, player.id);
          expect(fixture.controller.session.history.last.commands.length, 3);
          for (final other in fixture.controller.session.players) {
            if (other.id != player.id) expect(other.mana['W'] ?? 0, 0);
          }
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).mana['W'] ?? 0, 0);
          await tester.longPressAt(
            localPoint(tester, add, const Offset(.98, .1)),
          );
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).mana['W'], 10);
          await tester.longPressAt(
            localPoint(tester, spend, const Offset(.02, .9)),
          );
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).mana['W'], 0);
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).mana['W'], 10);
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).mana['W'] ?? 0, 0);
          expect(fixture.controller.player(player.id).life, 40);
        }
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
