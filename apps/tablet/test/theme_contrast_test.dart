import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/utility_inline_actions.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';
import 'support/table_fixture.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('theme-contrast-');
    Hive.init(directory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (captures != null) {
      await Directory(captures).create(recursive: true);
      await (FontLoader('Mana')..addFont(
            File(
              'assets/fonts/mana.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      for (final font in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final bytes = File(
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/${font.value}',
        );
        await (FontLoader(
          font.key,
        )..addFont(bytes.readAsBytes().then(ByteData.sublistView))).load();
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
      find.byKey(const ValueKey('theme-capture')),
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
    test('$brightness shared palette contrast and disabled distinction', () {
      final theme = tableTheme(brightness), c = theme.colorScheme;
      final old = ColorScheme.fromSeed(
        seedColor: const Color(0xFF91B79B),
        brightness: brightness,
        surface: c.surface,
      );
      for (final pair in [
        (c.onSecondaryContainer, c.secondaryContainer),
        (c.onPrimaryContainer, c.primaryContainer),
        (c.onErrorContainer, c.errorContainer),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      for (final background in [
        c.surface,
        c.surfaceContainer,
        c.surfaceContainerLow,
        c.surfaceContainerHigh,
        c.surfaceContainerHighest,
        theme.scaffoldBackgroundColor,
      ]) {
        expect(
          contrast(c.onSurfaceVariant, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(c.outline, background), greaterThanOrEqualTo(3));
      }
      expect(
        contrast(c.outline, c.secondaryContainer),
        greaterThanOrEqualTo(3),
      );
      expect(
        theme.filledButtonTheme.style!.side!.resolve({})!.color,
        c.outline,
      );
      expect(
        theme.filledButtonTheme.style!.side!.resolve({WidgetState.disabled}),
        isNull,
      );
      // Emit auditable ratios rather than treating low decorative fill contrast
      // as a text failure. Enabled controls also receive a visible boundary.
      debugPrint(
        '${brightness.name}: tonal fill/surface ${contrast(old.secondaryContainer, old.surface).toStringAsFixed(2)} -> ${contrast(c.secondaryContainer, c.surface).toStringAsFixed(2)}; outline/highest ${contrast(old.outline, old.surfaceContainerHighest).toStringAsFixed(2)} -> ${contrast(c.outline, c.surfaceContainerHighest).toStringAsFixed(2)}; small secondary text/surface ${contrast(old.outline, old.surface).toStringAsFixed(2)} -> ${contrast(c.onSurfaceVariant, c.surface).toStringAsFixed(2)}; neutral icon/highest ${contrast(Color.alphaBlend(old.onSurfaceVariant.withValues(alpha: .5), old.surfaceContainerHighest), old.surfaceContainerHighest).toStringAsFixed(2)} -> ${contrast(c.onSurfaceVariant, c.surfaceContainerHighest).toStringAsFixed(2)}; tonal text ${contrast(c.onSecondaryContainer, c.secondaryContainer).toStringAsFixed(2)}',
      );
    });
    testWidgets('$brightness actual utility actions and disabled controls', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 500);
      addTearDown(tester.view.reset);
      final f = TableFixture();
      await f.initialize();
      addTearDown(f.dispose);
      await f.board.addUtility(f.playerId, 'cathars_crusade');
      final utility = f.player.utilities.firstWhere(
        (u) => u.kind == 'cathars_crusade',
      );
      final theme = tableTheme(brightness), c = theme.colorScheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RepaintBoundary(
            key: const ValueKey('theme-capture'),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UtilityInlineActions(
                        board: f.board,
                        playerId: f.playerId,
                        utility: utility,
                      ),
                      const FilledButton.tonal(
                        onPressed: null,
                        child: Text('Disabled action'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(ValueKey('utility-action-${utility.id}'));
      final label = tester.renderObject<RenderParagraph>(
        find.descendant(of: action, matching: find.text('Resolve All')),
      );
      final material = tester.widget<Material>(
        find.descendant(of: action, matching: find.byType(Material)).first,
      );
      expect(material.color, c.secondaryContainer);
      expect(
        contrast(label.text.style!.color!, material.color!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast((material.shape! as OutlinedBorder).side.color, c.surface),
        greaterThanOrEqualTo(3),
      );
      final disabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Disabled action'),
      );
      expect(disabled.onPressed, isNull);
      await capture(tester, 'theme-${brightness.name}-utility-actions');
      expect(tester.takeException(), isNull);
    });
    testWidgets('$brightness actual player counter chip boundary', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1133, 744);
      addTearDown(tester.view.reset);
      final f = TableFixture();
      await f.initialize();
      f.catalog.loaded = true;
      f.player.counters = {'energy': 2};
      addTearDown(f.dispose);
      final theme = tableTheme(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RepaintBoundary(
            key: const ValueKey('theme-capture'),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTableWorkspace(
                    context,
                    f.controller,
                    catalog: f.catalog,
                    seatId: f.playerId,
                    quarterTurns: 0,
                    initialPage: WorkspacePage.counters,
                  ),
                  child: const Text('Counters'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Counters'));
      await tester.pumpAndSettle();
      addTearDown(() async {
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
      });
      final chip = find.byKey(const ValueKey('player-counter-energy'));
      final material = tester.widget<Material>(
        find.descendant(of: chip, matching: find.byType(Material)).first,
      );
      expect(material.color, theme.colorScheme.surfaceContainerHighest);
      final side = (material.shape! as OutlinedBorder).side;
      expect(contrast(side.color, material.color!), greaterThanOrEqualTo(3));
      expect(
        contrast(side.color, theme.colorScheme.surface),
        greaterThanOrEqualTo(3),
      );
      expect(tester.takeException(), isNull);
    });
    for (final page in [
      WorkspacePage.reset,
      WorkspacePage.settings,
      WorkspacePage.tableHub,
    ]) {
      testWidgets('$brightness rendered $page', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1133, 744);
        addTearDown(tester.view.reset);
        final f = TableFixture();
        await f.initialize();
        f.catalog.loaded = true;
        addTearDown(f.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: tableTheme(brightness),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: const ValueKey('theme-capture'),
                  child: SizedBox(
                    width: 440,
                    height: 700,
                    child: GameDrawerWorkspace(
                      controller: f.controller,
                      catalog: f.catalog,
                      drawerController: GameDrawerController(),
                      initialPage: page,
                      onClose: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (page == WorkspacePage.reset) {
          await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
          await tester.pumpAndSettle();
          final card = find.byKey(const ValueKey('starting-life-card'));
          for (final button in tester.widgetList<IconButton>(
            find.descendant(of: card, matching: find.byType(IconButton)),
          )) {
            expect(button.onPressed, isNotNull);
            final side = button.style!.side!;
            expect(
              contrast(
                side.resolve({})!.color,
                tableTheme(brightness).colorScheme.surfaceContainerHigh,
              ),
              greaterThanOrEqualTo(3),
            );
            expect(side.resolve({WidgetState.disabled}), isNull);
          }
          final selected = tester.renderObject<RenderParagraph>(
            find.text('Custom'),
          );
          expect(
            contrast(
              selected.text.style!.foreground?.color ??
                  selected.text.style!.color!,
              tableTheme(brightness).colorScheme.secondaryContainer,
            ),
            greaterThanOrEqualTo(4.5),
          );
        }
        await capture(tester, 'theme-${brightness.name}-${page.name}');
        expect(tester.takeException(), isNull);
      });
    }
    for (final count in [4, 6]) {
      testWidgets(
        '$brightness rendered $count seats, tabs, controls, empty lanes',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1133, 744);
          addTearDown(tester.view.reset);
          final f = TableFixture();
          await f.initialize();
          await f.controller.resetGame(keepBoard: false, playerCount: count);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            f.dispose();
          });
          final theme = tableTheme(brightness), c = theme.colorScheme;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: RepaintBoundary(
                key: const ValueKey('theme-capture'),
                child: TableScreen(controller: f.controller),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final element in find.text('Your token board').evaluate()) {
            final text = element.renderObject! as RenderParagraph;
            expect(
              contrast(text.text.style!.color!, c.surface),
              greaterThanOrEqualTo(4.5),
            );
          }
          for (final player in f.controller.session.players) {
            final profile = f.controller.profile(player.seatId);
            final background = Color.alphaBlend(
              Color(profile.color).withValues(alpha: .19),
              c.surface,
            );
            final name = tester.renderObject<RenderParagraph>(
              find.text(profile.name).first,
            );
            final foreground = Color.alphaBlend(
              name.text.style!.color!,
              background,
            );
            expect(
              contrast(foreground, background),
              greaterThanOrEqualTo(4.5),
              reason: '${brightness.name} seat ${profile.name}',
            );
          }
          final day = find.byKey(const ValueKey('shared-day-night'));
          final icon = tester.widget<Icon>(
            find.descendant(of: day, matching: find.byType(Icon)),
          );
          expect(
            contrast(icon.color!, c.surfaceContainerHighest),
            greaterThanOrEqualTo(3),
          );
          if (count == 6) {
            final tab = find.byKey(ValueKey('${f.playerId}-tokens-tab'));
            final text = tester.renderObject<RenderParagraph>(
              find.descendant(of: tab, matching: find.text('Tokens')),
            );
            expect(text.text.style!.color, c.onSecondaryContainer);
            expect(
              contrast(text.text.style!.color!, c.secondaryContainer),
              greaterThanOrEqualTo(4.5),
            );
          }
          await capture(tester, 'theme-${brightness.name}-${count}p');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
