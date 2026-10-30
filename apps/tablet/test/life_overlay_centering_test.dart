import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

Rect _localRect(WidgetTester tester, Finder child, Finder ancestor) {
  final box = tester.renderObject<RenderBox>(child);
  return MatrixUtils.transformRect(
    box.getTransformTo(tester.renderObject<RenderBox>(ancestor)),
    Offset.zero & box.size,
  );
}

void _sameRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, .001));
  expect(actual.top, closeTo(expected.top, .001));
  expect(actual.width, closeTo(expected.width, .001));
  expect(actual.height, closeTo(expected.height, .001));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cache;
  setUpAll(() async {
    cache = await Directory.systemTemp.createTemp('life-overlay-centering-');
    Hive.init(cache.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await cache.delete(recursive: true);
  });

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    for (final seats in [2, 3, 4]) {
      for (final partners in [false, true]) {
        testWidgets(
          'life overlay group centers at $size seats=$seats partners=$partners',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);
            final state = TabletState.initial();
            state.session.players = state.session.players.take(seats).toList();
            final fixture = TableFixture(state);
            await fixture.initialize();
            addTearDown(fixture.dispose);
            if (partners) {
              for (final player
                  in fixture.controller.session.players.toList()) {
                expect(
                  await fixture.controller.setHasPartner(player.id, true),
                  isTrue,
                );
              }
            }

            // The table's opposite seats already cover 0/2. Rotating the
            // surface once also exercises the same real geometry at 1/3.
            for (final turns in [0, 1]) {
              await tester.pumpWidget(
                MaterialApp(
                  theme: tableTheme(Brightness.dark),
                  home: RotatedBox(
                    quarterTurns: turns,
                    child: TableScreen(controller: fixture.controller),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              for (final phase in [
                'none',
                'zero',
                'one',
                'counter-cleared',
                'many',
                'counter-removed',
                'city',
                'initiative',
                'monarch',
                'removed',
              ]) {
                expect(
                  await fixture.controller.updateState('Set test summary', (s) {
                    s.session.monarchPlayerId = phase == 'monarch'
                        ? s.session.players.last.id
                        : null;
                    for (final player in s.session.players) {
                      player.counters = switch (phase) {
                        'one' => {'energy': 4},
                        'many' => {'energy': 4, 'poison': 2, 'radiation': 3},
                        'none' || 'counter-removed' => {},
                        _ => {'energy': 0, 'poison': 0},
                      };
                      player.citysBlessing = phase == 'city';
                      player.utilities.removeWhere(
                        (u) => u.kind == 'initiative',
                      );
                      player.utilities.add(
                        UtilityState(
                          id: '${player.id}-test-initiative',
                          kind: 'initiative',
                          name: 'The Initiative',
                          isActive:
                              phase == 'initiative' &&
                              player.id == s.session.players.first.id,
                        ),
                      );
                    }
                  }),
                  isTrue,
                );
                await tester.pumpAndSettle();

                for (final player in fixture.controller.session.players) {
                  final hasSummary =
                      ['one', 'many', 'city'].contains(phase) ||
                      (phase == 'initiative' &&
                          player.id ==
                              fixture.controller.session.players.first.id) ||
                      (phase == 'monarch' &&
                          player.id ==
                              fixture.controller.session.players.last.id);
                  final surface = find.byKey(
                    ValueKey('${player.id}-life-surface'),
                  );
                  final stepperFinder = find.descendant(
                    of: surface,
                    matching: find.byType(HalfStepper),
                  );
                  final stepper = tester.widget<HalfStepper>(stepperFinder);
                  final width = tester.getSize(stepperFinder).width;
                  final ledger = find.byKey(
                    ValueKey('${player.id}-commander-ledger'),
                  );
                  final ledgerRect = _localRect(tester, ledger, stepperFinder);
                  final summary = find.byKey(
                    ValueKey('${player.id}-life-counter-summary'),
                  );
                  expect(stepper.inkExclusions.length, hasSummary ? 2 : 1);
                  _sameRect(stepper.inkExclusions.first, ledgerRect);
                  var group = ledgerRect;
                  if (hasSummary) {
                    expect(summary, findsOneWidget);
                    final summaryRect = _localRect(
                      tester,
                      summary,
                      stepperFinder,
                    );
                    expect(
                      summaryRect.left - ledgerRect.right,
                      closeTo(4, .001),
                    );
                    expect(summaryRect.width, greaterThan(0));
                    expect(
                      summaryRect.center.dy,
                      closeTo(ledgerRect.center.dy, .001),
                    );
                    _sameRect(stepper.inkExclusions.last, summaryRect);
                    group = ledgerRect.expandToInclude(summaryRect);
                  } else {
                    expect(summary, findsNothing);
                    expect(
                      ledgerRect.center.dx,
                      closeTo(width / 2, .001),
                      reason: '$phase must reserve no counter width or gap.',
                    );
                  }
                  expect(
                    group.center.dx,
                    closeTo(width / 2, .001),
                    reason:
                        '$seats seats, rotation $turns, $phase, ${player.slot}',
                  );
                  expect(group.left, greaterThanOrEqualTo(0));
                  expect(group.right, lessThanOrEqualTo(width + .001));

                  final trackingSources =
                      fixture.controller.session.commanderTrackingSources;
                  for (final source in trackingSources) {
                    final cell = find.byKey(
                      ValueKey('${player.id}-ledger-source-${source.id}'),
                    );
                    expect(cell, findsOneWidget);
                    final cellRect = _localRect(tester, cell, stepperFinder);
                    expect(
                      ledgerRect.inflate(.001).contains(cellRect.center),
                      isTrue,
                    );
                  }
                }
                expect(tester.takeException(), isNull);
              }
            }
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
