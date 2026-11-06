import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';
import 'package:tripling_table/ui/workspace/table_workspace.dart';

import 'support/control_finders.dart';
import 'support/table_fixture.dart';

const captureKey = ValueKey('feedback-capture');
final captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  late Directory catalogDirectory;
  setUpAll(() async {
    catalogDirectory = await Directory.systemTemp.createTemp(
      'feedback-catalog-',
    );
    Hive.init(catalogDirectory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (captureDirectory == null) return;
    final root = Platform.environment['FLUTTER_ROOT']!;
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '$root/bin/cache/artifacts/material_fonts/${font.value}',
      );
      await (FontLoader(
        font.key,
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
    await Directory(captureDirectory!).create(recursive: true);
  });

  tearDownAll(() async {
    await Hive.close();
    await catalogDirectory.delete(recursive: true);
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (captureDirectory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$captureDirectory/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Future<GameDrawerController> mount(
    WidgetTester tester,
    TableFixture fixture,
    WorkspacePage page, {
    double width = 440,
    double height = 700,
  }) async {
    tester.view.physicalSize = const Size(1133, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fixture.catalog.loaded = true;
    final drawer = GameDrawerController();
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: captureKey,
              child: SizedBox(
                width: width,
                height: height,
                child: GameDrawerWorkspace(
                  controller: fixture.controller,
                  catalog: fixture.catalog,
                  drawerController: drawer,
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
    return drawer;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'settings keeps one Day/Night control and separates catalog actions',
    (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await mount(tester, fixture, WorkspacePage.settings);
      expect(find.text('Day / Night'), findsNothing);
      expect(find.text('Neither'), findsNothing);
      expect(find.text('Tripling Table'), findsOneWidget);
      expect(find.textContaining('cosmetics never gate'), findsNothing);
      final check = find.widgetWithText(OutlinedButton, 'Check updates');
      final bundled = find.widgetWithText(OutlinedButton, 'Use bundled');
      expect(
        tester.getRect(bundled).top - tester.getRect(check).bottom,
        greaterThanOrEqualTo(10),
      );
      await capture(tester, 'settings');
    },
  );

  for (final startingLife in [20, 30, 40, 57]) {
    testWidgets(
      'starting life chips and custom dial save $startingLife without a keyboard',
      (tester) async {
        final fixture = TableFixture(stateWithTokens([sampleToken()]));
        await fixture.initialize();
        addTearDown(fixture.dispose);
        await mount(tester, fixture, WorkspacePage.reset);
        expect(find.byType(PlayerField), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.byKey(const ValueKey('starting-life-dial')), findsNothing);
        if (startingLife == 57) {
          await tap(tester, find.widgetWithText(ChoiceChip, 'Custom'));
          final picker = tester.widget<ListWheelScrollView>(
            find.byType(ListWheelScrollView),
          );
          (picker.controller! as FixedExtentScrollController).jumpToItem(56);
          await tester.pumpAndSettle();
          expect(
            (picker.controller! as FixedExtentScrollController).selectedItem,
            56,
          );
          await capture(tester, 'new-game-custom');
        } else {
          await tap(tester, find.widgetWithText(ChoiceChip, '$startingLife'));
          final chip = tester.widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, '$startingLife'),
          );
          expect(chip.selected, isTrue);
          if (startingLife == 30) await capture(tester, 'new-game-presets');
        }
        expect(fixture.controller.session.startingLife, 40);
        await tap(tester, find.text('Keep seats'));
        await tap(tester, find.text('Start game'));
        expect(fixture.controller.session.startingLife, startingLife);
        expect(
          fixture.controller.session.players.every(
            (p) => p.life == startingLife,
          ),
          isTrue,
        );
        expect(fixture.controller.state.archives, hasLength(1));
        expect(fixture.player.tokens.single.amount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('custom dial stays bounded and survives drawer navigation', (
    tester,
  ) async {
    final fixture = TableFixture();
    await fixture.initialize();
    addTearDown(fixture.dispose);
    final drawer = await mount(tester, fixture, WorkspacePage.reset);
    await tap(tester, find.widgetWithText(ChoiceChip, 'Custom'));
    var picker = tester.widget<ListWheelScrollView>(
      find.byType(ListWheelScrollView),
    );
    (picker.controller! as FixedExtentScrollController).jumpToItem(0);
    await tester.pumpAndSettle();
    IconButton step(String name) => tester.widget<IconButton>(
      find.descendant(
        of: byControlLabel(name),
        matching: find.byType(IconButton),
      ),
    );
    expect(step('Decrease starting life').onPressed, isNull);
    (picker.controller! as FixedExtentScrollController).jumpToItem(999999);
    await tester.pumpAndSettle();
    expect(step('Increase starting life').onPressed, isNull);
    (picker.controller! as FixedExtentScrollController).jumpToItem(24);
    await tester.pumpAndSettle();
    await drawer.open(WorkspacePage.settings);
    await tester.pumpAndSettle();
    await drawer.open(WorkspacePage.reset);
    await tester.pumpAndSettle();
    picker = tester.widget<ListWheelScrollView>(
      find.byType(ListWheelScrollView),
    );
    expect(
      (picker.controller! as FixedExtentScrollController).selectedItem,
      24,
    );
    await tap(tester, byControlLabel('Increase starting life'));
    expect(
      (picker.controller! as FixedExtentScrollController).selectedItem,
      25,
    );
    expect(fixture.controller.session.startingLife, 40);
    expect(fixture.controller.session.history, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wipes show global options only and cancellation leaves boards intact',
    (tester) async {
      final fixture = TableFixture(stateWithTokens([sampleToken()]));
      await fixture.initialize();
      addTearDown(fixture.dispose);
      await mount(tester, fixture, WorkspacePage.boardWipes);
      for (final name in [
        'Creatures',
        'Artifacts',
        'Enchantments',
        'Artifacts & enchantments',
        'Nonland permanents',
        'All tokens',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      for (var i = 1; i <= 4; i++) {
        expect(find.text('Player $i'), findsNothing);
      }
      await capture(tester, 'global-wipes');
      final before = fixture.repository.encoded;
      await tap(tester, find.text('Artifacts'));
      expect(fixture.repository.encoded, before);
      await tap(tester, find.text('Delete selected'));
      expect(find.text('Delete artifacts for everyone?'), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      expect(fixture.repository.encoded, before);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('player seams are stronger in $brightness', (tester) async {
      final fixture = TableFixture();
      await fixture.initialize();
      fixture.catalog.loaded = true;
      addTearDown(fixture.dispose);
      tester.view.physicalSize = const Size(1133, 744);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = tableTheme(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: TableScreen(controller: fixture.controller),
        ),
      );
      await tester.pumpAndSettle();
      final divider = tester.widget<Divider>(
        find.byKey(const ValueKey('player-horizontal-divider')),
      );
      expect(divider.thickness, 5);
      expect(divider.color, theme.colorScheme.onSurfaceVariant);
      expect(tester.takeException(), isNull);
    });
  }
}
