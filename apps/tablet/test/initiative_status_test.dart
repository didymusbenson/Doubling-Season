import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/board_service.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';

import 'support/table_fixture.dart';

class _DelayedRepository extends MemoryTableRepository {
  Completer<void>? gate;
  _DelayedRepository(super.state);

  @override
  Future<void> save(TabletState state) async {
    await gate?.future;
    await super.save(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture fixture;
  setUp(() async {
    fixture = TableFixture();
    await fixture.initialize();
  });
  tearDown(() => fixture.dispose());

  List<UtilityState> entries(PlayerState player) => player.utilities
      .where((utility) => BoardService.isInitiativeKind(utility.kind))
      .toList();
  List<String> holders() => fixture.controller.session.players
      .where((player) => fixture.board.hasInitiative(player.id))
      .map((player) => player.id)
      .toList();
  Map<String, dynamic> withoutActive(UtilityState utility) =>
      utility.toJson()..remove('isActive');

  test(
    'new game first claim creates one status without schema changes',
    () async {
      final before = fixture.player.utilities.map((u) => u.toJson()).toList();
      expect(holders(), isEmpty);
      await fixture.board.setInitiative(fixture.playerId);
      expect(holders(), [fixture.playerId]);
      final entry = entries(fixture.player).single;
      expect(entry.kind, 'initiative');
      expect(entry.name, 'The Initiative');
      expect(entry.isActive, isTrue);
      expect(fixture.board.isUtilityVisible(entry), isFalse);
      expect(
        fixture.controller.state.schemaVersion,
        TabletState.currentSchemaVersion,
      );
      expect(
        fixture.player.utilities.take(before.length).map((u) => u.toJson()),
        before,
      );
      expect(
        fixture.controller.session.history.single.label,
        'Claim initiative',
      );
      expect(await fixture.controller.undo(), isTrue);
      expect(entries(fixture.player), isEmpty);
      expect(fixture.player.utilities.map((u) => u.toJson()).toList(), before);
    },
  );

  test(
    'claim transfers once and chronological undo restores both owners',
    () async {
      final first = fixture.playerId;
      final second = fixture.controller.session.players[1].id;
      await fixture.board.setInitiative(first);
      final originalId = entries(fixture.player).single.id;
      await fixture.board.setInitiative(second);
      expect(holders(), [second]);
      expect(entries(fixture.player).single.id, originalId);
      expect(fixture.controller.session.history.length, 2);
      expect(
        fixture.controller.session.history.last.affectedPlayerIds,
        containsAll([first, second]),
      );
      expect(await fixture.controller.undo(), isTrue);
      expect(holders(), [first]);
      expect(entries(fixture.controller.player(second)), isEmpty);
      expect(await fixture.controller.undo(), isTrue);
      expect(holders(), isEmpty);
    },
  );

  test(
    'clear preserves identity and repeated claim or clear adds no history',
    () async {
      await fixture.board.setInitiative(fixture.playerId);
      final original = entries(fixture.player).single.toJson();
      await fixture.board.setInitiative(fixture.playerId);
      expect(fixture.controller.session.history.length, 1);
      await fixture.board.setInitiative(null);
      expect(holders(), isEmpty);
      expect(entries(fixture.player).single.toJson(), {
        ...original,
        'isActive': false,
      });
      final historyCount = fixture.controller.session.history.length;
      await fixture.board.setInitiative(null);
      expect(fixture.controller.session.history.length, historyCount);
      expect(await fixture.controller.undo(), isTrue);
      expect(holders(), [fixture.playerId]);
    },
  );

  test(
    'reload retains status and undo restores transferred ownership',
    () async {
      final first = fixture.playerId;
      final second = fixture.controller.session.players[1].id;
      await fixture.board.setInitiative(first);
      await fixture.board.setInitiative(second);
      final reopened = TableController(repository: fixture.repository);
      await reopened.initialize();
      final catalog = TabletCatalog(reopened);
      final board = BoardService(reopened, catalog);
      addTearDown(catalog.dispose);
      addTearDown(reopened.dispose);
      expect(board.hasInitiative(second), isTrue);
      expect(board.hasInitiative(first), isFalse);
      expect(await reopened.undo(), isTrue);
      expect(board.hasInitiative(first), isTrue);
      expect(board.hasInitiative(second), isFalse);
      expect(
        (await fixture.repository.open()).state.toJson(),
        reopened.state.toJson(),
      );
    },
  );

  test(
    'failed claim, transfer and clear retain exact saved aggregate',
    () async {
      Future<void> fail(String? target) async {
        final before = fixture.controller.state.toJson();
        final encoded = fixture.repository.encoded;
        fixture.repository.failSave = true;
        await expectLater(
          fixture.board.setInitiative(target),
          throwsStateError,
        );
        expect(fixture.controller.state.toJson(), before);
        expect(fixture.repository.encoded, encoded);
        fixture.repository.failSave = false;
      }

      await fail(fixture.playerId);
      await fixture.board.setInitiative(fixture.playerId);
      await fail(fixture.controller.session.players[1].id);
      await fail(null);
      await fixture.board.setInitiative(null);
      expect(holders(), isEmpty);
    },
  );

  test(
    'hidden legacy and alias entries preserve metadata while transferring',
    () async {
      final first = fixture.playerId;
      final second = fixture.controller.session.players[1].id;
      await fixture.controller.updateState('Fixture', (state) {
        for (var i = 0; i < 2; i++) {
          state.session.players[i].utilities.add(
            UtilityState(
              id: 'legacy-$i',
              kind: i == 0 ? 'initiative' : 'the_initiative',
              name: 'Saved title $i',
              description: 'Saved description $i',
              value: 9 + i,
              defaultValue: 4 + i,
              colors: 'UG',
              visible: false,
              isActive: i == 0,
              artworkUrl: 'https://example.test/art-$i.png',
              configuration: {
                'type': 'toggle',
                'custom': ['retained', i],
              },
            ),
          );
        }
      });
      final before = {
        for (final p in fixture.controller.session.players.take(2))
          p.id: withoutActive(entries(p).single),
      };
      expect(holders(), [first]);
      await fixture.board.setInitiative(second);
      expect(holders(), [second]);
      for (final p in fixture.controller.session.players.take(2)) {
        expect(withoutActive(entries(p).single), before[p.id]);
        expect(entries(p).single.visible, isFalse);
        expect(fixture.board.isUtilityVisible(entries(p).single), isFalse);
      }
      expect(await fixture.controller.undo(), isTrue);
      expect(holders(), [first]);
      await fixture.board.setUtility(second, 'legacy-1', visible: true);
      expect(
        holders(),
        [first],
        reason:
            'Restoring a hidden entry never changes its saved active state.',
      );
      expect(entries(fixture.controller.player(second)).single.id, 'legacy-1');
      expect(
        fixture.board.isUtilityVisible(
          entries(fixture.controller.player(second)).single,
        ),
        isFalse,
      );
    },
  );

  test(
    'duplicate legacy states are not silently migrated; explicit claim resolves them',
    () async {
      await fixture.controller.updateState('Fixture', (state) {
        for (final p in state.session.players.take(2)) {
          p.utilities.addAll([
            UtilityState(id: '${p.id}-a', kind: 'initiative', isActive: true),
            UtilityState(
              id: '${p.id}-b',
              kind: 'the_initiative',
              isActive: true,
            ),
          ]);
        }
      });
      final original = fixture.controller.session.players
          .map((p) => p.toJson())
          .toList();
      expect(holders().length, 2);
      expect(
        fixture.controller.session.players.map((p) => p.toJson()).toList(),
        original,
      );
      await fixture.board.setInitiative(fixture.playerId);
      expect(holders(), [fixture.playerId]);
      expect(
        fixture.controller.session.players
            .expand(entries)
            .where((u) => u.isActive)
            .length,
        1,
      );
      expect(entries(fixture.player).first.isActive, isTrue);
      expect(await fixture.controller.undo(), isTrue);
      for (var index = 0; index < original.length; index++) {
        final restored = fixture.controller.session.players[index].toJson();
        // Undo invalidates stale per-player command scopes by advancing the
        // generation; all gameplay data and legacy payloads must restore.
        expect(
          restored['generation'],
          index < 2
              ? greaterThan(original[index]['generation'] as int)
              : original[index]['generation'],
        );
        restored['generation'] = original[index]['generation'];
        expect(restored, original[index]);
      }
    },
  );

  test(
    'legacy activation commands share one-holder invariant without changing hide behavior',
    () async {
      final first = fixture.playerId;
      final second = fixture.controller.session.players[1].id;
      await fixture.board.setInitiative(first);
      await fixture.board.setInitiative(second);
      final firstId = entries(fixture.controller.player(first)).single.id;
      final secondId = entries(fixture.controller.player(second)).single.id;
      await fixture.board.setUtility(first, firstId, isActive: true);
      expect(holders(), [first]);
      await fixture.board.toggleUtility(second, secondId);
      expect(holders(), [second]);
      await fixture.board.setUtility(first, firstId, isActive: false);
      expect(
        holders(),
        [second],
        reason: 'An already-inactive legacy entry cannot clear another owner.',
      );
      await fixture.board.setUtility(second, secondId, visible: false);
      expect(holders(), [second]);
      await fixture.board.toggleUtility(second, secondId);
      expect(holders(), isEmpty);
      await fixture.board.setUtility(first, firstId, isActive: true);
      await fixture.board.setUtility(first, firstId, isActive: false);
      expect(holders(), isEmpty);
    },
  );

  for (final keepBoard in [false, true]) {
    test(
      'reset keepBoard=$keepBoard clears status; archive restores ownership and undo',
      () async {
        final first = fixture.playerId;
        final fourth = fixture.controller.session.players.last.id;
        await fixture.board.setInitiative(first);
        await fixture.board.setInitiative(fourth);
        final originalIds = entries(fixture.player).map((u) => u.id).toList();
        final oldProfiles = fixture.controller.state.profiles
            .map((p) => p.toJson())
            .toList();
        expect(
          await fixture.controller.resetGame(
            keepBoard: keepBoard,
            playerCount: 2,
          ),
          isTrue,
        );
        expect(holders(), isEmpty);
        expect(
          fixture.controller.state.profiles.map((p) => p.toJson()).toList(),
          oldProfiles,
        );
        expect(
          entries(fixture.player).map((u) => u.id).toList(),
          keepBoard ? originalIds : isEmpty,
        );
        final archive = fixture.controller.state.archives.single;
        expect(
          archive.session.players.last.utilities
              .where((u) => BoardService.isInitiativeKind(u.kind))
              .single
              .isActive,
          isTrue,
        );
        await expectLater(
          fixture.board.setInitiative(fourth),
          throwsStateError,
        );
        await fixture.board.setInitiative(fixture.playerId);
        expect(holders(), [fixture.playerId]);
        expect(
          archive.session.players.last.utilities
              .where((u) => BoardService.isInitiativeKind(u.kind))
              .single
              .isActive,
          isTrue,
        );
        expect(await fixture.controller.restoreArchive(archive.id), isTrue);
        expect(holders(), [fourth]);
        expect(await fixture.controller.undo(), isTrue);
        expect(holders(), [first]);
      },
    );
  }

  test(
    'newly active hidden seat never inherits an archived Initiative holder',
    () async {
      await fixture.board.setInitiative(
        fixture.controller.session.players.last.id,
      );
      await fixture.controller.resetGame(keepBoard: true, playerCount: 2);
      await fixture.board.setInitiative(fixture.playerId);
      await fixture.controller.resetGame(keepBoard: true, playerCount: 4);
      expect(holders(), isEmpty);
      expect(entries(fixture.controller.session.players.last), isEmpty);
    },
  );

  test(
    'pending transfer stays unpublished; rapid claims serialize durably',
    () async {
      final repository = _DelayedRepository(TabletState.initial());
      final controller = TableController(repository: repository);
      await controller.initialize();
      final catalog = TabletCatalog(controller);
      final board = BoardService(controller, catalog);
      addTearDown(catalog.dispose);
      addTearDown(controller.dispose);
      final players = controller.session.players.map((p) => p.id).toList();
      await board.setInitiative(players[0]);
      repository.gate = Completer<void>();
      final transfer = board.setInitiative(players[1]);
      final later = board.setInitiative(players[2]);
      await Future<void>.delayed(Duration.zero);
      expect(board.hasInitiative(players[0]), isTrue);
      expect(board.hasInitiative(players[1]), isFalse);
      expect(board.hasInitiative(players[2]), isFalse);
      expect(
        jsonDecode(
          repository.encoded,
        )['session']['players'][0]['utilities'].last['isActive'],
        isTrue,
      );
      repository.gate!.complete();
      await Future.wait([transfer, later]);
      expect(board.hasInitiative(players[0]), isFalse);
      expect(board.hasInitiative(players[1]), isFalse);
      expect(board.hasInitiative(players[2]), isTrue);
      expect(controller.session.history.length, 3);
      expect(
        (await repository.open()).state.toJson(),
        controller.state.toJson(),
      );
    },
  );

  test('claim queued behind a new game rejects its stale scope', () async {
    final oldId = fixture.playerId;
    final resetting = fixture.controller.resetGame(keepBoard: true);
    final claiming = fixture.board.setInitiative(oldId);
    final rejected = expectLater(claiming, throwsStateError);
    expect(await resetting, isTrue);
    await rejected;
    expect(holders(), isEmpty);
    expect(fixture.controller.session.history, isEmpty);
    expect(
      fixture.controller.session.players.every((p) => entries(p).isEmpty),
      isTrue,
    );
  });

  test(
    'unknown players are rejected without state or history mutation',
    () async {
      final before = fixture.controller.state.toJson();
      await expectLater(
        fixture.board.setInitiative('not-an-active-player'),
        throwsStateError,
      );
      expect(fixture.controller.state.toJson(), before);
    },
  );

  test(
    'catalog excludes exact Initiative kinds but preserves custom names',
    () async {
      fixture.catalog.loaded = true;
      expect(
        fixture.board.utilityDefinitions.map((d) => d.id),
        isNot(contains('initiative')),
      );
      for (final kind in ['initiative', 'the_initiative']) {
        expect(fixture.board.isStandaloneUtilityKind(kind), isFalse);
        await expectLater(
          fixture.board.addUtility(fixture.playerId, kind),
          throwsStateError,
        );
      }
      expect(
        fixture.board.isUtilityVisible(
          UtilityState(
            id: 'custom',
            kind: 'custom_toggle',
            name: 'The Initiative',
          ),
        ),
        isTrue,
      );
    },
  );
}
