import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/biohazard_icon.dart';

void main() {
  for (final (size, tint) in [
    (16, const Color(0xffcdf4da)),
    (18, const Color(0xff283c30)),
  ]) {
    testWidgets('paints a hollow monochrome biohazard at ${size}px', (
      tester,
    ) async {
      const boundaryKey = ValueKey('biohazard-pixels');
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: IconTheme(
              data: IconThemeData(size: size.toDouble(), color: tint),
              child: const BiohazardIcon(),
            ),
          ),
        ),
      );
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(
        tester.getSize(find.byKey(boundaryKey)),
        Size.square(size.toDouble()),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final pixels = (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final out = Platform.environment['TABLET_CAPTURE_DIR'];
          if (out != null) {
            await Directory(out).create(recursive: true);
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '$out/biohazard-$size.png',
            ).writeAsBytes(png.buffer.asUint8List());
          }
          return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        } finally {
          image.dispose();
        }
      }))!;
      int offset(int x, int y) => (y * size + x) * 4;
      int alpha(int x, int y) => pixels.getUint8(offset(x, y) + 3);
      expect(alpha(size ~/ 2, size ~/ 2), lessThan(32));
      expect(alpha(0, 0), 0);
      var solidPixels = 0;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (alpha(x, y) != 255) continue;
          final index = offset(x, y);
          expect(pixels.getUint8(index), (tint.r * 255).round());
          expect(pixels.getUint8(index + 1), (tint.g * 255).round());
          expect(pixels.getUint8(index + 2), (tint.b * 255).round());
          solidPixels++;
        }
      }
      expect(solidPixels, greaterThan(size));
    });
  }
}
