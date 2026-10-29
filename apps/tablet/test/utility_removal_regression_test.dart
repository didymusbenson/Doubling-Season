import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/state/table_controller.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture f;
  setUp(() async {
    final state = TabletState.initial();
    state.session.players.first.utilities = [
      UtilityState(
        id: 'legacy-hidden',
        kind: 'storm_count',
        name: 'Old storm',
        value: 17,
        visible: false,
        configuration: {'legacySetting': true},
      ),
      UtilityState(
        id: 'removed',
        kind: 'custom_tracker',
        name: 'My counter',
        description: 'Personal rules',
        colors: 'BG',
        value: 9,
        defaultValue: 2,
        isActive: true,
        artworkUrl: 'file:///private/test-art.jpg',
        configuration: {
          'tapIncrement': 3,
          'artworkOptions': [
            {'url': 'file:///private/test-art.jpg', 'artist': 'Local artist'},
          ],
        },
      ),
      UtilityState(id: 'projection', kind: 'life_total', name: 'Legacy life'),
      UtilityState(id: 'after', kind: 'custom_toggle', name: 'After'),
    ];
    f = TableFixture(state);
    await f.initialize();
    f.catalog.loaded = true;
  });
  tearDown(() => f.dispose());

  List<Map<String, dynamic>> utilities() =>
      f.player.utilities.map((u) => u.toJson()).toList();

  test(
    'Remove is persisted and History restores exact instance and order',
    () async {
      final before = utilities();
      final presets = PresetService(f.controller, f.catalog);
      await presets.save(f.playerId, 'Saved setup');
      final savedPresets = cloneJson({'presets': f.controller.state.decks});
      await f.board.removeUtility(f.playerId, 'removed');
      expect(f.player.utilities.map((u) => u.id), [
        'legacy-hidden',
        'projection',
        'after',
      ]);
      expect(f.player.utilities.first.toJson(), before.first);
      expect(f.controller.state.decks, savedPresets['presets']);
      expect(f.controller.session.history.last.label, 'Remove utility');

      final reopened = TableController(repository: f.repository);
      await reopened.initialize();
      addTearDown(reopened.dispose);
      expect(reopened.player(f.playerId).utilities.length, 3);
      expect(await reopened.undo(), isTrue);
      expect(
        reopened.player(f.playerId).utilities.map((u) => u.toJson()).toList(),
        before,
      );
      expect(reopened.state.decks, savedPresets['presets']);
    },
  );

  test('Remove and fresh Mana view preserve player mana and locks', () async {
    await f.board.addUtility(f.playerId, 'mana_pool');
    final mana = f.player.utilities.singleWhere((u) => u.kind == 'mana_pool');
    await f.controller.adjustMana(f.playerId, 'U', 7);
    await f.controller.updateState('Lock mana', (state) {
      state.session.player(f.playerId).manaLocks.add('U');
    });
    await f.board.setUtility(f.playerId, mana.id, name: 'Old pool', value: 9);
    await f.board.removeUtility(f.playerId, mana.id);
    await f.board.addUtility(f.playerId, 'mana_pool');
    final fresh = f.player.utilities.singleWhere((u) => u.kind == 'mana_pool');
    expect(fresh.id, isNot(mana.id));
    expect(fresh.name, 'Mana pool');
    expect(fresh.value, fresh.defaultValue);
    expect(f.player.mana['U'], 7);
    expect(f.player.manaLocks, {'U'});
  });

  test(
    'Hidden and built-in projections cannot be removed through board action',
    () async {
      final before = utilities();
      for (final id in ['legacy-hidden', 'projection', 'missing']) {
        await expectLater(
          f.board.removeUtility(f.playerId, id),
          throwsStateError,
        );
        expect(utilities(), before);
      }
    },
  );

  test(
    'Failed removal keeps complete visible state and persisted history',
    () async {
      final before = utilities();
      final encoded = f.repository.encoded;
      f.repository.failSave = true;
      await expectLater(
        f.board.removeUtility(f.playerId, 'removed'),
        throwsStateError,
      );
      expect(utilities(), before);
      expect(f.repository.encoded, encoded);
    },
  );
}
