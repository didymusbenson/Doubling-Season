import 'package:doubling_season/models/item.dart';
import 'package:doubling_season/services/token_merge_compatibility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture f;

  Future<void> open(TabletState state) async {
    f = TableFixture(state);
    await f.initialize();
  }

  tearDown(() => f.dispose());

  test(
    'quick add grows selected counter-bearing stack without changing counters',
    () async {
      final source = sampleToken(
        plusOne: 2,
        counters: {'+1/+0': 1, 'shield': 2},
        artworkUrl: 'https://example.test/source.jpg',
      );
      // The canonical phone merge contract rejects this modified stack.
      final original = Item(
        name: source.name,
        pt: source.pt,
        plusOneCounters: 2,
      );
      expect(TokenMergeCompatibility.isClean(original), isFalse);
      await open(
        stateWithTokens([source, sampleToken(id: 'other', name: 'Elf')]),
      );
      final before = f.token('source').toJson();
      final otherSeat = f.controller.session.players[1].toJson();

      await f.board.changeQuantity(f.playerId, 'source', 1);

      expect(f.player.tokens.map((t) => t.id), ['source', 'other']);
      final grown = f.token('source');
      expect(grown.amount, 4);
      expect(grown.tapped, 1);
      expect(grown.summoningSick, 2);
      expect(grown.plusOneCounters, 2);
      expect(grown.counters, source.counters);
      expect(grown.artworkUrl, source.artworkUrl);
      expect(grown.artworkOptions, source.artworkOptions);
      expect(f.controller.session.players[1].toJson(), otherSeat);
      expect(await f.controller.undo(), isTrue);
      expect(f.player.tokens.map((t) => t.id), ['source', 'other']);
      expect(f.token('source').toJson(), before);
    },
  );

  test(
    'quick add targets selected modified stack instead of another clean stack',
    () async {
      final source = sampleToken(
        plusOne: 1,
        artworkUrl: 'https://example.test/a.jpg',
      );
      final compatible = sampleToken(
        id: 'clean',
        amount: 2,
        artworkUrl: source.artworkUrl,
      );
      final otherArt = sampleToken(
        id: 'other-art',
        artworkUrl: 'https://example.test/b.jpg',
      );
      await open(stateWithTokens([source, otherArt, compatible]));
      await f.board.changeQuantity(f.playerId, 'source', 1);

      expect(f.player.tokens.length, 3);
      expect(f.token('source').amount, 4);
      expect(f.token('source').plusOneCounters, 1);
      expect(f.token('clean').amount, 2);
      expect(f.token('clean').summoningSick, 1);
      expect(f.token('other-art').amount, 3);
    },
  );

  test(
    'quick add applies multipliers and companions while preserving counter source',
    () async {
      await open(
        stateWithTokens(
          [sampleToken(plusOne: 1)],
          modifiers: ['token_doubler', 'chatterfang'],
        ),
      );

      await f.board.changeQuantity(f.playerId, 'source', 1);

      expect(f.token('source').amount, 5);
      expect(f.token('source').plusOneCounters, 1);
      final added = f.player.tokens.where((t) => t.id != 'source').toList();
      expect(added.map((t) => t.amount), everyElement(2));
      expect(added.map((t) => t.name).toSet(), {'Squirrel'});
      expect(added.map((t) => t.plusOneCounters), everyElement(0));
      expect(
        f.controller.session.history.last.tokenSummary,
        contains('Saproling +2'),
      );
      expect(
        f.controller.session.history.last.tokenSummary,
        contains('Squirrel +2'),
      );
      expect(await f.controller.undo(), isTrue);
      expect(f.player.tokens.map((t) => t.id), ['source']);
    },
  );

  test('quantity add and remove remain separate undo groups', () async {
    await open(stateWithTokens([sampleToken()]));
    await f.board.changeQuantity(f.playerId, 'source', 1);
    await f.board.changeQuantity(f.playerId, 'source', -1);
    expect(f.controller.session.history.length, 2);
    expect(await f.controller.undo(), isTrue);
    expect(f.token('source').amount, 4);
    expect(await f.controller.undo(), isTrue);
    expect(f.token('source').amount, 3);
  });

  test(
    'quick add keeps clean source identity even with earlier compatible stack',
    () async {
      await open(stateWithTokens([sampleToken(id: 'earlier'), sampleToken()]));
      await f.board.changeQuantity(f.playerId, 'source', 1);
      expect(f.token('earlier').amount, 3);
      expect(f.token('source').amount, 4);
      expect(f.player.tokens.map((t) => t.id), ['earlier', 'source']);
    },
  );

  test(
    'repeated explicit Create keeps primary rows distinct and merges untapped companions',
    () async {
      await open(stateWithTokens([sampleToken()], modifiers: ['chatterfang']));
      final definition = f.board.definition(f.token('source'));
      await f.board.createToken(
        f.playerId,
        definition,
        quantity: 2,
        tapped: true,
      );
      await f.board.createToken(
        f.playerId,
        definition,
        quantity: 2,
        tapped: true,
      );
      final primaries = f.player.tokens
          .where((t) => t.name == 'Saproling')
          .toList();
      expect(primaries.map((t) => t.amount), [3, 2, 2]);
      expect(primaries.skip(1).map((t) => t.tapped), [2, 2]);
      final companions = f.player.tokens
          .where((t) => t.name == 'Squirrel')
          .toList();
      expect(companions.length, 1);
      expect(companions.single.amount, 4);
      expect(companions.single.tapped, 0);
      await f.board.changeQuantity(f.playerId, 'source', 1);
      expect(f.token('source').amount, 4);
      expect(f.player.tokens.where((t) => t.name == 'Saproling').length, 3);
    },
  );

  test(
    'replacement rule creates its own identity without source counters or art',
    () async {
      final state = stateWithTokens([
        sampleToken(plusOne: 2, artworkUrl: 'https://example.test/source.jpg'),
      ]);
      final player = state.session.players.first;
      player.rules.add(
        ModifierSource(
          id: 'replace',
          ownerPlayerId: player.id,
          definitionId: 'custom',
          name: 'Replace with Elf',
          enabled: true,
          count: 1,
          configuration: {
            'triggerType': 'any_token',
            'outcomes': [
              {
                'outcomeType': 'replace',
                'targetTokenId': 'Elf|2/2|G|Creature — Elf|Vigilance',
              },
            ],
          },
        ),
      );
      await open(state);
      final before = f.token('source').toJson();
      await f.board.changeQuantity(f.playerId, 'source', 1);
      expect(f.token('source').toJson(), before);
      final created = f.player.tokens[1];
      expect(created.name, 'Elf');
      expect(created.pt, '2/2');
      expect(created.abilities, 'Vigilance');
      expect(created.plusOneCounters, 0);
      expect(created.artworkUrl, isNull);
    },
  );

  test(
    'Scute counts all local Scute stacks and creates companions in one undo',
    () async {
      await open(
        stateWithTokens(
          [
            sampleToken(name: 'Scute Swarm', amount: 3, plusOne: 1),
            sampleToken(id: 'clean-scute', name: 'Scute Swarm', amount: 2),
          ],
          modifiers: ['token_doubler', 'chatterfang'],
        ),
      );
      await f.board.scuteSwarm(f.playerId, 'source');
      expect(f.token('source').amount, 3);
      expect(f.token('source').plusOneCounters, 1);
      expect(f.token('clean-scute').amount, 12);
      expect(
        f.player.tokens.firstWhere((t) => t.name == 'Squirrel').amount,
        10,
      );
      expect(f.controller.session.history.length, 1);
      expect(await f.controller.undo(), isTrue);
      expect(f.player.tokens.map((t) => t.amount), [3, 2]);
    },
  );

  test(
    'emblem quantity bypasses token multipliers and inapplicable actions reject',
    () async {
      await open(
        stateWithTokens(
          [
            sampleToken(
              name: 'Elspeth Emblem',
              pt: '',
              type: 'Emblem',
              tapped: 0,
              sick: 0,
            ),
          ],
          modifiers: ['token_doubler', 'chatterfang'],
        ),
      );
      await f.board.changeQuantity(f.playerId, 'source', 1);
      expect(f.player.tokens.length, 1);
      expect(f.token('source').amount, 4);
      await expectLater(
        f.board.tapTokens(f.playerId, 'source', 1),
        throwsStateError,
      );
      await expectLater(
        f.board.copyToken(f.playerId, 'source'),
        throwsStateError,
      );
      await expectLater(
        f.board.splitToken(f.playerId, 'source', 1),
        throwsStateError,
      );
      expect(f.token('source').tapped, 0);
    },
  );

  test(
    'absolute total adds eligible sickness without applying multipliers',
    () async {
      await open(
        stateWithTokens(
          [sampleToken(amount: 2, tapped: 1, sick: 0, plusOne: 1)],
          modifiers: ['token_doubler'],
        ),
      );
      await f.board.editToken(f.playerId, 'source', amount: 10);
      expect(f.token('source').amount, 10);
      expect(f.token('source').summoningSick, 8);
      expect(f.token('source').plusOneCounters, 1);
      expect(f.player.tokens.length, 1);
      await f.board.editToken(f.playerId, 'source', amount: 0);
      expect(f.token('source').tapped, 0);
      expect(f.token('source').summoningSick, 0);
    },
  );

  for (final condition in ['haste', 'disabled', 'no-pt']) {
    test('absolute total honors sickness condition: $condition', () async {
      await open(
        stateWithTokens([
          sampleToken(
            abilities: condition == 'haste' ? 'Haste' : '',
            pt: condition == 'no-pt' ? '' : '1/1',
            type: condition == 'no-pt'
                ? 'Artifact — Treasure'
                : 'Creature — Saproling',
            sick: 0,
          ),
        ], sickness: condition != 'disabled'),
      );
      await f.board.editToken(f.playerId, 'source', amount: 10);
      expect(f.token('source').summoningSick, 0);
    });
  }

  test(
    'fresh copy retains artwork but bypasses modifiers, tap and counters',
    () async {
      await open(
        stateWithTokens(
          [
            sampleToken(
              plusOne: 2,
              counters: {'+1/+0': 2},
              artworkUrl: 'https://example.test/a.jpg',
            ),
          ],
          modifiers: ['token_doubler'],
        ),
      );
      final before = f.token('source').toJson();
      await f.board.copyToken(f.playerId, 'source');
      final copy = f.player.tokens[1];
      expect(f.token('source').toJson(), before);
      expect(copy.amount, 1);
      expect(copy.tapped, 0);
      expect(copy.summoningSick, 1);
      expect(copy.plusOneCounters, 0);
      expect(copy.counters, isEmpty);
      expect(copy.artworkUrl, before['artworkUrl']);
    },
  );

  for (final tappedFirst in [false, true]) {
    test(
      'split preserves counters/art and allocates tappedFirst=$tappedFirst',
      () async {
        await open(
          stateWithTokens([
            sampleToken(
              amount: 5,
              tapped: 3,
              sick: 4,
              plusOne: 2,
              counters: {'+1/+0': 1, '+0/+1': 3},
              artworkUrl: 'https://example.test/a.jpg',
            ),
          ]),
        );
        await f.board.splitToken(
          f.playerId,
          'source',
          2,
          tappedFirst: tappedFirst,
        );
        final source = f.token('source'), split = f.player.tokens[1];
        expect(source.amount, 3);
        expect(split.amount, 2);
        expect(split.tapped, tappedFirst ? 2 : 0);
        expect(source.tapped, tappedFirst ? 1 : 3);
        expect(source.summoningSick, 0);
        expect(split.summoningSick, 0);
        expect(split.plusOneCounters, 2);
        expect(split.counters, source.counters);
        expect(split.artworkUrl, source.artworkUrl);
        expect(await f.controller.undo(), isTrue);
        expect(f.player.tokens.length, 1);
        expect(f.token('source').amount, 5);
        expect(f.token('source').summoningSick, 4);
      },
    );
  }

  test(
    'partial tap/untap clamps and does not affect quantity or counters',
    () async {
      await open(stateWithTokens([sampleToken(plusOne: 1)]));
      await f.board.tapTokens(f.playerId, 'source', 1);
      expect(f.token('source').tapped, 2);
      await f.board.tapTokens(f.playerId, 'source', 100);
      expect(f.token('source').tapped, 3);
      await f.board.tapTokens(f.playerId, 'source', -1);
      expect(f.token('source').tapped, 2);
      await f.board.tapTokens(f.playerId, 'source', -100);
      expect(f.token('source').tapped, 0);
      expect(f.token('source').amount, 3);
      expect(f.token('source').plusOneCounters, 1);
    },
  );

  test(
    'numeric counter Set bypasses multipliers, cancels opposing PT, removes zero custom',
    () async {
      await open(
        stateWithTokens(
          [
            sampleToken(minusOne: 2, counters: {'+1/+0': 2, 'shield': 2}),
          ],
          modifiers: ['doubling_season'],
        ),
      );
      await f.board.setCounter(f.playerId, 'source', '+1/+1', 5);
      expect(f.token('source').plusOneCounters, 3);
      expect(f.token('source').minusOneCounters, 0);
      expect(f.token('source').counters['+1/+0'], 2);
      await f.board.setCounter(f.playerId, 'source', 'shield', 0);
      expect(f.token('source').counters.containsKey('shield'), isFalse);
    },
  );

  test(
    'counter history reflects rules-adjusted delta and clamped removal',
    () async {
      await open(
        stateWithTokens([sampleToken()], modifiers: ['all_counter_doubler']),
      );
      await f.board.counter(f.playerId, 'source', 'shield', 1);
      expect(f.token('source').counters['shield'], 2);
      expect(f.controller.session.history.last.summary, 'shield +2');
      await f.board.counter(f.playerId, 'source', 'shield', -10);
      expect(f.controller.session.history.last.summary, 'shield -2');
      expect(f.token('source').counters, isEmpty);
    },
  );

  test(
    'Split & Add to One follows original raw counter and appended fresh-status policy',
    () async {
      await open(
        stateWithTokens(
          [
            sampleToken(
              tapped: 3,
              sick: 3,
              plusOne: 1,
              counters: {'+0/+1': 2},
              artworkUrl: 'https://example.test/a.jpg',
            ),
            sampleToken(id: 'other', name: 'Elf'),
          ],
          modifiers: ['all_counter_doubler'],
        ),
      );
      await f.board.splitAndAddCounter(f.playerId, 'source', '+1/+0', 2);
      final source = f.token('source'), split = f.player.tokens.last;
      expect(source.amount, 2);
      expect(source.tapped, 2);
      expect(source.summoningSick, 2);
      expect(source.counters, {'+0/+1': 2});
      expect(f.player.tokens[1].id, 'other');
      expect(split.amount, 1);
      expect(split.tapped, 0);
      expect(split.summoningSick, 0);
      expect(split.plusOneCounters, 1);
      expect(split.counters, {'+0/+1': 2, '+1/+0': 2});
      expect(split.artworkUrl, source.artworkUrl);
      expect(f.controller.session.history.length, 1);
      expect(await f.controller.undo(), isTrue);
      expect(f.player.tokens.map((t) => t.id), ['source', 'other']);
      expect(f.token('source').amount, 3);
      expect(f.token('source').tapped, 3);
      expect(f.token('source').summoningSick, 3);
    },
  );

  test(
    'counter catalog Add to All uses raw quantity while quick counter uses modifiers',
    () async {
      await open(
        stateWithTokens([sampleToken()], modifiers: ['all_counter_doubler']),
      );
      await f.board.addSelectedCounter(f.playerId, 'source', 'shield', 2);
      expect(f.token('source').counters['shield'], 2);
      await f.board.counter(f.playerId, 'source', 'shield', 1);
      expect(f.token('source').counters['shield'], 4);
      expect(f.player.tokens.length, 1);
    },
  );

  test(
    'inline raw empty values commit without changing runtime state',
    () async {
      await open(
        stateWithTokens([
          sampleToken(plusOne: 1, counters: {'shield': 2}),
        ]),
      );
      final before = f.token('source').toJson();
      await f.board.editToken(
        f.playerId,
        'source',
        name: '',
        abilities: '  line one\nline two  ',
      );
      final result = f.token('source');
      expect(result.name, '');
      expect(result.abilities, '  line one\nline two  ');
      expect(result.amount, before['amount']);
      expect(result.tapped, before['tapped']);
      expect(result.summoningSick, before['summoningSick']);
      expect(result.plusOneCounters, before['plusOneCounters']);
      expect(result.counters, before['counters']);
    },
  );

  test('failed save publishes neither partial split nor history', () async {
    await open(stateWithTokens([sampleToken(plusOne: 1)]));
    final before = f.controller.state.toJson();
    f.repository.failSave = true;
    await expectLater(
      f.board.splitAndAddCounter(f.playerId, 'source', 'shield', 1),
      throwsStateError,
    );
    expect(f.controller.state.toJson(), before);
  });
}
