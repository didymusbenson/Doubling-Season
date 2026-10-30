import 'support/control_finders.dart';
import 'dart:io';
import 'dart:math' as math;

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

  const edgePoints = [Offset(.02, .35), Offset(.5, .9), Offset(.98, .5)];

  Future<void> tapEntireHalf(
    WidgetTester tester,
    Finder target, {
    List<Offset> points = edgePoints,
  }) async {
    for (final point in points) {
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
      final row = find.byKey(ValueKey('${fixture.playerId}-life-surface'));
      await tapAtFraction(tester, row, const Offset(.25, .5));
      expect(fixture.player.life, 39);
      expect(byControlLabel('Close workspace'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(650, 1024), const Size(744, 1133)]) {
    testWidgets(
      'two-seat flank circle at $size owns only its actual life intersection',
      (tester) async {
        final fixture = await showTable(tester);
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final ids = fixture.controller.session.players
            .map((p) => p.id)
            .toList();
        for (var index = 0; index < ids.length; index++) {
          final id = ids[index];
          final surface = tester.renderObject<RenderBox>(
            find.byKey(ValueKey('$id-life-surface')),
          );
          final clipping = find.byKey(ValueKey('$id-life-clip'));
          final rail = tester.renderObject<RenderBox>(clipping);
          final control = tester.getRect(
            find.byKey(
              ValueKey(index == 0 ? 'shared-day-night' : 'shared-dice'),
            ),
          );
          final center = rail.globalToLocal(control.center);
          final radius = control.width / 2;
          const y = 1.0;
          final rightEdge =
              center.dx +
              math.sqrt(radius * radius - math.pow(y - center.dy, 2));
          final inside = Offset(rightEdge - .25, y);
          final outside = Offset(rightEdge + .5, y);
          final path = tester
              .widget<ClipPath>(clipping)
              .clipper!
              .getClip(rail.size);
          expect(inside.dx, greaterThan(0));
          expect(path.contains(inside), isFalse);
          expect(path.contains(outside), isTrue);
          expect(
            path.contains(const Offset(26, 26)),
            isTrue,
            reason: 'No obsolete fixed life-corner hole',
          );
          final before = fixture.controller.player(id).life;
          final day = fixture.controller.session.dayNight;
          await tester.tapAt(rail.localToGlobal(inside));
          await tester.pumpAndSettle();
          expect(fixture.controller.player(id).life, before);
          if (index == 0) {
            expect(fixture.controller.session.dayNight, isNot(day));
          } else {
            expect(
              find.byKey(const ValueKey('game-drawer-workspace')),
              findsOneWidget,
            );
            await tester.tap(
              find.byKey(const ValueKey('central-game-controls')),
            );
            await tester.pumpAndSettle();
          }
          await tester.tapAt(rail.localToGlobal(outside));
          await tester.pumpAndSettle();
          expect(
            fixture.controller.player(id).life,
            before - 1,
            reason: 'The adjacent visible life pixel must remain tappable',
          );
          expect(
            surface.globalToLocal(rail.localToGlobal(outside)).dy,
            closeTo(1, .001),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'two-seat circle clearance stays at viewport during short scroll and disappears below warnings',
    (tester) async {
      final fixture = await showTable(tester);
      tester.view.padding = const FakeViewPadding();
      tester.view.physicalSize = const Size(650, 480);
      await tester.pumpAndSettle();
      final id = fixture.playerId;
      final clipping = find.byKey(ValueKey('$id-life-clip'));
      final surface = find.byKey(ValueKey('$id-life-surface'));
      final menu = find.byKey(const ValueKey('central-game-controls'));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final rail = tester.renderObject<RenderBox>(clipping);
      final beforeClip = tester.getRect(clipping);
      final beforeSurface = tester.getTopLeft(surface);
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(ValueKey('$id-short-life-rail-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final offset = math.min(40.0, scroll.position.maxScrollExtent);
      expect(offset, greaterThan(0));
      scroll.position.jumpTo(offset);
      await tester.pumpAndSettle();
      expect(tester.getRect(clipping), beforeClip);
      expect(
        tester.getTopLeft(surface).dy,
        closeTo(beforeSurface.dy - offset, .001),
      );
      final control = tester.getRect(
        find.byKey(const ValueKey('shared-day-night')),
      );
      final center = rail.globalToLocal(control.center);
      final path = tester
          .widget<ClipPath>(clipping)
          .clipper!
          .getClip(rail.size);
      for (var x = 1.0; x < rail.size.width; x += 7) {
        for (var y = 1.0; y < rail.size.height; y += 7) {
          final point = Offset(x, y);
          expect(
            path.contains(point),
            (point - center).distance > control.width / 2,
          );
        }
      }
      await tester.tap(menu);
      await tester.pumpAndSettle();
      fixture.repository.failSave = true;
      await tester.tap(find.byKey(ValueKey('$id-life-decrease')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('$id-acknowledge-life-error')),
        findsOneWidget,
      );
      final warnedRail = tester.renderObject<RenderBox>(clipping);
      final warnedPath = tester
          .widget<ClipPath>(clipping)
          .clipper!
          .getClip(warnedRail.size);
      expect(warnedPath.contains(const Offset(1, 1)), isTrue);
      expect(warnedPath.contains(const Offset(26, 26)), isTrue);
      expect(
        (warnedRail.localToGlobal(const Offset(1, 1)) -
                tester.getCenter(
                  find.byKey(const ValueKey('shared-day-night')),
                ))
            .distance,
        greaterThan(22),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      '$platform colored life surface includes names and border-inset corners; tools are disjoint',
      (tester) async {
        final fixture = await showTable(tester);
        for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          for (final player in fixture.controller.session.players) {
            final surface = find.byKey(ValueKey('${player.id}-life-surface'));
            final box = tester.renderObject<RenderBox>(surface);
            final before = fixture.controller.session.players
                .map((p) => p.life)
                .toList();
            var expected = player.life;
            for (final point in [
              const Offset(1, 1),
              const Offset(1, 32),
              Offset(box.size.width - 1, 32),
              Offset(box.size.width / 2 - 1, 1),
              Offset(box.size.width / 2 + 1, 1),
              Offset(box.size.width - 1, 1),
              Offset(1, box.size.height - 1),
              Offset(box.size.width / 2 - 1, box.size.height - 1),
              Offset(box.size.width / 2 + 1, box.size.height - 1),
              Offset(box.size.width - 1, box.size.height - 1),
            ]) {
              final clip = tester.widget<ClipPath>(
                find.byKey(ValueKey('${player.id}-life-clip')),
              );
              if (!clip.clipper!.getClip(box.size).contains(point)) continue;
              expected += point.dx < box.size.width / 2 ? -1 : 1;
              await tester.tapAt(box.localToGlobal(point));
              await tester.pumpAndSettle();
              expect(
                fixture.controller.player(player.id).life,
                expected,
                reason:
                    'size=$size player=${player.slot} '
                    'local=$point global=${box.localToGlobal(point)} '
                    'DayNight=${tester.getRect(find.byKey(const ValueKey("shared-day-night")))} '
                    'Dice=${tester.getRect(find.byKey(const ValueKey("shared-dice")))}',
              );
              expect(byControlLabel('Close workspace'), findsNothing);
            }
            final name = find.descendant(
              of: surface,
              matching: find.text(
                fixture.controller.profile(player.seatId).name,
              ),
            );
            final namePoint = tester.getCenter(name);
            // A centered label straddles the exact half seam. Exercise each
            // side explicitly; subpixel rounding at the seam is not a contract.
            final localName = box.globalToLocal(namePoint);
            for (final dx in [-4.0, 4.0]) {
              final point = Offset(box.size.width / 2 + dx, localName.dy);
              expected += dx < 0 ? -1 : 1;
              await tester.tapAt(box.localToGlobal(point));
              await tester.pumpAndSettle();
              expect(fixture.controller.player(player.id).life, expected);
            }
            expect(byControlLabel('Close workspace'), findsNothing);
            expect(await fixture.controller.undo(), isTrue);
            await tester.pumpAndSettle();
            expect(
              fixture.controller.session.players.map((p) => p.life).toList(),
              before,
            );
            expect(
              byControlLabel(
                '${fixture.controller.profile(player.seatId).name}, player counters',
              ),
              findsNothing,
              reason: 'Zero counters take no space on the life chip.',
            );
            for (final label in [
              'rules',
              'commander damage by source',
              'player details',
            ]) {
              final snapshot = fixture.controller.session.players
                  .map((p) => p.life)
                  .toList();
              await tester.tap(
                byControlLabel(
                  '${fixture.controller.profile(player.seatId).name}, $label',
                ),
              );
              await tester.pumpAndSettle();
              expect(byControlLabel('Close workspace'), findsOneWidget);
              expect(
                fixture.controller.session.players.map((p) => p.life).toList(),
                snapshot,
              );
              await tester.tap(byControlLabel('Close workspace'));
              await tester.pumpAndSettle();
            }
          }
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );

    testWidgets(
      '$platform life local halves step through center text and preserve separate footer controls',
      (tester) async {
        final fixture = await showTable(tester);
        // The bottom 44px contains the combined commander/counter entry.
        // Keep the three-point half coverage in the actual life-hit region;
        // the preceding test exercises the separate footer controls and
        // the one-pixel life padding below them without altering totals.
        const lifePoints = [Offset(.02, .35), Offset(.5, .5), Offset(.98, .5)];
        for (final player in fixture.controller.session.players) {
          final decrease = find.byKey(ValueKey('${player.id}-life-decrease'));
          final increase = find.byKey(ValueKey('${player.id}-life-increase'));
          expect(decrease.hitTestable(), findsOneWidget);
          expect(increase.hitTestable(), findsOneWidget);
          expect(
            tester.getSize(decrease).width,
            closeTo(tester.getSize(increase).width, .01),
          );
          expect(tester.getSize(decrease).height, greaterThanOrEqualTo(104));
          await tapEntireHalf(tester, decrease, points: lifePoints);
          expect(fixture.controller.player(player.id).life, 37);
          expectLifeDelta(tester, player.id, '-3');
          expect(fixture.controller.session.history.last.commands.length, 3);
          expect(fixture.controller.session.history.last.playerId, player.id);
          expect(
            byControlLabel('Close workspace'),
            findsNothing,
            reason: 'The number must not intercept center-adjacent half taps.',
          );
          expect(await fixture.controller.undo(), isTrue);
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).life, 40);
          expectLifeDelta(tester, player.id, null);
          await tapEntireHalf(tester, increase, points: lifePoints);
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
          expect(fixture.controller.player(player.id).life, 60);
          expectLifeDelta(tester, player.id, '+20');
          await held.up();
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            fixture.controller.player(player.id).life,
            60,
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
          expect(byControlLabel('Close workspace'), findsOneWidget);
          expect(fixture.controller.session.toJson(), beforeDetails);
          await tester.tap(byControlLabel('Close workspace'));
          await tester.pumpAndSettle();

          final heldWhileOpening = await tester.startGesture(
            localPoint(tester, increase, const Offset(.98, .5)),
          );
          await tester.pump(const Duration(milliseconds: 550));
          expect(fixture.controller.player(player.id).life, 50);
          await tester.tap(find.byKey(ValueKey('${player.id}-player-details')));
          await tester.pumpAndSettle();
          expect(byControlLabel('Close workspace'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 900));
          expect(
            fixture.controller.player(player.id).life,
            50,
            reason:
                'Opening the full-table workspace must stop the held board action.',
          );
          await heldWhileOpening.up();
          await tester.pumpAndSettle();
          expect(fixture.controller.player(player.id).life, 50);
          await tester.tap(byControlLabel('Close workspace'));
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
          expect(byControlLabel('Close workspace'), findsNothing);
          expect(
            find.descendant(
              of: seat,
              matching: byControlLabel('Storm, details and actions'),
            ),
            findsNothing,
            reason: 'Stepping must not expand the utility.',
          );
          expect(
            find
                .descendant(of: seat, matching: byControlLabel('Remove Storm'))
                .hitTestable(),
            findsOneWidget,
            reason: 'Remove remains directly available while collapsed.',
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
          await tester.tap(
            find.byKey(ValueKey('${player.id}-commander-ledger')),
          );
          await tester.pumpAndSettle();
          for (final source in fixture.controller.session.commanders) {
            final chip = find.byKey(ValueKey('commander-tracker-${source.id}'));
            await tester.ensureVisible(chip);
            await tester.pumpAndSettle();
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
            // Direct edit was removed; the whole half is now a damage target.
            expect(
              find.descendant(
                of: chip,
                matching: find.byIcon(Icons.edit_outlined),
              ),
              findsNothing,
            );
            for (final point in edgePoints) {
              await tapAtFraction(tester, increase, point);
            }
            expect(
              fixture.controller.player(player.id).commanderDamage[source.id],
              3,
            );
            expect(fixture.controller.player(player.id).life, 37);
            expect(fixture.controller.session.history.last.commands.length, 3);
            expect(fixture.controller.session.history.last.playerId, player.id);
            expect(byControlLabel('Close workspace'), findsOneWidget);
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
          await tester.tap(byControlLabel('Close workspace'));
          await tester.pumpAndSettle();
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
          await tester.tap(
            find.byKey(ValueKey('${player.id}-commander-ledger')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Add counter'), findsNothing);
          final poison = stepper('poison');
          await tester.ensureVisible(poison);
          await tester.pumpAndSettle();
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
          await tester.tap(byControlLabel('Close workspace'));
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
          expect(spendBox.size.height, 44);
          expect(addBox.size.height, 44);
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
