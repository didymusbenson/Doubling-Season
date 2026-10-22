import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/ui/artwork_selection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> quadrants(int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final colors = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          (i % 2) * width / 2,
          (i ~/ 2) * height / 2,
          width / 2,
          height / 2,
        ),
        Paint()..color = colors[i],
      );
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  for (final turns in [1, 2, 3]) {
    test(
      'crop export rotates $turns quarter turns with correct pixels and 4:3 bounds',
      () async {
        final image = await quadrants(turns.isOdd ? 6 : 8, turns.isOdd ? 8 : 6);
        // Deliberately dispose the caller's image before the async export finishes.
        final pending = encodeTabletArtworkCrop(
          image,
          const Rect.fromLTWH(0, 0, 8, 6),
          quarterTurns: turns,
        );
        image.dispose();
        final encoded = await pending;
        final codec = await ui.instantiateImageCodec(encoded);
        final result = (await codec.getNextFrame()).image;
        codec.dispose();
        try {
          expect(result.width, 768);
          expect(result.height, 576);
          final bytes = (await result.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          Color at(int x, int y) {
            final offset = (y * result.width + x) * 4;
            return Color.fromARGB(
              bytes.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          }

          final expected = switch (turns) {
            1 => [Colors.blue, Colors.red, Colors.yellow, Colors.green],
            2 => [Colors.yellow, Colors.blue, Colors.green, Colors.red],
            _ => [Colors.green, Colors.yellow, Colors.red, Colors.blue],
          };
          expect(
            [
              at(192, 144),
              at(576, 144),
              at(192, 432),
              at(576, 432),
            ].map((color) => color.toARGB32()),
            expected.map((color) => color.toARGB32()),
          );
        } finally {
          result.dispose();
        }
      },
    );
  }
}
