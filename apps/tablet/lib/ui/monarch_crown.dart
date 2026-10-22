import 'package:flutter/material.dart';

/// A literal three-point crown, independent of platform emoji/font fallback.
class MonarchCrown extends StatelessWidget {
  const MonarchCrown({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 18,
    child: CustomPaint(
      painter: _CrownPainter(IconTheme.of(context).color ?? Colors.white),
    ),
  );
}

class _CrownPainter extends CustomPainter {
  final Color color;
  const _CrownPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 20, size.height / 20);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.7;
    final crown = Path()
      ..moveTo(2, 5)
      ..lineTo(6, 9)
      ..lineTo(10, 2)
      ..lineTo(14, 9)
      ..lineTo(18, 5)
      ..lineTo(15.5, 15)
      ..lineTo(4.5, 15)
      ..close();
    canvas.drawPath(crown, paint);
    canvas.drawLine(const Offset(5, 18), const Offset(15, 18), paint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) =>
      oldDelegate.color != color;
}
