import 'package:doubling_season/models/token_definition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/features/ring_service.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TableFixture f;
  late RingService ring;
  late String id;
  UtilityState utility() => f.player.utilities.firstWhere((u) => u.id == id);
  setUp(() async {
    f = TableFixture();
    await f.initialize();
    f.catalog.loaded = true;
    await f.board.addUtility(f.playerId, RingService.kind);
    id = f.player.utilities.last.id;
    ring = RingService(f.controller);
  });
  tearDown(() => f.dispose());

  test(
    'five temptations, no creatures, same bearer, clear and undo are scoped',
    () async {
      final other = f.controller.session.players.last.toJson();
      for (var n = 1; n <= 5; n++) {
        final history = f.controller.session.history.length;
        await ring.tempt(f.playerId, id, bearer: 'Frodo');
        expect(utility().value, n);
        expect(RingService.stage(utility()), n.clamp(0, 4));
        expect(RingService.bearer(utility()), 'Frodo');
        expect(f.controller.session.history.length, history + 1);
      }
      await ring.tempt(f.playerId, id, bearer: '', noCreatures: true);
      expect(utility().value, 6);
      expect(RingService.stage(utility()), 4);
      expect(RingService.bearer(utility()), '');
      await f.controller.undo();
      expect(utility().value, 5);
      expect(RingService.bearer(utility()), 'Frodo');
      await ring.clearBearer(f.playerId, id);
      expect(utility().value, 5);
      expect(RingService.bearer(utility()), '');
      await f.controller.undo();
      expect(RingService.bearer(utility()), 'Frodo');
      expect(f.controller.session.players.last.toJson(), other);
    },
  );

  test('failed save and stale seat leave both fields unchanged', () async {
    final before = utility().toJson();
    f.repository.failSave = true;
    await expectLater(
      ring.tempt(f.playerId, id, bearer: 'Sam'),
      throwsStateError,
    );
    expect(utility().toJson(), before);
    f.repository.failSave = false;
    final captured = f.board.scope(f.playerId);
    await f.controller.resetGame(keepBoard: true);
    await expectLater(
      ring.tempt(f.playerId, id, bearer: 'Sam', captured: captured),
      throwsStateError,
    );
    expect(f.controller.session.players.first.utilities.last.value, 0);
  });

  test('reload and start turn persist progress; new game resets it', () async {
    await ring.tempt(f.playerId, id, bearer: 'Squirrel token');
    await f.board.startTurn(f.playerId);
    expect(utility().value, 1);
    expect(RingService.bearer(utility()), 'Squirrel token');
    final reopened = TableController(repository: f.repository);
    await reopened.initialize();
    addTearDown(reopened.dispose);
    final saved = reopened.player(f.playerId).utilities.last;
    expect(saved.value, 1);
    expect(RingService.bearer(saved), 'Squirrel token');
    await f.controller.resetGame(keepBoard: true);
    final fresh = f.controller.session.players.first.utilities.last;
    expect(fresh.kind, RingService.kind);
    expect(fresh.value, 0);
    expect(RingService.bearer(fresh), '');
    await f.controller.resetGame(keepBoard: false);
    expect(f.controller.session.players.first.utilities.map((u) => u.kind), [
      'storm_count',
      'mana_pool',
    ]);
  });

  test(
    'presets include Ring setup without live progress or bearer, append singleton',
    () async {
      final presets = PresetService(f.controller, f.catalog);
      await ring.correct(
        f.playerId,
        id,
        temptations: 7,
        bearer: 'Physical commander',
      );
      final saved = await presets.save(f.playerId, 'Ring setup');
      final template = (saved['utilities'] as List).last as Map;
      expect(template['defaultValue'], 0);
      expect(
        (template['configuration'] as Map).containsKey(RingService.bearerKey),
        false,
      );
      await presets.load(f.playerId, saved['id'] as String, append: true);
      expect(
        f.player.utilities.where((u) => u.kind == RingService.kind),
        hasLength(1),
      );
      expect(utility().value, 7);
      await presets.load(f.playerId, saved['id'] as String);
      final fresh = f.player.utilities.last;
      expect(fresh.kind, RingService.kind);
      expect(fresh.value, 0);
      expect(RingService.bearer(fresh), '');
      await f.controller.undo();
      expect(utility().value, 7);
      expect(RingService.bearer(utility()), 'Physical commander');
    },
  );

  test(
    'new catalog Ring creates one utility while legacy objects remain exact',
    () async {
      final legacy = sampleToken(
        id: 'old-ring',
        name: 'The Ring // The Ring Tempts You',
        pt: '',
        type: 'Emblem',
        amount: 1,
        tapped: 0,
        sick: 0,
      );
      await f.controller.commit(
        'Legacy fixture',
        playerId: f.playerId,
        mutate: (s) => s.player(f.playerId).tokens.add(legacy.copy()),
      );
      final before = f.token('old-ring').toJson();
      final definition = TokenDefinition(
        name: legacy.name,
        pt: '',
        colors: '',
        type: 'Emblem',
        abilities: '',
        popularity: 0,
      );
      await f.board.createToken(f.playerId, definition, quantity: 3);
      expect(f.player.tokens, hasLength(1));
      expect(f.token('old-ring').toJson(), before);
      expect(
        f.player.utilities.where((u) => u.kind == RingService.kind),
        hasLength(1),
      );
      final preset = await PresetService(
        f.controller,
        f.catalog,
      ).save(f.playerId, 'Legacy ring');
      expect((preset['tokens'] as List).single['name'], legacy.name);
    },
  );

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets(
      'Ring progresses without a label and optional notes commit atomically at $size',
      (tester) async {
        f.dispose();
        f = TableFixture();
        await f.initialize();
        f.catalog.loaded = true;
        await f.board.addUtility(f.playerId, RingService.kind);
        id = f.player.utilities.last.id;
        ring = RingService(f.controller);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        utility().artworkUrl = null;
        await tester.pumpWidget(
          MaterialApp(
            theme: tableTheme(Brightness.dark),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTableWorkspace(
                    context,
                    f.controller,
                    catalog: f.catalog,
                    seatId: f.playerId,
                    initialPage: WorkspacePage.utilities,
                    itemId: id,
                  ),
                  child: const Text('Open Ring'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open Ring'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('utility-detail-the_ring')),
          findsOneWidget,
        );
        expect(find.text('The Ring tempts you').hitTestable(), findsOneWidget);
        expect(find.byKey(const ValueKey('ring-no-creatures')), findsNothing);
        expect(find.text('Cancel choice'), findsNothing);
        expect(f.player.tokens, isEmpty);
        final before = f.controller.session.history.length;
        await tester.tap(find.text('The Ring tempts you'));
        await tester.pumpAndSettle();
        expect(utility().value, 1);
        expect(RingService.bearer(utility()), '');
        expect(f.controller.session.history.length, before + 1);
        // A physical creature label uses the shared player-facing keyboard and
        // remains a draft until the complete temptation is committed.
        final field = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Ring-bearer label (optional)',
        );
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(find.text('Done'), findsOneWidget);
        await tester.tap(find.text('f'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(RingService.bearer(utility()), '');
        await tester.ensureVisible(find.text('The Ring tempts you'));
        await tester.tap(find.text('The Ring tempts you'));
        await tester.pumpAndSettle();
        expect(utility().value, 2);
        expect(RingService.bearer(utility()), 'f');
        await tester.ensureVisible(find.text('Clear bearer'));
        await tester.tap(find.text('Clear bearer'));
        await tester.pumpAndSettle();
        expect(utility().value, 2);
        expect(RingService.bearer(utility()), isEmpty);
        expect(f.player.tokens, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
