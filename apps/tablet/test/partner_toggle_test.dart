import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<TableFixture> setup([TabletState? state]) async {
    final fixture = TableFixture(state);
    await fixture.initialize();
    addTearDown(fixture.dispose);
    return fixture;
  }

  test(
    'missing active flag imports as active and explicit false roundtrips',
    () {
      final source = CommanderSource.fromJson({
        'id': 'a',
        'ownerPlayerId': 'p',
        'name': 'Named',
      });
      expect(source.active, isTrue);
      source.active = false;
      expect(source.copy().toJson(), source.toJson());
      expect(source.copy().active, isFalse);
    },
  );

  test(
    'enable materializes exact implicit primary and is idempotent',
    () async {
      final f = await setup();
      final id = f.playerId;
      final primary = f.controller.session.commanderTrackingSources.first.id;
      expect(await f.controller.setHasPartner(id, true), isTrue);
      final sources = f.controller.session.commanders;
      expect(sources.map((s) => s.id).first, primary);
      expect(sources.map((s) => s.name), ['Commander', 'Partner']);
      expect(sources.map((s) => s.id).toSet(), hasLength(2));
      expect(f.controller.session.hasPartner(id), isTrue);
      final before = sources.map((s) => s.toJson()).toList();
      final history = f.controller.session.history.length;
      expect(await f.controller.setHasPartner(id, true), isTrue);
      expect(f.controller.session.commanders.map((s) => s.toJson()), before);
      expect(f.controller.session.history, hasLength(history));
    },
  );

  test('existing primary damage and name survive partner enable', () async {
    final f = await setup();
    final primary = f.controller.session.commanderTrackingSources.first.id;
    await f.controller.adjustCommanderDamage(f.playerId, primary, 7);
    await f.controller.renameCommander(primary, 'Same name');
    expect(await f.controller.setHasPartner(f.playerId, true), isTrue);
    expect(f.controller.session.commanders.first.id, primary);
    expect(f.controller.session.commanders.first.name, 'Same name');
    expect(f.player.commanderDamage[primary], 7);
    expect(f.player.life, 33);
  });

  test(
    'off blocks any recipient damage without changing state or history',
    () async {
      final f = await setup();
      await f.controller.setHasPartner(f.playerId, true);
      final partner = f.controller.session.commanders.last.id;
      final recipient = f.controller.session.players.last.id;
      await f.controller.setCommanderDamage(recipient, partner, 1);
      final before = f.controller.state.toJson();
      final persisted = f.repository.encoded;
      expect(await f.controller.setHasPartner(f.playerId, false), isFalse);
      expect(f.controller.error, contains('zero for everyone'));
      expect(f.controller.state.toJson(), before);
      expect(f.repository.encoded, persisted);
    },
  );

  test(
    'zero off hides only partner; reenable preserves ID name ledger and history',
    () async {
      final f = await setup();
      await f.controller.setHasPartner(f.playerId, true);
      final partner = f.controller.session.commanders.last.id;
      await f.controller.renameCommander(partner, 'My partner');
      await f.controller.setCommanderDamage(f.playerId, partner, 3);
      await f.controller.setCommanderDamage(f.playerId, partner, 0);
      final history = f.controller.session.history.length;
      expect(await f.controller.setHasPartner(f.playerId, false), isTrue);
      expect(f.controller.session.commanders, hasLength(2));
      expect(f.controller.session.commanders.last.active, isFalse);
      expect(f.controller.session.hasPartner(f.playerId), isFalse);
      expect(
        f.controller.session.commanderTrackingSources.any(
          (s) => s.id == partner,
        ),
        isFalse,
      );
      expect(f.player.commanderDamage[partner], 0);
      expect(f.controller.session.history, hasLength(history + 1));
      expect(
        await f.controller.adjustCommanderDamage(f.playerId, partner, 1),
        isFalse,
      );
      expect(
        await f.controller.setCommanderDamage(f.playerId, partner, 2),
        isFalse,
      );
      expect(await f.controller.setHasPartner(f.playerId, true), isTrue);
      expect(f.controller.session.commanders.last.id, partner);
      expect(f.controller.session.commanders.last.name, 'My partner');
      expect(f.controller.session.commanders.last.active, isTrue);
    },
  );

  test('21 warning is per source, never aggregate across partners', () async {
    final f = await setup();
    await f.controller.setHasPartner(f.playerId, true);
    final sources = f.controller.session.commanders;
    await f.controller.setCommanderDamage(f.playerId, sources[0].id, 11);
    await f.controller.setCommanderDamage(f.playerId, sources[1].id, 10);
    expect(f.player.warnings.any((s) => s.contains('21')), isFalse);
    await f.controller.setCommanderDamage(f.playerId, sources[1].id, 21);
    expect(f.player.warnings.any((s) => s.contains('21')), isTrue);
    expect(f.player.life, 40);
  });

  test(
    'undo off and on restores activation and implicit setup exactly',
    () async {
      final f = await setup();
      await f.controller.setHasPartner(f.playerId, true);
      final ids = f.controller.session.commanders.map((s) => s.id).toList();
      await f.controller.setHasPartner(f.playerId, false);
      expect(await f.controller.undo(), isTrue);
      expect(f.controller.session.hasPartner(f.playerId), isTrue);
      expect(f.controller.session.commanders.map((s) => s.id), ids);
      expect(await f.controller.undo(), isTrue);
      expect(f.controller.session.commanders, isEmpty);
      expect(
        f.controller.session.commanderTrackingSources.first.id,
        'default-commander:${f.playerId}',
      );
    },
  );

  for (final keepBoard in [false, true]) {
    test(
      'reset keepBoard=$keepBoard retains names/flags; archive restores IDs and undo',
      () async {
        final f = await setup();
        final oldPlayer = f.playerId;
        await f.controller.setHasPartner(oldPlayer, true);
        final partner = f.controller.session.commanders.last.id;
        await f.controller.renameCommander(partner, 'Retained partner');
        await f.controller.setHasPartner(oldPlayer, false);
        expect(await f.controller.resetGame(keepBoard: keepBoard), isTrue);
        expect(f.controller.session.commanders.map((s) => s.name), [
          'Commander',
          'Retained partner',
        ]);
        expect(f.controller.session.commanders.map((s) => s.active), [
          true,
          false,
        ]);
        expect(f.controller.session.commanders.last.id, isNot(partner));
        final archive = f.controller.state.archives.last;
        expect(await f.controller.restoreArchive(archive.id), isTrue);
        expect(f.controller.session.commanders.last.id, partner);
        expect(f.controller.session.commanders.last.active, isFalse);
        expect(await f.controller.undo(), isTrue);
        expect(f.controller.session.hasPartner(oldPlayer), isTrue);
      },
    );
  }

  test(
    'failed save preserves live/persisted state; reload preserves inactive identity',
    () async {
      final f = await setup();
      final before = f.controller.state.toJson();
      final encoded = f.repository.encoded;
      f.repository.failSave = true;
      expect(await f.controller.setHasPartner(f.playerId, true), isFalse);
      expect(f.controller.state.toJson(), before);
      expect(f.repository.encoded, encoded);
      f.repository.failSave = false;
      await f.controller.setHasPartner(f.playerId, true);
      final enabled = f.controller.state.toJson();
      final persistedEnabled = f.repository.encoded;
      f.repository.failSave = true;
      expect(await f.controller.setHasPartner(f.playerId, false), isFalse);
      expect(f.controller.state.toJson(), enabled);
      expect(f.repository.encoded, persistedEnabled);
      f.repository.failSave = false;
      await f.controller.setHasPartner(f.playerId, false);
      final sources = f.controller.session.commanders
          .map((s) => s.toJson())
          .toList();
      final reloaded = TableController(repository: f.repository);
      addTearDown(reloaded.dispose);
      await reloaded.initialize();
      expect(reloaded.session.commanders.map((s) => s.toJson()), sources);
      expect(reloaded.session.hasPartner(f.playerId), isFalse);
      expect(await reloaded.setHasPartner(f.playerId, true), isTrue);
      expect(reloaded.session.commanders.last.id, sources.last['id']);
    },
  );

  test(
    'three-plus explicit legacy sources are not capped dropped or hidden',
    () async {
      final f = await setup();
      for (final name in ['One', 'Two', 'Three']) {
        await f.controller.addCommander(f.playerId, name);
      }
      final sources = f.controller.session.commanders
          .map((s) => s.toJson())
          .toList();
      expect(await f.controller.setHasPartner(f.playerId, true), isTrue);
      expect(await f.controller.setHasPartner(f.playerId, false), isFalse);
      expect(f.controller.error, contains('individually'));
      expect(f.controller.session.commanders.map((s) => s.toJson()), sources);
      expect(
        f.controller.session.commanderTrackingSources.where(
          (s) => s.ownerPlayerId == f.playerId,
        ),
        hasLength(3),
      );
    },
  );

  test(
    'all-inactive imported owner never acquires a different implicit identity',
    () async {
      final state = TabletState.initial();
      final owner = state.session.players.first.id;
      state.session.commanders.add(
        CommanderSource(
          id: 'old-primary',
          ownerPlayerId: owner,
          name: 'Imported',
          active: false,
        ),
      );
      final f = await setup(state);
      expect(
        f.controller.session.commanderTrackingSources.where(
          (s) => s.ownerPlayerId == owner,
        ),
        isEmpty,
      );
      expect(await f.controller.setHasPartner(owner, true), isTrue);
      expect(f.controller.session.commanders.first.id, 'old-primary');
      expect(f.controller.session.commanders.first.name, 'Imported');
      expect(f.controller.session.hasPartner(owner), isTrue);
    },
  );
}
