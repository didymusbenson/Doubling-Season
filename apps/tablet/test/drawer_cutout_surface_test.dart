import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/ui/table_screen.dart';
import 'package:tripling_table/ui/table_theme.dart';

import 'support/table_fixture.dart';

void main() {
  late Directory directory;
  late String artwork;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('drawer-surface-');
    Hive.init(directory.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xffffd66a), BlendMode.src);
    canvas.drawRect(
      const Rect.fromLTWH(32, 0, 32, 64),
      Paint()..color = const Color(0xff183a70),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    artwork =
        'data:image/png;base64,${base64Encode(data!.buffer.asUint8List())}';
    image.dispose();
    picture.dispose();
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
      for (final seats in [2, 3, 4]) {
        testWidgets(
          '$brightness $size $seats seats cutout follows drawer surface',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);
            final state = TabletState.initial();
            state.session.players = state.session.players.take(seats).toList();
            for (final profile in state.profiles) {
              profile.artworkUrl = artwork;
            }
            for (final player in state.session.players) {
              player.tokens = [
                sampleToken(id: '${player.id}-token', artworkUrl: artwork),
              ];
            }
            final fixture = TableFixture(state);
            await fixture.initialize();
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
              fixture.dispose();
            });
            final theme = tableTheme(brightness);
            expect(
              theme.scaffoldBackgroundColor,
              isNot(theme.colorScheme.surface),
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: RepaintBoundary(
                  key: const ValueKey('cutout-capture'),
                  child: TableScreen(controller: fixture.controller),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final before = jsonEncode(fixture.controller.state.toJson());

            Future<void> expectSurface() async {
              final table = tester.getRect(
                find.byKey(const ValueKey('table-surface')),
              );
              final reveal = find
                  .descendant(
                    of: find.byKey(const ValueKey('table-drawer-layer')),
                    matching: find.byType(ClipRect),
                  )
                  .first;
              final channel = tester
                  .widget<ClipRect>(reveal)
                  .clipper!
                  .getClip(tester.getSize(reveal))
                  .shift(tester.getTopLeft(reveal));
              final samples = seats == 2
                  ? [
                      Offset(table.left + 30, channel.top - 14),
                      Offset(table.left + 25, channel.top - 10),
                      Offset(table.left + 35, channel.top - 10),
                      Offset(table.left + 8, channel.top + 6),
                    ]
                  : [
                      Offset(channel.left - 20, table.center.dy),
                      Offset(channel.left - 10, table.center.dy - 10),
                      Offset(channel.left - 10, table.center.dy + 10),
                      Offset(channel.left + 6, table.center.dy),
                    ];
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('cutout-capture')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                final pixels = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                // These points lie inside the exposed half-circle, away from its
                // antialiased wall and the Dice target. The final point is inside
                // the rectangular workspace, proving both surfaces match.
                for (final point in samples) {
                  final local = boundary.globalToLocal(point);
                  final index =
                      (local.dy.floor() * image.width + local.dx.floor()) * 4;
                  final color = Color.fromARGB(
                    pixels.getUint8(index + 3),
                    pixels.getUint8(index),
                    pixels.getUint8(index + 1),
                    pixels.getUint8(index + 2),
                  );
                  expect(
                    color,
                    theme.colorScheme.surface,
                    reason: 'Exposed drawer at $point',
                  );
                }
                image.dispose();
              });
            }

            final menu = find.byKey(const ValueKey('central-game-controls'));
            await tester.tap(menu);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 70));
            await expectSurface();
            await tester.pump(const Duration(milliseconds: 155));
            await expectSurface();
            await tester.pumpAndSettle();
            await expectSurface();
            expect(tester.getSize(menu), const Size(52, 52));
            expect(menu.hitTestable(), findsOneWidget);
            await tester.tap(menu);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('table-drawer-surface')),
              findsNothing,
            );
            expect(jsonEncode(fixture.controller.state.toJson()), before);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
