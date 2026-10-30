import 'support/control_finders.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

class _PausedRepository extends MemoryTableRepository {
  _PausedRepository(super.state);
  bool pauseNext = false;
  final reached = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> save(TabletState state) async {
    if (pauseNext) {
      pauseNext = false;
      reached.complete();
      await release.future;
    }
    await super.save(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _PausedRepository repository;
  late TableController controller;
  late TabletCatalog catalog;
  late String owner, partner;
  final toggle = find.widgetWithText(SwitchListTile, 'Has partner');
  final guidance = find.byKey(const ValueKey('partner-toggle-guidance'));

  Future<void> prepare() async {
    repository = _PausedRepository(TabletState.initial());
    controller = TableController(repository: repository);
    catalog = TabletCatalog(controller)..loaded = true;
    await controller.initialize();
    owner = controller.session.players.first.id;
    await controller.setHasPartner(owner, true);
    partner = controller.session.commanders.last.id;
  }

  tearDown(() {
    catalog.dispose();
    controller.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        home: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                if (controller.error != null)
                  Text('Global error: ${controller.error}'),
                TextButton(
                  onPressed: () => showTableWorkspace(
                    context,
                    controller,
                    catalog: catalog,
                    seatId: owner,
                    initialPage: WorkspacePage.player,
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
  }

  void expectLocal(WidgetTester tester) {
    expect(controller.error, isNull);
    expect(find.textContaining('Global error:'), findsNothing);
    expect(find.textContaining('Bad state:'), findsNothing);
    expect(find.textContaining('zero for everyone'), findsOneWidget);
    expect(guidance, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
  }

  testWidgets(
    'blocked Off preflight shows one local helper without command or global error',
    (tester) async {
      await prepare();
      await controller.setCommanderDamage(
        controller.session.players.last.id,
        partner,
        2,
      );
      await open(tester);
      final before = controller.state.toJson();
      final encoded = repository.encoded;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expectLocal(tester);
      expect(controller.state.toJson(), before);
      expect(repository.encoded, encoded);
      await close(tester);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(toggle);
      expect(
        guidance,
        findsNothing,
      ); // Local guidance is not a persisted failure.
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expectLocal(tester);
      await controller.setCommanderDamage(
        controller.session.players.last.id,
        partner,
        0,
      );
      await tester.pumpAndSettle();
      expect(guidance, findsNothing);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(controller.session.hasPartner(owner), isFalse);
      expect(controller.error, isNull);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets(
    'queued damage race rejects Off locally and preserves active source',
    (tester) async {
      await prepare();
      await open(tester);
      final history = controller.session.history.length;
      final observedErrors = <String>[];
      controller.addListener(() {
        if (controller.error != null) observedErrors.add(controller.error!);
      });
      repository.pauseNext = true;
      final damage = controller.setCommanderDamage(
        controller.session.players.last.id,
        partner,
        1,
      );
      await repository.reached.future;
      expect(controller.partnerToggleBlockReason(owner), isNull);
      await tester.tap(toggle);
      await tester.pump();
      repository.release.complete();
      expect(await damage, isTrue);
      await tester.pumpAndSettle();
      expectLocal(tester);
      expect(observedErrors, isEmpty);
      expect(controller.session.history, hasLength(history + 1));
      expect(controller.session.players.last.commanderDamage[partner], 1);
      expect(controller.session.commanders.last.active, isTrue);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets(
    'actual save failure retains existing global error path, not guard helper',
    (tester) async {
      await prepare();
      await open(tester);
      repository.failSave = true;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(controller.error, contains('Simulated storage failure'));
      expect(find.textContaining('Global error:'), findsOneWidget);
      expect(guidance, findsNothing);
      expect(controller.session.hasPartner(owner), isTrue);
      repository.failSave = false;
      await close(tester);
    },
  );
}
