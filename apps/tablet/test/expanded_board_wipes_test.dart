import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/board_service.dart';
import 'package:tripling_table/state/table_controller.dart';

import 'support/table_fixture.dart';

const _removed = <String, Set<String>>{
  'wipe_creatures': {
    'creature',
    'artifact-creature',
    'enchantment-creature',
    'land-creature',
    'emblem-text',
  },
  'wipe_artifacts': {
    'artifact',
    'artifact-creature',
    'artifact-enchantment',
    'artifact-land',
  },
  'wipe_enchantments': {
    'enchantment',
    'enchantment-creature',
    'artifact-enchantment',
  },
  'wipe_artifacts_enchantments': {
    'artifact',
    'artifact-creature',
    'enchantment',
    'enchantment-creature',
    'artifact-enchantment',
    'artifact-land',
  },
  'wipe_nonland': {
    'creature',
    'artifact',
    'artifact-creature',
    'enchantment',
    'enchantment-creature',
    'artifact-enchantment',
    'planeswalker',
    'battle',
    'emblem-text',
  },
};

List<TokenState> _tokens([String prefix = '']) {
  final types = <String, String>{
    'creature': 'Creature — Spirit',
    'artifact': 'Artifact — Treasure',
    'artifact-creature': 'Legendary Artifact Creature — Golem',
    'enchantment': 'Enchantment — Aura',
    'enchantment-creature': 'Enchantment Creature — Nymph',
    'artifact-enchantment': 'Artifact Enchantment',
    'artifact-land': 'Artifact Land',
    'land': 'Basic Land — Forest',
    'land-creature': 'Land Creature — Forest Dryad',
    'planeswalker': 'Legendary Planeswalker — Jace',
    'battle': 'Battle — Siege',
    'emblem': 'Emblem',
    'instant': 'Instant',
    'sorcery': 'Sorcery',
    'subtype-only': 'Kindred — Creature Artifact Enchantment',
    'abilities-only': 'Kindred — Wizard',
    'unknown': '',
    'emblem-text': 'Creature — Wizard',
  };
  return [
    for (final entry in types.entries)
      sampleToken(
          id: '$prefix${entry.key}',
          name: entry.key == 'emblem-text' ? 'Wizard' : entry.key,
          type: entry.value,
          // Creature type recognition must not depend on populated P/T.
          pt: '',
          abilities: entry.key == 'abilities-only'
              ? 'Create a Creature, Artifact, or Enchantment token.'
              : entry.key == 'emblem-text'
              ? 'You get an emblem with a triggered ability.'
              : '',
          plusOne: 2,
          counters: {'charge': 4},
          artworkUrl: 'https://example.invalid/${entry.key}.png',
        )
        ..extra['preserved'] = {
          'nested': [1, 2, 3],
        },
  ];
}

TabletState _table() {
  final state = TabletState.initial();
  for (final player in state.session.players) {
    player.tokens = _tokens('${player.id}/');
    player.life = 29;
    player.mana['U'] = 3;
    player.counters['energy'] = 7;
  }
  state.archives.add(
    GameArchive(
      id: 'previous-game',
      label: 'Previous game',
      savedAt: DateTime.utc(2026, 11, 1),
      session: state.session.copy(),
    ),
  );
  // A retained seat profile and archived player are not current participants.
  state.session.players = state.session.players.take(3).toList();
  return state;
}

Map<String, dynamic> _board(PlayerState player) =>
    player.toJson()..remove('generation');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final action in [..._removed.keys, 'wipe_all']) {
    test(
      '$action matches card types, stays in current game, and undoes once',
      () async {
        final f = TableFixture(_table());
        addTearDown(f.dispose);
        await f.initialize();
        final before = f.controller.state.copy();
        final removed = action == 'wipe_all'
            ? _tokens().map((t) => t.id).toSet()
            : _removed[action]!;

        await f.board.wipeEveryone(action);

        for (final player in f.controller.session.players) {
          final old = before.session.player(player.id);
          expect(
            player.tokens.map((t) => t.toJson()).toList(),
            old.tokens
                .where((t) => !removed.contains(t.id.split('/').last))
                .map((t) => t.toJson())
                .toList(),
            reason:
                '$action must match only its intended types, including multitypes',
          );
          expect(player.generation, old.generation + 1);
          expect(
            _board(player)..remove('tokens'),
            _board(old)..remove('tokens'),
          );
        }
        final history = f.controller.session.history.single;
        expect(history.playerId, isNull);
        expect(history.commands, hasLength(1));
        expect(
          history.affectedPlayerIds.toSet(),
          before.session.players.map((p) => p.id).toSet(),
        );
        expect(
          f.controller.state.archives.map((a) => a.toJson()).toList(),
          before.archives.map((a) => a.toJson()).toList(),
        );
        expect(
          f.controller.state.profiles.map((p) => p.toJson()).toList(),
          before.profiles.map((p) => p.toJson()).toList(),
        );

        final reopened = TableController(repository: f.repository);
        addTearDown(reopened.dispose);
        await reopened.initialize();
        expect(await reopened.undo(), isTrue);
        expect(reopened.canUndo, isFalse);
        for (final player in reopened.session.players) {
          // Generation deliberately changes to invalidate old editors; all board
          // data, token order, metadata, counters and quantities restore exactly.
          expect(_board(player), _board(before.session.player(player.id)));
        }
      },
    );

    test(
      '$action skips empty seats and repeated wipes add no history',
      () async {
        final initial = _table();
        initial.session.players[1].tokens.clear();
        initial.session.players[2].tokens.clear();
        final f = TableFixture(initial);
        addTearDown(f.dispose);
        await f.initialize();
        final emptySeats = f.controller.session.players
            .skip(1)
            .map((p) => p.toJson())
            .toList();

        await f.board.wipeEveryone(action);

        expect(f.controller.session.history.single.affectedPlayerIds, [
          f.playerId,
        ]);
        expect(
          f.controller.session.players.skip(1).map((p) => p.toJson()).toList(),
          emptySeats,
        );
        final afterFirst = f.controller.session.players
            .map((p) => p.toJson())
            .toList();
        await f.board.wipeEveryone(action);
        expect(f.controller.session.history, hasLength(1));
        expect(
          f.controller.session.players.map((p) => p.toJson()).toList(),
          afterFirst,
        );
      },
    );

    test(
      '$action persistence failure leaves all boards and history untouched',
      () async {
        final f = TableFixture(_table());
        addTearDown(f.dispose);
        await f.initialize();
        final before = f.controller.state.toJson();
        final stored = f.repository.encoded;
        f.repository.failSave = true;

        await expectLater(f.board.wipeEveryone(action), throwsStateError);

        expect(f.controller.state.toJson(), before);
        expect(f.repository.encoded, stored);
        expect(f.controller.canUndo, isFalse);
      },
    );
  }

  for (final action in ['wipe_creatures', 'wipe_nonland']) {
    test('$action uses legacy P/T only when the type line is absent', () async {
      final f = TableFixture(
        stateWithTokens([
          sampleToken(id: 'legacy', type: '', pt: '2/2'),
          sampleToken(id: 'instant', type: 'Instant', pt: '2/2'),
          sampleToken(id: 'subtype', type: 'Kindred - Creature', pt: ''),
          sampleToken(id: 'emblem', name: 'Emblem', type: '', pt: '2/2'),
        ]),
      );
      addTearDown(f.dispose);
      await f.initialize();

      await f.board.wipeEveryone(action);

      expect(f.player.tokens.map((t) => t.id), [
        'instant',
        'subtype',
        'emblem',
      ]);
    });
  }

  test('all six supported wipe options have descriptions', () {
    expect(BoardService.wipeOptions.keys.toSet(), {
      ..._removed.keys,
      'wipe_all',
    });
    expect(
      BoardService.wipeDescriptions.keys.toSet(),
      BoardService.wipeOptions.keys.toSet(),
    );
    expect(BoardService.wipeDescriptions.values, everyElement(isNotEmpty));
  });
}
