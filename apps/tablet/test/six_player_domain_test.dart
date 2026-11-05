import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/storage/table_repository.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture f;
  setUp(() async {
    f = TableFixture(stateWithTokens([sampleToken()]));
    await f.initialize();
  });
  tearDown(() => f.dispose());

  for (final count in [5, 6]) {
    test('$count players extends an old roster and survives reopen', () async {
      final existingProfiles = f.controller.state.profiles
          .map((p) => p.toJson())
          .toList();
      final oldSession = f.controller.session.toJson();
      expect(
        await f.controller.resetGame(keepBoard: true, playerCount: count),
        isTrue,
      );
      final state = f.controller.state;
      expect(state.profiles, hasLength(count));
      expect(state.profiles.take(4).map((p) => p.toJson()), existingProfiles);
      expect(state.profiles.map((p) => p.color).toSet(), hasLength(count));
      expect(
        state.session.players.map((p) => p.slot),
        List.generate(count, (i) => i),
      );
      expect(state.archives.single.session.toJson(), oldSession);
      expect(f.player.tokens.single.amount, 0);
      for (final player in state.session.players.skip(4)) {
        expect(player.life, 40);
        expect(player.tokens, isEmpty);
        expect(player.utilities.map((u) => u.kind), [
          'storm_count',
          'mana_pool',
        ]);
      }
      final rows = state.session.seatRows;
      expect(rows.first.map((p) => p!.slot), count == 5 ? [1, 2] : [1, 5, 2]);
      expect(rows.last.map((p) => p!.slot), [0, 4, 3]);
      for (final player in rows.first) {
        expect(state.session.quarterTurnsFor(player!), 2);
      }
      for (final player in rows.last) {
        expect(state.session.quarterTurnsFor(player!), 0);
      }
      await f.controller.flush();
      final reopened = TableController(repository: f.repository);
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.state.toJson(), state.toJson());
      validateTabletState(reopened.state);
    });
  }

  test(
    'six partners preserve coupled damage, history and archive undo',
    () async {
      expect(
        await f.controller.resetGame(keepBoard: false, playerCount: 6),
        isTrue,
      );
      final playerIds = f.controller.session.players.map((p) => p.id).toList();
      for (final id in playerIds) {
        expect(await f.controller.setHasPartner(id, true), isTrue);
      }
      final sources = f.controller.session.commanderTrackingSources;
      expect(sources, hasLength(12));
      final recipientId = playerIds.last;
      final source = sources.where((s) => s.ownerPlayerId == playerIds[4]).last;
      expect(
        await f.controller.adjustCommanderDamage(recipientId, source.id, 3),
        isTrue,
      );
      expect(f.controller.player(recipientId).life, 37);
      expect(f.controller.player(recipientId).commanderDamage[source.id], 3);
      expect(f.controller.player(playerIds[4]).life, 40);
      expect(await f.controller.setHasPartner(playerIds[4], false), isFalse);
      expect(f.controller.session.hasPartner(playerIds[4]), isTrue);
      final originalSession = f.controller.session.id;
      final originalProfiles = f.controller.state.profiles
          .map((p) => p.id)
          .toList();
      expect(
        await f.controller.resetGame(keepBoard: false, playerCount: 2),
        isTrue,
      );
      final archive = f.controller.state.archives.last;
      expect(archive.session.id, originalSession);
      expect(await f.controller.restoreArchive(archive.id), isTrue);
      expect(f.controller.state.profiles.map((p) => p.id), originalProfiles);
      expect(f.controller.session.commanderTrackingSources, hasLength(12));
      expect(f.controller.player(recipientId).life, 37);
      expect(await f.controller.undo(), isTrue);
      expect(f.controller.player(recipientId).life, 40);
      expect(
        f.controller.player(recipientId).commanderDamage[source.id] ?? 0,
        0,
      );
      expect(await f.controller.setHasPartner(playerIds[4], false), isTrue);
      expect(f.controller.session.commanderTrackingSources, hasLength(11));
      validateTabletState(f.controller.state);
    },
  );

  test(
    'six to five to two to six preserves profiles, not removed live boards',
    () async {
      await f.controller.resetGame(keepBoard: false, playerCount: 6);
      final sixthSeatId = f.controller.session.players.last.seatId;
      await f.controller.modifyLibrary((state) {
        state.profiles.last.name = 'Returning sixth player';
        state.profiles.last.artworkUrl = 'file://saved-art';
        state.session.players.last.tokens = [sampleToken(id: 'sixth-token')];
      });
      final profiles = f.controller.state.profiles
          .map((p) => p.toJson())
          .toList();
      await f.controller.resetGame(keepBoard: true, playerCount: 5);
      expect(f.controller.session.players, hasLength(5));
      await f.controller.resetGame(keepBoard: true, playerCount: 2);
      expect(f.controller.session.seatRows.map((r) => r.single!.slot), [2, 0]);
      await f.controller.resetGame(keepBoard: true, playerCount: 6);
      expect(f.controller.state.profiles.map((p) => p.toJson()), profiles);
      final sixth = f.controller.session.players.last;
      expect(sixth.seatId, sixthSeatId);
      expect(sixth.tokens, isEmpty);
      expect(sixth.utilities.map((u) => u.kind), ['storm_count', 'mana_pool']);
      expect(f.controller.profile(sixth.seatId).name, 'Returning sixth player');
    },
  );

  test(
    'failed roster expansion is atomic and does not archive or add profiles',
    () async {
      final before = f.controller.state.toJson();
      final encoded = f.repository.encoded;
      f.repository.failSave = true;
      expect(
        await f.controller.resetGame(keepBoard: false, playerCount: 6),
        isFalse,
      );
      expect(f.controller.state.toJson(), before);
      expect(f.repository.encoded, encoded);
      f.repository.failSave = false;
      expect(
        await f.controller.resetGame(keepBoard: false, playerCount: 6),
        isTrue,
      );
      expect(f.controller.state.profiles, hasLength(6));
      expect(f.controller.state.archives, hasLength(1));
    },
  );

  test(
    'invalid roster counts and incompatible slots remain rejected',
    () async {
      for (final count in [1, 7]) {
        final before = f.controller.state.toJson();
        expect(
          await f.controller.resetGame(keepBoard: false, playerCount: count),
          isFalse,
        );
        expect(f.controller.state.toJson(), before);
      }
      for (final count in [4, 5, 6]) {
        await f.controller.resetGame(keepBoard: false, playerCount: count);
        final invalid = f.controller.state.copy();
        invalid.session.players.last.slot = count == 4 ? 4 : count;
        expect(() => validateTabletState(invalid), throwsFormatException);
      }
    },
  );

  test('legacy empty-corner layouts retain every orientation', () async {
    for (var empty = 0; empty < 4; empty++) {
      await f.controller.resetGame(
        keepBoard: false,
        playerCount: 3,
        emptySlot: empty,
      );
      expect(f.controller.session.players.map((p) => p.slot), [
        for (var slot = 0; slot < 4; slot++)
          if (slot != empty) slot,
      ]);
      final rows = f.controller.session.seatRows;
      expect(rows.map((row) => row.length), [2, 2]);
      expect(rows.expand((row) => row).where((p) => p == null), hasLength(1));
    }
  });
}
