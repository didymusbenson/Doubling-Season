import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/half_stepper.dart';
import 'support/table_fixture.dart';
import 'support/legacy_utility_fixture.dart';

final captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
final capturePhase = Platform.environment['UTILITY_CAPTURE_PHASE'] ?? 'after';
const captureKey = ValueKey('legacy-utility-renderer');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalogDirectory;
  setUpAll(() async {
    catalogDirectory = await Directory.systemTemp.createTemp(
      'utility-presentation-catalog-',
    );
    Hive.init(catalogDirectory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (captureDirectory == null) return;
    await Directory(captureDirectory!).create(recursive: true);
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    for (final entry in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${entry.value}',
      );
      if (await file.exists()) {
        await (FontLoader(
          entry.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
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
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$captureDirectory/$capturePhase-$name.png',
        ).writeAsBytes(data.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Future<TableFixture> openBoard(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    final fixture = TableFixture(legacyUtilityState());
    await fixture.initialize();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      fixture.dispose();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: tableTheme(Brightness.dark),
          home: TableScreen(controller: fixture.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  // Deliberately reusable on the old source as a before/after renderer fixture.
  // Behavioral filtering and payload preservation are asserted separately.
  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets('capture populated legacy board and utility menu at $size', (
      tester,
    ) async {
      final fixture = await openBoard(tester, size);
      final before = fixture.player.utilities.map((u) => u.toJson()).toList();
      final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
      await capture(tester, 'legacy-board-$dimensions');
      await tester.tap(
        find.byKey(ValueKey('${fixture.playerId}-manage-utilities')),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'legacy-menu-$dimensions');
      expect(fixture.player.utilities.map((u) => u.toJson()).toList(), before);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
    });
  }
  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    for (final upper in [false, true]) {
      testWidgets(
        'metadata-only legacy settings and custom names at $size facing ${upper ? 'top' : 'bottom'}',
        (tester) async {
          final f = await openBoard(tester, size);
          final playerId = f.controller.session.players[upper ? 1 : 0].id;
          await f.board.createCustomUtility(playerId, name: 'Poison Counters');
          await f.board.createCustomUtility(
            playerId,
            name: 'Monarch',
            toggle: true,
          );
          await tester.pumpAndSettle();
          final player = f.controller.player(playerId);
          final before = player.utilities.map((u) => u.toJson()).toList();
          await tester.tap(find.byKey(ValueKey('$playerId-manage-utilities')));
          await tester.pumpAndSettle();
          for (final u in player.utilities) {
            expect(
              find.byKey(ValueKey('utility-menu-${u.id}')),
              f.board.isStandaloneUtilityKind(u.kind)
                  ? findsOneWidget
                  : findsNothing,
            );
          }
          final legacy = player.utilities.firstWhere(
            (u) => u.kind == 'life_total',
          );
          expect(
            find.byKey(ValueKey('legacy-settings-${legacy.id}')),
            findsNothing,
          );
          expect(find.text('Life Total'), findsNothing);
          if (upper) {
            await capture(
              tester,
              'menu-top-${size.width.toInt()}x${size.height.toInt()}',
            );
          }
          await tester.tap(find.text('Legacy settings'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(ValueKey('legacy-settings-${legacy.id}')),
          );
          await tester.pumpAndSettle();
          final detail = find.byKey(
            const ValueKey('utility-detail-life_total'),
          );
          expect(detail, findsOneWidget);
          expect(
            find.descendant(of: detail, matching: find.byType(HalfStepper)),
            findsNothing,
          );
          expect(
            find.descendant(of: detail, matching: find.byType(SwitchListTile)),
            findsNothing,
          );
          expect(find.byTooltip('Hide this utility'), findsNothing);
          expect(find.text('Set value'), findsNothing);
          expect(find.text('Artwork'), findsOneWidget);
          if (!upper) {
            await capture(
              tester,
              'legacy-metadata-${size.width.toInt()}x${size.height.toInt()}',
            );
          }
          await tester.tap(find.text('Artwork'));
          await tester.pumpAndSettle();
          expect(find.text('Upload utility artwork'), findsOneWidget);
          expect(
            f.controller
                .player(playerId)
                .utilities
                .map((u) => u.toJson())
                .toList(),
            before,
          );
          await tester.tap(find.byTooltip('Close workspace'));
          await tester.pumpAndSettle();
          expect(f.controller.player(playerId).life, 37);
          expect(f.controller.player(playerId).counters['poison'], 5);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'legacy-only lanes retain chooser and absent legacy means no disclosure',
    (tester) async {
      final f = await openBoard(tester, const Size(1133, 744));
      await f.controller.modifyLibrary((s) {
        for (final p in s.session.players) {
          p.utilities.removeWhere(
            (u) => !redundantUtilityKinds.contains(u.kind),
          );
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Choose utilities').hitTestable(), findsNWidgets(4));
      await tester.tap(find.text('Choose utilities').first);
      await tester.pumpAndSettle();
      expect(find.text('Legacy settings'), findsOneWidget);
      await f.controller.modifyLibrary((s) {
        for (final p in s.session.players) {
          p.utilities.clear();
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Legacy settings'), findsNothing);
      expect(find.text('Add a utility'), findsOneWidget);
      expect(find.text('Life Total'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close workspace'));
      await tester.pumpAndSettle();
    },
  );
}
