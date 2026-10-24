import 'package:flutter/material.dart';
import '../domain/table_state.dart';
import '../state/table_controller.dart';
import 'table_artwork.dart';

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
                    child: Wrap(
                      children: [
                        for (final owner in owners)
                          SizedBox(
                            key: ValueKey(
                              '${recipient.id}-ledger-owner-${owner.id}',
                            ),
                            width: width / 2,
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
                                          controller
                                              .profile(owner.seatId)
                                              .color,
                                        ).withValues(alpha: .22),
                                        border: Border.all(
                                          color: Color(
                                            controller
                                                .profile(owner.seatId)
                                                .color,
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
                      ],
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
