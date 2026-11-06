import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/table_fixture.dart';

void main() {
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('minor-visual-fixes-');
    Hive.init(directory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (captures != null) {
      await Directory(captures).create(recursive: true);
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
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('visual-fix-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$captures/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness custom life dial has readable selected and adjacent values',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1133, 744);
        addTearDown(tester.view.reset);
        final f = TableFixture();
        await f.initialize();
        f.catalog.loaded = true;
        addTearDown(f.dispose);
        final theme = tableTheme(brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: const ValueKey('visual-fix-capture'),
                  child: SizedBox(
                    width: 440,
                    height: 700,
                    child: GameDrawerWorkspace(
                      controller: f.controller,
                      catalog: f.catalog,
                      drawerController: GameDrawerController(),
                      initialPage: WorkspacePage.reset,
                      onClose: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
        await tester.pumpAndSettle();
        final dial = find.byKey(const ValueKey('starting-life-dial'));
        final wheel = tester.widget<ListWheelScrollView>(dial);
        final controller = wheel.controller! as FixedExtentScrollController;
        controller.jumpToItem(7);
        await tester.pumpAndSettle();
        final card = tester.widget<Card>(
          find.byKey(const ValueKey('starting-life-card')),
        );
        final highlight = tester.widget<Container>(
          find.byKey(const ValueKey('starting-life-selection')),
        );
        final selectedBackground =
            (highlight.decoration! as BoxDecoration).color!;
        double contrast(Color foreground, Color background) {
          final a = foreground.computeLuminance();
          final b = background.computeLuminance();
          return (math.max(a, b) + .05) / (math.min(a, b) + .05);
        }

        final selected = tester.widget<Text>(
          find.descendant(of: dial, matching: find.text('8')),
        );
        final adjacent = tester.widget<Text>(
          find.descendant(of: dial, matching: find.text('9')),
        );
        expect(
          contrast(selected.style!.color!, selectedBackground),
          greaterThanOrEqualTo(4.5),
        );
        final fadedAdjacent = Color.alphaBlend(
          adjacent.style!.color!.withValues(
            alpha: wheel.overAndUnderCenterOpacity,
          ),
          card.color!,
        );
        expect(contrast(fadedAdjacent, card.color!), greaterThanOrEqualTo(4.5));
        expect(selected.style!.fontWeight, FontWeight.w700);
        expect(find.byType(TextField), findsNothing);
        final adjustable = find
            .ancestor(of: dial, matching: find.byType(Semantics))
            .first;
        var semantics = tester.widget<Semantics>(adjustable);
        expect(semantics.properties.value, '8');
        semantics.properties.onIncrease!();
        await tester.pumpAndSettle();
        expect(controller.selectedItem, 8);
        semantics = tester.widget<Semantics>(adjustable);
        semantics.properties.onDecrease!();
        await tester.pumpAndSettle();
        expect(controller.selectedItem, 7);
        await tester.drag(dial, const Offset(0, -44));
        await tester.pumpAndSettle();
        expect(controller.selectedItem, greaterThan(7));
        expect(f.controller.session.startingLife, 40);
        await capture(tester, 'custom-life-${brightness.name}');
        expect(tester.takeException(), isNull);
      },
    );

    for (final count in [4, 5, 6]) {
      for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
        if (count == 4 && size.width > 1040) continue;
        testWidgets(
          '$brightness $count seats $size cutouts follow actual controls while opening and closing',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);
            final f = TableFixture();
            await f.initialize();
            await f.controller.resetGame(keepBoard: false, playerCount: count);
            await tester.pumpWidget(
              MaterialApp(
                theme: tableTheme(brightness),
                home: RepaintBoundary(
                  key: const ValueKey('visual-fix-capture'),
                  child: TableScreen(controller: f.controller),
                ),
              ),
            );
            await tester.pumpAndSettle();
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
              f.dispose();
            });
            final before = jsonEncode(f.controller.state.toJson());
            void expectControlClearance() {
              final controls = [
                for (final key in [
                  'table-dice-layer',
                  'table-menu-layer',
                  'table-day-night-layer',
                ])
                  tester.getCenter(find.byKey(ValueKey(key))),
              ];
              final boardFinder = find.byKey(
                const ValueKey('drawer-board-mask'),
              );
              final boardClip = tester.widget<ClipPath>(boardFinder);
              final boardBox = tester.renderObject<RenderBox>(boardFinder);
              final boardPath = boardClip.clipper!.getClip(boardBox.size);
              // Above the upper wall, only Dice owns a notch. The old Menu and
              // Day/Night positions must retain the board surface.
              for (final x in [controls[1].dx, controls[2].dx]) {
                final point = boardBox.globalToLocal(
                  Offset(x, controls[0].dy - 10),
                );
                expect(
                  boardPath.contains(point),
                  isTrue,
                  reason: 'Unused upper wall notch at $point',
                );
              }
              var checked = 0;
              for (final player in f.controller.session.players) {
                final finder = find.byKey(ValueKey('${player.id}-life-clip'));
                final clip = tester.widget<ClipPath>(finder);
                final box = tester.renderObject<RenderBox>(finder);
                final path = clip.clipper!.getClip(box.size);
                for (final control in controls) {
                  final local = Offset(box.globalToLocal(control).dx, 10);
                  if (!(Offset.zero & box.size).contains(local)) continue;
                  final global = box.localToGlobal(local);
                  final occupied = controls.any(
                    (center) => (center - global).distance < 30,
                  );
                  expect(
                    path.contains(local),
                    !occupied,
                    reason:
                        '${player.id} at $global should clear only actual controls $controls',
                  );
                  checked++;
                }
              }
              expect(checked, greaterThan(0));
            }

            expectControlClearance();
            final menu = find.byKey(const ValueKey('central-game-controls'));
            for (var repeat = 0; repeat < 2; repeat++) {
              await tester.tap(menu);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 12));
              expectControlClearance();
              await tester.pump(const Duration(milliseconds: 70));
              expectControlClearance();
              await tester.pumpAndSettle();
              expectControlClearance();
              if (repeat == 0) {
                await capture(
                  tester,
                  'drawer-${brightness.name}-${count}p-${size.width.toInt()}',
                );
              }
              await tester.tap(menu);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 80));
              expectControlClearance();
              await tester.pumpAndSettle();
              expectControlClearance();
            }
            expect(jsonEncode(f.controller.state.toJson()), before);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
