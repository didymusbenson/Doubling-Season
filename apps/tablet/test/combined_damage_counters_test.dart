import 'support/control_finders.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/commander_ledger.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cache;
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  const captureKey = ValueKey('combined-counter-capture');
  setUpAll(() async {
    if (captures != null) {
      await Directory(captures).create(recursive: true);
      for (final font in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)..addFont(
              File(
                '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${font.value}',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    }
    cache = await Directory.systemTemp.createTemp('combined-popup-test-');
    Hive.init(cache.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
  });
  tearDownAll(() async {
    await Hive.close();
    await cache.delete(recursive: true);
  });

  Future<TableFixture> mount(
    WidgetTester tester, {
    int seats = 4,
    int turns = 0,
    Size size = const Size(1133, 744),
    bool partners = false,
    bool table = false,
    Map<String, int>? counters,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    state.session.players = state.session.players.take(seats).toList();
    if (counters != null) {
      state.session.players.first.counters = Map.of(counters);
    }
    final f = TableFixture(state);
    await f.initialize();
    f.catalog.loaded = true;
    if (partners) {
      for (final player in f.controller.session.players.toList()) {
        await f.controller.setHasPartner(player.id, true);
      }
    }
    addTearDown(f.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: table
              ? TableScreen(controller: f.controller)
              : Scaffold(
                  body: Builder(
                    builder: (context) => Column(
                      children: [
                        for (final page in [
                          WorkspacePage.commanderDamage,
                          WorkspacePage.counters,
                          WorkspacePage.history,
                          WorkspacePage.reset,
                        ])
                          TextButton(
                            onPressed: () => showTableWorkspace(
                              context,
                              f.controller,
                              catalog: f.catalog,
                              seatId: f.playerId,
                              quarterTurns: turns,
                              initialPage: page,
                            ),
                            child: Text(page.name),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return f;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$captures/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> open(WidgetTester tester, String route) async {
    await tester.tap(find.text(route));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(1133, 744), const Size(600, 1024)]) {
    for (final seats in [2, 3, 4]) {
      for (final turns in [0, 1, 2, 3]) {
        testWidgets(
          'combined popup preserves seats and partners $seats/$turns at $size',
          (tester) async {
            final f = await mount(
              tester,
              size: size,
              seats: seats,
              turns: turns,
              partners: true,
            );
            await open(tester, 'commanderDamage');
            expect(find.text('Add counter'), findsNothing);
            expect(
              find.byKey(const ValueKey('player-counter-energy')),
              findsOneWidget,
            );
            expect(find.text('Monarch'), findsOneWidget);
            expect(byControlLabel('Undo latest action'), findsNothing);
            expect(find.text('Set damage total'), findsNothing);
            expect(find.text('Correct life'), findsNothing);
            expect(
              find.byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith(
                      'commander-edit-',
                    ),
              ),
              findsNothing,
            );
            final surface = tester.getRect(
              find.byKey(const ValueKey('commander-workspace')),
            );
            expect(surface.left, greaterThanOrEqualTo(15.99));
            expect(surface.top, greaterThanOrEqualTo(15.99));
            expect(surface.right, lessThanOrEqualTo(size.width - 15.99));
            expect(surface.bottom, lessThanOrEqualTo(size.height - 15.99));
            final grid = tester.renderObject<RenderBox>(
              find.byKey(const ValueKey('focused-commander-grid')),
            );
            final rows = CommanderSeatLayout.rowsFor(
              f.controller.session.players,
              turns,
            );
            for (var r = 0; r < rows.length; r++) {
              for (var col = 0; col < rows[r].length; col++) {
                final owner = rows[r][col];
                if (owner == null) continue;
                final position = grid.globalToLocal(
                  tester.getCenter(
                    find.byKey(ValueKey('commander-owner-${owner.id}')),
                  ),
                );
                if (col > 0 && rows[r][col - 1] != null) {
                  final previous = grid.globalToLocal(
                    tester.getCenter(
                      find.byKey(
                        ValueKey('commander-owner-${rows[r][col - 1]!.id}'),
                      ),
                    ),
                  );
                  expect(position.dx, greaterThan(previous.dx));
                }
                for (final source
                    in f.controller.session.commanderTrackingSources.where(
                      (s) => s.ownerPlayerId == owner.id,
                    )) {
                  final plus = find.byKey(
                    ValueKey('commander-increase-${source.id}'),
                  );
                  await tester.ensureVisible(plus);
                  await tester.pumpAndSettle();
                  final target = tester.getSize(plus);
                  expect(target.width, greaterThanOrEqualTo(44));
                  expect(target.height, greaterThanOrEqualTo(44));
                  expect(plus.hitTestable(), findsOneWidget);
                  final before = f.player.life;
                  await tester.tap(plus);
                  await tester.pumpAndSettle();
                  expect(f.player.commanderDamage[source.id], 1);
                  expect(f.player.life, before - 1);
                  final name = tester.renderObject<RenderBox>(
                    find.byKey(
                      ValueKey('commander-source-owner-label-${source.id}'),
                    ),
                  );
                  final tracker = tester.renderObject<RenderBox>(
                    find.byKey(ValueKey('commander-tracker-${source.id}')),
                  );
                  final rightName = name.localToGlobal(
                    Offset(name.size.width * .75, name.size.height / 2),
                  );
                  final leftName = name.localToGlobal(
                    Offset(name.size.width * .25, name.size.height / 2),
                  );
                  expect(tracker.globalToLocal(rightName).dy, lessThan(28));
                  await tester.tapAt(rightName);
                  await tester.pumpAndSettle();
                  expect(
                    f.player.commanderDamage[source.id],
                    2,
                    reason: 'Actual name right half steps damage.',
                  );
                  expect(f.player.life, before - 2);
                  await tester.tapAt(leftName);
                  await tester.pumpAndSettle();
                  expect(
                    f.player.commanderDamage[source.id],
                    1,
                    reason: 'Actual name left half restores damage.',
                  );
                  expect(f.player.life, before - 1);
                  await tester.tapAt(
                    tracker.localToGlobal(Offset(tracker.size.width * .75, 3)),
                  );
                  await tester.pumpAndSettle();
                  expect(f.player.commanderDamage[source.id], 2);
                  await tester.tapAt(
                    tracker.localToGlobal(Offset(tracker.size.width * .25, 3)),
                  );
                  await tester.pumpAndSettle();
                  expect(f.player.commanderDamage[source.id], 1);
                  expect(f.player.life, before - 1);
                }
              }
            }
            expect(tester.takeException(), isNull);
            await close(tester);
          },
        );
      }
    }
  }

  testWidgets(
    'zero counter chips are ready without growth; Undo exists only in History',
    (tester) async {
      final f = await mount(tester);
      await open(tester, 'counters');
      expect(
        find.byKey(const ValueKey('focused-commander-grid')),
        findsOneWidget,
      );
      final initialHeight = tester
          .getSize(find.byKey(const ValueKey('commander-workspace')))
          .height;
      expect(initialHeight, lessThan(500));
      expect(find.text('Change life by'), findsNothing);
      expect(find.text('Set life total to'), findsNothing);
      expect(find.text('Reset life to 40'), findsNothing);
      expect(f.player.counters['energy'], 0);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('commander-workspace')))
            .height,
        initialHeight,
      );
      final increase = find.bySemanticsLabel(RegExp('Increase energy'));
      final semantics = tester.ensureSemantics();
      await tester.pump();
      await tester.ensureVisible(increase);
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(f.player.counters['energy'], 1);
      await close(tester);
      await open(tester, 'history');
      final undo = byActionNamePrefix('Undo latest:');
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(f.player.counters['energy'], 0);
      expect(find.text('Latest action undone.'), findsNothing);
      await close(tester);
      await open(tester, 'reset');
      expect(find.widgetWithText(TextField, 'Starting life'), findsOneWidget);
      await close(tester);
      semantics.dispose();
    },
  );

  testWidgets(
    'empty life chip has no counter target; active badges sit beside ledger',
    (tester) async {
      final f = await mount(tester, table: true);
      final summary = find.byKey(
        ValueKey('${f.playerId}-life-counter-summary'),
      );
      final ledger = find.byKey(ValueKey('${f.playerId}-commander-ledger'));
      expect(summary, findsNothing);
      expect(ledger.hitTestable(), findsOneWidget);
      await tester.tap(ledger);
      await tester.pumpAndSettle();
      expect(find.text('Add counter'), findsNothing);
      expect(
        find.byKey(const ValueKey('player-counter-energy')),
        findsOneWidget,
      );
      await close(tester);
      await f.controller.setPlayerCounter(f.playerId, 'energy', 2);
      await tester.pumpAndSettle();
      expect(summary.hitTestable(), findsOneWidget);
      final a = tester.getRect(ledger), b = tester.getRect(summary);
      expect((b.left - a.right).abs(), lessThanOrEqualTo(5));
      expect(b.height, closeTo(44, .001));
      expect(b.width, closeTo(44, .001));
      await f.controller.setPlayerCounter(f.playerId, 'energy', 0);
      await tester.pumpAndSettle();
      expect(summary, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy maps retain custom zero chips without normalizing on open',
    (tester) async {
      final original = <String, int>{
        'Legacy score': 0,
        '': 0,
        'Very long historical custom counter name which must not shrink its number':
            999999999999,
      };
      final f = await mount(tester, counters: original);
      final saved = f.repository.encoded;
      await open(tester, 'commanderDamage');
      expect(find.text('Add counter'), findsNothing);
      expect(find.text('Counter name'), findsNothing);
      for (final key in [
        'energy',
        'poison',
        'experience',
        'radiation',
        ...original.keys,
      ]) {
        final chip = find.byKey(ValueKey('player-counter-$key'));
        expect(chip, findsOneWidget);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        expect(chip.hitTestable(), findsOneWidget);
      }
      expect(f.player.counters, original);
      expect(f.repository.encoded, saved);
      expect(f.controller.session.history, isEmpty);
      final largeText = tester.renderObject<RenderBox>(
        find.byKey(ValueKey('player-counter-value-${original.keys.last}')),
      );
      final painted = MatrixUtils.transformRect(
        largeText.getTransformTo(null),
        Offset.zero & largeText.size,
      );
      expect(painted.height, greaterThanOrEqualTo(20));
      await capture(tester, 'legacy-zero-empty-long-and-large-counter-chips');
      final increase = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Increase Legacy score',
      );
      await tester.ensureVisible(increase);
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(f.player.counters['Legacy score'], 1);
      expect(f.player.counters[''], 0);
      expect(f.player.counters[original.keys.last], 999999999999);
      expect(f.player.counters.containsKey('energy'), isFalse);
      final unnamed = find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Increase unnamed counter',
      );
      await tester.ensureVisible(unnamed);
      await tester.tap(unnamed);
      await tester.pumpAndSettle();
      expect(f.player.counters[''], 1);
      expect(byControlLabel('Set unnamed counter total'), findsOneWidget);
      await close(tester);
      await open(tester, 'commanderDamage');
      expect(
        find.byKey(const ValueKey('player-counter-Legacy score')),
        findsOneWidget,
      );
      expect(f.player.counters['Legacy score'], 1);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  testWidgets(
    'correction remains beside its chip and reveals in long legacy list',
    (tester) async {
      final f = await mount(
        tester,
        size: const Size(600, 744),
        counters: {'energy': 0, for (var i = 0; i < 32; i++) 'Legacy $i': i},
      );
      await open(tester, 'commanderDamage');
      final pencil = byControlLabel('Set energy total');
      await tester.ensureVisible(pencil);
      await tester.pumpAndSettle();
      await tester.tap(pencil);
      await tester.pumpAndSettle();
      final input = find.widgetWithText(TextField, 'Set total');
      expect(input.hitTestable(), findsOneWidget);
      expect(
        byControlLabel('Cancel counter correction').hitTestable(),
        findsOneWidget,
      );
      final energy = tester.getRect(
        find.byKey(const ValueKey('player-counter-energy')),
      );
      expect(tester.getRect(input).top - energy.bottom, lessThan(16));
      expect(tester.widget<TextField>(input).controller!.text, '0');
      await capture(tester, 'legacy-counter-correction-at-selected-row');
      await tester.tap(byControlLabel('Cancel counter correction'));
      await tester.pumpAndSettle();
      expect(f.player.counters['energy'], 0);
      expect(f.player.counters['Legacy 31'], 31);
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

  for (final turns in [0, 1, 2, 3]) {
    testWidgets('commander name region retains holds at rotation $turns', (
      tester,
    ) async {
      final f = await mount(tester, turns: turns, partners: true);
      await open(tester, 'commanderDamage');
      final sources = f.controller.session.commanderTrackingSources;
      final source = sources.first;
      final finder = find.byKey(
        ValueKey('commander-source-owner-label-${source.id}'),
      );
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      final name = tester.renderObject<RenderBox>(finder);
      await capture(tester, 'commander-name-full-hit-rotation$turns');
      final gesture = await tester.startGesture(
        name.localToGlobal(Offset(name.size.width * .75, name.size.height / 2)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(f.player.commanderDamage[source.id], 5);
      expect(f.player.commanderDamage[sources[1].id] ?? 0, 0);
      expect(f.player.life, 35);
      await tester.pump(const Duration(seconds: 1));
      expect(f.player.commanderDamage[source.id], 5);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
}
