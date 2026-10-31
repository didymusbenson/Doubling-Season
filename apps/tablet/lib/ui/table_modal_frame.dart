import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'player_input_mode.dart';

/// A bounded app-owned dialog, sized in the initiating seat's coordinates.
/// Short forms can supply their content height; long forms retain a scrollable
/// viewport without expanding to a fixed fraction of the whole table.
class TableModalFrame extends StatelessWidget {
  const TableModalFrame({
    super.key,
    required this.child,
    this.quarterTurns = 0,
    this.surfaceKey,
    this.preferredWidth = 720,
    this.preferredHeight = 640,
  });

  final Widget child;
  final int quarterTurns;
  final Key? surfaceKey;
  final double preferredWidth;
  final double preferredHeight;

  static Size localSize(Size viewport, int quarterTurns) {
    final local = quarterTurns.isOdd
        ? Size(viewport.height, viewport.width)
        : viewport;
    return Size(
      math.max(0.0, math.min(720.0, local.width - 32)),
      math.max(0.0, math.min(640.0, local.height - 32)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = usesNativePlayerInput(context)
        ? media.viewInsets.bottom
        : 0.0;
    final available = Size(
      media.size.width - media.padding.horizontal,
      media.size.height - media.padding.vertical - keyboardInset,
    );
    final bounds = localSize(available, quarterTurns);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Center(
          child: RotatedBox(
            quarterTurns: quarterTurns,
            child: SizedBox(
              key: surfaceKey ?? const ValueKey('table-modal-surface'),
              width: math.min(preferredWidth, bounds.width),
              height: math.min(preferredHeight, bounds.height),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 24,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(22),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
