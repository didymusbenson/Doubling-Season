import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

class _DelayedPartnerRepository extends MemoryTableRepository {
  _DelayedPartnerRepository() : super(TabletState.initial());

  bool holdSave = false;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> save(TabletState state) async {
    if (holdSave) {
      if (!started.isCompleted) started.complete();
      await release.future;
    }
    await super.save(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('only visible Close is actionable; raw outside tap is consumed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final controller = TableController(
      repository: MemoryTableRepository(TabletState.initial()),
    );
    await controller.initialize();
    final catalog = TabletCatalog(controller)..loaded = true;
    addTearDown(catalog.dispose);
    addTearDown(controller.dispose);
    var boardTaps = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => boardTaps++,
            child: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    await showTableWorkspace(
                      context,
                      controller,
                      catalog: catalog,
                      seatId: controller.session.players.first.seatId,
                      initialPage: WorkspacePage.player,
                    );
                    dismissed++;
                  },
                  child: const Text('Open player'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open player'));
    await tester.pumpAndSettle();
    final nodes = <SemanticsNode>[];
    void collect(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((child) {
        collect(child);
        return true;
      });
    }

    var root = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Close workspace',
      ),
    );
    while (root.parent != null) {
      root = root.parent!;
    }
    collect(root);
    final actionable = nodes.where(
      (node) => node.getSemanticsData().hasAction(SemanticsAction.tap),
    );
    final close = actionable
        .where(
          (node) =>
              (node.getSemanticsData().label == 'Close workspace' ||
              node.getSemanticsData().tooltip == 'Close workspace'),
        )
        .toList();
    expect(close, hasLength(1), reason: root.toStringDeep());
    expect(close.single.rect.size, const Size(44, 44));
    expect(
      actionable.where(
        (node) => node.rect.width >= 1133 && node.rect.height >= 744,
      ),
      isEmpty,
      reason: 'A full-window accessible tap target must not cover the modal.',
    );
    final before = boardTaps;
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    expect(find.text('Has partner'), findsNothing);
    expect(boardTaps, before, reason: 'Dismissal must not click the board.');
    // Prove that this coordinate is actionable on the underlying page once
    // the modal has gone, rather than passing because the board is inert.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(boardTaps, before + 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  for (final dismiss in ['Close button', 'outside barrier']) {
    for (final fail in [false, true]) {
      testWidgets(
        '$dismiss cannot hide a pending partner save (failure=$fail)',
        (tester) async {
          tester.view.physicalSize = const Size(1133, 744);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final repository = _DelayedPartnerRepository();
          final controller = TableController(repository: repository);
          await controller.initialize();
          final catalog = TabletCatalog(controller)..loaded = true;
          addTearDown(catalog.dispose);
          addTearDown(controller.dispose);
          var opened = 0;
          var dismissed = 0;
          final owner = controller.session.players.first;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      opened++;
                      await showTableWorkspace(
                        context,
                        controller,
                        catalog: catalog,
                        seatId: owner.seatId,
                        initialPage: WorkspacePage.player,
                      );
                      dismissed++;
                    },
                    child: const Text('Open player'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open player'));
          await tester.pumpAndSettle();
          final before = repository.encoded;
          final history = controller.session.history.length;
          repository.holdSave = true;
          await tester.tap(find.text('Has partner'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(repository.started.isCompleted, isTrue);
          expect(controller.session.hasPartner(owner.id), isFalse);
          expect(repository.encoded, before);
          final close = find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == 'Close workspace',
          );
          expect(tester.widget<IconButton>(close).onPressed, isNull);

          if (dismiss == 'Close button') {
            await tester.tap(close);
          } else {
            await tester.tapAt(const Offset(10, 10));
          }
          // Do not pumpAndSettle while the deliberate pending-save progress
          // indicator is animating. The route must remain throughout the wait.
          await tester.pump(const Duration(milliseconds: 500));
          expect(close, findsOneWidget);
          expect(find.text('Has partner'), findsOneWidget);
          expect(dismissed, 0);
          expect(
            opened,
            1,
          ); // The barrier tap did not reach the underlying page.
          expect(repository.encoded, before);
          expect(controller.session.history, hasLength(history));

          repository.failSave = fail;
          repository.holdSave = false;
          repository.release.complete();
          await tester.pumpAndSettle();
          expect(close, findsOneWidget);
          expect(dismissed, 0); // Finishing the save does not replay dismissal.
          expect(tester.widget<IconButton>(close).onPressed, isNotNull);
          if (fail) {
            expect(
              find.textContaining('Simulated storage failure'),
              findsOneWidget,
            );
            expect(controller.session.hasPartner(owner.id), isFalse);
            expect(repository.encoded, before);
            expect(controller.session.history, hasLength(history));
            repository.failSave = false;
            await tester.tap(find.text('Has partner'));
            await tester.pumpAndSettle();
          }
          expect(controller.session.hasPartner(owner.id), isTrue);
          expect(controller.session.history, hasLength(history + 1));
          expect(repository.encoded, isNot(before));
          expect(
            find.textContaining('Simulated storage failure'),
            findsNothing,
          );
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(close, findsNothing);
          expect(dismissed, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
