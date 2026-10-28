import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/tablet_token_card.dart';
import 'package:tripling_table/ui/table_mana_icons.dart';

import 'support/table_fixture.dart';

const _capture = ValueKey('field-second-capture');
final _directory = Platform.environment['TABLET_CAPTURE_DIR'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hive;
  setUpAll(() async {
    hive = await Directory.systemTemp.createTemp('field-second-');
    Hive.init(hive.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    for (final font in {
      'sans-serif': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(
        '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts/${font.value}',
      );
      if (await file.exists()) {
        await (FontLoader(
          font.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
    if (_directory != null) {
      await Directory(_directory!).create(recursive: true);
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await hive.delete(recursive: true);
  });

  Future<TableFixture> board(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final state = TabletState.initial();
    for (final player in state.session.players) {
      player.tokens = [
        sampleToken(id: '${player.id}-token', counters: {'charge': 1}),
      ];
    }
    final fixture = TableFixture(state);
    await fixture.initialize();
    addTearDown(() async {
      if (find.byTooltip('Close workspace').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      fixture.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: tableTheme(Brightness.dark),
        home: RepaintBoundary(
          key: _capture,
          child: TableScreen(controller: fixture.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<(Uint8List, int)> pixels(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_capture),
    );
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      if (_directory != null) {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '$_directory/$name.png',
        ).writeAsBytes(png.buffer.asUint8List());
      }
      final result = (
        Uint8List.fromList(bytes.buffer.asUint8List()),
        image.width,
      );
      image.dispose();
      return result;
    }))!;
  }

  for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
    testWidgets(
      'owned Monarch hold clears once, stays visible and undo restores at $size',
      (tester) async {
        final f = await board(tester, size);
        final p = f.playerId;
        await tester.tap(find.byTooltip('Player 1, player counters'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Monarch · Off'));
        await tester.pumpAndSettle();
        expect(f.controller.session.monarchPlayerId, p);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byTooltip('Monarch · On')),
        );
        await tester.pump(const Duration(milliseconds: 650));
        expect(f.controller.session.monarchPlayerId, isNull);
        await pixels(tester, 'monarch-held-${size.width.toInt()}');
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          f.controller.session.monarchPlayerId,
          isNull,
          reason: 'Release must not trail into claim.',
        );
        expect(find.byTooltip('Monarch · Off'), findsOneWidget);
        await f.controller.undo();
        await tester.pumpAndSettle();
        expect(f.controller.session.monarchPlayerId, p);
        final next = f.controller.session.players[1];
        await tester.tap(find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Player 2, player counters'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Monarch · Off'));
        await tester.pumpAndSettle();
        expect(f.controller.session.monarchPlayerId, next.id);
        expect(find.byIcon(TableManaIcons.ascend), findsOneWidget);
        await tester.tap(find.byTooltip('Close workspace'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close workspace'), findsNothing);
      },
    );

    testWidgets(
      'names remain centered and swipe cannot paint over life during motion at $size',
      (tester) async {
        final f = await board(tester, size);
        for (final p in f.controller.session.players) {
          final text = tester.getCenter(
            find.byKey(ValueKey('${p.id}-player-name')),
          );
          final surface = tester.getCenter(
            find.byKey(ValueKey('${p.id}-life-surface')),
          );
          expect((text.dx - surface.dx).abs(), lessThan(1));
        }
        // Lower-right seat swipes toward its adjacent life zone, exercising the
        // transformed Dismissible content rather than a settled/deleted row.
        final p = f.controller.session.players.last;
        final life = tester
            .getRect(find.byKey(ValueKey('${p.id}-life-surface')))
            .deflate(2);
        final card = find
            .descendant(
              of: find.byKey(ValueKey(p.id)),
              matching: find.byType(TabletTokenCard),
            )
            .first;
        final before = await pixels(
          tester,
          'swipe-before-${size.width.toInt()}',
        );
        final gesture = await tester.startGesture(tester.getCenter(card));
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveBy(const Offset(-105, 0));
        await tester.pump(const Duration(milliseconds: 80));
        expect(
          tester
              .widgetList<SlideTransition>(
                find.descendant(
                  of: card,
                  matching: find.byType(SlideTransition),
                ),
              )
              .any((slide) => slide.position.value.dx.abs() > .1),
          isTrue,
          reason: 'Capture a token actually displaced by an active swipe.',
        );
        final during = await pixels(
          tester,
          'swipe-during-${size.width.toInt()}',
        );
        var changed = 0;
        for (var y = life.top.ceil(); y < life.bottom.floor(); y++) {
          for (var x = life.left.ceil(); x < life.right.floor(); x++) {
            final offset = (y * before.$2 + x) * 4;
            for (var c = 0; c < 4; c++) {
              if (before.$1[offset + c] != during.$1[offset + c]) changed++;
            }
          }
        }
        expect(
          changed,
          0,
          reason: 'A moving token must be clipped behind the life zone.',
        );
        await gesture.up();
        await tester.pumpAndSettle();
        if (f.controller.player(p.id).tokens.isEmpty) {
          await f.controller.undo();
          await tester.pumpAndSettle();
        }
        expect(f.controller.player(p.id).tokens, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
