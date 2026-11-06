import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A seat-facing speed dial. The transparent popup route consumes outside taps
/// without turning this two-action menu into another workspace dialog.
class PlayerToolsFab extends StatefulWidget {
  const PlayerToolsFab({
    super.key,
    required this.playerId,
    required this.playerName,
    required this.quarterTurns,
    required this.interactionEpoch,
    required this.onUtilities,
    required this.onCustomize,
  });

  final String playerId, playerName;
  final int quarterTurns, interactionEpoch;
  final VoidCallback onUtilities, onCustomize;

  @override
  State<PlayerToolsFab> createState() => _PlayerToolsFabState();
}

class _PlayerToolsFabState extends State<PlayerToolsFab>
    with WidgetsBindingObserver {
  final _anchorKey = GlobalKey();
  _PlayerToolsRoute? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _dismiss() {
    final route = _route;
    _route = null;
    if (route == null) return;
    // A responsive transition can unmount the lane during the build phase.
    void remove() {
      if (route.isActive) route.navigator?.removeRoute(route);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => remove());
    } else {
      remove();
    }
  }

  @override
  void didChangeMetrics() => _dismiss();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _dismiss();
  }

  @override
  void didUpdateWidget(covariant PlayerToolsFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quarterTurns != widget.quarterTurns ||
        oldWidget.interactionEpoch != widget.interactionEpoch ||
        oldWidget.playerId != widget.playerId) {
      _dismiss();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismiss();
    super.dispose();
  }

  Future<void> _open() async {
    if (_route != null) return;
    final anchor = _anchorKey.currentContext!.findRenderObject()! as RenderBox;
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchorBounds = Rect.fromPoints(
      anchor.localToGlobal(Offset.zero, ancestor: overlay),
      anchor.localToGlobal(
        anchor.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
    final route = _PlayerToolsRoute(
      anchor: anchorBounds,
      quarterTurns: widget.quarterTurns,
      playerName: widget.playerName,
      playerId: widget.playerId,
    );
    _route = route;
    final selected = await navigator.push<_PlayerTool>(route);
    if (!mounted || _route != route) return;
    _route = null;
    switch (selected) {
      case _PlayerTool.utilities:
        widget.onUtilities();
      case _PlayerTool.customize:
        widget.onCustomize();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => FloatingActionButton.small(
    key: _anchorKey,
    heroTag: '${widget.playerId}-utility-tools',
    tooltip: '${widget.playerName}, utilities and customization',
    onPressed: _open,
    child: const Icon(Icons.tune),
  );
}

enum _PlayerTool { utilities, customize }

class _PlayerToolsRoute extends PopupRoute<_PlayerTool> {
  _PlayerToolsRoute({
    required this.anchor,
    required this.quarterTurns,
    required this.playerName,
    required this.playerId,
  });

  final Rect anchor;
  final int quarterTurns;
  final String playerName, playerId;

  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => null;
  @override
  String get barrierLabel => 'Close $playerName tools menu';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 140);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 100);

  Rect _localRect(Rect rect, Size size) {
    Offset local(Offset point) => switch (quarterTurns % 4) {
      1 => Offset(point.dy, size.width - point.dx),
      2 => Offset(size.width - point.dx, size.height - point.dy),
      3 => Offset(size.height - point.dy, point.dx),
      _ => point,
    };
    return Rect.fromPoints(local(rect.topLeft), local(rect.bottomRight));
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return LayoutBuilder(
      builder: (context, screen) {
        final bounds = _localRect(anchor, screen.biggest);
        final padding = MediaQuery.paddingOf(context);
        final safe = _localRect(
          Rect.fromLTRB(
            padding.left,
            padding.top,
            screen.maxWidth - padding.right,
            screen.maxHeight - padding.bottom,
          ),
          screen.biggest,
        );
        return RotatedBox(
          quarterTurns: quarterTurns,
          child: LayoutBuilder(
            builder: (context, local) {
              final width = math.min(272.0, math.max(48.0, safe.width - 24));
              final left = (bounds.right - width).clamp(
                safe.left + 12,
                safe.right - width - 12,
              );
              // Action labels can wrap at large text sizes; measure the whole menu
              // in a bounded popup instead of guessing fixed row heights.
              final above =
                  bounds.top - safe.top >= safe.bottom - bounds.bottom;
              final available = above
                  ? bounds.top - safe.top - 20
                  : safe.bottom - bounds.bottom - 20;
              final colors = Theme.of(context).colorScheme;
              Widget action(
                _PlayerTool value,
                IconData icon,
                String label,
              ) => Semantics(
                button: true,
                child: Material(
                  key: ValueKey(
                    '$playerId-${value == _PlayerTool.utilities ? 'manage-utilities' : 'player-details'}',
                  ),
                  color: colors.secondaryContainer,
                  elevation: 5,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => navigator!.pop(value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: colors.onSecondaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: colors.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              return Stack(
                children: [
                  Positioned(
                    left: left,
                    width: width,
                    bottom: above ? local.maxHeight - bounds.top + 8 : null,
                    top: above ? null : bounds.bottom + 8,
                    child: FadeTransition(
                      opacity: animation,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.max(48, available),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              action(
                                _PlayerTool.utilities,
                                Icons.widgets_outlined,
                                'Utilities',
                              ),
                              const SizedBox(height: 10),
                              action(
                                _PlayerTool.customize,
                                Icons.person_outline,
                                'Player customization',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: bounds,
                    child: FloatingActionButton.small(
                      key: ValueKey('$playerId-close-tools-menu'),
                      heroTag: null,
                      tooltip: 'Close $playerName tools menu',
                      onPressed: () => navigator!.pop(),
                      child: const Icon(Icons.close),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
