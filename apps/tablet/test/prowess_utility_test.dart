import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/token_board_summary.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'support/control_finders.dart';

import 'support/table_fixture.dart';

TokenState get creature =>
    sampleToken(plusOne: 2, minusOne: 1, counters: {'+1/+0': 1, '+0/+1': 3});

void main() {
  test(
    'Prowess is local derived stats, persisted once, never copied into tokens',
    () async {
      final original = creature;
      final f = TableFixture(stateWithTokens([original]));
      await f.initialize();
      addTearDown(f.dispose);
      final player = f.playerId;
      final opponent = f.controller.session.players.last.id;
      final snapshot = cloneJson(original.toJson());
      await f.board.addUtility(player, UtilityState.prowessKind);
      final id = f.player.utilities.last.id;
      final utility = f.player.utilities.last;
      expect(utility.displayedArtworkUrl, UtilityState.prowessArtworkUrl);
      expect(
        utility.configuration['artworkOptions'].single['artist'],
        'Borja Pindado',
      );
      expect(f.player.prowessBonus, 0);
      await f.board.setUtility(player, id, value: 3);
      expect(
        f.token('source').effectivePowerToughness(f.player.prowessBonus),
        '6/8',
      );
      expect(f.token('source').toJson(), snapshot);
      expect(
        original.effectivePowerToughness(
          f.controller.player(opponent).prowessBonus,
        ),
        '3/5',
      );
      final noncreature = sampleToken(pt: '2/3', type: 'Artifact — Vehicle');
      expect(noncreature.effectivePowerToughness(f.player.prowessBonus), '2/3');
      final artifactCreature = sampleToken(
        pt: '*/1',
        type: 'Token Artifact Creature — Otter',
      );
      expect(
        artifactCreature.effectivePowerToughness(f.player.prowessBonus),
        '*+3/4',
      );
      expect(artifactCreature.effectivePower(f.player.prowessBonus), isNull);
      await f.board.copyToken(player, 'source');
      final copy = f.player.tokens.last;
      expect(copy.pt, '1/1');
      expect(copy.plusOneCounters, 0);
      expect(copy.effectivePowerToughness(f.player.prowessBonus), '4/4');
      await f.board.setUtility(player, id, visible: false);
      expect(f.player.prowessBonus, 3);
      await f.board.addUtility(player, UtilityState.prowessKind);
      expect(
        f.player.utilities
            .where((u) => u.kind == UtilityState.prowessKind)
            .single
            .id,
        id,
      );
      expect(f.player.prowessBonus, 3);
      final restored = TabletState.fromJson(
        jsonMap(jsonDecode(f.repository.encoded)),
      );
      expect(restored.session.player(player).prowessBonus, 3);
      await f.board.adjustUtility(player, id, -99);
      expect(f.player.prowessBonus, 0);
      expect(
        f.token('source').effectivePowerToughness(f.player.prowessBonus),
        '3/5',
      );
      expect(await f.controller.undo(), isTrue);
      expect(f.player.prowessBonus, 3);
      await f.board.removeUtility(player, id);
      expect(f.player.prowessBonus, 0);
    },
  );

  test(
    'keep-board reset clears Prowess; archive restore reinstates it',
    () async {
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      await f.board.addUtility(f.playerId, UtilityState.prowessKind);
      final id = f.player.utilities.last.id;
      await f.board.setUtility(f.playerId, id, value: 4, visible: false);
      expect(await f.controller.resetGame(keepBoard: true), isTrue);
      expect(f.player.prowessBonus, 0);
      expect(
        f.player.utilities.singleWhere((u) => u.id == id).visible,
        isFalse,
      );
      expect(
        await f.controller.restoreArchive(f.controller.state.archives.last.id),
        isTrue,
      );
      expect(f.player.prowessBonus, 4);
    },
  );

  testWidgets('utility viewer stepper updates real token card and summary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = TableFixture(stateWithTokens([creature]));
    await f.initialize();
    f.catalog.loaded = true;
    addTearDown(f.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: f.controller,
            builder: (context, _) => Column(
              children: [
                TextButton(
                  onPressed: () => showTableWorkspace(
                    context,
                    f.controller,
                    catalog: f.catalog,
                    initialPage: WorkspacePage.utilities,
                    seatId: f.playerId,
                  ),
                  child: const Text('Open utility viewer'),
                ),
                SizedBox(
                  width: 350,
                  height: 200,
                  child: TabletTokenCard(
                    token: f.token('source'),
                    player: f.player,
                    board: f.board,
                    playerName: 'Player 1',
                    quarterTurns: 0,
                    expanded: false,
                    onExpand: () {},
                    onOpenDetailed: (_) {},
                    onInputLock: (_) {},
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: TokenBoardSummary(player: f.player),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('3/5'), findsOneWidget);
    await tester.tap(find.text('Open utility viewer'));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('utility-picker-search'));
    tester.widget<PlayerField>(search).controller.text = 'Prowess';
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('utility-open-prowess'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(f.player.prowessBonus, 0);
    final increase = byControlLabel('Increase Value');
    await tester.ensureVisible(increase);
    await tester.tap(increase);
    await tester.pumpAndSettle();
    expect(f.player.prowessBonus, 1);
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
    expect(find.text('4/6'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
