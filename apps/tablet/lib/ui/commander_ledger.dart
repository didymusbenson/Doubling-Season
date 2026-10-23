import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/table_state.dart';
import '../state/table_controller.dart';
import 'table_artwork.dart';

/// Read-only source overview; the whole mini-grid opens the expanded grid.
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
    final sources = controller.session.commanders;
    final entries = sources.isEmpty
        ? controller.session.players
              .map(
                (p) => (
                  id: p.id,
                  owner: p,
                  label:
                      '${controller.profile(p.seatId).name}, no commander configured',
                  value: p.id == recipient.id ? 'me' : '0',
                ),
              )
              .toList()
        : sources
              .map(
                (s) => (
                  id: s.id,
                  owner: controller.player(s.ownerPlayerId),
                  label:
                      '${s.name} (${controller.profile(controller.player(s.ownerPlayerId).seatId).name})',
                  value: '${recipient.commanderDamage[s.id] ?? 0}',
                ),
              )
              .toList();
    final columns = math.max(2, (entries.length / 2).ceil());
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
            value: entries.map((e) => '${e.label}: ${e.value}').join('; '),
            hint:
                'Expand source trackers${sources.isEmpty ? ' and configure commanders' : ''}',
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
                        for (final entry in entries)
                          SizedBox(
                            key: ValueKey(
                              '${recipient.id}-ledger-source-${entry.id}',
                            ),
                            width: width / columns,
                            height: 22,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(
                                  controller.profile(entry.owner.seatId).color,
                                ).withValues(alpha: .22),
                                border: Border.all(
                                  color: Color(
                                    controller
                                        .profile(entry.owner.seatId)
                                        .color,
                                  ),
                                ),
                              ),
                              child: TableArtworkSurface(
                                url: controller
                                    .profile(entry.owner.seatId)
                                    .artworkUrl,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      entry.value,
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
        );
      },
    );
  }
}
