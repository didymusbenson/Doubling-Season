# Attached controls and two-player drawer follow-up

The 2026-10-30 feedback follows PR59. This batch keeps the existing game drawer
and direct gameplay controls, while correcting five concrete visual/interaction
defects. It does not change release versions, persisted schemas, OTA data,
signing, or the original application's behavior.

## Findings before editing

- The board mask removes the rectangular drawer opening plus its circular wall
  clearances, but the workspace only paints inside the rectangle. The exposed
  half-circles therefore show the Scaffold color, which deliberately differs
  from the drawer surface in both light and dark themes.
- Short drawer content is centered independently of Back/Close at the viewport
  top. Header and body need to size and center as one group, with the header
  remaining above a bounded scrolling body when that group fills the viewport.
- The four supported player counters already have zero defaults and nonnegative
  adjustment rules. The editor currently hides those defaults behind Add counter.
  Existing saved custom/legacy keys must remain editable without rewriting maps
  merely by opening the editor. Only nonzero numeric values belong on the life
  summary; active status badges retain their independent presence rules.
- Commander tile owner names occupy a separate header above the two stepper
  halves. The visual name must belong to the same full-height tap/hold surface.
- The actual two-player screenshot shows a 480px vertical drawer crossing wide
  token lanes: about 392px of a 906px card is obscured. A separate stale 30px
  hub-clearance padding pushes the first token row away from each local top edge,
  although lane controls are already positioned as bottom overlays. Reversing
  the existing drawer direction alone cannot eliminate that intersection.

## Implementation and verification scope

The exposed drawer shape and its themed backing share geometry, without changing
hit regions. Navigation belongs directly above the content group. Player counter
stepper chips sit beneath the status chips, including supported zero values and
any existing custom entries; commander names are inside each full tile stepper.

Two-player mode uses a separate horizontal seam reveal with full-width seat rows
and unchanged token card widths. Normal vertical token scrolling must keep
expanded/multiple cards accessible. The stale top reservation is removed;
controls continue to overlay their lanes. Three/four-player vertical reveals
retain their existing behavior. This supersedes earlier notes/tests that treated
two-player token clipping as intentional.

Review also caught and corrected three integration cases: numeric counter
correction now appears beside the selected row and scrolls into view; two-player
warning text and acknowledgement stay clear of the life-side shared controls;
and utility scroll offsets survive viewport/presentation changes. Warning-only
clearance never introduces padding in normal token rows. Life-corner notches
follow the actual control placement when a warning is present.

Required final evidence includes both themes, 2/3/4 players, portrait/landscape,
rotated seats, intermediate/settled/reversed drawer frames, first-row and scroll
geometry, large text, short and long routes, counter zero/nonzero transitions,
legacy maps, name/edge coordinate taps, holds, partners, and failure/History
behavior. Browser checks, platform CI, and physical installation/launch are
recorded separately; none alone establish hands-on touch responsiveness.

Validation results are recorded in the associated pull request and private
delivery receipts, including the exact tested source and deployed commit.
