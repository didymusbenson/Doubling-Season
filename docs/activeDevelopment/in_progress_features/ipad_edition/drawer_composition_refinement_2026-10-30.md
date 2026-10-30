# Drawer composition and commander alignment refinement

## Visual review before changes

This refinement starts from delivered PR58/main
`74abf76eff07ad50962ef4ed3c58c30b3afb4652`. The supplied annotated iPad
screenshot and three Lifetap reference images were materialized privately on
the verified Mac and their actual pixels reviewed. Existing release-browser
captures and fresh baseline views were also reviewed by workflow and visual
reviewers before changing the affected layouts.

The open Menu handle was on the left, contrary to the requested right edge.
Its six fixed-width buttons were aligned near the channel's upper-left corner,
leaving unequal horizontal margins and a large unused area below. The same
top-heavy treatment affected short dice results, empty states and confirmation
pages. Wipe actions wrapped beneath player names without a clear scope group;
New game choices and reset actions had inconsistent widths. Long History,
archive and Settings content needs readable, top-first scrolling rather than
the compact-page centering policy.

The life-chip counter summary was already absent when empty. The remaining
commander displacement came from the ledger's unconditional left inset. This
requires correcting the actual ledger rectangle, not hiding another widget or
asserting only that a summary is absent. The Lifetap references inform compact
art/icon groups and active-only summaries; their tabs and instructional text
are not adopted.

## Implemented behavior and constraints

- Menu travels intact to the right wall. Dice stays on the left edge and
  Day/Night on the right, with the opposite semicircle clearance preserved.
  Opening, bounce, reversal and closing must retain distinct targets. Token
  dismissal consumes the tap; stationary token content and underlying sliding
  rails retain their existing state.
- Each game page has a deliberate content envelope. Short menus, forms, dice
  groups, confirmations and empty states balance their natural content in the
  available area. Long lists remain scroll-first. Body gutters clear the
  overhanging handle and curved wall even while content scrolls past them.
  Headers, spacing, action sizes and hierarchy are consistent without a fixed
  percentage modal, generic stretched column or new navigation tabs.
- A counter-free ledger centers in the life panel's local coordinates. Only
  nonzero counters or active statuses contribute summary width and spacing;
  an active compact ledger/summary group centers together. Placement and ink
  exclusions continue using the same rectangles. Life gestures remain full
  rectangular hit regions outside the overlays' own actions.

Preserve partners, seat rotations, pending life receipts, hold feedback,
save-failure recovery, History undo, game data and accessibility. No tooltips,
routine success notices, release-version edits, schema/OTA changes, signing
changes or excluded `AGENTS.md` edits belong in this batch.

## Validation record

Local analysis is clean and the full suite passes **994 tests with 5 intentional
skips**. The review caught a widened standalone Dice layout outside the drawer;
its original constraints were restored and its existing interaction/fit tests
pass. Legacy selectors were migrated to the actual accessible actions without
weakening save, undo or hit-target assertions.

The browser checks include every game route and nested confirmation in both
tablet orientations, a dense 23-die result, six drawer animation/layout cases,
actual icon/text pixels, and life-overlay geometry. The first complete visual
pass confirmed balanced embedded layouts; the corrected release artifact and
exact-head CI remain the publication gates recorded in the pull request.

Regression evidence includes actual centered geometry
with no/one/multiple/status-only counters and removal of the last active item;
partners and all rendered seat rotations; 2/3/4-player portrait/landscape;
drawer start/middle/end/reversal; all game pages with short and dense content;
large text and long names; actual browser screenshots; full analysis/tests and
platform/browser CI. Release installation and launch are verified separately.
An optional backup failure does not require a destructive reinstall or prevent
an authorized in-place update. Automated evidence does not establish hands-on
physical responsiveness.
