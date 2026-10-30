import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Natural-size game content inside the moving drawer walls. The 32px side
/// gutters clear both the 30px wall cutout and the overhanging Menu handle,
/// including when a long page scrolls past the middle of the table.
class GameDrawerBody extends StatelessWidget {
  const GameDrawerBody({
    super.key,
    required this.child,
    this.centered = false,
    this.scrollKey,
  });

  final Widget child;
  final bool centered;
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final availableWidth = math.max(0.0, constraints.maxWidth - 64);
      return Semantics(
        identifier: 'game-drawer-body-viewport',
        container: true,
        explicitChildNodes: true,
        child: SingleChildScrollView(
          key: scrollKey,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0.0, constraints.maxHeight - 32),
            ),
            child: Align(
              alignment: centered ? Alignment.center : Alignment.topCenter,
              child: SizedBox(
                width: math.min(384.0, availableWidth),
                child: Semantics(
                  identifier: 'game-drawer-body-content',
                  container: true,
                  explicitChildNodes: true,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
