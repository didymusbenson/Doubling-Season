import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/table_artwork.dart';

// Opaque landscape illustration: red / green / blue bands centered on a
// 12 x 12 white square in a 120 x 60 image. Solid sample points avoid goldens.
const _art =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHgAAAA8CAIAAAAiz+n/AAAAtklEQVR4nO3QsQ3DMBAEQfbftFWBAGeEbodgvn9zfudc+XeqF8O1vaDXw7W9oNfDtb2g18O1vaDXw7W9oNfDtb2g18O1vaDXw7W9oNfDtb2g18O1vaDXw7W9oNfDtb2g3y/844EGDRo0aNCgQYMGDRo0aNCgQX8FeiRc2wt6PVzbC3o9XNsLej1c2wt6PVzbC3o9XNsLej1c2wt6PVzbC3o9XNsLej1c2wt6PVzbC3o9XNt7K/wAqAAkdOspDCkAAAAASUVORK5CYII=';
const _capture = ValueKey('artwork-surface-paint');

void main() {
  final captureDirectory = Platform.environment['TABLE_ART_FIT_CAPTURES'];

  for (final (name, bounds, markerRadius) in [
    ('narrow-tall', const Size(80, 160), 16),
    ('ordinary-landscape', const Size(240, 100), 12),
  ]) {
    testWidgets('artwork fills $name without stretching', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: _capture,
                child: ColoredBox(
                  color: Colors.black,
                  child: TableArtworkSurface(
                    url: _art,
                    shadeArtwork: false,
                    child: SizedBox.fromSize(size: bounds),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final imageFinder = find.byType(Image);
      final image = tester.widget<Image>(imageFinder);
      await tester.runAsync(
        () => precacheImage(image.image, tester.element(imageFinder)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_capture),
      );
      final pending = boundary.toImage(pixelRatio: 1);
      final bytes = (await tester.runAsync(() async {
        final rendered = await pending;
        try {
          if (captureDirectory != null) {
            await Directory(captureDirectory).create(recursive: true);
            final png = (await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '$captureDirectory/$name.png',
            ).writeAsBytes(png.buffer.asUint8List());
          }
          return (await rendered.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
        } finally {
          rendered.dispose();
        }
      }))!;
      int at(int x, int y) =>
          bytes.getUint32((y * bounds.width.toInt() + x) * 4);
      const green = 0x00ff00ff;
      const red = 0xff0000ff;
      const blue = 0x0000ffff;
      const white = 0xffffffff;
      final x = bounds.width ~/ 2;
      final y = bounds.height ~/ 2;

      // Neither viewport leaves background bands above or below the art.
      expect(at(x, 1), green);
      expect(at(x, bounds.height.toInt() - 2), green);
      // Tall view crops left/right bands; wide view keeps them as before.
      expect(at(1, y), name == 'narrow-tall' ? green : red);
      expect(
        at(bounds.width.toInt() - 2, y),
        name == 'narrow-tall' ? green : blue,
      );
      // Square marker remains square after zoom, not a stretched rectangle.
      expect(at(x + markerRadius - 2, y), white);
      expect(at(x, y + markerRadius - 2), white);
      expect(at(x + markerRadius + 2, y), green);
      expect(at(x, y + markerRadius + 2), green);
    });
  }
}
