# Utility visibility and player tools — 2026-11-06

The utility menu now has one alphabetical searchable list. Its switches mean
shown/hidden on the initiating player's board. Hiding/restoring uses the existing
instance and preserves its ID, values, artwork, settings and Ring progression.
Missing definitions are instantiated only on the first activation. Custom and
imported duplicate instances retain independent controls. Legacy metadata stays
available in its collapsed settings section without duplicate gameplay controls.

The UX review identified the former search field sharing dismissal-button space
and search filtering only the separate Add list. The new heading reserves the
close/back corner; the search field gets a separate full-width row and 12px gap.
Edit is a separate 48px action outside each switch's merged semantics.

Utilities and Player customization move from the row under life into an oriented
player-tools menu opened by a FAB inside the Utilities area. Token modifiers are
being moved independently to the token lane in the companion branch. Scroll
clearance keeps the last utility reachable above the FAB.

The Ring board presentation omits its temptation count and labels its existing
action Next temptation. Numbered cumulative ability reminders and internal
progress/history/persistence remain intact, including further temptations after
all four abilities have unlocked. Manual correction remains in its details.

Validation is in progress. Native acceptance and installation are not implied.

## Focused verification

On Flutter 3.41.2 / Dart 3.11.0, analysis is clean and the 30 focused picker,
Ring, utility-detail and silent-success regressions pass. They cover exact
hidden/restored payloads, reload, independent seats and duplicate instances,
failed saves, renamed/catalog search, stage progression beyond four, and
320x700 at 1.5x text plus 744x1133 / 1133x744 layouts. Rendered checks at those
three sizes confirmed search/heading separation. Narrow edit actions move below
the switch row to retain readable labels. The utility FAB has a 48px target.
Combined board/FAB and modifier regression validation is owned by the companion
integration branch; this focused result is not a full-suite or native acceptance.
