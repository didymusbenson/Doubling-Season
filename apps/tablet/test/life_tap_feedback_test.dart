import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/life_tap_feedback.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

/// Hold actual serialized saves, not a synthetic animation timer.
class _GateRepository extends MemoryTableRepository {
  _GateRepository(super.state);
  bool blocked = true;
  int saveAttempts = 0;
  final writes = <Completer<bool>>[];

  @override
  Future<void> save(TabletState state) async {
    saveAttempts++;
    if (blocked) {
      final receipt = Completer<bool>();
      writes.add(receipt);
      if (!await receipt.future) throw StateError('Injected write failure');
    }
    await super.save(state);
  }

  void finish(int index, {bool saved = true}) => writes[index].complete(saved);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'life-feedback-catalog-',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });
  late _GateRepository repository;
  late TableController controller;
  late LifeTapFeedback feedback;
  late String playerId;

  Future<void> initialize() async {
    repository = _GateRepository(TabletState.initial());
    controller = TableController(repository: repository);
    await controller.initialize();
    playerId = controller.session.players.first.id;
    feedback = LifeTapFeedback(controller, playerId: playerId);
  }

  tearDown(() {
    feedback.dispose();
    controller.dispose();
  });

  Widget surface({bool preview = true}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          child: AnimatedBuilder(
            animation: preview ? feedback : controller,
            builder: (context, _) => HalfStepper(
              label: 'Life',
              value:
                  '${preview ? feedback.life : controller.player(playerId).life}',
              valueWidget: Text(
                '${preview ? feedback.life : controller.player(playerId).life}',
                key: const ValueKey('rendered-life'),
              ),
              decreaseKey: const ValueKey('life-decrease'),
              increaseKey: const ValueKey('life-increase'),
              height: 120,
              onDecrease: () => preview
                  ? feedback.adjust(-1)
                  : controller.adjustLife(playerId, -1),
              onIncrease: () => preview
                  ? feedback.adjust(1)
                  : controller.adjustLife(playerId, 1),
              onDecreaseHoldStep: (amount) async {
                await feedback.adjust(-amount);
              },
              onIncreaseHoldStep: (amount) async {
                await feedback.adjust(amount);
              },
              holdStep: 10,
            ),
          ),
        ),
      ),
    ),
  );

  String rendered(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('rendered-life'))).data!;

  Future<void> drain(WidgetTester tester) async {
    repository.blocked = false;
    for (final write in repository.writes) {
      if (!write.isCompleted) write.complete(true);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('durable-only baseline stays stale throughout a held save', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(surface(preview: false));
    await tester.tap(find.byKey(const ValueKey('life-increase')));
    for (final milliseconds in [16, 80, 300]) {
      await tester.pump(Duration(milliseconds: milliseconds));
      expect(rendered(tester), '40');
      expect(controller.player(playerId).life, 40);
      expect(repository.writes, hasLength(1));
    }
    repository.finish(0);
    await tester.pump();
    expect(rendered(tester), '41');
  });

  testWidgets('tap release paints next frame without waiting for long press', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(surface());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('life-increase'))),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(feedback.hasPending, isFalse);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(rendered(tester), '41');
    expect(controller.player(playerId).life, 40);
    expect(feedback.pendingDelta, 1);
    expect(repository.writes, hasLength(1));
    for (final milliseconds in [80, 300]) {
      await tester.pump(Duration(milliseconds: milliseconds));
      expect(rendered(tester), '41');
      expect(controller.player(playerId).life, 40);
    }
    await drain(tester);
    expect(rendered(tester), '41');
    expect(feedback.hasPending, isFalse);
    expect((await repository.open()).state.session.player(playerId).life, 41);
  });

  testWidgets('exact receipts prevent publication and delta double counting', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(surface());
    final observed = <(int, int, int)>[];
    controller.addListener(() {
      observed.add((
        controller.player(playerId).life,
        feedback.pendingDelta,
        feedback.life,
      ));
    });
    final first = feedback.adjust(1), second = feedback.adjust(1);
    await tester.pump();
    expect(rendered(tester), '42');
    repository.finish(0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(await first, isTrue);
    expect(rendered(tester), '42');
    expect(
      feedback.displayDelta(controller.session.history.last.totalDelta),
      2,
    );
    expect(controller.player(playerId).life, 41);
    expect(feedback.pendingDelta, 1);
    repository.finish(1);
    await tester.pump(const Duration(milliseconds: 16));
    expect(await second, isTrue);
    expect(rendered(tester), '42');
    expect(
      feedback.displayDelta(controller.session.history.last.totalDelta),
      2,
    );
    expect(
      observed.any((sample) => sample.$1 == 41 && sample.$3 == 43),
      isFalse,
    );
    expect(
      observed.any((sample) => sample.$1 == 42 && sample.$3 != 42),
      isFalse,
    );
  });

  testWidgets(
    'rapid opposite and multiple-seat taps remain independently exact',
    (tester) async {
      await initialize();
      await tester.pumpWidget(surface());
      final otherId = controller.session.players.last.id;
      final other = LifeTapFeedback(controller, playerId: otherId);
      addTearDown(other.dispose);
      final saves = [
        feedback.adjust(1),
        other.adjust(-1),
        feedback.adjust(1),
        feedback.adjust(-1),
        other.adjust(-1),
      ];
      await tester.pump(const Duration(milliseconds: 16));
      expect(feedback.life, 41);
      expect(other.life, 38);
      expect(controller.player(playerId).life, 40);
      expect(controller.player(otherId).life, 40);
      for (var i = 0; i < saves.length; i++) {
        repository.finish(i);
        await tester.pump(const Duration(milliseconds: 16));
        expect(feedback.life, 41);
        expect(other.life, 38);
      }
      expect(await Future.wait(saves), everyElement(isTrue));
      final reopened = (await repository.open()).state.session;
      expect(reopened.player(playerId).life, 41);
      expect(reopened.player(otherId).life, 38);
    },
  );

  for (final failedIndex in [0, 1]) {
    testWidgets(
      'failure $failedIndex removes only its own receipt, not newer taps',
      (tester) async {
        await initialize();
        await tester.pumpWidget(surface());
        final saves = [
          feedback.adjust(1),
          feedback.adjust(1),
          feedback.adjust(1),
        ];
        await tester.pump(const Duration(milliseconds: 16));
        expect(rendered(tester), '43');
        for (var i = 0; i < saves.length; i++) {
          repository.finish(i, saved: i != failedIndex);
          await tester.pump(const Duration(milliseconds: 16));
          expect(rendered(tester), i < failedIndex ? '43' : '42');
        }
        expect(await Future.wait(saves), [
          for (var i = 0; i < 3; i++) i != failedIndex,
        ]);
        expect(feedback.life, 42);
        expect(feedback.error, contains('not saved'));
        expect(
          (await repository.open()).state.session.player(playerId).life,
          42,
        );
        repository.blocked = false;
        expect(await feedback.adjust(1), isTrue);
        expect(feedback.life, 43);
        expect(
          feedback.error,
          isNotNull,
          reason: 'Success must not erase an unseen failure.',
        );
        feedback.clearError();
        expect(feedback.error, isNull);
      },
    );
  }

  testWidgets('undo behind pending taps sees only durable history', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(surface());
    final first = feedback.adjust(1),
        second = feedback.adjust(1),
        undo = controller.undo();
    await tester.pump();
    expect(controller.session.history, isEmpty);
    expect(feedback.life, 42);
    repository.finish(0);
    await tester.pump();
    repository.finish(1);
    await tester.pump();
    expect(feedback.life, 42);
    expect(controller.player(playerId).life, 42);
    repository.finish(2);
    await tester.pump();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(await undo, isTrue);
    expect(feedback.life, 40);
    expect(feedback.hasPending, isFalse);
    expect(controller.session.history.single.undone, isTrue);
  });

  testWidgets(
    'tap behind Undo rebases onto committed life without disappearing',
    (tester) async {
      await initialize();
      repository.blocked = false;
      expect(await controller.adjustLife(playerId, 1), isTrue);
      repository.blocked = true;
      await tester.pumpWidget(surface());
      final undo = controller.undo(), next = feedback.adjust(1);
      await tester.pump();
      expect(feedback.life, 42);
      repository.finish(0);
      await tester.pump(const Duration(milliseconds: 16));
      expect(await undo, isTrue);
      expect(controller.player(playerId).life, 40);
      expect(feedback.life, 41);
      expect(feedback.hasPending, isTrue);
      repository.finish(1);
      await tester.pump(const Duration(milliseconds: 16));
      expect(await next, isTrue);
      expect(feedback.life, 41);
      expect(feedback.hasPending, isFalse);
      expect(feedback.error, isNull);
    },
  );

  testWidgets(
    'reset rejects old session tap without leaking a receipt or warning',
    (tester) async {
      await initialize();
      await tester.pumpWidget(surface());
      final first = feedback.adjust(1);
      final reset = controller.resetGame(keepBoard: true, startingLife: 20);
      final stale = feedback.adjust(1);
      await tester.pump();
      expect(feedback.life, 42);
      repository.finish(0);
      await tester.pump();
      expect(await first, isTrue);
      repository.finish(1);
      await tester.pump();
      expect(await reset, isTrue);
      expect(await stale, isFalse);
      expect(feedback.hasPending, isFalse);
      expect(feedback.error, isNull);
      final replacement = LifeTapFeedback(
        controller,
        playerId: controller.session.players.first.id,
      );
      addTearDown(replacement.dispose);
      expect(replacement.life, 20);
      expect(repository.writes, hasLength(2));
    },
  );

  testWidgets('same-player preset replacement rebases accepted pending tap', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(surface());
    final replace = controller.updateState('Replace board', (draft) {
      draft.session.player(playerId).generation++;
      draft.session.player(playerId).life = 17;
    });
    final next = feedback.adjust(1);
    await tester.pump();
    expect(feedback.life, 41);
    repository.finish(0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(await replace, isTrue);
    expect(feedback.hasPending, isTrue);
    expect(feedback.life, 18);
    repository.finish(1);
    await tester.pump();
    expect(await next, isTrue);
    expect(feedback.life, 18);
  });

  testWidgets(
    'old failure warning clears on same-player generation replacement',
    (tester) async {
      await initialize();
      final failed = feedback.adjust(1);
      await tester.pump();
      repository.finish(0, saved: false);
      await tester.pump();
      expect(await failed, isFalse);
      expect(feedback.error, isNotNull);
      repository.blocked = false;
      expect(
        await controller.updateState('Replace board', (draft) {
          draft.session.player(playerId).generation++;
        }),
        isTrue,
      );
      expect(feedback.error, isNull);
    },
  );

  testWidgets('dispose/unmount preserves accepted durable save', (
    tester,
  ) async {
    await initialize();
    final detached = LifeTapFeedback(controller, playerId: playerId);
    final save = detached.adjust(1);
    await tester.pump();
    detached.dispose();
    await tester.pumpWidget(const SizedBox());
    repository.finish(0);
    await tester.pump();
    expect(await save, isTrue);
    expect(controller.player(playerId).life, 41);
    expect((await repository.open()).state.session.player(playerId).life, 41);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'background cancels hold repeats, not the accepted life receipt',
    (tester) async {
      await initialize();
      await tester.pumpWidget(surface());
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('life-increase'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(feedback.life, 50);
      expect(controller.player(playerId).life, 40);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      repository.finish(0);
      await tester.pump(const Duration(seconds: 2));
      expect(feedback.life, 50);
      expect(repository.writes, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(feedback.life, 50);
      expect(
        repository.writes,
        hasLength(1),
        reason: 'Hold release must not produce a trailing tap.',
      );
    },
  );

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets(
      'actual table paints each rotated seat before durable save at $size',
      (tester) async {
        await initialize();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: tableTheme(Brightness.dark),
            home: TableScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        final ids = controller.session.players
            .map((player) => player.id)
            .toList();
        for (final id in ids) {
          await tester.tap(find.byKey(ValueKey('$id-life-increase')));
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.widget<Text>(find.byKey(ValueKey('$id-life-number'))).data,
            '41',
          );
          expect(controller.player(id).life, 40);
          expect(
            tester
                .widget<HalfStepper>(
                  find.ancestor(
                    of: find.byKey(ValueKey('$id-life-increase')),
                    matching: find.byType(HalfStepper),
                  ),
                )
                .value,
            '41',
          );
        }
        expect(repository.writes, hasLength(1));
        await drain(tester);
        for (final id in ids) {
          expect(
            tester.widget<Text>(find.byKey(ValueKey('$id-life-number'))).data,
            '41',
          );
          expect(controller.player(id).life, 41);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'actual table removes only failed tap and retains visible warning',
    (tester) async {
      await initialize();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1133, 744);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(ValueKey('$playerId-life-increase')));
      }
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.widget<Text>(find.byKey(ValueKey('$playerId-life-number'))).data,
        '43',
      );
      repository.finish(0, saved: false);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.widget<Text>(find.byKey(ValueKey('$playerId-life-number'))).data,
        '42',
      );
      expect(
        find.textContaining('A life change was not saved.'),
        findsOneWidget,
      );
      await drain(tester);
      expect(controller.player(playerId).life, 42);
      expect(
        find.textContaining('A life change was not saved.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ValueKey('$playerId-life-increase')));
      await tester.pumpAndSettle();
      expect(controller.player(playerId).life, 43);
      expect(
        find.textContaining('A life change was not saved.'),
        findsOneWidget,
      );
      final beforeAcknowledgement = controller.state.toJson();
      final writesBeforeAcknowledgement = repository.saveAttempts;
      final acknowledge = find.byKey(
        ValueKey('$playerId-acknowledge-life-error'),
      );
      expect(tester.getSize(acknowledge), const Size(44, 44));
      await tester.tap(acknowledge);
      await tester.pumpAndSettle();
      expect(find.textContaining('A life change was not saved.'), findsNothing);
      expect(controller.state.toJson(), beforeAcknowledgement);
      expect(
        repository.saveAttempts,
        writesBeforeAcknowledgement,
        reason: 'Acknowledging feedback must not retry or mutate gameplay.',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'archive restore with same player IDs drops old session receipts',
    (tester) async {
      await initialize();
      repository.blocked = false;
      expect(
        await controller.updateState('Save archive fixture', (draft) {
          draft.archives.add(
            GameArchive(
              id: 'saved',
              label: 'Saved game',
              savedAt: DateTime.now().toUtc(),
              session: draft.session.copy(),
              playerLabels: {
                for (final player in draft.session.players) player.id: 'Player',
              },
            ),
          );
        }),
        isTrue,
      );
      expect(await controller.adjustLife(playerId, 5), isTrue);
      repository.blocked = true;
      final restore = controller.restoreArchive('saved');
      final stale = feedback.adjust(1);
      await tester.pump();
      expect(feedback.life, 46);
      repository.finish(0);
      await tester.pump();
      expect(await restore, isTrue);
      expect(await stale, isFalse);
      expect(feedback.life, 40);
      expect(feedback.hasPending, isFalse);
      expect(feedback.error, isNull);
      expect(repository.writes, hasLength(1));
    },
  );

  testWidgets(
    'reloaded controller starts from acknowledged total without receipts',
    (tester) async {
      await initialize();
      final save = feedback.adjust(1);
      await tester.pump();
      expect(feedback.life, 41);
      final duringSave = TableController(repository: repository);
      await duringSave.initialize();
      expect(duringSave.player(playerId).life, 40);
      duringSave.dispose();
      repository.finish(0);
      await tester.pump();
      expect(await save, isTrue);
      final reopened = TableController(repository: repository);
      await reopened.initialize();
      final fresh = LifeTapFeedback(reopened, playerId: playerId);
      expect(fresh.life, 41);
      expect(fresh.hasPending, isFalse);
      expect(fresh.displayDelta(null), isNull);
      fresh.dispose();
      reopened.dispose();
    },
  );

  testWidgets('optional life receipt ID preserves command idempotence', (
    tester,
  ) async {
    await initialize();
    repository.blocked = false;
    expect(
      await controller.adjustLife(playerId, 1, commandId: 'same-life-command'),
      isTrue,
    );
    expect(
      await controller.adjustLife(playerId, 1, commandId: 'same-life-command'),
      isTrue,
    );
    expect(controller.player(playerId).life, 41);
    expect(controller.session.history.single.commands, hasLength(1));
    expect(repository.saveAttempts, 1);
  });
}
