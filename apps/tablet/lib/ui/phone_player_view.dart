part of 'table_screen.dart';

/// Fixed Player 1, one utilities-then-tokens scroll body, approved action pod C.
/// Gameplay commands are the existing Table commands; this is presentation only.
class _PhonePlayerView extends StatefulWidget {
  const _PhonePlayerView({
    required this.controller,
    required this.board,
    required this.catalog,
    required this.lifeFeedback,
    required this.interactionEpoch,
    required this.active,
    required this.inputLocked,
    required this.onInputLock,
    required this.onCancelGestures,
    required this.onOpen,
  });
  final TableController controller;
  final BoardService board;
  final TabletCatalog catalog;
  final LifeTapFeedback lifeFeedback;
  final int interactionEpoch;
  final bool active, inputLocked;
  final ValueChanged<bool> onInputLock;
  final VoidCallback onCancelGestures;
  final void Function(WorkspacePage, [String?]) onOpen;
  @override
  State<_PhonePlayerView> createState() => _PhonePlayerViewState();
}

class _PhonePlayerViewState extends State<_PhonePlayerView> {
  final scroll = ScrollController();
  late LifeTapFeedback feedback;
  String? expanded, error;
  bool moreOpen = false;
  String? sessionId;
  PlayerState get player => widget.controller.session.players.first;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    sessionId = widget.controller.session.id;
    feedback = widget.lifeFeedback..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _PhonePlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (sessionId != widget.controller.session.id ||
        oldWidget.lifeFeedback != widget.lifeFeedback) {
      feedback.removeListener(_refresh);
      _bind();
      expanded = null;
      error = null;
    }
    if (oldWidget.active != widget.active) moreOpen = false;
  }

  @override
  void dispose() {
    feedback.removeListener(_refresh);
    scroll.dispose();
    super.dispose();
  }

  Future<void> perform(Future<dynamic> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = inputErrorMessage(e));
    }
  }

  void expand(String id) => setState(() {
    expanded = expanded == null ? id : null;
  });

  Widget action(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool primary = false,
  }) => Semantics(
    label: label,
    button: true,
    onTap: onTap,
    excludeSemantics: true,
    child: Material(
      color: primary
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          key: ValueKey(
            'phone-action-${label.toLowerCase().replaceAll(' ', '-')}',
          ),
          width: 56,
          height: 56,
          child: Icon(icon, size: 25),
        ),
      ),
    ),
  );

  Widget moreMenu() {
    Widget row(IconData icon, String label, VoidCallback onTap) => ListTile(
      dense: true,
      minVerticalPadding: 8,
      leading: Icon(icon, size: 22),
      title: Text(label),
      onTap: () {
        setState(() => moreOpen = false);
        onTap();
      },
    );
    return Material(
      key: const ValueKey('phone-more-menu'),
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260, maxHeight: 370),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row(
                Icons.style_outlined,
                'Player 1 summary',
                () => widget.onOpen(WorkspacePage.tokenSummary),
              ),
              row(
                ManaIcons.untap,
                'Start Player 1 turn',
                () => perform(() => widget.board.startTurn(player.id)),
              ),
              row(
                Icons.widgets_outlined,
                'Manage utilities',
                () => widget.onOpen(WorkspacePage.utilities),
              ),
              row(
                Icons.inventory_2_outlined,
                'Saved setups',
                () => widget.onOpen(WorkspacePage.presets),
              ),
              row(
                Icons.rule_outlined,
                'Player 1 rules',
                () => widget.onOpen(WorkspacePage.rules),
              ),
              row(
                Icons.edit_outlined,
                'Player 1 settings',
                () => widget.onOpen(WorkspacePage.player),
              ),
              const Divider(height: 1),
              row(
                Icons.tune,
                'Game tools',
                () => widget.onOpen(WorkspacePage.tableHub),
              ),
              row(
                Icons.history,
                'Game history & undo',
                () => widget.onOpen(WorkspacePage.history),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = player;
    final profile = widget.controller.profile(p.seatId);
    final visible = p.utilities.where(widget.board.isUtilityVisible).toList();
    final epoch = Object.hash(
      widget.interactionEpoch,
      widget.active,
      moreOpen,
      p.generation,
      widget.controller.session.generation,
    );
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      key: const ValueKey('phone-player-one'),
      children: [
        GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: moreOpen ? () => setState(() => moreOpen = false) : null,
          child: IgnorePointer(
            ignoring: moreOpen,
            child: _LifePanel(
              phone: true,
              compose: (surface, tools) => surface,
              twoPlayer: false,
              hubNotchScale: 0,
              height: MediaQuery.textScalerOf(context).scale(14) > 21
                  ? 158
                  : 142,
              centerNotch: 0,
              centerNotchAtStart: false,
              player: p,
              profile: profile,
              controller: widget.controller,
              epoch: epoch,
              enabledRules: 0,
              onOpen: widget.onOpen,
              lifeFeedback: feedback,
              onChange: (delta) async {
                await feedback.adjust(delta);
              },
            ),
          ),
        ),
        if (widget.controller.recoveryMessage != null ||
            (widget.controller.error != null &&
                error == null &&
                feedback.error == null))
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.controller.error ??
                        widget.controller.recoveryMessage!,
                    maxLines: 3,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onOpen(WorkspacePage.settings),
                  child: const Text('Details'),
                ),
              ],
            ),
          ),
        if (error != null || feedback.error != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(feedback.error ?? error!),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    feedback.clearError();
                    setState(() => error = null);
                  },
                  icon: const Icon(
                    Icons.close,
                    semanticLabel: 'Dismiss save warning',
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: DragBoundary(
                  child: CustomScrollView(
                    key: const PageStorageKey('phone-player-one-scroll'),
                    controller: scroll,
                    slivers: [
                      SliverReorderableList(
                        itemCount: visible.length,
                        onReorder: (old, next) => perform(() async {
                          final ids = visible.map((u) => u.id).toList();
                          if (next > old) {
                            next--;
                          }
                          ids.insert(next, ids.removeAt(old));
                          await widget.board.reorderVisibleUtilities(p.id, ids);
                        }),
                        itemBuilder: (context, index) {
                          final u = visible[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('phone-utility-${u.id}'),
                            index: index,
                            enabled: expanded == null,
                            child: _UtilityRow(
                              phone: true,
                              compactSpacing: true,
                              interactionEpoch: epoch,
                              utility: u,
                              player: p,
                              board: widget.board,
                              onRemove: () => perform(() async {
                                await widget.board.removeUtility(p.id, u.id);
                                if (mounted && expanded == u.id) {
                                  setState(() => expanded = null);
                                }
                              }),
                              onTempt: () => perform(
                                () => RingService(
                                  widget.controller,
                                ).tempt(p.id, u.id),
                              ),
                              onOpen: () =>
                                  widget.onOpen(WorkspacePage.utilities, u.id),
                              onChange: (delta) => perform(
                                () => widget.board.adjustUtility(
                                  p.id,
                                  u.id,
                                  delta,
                                ),
                              ),
                              onToggle: () => perform(
                                () => widget.board.toggleUtility(p.id, u.id),
                              ),
                              onMana: (mana, delta) => perform(
                                () => widget.controller.adjustMana(
                                  p.id,
                                  mana,
                                  delta,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (p.tokens.isEmpty)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 160,
                            child: _EmptyLane(
                              icon: Icons.style_outlined,
                              text: 'Your token board',
                              action: 'Add a token',
                              onTap: () => widget.onOpen(WorkspacePage.tokens),
                            ),
                          ),
                        )
                      else
                        SliverReorderableList(
                          itemCount: p.tokens.length,
                          onReorder: (old, next) => perform(
                            () =>
                                widget.board.reorder(p.id, 'tokens', old, next),
                          ),
                          itemBuilder: (context, index) {
                            final token = p.tokens[index];
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey('phone-token-${token.id}'),
                              index: index,
                              enabled: expanded == null,
                              child: TabletTokenCard(
                                token: token,
                                interactionEpoch: epoch,
                                player: p,
                                board: widget.board,
                                playerName: profile.name,
                                quarterTurns: 0,
                                expanded: expanded == token.id,
                                onExpand: () => expand(token.id),
                                onOpenDetailed: (page) =>
                                    widget.onOpen(page, token.id),
                                onInputLock: widget.onInputLock,
                              ),
                            );
                          },
                        ),
                      // Trailing scroll clearance only: no leading/header spacer.
                      const SliverToBoxAdapter(child: SizedBox(height: 88)),
                    ],
                  ),
                ),
              ),
              if (moreOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => moreOpen = false),
                    child: const ColoredBox(color: Color(0x22000000)),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 80,
                  top: 8,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: moreMenu(),
                  ),
                ),
              ],
              if (!keyboard && !widget.inputLocked)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      action(Icons.more_horiz, 'More', () {
                        widget.onCancelGestures();
                        setState(() => moreOpen = !moreOpen);
                      }),
                      const SizedBox(width: 8),
                      action(Icons.widgets_outlined, 'Utilities', () {
                        setState(() => moreOpen = false);
                        widget.onOpen(WorkspacePage.utilities);
                      }),
                      const SizedBox(width: 8),
                      action(Icons.add, 'Add token', () {
                        setState(() => moreOpen = false);
                        widget.onOpen(WorkspacePage.tokens);
                      }, primary: true),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
