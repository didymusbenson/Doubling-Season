import 'package:flutter/widgets.dart';

/// Presentation is local to the space a seat actually receives, never its
/// player count. Keep this threshold in one place for hands-on tablet tuning.
abstract final class SeatLayoutPolicy {
  static const minimumSplitWidth = 520.0;

  static bool useLocalViews({
    required double width,
    TextScaler textScaler = TextScaler.noScaling,
  }) => width < minimumSplitWidth * (textScaler.scale(14) / 14).clamp(1.0, 1.4);
}
