import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An outlined die, not an input control. Callers provide the quantity/result
/// context so a rolled value cannot be mistaken for a selected dice count.
class DieOutline extends StatelessWidget {
  const DieOutline({
    super.key,
    required this.sides,
    required this.value,
    this.selected = false,
    this.showDenomination = true,
    this.semanticsLabel,
    this.size = 76,
  }) : assert(
         sides == 4 ||
             sides == 6 ||
             sides == 8 ||
             sides == 10 ||
             sides == 12 ||
             sides == 20,
       ),
       assert(size > 0);

  final int sides, value;
  final bool selected;

  /// Grouped results can omit the repeated visible D-label without changing semantics.
  final bool showDenomination;
  final String? semanticsLabel;

  /// Width of the die and height of its square silhouette, excluding D-label.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: semanticsLabel ?? 'D$sides, $value',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: DieOutlinePainter(
                  sides: sides,
                  outline: selected ? scheme.primary : scheme.onSurfaceVariant,
                  surface: scheme.surface,
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      size * .22,
                      size * .24,
                      size * .22,
                      size * .17,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$value',
                        key: const ValueKey('die-value'),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: size * .32,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showDenomination) ...[
              const SizedBox(height: 4),
              Text(
                'D$sides',
                key: const ValueKey('die-denomination'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vector geometry follows the familiar triangle, cube, crystal, diamond,
/// many-sided and faceted-hexagon silhouettes. Facets stay outside the number.
class DieOutlinePainter extends CustomPainter {
  const DieOutlinePainter({
    required this.sides,
    required this.outline,
    required this.surface,
  });
  final int sides;
  final Color outline, surface;

  List<Offset> get _vertices => switch (sides) {
    4 => const [Offset(.5, .06), Offset(.94, .90), Offset(.06, .90)],
    6 => const [
      Offset(.14, .14),
      Offset(.86, .14),
      Offset(.86, .86),
      Offset(.14, .86),
    ],
    8 => const [
      Offset(.5, .04),
      Offset(.94, .5),
      Offset(.5, .96),
      Offset(.06, .5),
    ],
    10 => const [
      Offset(.5, .04),
      Offset(.94, .43),
      Offset(.88, .72),
      Offset(.5, .96),
      Offset(.12, .72),
      Offset(.06, .43),
    ],
    12 => List.generate(12, (i) {
      final angle = -math.pi / 2 + i * math.pi / 6;
      return Offset(.5 + .45 * math.cos(angle), .5 + .45 * math.sin(angle));
    }),
    _ => const [
      Offset(.5, .04),
      Offset(.94, .28),
      Offset(.94, .72),
      Offset(.5, .96),
      Offset(.06, .72),
      Offset(.06, .28),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    Offset point(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    final vertices = _vertices.map(point).toList();
    final path = Path()..addPolygon(vertices, true);
    // A neutral surface makes the number's contrast independent of surrounding
    // card accents; only the thin outline receives the selected accent.
    canvas.drawPath(path, Paint()..color = surface);
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final facet = Paint()
      ..color = Color.alphaBlend(outline.withValues(alpha: .48), surface)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(point(Offset(x1, y1)), point(Offset(x2, y2)), facet);
    switch (sides) {
      case 4:
        line(.5, .06, .5, .22);
        line(.06, .90, .23, .79);
        line(.94, .90, .77, .79);
      case 6:
        line(.14, .14, .24, .24);
        line(.86, .14, .76, .24);
        line(.86, .86, .76, .76);
        line(.14, .86, .24, .76);
      case 8:
        line(.5, .04, .5, .21);
        line(.94, .5, .80, .5);
        line(.5, .96, .5, .80);
        line(.06, .5, .20, .5);
      case 10:
        line(.5, .04, .5, .21);
        line(.06, .43, .19, .48);
        line(.94, .43, .81, .48);
        line(.12, .72, .28, .79);
        line(.88, .72, .72, .79);
      case 12:
        for (var i = 0; i < 12; i += 2) {
          final start = _vertices[i];
          final end = Offset(
            .5 + (start.dx - .5) * .77,
            .5 + (start.dy - .5) * .77,
          );
          canvas.drawLine(point(start), point(end), facet);
        }
      case 20:
        line(.06, .28, .5, .19);
        line(.5, .19, .94, .28);
        line(.06, .28, .18, .72);
        line(.94, .28, .82, .72);
        line(.06, .72, .5, .83);
        line(.5, .83, .94, .72);
        line(.5, .83, .5, .96);
    }
  }

  @override
  bool shouldRepaint(DieOutlinePainter oldDelegate) =>
      sides != oldDelegate.sides ||
      outline != oldDelegate.outline ||
      surface != oldDelegate.surface;
}
