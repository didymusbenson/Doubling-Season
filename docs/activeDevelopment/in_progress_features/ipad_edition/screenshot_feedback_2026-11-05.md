# Tablet screenshot feedback (2026-11-05)

Implemented from the user's annotated IMG_0143–IMG_0150 screenshots. The user
confirmed the list and requested implementation, excluding five/six-player
support. Larger-player-count layout remains research only. This branch continues
`f42112b` and preserves its artwork/reorder and device-system-bar work.

## Changes

- Player-to-player seams are 5 logical pixels with higher-contrast theme ink.
  Shared-control cutouts use the same seam width, including the two-player
  scrolling life rail. Life/token lane dividers remain distinct.
- Settings removes the duplicate Day/Night controls; the shared table control
  still cycles and clears Day/Night. Catalog actions have a 10px gap. About now
  identifies Tripling Table and describes it directly; support copy explains
  the optional badge without changing products or purchases.
- Dice keeps individual minus/plus buttons. Both have 48px minimum targets,
  28px symbols and 8px separation, with filled high-contrast active surfaces.
  Narrow drawers reduce columns rather than shrink targets. Existing holds,
  count limits, dice generation and results are unchanged.
- New game presents 20, 30, 40 and Custom chips. Custom opens a bounded number
  wheel with minus/plus controls, without a keyboard or text field. Values from
  1 to 1,000,000 remain supported and workspace drafts preserve the selection.
- Reset action labels are **Keep seats** and **Reset everything**. Their existing
  behavior is preserved and explained before confirmation: both archive the
  game, preserve saved appearances/setups and reset gameplay; Keep seats retains
  zeroed token entries and utility selections, while Reset everything clears
  live token lanes and restores default utilities.
- Board wipes contains only global actions. The implementation uses Creatures,
  Artifacts, Enchantments, Artifacts & enchantments, Nonland permanents and All
  tokens as the expanded choices. These categories were a design assumption;
  the screenshots did not name the new options.
- The utility picker's Add list hides kinds already visible for that player,
  including renamed instances, and updates after removal/undo. Hidden choices
  can still be re-enabled; another player's selection does not hide an option.
- The Ring displays the cumulative unlocked abilities with exact descriptions
  from the bundled Ring emblem, not the generic helper or stage count. At zero,
  the first ability is previewed as the next temptation. Temptation count and
  optional bearer remain; the existing progression/undo logic is unchanged.

## Wipe semantics and safeguards

All options affect current seats in one durable operation and one History Undo.
Utilities, life, player counters, rules, saved setups and archives remain intact.
Only affected live boards advance their generation. Save failure and stale-board
checks preserve the previous state.

Typed options use the token's card types before its subtype divider, including
multitypes; abilities and subtype text are not card types. Blank legacy type
lines retain the P/T creature fallback. Explicit noncreature types with stale P/T
do not become creatures. Emblems survive typed options; **All tokens** explicitly
includes emblems and lands. Nonland permanents excludes lands and nonpermanent
records. These are board-editing shortcuts, not a Magic rules engine: the UI
reminds players to check protection and other effects before applying a wipe.
Legacy single-seat service operations remain for compatibility and historical
callers, but player-specific wipe buttons are removed from the game UI.

## Validation

- Scoped dice tests: 49 passed, including light/dark contrast, 48px targets,
  narrow/wide layouts, holds and result behavior.
- Scoped Ring/picker tests: 11 passed.
- Expanded and existing global-wipe service tests: 32 passed, including type
  matching, current-game scope, durable one-step undo and failed-save rollback.
- Rendered widget-test screenshots of Settings, preset/custom New game, global
  wipes and Dice were inspected. These are Flutter-renderer evidence, not
  browser/native screenshots.
- Final aggregate analyzer/tests/release web build are being checked before the
  final validation checkpoint. The browser smoke selectors were updated for the
  new labels, dial and global-only menu; live browser execution is not claimed.

Native iPad/Android installation and acceptance are still required. In particular,
check the wheel's touch feel, the divider over real artwork, rotated/narrow
layouts, Ring readability and repeated dice holds. No deployment, Firebase App
Distribution upload, store action or default-branch merge is part of this batch.
