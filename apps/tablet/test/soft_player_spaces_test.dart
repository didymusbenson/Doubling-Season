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

import 'support/table_fixture.dart';

const captureKey = ValueKey('soft-spaces-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captures = Platform.environment['TABLET_CAPTURE_DIR'];
  late Directory catalog;
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('soft-player-spaces-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (captures != null) {
      await Directory(captures).create(recursive: true);
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
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
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });

  Future<TableFixture> mount(
    WidgetTester tester,
    int count,
    Size size,
    Brightness brightness,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    final f = TableFixture();
    await f.initialize();
    await f.controller.resetGame(keepBoard: false, playerCount: count);
    for (final p in f.controller.session.players) {
      p.tokens = [
        sampleToken(id: '${p.id}-token-0', name: 'Saproling', plusOne: 2),
        sampleToken(id: '${p.id}-token-1', name: 'Soldier', colors: 'W'),
        sampleToken(
          id: '${p.id}-token-2',
          name: 'Treasure',
          colors: '',
          pt: '',
          type: 'Artifact — Treasure',
        ),
        for (var n = 3; n < 8; n++)
          sampleToken(id: '${p.id}-token-$n', name: 'Elf $n'),
      ];
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tableTheme(brightness),
          home: TableScreen(controller: f.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      f.dispose();
    });
    return f;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (captures == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$captures/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  for (final count in [2, 3, 4, 5, 6]) {
    for (final size in [const Size(1133, 744), const Size(744, 1133)]) {
      testWidgets(
        '$count player spaces retain 8px rivers and 14px corners at $size',
        (tester) async {
          final f = await mount(tester, count, size, Brightness.dark);
          final table = tester.getRect(
            find.byKey(const ValueKey('table-surface')),
          );
          for (final row in f.controller.session.seatRows) {
            for (final p in row.whereType<PlayerState>()) {
              final clipFinder = find.byKey(ValueKey('${p.id}-space-clip'));
              final clip = tester.widget<ClipRRect>(clipFinder);
              final bounds = tester.getRect(clipFinder);
              final rounded = clip.clipper!.getClip(tester.getSize(clipFinder));
              expect(rounded.tlRadiusX, 14);
              expect(rounded.brRadiusX, 14);
              expect(
                rounded.outerRect,
                Offset.zero & tester.getSize(clipFinder),
              );
              expect(rounded.contains(const Offset(1, 1)), isFalse);
              expect(
                bounds.width,
                closeTo((table.width - (row.length - 1) * 8) / row.length, .01),
              );
              expect(bounds.height, closeTo((table.height - 8) / 2, .01));
              expect(
                find.byKey(ValueKey('${p.id}-life-surface')).hitTestable(),
                findsOneWidget,
              );
            }
          }
          final horizontal = tester.getRect(
            find.byKey(const ValueKey('player-horizontal-river')),
          );
          expect(horizontal.height, 8);
          expect(horizontal.center.dy, table.center.dy);
          for (final control in [
            'central-game-controls',
            'shared-dice',
            'shared-day-night',
          ]) {
            expect(find.byKey(ValueKey(control)).hitTestable(), findsOneWidget);
          }
          // The river and trimmed corners expose the same black underlay in both
          // themes, rather than a painted dividing stroke or player-colored frame.
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(captureKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              for (final point in [
                Offset(table.left + 1, table.top + 1),
                Offset(table.left + 50, table.center.dy),
              ]) {
                final local = boundary.globalToLocal(point);
                final offset =
                    (local.dy.floor() * image.width + local.dx.floor()) * 4;
                expect(bytes.getUint8(offset), 0);
                expect(bytes.getUint8(offset + 1), 0);
                expect(bytes.getUint8(offset + 2), 0);
                expect(bytes.getUint8(offset + 3), 255);
              }
            } finally {
              image.dispose();
            }
          });
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final count in [4, 6]) {
    for (final size in [
      const Size(1133, 744),
      const Size(744, 1133),
      const Size(1194, 834),
      const Size(1366, 1024),
    ]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'populated $count spaces at $size $brightness preserve drawer and interactions',
          (tester) async {
            final f = await mount(tester, count, size, brightness);
            final name =
                'soft-${count}p-${size.width.toInt()}x${size.height.toInt()}-${brightness.name}';
            await capture(tester, '$name-tokens');
            final p = f.controller.session.players.first;
            final before = p.tokens.first.amount;
            await tester.tap(
              find.byKey(ValueKey('${p.tokens.first.id}-quantity-increase')),
            );
            await tester.pumpAndSettle();
            expect(f.controller.player(p.id).tokens.first.amount, before + 1);
            final tokenList = find.descendant(
              of: find.byKey(ValueKey('${p.id}-token-lane')),
              matching: find.byType(ReorderableListView),
            );
            final scroll = tester
                .widget<ReorderableListView>(tokenList)
                .scrollController!;
            scroll.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            final lastQuantity = find.byKey(
              ValueKey('${p.tokens.last.id}-quantity-increase'),
            );
            expect(
              lastQuantity.hitTestable(),
              findsOneWidget,
              reason:
                  'Final token actions stay reachable above the corner overlays.',
            );
            scroll.jumpTo(0);
            await tester.pumpAndSettle();
            for (final player in f.controller.session.players) {
              final tab = find.byKey(ValueKey('${player.id}-utilities-tab'));
              if (tab.evaluate().isNotEmpty) {
                await tester.tap(tab);
                await tester.pumpAndSettle();
              }
            }
            await capture(tester, '$name-utilities');
            final menu = find.byKey(const ValueKey('central-game-controls'));
            final life = p.life;
            final tokenLane = find.byKey(
              ValueKey('${p.id}-token-lane'),
              skipOffstage: false,
            );
            final tokenWidth = tester.getSize(tokenLane).width;
            await tester.tap(menu);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 110));
            expect(tester.takeException(), isNull);
            if (count == 4 && size.width >= 1048) {
              final table = tester.getRect(
                find.byKey(const ValueKey('table-surface')),
              );
              final shift = tester.getCenter(menu).dx - table.center.dx;
              expect(shift, greaterThan(0));
              for (final player in f.controller.session.players) {
                final clipFinder = find.byKey(
                  ValueKey('${player.id}-space-clip'),
                );
                final clipSize = tester.getSize(clipFinder);
                final rounded = tester
                    .widget<ClipRRect>(clipFinder)
                    .clipper!
                    .getClip(clipSize);
                expect(rounded.width, closeTo(clipSize.width - shift, .01));
                expect(rounded.height, clipSize.height);
                expect(rounded.tlRadiusX, 14);
                final tokenLeft = player.slot == 0 || player.slot == 2;
                expect(rounded.left, tokenLeft ? 0 : closeTo(shift, .01));
              }
            }
            await capture(tester, '$name-opening');
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('table-drawer-layer')),
              findsOneWidget,
            );
            expect(tester.getSize(tokenLane).width, tokenWidth);
            expect(
              find.byKey(ValueKey('${p.id}-life-surface')).hitTestable(),
              findsNothing,
            );
            await capture(tester, '$name-drawer');
            // Repeated menu dismissal and reopening leave the board intact.
            await tester.tap(menu);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('table-drawer-layer')),
              findsNothing,
            );
            expect(
              find.byKey(ValueKey('${p.id}-life-surface')).hitTestable(),
              findsOneWidget,
            );
            await tester.tap(menu);
            await tester.pumpAndSettle();
            final dismissal = find.byKey(ValueKey('${p.id}-dismiss-drawer'));
            await tester.tap(dismissal);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('table-drawer-layer')),
              findsNothing,
            );
            expect(
              f.controller.player(p.id).life,
              life,
              reason: 'Closing tap must not change the board.',
            );
            expect(f.controller.player(p.id).tokens.first.amount, before + 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
