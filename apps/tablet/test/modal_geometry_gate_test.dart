import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_modal_frame.dart';
import 'package:tripling_table/ui/table_theme.dart';
import 'package:tripling_table/ui/workspace/player_keyboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const captureKey = ValueKey('geometry-gate-capture');
  final captureDirectory = Platform.environment['TABLET_CAPTURE_DIR'];
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      for (final font in {
        'sans-serif': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(
          '$root/bin/cache/artifacts/material_fonts/${font.value}',
        );
        if (await file.exists()) {
          await (FontLoader(
            font.key,
          )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
      }
    }
    await (FontLoader(
      'Mana',
    )..addFont(rootBundle.load('assets/fonts/mana.ttf'))).load();
    if (captureDirectory != null) {
      await Directory(captureDirectory).create(recursive: true);
    }
  });
  for (final viewport in [
    const Size(1133, 744),
    const Size(744, 1133),
    const Size(1024, 600),
    const Size(600, 1024),
    const Size(844, 480),
    const Size(844, 390),
  ]) {
    for (var turns = 0; turns < 4; turns++) {
      testWidgets('populated keyboard shell $viewport rotation $turns', (
        tester,
      ) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = TextEditingController(text: 'Scute Swarm artwork');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              theme: tableTheme(Brightness.dark),
              home: Scaffold(
                body: TableModalFrame(
                  quarterTurns: turns,
                  child: PlayerKeyboardHost(
                    onClose: () {},
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Player • Artwork',
                                  style: TextStyle(fontSize: 22),
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
                                tooltip: 'Close',
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              const Text(
                                'Choose artwork',
                                style: TextStyle(fontSize: 20),
                              ),
                              const SizedBox(height: 12),
                              PlayerField(
                                controller: controller,
                                label: 'Artwork image URL',
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'This link is not an image. Choose a direct image URL; previous artwork is unchanged.',
                                style: TextStyle(color: Color(0xffffb4ab)),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () {},
                                child: const Text('Preview image'),
                              ),
                              const SizedBox(height: 16),
                              const SizedBox(
                                height: 80,
                                child: ColoredBox(color: Color(0xff497b60)),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () {},
                                child: const Text('Use this artwork'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final surface = find.byKey(const ValueKey('table-modal-surface'));
        final localViewport = turns.isOdd
            ? Size(viewport.height, viewport.width)
            : viewport;
        expect(
          tester.getSize(surface),
          Size(
            math.min(720, localViewport.width - 32),
            math.min(640, localViewport.height - 32),
          ),
        );
        final surfaceBox = tester.renderObject<RenderBox>(surface);
        final globalBounds = MatrixUtils.transformRect(
          surfaceBox.getTransformTo(null),
          Offset.zero & surfaceBox.size,
        );
        expect(globalBounds.left, greaterThanOrEqualTo(16 - .01));
        expect(globalBounds.top, greaterThanOrEqualTo(16 - .01));
        expect(
          globalBounds.right,
          lessThanOrEqualTo(viewport.width - 16 + .01),
        );
        expect(
          globalBounds.bottom,
          lessThanOrEqualTo(viewport.height - 16 + .01),
        );
        expect(globalBounds.center.dx, closeTo(viewport.width / 2, .01));
        expect(globalBounds.center.dy, closeTo(viewport.height / 2, .01));
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(find.text('Done'), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final element in find.byType(FilledButton).evaluate()) {
          final box = element.renderObject as RenderBox;
          if (box.hasSize) {
            expect(box.size.width, greaterThanOrEqualTo(44));
            expect(box.size.height, greaterThanOrEqualTo(44));
          }
        }
        if (captureDirectory != null) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(captureKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$captureDirectory/gate-${viewport.width.toInt()}x${viewport.height.toInt()}-r$turns.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        final before = controller.text;
        await tester.tap(find.text('q').last);
        await tester.pump();
        expect(controller.text.length, before.length + 1);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        final apply = find.text('Use this artwork');
        for (
          var attempt = 0;
          attempt < 8 && apply.evaluate().isEmpty;
          attempt++
        ) {
          final movement = switch (turns) {
            1 => const Offset(180, 0),
            2 => const Offset(0, 180),
            3 => const Offset(-180, 0),
            _ => const Offset(0, -180),
          };
          await tester.drag(find.byType(ListView), movement);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(apply);
        await tester.pumpAndSettle();
        await tester.tap(apply);
        expect(controller.text.length, before.length + 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
