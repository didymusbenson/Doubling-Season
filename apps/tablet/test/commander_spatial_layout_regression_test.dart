import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/commander_ledger.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

void main() {
  Rect painted(WidgetTester tester, Finder finder) {
    final box = tester.renderObject<RenderBox>(finder);
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  void expectPhysicalPositions(
    WidgetTester tester,
    List<PlayerState> players,
    Finder Function(PlayerState) owner,
  ) {
    if (players.length == 2) {
      final bottom = painted(tester, owner(players.first));
      final top = painted(tester, owner(players.last));
      expect(top.center.dy, lessThan(bottom.center.dy));
      expect(top.center.dx, closeTo(bottom.center.dx, .01));
      return;
    }
    final center = players
        .map((p) => painted(tester, owner(p)))
        .reduce((a, b) => a.expandToInclude(b))
        .center;
    for (final p in players) {
      final point = painted(tester, owner(p)).center;
      expect(
        point.dx < center.dx,
        p.slot == 0 || p.slot == 1,
        reason: 'slot ${p.slot} must retain its physical table column',
      );
      expect(
        point.dy < center.dy,
        p.slot == 1 || p.slot == 2,
        reason: 'slot ${p.slot} must retain its physical table row',
      );
    }
  }

  for (final seats in [2, 3, 4]) {
    for (final empty in seats == 3 ? [0, 1, 2, 3] : [-1]) {
      for (final size in const [Size(1133, 744), Size(744, 1133)]) {
        final initial = TabletState.initial();
        if (seats == 2) {
          initial.session.players = initial.session.players.take(2).toList();
        } else if (seats == 3) {
          initial.session.players.removeWhere((p) => p.slot == empty);
        }
        for (var initiating = 0; initiating < seats; initiating++) {
          testWidgets(
            '$seats seats empty $empty $size initiating $initiating keeps mini and popup physical seats',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = size;
              addTearDown(tester.view.reset);
              final state = TabletState.fromJson(initial.toJson());
              final partnerOwner = state.session.players.last;
              state.session.commanders.addAll([
                CommanderSource(
                  id: 'partner-a',
                  ownerPlayerId: partnerOwner.id,
                  name: 'Partner A',
                ),
                CommanderSource(
                  id: 'partner-b',
                  ownerPlayerId: partnerOwner.id,
                  name: 'Partner B',
                ),
              ]);
              final fixture = TableFixture(state);
              await fixture.initialize();
              fixture.catalog.loaded = true;
              final player = fixture.controller.session.players[initiating];
              final players = fixture.controller.session.players;
              final turns = CommanderSeatLayout.turnsForPlayer(players, player);
              addTearDown(() async {
                await tester.pumpWidget(const SizedBox());
                await tester.pumpAndSettle();
                fixture.dispose();
              });
              await tester.pumpWidget(
                MaterialApp(
                  theme: tableTheme(Brightness.dark),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: RotatedBox(
                          quarterTurns: turns,
                          child: SizedBox(
                            width: 180,
                            child: CommanderLedger(
                              controller: fixture.controller,
                              recipient: player,
                              onOpen: () => showTableWorkspace(
                                context,
                                fixture.controller,
                                catalog: fixture.catalog,
                                seatId: player.seatId,
                                quarterTurns: turns,
                                initialPage: WorkspacePage.commanderDamage,
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
              expectPhysicalPositions(
                tester,
                players,
                (owner) => find.byKey(
                  ValueKey('${player.id}-ledger-owner-${owner.id}'),
                ),
              );
              final miniOwner = painted(
                tester,
                find.byKey(
                  ValueKey('${player.id}-ledger-owner-${partnerOwner.id}'),
                ),
              );
              final partnerA = painted(
                tester,
                find.byKey(ValueKey('${player.id}-ledger-source-partner-a')),
              );
              final partnerB = painted(
                tester,
                find.byKey(ValueKey('${player.id}-ledger-source-partner-b')),
              );
              expect(miniOwner.contains(partnerA.center), isTrue);
              expect(miniOwner.contains(partnerB.center), isTrue);
              expect(partnerA.overlaps(partnerB), isFalse);
              await tester.tap(find.byType(CommanderLedger));
              await tester.pumpAndSettle();
              expectPhysicalPositions(
                tester,
                players,
                (owner) => find.byKey(ValueKey('commander-owner-${owner.id}')),
              );
              final expandedOwner = painted(
                tester,
                find.byKey(ValueKey('commander-owner-${partnerOwner.id}')),
              );
              for (final id in ['partner-a', 'partner-b']) {
                final source = painted(
                  tester,
                  find.byKey(ValueKey('commander-tracker-$id')),
                );
                expect(expandedOwner.contains(source.center), isTrue);
              }
              // Opening and closing never changes life or writes setup/history.
              expect(player.life, 40);
              expect(fixture.controller.session.history, isEmpty);
              final selfSource = fixture
                  .controller
                  .session
                  .commanderTrackingSources
                  .firstWhere((s) => s.ownerPlayerId == player.id);
              final selfBox = tester.renderObject<RenderBox>(
                find.byKey(ValueKey('commander-tracker-${selfSource.id}')),
              );
              await tester.tapAt(
                selfBox.localToGlobal(Offset(selfBox.size.width * .75, 35)),
              );
              await tester.pumpAndSettle();
              expect(fixture.controller.player(player.id).life, 39);
              expect(
                fixture.controller
                    .player(player.id)
                    .commanderDamage[selfSource.id],
                1,
              );
              expect(fixture.controller.session.history.length, 1);
              expect(await fixture.controller.undo(), isTrue);
              await tester.pumpAndSettle();
              expect(fixture.controller.player(player.id).life, 40);
              expect(
                fixture.controller
                        .player(player.id)
                        .commanderDamage[selfSource.id] ??
                    0,
                0,
              );
              await tester.tap(find.byTooltip('Close workspace'));
              await tester.pumpAndSettle();
              expect(player.life, 40);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  testWidgets(
    'quarter-turn layouts transform positions before parent rotation',
    (tester) async {
      final players = TabletState.initial().session.players;
      for (var turns = 0; turns < 4; turns++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RotatedBox(
                quarterTurns: turns,
                child: SizedBox(
                  width: 200,
                  child: CommanderSeatLayout(
                    players: players,
                    quarterTurns: turns,
                    rowHeight: 40,
                    ownerBuilder: (owner) => SizedBox(
                      key: ValueKey(owner.id),
                      width: double.infinity,
                      height: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expectPhysicalPositions(
          tester,
          players,
          (p) => find.byKey(ValueKey(p.id)),
        );
      }
    },
  );
}
