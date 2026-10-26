import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/board_service.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';

import 'support/table_fixture.dart';

class _ObservedRepository extends MemoryTableRepository {
  _ObservedRepository(super.state);
  int saves = 0;
  Completer<void>? pause;

  @override
  Future<void> save(TabletState state) async {
    saves++;
    if (pause case final pending?) await pending.future;
    await super.save(state);
  }
}

TabletState _populatedTable(int count) {
  final state = TabletState.initial();
  state.session.players = state.session.players.take(count).toList();
  for (final player in state.session.players) {
    final prefix = player.id;
    player.tokens = [
      sampleToken(id: '$prefix-creature', plusOne: 2),
      sampleToken(
        id: '$prefix-food',
        name: 'Food',
        pt: '',
        type: 'Artifact — Food',
        tapped: 0,
        sick: 0,
      ),
      sampleToken(
        id: '$prefix-emblem',
        name: 'Emblem',
        pt: '',
        type: 'Emblem',
        tapped: 0,
        sick: 0,
      ),
    ];
    player.life = 31;
    player.counters['energy'] = 3;
    player.mana['G'] = 4;
    player.citysBlessing = true;
    player.rules.add(
      ModifierSource(
        id: '$prefix-rule',
        ownerPlayerId: player.id,
        definitionId: 'doubling_season',
        name: 'Doubling Season',
        count: 1,
      ),
    );
  }
  state.session.dayNight = 'night';
  state.session.monarchPlayerId = state.session.players.last.id;
  state.archives.add(
    GameArchive(
      id: 'archive',
      label: 'Previous game',
      savedAt: DateTime.utc(2026, 10, 1),
      session: state.session.copy(),
    ),
  );
  return state;
}

Map<String, dynamic> _withoutGeneration(PlayerState player) =>
    player.toJson()..remove('generation');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final count in [2, 3, 4]) {
    for (final action in ['wipe_creatures', 'wipe_all']) {
      test(
        '$action for $count active seats saves once and undoes once',
        () async {
          final initial = _populatedTable(count);
          final repository = _ObservedRepository(initial);
          final controller = TableController(repository: repository);
          final catalog = TabletCatalog(controller);
          final board = BoardService(controller, catalog);
          addTearDown(catalog.dispose);
          addTearDown(controller.dispose);
          await controller.initialize();
          final before = controller.state.copy();
          final scopes = {
            for (final player in controller.session.players)
              player.id: board.scope(player.id),
          };

          await board.wipeEveryone(action);

          expect(repository.saves, 1);
          expect(controller.session.history, hasLength(1));
          final entry = controller.session.history.single;
          expect(entry.playerId, isNull);
          expect(entry.label, startsWith('Everyone:'));
          expect(entry.affectedPlayerIds.toSet(), scopes.keys.toSet());
          expect(entry.commands, hasLength(1));
          expect(
            entry.commands.single.tokenChanges.map((c) => c.playerId).toSet(),
            scopes.keys.toSet(),
          );
          for (final player in controller.session.players) {
            expect(
              player.tokens.map((t) => t.name),
              action == 'wipe_all' ? isEmpty : ['Food', 'Emblem'],
            );
            final previous = before.session.player(player.id);
            expect(player.generation, previous.generation + 1);
            expect(
              player.toJson()
                ..remove('tokens')
                ..remove('generation'),
              previous.toJson()
                ..remove('tokens')
                ..remove('generation'),
            );
            await expectLater(
              board.editToken(
                player.id,
                '${player.id}-food',
                name: 'Stale',
                captured: scopes[player.id],
              ),
              throwsStateError,
            );
          }
          expect(
            controller.state.profiles.map((p) => p.toJson()).toList(),
            before.profiles.map((p) => p.toJson()).toList(),
          );
          expect(
            controller.state.archives.map((a) => a.toJson()).toList(),
            before.archives.map((a) => a.toJson()).toList(),
          );
          expect(controller.session.dayNight, 'night');
          expect(
            controller.session.monarchPlayerId,
            before.session.monarchPlayerId,
          );

          // Reopen from the acknowledged aggregate, then restore all affected
          // boards with one Undo rather than one per seat.
          final reopened = TableController(repository: repository);
          addTearDown(reopened.dispose);
          await reopened.initialize();
          expect(await reopened.undo(), isTrue);
          expect(reopened.canUndo, isFalse);
          for (final player in reopened.session.players) {
            expect(
              _withoutGeneration(player),
              _withoutGeneration(before.session.player(player.id)),
            );
          }
        },
      );
    }
  }

  test(
    'empty/non-creature boards retain generations and stay out of affected seats',
    () async {
      final state = _populatedTable(4);
      state.session.players[1].tokens.clear();
      state.session.players[2].tokens.removeWhere((t) => t.pt.isNotEmpty);
      state.session.players[3].tokens.clear();
      final f = TableFixture(state);
      addTearDown(f.dispose);
      await f.initialize();
      final previous = f.controller.session.players
          .map((p) => p.copy())
          .toList();

      await f.board.wipeEveryone('wipe_creatures');

      expect(f.controller.session.history.single.affectedPlayerIds, [
        f.playerId,
      ]);
      for (final player in previous.skip(1)) {
        expect(f.controller.player(player.id).toJson(), player.toJson());
      }
    },
  );

  test(
    'empty table wipe records no undo and does not invalidate editors',
    () async {
      final f = TableFixture();
      addTearDown(f.dispose);
      await f.initialize();
      final before = f.controller.session.players
          .map((p) => p.toJson())
          .toList();
      await f.board.wipeEveryone('wipe_all');
      expect(f.controller.session.history, isEmpty);
      expect(
        f.controller.session.players.map((p) => p.toJson()).toList(),
        before,
      );
    },
  );

  test(
    'failed everyone save leaves every board and stored history unchanged',
    () async {
      final f = TableFixture(_populatedTable(4));
      addTearDown(f.dispose);
      await f.initialize();
      final before = f.controller.state.toJson();
      final encoded = f.repository.encoded;
      f.repository.failSave = true;

      await expectLater(f.board.wipeEveryone('wipe_all'), throwsStateError);

      expect(f.controller.state.toJson(), before);
      expect(f.repository.encoded, encoded);
    },
  );

  test(
    'everyone wipe never publishes partially while storage is pending',
    () async {
      final repository = _ObservedRepository(_populatedTable(3));
      final controller = TableController(repository: repository);
      final catalog = TabletCatalog(controller);
      final board = BoardService(controller, catalog);
      addTearDown(catalog.dispose);
      addTearDown(controller.dispose);
      await controller.initialize();
      final before = controller.state.toJson();
      repository.pause = Completer<void>();

      final pending = board.wipeEveryone('wipe_all');
      await Future<void>.delayed(Duration.zero);
      expect(repository.saves, 1);
      expect(controller.state.toJson(), before);
      repository.pause!.complete();
      await pending;
      expect(controller.session.players.every((p) => p.tokens.isEmpty), isTrue);
      expect(controller.session.history, hasLength(1));
    },
  );

  test(
    'everyone wipe rejects stale queued boards and unrelated bulk actions',
    () async {
      final f = TableFixture(_populatedTable(2));
      addTearDown(f.dispose);
      await f.initialize();
      final first = f.board.bulk(f.playerId, 'wipe_creatures');
      final stale = expectLater(
        f.board.wipeEveryone('wipe_all'),
        throwsStateError,
      );
      await first;
      await stale;
      expect(f.controller.session.players[1].tokens, hasLength(3));
      expect(f.controller.session.history, hasLength(1));
      await expectLater(f.board.wipeEveryone('untap'), throwsArgumentError);
      expect(f.controller.session.history, hasLength(1));
    },
  );
}
