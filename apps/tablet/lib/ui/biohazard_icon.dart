import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A monochrome biohazard mark. Parent counter controls provide the accessible
/// labels and values; the mark is decorative and cannot fall back to emoji.
class BiohazardIcon extends StatelessWidget {
  const BiohazardIcon({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final color = (theme.color ?? Theme.of(context).colorScheme.onSurface)
        .withValues(alpha: (theme.color?.a ?? 1) * (theme.opacity ?? 1));
    return CustomPaint(
      size: Size.square(size ?? theme.size ?? 24),
      painter: _BiohazardPainter(color),
    );
  }
}

class _BiohazardPainter extends CustomPainter {
  const _BiohazardPainter(this.color);

  final Color color;

  // The mark is a ring and three open crescents, with a clear center.
  // Normalize to a 24-point canvas so it stays legible at tiny board sizes.
  static final Path _crescent = Path()
    ..moveTo(-3.1, -11.15)
    ..cubicTo(-8.3, -7.7, -5.3, -1.7, -0.9, -1.2)
    ..quadraticBezierTo(0, -1.05, .9, -1.2)
    ..cubicTo(5.3, -1.7, 8.3, -7.7, 3.1, -11.15)
    ..cubicTo(6.1, -6.8, 3.25, -4.25, 0, -4.25)
    ..cubicTo(-3.25, -4.25, -6.1, -6.8, -3.1, -11.15)
    ..close();
  static final Path _shape = _makeShape();

  static Path _makeShape() {
    var glyph = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 5.55)),
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 4.15)),
    );
    for (var i = 0; i < 3; i++) {
      glyph = Path.combine(
        PathOperation.union,
        glyph,
        _crescent.transform(Matrix4.rotationZ(2 * math.pi * i / 3).storage),
      );
    }
    return Path.combine(
      PathOperation.difference,
      glyph,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 1.85)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 24);
    canvas.drawPath(_shape, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BiohazardPainter oldDelegate) =>
      oldDelegate.color != color;
}
