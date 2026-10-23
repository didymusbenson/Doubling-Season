# Tablet Utilities tool placement (2026-10-23)

User correction: Manage Utilities belongs with the tools below the life chip,
not inside Storm or any other utility row.

- Move the existing action into life tools immediately before Edit.
- Keep six full-size tools in one row where they fit, otherwise balanced rows
  of three. Monarch and City's Blessing remain adjacent; Edit stays last.
- Commander mini-tracker remains inside the life chip. No state or gesture
  handlers, lane proportions, orientations, or original app source changed.
- Short empty utility lanes show a directly tappable chooser without decorative
  empty-state content. Populated utility rows retain full-size controls and
  scroll when needed. Mini-landscape 3/4-seat default utilities need 73.5px
  scrolling (bounded at 80px in regression), rather than shrinking life/tools.

Validation covers player-local tool ordering, separation from utility rows,
opening/closing Utilities from both orientations, legacy/custom utility data,
2/3/4-seat layout and full-size mana targets, commander gestures and undo.
Real-font Flutter renderer captures use the existing commander-chip capture
fixture with normal40 life, empty/single/partner sources, mini/large portrait
and landscape. Full tablet tests, analyzer, release web build, Android/iPad CI,
and combined Pages publication are checked before completion. This is not a
native hands-on claim.
