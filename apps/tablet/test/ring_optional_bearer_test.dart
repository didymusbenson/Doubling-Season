import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/ring_service.dart';
import 'package:tripling_table/state/table_controller.dart';

import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture fixture;
  late RingService ring;
  late String utilityId;

  UtilityState utility() =>
      fixture.player.utilities.firstWhere((utility) => utility.id == utilityId);

  setUp(() async {
    fixture = TableFixture();
    await fixture.initialize();
    fixture.catalog.loaded = true;
    await fixture.board.addUtility(fixture.playerId, RingService.kind);
    utilityId = fixture.player.utilities.last.id;
    ring = RingService(fixture.controller);
  });

  tearDown(() => fixture.dispose());

  test(
    'an untracked physical bearer needs no token or name to progress',
    () async {
      expect(fixture.player.tokens, isEmpty);
      final otherSeat = cloneJson(
        fixture.controller.session.players.last.toJson(),
      );
      final configuration = cloneJson(utility().configuration);
      final history = fixture.controller.session.history.length;

      for (var count = 1; count <= 5; count++) {
        await ring.tempt(fixture.playerId, utilityId);
        expect(utility().value, count);
        expect(RingService.stage(utility()), count.clamp(0, 4));
        expect(RingService.bearer(utility()), isEmpty);
        expect(utility().configuration, configuration);
      }

      expect(fixture.player.tokens, isEmpty);
      expect(fixture.controller.session.players.last.toJson(), otherSeat);
      expect(fixture.controller.session.history.length, history + 5);
      await fixture.controller.undo();
      expect(utility().value, 4);
      expect(fixture.player.tokens, isEmpty);
    },
  );

  test(
    'blank optional notes are accepted and omission preserves a name',
    () async {
      await ring.tempt(fixture.playerId, utilityId, bearer: '');
      expect(utility().value, 1);
      expect(RingService.bearer(utility()), isEmpty);

      await ring.tempt(
        fixture.playerId,
        utilityId,
        bearer: '  Physical commander  ',
      );
      await ring.tempt(fixture.playerId, utilityId);
      expect(utility().value, 3);
      expect(RingService.bearer(utility()), 'Physical commander');

      await ring.tempt(fixture.playerId, utilityId, bearer: '  ');
      expect(utility().value, 4);
      expect(RingService.bearer(utility()), isEmpty);
      await fixture.controller.undo();
      expect(utility().value, 3);
      expect(RingService.bearer(utility()), 'Physical commander');

      await ring.clearBearer(fixture.playerId, utilityId);
      expect(utility().value, 3);
      expect(RingService.bearer(utility()), isEmpty);
      await fixture.controller.undo();
      expect(RingService.bearer(utility()), 'Physical commander');
      expect(fixture.player.tokens, isEmpty);
    },
  );

  test(
    'legacy bearer notes load unchanged and stay optional after reload',
    () async {
      await fixture.controller.commit(
        'Legacy Ring fixture',
        playerId: fixture.playerId,
        mutate: (session) {
          final saved = session
              .player(fixture.playerId)
              .utilities
              .firstWhere((utility) => utility.id == utilityId);
          saved.value = 3;
          saved.configuration.addAll({
            RingService.bearerKey: 'Existing physical creature',
            'legacyNote': {'keep': true},
          });
        },
      );
      final encodedBefore = fixture.repository.encoded;
      final savedBefore = cloneJson(utility().toJson());
      final reopened = TableController(repository: fixture.repository);
      addTearDown(reopened.dispose);
      await reopened.initialize();
      final saved = reopened
          .player(fixture.playerId)
          .utilities
          .firstWhere((utility) => utility.id == utilityId);
      expect(saved.toJson(), savedBefore);
      expect(fixture.repository.encoded, encodedBefore);

      await RingService(reopened).tempt(fixture.playerId, utilityId);
      final progressed = reopened
          .player(fixture.playerId)
          .utilities
          .firstWhere((utility) => utility.id == utilityId);
      expect(progressed.value, 4);
      expect(RingService.bearer(progressed), 'Existing physical creature');
      expect(progressed.configuration['legacyNote'], {'keep': true});
      expect(reopened.player(fixture.playerId).tokens, isEmpty);
    },
  );

  test(
    'removing a named token cannot block Ring progress or clearing notes',
    () async {
      await fixture.controller.commit(
        'Token fixture',
        playerId: fixture.playerId,
        mutate: (session) => session
            .player(fixture.playerId)
            .tokens
            .add(sampleToken(id: 'bearer-token', name: 'Squirrel', amount: 1)),
      );
      // Existing Ring notes store text, not a reference to a token ID.
      await ring.tempt(fixture.playerId, utilityId, bearer: 'Squirrel');
      await fixture.board.deleteToken(fixture.playerId, 'bearer-token');
      expect(fixture.player.tokens, isEmpty);
      await ring.tempt(fixture.playerId, utilityId);
      expect(utility().value, 2);
      expect(RingService.bearer(utility()), 'Squirrel');
      await ring.clearBearer(fixture.playerId, utilityId);
      await ring.tempt(fixture.playerId, utilityId);
      expect(utility().value, 3);
      expect(RingService.bearer(utility()), isEmpty);
      expect(fixture.player.tokens, isEmpty);
    },
  );

  test(
    'progress correction does not require or discard optional bearer notes',
    () async {
      await ring.correct(fixture.playerId, utilityId, temptations: 2);
      expect(utility().value, 2);
      expect(RingService.bearer(utility()), isEmpty);
      await ring.correct(
        fixture.playerId,
        utilityId,
        temptations: 3,
        bearer: 'Named creature',
      );
      await ring.correct(fixture.playerId, utilityId, temptations: 1);
      expect(utility().value, 1);
      expect(RingService.bearer(utility()), 'Named creature');
      await ring.correct(
        fixture.playerId,
        utilityId,
        temptations: 0,
        bearer: '',
      );
      expect(RingService.bearer(utility()), isEmpty);
    },
  );

  test(
    'failed untracked temptation leaves state and durable data unchanged',
    () async {
      final before = cloneJson(utility().toJson());
      final encodedBefore = fixture.repository.encoded;
      fixture.repository.failSave = true;
      await expectLater(
        ring.tempt(fixture.playerId, utilityId),
        throwsStateError,
      );
      expect(utility().toJson(), before);
      expect(fixture.repository.encoded, encodedBefore);
    },
  );
}
