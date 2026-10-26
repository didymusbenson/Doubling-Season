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

final _captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
final _normalLife =
    Platform.environment['TABLET_CAPTURE_NORMAL_LIFE'] == 'true';
const _captureKey = ValueKey('commander-chip-renderer');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory catalog;
  setUpAll(() async {
    catalog = await Directory.systemTemp.createTemp('commander-chip-');
    Hive.init(catalog.path);
    await Hive.openBox<String>('tripling_season_tablet_catalog_v1');
    if (_captureDirectory != null) {
      final root = Platform.environment['FLUTTER_ROOT'];
      if (root == null) {
        throw StateError('Captures require FLUTTER_ROOT fonts');
      }
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
      await (FontLoader(
        'Mana',
      )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
      await Directory(_captureDirectory!).create(recursive: true);
    }
  });
  tearDownAll(() async {
    await Hive.close();
    await catalog.delete(recursive: true);
  });

  Rect painted(WidgetTester tester, Finder finder, {RenderObject? ancestor}) {
    final box = tester.renderObject<RenderBox>(finder);
    return MatrixUtils.transformRect(
      box.getTransformTo(ancestor),
      Offset.zero & box.size,
    );
  }

  Future<void> capture(WidgetTester tester, String name, {Rect? region}) async {
    if (_captureDirectory == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    await tester.runAsync(() async {
      var image = await boundary.toImage(pixelRatio: 1);
      if (region != null) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImageRect(image, region, Offset.zero & region.size, Paint());
        final picture = recorder.endRecording();
        final crop = await picture.toImage(
          region.width.ceil(),
          region.height.ceil(),
        );
        picture.dispose();
        image.dispose();
        image = crop;
      }
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$_captureDirectory/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  for (final size in const [
    Size(1133, 744),
    Size(744, 1133),
    Size(1366, 1024),
    Size(1024, 1366),
  ]) {
    for (final seats in [2, 3, 4]) {
      for (final sources in ['empty', 'single', 'partners']) {
        final populated = sources != 'empty';
        testWidgets('$seats seats $size embeds $sources ledger below signed life', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
          addTearDown(tester.view.reset);
          final state = TabletState.initial();
          if (seats == 2) {
            state.session.players = state.session.players.take(2).toList();
          }
          if (seats == 3) {
            state.session.players.removeAt(0);
          }
          for (var i = 0; i < seats; i++) {
            final player = state.session.players[i];
            player.life = _normalLife
                ? 40
                : i == 0
                ? -999999
                : i == 1
                ? 999999
                : 40;
            player.tokens = [sampleToken(id: '${player.id}-token')];
            if (sources == 'partners' || (sources == 'single' && i == 0)) {
              for (var n = 0; n < (sources == 'single' ? 1 : 2); n++) {
                state.session.commanders.add(
                  CommanderSource(
                    id: '${player.id}-$n',
                    ownerPlayerId: player.id,
                    name: n == 0 ? 'Partner A' : 'Partner B',
                  ),
                );
              }
            }
          }
          for (final player in state.session.players) {
            for (var n = 0; n < state.session.commanders.length; n++) {
              player.commanderDamage[state.session.commanders[n].id] = n + 1;
            }
          }
          final fixture = TableFixture(state);
          await fixture.initialize();
          await tester.pumpWidget(
            RepaintBoundary(
              key: _captureKey,
              child: MaterialApp(
                theme: tableTheme(Brightness.dark),
                home: TableScreen(controller: fixture.controller),
              ),
            ),
          );
          await tester.pumpAndSettle();
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            fixture.dispose();
          });
          final label =
              '${seats}p-${size.width.toInt()}x${size.height.toInt()}-$sources${_normalLife ? '-normal' : ''}';
          await capture(tester, 'renderer-$label');
          for (final player in fixture.controller.session.players) {
            final surface = find.byKey(ValueKey('${player.id}-life-surface'));
            final surfaceBox = tester.renderObject<RenderBox>(surface);
            final ledger = find.byKey(
              ValueKey('${player.id}-commander-ledger'),
            );
            final number = find.byKey(ValueKey('${player.id}-life-number'));
            final tools = find.byKey(ValueKey('${player.id}-life-tools'));
            expect(
              find.descendant(of: surface, matching: ledger),
              findsOneWidget,
            );
            expect(find.descendant(of: tools, matching: ledger), findsNothing);
            final gridRect = painted(tester, ledger, ancestor: surfaceBox);
            final numberRect = painted(tester, number, ancestor: surfaceBox);
            final nameRect = painted(
              tester,
              find.descendant(
                of: surface,
                matching: find.text(
                  fixture.controller.profile(player.seatId).name,
                ),
              ),
              ancestor: surfaceBox,
            );
            expect(gridRect.center.dx, closeTo(surfaceBox.size.width / 2, .01));
            // Every owner retains a visible position, even before configuration.
            for (final source
                in fixture.controller.session.commanderTrackingSources) {
              final cell = find.byKey(
                ValueKey('${player.id}-ledger-source-${source.id}'),
              );
              expect(
                find.descendant(of: ledger, matching: cell),
                findsOneWidget,
              );
              final cellRect = painted(tester, cell, ancestor: surfaceBox);
              expect(cellRect.left, greaterThanOrEqualTo(gridRect.left));
              expect(cellRect.right, lessThanOrEqualTo(gridRect.right + .01));
              expect(cellRect.bottom, lessThanOrEqualTo(gridRect.bottom + .01));
            }
            expect(numberRect.center.dx, closeTo(gridRect.center.dx, .01));
            expect(numberRect.bottom, lessThanOrEqualTo(gridRect.top));
            expect(numberRect.bottom, lessThanOrEqualTo(nameRect.top + .01));
            expect(nameRect.bottom, lessThanOrEqualTo(gridRect.top + .01));
            expect(gridRect.bottom, lessThan(surfaceBox.size.height));
            expect(gridRect.height, 44);
            expect(surfaceBox.size.height, greaterThanOrEqualTo(140));
            expect(
              numberRect.height,
              greaterThanOrEqualTo(
                player.life == 40 ? 40 : (_captureDirectory == null ? 11 : 16),
              ),
            );
            expect(ledger.hitTestable(), findsOneWidget);
            if (player.id == fixture.controller.session.players.last.id) {
              await capture(
                tester,
                'renderer-$label-chip',
                region: painted(tester, surface),
              );
            }
            // Both sides and the center of the distinct commander target must
            // consume the gesture instead of letting it reach either life half.
            for (final x in [.02, .5, .98]) {
              final before = fixture.controller.session.toJson();
              final box = tester.renderObject<RenderBox>(ledger);
              await tester.tapAt(
                box.localToGlobal(Offset(box.size.width * x, 22)),
              );
              await tester.pumpAndSettle();
              expect(find.byTooltip('Close workspace'), findsOneWidget);
              expect(fixture.controller.session.toJson(), before);
              if (x == .5 && player.id == fixture.playerId && populated) {
                await capture(tester, 'renderer-$label-source-grid');
              }
              await tester.tapAt(const Offset(2, 30));
              await tester.pumpAndSettle();
              expect(find.byTooltip('Close workspace'), findsNothing);
              expect(fixture.controller.session.toJson(), before);
            }
            // The padding immediately beside and below the grid remains life.
            var expected = player.life;
            for (final point in [
              Offset(gridRect.left - 2, gridRect.center.dy),
              Offset(gridRect.right + 2, gridRect.center.dy),
              Offset(surfaceBox.size.width / 2 - 1, surfaceBox.size.height - 1),
              Offset(surfaceBox.size.width / 2 + 1, surfaceBox.size.height - 1),
            ]) {
              expected += point.dx < surfaceBox.size.width / 2 ? -1 : 1;
              await tester.tapAt(surfaceBox.localToGlobal(point));
              await tester.pumpAndSettle();
              expect(fixture.controller.player(player.id).life, expected);
              expect(find.byTooltip('Close workspace'), findsNothing);
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
