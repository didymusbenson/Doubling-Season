import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/board_service.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'support/table_fixture.dart';
import 'support/legacy_utility_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture f;
  late PresetService presets;
  setUp(() async {
    f = TableFixture(legacyUtilityState(artwork: true));
    await f.initialize();
    f.catalog.loaded = true;
    presets = PresetService(f.controller, f.catalog);
  });
  tearDown(() => f.dispose());
  UtilityState utility(String kind) =>
      f.player.utilities.firstWhere((u) => u.kind == kind);
  List<Map<String, dynamic>> payload() =>
      f.player.utilities.map((u) => u.toJson()).toList();
  test(
    'exact catalog exclusion, retained game/card kinds and custom names',
    () async {
      final ids = f.board.utilityDefinitions.map((d) => d.id).toSet();
      for (final kind in redundantUtilityKinds) {
        expect(ids, isNot(contains(kind)));
        expect(f.board.isUtilityVisible(utility(kind)), isFalse);
        await expectLater(
          f.board.addUtility(f.playerId, kind),
          throwsStateError,
        );
      }
      expect(ids, containsAll(retainedUtilityKinds));
      for (final kind in [
        ...retainedUtilityKinds,
        'commander_tax',
        'initiative',
        'custom_tracker',
        'custom_toggle',
      ]) {
        final u = UtilityState(id: kind, kind: kind, name: 'Poison Counters');
        expect(f.board.isUtilityVisible(u), isTrue, reason: kind);
        u.visible = false;
        expect(f.board.isUtilityVisible(u), isFalse);
      }
    },
  );
  test(
    'save/reopen preserves raw values, IDs, flags, art and configuration exactly',
    () async {
      final before = payload();
      expect(f.board.utilityValue(f.playerId, utility('life_total').id), 37);
      expect(
        f.board.utilityValue(f.playerId, utility('poison_counters').id),
        5,
      );
      for (final kind in ['citys_blessing', 'monarch', 'day_night']) {
        expect(f.board.utilityActive(f.playerId, utility(kind).id), isTrue);
      }
      await f.controller.adjustMana(f.playerId, 'U', 1);
      expect(payload(), before);
      final reopened = TableController(repository: f.repository);
      await reopened.initialize();
      addTearDown(reopened.dispose);
      final board = BoardService(reopened, f.catalog);
      expect(
        reopened.player(f.playerId).utilities.map((u) => u.toJson()).toList(),
        before,
      );
      expect(
        reopened
            .player(f.playerId)
            .utilities
            .where(board.isUtilityVisible)
            .map((u) => u.kind),
        ['storm_count', 'mana_pool'],
      );
    },
  );
  test(
    'reorder keeps legacy and ordinary hidden entries in their slots and undoes',
    () async {
      await f.board.setUtility(
        f.playerId,
        utility('mana_pool').id,
        visible: false,
      );
      await f.board.createCustomUtility(f.playerId, name: 'Poison Counters');
      final before = payload();
      final ids = f.player.utilities
          .where(f.board.isUtilityVisible)
          .map((u) => u.id)
          .toList();
      await f.board.reorderVisibleUtilities(f.playerId, ids.reversed.toList());
      expect(
        f.player.utilities.where(f.board.isUtilityVisible).map((u) => u.id),
        ids.reversed,
      );
      for (var i = 0; i < before.length; i++) {
        if (before[i]['kind'] != 'storm_count' &&
            before[i]['kind'] != 'custom_tracker') {
          expect(f.player.utilities[i].toJson(), before[i]);
        }
      }
      await expectLater(
        f.board.reorderVisibleUtilities(f.playerId, [
          ...ids,
          utility('life_total').id,
        ]),
        throwsStateError,
      );
      expect(await f.controller.undo(), isTrue);
      expect(payload(), before);
    },
  );
  test(
    'legacy bindings use authoritative counters/statuses and undo without normalizing raw values',
    () async {
      final before = payload();
      for (final entry in {
        'poison_counters': 'poison',
        'energy_counters': 'energy',
        'experience_counters': 'experience',
        'radiation_counters': 'radiation',
      }.entries) {
        final previous = f.player.counters[entry.value]!;
        await f.board.adjustUtility(f.playerId, utility(entry.key).id, 2);
        expect(f.player.counters[entry.value], previous + 2);
        expect(payload(), before);
        expect(await f.controller.undo(), isTrue);
        expect(f.player.counters[entry.value], previous);
      }
      await f.board.setUtility(f.playerId, utility('life_total').id, value: 31);
      expect(f.player.life, 31);
      expect(payload(), before);
      expect(await f.controller.undo(), isTrue);
      expect(f.player.life, 37);
      for (final kind in ['citys_blessing', 'monarch', 'day_night']) {
        await f.board.toggleUtility(f.playerId, utility(kind).id);
        expect(f.board.utilityActive(f.playerId, utility(kind).id), isFalse);
        expect(payload(), before);
        expect(await f.controller.undo(), isTrue);
        expect(f.board.utilityActive(f.playerId, utility(kind).id), isTrue);
      }
    },
  );
  test(
    'persisted @id field diffs and whole-list add snapshots still undo after reopen',
    () async {
      final before = payload();
      final energy = utility('energy_counters');
      await f.board.setUtility(
        f.playerId,
        energy.id,
        description: 'Historical edit',
      );
      expect(
        f.controller.session.history.last.commands.single.changes.any(
          (c) => c.path.contains('@id:${energy.id}'),
        ),
        isTrue,
      );
      await f.board.addUtility(f.playerId, 'hare_apparent');
      final saved = jsonDecode(f.repository.encoded);
      final reopened = TableController(repository: f.repository);
      await reopened.initialize();
      addTearDown(reopened.dispose);
      expect(reopened.state.toJson(), saved);
      expect(await reopened.undo(), isTrue);
      expect(await reopened.undo(), isTrue);
      expect(
        reopened.player(f.playerId).utilities.map((u) => u.toJson()).toList(),
        before,
      );
    },
  );
  test(
    'archive restore retains payload and bound counter undo timeline',
    () async {
      final before = payload();
      await f.board.adjustUtility(f.playerId, utility('poison_counters').id, 3);
      await f.controller.resetGame(keepBoard: false, playerCount: 2);
      final archive = f.controller.state.archives.single;
      expect(
        archive.session.players.first.utilities.map((u) => u.toJson()).toList(),
        before,
      );
      await f.controller.restoreArchive(archive.id);
      expect(payload(), before);
      expect(f.player.counters['poison'], 8);
      expect(
        f.player.utilities.where(f.board.isUtilityVisible).map((u) => u.kind),
        ['storm_count', 'mana_pool'],
      );
      expect(await f.controller.undo(), isTrue);
      expect(f.player.counters['poison'], 5);
      expect(payload(), before);
    },
  );
  test(
    'preset replace/append and tablet v4 preserve legacy templates without counter migration',
    () async {
      final before = payload();
      final saved = await presets.save(f.playerId, 'Legacy setup');
      final templates =
          cloneJson({'items': saved['utilities']})['items'] as List;
      expect(payload(), before);
      final exported = await presets.exportJson(saved['id']);
      final imported = await presets.importJson(exported);
      expect(imported['utilities'], templates);
      await presets.load(f.playerId, imported['id']);
      final replaced = payload();
      for (final raw in templates) {
        final u = utility(raw['kind']);
        expect(u.defaultValue, raw['defaultValue']);
        expect(u.value, raw['defaultValue']);
        expect(u.configuration, raw['configuration']);
        expect(u.artworkUrl, raw['artworkUrl']);
        expect(u.visible, raw['visible']);
      }
      expect(f.player.life, 37);
      expect(f.player.counters['poison'], 5);
      await presets.load(f.playerId, saved['id'], append: true);
      expect(
        f.player.utilities.where(f.board.isUtilityVisible).map((u) => u.kind),
        ['storm_count', 'mana_pool'],
      );
      expect(await f.controller.undo(), isTrue);
      expect(payload(), replaced);
      expect(await f.controller.undo(), isTrue);
      expect(payload(), before);
    },
  );
  for (final schema in [1, 2, 3]) {
    test(
      'phone schema $schema preserves built-ins and explicitly custom same-name trackers/toggles',
      () async {
        final imported = await presets.importJson(
          jsonEncode({
            'schemaVersion': schema,
            'deck': {
              'name': 'Phone setup $schema',
              'templates': [],
              'trackerWidgets': [
                for (var n = 0; n < 5; n++)
                  {
                    'name': legacyNames[n],
                    'actionType': redundantUtilityKinds[n],
                    'defaultValue': n + 2,
                    'colorIdentity': 'UG',
                    'artworkUrl': 'https://example.test/phone-$n.png',
                    'retainedConfig': {'marker': n},
                  },
                {
                  'name': 'Poison Counters',
                  'isCustom': true,
                  'defaultValue': 4,
                },
              ],
              'toggleWidgets': [
                for (var n = 5; n < 8; n++)
                  {
                    'name': legacyNames[n],
                    'actionType': redundantUtilityKinds[n],
                    'defaultValue': 0,
                    'onDescription': 'Saved on',
                    'offDescription': 'Saved off',
                  },
                {'name': 'Monarch', 'isCustom': true, 'defaultValue': 0},
              ],
            },
          }),
        );
        final before =
            cloneJson({'items': imported['utilities']})['items'] as List;
        expect(
          before.map((u) => u['kind']),
          containsAll([
            ...redundantUtilityKinds,
            'custom_tracker',
            'custom_toggle',
          ]),
        );
        await presets.load(f.playerId, imported['id']);
        expect(
          f.player.utilities.where(f.board.isUtilityVisible).map((u) => u.kind),
          ['custom_tracker', 'custom_toggle'],
        );
        expect(f.player.life, 37);
        expect(f.player.counters['poison'], 5);
        final exported = await presets.exportJson(
          imported['id'],
          phoneCompatible: true,
        );
        final roundtrip = await presets.importJson(exported);
        final after = roundtrip['utilities'] as List;
        for (var n = 0; n < before.length; n++) {
          for (final key in ['kind', 'defaultValue', 'colors', 'artworkUrl']) {
            expect(after[n][key], before[n][key]);
          }
        }
        expect(imported['utilities'], before);
      },
    );
  }
}
