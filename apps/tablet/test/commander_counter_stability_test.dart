import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

class _DelayedRepository extends MemoryTableRepository {
  _DelayedRepository() : super(TabletState.initial());
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

void main() {
  const renderer = ValueKey('counter-stability-renderer');
  late _DelayedRepository repository;
  late TableController controller;
  late TabletCatalog catalog;
  late String playerId, sourceId;

  Future<void> open(WidgetTester tester, Size size, int turns) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository = _DelayedRepository();
    controller = TableController(repository: repository);
    await controller.initialize();
    catalog = TabletCatalog(controller)..loaded = true;
    playerId = controller.session.players.first.id;
    sourceId = controller.session.commanderTrackingSources.last.id;
    await tester.pumpWidget(
      RepaintBoundary(
        key: renderer,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTableWorkspace(
                  context,
                  controller,
                  catalog: catalog,
                  seatId: playerId,
                  initialPage: WorkspacePage.commanderDamage,
                  quarterTurns: turns,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  HalfStepper counter(WidgetTester tester, String name) =>
      tester.widget<HalfStepper>(
        find.byWidgetPredicate(
          (widget) => widget is HalfStepper && widget.label == name,
        ),
      );

  Color? minusColor(WidgetTester tester, String name) => tester
      .widget<Icon>(
        find.descendant(
          of: byControlLabel('Decrease $name'),
          matching: find.byIcon(Icons.remove),
        ),
      )
      .color;

  Future<Uint8List> counterPixels(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(renderer),
    );
    final area = tester.getRect(
      find.byKey(const ValueKey('player-counter-energy')),
    );
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final bytes = BytesBuilder(copy: false);
      for (var y = area.top.ceil(); y < area.bottom.floor(); y++) {
        final start = (y * image.width + area.left.ceil()) * 4;
        bytes.add(
          raw.buffer.asUint8List(
            start,
            (area.right.floor() - area.left.ceil()) * 4,
          ),
        );
      }
      image.dispose();
      return bytes.takeBytes();
    }))!;
  }

  Future<void> release(
    WidgetTester tester,
    int index, {
    bool fail = false,
  }) async {
    if (fail) {
      repository.waits[index].completeError(StateError('Delayed write failed'));
    } else {
      repository.waits[index].complete();
    }
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    repository.delay = false;
    for (final wait in repository.waits) {
      if (!wait.isCompleted) wait.complete();
    }
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      if (byControlLabel('Close workspace').evaluate().isEmpty) break;
      await tester.tap(byControlLabel('Close workspace'));
      await tester.pumpAndSettle();
    }
    expect(byControlLabel('Close workspace'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    catalog.dispose();
    controller.dispose();
    expect(tester.takeException(), isNull);
  }

  for (final layout in [
    (const Size(390, 844), 0),
    (const Size(1133, 744), 0),
    (const Size(1133, 744), 2),
  ]) {
    testWidgets(
      'commander writes keep zero-counter ink and controls stable at $layout',
      (tester) async {
        await open(tester, layout.$1, layout.$2);
        final beforePixels = await counterPixels(tester);
        final beforeColor = minusColor(tester, 'energy');
        final rect = tester.getRect(
          find.byKey(const ValueKey('player-counter-energy')),
        );
        final stored = repository.encoded;
        await tester.tap(find.byKey(ValueKey('commander-increase-$sourceId')));
        await tester.pump();
        expect(repository.waits, hasLength(1));
        for (final elapsed in [16, 80, 300]) {
          await tester.pump(Duration(milliseconds: elapsed));
          for (final name in ['energy', 'poison', 'experience', 'radiation']) {
            expect(
              counter(tester, name).onDecrease,
              isNull,
              reason: 'An unrelated commander write cannot enable $name.',
            );
            expect(counter(tester, name).value, '0');
          }
          expect(minusColor(tester, 'energy'), beforeColor);
          expect(
            tester.getRect(find.byKey(const ValueKey('player-counter-energy'))),
            rect,
          );
          expect(await counterPixels(tester), beforePixels);
          expect(repository.encoded, stored);
        }
        await release(tester, 0);
        await tester.pumpAndSettle();
        expect(controller.player(playerId).commanderDamage[sourceId], 1);
        expect(controller.player(playerId).life, 39);
        expect(minusColor(tester, 'energy'), beforeColor);
        expect(await counterPixels(tester), beforePixels);
        await close(tester);
      },
    );

    testWidgets(
      'only the pending counter allows a queued zero reversal at $layout',
      (tester) async {
        await open(tester, layout.$1, layout.$2);
        await tester.tap(byControlLabel('Increase energy'));
        await tester.pump();
        expect(counter(tester, 'energy').onDecrease, isNotNull);
        expect(counter(tester, 'poison').onDecrease, isNull);
        await tester.tap(byControlLabel('Decrease energy'));
        await tester.pump();
        await release(tester, 0);
        expect(controller.player(playerId).counters['energy'], 1);
        await release(tester, 1);
        await tester.pumpAndSettle();
        expect(controller.player(playerId).counters['energy'], 0);
        expect(counter(tester, 'energy').onDecrease, isNull);
        expect(counter(tester, 'poison').onDecrease, isNull);
        expect(controller.player(playerId).life, 40);
        expect(controller.player(playerId).commanderDamage, isEmpty);
        await close(tester);
      },
    );

    testWidgets(
      'a failed counter clears its pending affordance independently at $layout',
      (tester) async {
        await open(tester, layout.$1, layout.$2);
        final stored = repository.encoded;
        await tester.tap(byControlLabel('Increase energy'));
        await tester.pump();
        await tester.tap(byControlLabel('Increase poison'));
        await tester.pump();
        await release(tester, 0, fail: true);
        expect(counter(tester, 'energy').onDecrease, isNull);
        expect(counter(tester, 'poison').onDecrease, isNotNull);
        expect(counter(tester, 'radiation').onDecrease, isNull);
        expect(repository.encoded, stored);
        await release(tester, 1);
        await tester.pumpAndSettle();
        expect(controller.player(playerId).counters['energy'], 0);
        expect(controller.player(playerId).counters['poison'], 1);
        expect(counter(tester, 'energy').onDecrease, isNull);
        expect(
          find.textContaining('Some changes were not saved.'),
          findsOneWidget,
        );
        await close(tester);
      },
    );
  }
}
