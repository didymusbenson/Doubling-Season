import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/state/table_controller.dart';
import 'package:tripling_table/services/tablet_catalog.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'support/table_fixture.dart';

final _captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
const _captureKey = ValueKey('commander-pending-renderer');

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
  setUpAll(() async {
    if (_captureDirectory == null) return;
    final root = Platform.environment['FLUTTER_ROOT']!;
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(
            File(
              '$root/bin/cache/artifacts/material_fonts/${font.value}',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await Directory(_captureDirectory!).create(recursive: true);
  });
  Future<void> capture(WidgetTester tester, String name) async {
    if (_captureDirectory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$_captureDirectory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

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
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
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
    await tester.tap(find.byKey(ValueKey('commander-increase-$sourceId')));
    await tester.pump();
  }

  Future<void> minus(WidgetTester tester) async {
    await tester.tap(find.byKey(ValueKey('commander-decrease-$sourceId')));
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
  Future<void> enableEnergy(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Add counter'));
    await tester.tap(find.text('Add counter'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enable energy'));
    await tester.tap(find.text('Enable energy'));
    await tester.pumpAndSettle();
  }

  Future<void> setEnergy(WidgetTester tester, String value) async {
    final field = find.widgetWithText(TextField, 'Set total');
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select all'));
    await tester.tap(find.text(value));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Set'));
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'counter correction starts from latest total without changing life or damage',
    (tester) async {
      await open(tester);
      expect(find.byKey(ValueKey('commander-edit-$sourceId')), findsNothing);
      expect(find.text('Set damage total'), findsNothing);
      expect(find.byTooltip('Undo latest action'), findsNothing);
      await enableEnergy(tester);
      await tester.ensureVisible(find.byTooltip('Set energy total'));
      await tester.tap(find.byTooltip('Set energy total'));
      await tester.pumpAndSettle();
      await setEnergy(tester, '7');
      expect(controller.player(playerId).life, 40);
      expect(controller.player(playerId).commanderDamage[sourceId] ?? 0, 0);
      expect(controller.player(playerId).counters['energy'], 7);
      final plus = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Increase energy',
      );
      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Set energy total'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Set total');
      expect(tester.widget<TextField>(field).controller!.text, '8');
      await close(tester);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'queued commander failure survives entering and saving counter correction',
    (tester) async {
      await open(tester);
      await enableEnergy(tester);
      repo.delay = true;
      await plus(tester);
      await tester.ensureVisible(find.byTooltip('Set energy total'));
      await tester.tap(find.byTooltip('Set energy total'));
      await tester.pump();
      expect(
        find.widgetWithText(TextField, 'Set total'),
        findsNothing,
        reason: 'Counter editing must wait for the accepted commander write.',
      );
      repo.waits[0].completeError(StateError('Queued save failed'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Some changes were not saved.'),
        findsOneWidget,
      );
      repo.delay = false;
      await setEnergy(tester, '4');
      expect(controller.player(playerId).commanderDamage[sourceId] ?? 0, 0);
      expect(controller.player(playerId).life, 40);
      expect(controller.player(playerId).counters['energy'], 4);
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
        tester.getCenter(find.byKey(ValueKey('commander-increase-$sourceId'))),
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
  testWidgets(
    'real renderer preserves the grid before during and after an acknowledged write',
    (tester) async {
      await open(tester);
      final before = tester.getRect(card());
      await capture(tester, 'commander-before-save');
      repo.delay = true;
      await plus(tester);
      await tester.pumpAndSettle();
      expect(tester.getRect(card()), before);
      await capture(tester, 'commander-save-pending');
      repo.waits.single.complete();
      await tester.pumpAndSettle();
      expect(tester.getRect(card()), before);
      expect(controller.player(playerId).commanderDamage[sourceId], 1);
      await capture(tester, 'commander-save-acknowledged');
      await close(tester);
      await tester.pumpAndSettle();
    },
  );
}
