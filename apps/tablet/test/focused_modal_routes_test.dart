import 'support/control_finders.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  setUpAll(() async {
    if (captures == null) return;
    await Directory(captures).create(recursive: true);
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${font.value}',
      );
      await (FontLoader(
        font.key,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  Future<TableFixture> open(
    WidgetTester tester,
    Size size,
    WorkspacePage page,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    state.archives.add(
      GameArchive(
        id: 'capture-archive',
        label: 'Friday Commander',
        savedAt: DateTime.utc(2026, 10, 23),
        session: GameSession.fromJson(state.session.toJson()),
      ),
    );
    final f = TableFixture(state);
    await f.initialize();
    f.catalog.loaded = true;
    addTearDown(f.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture-focused-routes'),
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTableWorkspace(
                  context,
                  f.controller,
                  catalog: f.catalog,
                  seatId:
                      [
                        WorkspacePage.player,
                        WorkspacePage.counters,
                        WorkspacePage.commanderDamage,
                      ].contains(page)
                      ? f.controller.session.players.first.id
                      : null,
                  initialPage: page,
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
    return f;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(byControlLabel('Close workspace'));
    await tester.pumpAndSettle();
    expect(byControlLabel('Close workspace'), findsNothing);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture-focused-routes')),
    );
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(boundary);
    await tester.pump();
    // Match Flutter's golden matcher: build the image future in the frame's
    // test zone, then await rasterization in runAsync. Starting toImage inside
    // runAsync can omit retained overlay layers (Close/debug banner).
    final closeCenter = tester.getCenter(byControlLabel('Close workspace'));
    final pendingImage = boundary.toImage(pixelRatio: 1);
    await tester.runAsync(() async {
      final image = await pendingImage;
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var paintedClosePixels = 0;
      for (
        var y = closeCenter.dy.round() - 10;
        y <= closeCenter.dy.round() + 10;
        y++
      ) {
        for (
          var x = closeCenter.dx.round() - 10;
          x <= closeCenter.dx.round() + 10;
          x++
        ) {
          final offset = (y * image.width + x) * 4;
          if (rgba.getUint8(offset) > 120 &&
              rgba.getUint8(offset + 1) > 120 &&
              rgba.getUint8(offset + 2) > 120) {
            paintedClosePixels++;
          }
        }
      }
      expect(
        paintedClosePixels,
        greaterThan(16),
        reason:
            '$name must paint its Close glyph, not merely expose a hit target.',
      );
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('$captures/$name.png').writeAsBytes(png.buffer.asUint8List());
      image.dispose();
    });
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  Finder workspace() => find.byWidgetPredicate(
    (widget) =>
        widget.key == const ValueKey('context-workspace') ||
        widget.key == const ValueKey('commander-workspace'),
  );
  void assertClearControls(WidgetTester tester) {
    final surface = workspace();
    final close = byControlLabel('Close workspace');
    final closeRect = tester.getRect(close);
    expect(close.hitTestable(), findsOneWidget);
    expect(closeRect.width, greaterThanOrEqualTo(44));
    expect(closeRect.height, greaterThanOrEqualTo(44));
    final buttons = find.descendant(
      of: surface,
      matching: find.byWidgetPredicate(
        (w) => w is ButtonStyleButton || w is SwitchListTile || w is ChoiceChip,
      ),
    );
    for (final element in buttons.evaluate()) {
      final target = find.byWidget(element.widget);
      if (element
              .findAncestorWidgetOfExactType<Semantics>()
              ?.properties
              .label ==
          'Close workspace') {
        continue;
      }
      if (target.hitTestable().evaluate().isEmpty) continue;
      expect(
        tester.getRect(target).deflate(.01).overlaps(closeRect),
        isFalse,
        reason: '${element.widget.runtimeType} must not overlap Close',
      );
    }
  }

  const pages = {
    'player': WorkspacePage.player,
    'counters': WorkspacePage.counters,
    'hub': WorkspacePage.tableHub,
    'new-game': WorkspacePage.reset,
    'archives': WorkspacePage.archives,
    'wipes': WorkspacePage.boardWipes,
    'settings': WorkspacePage.settings,
    'dice': WorkspacePage.dice,
  };
  for (final size in [const Size(1133, 744), const Size(600, 1024)]) {
    for (final entry in pages.entries) {
      testWidgets('${entry.key} focused route at $size', (tester) async {
        final f = await open(tester, size, entry.value);
        expect(find.widgetWithText(ChoiceChip, 'Player'), findsNothing);
        expect(find.widgetWithText(ChoiceChip, 'Counters'), findsNothing);
        expect(find.widgetWithText(ChoiceChip, 'Settings'), findsNothing);
        expect(byControlLabel('Back'), findsNothing);
        final shell = tester.getRect(workspace());
        expect(shell.left, greaterThanOrEqualTo(16));
        expect(shell.top, greaterThanOrEqualTo(16));
        expect(shell.right, lessThanOrEqualTo(size.width - 16));
        expect(shell.bottom, lessThanOrEqualTo(size.height - 16));
        if (entry.value == WorkspacePage.counters) {
          expect(shell.width, size.width == 600 ? 568 : 620);
          expect(shell.height, lessThan(640));
        } else {
          expect(shell.size, Size(size.width == 600 ? 568 : 720, 640));
        }
        assertClearControls(tester);
        if (entry.value == WorkspacePage.player) {
          expect(find.text('Has partner'), findsOneWidget);
          expect(field('Commander name'), findsNothing);
          expect(find.text('Player counters'), findsNothing);
          final owner = f.controller.session.players.first;
          expect(
            f.controller.session.commanderTrackingSources
                .where((s) => s.ownerPlayerId == owner.id)
                .length,
            1,
          );
          await tester.tap(find.text('Has partner'));
          await tester.pumpAndSettle();
          expect(f.controller.session.hasPartner(owner.id), isTrue);
          expect(
            f.controller.session.commanderTrackingSources
                .where((s) => s.ownerPlayerId == owner.id)
                .length,
            2,
          );
        }
        if (entry.value == WorkspacePage.counters) {
          expect(find.text('Has partner'), findsNothing);
          expect(field('Player name'), findsNothing);
          expect(
            find.byKey(const ValueKey('focused-commander-grid')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('player-counter-energy')),
            findsOneWidget,
          );
          expect(find.text('Add counter'), findsNothing);
          expect(f.player.counters['energy'], 0);
          expect(byControlLabel('Set energy total'), findsNothing);
          expect(find.byType(TextField), findsNothing);
          expect(byControlLabel('Increase energy'), findsOneWidget);
          assertClearControls(tester);
        }
        if (entry.value == WorkspacePage.reset) {
          expect(find.text('Friday Commander'), findsNothing);
          expect(find.text('Wipe all creatures'), findsNothing);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.label == '2 players',
            ),
            findsOneWidget,
          );
        }
        if (entry.value == WorkspacePage.archives) {
          expect(find.text('Friday Commander'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.label == '2 players',
            ),
            findsNothing,
          );
        }
        if (entry.value == WorkspacePage.boardWipes) {
          expect(find.text('Everyone'), findsOneWidget);
          expect(find.text('Friday Commander'), findsNothing);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.label == '2 players',
            ),
            findsNothing,
          );
        }
        await capture(
          tester,
          '${entry.key}-${size.width.toInt()}x${size.height.toInt()}',
        );
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }
    testWidgets('hub routes Back restores only tools at $size', (tester) async {
      final f = await open(tester, size, WorkspacePage.tableHub);
      final before = f.controller.session.toJson();
      for (final label in [
        'Dice',
        'History',
        'New game',
        'Archives',
        'Board wipes',
        'Settings',
      ]) {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(byControlLabel('Back'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Settings'), findsNothing);
        assertClearControls(tester);
        await tester.tap(byControlLabel('Back'));
        await tester.pumpAndSettle();
        expect(byControlLabel('Back'), findsNothing);
        expect(find.text('New game'), findsOneWidget);
        expect(find.text('Archives'), findsOneWidget);
      }
      expect(f.controller.session.toJson(), before);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
  for (final size in [const Size(1133, 744), const Size(600, 1024)]) {
    testWidgets('mixed unconfigured primary and partner owners at $size', (
      tester,
    ) async {
      final f = await open(tester, size, WorkspacePage.commanderDamage);
      final owners = f.controller.session.players;
      await f.controller.setHasPartner(owners[1].id, true);
      await f.controller.addCommander(owners[2].id, 'Preserved legacy name');
      await f.controller.setHasPartner(owners[3].id, true);
      await tester.pumpAndSettle();
      expect(
        f.controller.session.commanders.where(
          (s) => s.ownerPlayerId == owners[0].id,
        ),
        isEmpty,
      );
      final sources = f.controller.session.commanderTrackingSources;
      expect(sources.length, 6);
      expect(
        find.byKey(const ValueKey('focused-commander-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('commander-density-fallback')),
        findsNothing,
      );
      for (final source in sources) {
        for (final action in ['increase', 'decrease']) {
          final target = find.byKey(ValueKey('commander-$action-${source.id}'));
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
          expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
        }
        expect(
          find.byKey(ValueKey('commander-edit-${source.id}')),
          findsNothing,
        );
      }
      await capture(
        tester,
        'commander-mixed-${size.width.toInt()}x${size.height.toInt()}',
      );
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
}
