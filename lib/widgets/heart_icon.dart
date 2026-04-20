import 'package:flutter/material.dart';
import '../models/heart_style.dart';

/// Renders a heart badge in the shape of `Icons.favorite`, tinted by the
/// supplied [HeartStyle]. Solid styles use a flat color; gradient styles use
/// a diagonal `ShaderMask`.
class HeartIcon extends StatelessWidget {
  final HeartStyle style;
  final double size;

  const HeartIcon({
    super.key,
    required this.style,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    if (style.type == HeartStyleType.solid) {
      return Icon(
        Icons.favorite,
        color: style.colors[0],
        size: size,
      );
    }

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.colors,
        ).createShader(bounds);
      },
      child: Icon(
        Icons.favorite,
        size: size,
        color: Colors.white,
      ),
    );
  }
}
