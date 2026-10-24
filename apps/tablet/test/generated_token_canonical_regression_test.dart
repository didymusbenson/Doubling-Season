import 'dart:io';

import 'package:doubling_season/models/token_definition.dart';
import 'package:doubling_season/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalogDirectory;
  late TableFixture f;

  setUpAll(() async {
    catalogDirectory = await Directory.systemTemp.createTemp(
      'canonical-tokens-',
    );
    Hive.init(catalogDirectory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await catalogDirectory.delete(recursive: true);
  });
  tearDown(() => f.dispose());

  Future<void> open([TabletState? state]) async {
    f = TableFixture(state);
    await f.initialize();
    await f.catalog.load();
    expect(f.catalog.loaded, isTrue);
    expect(f.catalog.error, isNull);
  }

  Future<UtilityState> add(String kind, {int? value}) async {
    await f.board.addUtility(f.playerId, kind);
    final utility = f.player.utilities.last;
    if (value != null) {
      await f.board.setUtility(f.playerId, utility.id, value: value);
    }
    return f.player.utilities.last;
  }

  TokenDefinition definition(String id) {
    final result = f.catalog.byId(id);
    expect(result, isNotNull, reason: 'Must resolve the bundled canonical ID');
    expect(result!.artwork, isNotEmpty);
    return result;
  }

  const generated = {
    'krenko_mob_boss': 'Goblin|1/1|R|Creature — Goblin|',
    'krenko_tin_street': 'Goblin|1/1|R|Creature — Goblin|',
    'hare_apparent': 'Rabbit|1/1|W|Creature — Rabbit|',
    'the_unbeatable_squirrel_girl': GameConstants.squirrelCompositeId,
  };

  for (final entry in generated.entries) {
    test(
      '${entry.key} first creation uses canonical metadata and default art',
      () async {
        await open();
        final d = definition(entry.value);
        final utility = await add(entry.key, value: 2);
        final preview = f.board.utilityPreview(f.playerId, utility.id);
        expect(preview.single.compositeId, d.id);

        await f.board.utilityAction(f.playerId, utility.id);

        final token = f.player.tokens.single;
        expect(token.definitionId, d.id);
        expect(token.type, d.type);
        expect(token.name, d.name);
        expect(token.abilities, d.abilities);
        expect(token.colors, d.colors);
        expect(token.pt, d.pt);
        expect(token.artworkUrl, d.artwork.first.url);
        expect(token.artworkSet, d.artwork.first.set);
        expect(token.artworkOptions, d.artwork.map((a) => a.toJson()).toList());
        expect(token.artworkOptions.first['artist'], isNotEmpty);
        expect(token.tapped, 0);
        expect(token.summoningSick, token.amount);
        expect(token.plusOneCounters, 0);
      },
    );

    test(
      '${entry.key} merges only matching clean canonical art and preserves undo',
      () async {
        await open();
        final d = definition(entry.value);
        final utility = await add(entry.key, value: 2);
        await f.board.createToken(f.playerId, d, quantity: 3);
        final original = f.player.tokens.single;
        final before = f.player.toJson();
        final other = f.controller.session.players[1].toJson();
        final amount = f.board
            .utilityPreview(f.playerId, utility.id)
            .single
            .quantity;

        await f.board.utilityAction(f.playerId, utility.id);

        expect(f.player.tokens.length, 1);
        expect(f.player.tokens.single.id, original.id);
        expect(f.player.tokens.single.amount, 3 + amount);
        expect(f.player.tokens.single.artworkOptions, original.artworkOptions);
        expect(f.controller.session.players[1].toJson(), other);
        expect(await f.controller.undo(), isTrue);
        expect(
          f.player.toJson()..remove('generation'),
          before..remove('generation'),
        );
      },
    );
  }

  for (final entry in generated.entries) {
    test(
      '${entry.key} uses canonical art preference, set and credits',
      () async {
        await open();
        final d = definition(entry.value);
        expect(d.artwork.length, greaterThan(1));
        final art = d.artwork.last;
        final utility = await add(entry.key, value: 2);
        await f.board.createToken(
          f.playerId,
          d,
          quantity: 2,
          artworkUrl: art.url,
        );
        final selected = f.player.tokens.single;
        expect(selected.artworkSet, art.set);
        expect(f.player.artPreferences[d.id], art.url);
        final expected =
            2 + f.board.utilityPreview(f.playerId, utility.id).single.quantity;

        await f.board.utilityAction(f.playerId, utility.id);

        expect(f.player.tokens.length, 1);
        expect(f.player.tokens.single.id, selected.id);
        expect(f.player.tokens.single.amount, expected);
        expect(f.player.tokens.single.artworkUrl, art.url);
        expect(f.player.tokens.single.artworkSet, art.set);
        expect(
          f.player.tokens.single.artworkOptions,
          d.artwork.map((a) => a.toJson()).toList(),
        );
      },
    );
  }

  test(
    'utility resolves canonical identity before specific-token rules',
    () async {
      await open();
      final d = definition(generated['krenko_mob_boss']!);
      final utility = await add('krenko_tin_street', value: 2);
      f.player.rules.add(
        ModifierSource(
          id: 'specific-goblin-rule',
          ownerPlayerId: f.playerId,
          definitionId: 'custom',
          enabled: true,
          count: 1,
          configuration: {
            'triggerType': 'specific_token',
            'targetTokenId': d.id,
            'outcomes': [
              {'outcomeType': 'multiply', 'multiplier': 3},
            ],
          },
        ),
      );
      expect(f.board.utilityPreview(f.playerId, utility.id).single.quantity, 6);
      await f.board.utilityAction(f.playerId, utility.id);
      expect(f.player.tokens.single.amount, 6);
      expect(f.player.tokens.single.definitionId, d.id);
      expect(f.player.tokens.single.artworkUrl, d.artwork.first.url);
    },
  );

  test(
    'counter, art and legacy identities remain separate without saved-data rewrite',
    () async {
      await open();
      final d = definition(generated['krenko_mob_boss']!);
      final utility = await add('krenko_tin_street', value: 2);
      await f.board.createToken(f.playerId, d, quantity: 3, tapped: true);
      final cleanId = f.player.tokens.single.id;
      final clean = f.player.tokens.single.copy();
      final modified = clean.copy()
        ..id = 'modified'
        ..plusOneCounters = 2
        ..counters = {'shield': 1};
      final otherArt = clean.copy()
        ..id = 'other-art'
        ..artworkUrl = d.artwork.last.url;
      final legacy = clean.copy()
        ..id = 'legacy-artless'
        ..type = 'Creature Token — Goblin'
        ..definitionId = 'Goblin|1/1|R|Creature Token — Goblin|'
        ..artworkUrl = null
        ..artworkSet = null
        ..artworkOptions = [];
      // Stage representative saved stacks, then reopen through real serialization.
      f.player.tokens.addAll([modified, otherArt, legacy]);
      final saved = TabletState.fromJson(f.controller.state.toJson());
      f.dispose();
      await open(saved);
      final snapshots = {
        for (final t in f.player.tokens.where((t) => t.id != cleanId))
          t.id: t.toJson(),
      };
      await f.board.utilityAction(f.playerId, utility.id);

      expect(f.player.tokens.length, 4);
      final grown = f.token(cleanId);
      expect(grown.amount, 5);
      expect(grown.tapped, 3);
      expect(grown.summoningSick, 5);
      for (final entry in snapshots.entries) {
        expect(f.token(entry.key).toJson(), entry.value);
      }
    },
  );

  test(
    'Squirrel Girl counts all owned Squirrels at resolution and applies rules once',
    () async {
      final state = stateWithTokens(
        [],
        modifiers: ['token_doubler', 'chatterfang'],
      );
      await open(state);
      final d = definition(GameConstants.squirrelCompositeId);
      final utility = await add('the_unbeatable_squirrel_girl');
      expect(
        utility.value,
        1,
        reason: 'Includes the nontoken Squirrel Girl by default',
      );
      // Representative modified tokens must count but must not be copied/merged.
      final modified = sampleToken(
        id: 'modified-squirrels',
        name: 'Squirrel',
        type: d.type,
        amount: 3,
        plusOne: 2,
        counters: {'shield': 1},
        tapped: 2,
        sick: 0,
        artworkUrl: d.artwork.first.url,
      );
      final clean = modified.copy()
        ..id = 'clean-squirrels'
        ..amount = 2
        ..tapped = 1
        ..plusOneCounters = 0
        ..counters = {};
      f.player.tokens.addAll([modified, clean]);
      f.controller.session.players[1].tokens.add(
        modified.copy()
          ..id = 'other-seat-squirrels'
          ..amount = 100,
      );
      final before = f.player.toJson();
      final other = f.controller.session.players[1].toJson();
      final history = f.controller.session.history.length;

      await f.board.utilityAction(f.playerId, utility.id);

      expect(f.player.tokens.length, 2);
      expect(f.token('modified-squirrels').toJson(), modified.toJson());
      // (1 manual + 3 modified + 2 clean) * 2, plus Chatterfang's 12.
      expect(f.token('clean-squirrels').amount, 26);
      expect(f.token('clean-squirrels').tapped, 1);
      expect(f.token('clean-squirrels').summoningSick, 24);
      expect(f.token('clean-squirrels').plusOneCounters, 0);
      expect(f.controller.session.players[1].toJson(), other);
      expect(f.controller.session.history.length, history + 1);
      expect(await f.controller.undo(), isTrue);
      expect(
        f.player.toJson()..remove('generation'),
        before..remove('generation'),
      );
    },
  );

  test(
    'Squirrel Girl utility retains supplied art first and credited variant',
    () async {
      await open();
      final utility = await add('the_unbeatable_squirrel_girl');
      final options = utility.configuration['artworkOptions'] as List;
      expect(utility.artworkUrl, options.first['url']);
      expect(options.first['artist'], 'Kim Dingwall');
      expect(options.first['url'], contains('/d/8/d8b94ebb-'));
      expect(options.last['artist'], 'Swayart');
      expect(
        utility.configuration['actionButtonText'],
        'Make Squirrels · 1GGG',
      );
    },
  );

  test(
    'analogous Manufactor, Myr and Chatterfang generated IDs resolve artwork',
    () async {
      await open();
      final manufactor = await add('academy_manufactor');
      await f.board.utilityAction(f.playerId, manufactor.id);
      final brudiclad = await add('brudiclad_telchor_engineer');
      await f.board.utilityAction(f.playerId, brudiclad.id, skip: true);
      await f.board.setModifier(f.playerId, 'chatterfang', 1);
      final goblin = definition(generated['krenko_mob_boss']!);
      await f.board.createToken(f.playerId, goblin);
      expect(
        f.player.tokens.map((t) => t.definitionId).toSet(),
        containsAll({
          GameConstants.foodCompositeId,
          GameConstants.clueCompositeId,
          GameConstants.treasureCompositeId,
          GameConstants.phyrexianMyrCompositeId,
          GameConstants.squirrelCompositeId,
          goblin.id,
        }),
      );
      for (final token in f.player.tokens) {
        final d = definition(token.definitionId);
        expect(token.artworkUrl, d.artwork.first.url);
        expect(token.artworkOptions, d.artwork.map((a) => a.toJson()).toList());
      }
    },
  );
}
