import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

class DelayedRepository extends MemoryTableRepository {
  DelayedRepository(super.state);
  bool delay = false;
  final waits = <Completer<void>>[];
  @override
  Future<void> save(TabletState state) async {
    if (delay) {
      final waiter = Completer<void>();
      waits.add(waiter);
      await waiter.future;
    }
    await super.save(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DelayedRepository repo;
  late TableController controller;
  late TabletCatalog catalog;
  late String playerId, sourceId;
  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1133, 744);
    addTearDown(tester.view.reset);
    repo = DelayedRepository(TabletState.initial());
    controller = TableController(repository: repo);
    await controller.initialize();
    catalog = TabletCatalog(controller)..loaded = true;
    playerId = controller.session.players.first.id;
    sourceId = controller.session.commanderTrackingSources.last.id;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTableWorkspace(
                context,
                controller,
                catalog: catalog,
                seatId: controller.session.players.first.seatId,
                initialPage: WorkspacePage.commanderDamage,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  tearDown(() {
    catalog.dispose();
    controller.dispose();
  });
  Finder card() => find.byKey(ValueKey('commander-tracker-$sourceId'));
  Future<void> plus(WidgetTester tester) async {
    final rect = tester.getRect(card());
    await tester.tapAt(rect.center + const Offset(35, -10));
    await tester.pump();
  }

  Future<void> minus(WidgetTester tester) async {
    final rect = tester.getRect(card());
    await tester.tapAt(rect.center - const Offset(35, 10));
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Close workspace'));
    await tester.pump();
  }

  testWidgets(
    'opening is pure; rapid first hits keep geometry and drain before closing',
    (tester) async {
      await open(tester);
      expect(controller.session.commanders, isEmpty);
      final rect = tester.getRect(card());
      repo.delay = true;
      await plus(tester);
      await plus(tester);
      await plus(tester);
      expect(repo.waits.length, 1);
      expect(tester.getRect(card()), rect);
      await close(tester);
      expect(card(), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        repo.waits[i].complete();
        await tester.pump();
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(card(), findsNothing);
      expect(controller.player(playerId).life, 37);
      expect(controller.player(playerId).commanderDamage[sourceId], 3);
      expect(controller.session.commanders.length, 1);
    },
  );
  testWidgets(
    'early failure followed by success remains visible when closing queued writes',
    (tester) async {
      await open(tester);
      repo.delay = true;
      await plus(tester);
      await plus(tester);
      await close(tester);
      repo.waits[0].completeError(StateError('First save failed'));
      await tester.pump();
      await tester.pump();
      repo.waits[1].complete();
      await tester.pumpAndSettle();
      expect(card(), findsOneWidget);
      expect(
        find.textContaining('Some changes were not saved.'),
        findsOneWidget,
      );
      expect(controller.player(playerId).life, 39);
      expect(controller.player(playerId).commanderDamage[sourceId], 1);
      expect(controller.error, isNull);
      await close(tester);
      await tester.pumpAndSettle();
      expect(card(), findsNothing);
    },
  );
  testWidgets('rapid plus then minus while display is zero is not dropped', (
    tester,
  ) async {
    await open(tester);
    repo.delay = true;
    await plus(tester);
    await minus(tester);
    repo.waits[0].complete();
    await tester.pump();
    await tester.pump();
    repo.waits[1].complete();
    await tester.pumpAndSettle();
    expect(controller.player(playerId).life, 40);
    expect(controller.player(playerId).commanderDamage[sourceId], 0);
    await close(tester);
    await tester.pumpAndSettle();
  });
  testWidgets(
    'correction starts from latest total and placeholder correction does not deduct life',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(ValueKey('commander-edit-$sourceId')));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Set damage total');
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select all'));
      await tester.tap(find.text('7'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correct ledger only'));
      await tester.pumpAndSettle();
      expect(controller.player(playerId).life, 40);
      expect(controller.player(playerId).commanderDamage[sourceId], 7);
      await tester.tap(find.text('Back to damage'));
      await tester.pumpAndSettle();
      await plus(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('commander-edit-$sourceId')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '8');
      await close(tester);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'queued failure survives entering correction and a successful correction',
    (tester) async {
      await open(tester);
      repo.delay = true;
      await plus(tester);
      await tester.tap(find.byKey(ValueKey('commander-edit-$sourceId')));
      await tester.pump();
      repo.waits[0].completeError(StateError('Queued save failed'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Some changes were not saved.'),
        findsOneWidget,
      );
      repo.delay = false;
      await tester.tap(find.widgetWithText(TextField, 'Set damage total'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select all'));
      await tester.tap(find.text('4'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correct ledger only'));
      await tester.pumpAndSettle();
      expect(controller.player(playerId).commanderDamage[sourceId], 4);
      expect(
        find.textContaining('Some changes were not saved.'),
        findsOneWidget,
      );
      await close(tester);
      await tester.pumpAndSettle();
      await close(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('commander-workspace')), findsNothing);
    },
  );
  testWidgets(
    'a failed held write stops acceleration rather than retrying indefinitely',
    (tester) async {
      await open(tester);
      repo.delay = true;
      final gesture = await tester.startGesture(
        tester.getRect(card()).center + const Offset(35, -10),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(repo.waits.length, 1);
      repo.waits.single.completeError(StateError('Held save failed'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(repo.waits.length, 1);
      await gesture.up();
      await tester.pumpAndSettle();
      await close(tester);
      await tester.pumpAndSettle();
      await close(tester);
      await tester.pumpAndSettle();
    },
  );
}
