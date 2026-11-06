import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/board_service.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/board_reorder_feedback.dart';

import 'support/table_fixture.dart';

class _GateRepository extends MemoryTableRepository {
  _GateRepository(super.state);
  bool blocked = true;
  final writes = <Completer<bool>>[];
  @override
  Future<void> save(TabletState state) async {
    if (blocked) {
      final gate = Completer<bool>();
      writes.add(gate);
      if (!await gate.future) throw StateError('Injected write failure');
    }
    await super.save(state);
  }
}

void main() {
  late _GateRepository repository;
  late TableController controller;
  late TabletCatalog catalog;
  late BoardService board;
  late BoardReorderFeedback feedback;
  late String playerId;
  List<String> displayed() => feedback.tokens.map((t) => t.id).toList();
  List<String> canonical() =>
      controller.player(playerId).tokens.map((t) => t.id).toList();
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    repository = _GateRepository(
      stateWithTokens([
        for (final id in ['a', 'b', 'c']) sampleToken(id: id, name: id),
      ]),
    );
    controller = TableController(repository: repository);
    await controller.initialize();
    catalog = TabletCatalog(controller);
    board = BoardService(controller, catalog);
    playerId = controller.session.players.first.id;
    feedback = BoardReorderFeedback(board, playerId: playerId);
  });
  tearDown(() {
    feedback.dispose();
    catalog.dispose();
    controller.dispose();
  });

  test(
    'drop projects synchronously; durable data and undo change only after acknowledgement',
    () async {
      final before = controller
          .player(playerId)
          .tokens
          .map((t) => jsonEncode(t.toJson()))
          .toList();
      final otherSeats = controller.session.players
          .skip(1)
          .map((p) => jsonEncode(p.toJson()))
          .toList();
      final save = feedback.reorderTokens(0, 2);
      expect(displayed(), ['b', 'a', 'c']);
      expect(canonical(), ['a', 'b', 'c']);
      expect(controller.session.history, isEmpty);
      await flush();
      repository.writes.single.complete(true);
      await save;
      expect(displayed(), canonical());
      expect(canonical(), ['b', 'a', 'c']);
      expect(controller.session.history, hasLength(1));
      expect(
        controller.player(playerId).tokens.map((t) => jsonEncode(t.toJson())),
        [before[1], before[0], before[2]],
      );
      expect(
        controller.session.players.skip(1).map((p) => jsonEncode(p.toJson())),
        otherSeats,
      );
      expect(
        (await repository.open()).state.session
            .player(playerId)
            .tokens
            .map((t) => t.id),
        canonical(),
      );
      repository.blocked = false;
      expect(await controller.undo(), isTrue);
      expect(displayed(), ['a', 'b', 'c']);
    },
  );

  for (final firstSucceeds in [true, false]) {
    test(
      'newer drag stays displayed after earlier ${firstSucceeds ? 'success' : 'failure'}',
      () async {
        final first = feedback.reorderTokens(0, 3);
        final firstResult = first.then(
          (_) => true,
          onError: (Object _) => false,
        );
        final second = feedback.reorderTokens(0, 2);
        expect(displayed(), ['c', 'b', 'a']);
        await flush();
        repository.writes[0].complete(firstSucceeds);
        expect(await firstResult, firstSucceeds);
        await flush();
        expect(displayed(), ['c', 'b', 'a']);
        expect(canonical(), firstSucceeds ? ['b', 'c', 'a'] : ['a', 'b', 'c']);
        repository.writes[1].complete(true);
        await second;
        expect(canonical(), ['c', 'b', 'a']);
        expect(displayed(), canonical());
        expect(controller.session.history, hasLength(firstSucceeds ? 2 : 1));
      },
    );
  }

  test(
    'failed final drop restores durable order and does not create history',
    () async {
      final result = feedback
          .reorderTokens(0, 3)
          .then((_) => true, onError: (Object _) => false);
      expect(displayed(), ['b', 'c', 'a']);
      await flush();
      repository.writes.single.complete(false);
      expect(await result, isFalse);
      expect(displayed(), ['a', 'b', 'c']);
      expect(controller.session.history, isEmpty);
      expect(controller.error, contains('Injected write failure'));
    },
  );

  test(
    'visible utilities project while hidden and legacy slots remain exact',
    () async {
      repository.blocked = false;
      await controller.commit(
        'Seed utilities',
        playerId: playerId,
        mutate: (s) {
          s.player(playerId).utilities = [
            UtilityState(id: 'u1', name: 'Tool 1', value: 3),
            UtilityState(
              id: 'hidden',
              name: 'Hidden',
              visible: false,
              value: 19,
            ),
            UtilityState(id: 'u2', name: 'Tool 2', value: 7),
            UtilityState(
              id: 'legacy',
              name: 'Legacy',
              kind: 'life_total',
              value: 41,
            ),
          ];
        },
      );
      final before = controller
          .player(playerId)
          .utilities
          .map((u) => jsonEncode(u.toJson()))
          .toList();
      repository.blocked = true;
      final save = feedback.reorderUtilities(0, 2);
      expect(feedback.utilities.map((u) => u.id), ['u2', 'u1']);
      expect(controller.player(playerId).utilities.map((u) => u.id), [
        'u1',
        'hidden',
        'u2',
        'legacy',
      ]);
      await flush();
      repository.writes.single.complete(true);
      await save;
      expect(
        controller
            .player(playerId)
            .utilities
            .map((u) => jsonEncode(u.toJson())),
        [before[2], before[1], before[0], before[3]],
      );
    },
  );

  test(
    'queued removal invalidates stale IDs without resurrecting the token',
    () async {
      final removal = controller.commit(
        'Remove b',
        playerId: playerId,
        mutate: (s) {
          s.player(playerId).tokens.removeWhere((t) => t.id == 'b');
        },
      );
      final reorder = feedback
          .reorderTokens(0, 3)
          .then((_) => true, onError: (Object _) => false);
      await flush();
      repository.writes.single.complete(true);
      expect(await removal, isTrue);
      expect(await reorder, isFalse);
      expect(displayed(), ['a', 'c']);
      expect(canonical(), ['a', 'c']);
      expect(controller.error, contains('Tokens changed'));
    },
  );

  test(
    'player generation change clears pending projection and rejects stale command',
    () async {
      final reset = controller.commit(
        'Clear board',
        playerId: playerId,
        mutate: (s) {
          s.player(playerId).generation++;
          s.player(playerId).tokens = [sampleToken(id: 'new')];
        },
      );
      final reorder = feedback
          .reorderTokens(0, 3)
          .then((_) => true, onError: (Object _) => false);
      expect(displayed(), ['b', 'c', 'a']);
      await flush();
      repository.writes.single.complete(true);
      expect(await reset, isTrue);
      expect(await reorder, isFalse);
      expect(displayed(), ['new']);
      expect(canonical(), ['new']);
    },
  );

  test('invalid identity lists never mutate durable state', () async {
    repository.blocked = false;
    for (final ids in [
      ['a', 'a', 'c'],
      ['a', 'c'],
      ['a', 'b', 'unknown'],
    ]) {
      await expectLater(board.reorderTokens(playerId, ids), throwsStateError);
      expect(canonical(), ['a', 'b', 'c']);
    }
    expect(controller.session.history, isEmpty);
  });

  test('no-op drop creates no save or history entry', () async {
    await feedback.reorderTokens(1, 2);
    expect(repository.writes, isEmpty);
    expect(controller.session.history, isEmpty);
    expect(displayed(), ['a', 'b', 'c']);
  });
}
