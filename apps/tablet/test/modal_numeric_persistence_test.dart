import 'support/control_finders.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

class _DelayedRepository extends MemoryTableRepository {
  _DelayedRepository(super.state);

  bool delay = true;
  final waits = <Completer<void>>[];

  @override
  Future<void> save(TabletState state) async {
    if (delay) {
      final wait = Completer<void>();
      waits.add(wait);
      await wait.future;
    }
    await super.save(state);
  }
}

enum _Target {
  counter,
  utility,
  mana,
  manaTen;

  String get label => switch (this) {
    counter => 'energy',
    utility => 'Value',
    mana => 'White mana',
    manaTen => 'White mana by ten',
  };

  int get step => this == manaTen ? 10 : 1;
  WorkspacePage get page =>
      this == counter ? WorkspacePage.counters : WorkspacePage.utilities;

  String? itemId(PlayerState player) => this == counter
      ? null
      : player.utilities
            .firstWhere(
              (u) => u.kind == (this == utility ? 'storm_count' : 'mana_pool'),
            )
            .id;

  int value(PlayerState player) => switch (this) {
    counter => player.counters['energy'] ?? 0,
    utility =>
      player.utilities.firstWhere((u) => u.kind == 'storm_count').value,
    mana || manaTen => player.mana['W'] ?? 0,
  };

  void seed(PlayerState player, int value) {
    switch (this) {
      case counter:
        player.counters['energy'] = value;
      case utility:
        player.utilities.firstWhere((u) => u.kind == 'storm_count').value =
            value;
      case mana || manaTen:
        player.mana['W'] = value;
    }
  }
}

void main() {
  late _DelayedRepository repository;
  late TableController controller;
  late TabletCatalog catalog;
  late String playerId;
  var dismissed = 0;

  PlayerState player() => controller.player(playerId);
  Finder close() => find.descendant(
    of: byControlLabel('Close workspace'),
    matching: find.byType(IconButton),
  );
  Finder stepper(_Target target) => find.byWidgetPredicate(
    (widget) => widget is HalfStepper && widget.label == target.label,
  );

  Future<void> open(
    WidgetTester tester,
    _Target target, {
    int turns = 0,
    int initial = 3,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1133, 744);
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    target.seed(state.session.players.first, initial);
    repository = _DelayedRepository(state);
    controller = TableController(repository: repository);
    await controller.initialize();
    catalog = TabletCatalog(controller)..loaded = true;
    playerId = controller.session.players.first.id;
    dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showTableWorkspace(
                  context,
                  controller,
                  catalog: catalog,
                  seatId: playerId,
                  initialPage: target.page,
                  itemId: target.itemId(player()),
                  quarterTurns: turns,
                );
                dismissed++;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    if (target == _Target.counter && initial == 0) {
      repository.delay = false;
      await tester.tap(find.text('Add counter'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enable energy'));
      await tester.tap(find.text('Enable energy'));
      await tester.pumpAndSettle();
      repository.delay = true;
    }
    addTearDown(() {
      catalog.dispose();
      controller.dispose();
    });
  }

  Future<void> finish(WidgetTester tester) async {
    // Close while the widget-test tree is still mounted. addTearDown runs
    // after the framework disposes it and cannot complete showDialog's Future.
    repository.delay = false;
    for (final wait in repository.waits) {
      if (!wait.isCompleted) wait.complete();
    }
    await tester.pumpAndSettle();
    for (var i = 0; i < 2 && close().evaluate().isNotEmpty; i++) {
      await tester.tap(close());
      await tester.pumpAndSettle();
    }
    expect(close(), findsNothing);
    expect(dismissed, 1);
  }

  Future<void> tap(
    WidgetTester tester,
    _Target target, {
    bool decrease = false,
  }) async {
    await tester.tap(
      byControlLabel('${decrease ? 'Decrease' : 'Increase'} ${target.label}'),
    );
    await tester.pump();
  }

  Future<void> release(
    WidgetTester tester,
    int index, {
    bool fail = false,
  }) async {
    expect(repository.waits.length, greaterThan(index));
    if (fail) {
      repository.waits[index].completeError(StateError('Delayed save failed'));
    } else {
      repository.waits[index].complete();
    }
    await tester.pump();
    await tester.pump();
  }

  void expectStable(WidgetTester tester, _Target target, Rect before) {
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.getRect(stepper(target)), before);
    final control = tester.widget<HalfStepper>(stepper(target));
    expect(control.onDecrease, isNotNull);
    expect(control.onIncrease, isNotNull);
    expect(tester.widget<IconButton>(close()).onPressed, isNotNull);
    expect(
      tester
          .widget<PlayerKeyboardHost>(find.byType(PlayerKeyboardHost))
          .enabled,
      isTrue,
    );
  }

  for (final target in _Target.values) {
    for (final turns in [0, 2]) {
      testWidgets(
        '${target.name} keeps transient save frames enabled and drains rapid taps before Close at turns=$turns',
        (tester) async {
          await open(tester, target, turns: turns, initial: 30);
          final otherBefore = controller.session.players[1].toJson();
          final storedBefore = repository.encoded;
          final rect = tester.getRect(stepper(target));
          await tap(tester, target);
          expect(repository.waits, hasLength(1));
          // Deliberately inspect unfinished frames. pumpAndSettle alone would
          // miss the old progress flash and disabled/dimmed controls entirely.
          for (final milliseconds in [16, 80, 300]) {
            await tester.pump(Duration(milliseconds: milliseconds));
            expectStable(tester, target, rect);
            expect(target.value(player()), 30);
            expect(repository.encoded, storedBefore);
          }
          await tap(tester, target);
          await tap(tester, target);
          expect(repository.waits, hasLength(1));
          expectStable(tester, target, rect);
          await tester.tap(close());
          await tester.pump();
          expect(dismissed, 0);
          for (var i = 0; i < 3; i++) {
            await release(tester, i);
          }
          await tester.pumpAndSettle();
          expect(dismissed, 1);
          expect(target.value(player()), 30 + 3 * target.step);
          expect(controller.session.players[1].toJson(), otherBefore);
          final reopened = await repository.open();
          expect(
            target.value(reopened.state.session.player(playerId)),
            30 + 3 * target.step,
          );
          await finish(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${target.name} queues plus then minus even while committed display is zero',
      (tester) async {
        await open(tester, target, initial: 0);
        expect(tester.widget<HalfStepper>(stepper(target)).onDecrease, isNull);
        await tap(tester, target);
        expect(target.value(player()), 0);
        expect(
          tester.widget<HalfStepper>(stepper(target)).onDecrease,
          isNotNull,
        );
        await tap(tester, target, decrease: true);
        await release(tester, 0);
        expect(target.value(player()), target.step);
        await release(tester, 1);
        await tester.pumpAndSettle();
        expect(target.value(player()), 0);
        expect(tester.widget<HalfStepper>(stepper(target)).onDecrease, isNull);
        final reopened = await repository.open();
        expect(target.value(reopened.state.session.player(playerId)), 0);
        await finish(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${target.name} retains a failed queued save after later success and blocks silent dismissal',
      (tester) async {
        await open(tester, target, initial: 0);
        final storedBefore = repository.encoded;
        await tap(tester, target);
        await tap(tester, target);
        await tester.tap(close());
        await tester.pump();
        await release(tester, 0, fail: true);
        expect(repository.encoded, storedBefore);
        expect(target.value(player()), 0);
        await release(tester, 1);
        await tester.pumpAndSettle();
        expect(dismissed, 0);
        expect(close(), findsOneWidget);
        expect(
          find.textContaining('Some changes were not saved.'),
          findsOneWidget,
        );
        expect(
          controller.error,
          isNull,
          reason: 'The later success must not erase the modal failure.',
        );
        expect(target.value(player()), target.step);
        final reopened = await repository.open();
        expect(
          target.value(reopened.state.session.player(playerId)),
          target.step,
        );
        await tester.tap(close());
        await tester.pumpAndSettle();
        expect(dismissed, 1);
        await finish(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final fail in [false, true]) {
    testWidgets(
      'utility taps flush an inline edit before their numeric save (failure=$fail)',
      (tester) async {
        await open(tester, _Target.utility, initial: 3);
        final name = tester
            .widget<TextField>(find.widgetWithText(TextField, 'Name'))
            .controller!;
        name.text = 'Storm with a saved name';
        await tap(tester, _Target.utility);
        expect(repository.waits, hasLength(1));
        expect(_Target.utility.value(player()), 3);
        await release(tester, 0, fail: fail);
        if (fail) {
          expect(repository.waits, hasLength(1));
          expect(_Target.utility.value(player()), 3);
          expect(
            find.textContaining('Some changes were not saved.'),
            findsOneWidget,
          );
          expect(name.text, 'Storm with a saved name');
        } else {
          expect(repository.waits, hasLength(2));
          await release(tester, 1);
          await tester.pumpAndSettle();
          final saved = (await repository.open()).state.session.player(
            playerId,
          );
          expect(
            saved.utilities.firstWhere((u) => u.kind == 'storm_count').name,
            'Storm with a saved name',
          );
          expect(_Target.utility.value(saved), 4);
        }
        await finish(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('counter correction reads the latest committed queued total', (
    tester,
  ) async {
    await open(tester, _Target.counter, initial: 0);
    await tap(tester, _Target.counter);
    await tap(tester, _Target.counter);
    await tester.tap(byControlLabel('Set energy total'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Set total'), findsNothing);
    await release(tester, 0);
    await release(tester, 1);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Set total'),
    );
    expect(field.controller!.text, '2');
    await finish(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'counter correction waits for direct taps and saves the new total exactly once',
    (tester) async {
      await open(tester, _Target.counter, initial: 0);
      await tap(tester, _Target.counter);
      await tap(tester, _Target.counter);
      await tester.tap(byControlLabel('Set energy total'));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Set total'), findsNothing);
      await release(tester, 0);
      await release(tester, 1);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Set total'),
      );
      expect(field.controller!.text, '2');
      expect(_Target.counter.value(player()), 2);
      expect(player().life, 40);
      field.controller!.text = '7';
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Set'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Set'));
      await tester.pump();
      expect(repository.waits, hasLength(3));
      expect(_Target.counter.value(player()), 2);
      await release(tester, 2);
      await tester.pumpAndSettle();
      expect(_Target.counter.value(player()), 7);
      expect(player().life, 40);
      expect(
        (await repository.open()).state.session
            .player(playerId)
            .counters['energy'],
        7,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await finish(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
