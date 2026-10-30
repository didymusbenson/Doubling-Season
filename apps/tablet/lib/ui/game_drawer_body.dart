import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Supplies the current navigation controls to the page's measured layout.
/// Keeping this above the content avoids duplicating page/navigation state.
class GameDrawerHeaderScope extends InheritedWidget {
  const GameDrawerHeaderScope({
    super.key,
    required this.header,
    required super.child,
  });

  final Widget header;

  static GameDrawerHeaderScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameDrawerHeaderScope>();

  @override
  bool updateShouldNotify(GameDrawerHeaderScope oldWidget) =>
      header != oldWidget.header;
}

/// A short page shrink-wraps header and body into one centered group. A long
/// page uses the finite available height: its header stays fixed and only the
/// Flexible body scrolls. Both modes are resolved in the same layout pass.
class GameDrawerLayout extends StatelessWidget {
  const GameDrawerLayout({
    super.key,
    required this.body,
    this.contentWidth = 384,
  });

  final Widget body;
  final double contentWidth;

  @override
  Widget build(BuildContext context) {
    final header = GameDrawerHeaderScope.of(context)?.header;
    if (header == null) return body;
    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        identifier: 'game-drawer-page-viewport',
        container: true,
        explicitChildNodes: true,
        child: Align(
          alignment: Alignment.center,
          child: Semantics(
            identifier: 'game-drawer-attached-group',
            container: true,
            explicitChildNodes: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: math.min(
                        contentWidth,
                        math.max(0.0, constraints.maxWidth - 64),
                      ),
                      child: header,
                    ),
                  ),
                ),
                Flexible(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Natural-size game content inside the moving drawer walls. The 32px side
/// gutters clear both the 30px wall cutout and the overhanging Menu handle,
/// including when a long page scrolls past the middle of the table.
class GameDrawerBody extends StatelessWidget {
  const GameDrawerBody({
    super.key,
    required this.child,
    this.centered = false,
    this.scrollKey,
    this.wideMaxContentWidth,
  });

  final Widget child;
  final bool centered;
  final Key? scrollKey;
  final double? wideMaxContentWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final attached = GameDrawerHeaderScope.of(context) != null;
      final availableWidth = math.max(0.0, constraints.maxWidth - 64);
      final contentWidth =
          wideMaxContentWidth != null &&
              constraints.maxWidth >= 650 &&
              constraints.maxHeight <= 500
          ? wideMaxContentWidth!
          : 384.0;
      final content = Align(
        alignment: attached || !centered
            ? Alignment.topCenter
            : Alignment.center,
        child: SizedBox(
          width: math.min(contentWidth, availableWidth),
          child: Semantics(
            identifier: 'game-drawer-body-content',
            container: true,
            explicitChildNodes: true,
            child: child,
          ),
        ),
      );
      final scroll = Semantics(
        identifier: 'game-drawer-body-viewport',
        container: true,
        explicitChildNodes: true,
        child: SingleChildScrollView(
          key: scrollKey,
          padding: EdgeInsets.fromLTRB(32, attached ? 8 : 16, 32, 16),
          child: attached
              ? content
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0.0, constraints.maxHeight - 32),
                  ),
                  child: content,
                ),
        ),
      );
      return attached
          ? GameDrawerLayout(body: scroll, contentWidth: contentWidth)
          : scroll;
    },
  );
}
