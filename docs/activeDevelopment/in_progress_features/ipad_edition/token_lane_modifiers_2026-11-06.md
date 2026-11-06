# Player-lane controls, 2026-11-06

## Request and behavior

Move token modifiers into each player's token lane, like the original app.
The calculator now sits at the local bottom-left alongside Summary, Start turn
and Add token. It opens the existing player-facing Rules panel. Wider lanes show
Rules or a simple creature-token multiplier preview; narrow seats retain the
calculator icon and its full accessible name. An active dot includes applicable
foreign global effects. Custom and companion-token effects show Rules rather
than implying a single multiplier. Capped results also show Rules.

All existing modifier storage, source ownership, global applicability, command
history and undo behavior remain unchanged. Switching Tokens/Utilities hides the
calculator with its own lane and retains all player state. Opposite seats retain
player-local control order and editor orientation. The phone presentation keeps
its separate More-menu action.

The parallel utility change moves Utilities/Player customization into one
utility-lane FAB. The old row under life is removed entirely. Utility scroll
clearance follows each seat's rotation, and the compact reorder mode hides the
FAB so Done and drag targets remain accessible. Its inset contracts only at the
minimum seat height to retain the full 48px target.

## Verification

Initial modifier-only checks passed Flutter analysis and 21 targeted widget
regressions covering 2–6 players at 650×480, 1133×744 and 1700×1100, token-tab
retention, rotated editor ownership, global-source previews, trailing scroll
clearance, repeated open/close and tapaway without click-through. Minimum-height
local views can scroll completely into trailing padding; tests do not assume an
offscreen virtualized token remains mounted.

Final combined validation at `53d5473f61a63143c6370b30618cb6a763133369`:

- Flutter 3.41.2 analysis: no issues.
- Full tablet suite: 1,331 passed, 7 opt-in skips.
- Release web build with the existing tablet base href and no service worker:
  passed, including the Wasm dry run.
- Eight font-loaded renderer scenarios for four/six players across minimum,
  portrait and wide split views passed. Reviewed the normal four-player board,
  six-player token views, and the minimum-size utility controls. Screenshots are
  under `/tmp/combined-lane-captures/` on the validating Mac.
- Independent dice/wipe review confirmed OR-category union, Set to 0 retention
  of stack IDs/artwork/counters/metadata, and one durable global undo, including
  reopening persisted state.

The combined pass also caught and fixed a transient narrow split lane during
pointer cancellation and a bounded utility auto-scroll edge case. The standard
utility list now uses the same 4px external viewport gutters as compact reorder,
so its drag proxy remains seat-bounded while reaching first/last insertion slots.

Widget-renderer evidence is not browser or native-device acceptance. No device
installation or distribution was performed as part of this validation.
