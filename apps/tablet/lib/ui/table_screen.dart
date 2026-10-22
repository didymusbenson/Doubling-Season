import 'dart:async';
import 'package:flutter/material.dart';
import 'package:doubling_season/utils/color_utils.dart';
import '../domain/table_state.dart';
import '../state/table_controller.dart';
import '../services/tablet_catalog.dart';
import '../services/table_support_service.dart';
import '../features/board_service.dart';
import 'workspace/table_workspace.dart';
import 'table_artwork.dart';
import 'tablet_token_card.dart';

/// The table is composed in seat-local coordinates, then oriented toward each
/// player. Tokens remain on the physical outer edge in the four-slot layout.
class TableScreen extends StatefulWidget {
  final TableController controller;
  const TableScreen({super.key, required this.controller});
  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  late final TabletCatalog catalog = TabletCatalog(widget.controller);
  late final BoardService board = BoardService(widget.controller, catalog);
  bool modalOpen = false;
  int interactionEpoch = 0;

  @override
  void initState() {
    super.initState();
    unawaited(catalog.load());
  }

  @override
  void dispose() {
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

  Future<void> hideUtility(
    PlayerState player,
    UtilityState utility,
    int turns,
  ) async {
    if (modalOpen) return;
    setState(() {
      modalOpen = true;
      interactionEpoch++;
    });
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => RotatedBox(
        quarterTurns: turns,
        child: AlertDialog(
          title: Text('Hide ${utility.name}?'),
          content: const Text(
            'Its values will be kept. You can bring it back from Utilities.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hide utility'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await widget.controller.updateState(
        'Hide utility',
        (state) {
          final found = state.session
              .player(player.id)
              .utilities
              .firstWhere((u) => u.id == utility.id);
          found.visible = false;
        },
        recordHistory: true,
        playerId: player.id,
      );
    }
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
          listenable: controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650 || constraints.maxHeight < 480) {
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
                  interactionEpoch: interactionEpoch,
                  onInputLock: setInputLock,
                  onOpen: (page, [itemId]) =>
                      open(page, player: player, itemId: itemId, turns: turns),
                  onHide: (u) => hideUtility(player, u, turns),
                );
              }

              Widget slot(int number) {
                final players = controller.session.players.where(
                  (p) => p.slot == number,
                );
                if (players.isNotEmpty) return seat(players.first);
                return RotatedBox(
                  quarterTurns: number == 1 || number == 2 ? 2 : 0,
                  child: _EmptyControlSpace(
                    onOpen: (page) =>
                        open(page, turns: number == 1 || number == 2 ? 2 : 0),
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
                    child: two
                        ? seat(controller.session.players[1])
                        : Row(
                            children: [
                              Expanded(child: slot(1)),
                              const VerticalDivider(width: 2),
                              Expanded(child: slot(2)),
                            ],
                          ),
                  ),
                  _GameStrip(
                    controller: controller,
                    onOpen: (page) => open(page),
                  ),
                  Expanded(
                    child: two
                        ? seat(controller.session.players[0])
                        : Row(
                            children: [
                              Expanded(child: slot(0)),
                              const VerticalDivider(width: 2),
                              Expanded(child: slot(3)),
                            ],
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

class _GameStrip extends StatelessWidget {
  final TableController controller;
  final ValueChanged<WorkspacePage> onOpen;
  const _GameStrip({required this.controller, required this.onOpen});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListenableBuilder(
              listenable: TableSupportService.instance,
              builder: (context, _) {
                final support = TableSupportService.instance;
                return Icon(
                  support.tier == 0 ? Icons.spa_outlined : Icons.favorite,
                  size: 22,
                  semanticLabel: support.tier == 0
                      ? 'Tripling Table'
                      : '${TableSupportService.tierNames[support.tier - 1]} supporter',
                  color: support.tier == 0
                      ? null
                      : Color(
                          support.tier == 1
                              ? 0xffdf7474
                              : support.tier == 2
                              ? 0xff83b7ce
                              : support.heartColor,
                        ),
                );
              },
            ),
          ),
          const Spacer(),
          _StripButton(
            icon: Icons.history,
            label: 'History',
            onTap: () => onOpen(WorkspacePage.history),
          ),
          _StripButton(
            icon: Icons.casino_outlined,
            label: 'Dice',
            onTap: () => onOpen(WorkspacePage.dice),
          ),
          _StripButton(
            icon: controller.session.dayNight == 'night'
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            label: controller.session.dayNight == 'neither'
                ? 'Day / night'
                : controller.session.dayNight,
            onTap: () => onOpen(WorkspacePage.settings),
          ),
          _StripButton(
            icon: Icons.restart_alt,
            label: 'Reset',
            onTap: () => onOpen(WorkspacePage.reset),
          ),
          _StripButton(
            icon: Icons.tune,
            label: 'Table',
            onTap: () => onOpen(WorkspacePage.settings),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Semantics(
              label: controller.busy ? 'Saving game' : 'Game saved',
              child: Icon(
                controller.busy ? Icons.sync : Icons.check_circle_outline,
                size: 17,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StripButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _StripButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      minimumSize: const Size(44, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
  final void Function(WorkspacePage, [String?]) onOpen;
  final ValueChanged<UtilityState> onHide;
  final ValueChanged<bool> onInputLock;
  const _PlayerSpace({
    super.key,
    required this.controller,
    required this.board,
    required this.player,
    required this.turns,
    required this.tokenLeft,
    required this.interactionEpoch,
    required this.onOpen,
    required this.onHide,
    required this.onInputLock,
  });
  @override
  State<_PlayerSpace> createState() => _PlayerSpaceState();
}

class _PlayerSpaceState extends State<_PlayerSpace> {
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
    final hidden = p.utilities.where((u) => !u.visible).length;
    final enabled = widget.board
        .effectiveSources(p.id)
        .where((s) => s.enabled && s.count > 0)
        .length;
    Widget tokenLane = Column(
      children: [
        _LaneHeading(
          count: p.tokens.length,
          tooltip: '${profile.name}, add token',
          onAdd: () => widget.onOpen(WorkspacePage.tokens),
          summaryTooltip: '${profile.name}, board summary',
          onSummary: () => widget.onOpen(WorkspacePage.tokenSummary),
        ),
        Expanded(
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
      ],
    );
    final visible = p.utilities.where((u) => u.visible).toList();
    Widget innerLane = Column(
      children: [
        _LifePanel(
          player: p,
          profile: profile,
          controller: widget.controller,
          epoch: widget.interactionEpoch,
          enabledRules: enabled,
          hiddenUtilities: hidden,
          onOpen: widget.onOpen,
          onChange: (d) => perform(() => widget.controller.adjustLife(p.id, d)),
        ),

        Expanded(
          child: visible.isEmpty
              ? _EmptyLane(
                  icon: Icons.widgets_outlined,
                  text: 'Tools for your game',
                  action: 'Choose utilities',
                  onTap: () => widget.onOpen(WorkspacePage.utilities),
                )
              : DragBoundary(
                  child: ReorderableListView.builder(
                    scrollController: utilityScroll,
                    buildDefaultDragHandles: false,
                    itemCount: visible.length,
                    onReorder: (old, next) => perform(() async {
                      final ids = visible.map((u) => u.id).toList();
                      if (next > old) next--;
                      ids.insert(next, ids.removeAt(old));
                      await widget.board.reorderVisibleUtilities(p.id, ids);
                    }),
                    proxyDecorator: (child, index, animation) =>
                        Material(elevation: 5, child: child),
                    itemBuilder: (context, index) {
                      final u = visible[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(u.id),
                        index: index,
                        enabled: expandedId == null,
                        child: _UtilityRow(
                          utility: u,
                          player: p,
                          board: widget.board,
                          expanded: expandedId == u.id,
                          onExpand: () => expand(u.id),
                          onHide: () => widget.onHide(u),
                          onOpen: () =>
                              widget.onOpen(WorkspacePage.utilities, u.id),
                          onChange: (delta) => perform(
                            () => widget.board.adjustUtility(p.id, u.id, delta),
                          ),
                          onToggle: () => perform(
                            () => widget.board.toggleUtility(p.id, u.id),
                          ),
                          onMana: (mana, delta) => perform(
                            () =>
                                widget.controller.adjustMana(p.id, mana, delta),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
    return RotatedBox(
      quarterTurns: widget.turns,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            if (error != null)
              Container(
                color: Theme.of(context).colorScheme.errorContainer,
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                child: Text(error!, style: const TextStyle(fontSize: 12)),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.tokenLeft) Expanded(flex: 11, child: tokenLane),
                  if (widget.tokenLeft) const VerticalDivider(width: 1),
                  Expanded(flex: 10, child: innerLane),
                  if (!widget.tokenLeft) const VerticalDivider(width: 1),
                  if (!widget.tokenLeft) Expanded(flex: 11, child: tokenLane),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LifePanel extends StatelessWidget {
  final PlayerState player;
  final SeatProfile profile;
  final TableController controller;
  final int epoch, enabledRules, hiddenUtilities;
  final ValueChanged<int> onChange;
  final void Function(WorkspacePage, [String?]) onOpen;
  const _LifePanel({
    required this.player,
    required this.profile,
    required this.controller,
    required this.epoch,
    required this.enabledRules,
    required this.hiddenUtilities,
    required this.onChange,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final color = Color(profile.color);
    final monarch = controller.session.monarchPlayerId == player.id;
    final artColor = profile.artworkUrl != null ? Colors.white : null;
    Widget shortcut(
      IconData icon,
      String label,
      WorkspacePage page, {
      int? count,
    }) => Tooltip(
      message: '${profile.name}, $label',
      child: Semantics(
        label: '${profile.name}, $label${count == null ? '' : ', $count'}',
        button: true,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onOpen(page),
          child: SizedBox(
            height: 40,
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
      ),
    );
    final shortcuts = [
      shortcut(
        Icons.shield_outlined,
        'commander damage',
        WorkspacePage.commanderDamage,
        count: player.commanderDamage.values.fold<int>(0, (a, b) => a + b),
      ),
      shortcut(
        Icons.hexagon_outlined,
        'player counters',
        WorkspacePage.counters,
        count: player.counters.values.fold<int>(0, (a, b) => a + b),
      ),
      shortcut(
        Icons.rule_outlined,
        'rules',
        WorkspacePage.rules,
        count: enabledRules,
      ),
      shortcut(
        Icons.inventory_2_outlined,
        'saved presets',
        WorkspacePage.presets,
      ),
      shortcut(
        Icons.widgets_outlined,
        hiddenUtilities == 0
            ? 'manage utilities'
            : 'manage utilities, $hiddenUtilities hidden',
        WorkspacePage.utilities,
      ),
      shortcut(Icons.more_horiz, 'player menu', WorkspacePage.player),
    ];
    return _ArtworkSurface(
      url: profile.artworkUrl,
      tint: Color.alphaBlend(
        color.withValues(alpha: .19),
        Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    profile.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: artColor ?? color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (monarch)
                  const Tooltip(
                    message: 'The monarch',
                    child: Icon(
                      Icons.workspace_premium,
                      size: 17,
                      color: Color(0xFFE8D391),
                    ),
                  ),
                if (player.citysBlessing)
                  const Tooltip(
                    message: 'City’s blessing',
                    child: Icon(
                      Icons.auto_awesome,
                      size: 17,
                      color: Color(0xFFE8D391),
                    ),
                  ),
                if (player.warnings.isNotEmpty)
                  Tooltip(
                    message: player.warnings.join('\n'),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFB485),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 64,
            child: Row(
              children: [
                _HoldControl(
                  epoch: epoch,
                  label: '${profile.name}, decrease life by one',
                  icon: Icons.remove,
                  onTap: () => onChange(-1),
                  onRepeat: () => onChange(-5),
                ),
                Expanded(
                  child: Semantics(
                    label: '${profile.name}, life ${player.life}',
                    button: true,
                    child: InkWell(
                      onTap: () => onOpen(WorkspacePage.player),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${player.life}',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w300,
                              height: 1,
                              color: artColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _HoldControl(
                  epoch: epoch,
                  label: '${profile.name}, increase life by one',
                  icon: Icons.add,
                  onTap: () => onChange(1),
                  onRepeat: () => onChange(5),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 240 ? 6 : 3;
              return Wrap(
                children: [
                  for (final shortcut in shortcuts)
                    SizedBox(
                      width: constraints.maxWidth / columns,
                      child: shortcut,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LaneHeading extends StatelessWidget {
  final String tooltip, summaryTooltip;
  final int count;
  final VoidCallback onAdd, onSummary;
  const _LaneHeading({
    required this.count,
    required this.tooltip,
    required this.summaryTooltip,
    required this.onAdd,
    required this.onSummary,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: Row(
      children: [
        Tooltip(
          message: summaryTooltip,
          child: Semantics(
            label: '$summaryTooltip, $count token stacks',
            button: true,
            excludeSemantics: true,
            child: InkWell(
              onTap: onSummary,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      const Icon(Icons.style_outlined, size: 18),
                      const SizedBox(width: 7),
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: tooltip,
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 20),
        ),
      ],
    ),
  );
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
  final UtilityState utility;
  final PlayerState player;
  final BoardService board;
  final bool expanded;
  final VoidCallback onExpand, onHide, onOpen, onToggle;
  final ValueChanged<int> onChange;
  final void Function(String, int) onMana;
  const _UtilityRow({
    required this.utility,
    required this.player,
    required this.board,
    required this.expanded,
    required this.onExpand,
    required this.onHide,
    required this.onOpen,
    required this.onChange,
    required this.onToggle,
    required this.onMana,
  });
  @override
  Widget build(BuildContext context) {
    final mana = utility.kind == 'mana_pool' || utility.kind == 'mana';
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
    final hasAction =
        utility.configuration['actionType'] != null ||
        utility.kind.contains('krenko') ||
        utility.kind.contains('rhys') ||
        utility.kind.contains('brudiclad') ||
        [
          'cathars_crusade',
          'academy_manufactor',
          'hare_apparent',
        ].contains(utility.kind);
    final color = utility.artworkUrl == null
        ? Theme.of(context).colorScheme.onSurface
        : Colors.white;
    Widget icon(IconData data, String label, VoidCallback action) => IconButton(
      tooltip: label,
      onPressed: action,
      icon: Icon(data, size: 19, color: color),
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(40, 44),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactStorm =
            utility.kind == 'storm_count' && constraints.maxWidth < 230;
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
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: ColorUtils.gradientForColors(utility.colors),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 0, 6, 4),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: color),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Tooltip(
                                message: utility.name,
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
                                      child: compactStorm
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
                            ),
                            if (mana)
                              icon(Icons.tune, 'Manage ${utility.name}', onOpen)
                            else if (toggle)
                              Switch(
                                value: board.utilityActive(
                                  player.id,
                                  utility.id,
                                ),
                                onChanged: (_) => onToggle(),
                              )
                            else if (!actionOnly) ...[
                              icon(
                                Icons.remove,
                                'Decrease ${utility.name}',
                                () => onChange(-step),
                              ),
                              Semantics(
                                label:
                                    '${utility.name}, ${board.utilityValue(player.id, utility.id)}, set value',
                                button: true,
                                child: InkWell(
                                  onTap: onOpen,
                                  child: SizedBox(
                                    width: 36,
                                    height: 44,
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${board.utilityValue(player.id, utility.id)}',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              icon(
                                Icons.add,
                                'Increase ${utility.name}',
                                () => onChange(step),
                              ),
                            ] else
                              icon(
                                Icons.play_arrow_outlined,
                                'Resolve ${utility.name}',
                                onOpen,
                              ),
                          ],
                        ),
                        if (mana)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Two columns keep both +/- targets usable in the narrow
                              // portrait lane; landscape fits all six colors in two rows.
                              final columns = constraints.maxWidth >= 225
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
                                      height: 48,
                                      child: Material(
                                        color: _manaColor(type),
                                        borderRadius: BorderRadius.circular(5),
                                        clipBehavior: Clip.antiAlias,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Tooltip(
                                                message:
                                                    'Spend ${_manaName(type)} mana; hold to spend ten',
                                                child: Semantics(
                                                  label:
                                                      'Spend one ${_manaName(type)} mana',
                                                  button: true,
                                                  excludeSemantics: true,
                                                  child: InkWell(
                                                    key: ValueKey(
                                                      '${player.id}-mana-$type-spend',
                                                    ),
                                                    onTap: () =>
                                                        onMana(type, -1),
                                                    onLongPress: () =>
                                                        onMana(type, -10),
                                                    child:
                                                        const SizedBox.expand(
                                                          child: Icon(
                                                            Icons.remove,
                                                            color: Colors.white,
                                                            size: 17,
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Tooltip(
                                                message:
                                                    'Add ${_manaName(type)} mana; hold to add ten',
                                                child: Semantics(
                                                  label:
                                                      '${_manaName(type)} mana ${player.mana[type] ?? 0}, add one',
                                                  button: true,
                                                  excludeSemantics: true,
                                                  child: InkWell(
                                                    key: ValueKey(
                                                      '${player.id}-mana-$type-add',
                                                    ),
                                                    onTap: () =>
                                                        onMana(type, 1),
                                                    onLongPress: () =>
                                                        onMana(type, 10),
                                                    child: SizedBox.expand(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Text(
                                                                type,
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                              const Icon(
                                                                Icons.add,
                                                                size: 12,
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                            ],
                                                          ),
                                                          FittedBox(
                                                            fit: BoxFit
                                                                .scaleDown,
                                                            child: Text(
                                                              '${player.mana[type] ?? 0}',
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 18,
                                                                height: 1.1,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        if (expanded) ...[
                          if (compactStorm)
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              icon(
                                Icons.visibility_off_outlined,
                                'Hide ${utility.name}',
                                onHide,
                              ),
                              icon(
                                Icons.open_in_full,
                                '${utility.name}, details and actions',
                                onOpen,
                              ),
                            ],
                          ),
                        ] else if (hasAction && !actionOnly)
                          Align(
                            alignment: Alignment.centerRight,
                            child: icon(
                              Icons.play_arrow_outlined,
                              'Resolve ${utility.name}',
                              onOpen,
                            ),
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
  const _ArtworkSurface({
    this.url,
    this.tint,
    required this.child,
    this.expanded = false,
  });
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: tint ?? Theme.of(context).colorScheme.surfaceContainerLow,
    child: TableArtworkSurface(url: url, expanded: expanded, child: child),
  );
}

class _HoldControl extends StatefulWidget {
  final int epoch;
  final String label;
  final IconData icon;
  final VoidCallback onTap, onRepeat;
  const _HoldControl({
    required this.epoch,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.onRepeat,
  });
  @override
  State<_HoldControl> createState() => _HoldControlState();
}

class _HoldControlState extends State<_HoldControl>
    with WidgetsBindingObserver {
  Timer? repeat;
  void stop() {
    repeat?.cancel();
    repeat = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _HoldControl old) {
    super.didUpdateWidget(old);
    if (old.epoch != widget.epoch) stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) stop();
  }

  @override
  void dispose() {
    stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    button: true,
    excludeSemantics: true,
    onTap: widget.onTap,
    child: GestureDetector(
      onLongPressStart: (_) {
        widget.onRepeat();
        repeat = Timer.periodic(
          const Duration(milliseconds: 300),
          (_) => widget.onRepeat(),
        );
      },
      onLongPressEnd: (_) => stop(),
      onLongPressCancel: stop,
      child: IconButton(
        tooltip: widget.label,
        onPressed: widget.onTap,
        icon: Icon(widget.icon),
        style: IconButton.styleFrom(minimumSize: const Size(48, 64)),
      ),
    ),
  );
}
