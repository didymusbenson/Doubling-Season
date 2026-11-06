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

Combined utility/dice/wipe checks and rendered review are recorded below when
complete. No native-device acceptance, installation, browser approval or
publication is implied by widget-renderer evidence.
