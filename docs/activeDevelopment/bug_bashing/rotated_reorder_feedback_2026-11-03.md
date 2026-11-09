# Rotated-seat reorder feedback — 2026-11-03

## Report and reproduction

The user reported that dragging a Player 2 token turned it upside down and made
it appear detached from that player's list, even when its final order was right.
The actual release web UI reproduced the flip and pointer jump with a catalog
Zombie in the four-player layout. Before/after captures use real rendered UI,
not mockups. The preceding P/T backplate fix remains in commit `7dae884`.

## Cause

The tablet lists lived beneath the seat's `RotatedBox`, but their lifted drag
proxies contained only a `Material` wrapper. Moving the row into Flutter's
screen overlay lost its ancestor rotation. Flutter 3.41.2's `_DragInfo` also
records a local grab offset and subtracts it from a global pointer position;
its target rectangles and drag axis assume screen-oriented list geometry.
Adding rotation to the proxy alone would leave the pointer offset incorrect.

The unchanged baseline regression measured a Player 2 grab-point error of
275.4 pixels (268.72 horizontal), and its text's x basis flipped from -10 to +10.
The issue also applied to the normal and compact utility reorder lists.

## Fix and preserved behavior

The reorder viewport cancels the outer seat rotation, while each row carries
that rotation inside its keyed drag listener. Flutter now measures the viewport
and proxy in the same screen coordinates, and the lifted row retains the
player-facing orientation. Half-turn seats use the existing list's `reverse`
behavior; token trailing padding moves from physical bottom to top so its
player-local clearance is unchanged.

This covers all active seat orientations: upright and half-turn, including
Player 2 in two-player mode and Players 2/3 in four-player mode. The change
does not introduce new seat orientations. Short-footer ordinary utility lists
remain seat-local; their separate compact reorder viewport gets the correction.
Indices, ordering services, scroll controllers, keys, bounds, undo, inline
editing, native phone keyboards and utility swipe removal remain intact.

The related phone utility drag check exposed a pre-existing missing `Material`
ancestor when its row entered the overlay. A matching proxy wrapper fixes that
exception. Phone token orientation requires no change. The original root app's
board is unrotated; its token/utility components were reviewed and do not need
the tablet seat adapter.

## Verification

`reorder_rotation_regression_test.dart` adds 17 cases covering all four seats,
two-player Player 2, phone tokens/utilities, and compact utility reorder. The
tests check oriented basis vectors, an off-center grab point, bounds, continuous
drags in both directions, persisted order and unchanged payloads/other seats,
undo, and utility autoscroll. Existing presentation tests cover cancellation
during folding. All 17 cases pass with default and real UI fonts; 10 reproduce
the old failures on `7dae884` (nine rotated cases and phone utility Material).

The fixed grab-point error is below `6e-14` pixels across 32 captured geometry
checks; 30 endpoint checks remain within bounds. Actual browser checks also
confirm forward/backward token swaps and exact pointer tracking for all four
seats, plus phone token and utility swaps. Layout assertions retain the same
sizes with a 0.001-pixel numerical tolerance and check trailing clearance in
player-local order.

Evidence is under
`/Users/didymusbenson/Documents/Codex/2026-10-30/task-4/verification/drag-rotation-2026-11-03/`:
`geometry-summary.json`, `before/`, `after/`, `browser/`, and validation logs.
The local release web build succeeds. The full tablet suite passes 1,148 tests
with 7 existing skips, and the analyzer reports no issues. Independent code
review found no remaining defect. Physical-device acceptance is not claimed: no device install,
signing change, main merge, Firebase/store upload or preview deployment was
performed for this fix.
