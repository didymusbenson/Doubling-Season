import 'dart:async';
import 'dart:math' as math;
import 'package:doubling_season/widgets/mana/mana_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../domain/table_state.dart';
import '../state/table_controller.dart';
import '../services/tablet_catalog.dart';
import '../features/board_service.dart';
import '../features/ring_service.dart';
import 'workspace/table_workspace.dart';
import 'table_artwork.dart';
import 'tablet_token_card.dart';
import 'half_stepper.dart';
import 'life_tap_feedback.dart';
import 'monarch_crown.dart';
import 'table_mana_icons.dart';
import 'ring_inline.dart';
import 'commander_ledger.dart';
import 'utility_inline_actions.dart';

/// The table is composed in seat-local coordinates, then oriented toward each
/// player. Tokens remain on the physical outer edge in the four-slot layout.
class TableScreen extends StatefulWidget {
  final TableController controller;
  const TableScreen({super.key, required this.controller});
  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen>
    with SingleTickerProviderStateMixin {
  late final TabletCatalog catalog = TabletCatalog(widget.controller);
  late final BoardService board = BoardService(widget.controller, catalog);
  bool modalOpen = false;
  int interactionEpoch = 0;
  final drawerController = GameDrawerController();
  final drawerWorkspaceKey = GlobalKey(debugLabel: 'game-drawer-shell');
  late final AnimationController drawerAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
    upperBound: 1.025,
  );
  bool drawerMounted = false;
  WorkspacePage drawerPage = WorkspacePage.tableHub;

  Future<void> _closeDrawer() async {
    await drawerController.close();
  }

  void _drawerClosed() {
    drawerAnimation
        .animateBack(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          if (mounted && drawerAnimation.isDismissed) {
            setState(() {
              drawerMounted = false;
              interactionEpoch++;
            });
          }
        });
  }

  void _openDrawer(WorkspacePage page) {
    if (drawerMounted) {
      if (drawerAnimation.status == AnimationStatus.reverse) return;
      unawaited(drawerController.open(page));
      return;
    }
    setState(() {
      drawerMounted = true;
      drawerPage = page;
      interactionEpoch++;
    });
    drawerAnimation.animateTo(
      1,
      duration: const Duration(milliseconds: 320),
      curve: _DrawerSpringCurve(),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(catalog.load());
  }

  @override
  void dispose() {
    drawerAnimation.dispose();
    catalog.dispose();
    super.dispose();
  }

  void setInputLock(bool locked) {
    if (!mounted) return;
    setState(() {
      modalOpen = locked;
      interactionEpoch++;
    });
  }

  Future<void> open(
    WorkspacePage page, {
    PlayerState? player,
    String? itemId,
    int turns = 0,
  }) async {
    if (modalOpen) return;
    if (isGameDrawerPage(page)) {
      _openDrawer(page);
      return;
    }
    if (drawerMounted) return;
    setState(() {
      modalOpen = true;
      interactionEpoch++;
    });
    await showTableWorkspace(
      context,
      widget.controller,
      catalog: catalog,
      seatId: player?.id,
      quarterTurns: turns,
      initialPage: page,
      itemId: itemId,
    );
    if (mounted) {
      setState(() {
        modalOpen = false;
        interactionEpoch++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, drawerAnimation]),
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650 || constraints.maxHeight < 480) {
                if (drawerMounted) {
                  return Center(
                    child: SizedBox(
                      width: math.min(480, constraints.maxWidth),
                      child: GameDrawerWorkspace(
                        key: drawerWorkspaceKey,
                        controller: controller,
                        catalog: catalog,
                        drawerController: drawerController,
                        initialPage: drawerPage,
                        onClose: _drawerClosed,
                      ),
                    ),
                  );
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tablet_mac, size: 60),
                        const SizedBox(height: 20),
                        const Text(
                          'Give your table a little more room',
                          style: TextStyle(fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enlarge this window or rotate your tablet to see every player. Your game is saved.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => open(WorkspacePage.settings),
                          child: const Text('Settings'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final two = controller.session.players.length == 2;
              final progress = drawerAnimation.value;
              final drawerWidth = math.min(
                480.0,
                constraints.maxWidth * .4 - 12,
              );
              final gap = drawerWidth * progress;

              Widget seat(PlayerState player) {
                final turns = two
                    ? (controller.session.players.indexOf(player) == 0 ? 0 : 2)
                    : (player.slot == 1 || player.slot == 2 ? 2 : 0);
                final tokenLeft = two || player.slot == 0 || player.slot == 2;
                return _PlayerSpace(
                  key: ValueKey(player.id),
                  controller: controller,
                  board: board,
                  player: player,
                  turns: turns,
                  tokenLeft: tokenLeft,
                  centerNotch: two ? 0 : 30,
                  centerNotchAtStart: two || !tokenLeft,
                  hubInTokenLane: two,
                  interactionEpoch: interactionEpoch,
                  drawerShift: gap / 2,
                  drawerOpen: drawerMounted,
                  onCloseDrawer: _closeDrawer,
                  onInputLock: setInputLock,
                  onOpen: (page, [itemId]) =>
                      open(page, player: player, itemId: itemId, turns: turns),
                );
              }

              Widget slot(int number) {
                final players = controller.session.players.where(
                  (p) => p.slot == number,
                );
                if (players.isNotEmpty) return seat(players.first);
                return RotatedBox(
                  quarterTurns: number == 1 || number == 2 ? 2 : 0,
                  child: Transform.translate(
                    offset: Offset(
                      (number == 0 || number == 2 ? -1 : 1) * gap / 2,
                      0,
                    ),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: IgnorePointer(
                        ignoring: drawerMounted,
                        child: ExcludeSemantics(
                          excluding: drawerMounted,
                          child: Opacity(
                            key: ValueKey('empty-table-controls-$number'),
                            opacity: (1 - progress * 3).clamp(0.0, 1.0),
                            child: _EmptyControlSpace(
                              onOpen: (page) => open(
                                page,
                                turns: number == 1 || number == 2 ? 2 : 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  if (controller.error != null ||
                      controller.recoveryMessage != null)
                    Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                controller.error ?? controller.recoveryMessage!,
                                maxLines: 3,
                              ),
                            ),
                            TextButton(
                              onPressed: () => open(WorkspacePage.settings),
                              child: const Text('Details'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, table) {
                        final dividerColor = Theme.of(
                          context,
                        ).colorScheme.outline;
                        final leftWall = (table.maxWidth - gap) / 2;
                        final rightWall = (table.maxWidth + gap) / 2;
                        Widget row(int left, int right) => Row(
                          children: [
                            Expanded(child: slot(left)),
                            VerticalDivider(
                              width: 3,
                              thickness: 3,
                              color: dividerColor,
                            ),
                            Expanded(child: slot(right)),
                          ],
                        );
                        return Stack(
                          key: const ValueKey('table-surface'),
                          children: [
                            if (drawerMounted)
                              Positioned(
                                key: const ValueKey('table-drawer-layer'),
                                left: (table.maxWidth - drawerWidth) / 2,
                                top: 0,
                                bottom: 0,
                                width: drawerWidth,
                                child: ClipRect(
                                  clipper: _DrawerRevealClipper(gap),
                                  child: IgnorePointer(
                                    ignoring:
                                        drawerAnimation.status ==
                                        AnimationStatus.reverse,
                                    child: ExcludeSemantics(
                                      excluding:
                                          drawerAnimation.status !=
                                          AnimationStatus.completed,
                                      child: Semantics(
                                        identifier: 'game-drawer',
                                        container: true,
                                        explicitChildNodes: true,
                                        label: 'Game drawer',
                                        child: GameDrawerWorkspace(
                                          key: drawerWorkspaceKey,
                                          controller: controller,
                                          catalog: catalog,
                                          drawerController: drawerController,
                                          initialPage: drawerPage,
                                          onClose: _drawerClosed,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              key: const ValueKey('table-board-layer'),
                              child: ClipPath(
                                key: const ValueKey('drawer-board-mask'),
                                clipper: _DrawerBoardClipper(
                                  gap: gap,
                                  enabled: drawerMounted,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: two
                                          ? seat(controller.session.players[1])
                                          : row(1, 2),
                                    ),
                                    Divider(
                                      key: const ValueKey(
                                        'player-horizontal-divider',
                                      ),
                                      height: 3,
                                      thickness: 3,
                                      color: dividerColor,
                                    ),
                                    Expanded(
                                      child: two
                                          ? seat(controller.session.players[0])
                                          : row(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (drawerMounted)
                              Positioned.fill(
                                key: const ValueKey('table-drawer-walls'),
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _DrawerWallPainter(
                                      gap,
                                      dividerColor,
                                    ),
                                  ),
                                ),
                              ),
                            // Two-seat token lanes meet at the true center.
                            // Keep direct tools in opposite life corners there,
                            // rather than expanding the token hub obstruction.
                            Positioned(
                              key: const ValueKey('table-dice-layer'),
                              left:
                                  leftWall -
                                  (two
                                      ? (table.maxWidth * .1 + 26) *
                                                (1 - progress) +
                                            54 * progress
                                      : 54) -
                                  22,
                              top:
                                  table.maxHeight / 2 -
                                  (two ? 26 * (1 - progress) : 0) -
                                  22,
                              child: _SharedTableControl(
                                controlKey: const ValueKey('shared-dice'),
                                label: 'Roll dice',
                                enabled:
                                    drawerAnimation.status !=
                                    AnimationStatus.reverse,
                                icon: Icons.casino_outlined,
                                onTap: () => open(WorkspacePage.dice),
                              ),
                            ),
                            Positioned(
                              key: const ValueKey('table-day-night-layer'),
                              left:
                                  rightWall +
                                  (two
                                      ? (table.maxWidth * .1 + 26) *
                                                (1 - progress) +
                                            54 * progress
                                      : 54) -
                                  22,
                              top:
                                  table.maxHeight / 2 +
                                  (two ? 26 * (1 - progress) : 0) -
                                  22,
                              child: _DayNightControl(controller: controller),
                            ),
                            Positioned(
                              key: const ValueKey('table-menu-layer'),
                              // Menu rides the right wall as one whole target;
                              // the left wall keeps the matching empty cutout.
                              left: rightWall - 26,
                              top: (table.maxHeight - 52) / 2,
                              child: _GameHub(
                                key: const ValueKey('central-game-controls'),
                                controller: controller,
                                expanded: drawerMounted,
                                onPressed: () => drawerMounted
                                    ? _closeDrawer()
                                    : open(WorkspacePage.tableHub),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DrawerRevealClipper extends CustomClipper<Rect> {
  final double width;
  const _DrawerRevealClipper(this.width);
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH((size.width - width) / 2, 0, width, size.height);
  @override
  Rect getApproximateClipRect(Size size) => getClip(size);
  @override
  bool shouldReclip(_DrawerRevealClipper oldClipper) =>
      width != oldClipper.width;
}

class _DrawerWallPainter extends CustomPainter {
  final double gap;
  final Color color;
  const _DrawerWallPainter(this.gap, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final side in [-1, 1]) {
      final x = center.dx + side * gap / 2;
      final circle = Rect.fromCircle(center: Offset(x, center.dy), radius: 30);
      final wall = Path()
        ..moveTo(x, 0)
        ..lineTo(x, center.dy - 30)
        ..arcTo(circle, -math.pi / 2, side * math.pi, false)
        ..lineTo(x, size.height);
      canvas.drawPath(wall, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawerWallPainter old) =>
      gap != old.gap || color != old.color;
}

/// Fast settle with a small, bounded overshoot rather than elastic wobble.
class _DrawerSpringCurve extends Curve {
  @override
  double transformInternal(double t) {
    const overshoot = .8;
    final x = t - 1;
    return 1 + (overshoot + 1) * x * x * x + overshoot * x * x;
  }
}

/// The cutout belongs to the opposite wall, while Menu stays one whole widget.
/// In two-seat mode the center passes through a stationary token viewport: only
/// its visible clip changes; its layout, coordinates and scroll offset do not.
class _DrawerBoardClipper extends CustomClipper<Path> {
  final double gap;
  final bool enabled;
  const _DrawerBoardClipper({required this.gap, required this.enabled});
  @override
  Path getClip(Size size) {
    final board = Path()..addRect(Offset.zero & size);
    if (!enabled) return board;
    final center = size.center(Offset.zero);
    return Path.combine(
      PathOperation.difference,
      board,
      Path()
        ..addRect(Rect.fromLTWH(center.dx - gap / 2, 0, gap, size.height))
        ..addOval(
          Rect.fromCircle(center: center + Offset(gap / 2, 0), radius: 30),
        )
        ..addOval(
          Rect.fromCircle(center: center - Offset(gap / 2, 0), radius: 30),
        ),
    );
  }

  @override
  bool shouldReclip(_DrawerBoardClipper oldClipper) =>
      gap != oldClipper.gap || enabled != oldClipper.enabled;
}

class _SharedTableControl extends StatelessWidget {
  final ValueKey<String> controlKey;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool active, enabled;
  final Color? backgroundColor, foregroundColor;
  const _SharedTableControl({
    required this.controlKey,
    required this.label,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.active = true,
    this.enabled = true,
    this.backgroundColor,
    this.foregroundColor,
  });
  @override
  Widget build(BuildContext context) => Material(
    color:
        backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest,
    shape: CircleBorder(
      side: BorderSide(
        color: foregroundColor ?? Theme.of(context).colorScheme.outline,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    elevation: 3,
    child: Semantics(
      identifier: controlKey.value,
      label: label,
      button: true,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      customSemanticsActions: onLongPress == null
          ? null
          : {
              const CustomSemanticsAction(label: 'Clear Day/Night'):
                  onLongPress!,
            },
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        child: SizedBox(
          key: controlKey,
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 23,
            color: active && enabled
                ? foregroundColor
                : Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: .5),
          ),
        ),
      ),
    ),
  );
}

class _DayNightControl extends StatelessWidget {
  final TableController controller;
  const _DayNightControl({required this.controller});
  @override
  Widget build(BuildContext context) {
    final state = controller.session.dayNight;
    return _SharedTableControl(
      controlKey: const ValueKey('shared-day-night'),
      label: 'Day/Night: $state. Tap to change; hold to clear',
      icon: state == 'night'
          ? Icons.dark_mode
          : state == 'day'
          ? Icons.light_mode
          : Icons.brightness_4_outlined,
      active: state != 'neither',
      backgroundColor: switch (state) {
        'day' => const Color(0xFFFFCA62),
        'night' => const Color(0xFF344C91),
        _ => null,
      },
      foregroundColor: switch (state) {
        'day' => const Color(0xFF4A2B05),
        'night' => const Color(0xFFE0E8FF),
        _ => null,
      },
      // Resolve inside the serialized command, so rapid taps do not all
      // capture the same pre-save state. Publication remains durable.
      onTap: () => controller.commit(
        'Cycle day/night',
        mutate: (game) {
          game.dayNight = game.dayNight == 'day' ? 'night' : 'day';
        },
      ),
      onLongPress: () => controller.setDayNight('neither'),
    );
  }
}

/// A whole circular handle attached to the moving left drawer wall.
class _GameHub extends StatelessWidget {
  final TableController controller;
  final bool expanded;
  final VoidCallback onPressed;
  const _GameHub({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Material(
    shape: CircleBorder(
      side: BorderSide(
        color: Theme.of(context).colorScheme.outline,
        width: 1.5,
      ),
    ),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    elevation: 4,
    clipBehavior: Clip.antiAlias,
    child: Semantics(
      identifier: 'game-menu',
      label: 'Game controls',
      value:
          '${expanded ? 'Expanded' : 'Collapsed'}, ${controller.busy ? 'Saving game' : 'Game saved'}',
      button: true,
      expanded: expanded,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.tune),
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          minimumSize: const Size(52, 52),
          maximumSize: const Size(52, 52),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ),
  );
}

class _EmptyControlSpace extends StatelessWidget {
  final ValueChanged<WorkspacePage> onOpen;
  const _EmptyControlSpace({required this.onOpen});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.spa_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text(
              'The table',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text('Shared tools for this game'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onOpen(WorkspacePage.dice),
                  icon: const Icon(Icons.casino),
                  label: const Text('Roll dice'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onOpen(WorkspacePage.history),
                  icon: const Icon(Icons.history),
                  label: const Text('History & undo'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onOpen(WorkspacePage.reset),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset / reload'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlayerSpace extends StatefulWidget {
  final TableController controller;
  final BoardService board;
  final PlayerState player;
  final int turns, interactionEpoch;
  final bool tokenLeft;
  final double centerNotch;
  final bool centerNotchAtStart;
  final bool hubInTokenLane;
  final double drawerShift;
  final bool drawerOpen;
  final VoidCallback onCloseDrawer;
  final void Function(WorkspacePage, [String?]) onOpen;
  final ValueChanged<bool> onInputLock;
  const _PlayerSpace({
    super.key,
    required this.controller,
    required this.board,
    required this.player,
    required this.turns,
    required this.tokenLeft,
    required this.centerNotch,
    required this.centerNotchAtStart,
    required this.hubInTokenLane,
    required this.drawerShift,
    required this.drawerOpen,
    required this.onCloseDrawer,
    required this.interactionEpoch,
    required this.onOpen,
    required this.onInputLock,
  });
  @override
  State<_PlayerSpace> createState() => _PlayerSpaceState();
}

class _PlayerSpaceState extends State<_PlayerSpace>
    with WidgetsBindingObserver {
  bool compactUtilityReorder = false;
  late LifeTapFeedback lifeFeedback;

  void _listenToLife() {
    lifeFeedback = LifeTapFeedback(
      widget.controller,
      playerId: widget.player.id,
    )..addListener(_lifeChanged);
  }

  void _lifeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _listenToLife();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _PlayerSpace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.player.id != widget.player.id) {
      lifeFeedback.removeListener(_lifeChanged);
      lifeFeedback.dispose();
      _listenToLife();
    }
    if (oldWidget.interactionEpoch != widget.interactionEpoch ||
        oldWidget.player.generation != widget.player.generation) {
      compactUtilityReorder = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && compactUtilityReorder) {
      setState(() => compactUtilityReorder = false);
    }
  }

  void setUtilityReorder(bool value) {
    if (utilityScroll.hasClients) utilityScroll.jumpTo(0);
    setState(() => compactUtilityReorder = value);
  }

  String? expandedId;
  String? error;
  final tokenScroll = ScrollController(), utilityScroll = ScrollController();
  Future<void> perform(Future<dynamic> Function() action) async {
    try {
      await action();
      if (mounted && error != null) setState(() => error = null);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    lifeFeedback.removeListener(_lifeChanged);
    lifeFeedback.dispose();
    tokenScroll.dispose();
    utilityScroll.dispose();
    super.dispose();
  }

  void expand(String id) => setState(() {
    expandedId = expandedId == null ? id : null;
  });

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final profile = widget.controller.profile(p.seatId);
    final enabled = widget.board
        .effectiveSources(p.id)
        .where((s) => s.enabled && s.count > 0)
        .length;
    Widget tokenLane = Stack(
      key: ValueKey('${p.id}-token-lane'),
      children: [
        Positioned.fill(
          child: p.tokens.isEmpty
              ? _EmptyLane(
                  icon: Icons.style_outlined,
                  text: 'Your token board',
                  action: 'Add a token',
                  onTap: () => widget.onOpen(WorkspacePage.tokens),
                )
              : DragBoundary(
                  child: ReorderableListView.builder(
                    scrollController: tokenScroll,
                    padding: EdgeInsets.only(
                      top: widget.hubInTokenLane ? 30 : 0,
                      bottom: 88,
                    ),
                    buildDefaultDragHandles: false,
                    itemCount: p.tokens.length,
                    onReorder: (old, next) => perform(
                      () => widget.board.reorder(p.id, 'tokens', old, next),
                    ),
                    proxyDecorator: (child, index, animation) =>
                        Material(elevation: 5, child: child),
                    itemBuilder: (context, index) {
                      final t = p.tokens[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(t.id),
                        index: index,
                        enabled: expandedId == null,
                        child: TabletTokenCard(
                          token: t,
                          player: p,
                          board: widget.board,
                          playerName: profile.name,
                          quarterTurns: widget.turns,
                          expanded: expandedId == t.id,
                          onExpand: () => expand(t.id),
                          onOpenDetailed: (page) => widget.onOpen(page, t.id),
                          onInputLock: widget.onInputLock,
                        ),
                      );
                    },
                  ),
                ),
        ),
        Positioned(
          left: 124,
          bottom: 12,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            elevation: 3,
            shape: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 44,
              child: IconButton(
                key: ValueKey('${p.id}-start-turn'),

                onPressed: () => perform(() => widget.board.startTurn(p.id)),
                icon: Icon(
                  ManaIcons.untap,
                  size: 20,
                  semanticLabel: '${profile.name}, Start turn',
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        Positioned(
          left: 68,
          bottom: 12,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            elevation: 3,
            shape: const CircleBorder(),
            child: IconButton(
              key: ValueKey('${p.id}-board-summary'),

              onPressed: () => widget.onOpen(WorkspacePage.tokenSummary),
              icon: Icon(
                Icons.style_outlined,
                size: 20,
                semanticLabel: '${profile.name}, board summary',
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            key: ValueKey('${p.id}-add-token'),
            heroTag: '${p.id}-add-token',

            onPressed: () => widget.onOpen(WorkspacePage.tokens),
            child: Icon(Icons.add, semanticLabel: '${profile.name}, add token'),
          ),
        ),
      ],
    );
    if (widget.hubInTokenLane) {
      final lane = tokenLane;
      tokenLane = LayoutBuilder(
        builder: (context, constraints) => ClipPath(
          key: ValueKey('${p.id}-token-hub-clearance'),
          clipper: _LifeHubNotch(
            atStart: true,
            inset: (constraints.maxWidth / .6 + 1) / 2,
            radiusScale: (1 - widget.drawerShift / 40).clamp(0.0, 1.0),
          ),
          child: lane,
        ),
      );
    }
    final visible = p.utilities.where(widget.board.isUtilityVisible).toList();
    Widget innerLane = LayoutBuilder(
      builder: (context, lane) {
        // Short player-local seats keep utility padding compact so the taller
        // life chip and tools never require shrinking the utility touch targets.
        final compactUtilities = lane.maxHeight < 420;
        final lifeHeight = (lane.maxHeight * .30 + 32).clamp(160.0, 180.0);
        final toolHeight = lane.maxWidth < 132 ? 96.0 : 48.0;
        // Keep the life surface fixed even at the existing 480px boundary.
        // Tools and utilities share the remaining viewport instead of shrinking
        // touch targets, adding a menu, or overflowing the seat.
        final shortFooter = lane.maxHeight < lifeHeight + toolHeight + 44;
        void reorderUtilities(int old, int next) => perform(() async {
          final ids = visible.map((u) => u.id).toList();
          if (next > old) next--;
          ids.insert(next, ids.removeAt(old));
          await widget.board.reorderVisibleUtilities(p.id, ids);
        });
        Widget utilityItem(BuildContext context, int index) {
          final u = visible[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(u.id),
            index: index,
            enabled: !shortFooter && expandedId == null,
            child: _UtilityRow(
              compactSpacing: compactUtilities,
              interactionEpoch: Object.hash(
                widget.interactionEpoch,
                widget.controller.session.generation,
                p.generation,
              ),
              utility: u,
              player: p,
              board: widget.board,
              expanded: expandedId == u.id,
              onExpand: () => expand(u.id),
              onRemove: () => perform(() async {
                await widget.board.removeUtility(p.id, u.id);
                if (mounted && expandedId == u.id) {
                  setState(() => expandedId = null);
                }
              }),
              onTempt: () => perform(
                () => RingService(widget.controller).tempt(p.id, u.id),
              ),
              onOpen: () => widget.onOpen(WorkspacePage.utilities, u.id),
              onChange: (delta) =>
                  perform(() => widget.board.adjustUtility(p.id, u.id, delta)),
              onToggle: () =>
                  perform(() => widget.board.toggleUtility(p.id, u.id)),
              onMana: (mana, delta) => perform(
                () => widget.controller.adjustMana(p.id, mana, delta),
              ),
            ),
          );
        }

        final utilities = visible.isEmpty
            ? LayoutBuilder(
                builder: (context, space) =>
                    shortFooter || space.maxHeight < 130
                    ? Center(
                        child: TextButton(
                          onPressed: () =>
                              widget.onOpen(WorkspacePage.utilities),
                          child: const Text('Choose utilities'),
                        ),
                      )
                    : _EmptyLane(
                        icon: Icons.widgets_outlined,
                        text: 'Tools for your game',
                        action: 'Choose utilities',
                        onTap: () => widget.onOpen(WorkspacePage.utilities),
                      ),
              )
            : DragBoundary(
                child: ReorderableListView.builder(
                  scrollController: utilityScroll,
                  buildDefaultDragHandles: false,
                  itemCount: visible.length,
                  onReorder: reorderUtilities,
                  proxyDecorator: (child, index, animation) =>
                      Material(elevation: 5, child: child),
                  itemBuilder: utilityItem,
                ),
              );
        // Native reorder measures the entire utility (mana can be taller than
        // this viewport). A deliberate compact mode keeps native drag/autoscroll
        // bounded without shrinking gameplay controls or replacing the engine.
        final compactReorderList = Row(
          children: [
            SizedBox(
              width: 44,
              child: IconButton(
                key: ValueKey('${p.id}-finish-utility-reorder'),

                onPressed: () => setUtilityReorder(false),
                icon: const Icon(
                  Icons.done,
                  semanticLabel: 'Done reordering utilities',
                ),
              ),
            ),
            Expanded(
              child: DragBoundary(
                key: ValueKey('${p.id}-utility-reorder-boundary'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: CustomScrollView(
                    key: ValueKey('${p.id}-compact-utility-reorder'),
                    controller: utilityScroll,
                    slivers: [
                      SliverReorderableList(
                        itemCount: visible.length,
                        onReorder: reorderUtilities,
                        proxyDecorator: (child, index, animation) => Material(
                          key: ValueKey('${p.id}-utility-reorder-proxy'),
                          elevation: 5,
                          child: child,
                        ),
                        itemBuilder: (context, index) {
                          final u = visible[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('compact-reorder-${u.id}'),
                            index: index,
                            enabled: expandedId == null,
                            child: Semantics(
                              label: 'Reorder ${u.name}',
                              excludeSemantics: true,
                              hint: 'Hold and drag to reorder',
                              child: SizedBox(
                                height: 44,
                                child: Row(
                                  children: [
                                    const Icon(Icons.drag_handle, size: 18),
                                    Expanded(
                                      child: Text(
                                        u.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        return _LifePanel(
          compose: (surface, tools) => Column(
            children: [
              surface,
              if (!shortFooter) tools,
              Expanded(
                key: ValueKey('${p.id}-utility-section'),
                child: shortFooter
                    ? compactUtilityReorder
                          ? compactReorderList
                          : CustomScrollView(
                              key: ValueKey('${p.id}-life-footer-scroll'),
                              controller: utilityScroll,
                              slivers: [
                                SliverToBoxAdapter(child: tools),
                                if (visible.length > 1)
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: 44,
                                      child: TextButton.icon(
                                        key: ValueKey(
                                          '${p.id}-start-utility-reorder',
                                        ),
                                        onPressed: expandedId == null
                                            ? () => setUtilityReorder(true)
                                            : null,
                                        icon: const Icon(
                                          Icons.reorder,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Reorder utilities',
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (visible.isEmpty)
                                  SliverToBoxAdapter(child: utilities)
                                else
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      utilityItem,
                                      childCount: visible.length,
                                    ),
                                  ),
                              ],
                            )
                    : utilities,
              ),
            ],
          ),
          height: lifeHeight,
          twoPlayer: widget.hubInTokenLane,
          hubNotchScale: (1 - widget.drawerShift / 40).clamp(0.0, 1.0),
          centerNotch: widget.centerNotch,
          centerNotchAtStart: widget.centerNotchAtStart,
          player: p,
          profile: profile,
          controller: widget.controller,
          epoch: Object.hash(
            widget.interactionEpoch,
            p.generation,
            widget.controller.session.generation,
          ),
          enabledRules: enabled,
          onOpen: widget.onOpen,
          lifeFeedback: lifeFeedback,
          onChange: (delta) async {
            await lifeFeedback.adjust(delta);
          },
        );
      },
    );
    return RotatedBox(
      quarterTurns: widget.turns,
      child: Column(
        children: [
          if (lifeFeedback.error != null || error != null)
            Container(
              color: Theme.of(context).colorScheme.errorContainer,
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lifeFeedback.error ?? error!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (lifeFeedback.error != null)
                    Semantics(
                      label: 'Acknowledge life save warning',
                      button: true,
                      onTap: lifeFeedback.clearError,
                      excludeSemantics: true,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          key: ValueKey('${p.id}-acknowledge-life-error'),
                          onPressed: lifeFeedback.clearError,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final tokenWidth = (box.maxWidth - 1) * .6;
                final railWidth = (box.maxWidth - 1) * .4;
                final railOffset = widget.hubInTokenLane
                    ? math.max(0.0, widget.drawerShift - box.maxWidth * .1)
                    : (widget.tokenLeft
                          ? -widget.drawerShift
                          : widget.drawerShift);
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: widget.tokenLeft
                          ? tokenWidth + 1 + railOffset
                          : railOffset,
                      top: 0,
                      bottom: 0,
                      width: railWidth,
                      child: IgnorePointer(
                        ignoring: widget.drawerOpen,
                        child: ExcludeSemantics(
                          excluding: widget.drawerOpen,
                          child: Material(
                            key: ValueKey('${p.id}-sliding-rail'),
                            color: Theme.of(context).colorScheme.surface,
                            child: innerLane,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: widget.tokenLeft ? tokenWidth : railWidth,
                      top: 0,
                      bottom: 0,
                      width: 1,
                      child: ColoredBox(color: Theme.of(context).dividerColor),
                    ),
                    Positioned(
                      left: widget.tokenLeft ? 0 : railWidth + 1,
                      top: 0,
                      bottom: 0,
                      width: tokenWidth,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: ClipRect(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ExcludeSemantics(
                                excluding: widget.drawerOpen,
                                child: IgnorePointer(
                                  ignoring: widget.drawerOpen,
                                  child: tokenLane,
                                ),
                              ),
                              if (widget.drawerOpen)
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  // Native path clipping does not narrow the
                                  // browser accessibility hit rectangle. Keep
                                  // this action inside the visible token area
                                  // while the token layout stays stationary.
                                  width: widget.hubInTokenLane
                                      ? math.min(
                                          tokenWidth,
                                          math.max(
                                            0.0,
                                            box.maxWidth / 2 -
                                                widget.drawerShift,
                                          ),
                                        )
                                      : tokenWidth,
                                  child: Semantics(
                                    identifier: '${p.id}-dismiss-drawer',
                                    label: 'Close game drawer',
                                    button: true,
                                    excludeSemantics: true,
                                    onTap: widget.onCloseDrawer,
                                    child: GestureDetector(
                                      key: ValueKey('${p.id}-dismiss-drawer'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: widget.onCloseDrawer,
                                      child: const ColoredBox(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LifePanel extends StatelessWidget {
  final Widget Function(Widget surface, Widget tools) compose;
  final bool twoPlayer;
  final double hubNotchScale;
  final double height;
  final double centerNotch;
  final bool centerNotchAtStart;
  final PlayerState player;
  final SeatProfile profile;
  final TableController controller;
  final int epoch, enabledRules;
  final Future<void> Function(int) onChange;
  final LifeTapFeedback lifeFeedback;
  final void Function(WorkspacePage, [String?]) onOpen;
  const _LifePanel({
    required this.compose,
    required this.twoPlayer,
    this.hubNotchScale = 1,
    required this.height,
    required this.centerNotch,
    required this.centerNotchAtStart,
    required this.player,
    required this.profile,
    required this.controller,
    required this.epoch,
    required this.enabledRules,
    required this.onChange,
    required this.lifeFeedback,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final color = Color(profile.color);
    final artColor = profile.artworkUrl != null ? Colors.white : null;
    Widget shortcut(
      IconData icon,
      String label,
      WorkspacePage page, {
      int? count,
    }) => Semantics(
      label: '${profile.name}, $label',
      value: count == null ? null : '$count',
      button: true,
      onTap: () => onOpen(page),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onOpen(page),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: artColor),
              if (count != null && count != 0) ...[
                const SizedBox(width: 3),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$count',
                      style: TextStyle(fontSize: 11, color: artColor),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    final shortcuts = [
      shortcut(
        Icons.rule_outlined,
        'rules',
        WorkspacePage.rules,
        count: enabledRules,
      ),
      KeyedSubtree(
        key: ValueKey('${player.id}-manage-utilities'),
        child: shortcut(
          Icons.widgets_outlined,
          'Manage utilities',
          WorkspacePage.utilities,
        ),
      ),
      SizedBox(
        key: ValueKey('${player.id}-player-details'),
        height: 44,
        child: Semantics(
          label: '${profile.name}, player details',
          button: true,
          onTap: () => onOpen(WorkspacePage.player),
          excludeSemantics: true,
          child: IconButton(
            onPressed: () => onOpen(WorkspacePage.player),
            icon: const Icon(Icons.edit_outlined, size: 19),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // One set of rectangles owns both overlay placement and life-ink
        // exclusion, so resizing/rail animation cannot desynchronize them.
        const overlayHeight = 44.0;
        const overlayBottom = 6.0;
        const overlayGap = 4.0;
        final overlayInset = constraints.maxWidth < 132 ? 0.0 : 6.0;
        final ledgerWidth = constraints.maxWidth < 132
            ? 44.0
            : constraints.maxWidth < 180
            ? 64.0
            : 80.0;
        final hasSummary = _LifeCounterSummary.hasContent(player, controller);
        final summaryWidth = hasSummary
            ? math.min(
                _LifeCounterSummary.preferredWidth(player, controller),
                math.max(
                  0.0,
                  constraints.maxWidth -
                      overlayInset * 2 -
                      ledgerWidth -
                      overlayGap,
                ),
              )
            : 0.0;
        // Center the content that is actually present. An absent summary
        // contributes neither width nor a gap, including zero-valued counters.
        final groupWidth =
            ledgerWidth + (hasSummary ? overlayGap + summaryWidth : 0.0);
        final ledgerRect = Rect.fromLTWH(
          (constraints.maxWidth - groupWidth) / 2,
          height - overlayBottom - overlayHeight,
          ledgerWidth,
          overlayHeight,
        );
        final summaryRect = hasSummary
            ? Rect.fromLTWH(
                ledgerRect.right + overlayGap,
                ledgerRect.top,
                summaryWidth,
                overlayHeight,
              )
            : null;
        final surface = ClipPath(
          key: ValueKey('${player.id}-life-clip'),
          clipper: _LifeHubNotch(
            atStart: centerNotchAtStart,
            inset: -1.5,
            enabled: centerNotch > 0 || twoPlayer,
            sharedControls: true,
            twoPlayer: twoPlayer,
            radiusScale: hubNotchScale,
          ),
          child: _ArtworkSurface(
            key: ValueKey('${player.id}-life-surface'),
            url: profile.artworkUrl,
            artworkFit: BoxFit.cover,
            tint: Color.alphaBlend(
              color.withValues(alpha: .19),
              Theme.of(context).colorScheme.surface,
            ),
            child: Stack(
              children: [
                HalfStepper(
                  label: '${profile.name}, life',
                  value: '${lifeFeedback.life}',
                  height: height,
                  inkExclusions: [ledgerRect, ?summaryRect],
                  iconSize: 22,
                  // The signs stay beside the number, not the subdued name.
                  iconY: -10 / height,
                  decreaseKey: ValueKey('${player.id}-life-decrease'),
                  increaseKey: ValueKey('${player.id}-life-increase'),
                  decreaseLabel: '${profile.name}, decrease life by one',
                  increaseLabel: '${profile.name}, increase life by one',
                  onDecrease: () => onChange(-1),
                  onIncrease: () => onChange(1),
                  onDecreaseHoldStep: (amount) => onChange(-amount),
                  onIncreaseHoldStep: onChange,
                  holdStep: 10,
                  interactionEpoch: epoch,
                  foregroundColor: artColor,
                  displayOverlay: Padding(
                    padding: const EdgeInsets.only(top: 46, bottom: 52),
                    child: _LifeDelta(
                      entry:
                          controller.session.history.isNotEmpty &&
                              !controller.session.history.last.undone &&
                              controller.session.history.last.groupKey ==
                                  'life:${player.id}'
                          ? controller.session.history.last
                          : null,
                      builder: (delta) => _LifeNumber(
                        playerId: player.id,
                        life: lifeFeedback.life,
                        delta: lifeFeedback.displayDelta(delta),
                        color: artColor,
                        fontSize: 80,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 28,
                  left: twoPlayer ? 54 : 26,
                  right: 26,
                  height: 18,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              profile.name,
                              key: ValueKey('${player.id}-player-name'),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color:
                                    (artColor ??
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface)
                                        .withValues(
                                          alpha: artColor == null ? .68 : .85,
                                        ),
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (player.warnings.isNotEmpty)
                            Icon(
                              Icons.warning_amber_rounded,
                              key: ValueKey('${player.id}-life-warning'),
                              color: const Color(0xFFFFB485),
                              size: 14,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: ledgerRect,
                  child: CommanderLedger(
                    key: ValueKey('${player.id}-commander-ledger'),
                    controller: controller,
                    recipient: player,
                    onOpen: () => onOpen(WorkspacePage.commanderDamage),
                  ),
                ),
                if (summaryRect != null)
                  Positioned.fromRect(
                    rect: summaryRect,
                    child: _LifeCounterSummary(
                      player: player,
                      profile: profile,
                      controller: controller,
                      onOpen: () => onOpen(WorkspacePage.commanderDamage),
                    ),
                  ),
              ],
            ),
          ),
        );
        final tools = SizedBox(
          key: ValueKey('${player.id}-life-tools'),
          height: constraints.maxWidth < 132 ? 96 : 48,
          child: constraints.maxWidth < 132
              ? Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 2,
                  runSpacing: 4,
                  children: [
                    for (final shortcut in shortcuts)
                      SizedBox(width: 44, height: 44, child: shortcut),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final shortcut in shortcuts)
                      SizedBox(width: 44, height: 44, child: shortcut),
                  ],
                ),
        );
        return compose(surface, tools);
      },
    );
  }
}

/// One stable, accessible target presents active state without adding another
/// toolbar. Every value remains available in the focused Counters route.
class _LifeCounterSummary extends StatelessWidget {
  final PlayerState player;
  final SeatProfile profile;
  final TableController controller;
  final VoidCallback onOpen;
  const _LifeCounterSummary({
    required this.player,
    required this.profile,
    required this.controller,
    required this.onOpen,
  });

  static double preferredWidth(PlayerState player, TableController controller) {
    final count =
        player.counters.values.where((value) => value != 0).length +
        (controller.session.monarchPlayerId == player.id ? 1 : 0) +
        (player.citysBlessing ? 1 : 0) +
        (player.utilities.any(
              (utility) =>
                  {'initiative', 'the_initiative'}.contains(utility.kind) &&
                  utility.isActive,
            )
            ? 1
            : 0);
    return (count * 30.0).clamp(44.0, 180.0);
  }

  static bool hasContent(PlayerState player, TableController controller) =>
      controller.session.monarchPlayerId == player.id ||
      player.citysBlessing ||
      player.counters.values.any((value) => value != 0) ||
      player.utilities.any(
        (utility) =>
            {'initiative', 'the_initiative'}.contains(utility.kind) &&
            utility.isActive,
      );

  @override
  Widget build(BuildContext context) {
    if (!hasContent(player, controller)) return const SizedBox.shrink();
    final monarch = controller.session.monarchPlayerId == player.id;
    final initiative = player.utilities.any(
      (utility) =>
          {'initiative', 'the_initiative'}.contains(utility.kind) &&
          utility.isActive,
    );
    final counters = player.counters.entries
        .where((entry) => entry.value != 0)
        .toList();
    final statuses = <Widget>[
      if (monarch) const MonarchCrown(),
      if (player.citysBlessing) const Icon(TableManaIcons.ascend),
      if (initiative) const Icon(Icons.explore_outlined),
    ];
    final entries = <Widget>[
      for (final counter in counters)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(switch (counter.key) {
              'energy' => Icons.bolt,
              'poison' => Icons.science_outlined,
              'experience' => Icons.auto_awesome,
              'radiation' => Icons.blur_circular,
              _ => Icons.hexagon_outlined,
            }),
            const SizedBox(width: 2),
            Text(
              '${counter.value}',
              style: const TextStyle(fontSize: 11, height: 1),
            ),
          ],
        ),
    ];
    final summary = [
      if (monarch) 'Monarch',
      if (player.citysBlessing) 'City’s blessing',
      if (initiative) 'Initiative',
      for (final counter in counters) '${counter.key}: ${counter.value}',
    ].join('; ');
    final foreground = profile.artworkUrl == null
        ? Theme.of(context).colorScheme.onSurface
        : Colors.white;
    return Semantics(
      identifier: '${player.id}-life-counter-summary',
      label: '${profile.name}, player counters',
      value: summary,
      hint: 'Open Commander damage and player counters',
      button: true,
      excludeSemantics: true,
      onTap: onOpen,
      child: Material(
        color: profile.artworkUrl == null
            ? Colors.black.withValues(alpha: .13)
            : Colors.black.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(7),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: SizedBox(
            key: ValueKey('${player.id}-life-counter-summary'),
            height: 44,
            child: IconTheme(
              data: IconThemeData(size: 16, color: foreground),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foreground),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final columns = math.max(
                      1,
                      ((box.maxWidth - 4) / 30).floor(),
                    );
                    final slots = columns * (statuses.isEmpty ? 2 : 1);
                    final shown = entries.length > slots
                        ? [
                            ...entries.take(slots - 1),
                            Text(
                              '+${entries.length - slots + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ]
                        : entries;
                    return Center(
                      child: statuses.isEmpty && entries.isEmpty
                          ? const Icon(Icons.hexagon_outlined, size: 22)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (statuses.isNotEmpty)
                                  SizedBox(
                                    height: 18,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (final status in statuses)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              child: status,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (statuses.isNotEmpty && shown.isNotEmpty)
                                  const SizedBox(height: 3),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  runSpacing: 3,
                                  children: [
                                    for (final entry in shown)
                                      SizedBox(
                                        width: (box.maxWidth - 4) / columns,
                                        height: 16,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: entry,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular clearance follows the hub, rather than removing a full-height strip.
class _LifeHubNotch extends CustomClipper<Path> {
  final bool atStart;
  final double inset;
  final bool enabled;
  final bool sharedControls, twoPlayer;
  final double radiusScale;
  const _LifeHubNotch({
    required this.atStart,
    required this.inset,
    this.enabled = true,
    this.sharedControls = false,
    this.twoPlayer = false,
    this.radiusScale = 1,
  });
  @override
  Path getClip(Size size) => !enabled
      ? (Path()..addRect(Offset.zero & size))
      : Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()
            ..addOval(
              Rect.fromCircle(
                center: twoPlayer
                    ? const Offset(26, 26)
                    : Offset(atStart ? inset : size.width - inset, -1.5),
                radius: (twoPlayer ? 26 : 30) * radiusScale,
              ),
            )
            ..addOval(
              Rect.fromCircle(
                center: Offset(
                  atStart ? inset + 54 : size.width - inset - 54,
                  -1.5,
                ),
                radius: sharedControls && !twoPlayer ? 26 * radiusScale : 0,
              ),
            ),
        );
  @override
  bool shouldReclip(covariant _LifeHubNotch oldClipper) =>
      atStart != oldClipper.atStart ||
      inset != oldClipper.inset ||
      enabled != oldClipper.enabled ||
      sharedControls != oldClipper.sharedControls ||
      twoPlayer != oldClipper.twoPlayer ||
      radiusScale != oldClipper.radiusScale;
}

class _EmptyLane extends StatelessWidget {
  final IconData icon;
  final String text, action;
  final VoidCallback onTap;
  const _EmptyLane({
    required this.icon,
    required this.text,
    required this.action,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onTap,
              child: Text(action, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    ),
  );
}

class _UtilityRow extends StatelessWidget {
  final bool compactSpacing;
  final int interactionEpoch;
  final UtilityState utility;
  final PlayerState player;
  final BoardService board;
  final bool expanded;
  final VoidCallback onExpand, onRemove, onOpen, onToggle, onTempt;
  final Future<void> Function(int) onChange;
  final Future<void> Function(String, int) onMana;
  const _UtilityRow({
    this.compactSpacing = false,
    required this.interactionEpoch,
    required this.utility,
    required this.player,
    required this.board,
    required this.expanded,
    required this.onExpand,
    required this.onRemove,
    required this.onTempt,
    required this.onOpen,
    required this.onChange,
    required this.onToggle,
    required this.onMana,
  });
  @override
  Widget build(BuildContext context) {
    final mana = utility.kind == 'mana_pool' || utility.kind == 'mana';
    final inlineAction =
        utility.kind == 'the_ring' ||
        UtilityInlineActions.labels.containsKey(utility.kind);
    final step = (utility.configuration['tapIncrement'] as num?)?.toInt() ?? 1;
    final actionOnly = utility.configuration['actionOnly'] == true;
    final toggle =
        utility.configuration['isToggle'] == true ||
        utility.configuration['type'] == 'toggle' ||
        utility.kind == 'citys_blessing' ||
        [
          'monarch',
          'the_monarch',
          'day_night',
          'the_initiative',
          'toggle',
        ].contains(utility.kind);
    final color = utility.artworkUrl == null
        ? Theme.of(context).colorScheme.onSurface
        : Colors.white;
    Widget icon(IconData data, String label, VoidCallback action) =>
        MergeSemantics(
          child: Semantics(
            label: label,
            child: IconButton(
              onPressed: action,
              icon: Icon(data, size: 19, color: color),
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactStorm =
            utility.kind == 'storm_count' && constraints.maxWidth < 230;
        final narrowStorm = compactStorm && constraints.maxWidth < 180;
        final narrowValue = constraints.maxWidth < 210;
        final narrowToggle =
            toggle && expanded && !inlineAction && constraints.maxWidth < 260;
        final toggleControl = Switch(
          value: board.utilityActive(player.id, utility.id),
          onChanged: (_) => onToggle(),
        );
        final valueStepper = Container(
          key: ValueKey('${utility.id}-value-surface'),
          decoration: BoxDecoration(
            color: utility.artworkUrl == null
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : const Color(0xDD111715),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: utility.artworkUrl == null
                  ? Theme.of(context).colorScheme.outline
                  : const Color(0xFFBDC9C0),
            ),
          ),
          child: HalfStepper(
            label: utility.name,
            value: '${board.utilityValue(player.id, utility.id)}',
            decreaseLabel: 'Decrease ${utility.name}',
            increaseLabel: 'Increase ${utility.name}',
            onDecrease: () => onChange(-step),
            onIncrease: () => onChange(step),
            onDecreaseHoldStep: (amount) => onChange(-amount),
            onIncreaseHoldStep: (amount) => onChange(amount),
            interactionEpoch: interactionEpoch,
            foregroundColor: color,
            iconSize: 15,
            iconPadding: 3,
            displayPadding: 19,
            valueStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        );
        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: _ArtworkSurface(
            url: utility.artworkUrl,
            expanded: expanded,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    narrowToggle ? 6 : 10,
                    0,
                    narrowToggle ? 2 : 6,
                    compactSpacing ? 0 : 3,
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: color),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                label:
                                    '${utility.name}, ${expanded ? 'collapse' : 'expand'}',
                                button: true,
                                excludeSemantics: true,
                                child: InkWell(
                                  onTap: onExpand,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: compactStorm && !narrowStorm
                                        ? Icon(
                                            Icons.bolt_outlined,
                                            size: 22,
                                            color: color,
                                          )
                                        : Text(
                                            utility.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                            maxLines: expanded ? null : 2,
                                            overflow: expanded
                                                ? null
                                                : TextOverflow.ellipsis,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            if (mana)
                              icon(
                                Icons.edit_outlined,
                                'Manage ${utility.name}',
                                onOpen,
                              )
                            else if (toggle && !narrowToggle)
                              toggleControl
                            else if (!toggle &&
                                !actionOnly &&
                                !narrowStorm &&
                                !narrowValue)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: SizedBox(width: 90, child: valueStepper),
                              ),
                            if (expanded && !inlineAction) ...[
                              if (!mana)
                                icon(
                                  Icons.edit_outlined,
                                  '${utility.name}, details and actions',
                                  onOpen,
                                ),
                            ],
                            SizedBox(
                              key: ValueKey('remove-utility-${utility.id}'),
                              width: 44,
                              height: 44,
                              child: icon(
                                Icons.close,
                                'Remove ${utility.name}',
                                onRemove,
                              ),
                            ),
                          ],
                        ),
                        if (narrowToggle)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: toggleControl,
                          ),
                        // A portrait Storm row cannot share its value width with
                        // its title while preserving comfortable stepper targets.
                        if (!mana &&
                            !toggle &&
                            !actionOnly &&
                            (narrowStorm || narrowValue))
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: narrowStorm ? double.infinity : 90,
                              child: valueStepper,
                            ),
                          ),
                        if (mana)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Two columns keep both +/- targets usable in the narrow
                              // portrait lane; landscape fits all six colors in two rows.
                              final columns = constraints.maxWidth >= 200
                                  ? 3
                                  : 2;
                              final width =
                                  (constraints.maxWidth - (columns - 1) * 4) /
                                  columns;
                              return Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final type in PlayerState.manaColors)
                                    SizedBox(
                                      width: width,
                                      height: 44,
                                      child: Material(
                                        color: _manaColor(type),
                                        borderRadius: BorderRadius.circular(6),
                                        clipBehavior: Clip.antiAlias,
                                        child: HalfStepper(
                                          label: '${_manaName(type)} mana',
                                          value: '${player.mana[type] ?? 0}',
                                          height: 44,
                                          iconSize: 15,
                                          iconPadding: 5,
                                          displayPadding: 20,
                                          decreaseKey: ValueKey(
                                            '${player.id}-mana-$type-spend',
                                          ),
                                          increaseKey: ValueKey(
                                            '${player.id}-mana-$type-add',
                                          ),
                                          decreaseLabel:
                                              'Spend one ${_manaName(type)} mana',
                                          increaseLabel:
                                              '${_manaName(type)} mana ${player.mana[type] ?? 0}, add one',
                                          decreaseHint:
                                              'Spend ${_manaName(type)} mana; hold to spend ten',
                                          increaseHint:
                                              'Add ${_manaName(type)} mana; hold to add ten',
                                          onDecrease: () => onMana(type, -1),
                                          onIncrease: () => onMana(type, 1),
                                          onDecreaseHoldStep: (amount) =>
                                              onMana(type, -amount),
                                          onIncreaseHoldStep: (amount) =>
                                              onMana(type, amount),
                                          holdStep: 10,
                                          interactionEpoch: interactionEpoch,
                                          foregroundColor: Colors.white,
                                          valueWidget: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _manaGlyph(type),
                                                size: 17,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${player.mana[type] ?? 0}',
                                                style: const TextStyle(
                                                  fontSize: 21,
                                                  height: 1,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        if (expanded) ...[
                          if (compactStorm && !narrowStorm)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                utility.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          if (utility.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                utility.description,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                        if (utility.kind == 'the_ring')
                          RingInline(
                            utility: utility,
                            onTempt: onTempt,
                            trailing: expanded
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      icon(
                                        Icons.edit_outlined,
                                        '${utility.name}, details and actions',
                                        onOpen,
                                      ),
                                    ],
                                  )
                                : null,
                          )
                        else
                          UtilityInlineActions(
                            key: ValueKey('inline-actions-${utility.id}'),
                            board: board,
                            playerId: player.id,
                            utility: utility,
                            management: expanded && inlineAction
                                ? [
                                    icon(
                                      Icons.edit_outlined,
                                      '${utility.name}, details and actions',
                                      onOpen,
                                    ),
                                  ]
                                : const [],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _manaGlyph(String color) => switch (color) {
    'W' => ManaIcons.white,
    'U' => ManaIcons.blue,
    'B' => ManaIcons.black,
    'R' => ManaIcons.red,
    'G' => ManaIcons.green,
    _ => ManaIcons.colorless,
  };
  String _manaName(String color) => switch (color) {
    'W' => 'white',
    'U' => 'blue',
    'B' => 'black',
    'R' => 'red',
    'G' => 'green',
    _ => 'colorless',
  };
  Color _manaColor(String color) => switch (color) {
    'W' => const Color(0xFF6C6149),
    'U' => const Color(0xFF28516B),
    'B' => const Color(0xFF4E405F),
    'R' => const Color(0xFF833D39),
    'G' => const Color(0xFF3E6547),
    _ => const Color(0xFF555D60),
  };
}

/// Immutable uploaded art uses data URIs. Missing remote or imported file art
/// stays selected and falls back visually without mutating saved metadata.
class _ArtworkSurface extends StatelessWidget {
  final String? url;
  final Color? tint;
  final Widget child;
  final bool expanded;
  final BoxFit artworkFit;
  const _ArtworkSurface({
    super.key,
    this.url,
    this.tint,
    required this.child,
    this.expanded = false,
    this.artworkFit = BoxFit.fitWidth,
  });
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: tint ?? Theme.of(context).colorScheme.surfaceContainerLow,
    child: TableArtworkSurface(
      url: url,
      expanded: expanded,
      artworkFit: artworkFit,
      child: child,
    ),
  );
}

class _LifeDelta extends StatefulWidget {
  final HistoryEntry? entry;
  final Widget Function(int?) builder;
  const _LifeDelta({this.entry, required this.builder});
  @override
  State<_LifeDelta> createState() => _LifeDeltaState();
}

class _LifeDeltaState extends State<_LifeDelta> {
  Timer? expiry;
  int? delta;
  String? version;
  void refresh() {
    final entry = widget.entry;
    final nextVersion = entry == null
        ? null
        : '${entry.id}:${entry.commands.length}';
    if (nextVersion == version) return;
    version = nextVersion;
    expiry?.cancel();
    // A persisted history row is not an active gesture after reopening a game.
    final fresh =
        entry != null &&
        DateTime.now().toUtc().difference(entry.updatedAt) <=
            TableController.groupingWindow;
    delta = fresh ? entry.totalDelta : null;
    if (fresh) {
      expiry = Timer(TableController.groupingWindow, () {
        if (mounted) setState(() => delta = null);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(covariant _LifeDelta oldWidget) {
    super.didUpdateWidget(oldWidget);
    refresh();
  }

  @override
  void dispose() {
    expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(delta);
}

/// Fit the total symmetrically, then anchor the delta to its painted text bounds.
/// Delta presence/sign never shifts the total, and neither depends on corner
/// alignment. Reserved side slots also bound long signed changes.
class _LifeNumber extends StatelessWidget {
  final String playerId;
  final int life;
  final int? delta;
  final Color? color;
  final double fontSize;
  const _LifeNumber({
    required this.playerId,
    required this.life,
    required this.delta,
    required this.color,
    required this.fontSize,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final style = DefaultTextStyle.of(context).style.merge(
        TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          height: 1,
          color: color,
        ),
      );
      final scaler = MediaQuery.textScalerOf(context);
      final painter = TextPainter(
        text: TextSpan(text: '$life', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final slot = box.maxWidth < 180 ? 26.0 : 42.0;
      const gap = 4.0;
      final available = math.max(1.0, box.maxWidth - 2 * (slot + gap + 2));
      final scale = math.min(
        1.0,
        math.min(available / painter.width, box.maxHeight / painter.height),
      );
      final width = painter.width * scale;
      final height = painter.height * scale;
      painter.dispose();
      final positive = (delta ?? 0) >= 0;
      return Stack(
        children: [
          Positioned(
            left: (box.maxWidth - width) / 2,
            top: (box.maxHeight - height) / 2,
            width: width,
            height: height,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$life',
                key: ValueKey('$playerId-life-number'),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
                style: style,
              ),
            ),
          ),
          Positioned(
            left: positive
                ? (box.maxWidth + width) / 2 + gap
                : (box.maxWidth - width) / 2 - gap - slot,
            top: 0,
            bottom: 0,
            width: slot,
            child: KeyedSubtree(
              key: ValueKey('$playerId-life-delta'),
              child: delta == null
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: positive
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Semantics(
                          label: 'Life change ${positive ? '+' : ''}$delta',
                          liveRegion: true,
                          child: Text(
                            '${positive ? '+' : ''}$delta',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      );
    },
  );
}
