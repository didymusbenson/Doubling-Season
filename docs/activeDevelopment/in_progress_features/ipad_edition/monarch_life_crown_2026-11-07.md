# Monarch wears the life total — 2026-11-07

## Request and implementation

Move Monarch out of the small counter/status summary and let the life total
wear a crown, following the user's annotated four-player reference.

- A tilted, gold vector crown sits on the upper-left of the fitted life total.
  It scales with the number and inherits the player's orientation. The name
  uses the upper-right space while crowned; the life number keeps its exact
  size and position.
- The crown fades/scales in once when claimed. Reduced-motion mode shows it
  immediately. There is no looping animation.
- The crown is decorative inside the existing ignored-pointer life display.
  Tapping it still adjusts life through the same left/right hit region.
  Monarch is included in the accessible life value.
- The duplicate Monarch badge is removed from the summary. City's Blessing,
  Initiative, and nonzero player counters keep their existing behavior. If
  Monarch is the only status, the commander ledger centers on its own again.
- Claim, transfer, clear/hold-to-clear, History, persistence, and undo still use
  the existing Monarch command in Commander damage/player counters. The
  commander ledger remains the route into these controls.
- No phone/root-app widgets, game model, storage keys, app version, signing,
  installation, or distribution settings changed.

## Validation

Passed on the isolated `feat/monarch-life-crown-20261107` worktree:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: **1,421 passed, 7 existing skips**.
- Dedicated rendered crown matrix: **33 tests passed**, using real fonts.
  Populated 2–6-player layouts cover 1133×744, 744×1133, and 1366×1024,
  both light/dark themes, and a claim on every seat.
- The matrix checks stable number bounds, crown/name/ledger separation, single
  ownership, life taps through the crown, status navigation, and closing the
  editor without a life change.
- Separate regressions cover Monarch-only summary removal, centered ledger,
  hold-to-clear, undo and serialized restore, failed-save rollback, negative and
  long totals, artwork, 150% text scale, reduced motion, and all quarter turns
  at 768×1024.
- Rendered images were inspected at four-player landscape, six-player portrait,
  and long signed artwork totals. Independent code/visual review found no
  concrete bugs or visually significant issues.
- `flutter build web --release --base-href /Doubling-Season/tablet/
  --pwa-strategy=none`: passed. No deployment was performed.

These are widget-rendered previews and automated/build checks, not native
hands-on acceptance. No device install or Firebase distribution was requested
or performed. CI runs only for pull requests/manual dispatch, so a pushed
feature branch alone does not trigger that workflow.
