import 'dart:async';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/life_artwork_picker.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/control_finders.dart';
import 'support/table_fixture.dart';

class _GatedRepository extends MemoryTableRepository {
  _GatedRepository(super.state);
  Completer<void>? pendingSave;
  bool saveStarted = false;
  @override
  Future<void> save(TabletState state) async {
    final gate = pendingSave;
    if (gate != null) {
      saveStarted = true;
      await gate.future;
    }
    await super.save(state);
  }
}

void main() {
  Future<void> viewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is PlayerField && widget.label == label,
  );
  Future<BuildContext> host(WidgetTester tester, TableFixture f) async {
    await viewport(tester);
    f.catalog.loaded = true;
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return TextButton(
                onPressed: () => showTableWorkspace(
                  context,
                  f.controller,
                  catalog: f.catalog,
                  seatId: f.playerId,
                  initialPage: WorkspacePage.player,
                ),
                child: const Text('Open player settings'),
              );
            },
          ),
        ),
      ),
    );
    return context;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open player settings'));
    await tester.pumpAndSettle();
  }

  Future<void> suspend(WidgetTester tester, BuildContext context) async {
    final closing = dismissTableTransientForPresentationChange(context);
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    await closing;
    await tester.pumpAndSettle();
  }

  test(
    'Queued stale token edit compares its baseline inside the durable transaction',
    () async {
      final f = TableFixture(stateWithTokens([sampleToken()]));
      await f.initialize();
      addTearDown(f.dispose);
      final newer = f.board.editToken(f.playerId, 'source', name: 'New');
      final stale = f.board.editToken(
        f.playerId,
        'source',
        name: 'Old draft',
        expectedFields: {'name': 'Saproling'},
      );
      final rejected = expectLater(stale, throwsA(isA<StateError>()));
      await newer;
      await rejected;
      expect(f.token('source').name, 'New');
      expect(f.controller.session.history.length, 1);
    },
  );

  test(
    'Queued numeric and counter drafts reject newer accepted values',
    () async {
      final f = TableFixture(stateWithTokens([sampleToken()]));
      await f.initialize();
      addTearDown(f.dispose);
      final original = f.token('source').amount;
      final newer = f.board.editToken(
        f.playerId,
        'source',
        amount: original + 2,
      );
      final stale = f.board.editToken(
        f.playerId,
        'source',
        amount: original + 1,
        expectedFields: {'amount': '$original'},
      );
      final rejected = expectLater(stale, throwsA(isA<StateError>()));
      await newer;
      await rejected;
      expect(f.token('source').amount, original + 2);
      final newCounter = f.board.setCounter(f.playerId, 'source', 'charge', 4);
      final staleCounter = f.board.setCounter(
        f.playerId,
        'source',
        'charge',
        2,
        expectedValue: 0,
      );
      final counterRejected = expectLater(
        staleCounter,
        throwsA(isA<StateError>()),
      );
      await newCounter;
      await counterRejected;
      expect(f.token('source').counters['charge'], 4);
    },
  );

  for (final dirty in [false, true]) {
    testWidgets(
      '${dirty ? 'Dirty' : 'Clean'} retained player name cannot overwrite a newer seat name',
      (tester) async {
        final f = TableFixture();
        await f.initialize();
        addTearDown(f.dispose);
        final context = await host(tester, f);
        await open(tester);
        if (dirty) {
          tester.widget<PlayerField>(field('Player name')).controller.text =
              'Unsaved old draft';
        }
        await suspend(tester, context);
        expect(byControlLabel('Close workspace'), findsNothing);
        await f.controller.updateState('Newer seat name', (state) {
          state.profiles.firstWhere((p) => p.id == f.player.seatId).name =
              'Newer name';
        });
        await open(tester);
        final restored = tester.widget<PlayerField>(field('Player name'));
        expect(
          restored.controller.text,
          dirty ? 'Unsaved old draft' : 'Newer name',
        );
        await tester.tap(byControlLabel('Close workspace'));
        await tester.pumpAndSettle();
        expect(f.controller.profile(f.player.seatId).name, 'Newer name');
        if (dirty) {
          expect(byControlLabel('Close workspace'), findsOneWidget);
          expect(restored.controller.text, 'Unsaved old draft');
          restored.controller.text = '  Reviewed name  ';
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(f.controller.profile(f.player.seatId).name, 'Reviewed name');
          restored.controller.text = '  Reviewed again  ';
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(f.controller.profile(f.player.seatId).name, 'Reviewed again');
          await tester.tap(byControlLabel('Close workspace'));
          await tester.pumpAndSettle();
          expect(byControlLabel('Close workspace'), findsNothing);
        } else {
          expect(byControlLabel('Close workspace'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'Posture dismissal removes nested life artwork and its workspace while preserving search draft',
    (tester) async {
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      final context = await host(tester, f);
      await open(tester);
      await tester.ensureVisible(find.text('Search token art'));
      await tester.tap(find.text('Search token art'));
      // Parent workspace remains busy while the child picker is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LifeArtworkPicker), findsOneWidget);
      tester.widget<PlayerField>(field('Search token art')).controller.text =
          'Unfinished artwork search';
      await suspend(tester, context);
      expect(find.byType(LifeArtworkPicker), findsNothing);
      expect(byControlLabel('Close workspace'), findsNothing);
      expect(find.text('Open player settings').hitTestable(), findsOneWidget);
      expect(f.controller.profile(f.player.seatId).artworkUrl, isNull);
      await open(tester);
      await tester.ensureVisible(find.text('Search token art'));
      await tester.tap(find.text('Search token art'));
      // Parent workspace remains busy while the child picker is open.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final restoredQuery = tester
          .widget<PlayerField>(field('Search token art'))
          .controller
          .text;
      await suspend(tester, context);
      expect(restoredQuery, 'Unfinished artwork search');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Posture-dismissed token name draft blocks unrelated actions after a newer name edit',
    (tester) async {
      await viewport(tester);
      final f = TableFixture(stateWithTokens([sampleToken()]));
      await f.initialize();
      addTearDown(f.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 390,
                child: ListenableBuilder(
                  listenable: f.controller,
                  builder: (_, _) => TabletTokenCard(
                    token: f.token('source'),
                    player: f.player,
                    board: f.board,
                    playerName: 'Player 1',
                    quarterTurns: 0,
                    expanded: true,
                    onExpand: () {},
                    onOpenDetailed: (_) {},
                    onInputLock: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saproling'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('z'));
      await tester.pumpAndSettle();
      final closing = dismissPlayerKeyboardForPresentationChange();
      await tester.pumpAndSettle();
      await closing;
      expect(f.token('source').name, 'Saproling');
      await f.board.editToken(f.playerId, 'source', name: 'Newer token name');
      await tester.pumpAndSettle();
      final history = f.controller.session.history.length;
      await tester.tap(find.byKey(const ValueKey('source-quantity-increase')));
      await tester.pumpAndSettle();
      expect(f.token('source').name, 'Newer token name');
      expect(f.token('source').amount, 3);
      expect(f.controller.session.history.length, history);
      expect(
        find.textContaining('This token changed in another view'),
        findsOneWidget,
      );
      expect(find.text('Saprolingz'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Accepted inline save settling during posture dismissal retains unrelated artwork search draft',
    (tester) async {
      await viewport(tester);
      final repository = _GatedRepository(TabletState.initial());
      final controller = TableController(repository: repository);
      await controller.initialize();
      final catalog = TabletCatalog(controller)..loaded = true;
      addTearDown(catalog.dispose);
      addTearDown(controller.dispose);
      final player = controller.session.players.first;
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (value) {
                context = value;
                return TextButton(
                  onPressed: () => showTableWorkspace(
                    context,
                    controller,
                    catalog: catalog,
                    seatId: player.id,
                    initialPage: WorkspacePage.player,
                  ),
                  child: const Text('Open player settings'),
                );
              },
            ),
          ),
        ),
      );
      await open(tester);
      await tester.ensureVisible(find.text('Search token art'));
      await tester.tap(find.text('Search token art'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      tester.widget<PlayerField>(field('Search token art')).controller.text =
          'Keep this unrelated draft';
      await tester.tap(byControlLabel('Close artwork search'));
      await tester.pumpAndSettle();
      repository.pendingSave = Completer<void>();
      tester.widget<PlayerField>(field('Player name')).controller.text =
          'Accepted name';
      await tester.pump(const Duration(milliseconds: 351));
      expect(repository.saveStarted, isTrue);
      final closing = dismissTableTransientForPresentationChange(context);
      await tester.pump();
      repository.pendingSave!.complete();
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await closing;
      await tester.pumpAndSettle();
      expect(controller.profile(player.seatId).name, 'Accepted name');
      await open(tester);
      await tester.ensureVisible(find.text('Search token art'));
      await tester.tap(find.text('Search token art'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final restoredQuery = tester
          .widget<PlayerField>(field('Search token art'))
          .controller
          .text;
      await suspend(tester, context);
      expect(restoredQuery, 'Keep this unrelated draft');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
