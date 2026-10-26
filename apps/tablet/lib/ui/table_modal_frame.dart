import 'package:flutter/material.dart';

/// The common app-owned dialog surface. Dimensions are viewport-relative in
/// physical orientation; content constraints rotate with the initiating seat.
/// Standalone board keyboards and native platform pickers are not this surface.
class TableModalFrame extends StatelessWidget {
  const TableModalFrame({
    super.key,
    required this.child,
    this.quarterTurns = 0,
    this.surfaceKey,
  });

  final Widget child;
  final int quarterTurns;
  final Key? surfaceKey;

  static Size localSize(Size viewport, int quarterTurns) => quarterTurns.isOdd
      ? Size(viewport.height * .75, viewport.width * .75)
      : Size(viewport.width * .75, viewport.height * .75);

  @override
  Widget build(BuildContext context) {
    final size = localSize(MediaQuery.sizeOf(context), quarterTurns);
    return Center(
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: SizedBox(
          key: surfaceKey ?? const ValueKey('table-modal-surface'),
          width: size.width,
          height: size.height,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 24,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(22),
            child: child,
          ),
        ),
      ),
    );
  }
}
