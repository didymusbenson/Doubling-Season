import 'package:flutter/material.dart';

/// A literal three-point crown, independent of platform emoji/font fallback.
class MonarchCrown extends StatelessWidget {
  const MonarchCrown({super.key, this.size = 18, this.worn = false});

  final double size;
  final bool worn;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: worn
          ? const _WornCrownPainter()
          : _CrownPainter(IconTheme.of(context).color ?? Colors.white),
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

/// A warm gold silhouette and dark edge keep the worn crown legible on both
/// player colors and artwork. This remains vector art at every fitted size.
class _WornCrownPainter extends CustomPainter {
  const _WornCrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final crown = Path()
      ..moveTo(3, 7)
      ..lineTo(8, 11)
      ..lineTo(12, 4)
      ..lineTo(16, 11)
      ..lineTo(21, 7)
      ..lineTo(18.5, 19)
      ..quadraticBezierTo(12, 21, 5.5, 19)
      ..close();
    canvas.drawShadow(crown, const Color(0xFF000000), 2.5, false);
    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1A8), Color(0xFFFFCC52), Color(0xFFCF8B21)],
        ).createShader(const Rect.fromLTWH(3, 4, 18, 17)),
    );
    canvas.drawPath(
      crown,
      Paint()
        ..color = const Color(0xFF5A350B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(6, 16)
        ..quadraticBezierTo(12, 18, 18, 16),
      Paint()
        ..color = const Color(0xFFFFF4BF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WornCrownPainter oldDelegate) => false;
}
