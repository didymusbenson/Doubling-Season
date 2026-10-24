import 'package:flutter/material.dart';
import '../domain/table_state.dart';
import '../state/table_controller.dart';
import 'table_artwork.dart';

/// The table's physical seat positions, expressed in the initiating player's
/// local coordinates. Empty positions remain empty and partners stay inside an
/// owner's position rather than becoming extra seats.
class CommanderSeatLayout extends StatelessWidget {
  final List<PlayerState> players;
  final int quarterTurns;
  final Widget Function(PlayerState owner) ownerBuilder;
  final double spacing;
  final double runSpacing;
  final double? rowHeight;

  const CommanderSeatLayout({
    super.key,
    required this.players,
    required this.quarterTurns,
    required this.ownerBuilder,
    this.spacing = 0,
    this.runSpacing = 0,
    this.rowHeight,
  });

  static int turnsForPlayer(List<PlayerState> players, PlayerState player) =>
      players.length == 2
      ? (players.indexWhere((p) => p.id == player.id) == 0 ? 0 : 2)
      : (player.slot == 1 || player.slot == 2 ? 2 : 0);

  static List<List<PlayerState?>> rowsFor(
    List<PlayerState> players,
    int quarterTurns,
  ) {
    final turns = quarterTurns % 4;
    if (players.length == 2) {
      final bottom = players.first;
      final top = players.last;
      return switch (turns) {
        1 => [
          [top, bottom],
        ],
        2 => [
          [bottom],
          [top],
        ],
        3 => [
          [bottom, top],
        ],
        _ => [
          [top],
          [bottom],
        ],
      };
    }
    PlayerState? at(int slot) =>
        players.where((p) => p.slot == slot).firstOrNull;
    final slots = switch (turns) {
      1 => [
        [2, 3],
        [1, 0],
      ],
      2 => [
        [3, 0],
        [2, 1],
      ],
      3 => [
        [0, 1],
        [3, 2],
      ],
      _ => [
        [1, 2],
        [0, 3],
      ],
    };
    return [
      for (final row in slots) [for (final slot in row) at(slot)],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = rowsFor(players, quarterTurns);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: runSpacing),
          SizedBox(
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < rows[r].length; col++) ...[
                  if (col > 0) SizedBox(width: spacing),
                  Expanded(
                    child: rows[r][col] == null
                        ? const SizedBox.shrink()
                        : ownerBuilder(rows[r][col]!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Stable owner slots, with partners subdividing their owner's slot.
class CommanderLedger extends StatelessWidget {
  final TableController controller;
  final PlayerState recipient;
  final VoidCallback onOpen;
  const CommanderLedger({
    super.key,
    required this.controller,
    required this.recipient,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final sources = controller.session.commanderTrackingSources;
    final owners = controller.session.players;
    final name = controller.profile(recipient.seatId).name;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 68.0;
        return Tooltip(
          message: '$name, commander damage',
          child: Semantics(
            button: true,
            label: '$name, commander damage by source',
            value: sources
                .map(
                  (s) =>
                      '${controller.profile(controller.player(s.ownerPlayerId).seatId).name}, ${s.name}: ${recipient.commanderDamage[s.id] ?? 0}',
                )
                .join('; '),
            hint: 'Expand source trackers',
            onTap: onOpen,
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onOpen,
                child: SizedBox(
                  width: width,
                  height: 44,
                  child: IgnorePointer(
                    child: CommanderSeatLayout(
                      players: owners,
                      quarterTurns: CommanderSeatLayout.turnsForPlayer(
                        owners,
                        recipient,
                      ),
                      rowHeight: 22,
                      ownerBuilder: (owner) => SizedBox(
                        key: ValueKey(
                          '${recipient.id}-ledger-owner-${owner.id}',
                        ),
                        height: 22,
                        child: Row(
                          children: [
                            for (final source in sources.where(
                              (s) => s.ownerPlayerId == owner.id,
                            ))
                              Expanded(
                                child: Container(
                                  key: ValueKey(
                                    '${recipient.id}-ledger-source-${source.id}',
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      controller.profile(owner.seatId).color,
                                    ).withValues(alpha: .22),
                                    border: Border.all(
                                      color: Color(
                                        controller.profile(owner.seatId).color,
                                      ),
                                    ),
                                  ),
                                  child: TableArtworkSurface(
                                    url: controller
                                        .profile(owner.seatId)
                                        .artworkUrl,
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          owner.id == recipient.id &&
                                                  (recipient.commanderDamage[source
                                                              .id] ??
                                                          0) ==
                                                      0
                                              ? 'me'
                                              : '${recipient.commanderDamage[source.id] ?? 0}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
