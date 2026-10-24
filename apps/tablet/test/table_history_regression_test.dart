import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture f;

  setUp(() async {
    f = TableFixture(stateWithTokens([sampleToken(plusOne: 1)]));
    await f.initialize();
  });
  tearDown(() => f.dispose());

  test('mana 2 minus 10 records minus 2, persists, and undoes to 2', () async {
    await f.controller.adjustMana(f.playerId, 'W', 2);
    f.controller.settleHistoryGroup();
    await f.controller.adjustMana(f.playerId, 'W', -10);
    expect(f.player.mana['W'], 0);
    expect(f.controller.session.history.last.summary, 'W mana -2');
    expect(f.controller.session.history.last.commands.single.delta, -2);

    final reopened = TableController(repository: f.repository);
    await reopened.initialize();
    expect(reopened.session.history.last.summary, 'W mana -2');
    expect(await reopened.undo(), isTrue);
    expect(reopened.player(f.playerId).mana['W'], 2);
    reopened.dispose();
  });

  test(
    'queued spending uses each committed value and groups actual deltas',
    () async {
      await f.controller.adjustMana(f.playerId, 'W', 2);
      final outcomes = await Future.wait([
        f.controller.adjustMana(f.playerId, 'W', -1),
        f.controller.adjustMana(f.playerId, 'W', -10),
        f.controller.adjustMana(f.playerId, 'W', -10),
      ]);
      expect(outcomes, everyElement(isTrue));
      expect(f.player.mana['W'], 0);
      final spending = f.controller.session.history.last;
      expect(spending.commands.map((command) => command.delta), [-1, -1]);
      expect(spending.totalDelta, -2);
      expect(spending.summary, contains('-2 total'));
      expect(await f.controller.undo(), isTrue);
      expect(f.player.mana['W'], 2);
    },
  );

  test(
    'table wipe records friendly action, target seat, actual token delta and undo',
    () async {
      final otherSeat = f.controller.session.players[1].toJson();
      final playerId = f.playerId;
      final before = f.player.toJson();
      await f.board.bulk(playerId, 'wipe_creatures', gameOrigin: true);
      final entry = f.controller.session.history.last;
      expect(entry.playerId, isNull);
      expect(entry.label.toLowerCase(), contains('wipe creature'));
      expect(entry.label, isNot(contains('_')));
      expect(entry.affectedPlayerIds, [playerId]);
      expect(entry.commands.single.tokenChanges.single.playerId, playerId);
      expect(entry.tokenSummary, 'Saproling -3');
      expect(f.controller.session.players[1].toJson(), otherSeat);
      expect(await f.controller.undo(), isTrue);
      final restored = f.player.toJson()..remove('generation');
      expect(restored, Map<String, dynamic>.from(before)..remove('generation'));
    },
  );

  test(
    'counter and commander clamp labels report actual loss with coupled life once',
    () async {
      await f.controller.adjustPlayerCounter(f.playerId, 'poison', 2);
      await f.controller.adjustPlayerCounter(f.playerId, 'poison', -10);
      expect(f.controller.session.history.last.summary, 'poison -2');
      await f.controller.addCommander(f.playerId, 'Partner one');
      await f.controller.addCommander(f.playerId, 'Partner two');
      final first = f.controller.session.commanders.first.id;
      final second = f.controller.session.commanders.last.id;
      await f.controller.adjustCommanderDamage(f.playerId, first, 2);
      await f.controller.adjustCommanderDamage(f.playerId, second, 3);
      expect(f.player.life, 35);
      await f.controller.adjustCommanderDamage(f.playerId, first, -10);
      expect(
        f.controller.session.history.last.summary,
        'Player 1: Partner one #1 damage -2',
      );
      expect(f.player.life, 37);
      expect(f.player.commanderDamage[second], 3);
      expect(await f.controller.undo(), isTrue);
      expect(f.player.life, 35);
      expect(f.player.commanderDamage[first], 2);
    },
  );

  test('failed save leaves live and persisted game unchanged', () async {
    final before = f.controller.state.toJson();
    final encoded = f.repository.encoded;
    f.repository.failSave = true;
    expect(await f.controller.adjustMana(f.playerId, 'W', 1), isFalse);
    expect(f.controller.state.toJson(), before);
    expect(f.repository.encoded, encoded);
    expect(f.controller.error, contains('Simulated storage failure'));
  });

  test(
    'keep-board reset is scoped, archived, and rejects stale queued editors',
    () async {
      final captured = f.board.scope(f.playerId);
      final oldSession = f.controller.session.id;
      final profileNames = f.controller.state.profiles
          .map((p) => p.name)
          .toList();
      await f.controller.adjustLife(f.playerId, -7);
      await f.controller.adjustMana(f.playerId, 'B', 3);
      expect(
        await f.controller.resetGame(
          keepBoard: true,
          playerCount: 3,
          emptySlot: 0,
        ),
        isTrue,
      );
      expect(f.controller.session.id, isNot(oldSession));
      expect(f.controller.session.players.map((p) => p.slot), [1, 2, 3]);
      expect(f.player.tokens.single.amount, 0);
      expect(f.player.tokens.single.plusOneCounters, 0);
      expect(f.player.life, 40);
      expect(f.player.mana.values, everyElement(0));
      expect(f.controller.session.history, isEmpty);
      expect(f.controller.state.archives.single.session.id, oldSession);
      expect(f.controller.state.profiles.map((p) => p.name), profileNames);
      final beforeStale = f.controller.state.toJson();
      await expectLater(
        f.board.editToken(
          captured.playerId,
          'source',
          name: 'Old draft',
          captured: captured,
        ),
        throwsStateError,
      );
      expect(f.controller.state.toJson(), beforeStale);
    },
  );

  test(
    'restore saves outgoing game and preserves permanent appearance and undo timeline',
    () async {
      final originalPlayer = f.playerId;
      await f.controller.adjustLife(originalPlayer, -7);
      final originalSession = f.controller.session.id;
      await f.controller.resetGame(keepBoard: false, playerCount: 2);
      final resetSession = f.controller.session.id;
      expect(
        f.controller.session.players.every((p) => p.tokens.isEmpty),
        isTrue,
      );
      await f.controller.modifyLibrary(
        (state) => state.profiles.first.name = 'Current name',
      );
      final archiveId = f.controller.state.archives.first.id;
      expect(await f.controller.restoreArchive(archiveId), isTrue);
      expect(f.controller.session.id, originalSession);
      expect(f.controller.player(originalPlayer).life, 33);
      expect(f.controller.state.archives.last.session.id, resetSession);
      expect(f.controller.state.profiles.first.name, 'Current name');
      expect(await f.controller.undo(), isTrue);
      expect(f.controller.player(originalPlayer).life, 40);
      expect(f.controller.state.profiles.first.name, 'Current name');
    },
  );

  test(
    'keep-board reactivates fresh default utilities without resurrecting removed setup',
    () async {
      await f.controller.modifyLibrary((state) {
        final remaining = state.session.players.first;
        remaining.utilities = remaining.utilities.reversed.toList();
        remaining.utilities.last
          ..visible = false
          ..value = 7;
        final removed = state.session.players[2];
        removed.tokens = [sampleToken(id: 'removed-token')];
        removed.mana['W'] = 9;
        removed.utilities = [
          UtilityState(
            id: 'removed-storm',
            kind: 'storm_count',
            name: 'Old storm',
            visible: false,
            value: 9,
          ),
          UtilityState(
            id: 'removed-custom',
            kind: 'cathars_crusade',
            name: 'Old setup',
            value: 8,
          ),
        ];
        state.profiles[2].name = 'Returning player';
      });
      final retainedIds = f.player.utilities.map((u) => u.id).toList();
      await f.controller.resetGame(keepBoard: true, playerCount: 2);
      await f.controller.resetGame(keepBoard: true, playerCount: 3);

      final returning = f.controller.session.players[2];
      expect(returning.tokens, isEmpty);
      expect(returning.mana.values, everyElement(0));
      expect(returning.utilities.map((u) => u.kind), [
        'storm_count',
        'mana_pool',
      ]);
      expect(returning.utilities.map((u) => u.visible), everyElement(isTrue));
      expect(returning.utilities.map((u) => u.value), everyElement(0));
      expect(returning.utilities.map((u) => u.isActive), everyElement(isFalse));
      expect(
        returning.utilities.map((u) => u.id),
        isNot(contains('removed-storm')),
      );
      expect(
        returning.utilities.map((u) => u.id),
        isNot(contains('removed-custom')),
      );
      expect(f.controller.profile(returning.seatId).name, 'Returning player');
      expect(f.player.utilities.map((u) => u.id), retainedIds);
      expect(f.player.utilities.map((u) => u.kind), [
        'mana_pool',
        'storm_count',
      ]);
      expect(f.player.utilities.last.visible, isFalse);
      expect(f.player.utilities.last.value, 0);

      // Complete reset also restores fresh default tools.
      await f.controller.resetGame(keepBoard: false, playerCount: 3);
      expect(
        f.controller.session.players.every(
          (p) =>
              p.utilities.map((u) => u.kind).join(',') ==
              'storm_count,mana_pool',
        ),
        isTrue,
      );
    },
  );

  test(
    'ten archives are separate from active state and oldest restore is safe during eviction',
    () async {
      final originalSession = f.controller.session.id;
      for (var i = 0; i < 10; i++) {
        expect(await f.controller.resetGame(keepBoard: false), isTrue);
      }
      expect(f.controller.state.archives.length, 10);
      final oldest = f.controller.state.archives.first;
      expect(oldest.session.id, originalSession);
      final outgoing = f.controller.session.id;
      expect(await f.controller.restoreArchive(oldest.id), isTrue);
      expect(f.controller.session.id, originalSession);
      expect(f.controller.state.archives.length, 10);
      expect(f.controller.state.archives.last.session.id, outgoing);
      expect(
        f.controller.state.archives.any((a) => a.id == oldest.id),
        isFalse,
      );
      expect(
        f.controller.state.archives.any(
          (a) => identical(a.session, f.controller.session),
        ),
        isFalse,
      );
    },
  );
}
