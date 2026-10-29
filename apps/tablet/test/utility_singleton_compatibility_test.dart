import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/board_service.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/storage/table_repository.dart';

import 'commander_direct_grid_interaction_test.dart' show DelayedRepository;
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TableFixture> fixture(String kind, {bool visible = false}) async {
    final state = TabletState.initial();
    final player = state.session.players.first;
    player.mana['U'] = 7;
    player.manaLocks.add('U');
    player.utilities = [
      UtilityState(
        id: 'unrelated-hidden',
        kind: 'custom_tracker',
        name: 'Saved other',
        visible: false,
        value: 42,
        configuration: {'untouched': true},
      ),
      UtilityState(
        id: 'legacy-singleton',
        kind: kind,
        name: 'My saved $kind',
        visible: visible,
        value: 17,
        defaultValue: 3,
        isActive: true,
        colors: 'UG',
        description: 'Saved description',
        artworkUrl: 'file:///private/test-art.jpg',
        configuration: {
          'tapIncrement': 3,
          'legacySetting': {'unchanged': true},
          'artworkOptions': [
            {'url': 'file:///private/test-art.jpg', 'artist': 'Local artist'},
          ],
        },
      ),
      UtilityState(id: 'after', kind: 'custom_toggle', name: 'After'),
    ];
    final f = TableFixture(state);
    await f.initialize();
    f.catalog.loaded = true;
    addTearDown(f.dispose);
    await PresetService(
      f.controller,
      f.catalog,
    ).save(f.playerId, 'Prior setup');
    return f;
  }

  List<Map<String, dynamic>> payload(TableFixture f) =>
      f.player.utilities.map((u) => u.toJson()).toList();

  Future<TableFixture> reopen(TableFixture f) async {
    final saved = jsonMap(jsonDecode(f.repository.encoded));
    expect(saved, f.controller.state.toJson());
    final decoded = TabletState.fromJson(saved);
    validateTabletState(decoded);
    final next = TableFixture(decoded);
    await next.initialize();
    next.catalog.loaded = true;
    addTearDown(next.dispose);
    expect(next.controller.state.toJson(), saved);
    return next;
  }

  for (final kind in ['storm_count', 'mana_pool']) {
    testWidgets(
      '$kind two queued Adds publish one fresh replacement only after durability',
      (tester) async {
        final seed = await fixture(kind);
        final repository = DelayedRepository(seed.controller.state.copy())
          ..delay = true;
        final controller = TableController(repository: repository);
        await controller.initialize();
        final catalog = TabletCatalog(controller)..loaded = true;
        addTearDown(() {
          catalog.dispose();
          controller.dispose();
        });
        final board = BoardService(controller, catalog);
        final playerId = seed.playerId;
        List<Map<String, dynamic>> currentUtilities() => controller
            .player(playerId)
            .utilities
            .map((u) => u.toJson())
            .toList();
        final oldState = controller.state.toJson();
        final oldPayload = currentUtilities();
        final oldSaved = repository.encoded;

        final first = board.addUtility(playerId, kind);
        await tester.pump();
        expect(repository.waits, hasLength(1));
        expect(controller.state.toJson(), oldState);
        expect(repository.encoded, oldSaved);
        final second = board.addUtility(playerId, kind);
        await tester.pump();
        expect(
          repository.waits,
          hasLength(1),
          reason: 'The writer serializes the second Add.',
        );
        expect(controller.state.toJson(), oldState);
        expect(currentUtilities(), oldPayload);
        expect(repository.encoded, oldSaved);

        repository.waits.first.complete();
        await tester.pump();
        expect(repository.waits, hasLength(2));
        final freshId = controller.player(playerId).utilities[1].id;
        expect(freshId, isNot('legacy-singleton'));
        expect(controller.session.history, hasLength(1));
        expect(controller.session.history.single.commands, hasLength(1));
        final firstPayload = currentUtilities();
        repository.waits.last.complete();
        await tester.pump();
        await Future.wait([first, second]);
        expect(currentUtilities(), firstPayload);
        expect(
          controller.player(playerId).utilities.where((u) => u.kind == kind),
          hasLength(1),
        );
        expect(controller.player(playerId).utilities[1].id, freshId);
        expect(controller.player(playerId).utilities[1].value, 0);
        expect(controller.session.history, hasLength(1));
        expect(controller.session.history.single.commands, hasLength(1));
        expect(
          controller
              .session
              .history
              .single
              .commands
              .single
              .changes
              .single
              .before,
          oldPayload,
        );
        expect(jsonDecode(repository.encoded), controller.state.toJson());
        expect(controller.state.decks, oldState['decks']);
        expect(currentUtilities().first, oldPayload.first);
        expect(currentUtilities().last, oldPayload.last);
        expect(controller.player(playerId).mana['U'], 7);
        expect(controller.player(playerId).manaLocks, {'U'});

        repository.delay = false;
        expect(await controller.undo(), isTrue);
        expect(currentUtilities(), oldPayload);
        expect(controller.state.decks, oldState['decks']);
        expect(jsonDecode(repository.encoded), controller.state.toJson());
        validateTabletState(controller.state);
      },
    );

    test(
      '$kind fresh replacement reloads and undoes exact hidden payload/order',
      () async {
        final f = await fixture(kind);
        final before = payload(f);
        final decks = cloneJson({'items': f.controller.state.decks})['items'];
        final otherPlayers = f.controller.session.players
            .skip(1)
            .map((p) => p.toJson())
            .toList();
        await f.board.addUtility(f.playerId, kind);
        final fresh = f.player.utilities[1];
        expect(f.player.utilities.map((u) => u.id), [
          'unrelated-hidden',
          fresh.id,
          'after',
        ]);
        expect(fresh.id, isNot('legacy-singleton'));
        expect(fresh.kind, kind);
        expect(fresh.visible, isTrue);
        expect(fresh.value, fresh.defaultValue);
        expect(fresh.defaultValue, 0);
        expect(fresh.configuration, isNot(contains('legacySetting')));
        expect(fresh.artworkUrl, isNot('file:///private/test-art.jpg'));
        expect(f.player.utilities.where((u) => u.kind == kind), hasLength(1));
        expect(f.player.utilities.first.toJson(), before.first);
        expect(f.player.utilities.last.toJson(), before.last);
        expect(f.player.mana['U'], 7);
        expect(f.player.manaLocks, {'U'});
        expect(f.controller.state.decks, decks);
        expect(
          f.controller.session.players.skip(1).map((p) => p.toJson()).toList(),
          otherPlayers,
        );
        final history = f.controller.session.history.last;
        expect(
          history.label,
          kind == 'storm_count' ? 'Add fresh Storm' : 'Add fresh Mana pool',
        );
        expect(history.commands, hasLength(1));
        final change = history.commands.single.changes.single;
        expect(change.path.last, 'utilities');
        expect(change.before, before);
        expect(change.after, payload(f));

        final restored = await reopen(f);
        expect(await restored.controller.undo(), isTrue);
        expect(payload(restored), before);
        expect(restored.controller.state.decks, decks);
        expect(restored.player.mana['U'], 7);
        expect(restored.player.manaLocks, {'U'});
        final again = await reopen(restored);
        expect(payload(again), before);
        await again.board.addUtility(again.playerId, kind);
        final secondFresh = again.player.utilities[1];
        expect(secondFresh.id, isNot(anyOf('legacy-singleton', fresh.id)));
        expect(secondFresh.value, 0);
        expect(secondFresh.configuration, isNot(contains('legacySetting')));
        expect(await again.controller.undo(), isTrue);
        expect(payload(again), before);
        expect(again.controller.state.decks, decks);
      },
    );

    test(
      '$kind visible Add is a no-op and Remove/Add history keeps exact identities',
      () async {
        final f = await fixture(kind, visible: true);
        final before = payload(f);
        final historyBefore = f.controller.session.history.length;
        await f.board.addUtility(f.playerId, kind);
        expect(payload(f), before);
        expect(f.controller.session.history.length, historyBefore);
        await f.board.removeUtility(f.playerId, 'legacy-singleton');
        final removed = payload(f);
        await f.board.addUtility(f.playerId, kind);
        final fresh = f.player.utilities.last;
        expect(fresh.id, isNot('legacy-singleton'));
        expect(fresh.value, 0);
        expect(f.player.utilities.where((u) => u.kind == kind), hasLength(1));
        final next = await reopen(f);
        expect(await next.controller.undo(), isTrue);
        expect(payload(next), removed);
        expect(await next.controller.undo(), isTrue);
        expect(payload(next), before);
        expect(next.player.mana['U'], 7);
        expect(next.player.manaLocks, {'U'});
      },
    );

    test(
      '$kind failed fresh replacement leaves saved state and History unchanged',
      () async {
        final f = await fixture(kind);
        final before = f.controller.state.toJson();
        final encoded = f.repository.encoded;
        f.repository.failSave = true;
        await expectLater(
          f.board.addUtility(f.playerId, kind),
          throwsStateError,
        );
        expect(f.controller.state.toJson(), before);
        expect(f.repository.encoded, encoded);
        f.repository.failSave = false;
        await f.board.addUtility(f.playerId, kind);
        expect(f.player.utilities.where((u) => u.kind == kind), hasLength(1));
        expect(f.controller.session.history, hasLength(1));
      },
    );

    test(
      '$kind old uniqueness invariant rejects every duplicate visibility combination',
      () async {
        final f = await fixture(kind);
        for (final firstVisible in [false, true]) {
          for (final secondVisible in [false, true]) {
            final state = f.controller.state.copy();
            final player = state.session.players.first;
            player.utilities[1].visible = firstVisible;
            player.utilities.add(
              UtilityState(
                id: 'duplicate',
                kind: kind,
                name: 'Duplicate',
                visible: secondVisible,
              ),
            );
            expect(() => validateTabletState(state), throwsFormatException);
          }
        }
      },
    );

    test(
      '$kind preset load deduplicates board copies without modifying definitions',
      () async {
        final f = await fixture(kind);
        final service = PresetService(f.controller, f.catalog);
        final id = service.presets.single['id'] as String;
        final originalDefinitions = cloneJson({
          'items': f.controller.state.decks,
        })['items'];
        await f.board.addUtility(f.playerId, kind);
        final fresh = payload(f);
        expect(f.controller.state.decks, originalDefinitions);
        await service.load(f.playerId, id, append: true);
        expect(f.player.utilities.where((u) => u.kind == kind), hasLength(1));
        expect(
          f.player.utilities.singleWhere((u) => u.kind == kind).id,
          fresh[1]['id'],
        );
        expect(f.controller.state.decks, originalDefinitions);
        expect(f.player.utilities.first.toJson(), fresh.first);
        expect(await f.controller.undo(), isTrue);
        expect(payload(f), fresh);
        await service.load(f.playerId, id);
        expect(f.player.utilities.where((u) => u.kind == kind), hasLength(1));
        expect(
          f.player.utilities.singleWhere((u) => u.kind == kind).visible,
          isFalse,
        );
        expect(f.controller.state.decks, originalDefinitions);
        expect(f.player.mana['U'], 7);
        expect(f.player.manaLocks, {'U'});
      },
    );
  }

  test(
    'Ring preset still retains hidden and fresh copies without rewriting definitions',
    () async {
      final f = await fixture('the_ring');
      await f.board.addUtility(f.playerId, 'the_ring');
      final service = PresetService(f.controller, f.catalog);
      final saved = await service.save(f.playerId, 'Both Ring views');
      final templates = cloneJson({'items': saved['utilities']})['items'];
      await service.load(f.playerId, saved['id']);
      final rings = f.player.utilities
          .where((u) => u.kind == 'the_ring')
          .toList();
      expect(rings, hasLength(2));
      expect(rings.where((u) => u.visible), hasLength(1));
      expect(
        rings.singleWhere((u) => !u.visible).configuration['legacySetting'],
        {'unchanged': true},
      );
      expect(service.presets.last['utilities'], templates);
      validateTabletState(f.controller.state);
    },
  );
}
