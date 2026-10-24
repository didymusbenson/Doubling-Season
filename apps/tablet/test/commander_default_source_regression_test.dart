import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture f;
  setUp(() async {
    f = TableFixture();
    await f.initialize();
  });
  tearDown(() => f.dispose());
  test(
    'projection is pure, stable, and includes each owner with partial partners',
    () async {
      final before = f.controller.session.toJson();
      final ids = f.controller.session.commanderTrackingSources
          .map((s) => s.id)
          .toList();
      expect(ids.length, 4);
      expect(
        f.controller.session.commanderTrackingSources.map((s) => s.id),
        ids,
      );
      expect(f.controller.session.toJson(), before);
      await f.controller.addCommander(f.playerId, 'Same');
      await f.controller.addCommander(f.playerId, 'Same');
      final sources = f.controller.session.commanderTrackingSources;
      expect(sources.length, 5);
      expect(sources.map((s) => s.ownerPlayerId).toSet().length, 4);
      expect(sources.map((s) => s.id).toSet().length, 5);
    },
  );
  test(
    'rapid first hits create once, couple once, persist identity, undo atomically',
    () async {
      final source = f.controller.session.commanderTrackingSources.last;
      final life = f.player.life;
      final results = await Future.wait(
        List.generate(
          5,
          (_) => f.controller.adjustCommanderDamage(f.playerId, source.id, 1),
        ),
      );
      expect(results, everyElement(isTrue));
      expect(f.controller.session.commanders.single.id, source.id);
      expect(f.player.life, life - 5);
      expect(f.player.commanderDamage[source.id], 5);
      final reopened = TableController(repository: f.repository);
      await reopened.initialize();
      expect(reopened.session.commanders.single.id, source.id);
      expect(await reopened.undo(), isTrue);
      expect(reopened.session.commanders, isEmpty);
      expect(reopened.player(f.playerId).life, life);
      expect(reopened.session.commanderTrackingSources.last.id, source.id);
      reopened.dispose();
    },
  );
  test('zero minus never creates source, damage key, or history', () async {
    final source = f.controller.session.commanderTrackingSources.first;
    final before = (f.controller.session.toJson()
      ..remove('revision')
      ..remove('completedCommandIds'));
    await f.controller.adjustCommanderDamage(f.playerId, source.id, -1);
    expect(
      (f.controller.session.toJson()
        ..remove('revision')
        ..remove('completedCommandIds')),
      before,
    );
    await f.controller.addCommander(f.playerId, 'Configured');
    final configured = f.controller.session.commanders.single;
    final configuredBefore = (f.controller.session.toJson()
      ..remove('revision')
      ..remove('completedCommandIds'));
    await f.controller.adjustCommanderDamage(f.playerId, configured.id, -5);
    expect(
      (f.controller.session.toJson()
        ..remove('revision')
        ..remove('completedCommandIds')),
      configuredBefore,
    );
  });
  test(
    'first ledger-only correction creates source but never changes life',
    () async {
      final source = f.controller.session.commanderTrackingSources.last;
      final life = f.player.life;
      await f.controller.setCommanderDamage(f.playerId, source.id, 7);
      expect(f.player.life, life);
      expect(f.player.commanderDamage[source.id], 7);
      expect(f.controller.session.commanders.single.id, source.id);
      await f.controller.undo();
      expect(f.player.life, life);
      expect(f.controller.session.commanders, isEmpty);
    },
  );
  test(
    'failed first hit is atomic and retry uses same default identity',
    () async {
      final source = f.controller.session.commanderTrackingSources.last;
      final before = f.controller.session.toJson();
      f.repository.failSave = true;
      expect(
        await f.controller.adjustCommanderDamage(f.playerId, source.id, 1),
        isFalse,
      );
      expect(f.controller.session.toJson(), before);
      f.repository.failSave = false;
      expect(
        await f.controller.adjustCommanderDamage(f.playerId, source.id, 1),
        isTrue,
      );
      expect(f.controller.session.commanders.single.id, source.id);
    },
  );
  test(
    'reset owner projection covers all current seats despite prior partial setup',
    () async {
      await f.controller.addCommander(
        f.controller.session.players.last.id,
        'Partner',
      );
      await f.controller.resetGame(
        playerCount: 2,
        startingLife: 40,
        keepBoard: false,
      );
      final sources = f.controller.session.commanderTrackingSources;
      expect(
        sources.map((s) => s.ownerPlayerId).toSet(),
        f.controller.session.players.map((p) => p.id).toSet(),
      );
      expect(sources.length, 2);
      expect(
        f.controller.session.players.every((p) => p.commanderDamage.isEmpty),
        isTrue,
      );
    },
  );
  test(
    'partners and self remain distinct and clamped refunds only restore recorded damage',
    () async {
      await f.controller.addCommander(f.playerId, 'Same');
      await f.controller.addCommander(f.playerId, 'Same');
      final a = f.controller.session.commanders[0];
      final b = f.controller.session.commanders[1];
      await f.controller.adjustCommanderDamage(f.playerId, a.id, 3);
      await f.controller.adjustCommanderDamage(f.playerId, b.id, 2);
      expect(f.player.life, 35);
      expect(f.player.commanderDamage[a.id], 3);
      expect(f.player.commanderDamage[b.id], 2);
      expect(f.controller.session.history.last.summary, contains('Same #2'));
      await f.controller.adjustCommanderDamage(f.playerId, a.id, -25);
      expect(f.player.life, 38);
      expect(f.player.commanderDamage[a.id], 0);
      expect(f.player.commanderDamage[b.id], 2);
      expect(f.controller.session.history.last.commands.single.delta, -3);
      await f.controller.undo();
      expect(f.player.life, 35);
      expect(f.player.commanderDamage[a.id], 3);
      expect(f.controller.session.commanders.length, 2);
    },
  );
}
