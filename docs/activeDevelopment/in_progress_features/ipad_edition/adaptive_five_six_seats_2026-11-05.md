# Five/six players and player-local views

Date: 2026-11-05. Feature branch: `feat/adaptive-five-six-seats-20261105`.
Base: `fix/tablet-feedback-20261105` at `76e216e`.

## Accepted direction

The user selected mockup option 3, Switch local view: life stays visible while
each player chooses Tokens or Utilities. This is a response to the usable space
of a seat, not a special six-player mode. Five players use three seats on one
long edge and two wider seats on the other; the wider side retains both lanes
when they fit. The same rule applies to small four-player layouts. Thresholds
are an initial implementation choice and remain open to native tablet tuning.

## Implementation

- New game supports two through six players. Five/six add the middle slots,
  preserving the original corner meanings: top `[1, 5, 2]`, bottom `[0, 4, 3]`.
  Five omits top-middle slot 5 and expands the top pair. The upper edge faces
  180 degrees; the lower edge faces 0 degrees. Shared row/turn helpers also
  govern commander layouts.
- `SeatLayoutPolicy.minimumSplitWidth` is 520 logical pixels per seat. Accessible
  text scale increases that requirement, capped at 1.4 times the base width.
  This decision uses actual seat width after player dividers, not player count.
  At 1133px, five has a split two-seat edge and a tabbed three-seat edge. At
  sufficiently wide widths, even all six seats can use the unchanged 60/40 split.
- Compact seats retain a 136px life region and 44px local view selector. Tools
  appear at the top of Utilities; token actions stay in the Tokens view. Each
  view keeps its scroll position, and the token subtree stays mounted across
  tab/width changes to retain inline expansion and recovery drafts. Selection is
  transient per-seat presentation state, not a saved gameplay/history command.
- Short Utilities viewports retain the existing scrollable tools and dedicated
  compact reorder mode. Save warnings have bounded text and an exceptional
  scrollable local layout so the complete life surface and full-size actions
  remain reachable instead of overflowing.
- View changes, geometry/text-size changes, input locks and lifecycle interruption
  cancel active seat pointers/holds. Hidden content is noninteractive and excluded
  from accessibility traversal. Reorder proxies still face their player.
- The shared drawer uses the horizontal seam for five/six and narrow layouts.
  Wide three/four layouts keep their existing vertical life-rail reveal. Shared
  circles receive actual per-seat life cutouts and internal token-content clearance
  where the middle-seat token lane intersects the hub; artwork stays flush.
- Commander views support ten/twelve sources with partners, per-row sizing,
  player-facing spatial mapping and the same coupled life/damage/undo commands.
  Five/six life ledgers use up to 120px when available.
- Saved-state validation accepts two to six players. Old four-profile saves are
  unchanged on load; Player 5/6 profiles are appended in the durable reset draft
  only when needed. Shrinking retains hidden profiles; reset/archive/restore
  retain identity. No schema, Hive box or phone-provider changes are made.

## Validation record

- Full tablet regression suite: final clean aggregate pending. Earlier late
  failures were stale narrow-layout test expectations; both affected files
  passed all 51 tests after selecting the intended local view and using the
  revised toolbar geometry. Production source was unchanged for that correction.
- `flutter analyze --no-pub`: passed with no issues.
- `git diff --check`: passed.
- Final release web build with `/Doubling-Season/tablet/` base href and
  `--pwa-strategy=none`: passed; Wasm dry run also succeeded.
- Rendered Flutter checks cover four/five/six seats at 1133×744, 744×1133,
  650×480 and 1700×1100. Captures were visually inspected. They verify the mixed
  five-player arrangement, six-player local views, player-facing text, full-size
  controls and shared drawer placement. Wide middle-seat token clearance was
  additionally checked at 1920×1080.
- New focused regressions cover independent local selection, no history from
  switching, retained scroll/token editor identity, all twelve partner sources,
  coupled damage/undo, reopen/archive/reset, failed-save recovery, active holds,
  and reorder cancellation during tab, text-size and extreme window changes.
- The repeatable `tool/browser_adaptive_seats_smoke.mjs` uses real UI actions,
  a fresh profile and either local or Pages base paths. Its syntax and seven
  base-path parser cases passed. Live browser execution was blocked before page
  load because this workspace prevents Chromium's required Unix sockets.
  No live-browser pass or screenshots are claimed.
- No pull request was opened, so the pull-request-only native CI workflow did
  not run. Android/iPad builds are not established by the web build.

Native iPad/Android hands-on acceptance and threshold tuning are separate.
No device install, Firebase App Distribution, store release or Pages publication
is part of this feature-branch checkpoint.
