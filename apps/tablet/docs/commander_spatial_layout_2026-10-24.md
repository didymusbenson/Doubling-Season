# Commander spatial seat correction — October 24, 2026

Both the 44px life-chip miniature and expanded damage controls use the same
`CommanderSeatLayout`. The four physical table slots are `[1, 2] / [0, 3]`.
The layout compensates for the initiating player's rotation before the parent
rotates the surface, so opening the popup preserves every source owner's
physical position. Three-player games keep their actual empty table slot.
Two-player tables use the same opposite-seat arrangement as the board, rather
than treating their stored slot numbers as a four-seat table. Configured
partners subdivide their owner's cell; the self-source stays visible.

This changes presentation only. Source IDs, default sources, source metadata,
seat state, damage commands, chronological history and atomic life/damage undo
remain on their existing paths. Opening the popup does not create setup or
history. Popup sizing counts actual spatial rows, including two-player tables.

Validation:

- 37 new spatial tests passed, including self-damage, atomic life changes and undo:
  every initiating seat in portrait/landscape, each possible three-player empty
  slot, partner containment, and all quarter-turn transforms.
- Existing commander direct-interaction and life-chip suites: 43 passed,
  including delayed-save/close, failure recovery, holds and source editing.
- Native pixel acceptance is owned by the integrating executor; widget geometry
  tests do not establish native acceptance.
