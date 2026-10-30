# Game drawer, life ink and tooltip removal

## Requested behavior

The supplied mockup represents the center channel midway through opening.
Game workflows (dice, history, archives, board wipes, new game and settings)
belong in that channel. The life and utility rails slide outward below stationary
token content. The Menu button stays whole, travels with a wall and overhangs its
edge; the opposite wall provides matching circular clearance. Menu or a token
area closes the drawer, consuming that dismissal tap. Player and token editors
remain their existing focused dialogs.

Life feedback must remain visible over the life surface but must not paint
through translucent commander/counter summaries. Exclusions affect ink paint
only; rectangular tap regions, numeric holds, immediate receipts, durable saves,
failure rollback and History retain their behavior.

Tablet controls no longer show hover or hold tooltips. Accessible names, values,
states and actions remain explicit. Selection/Paste menus, real errors and
functional holds are distinct from tooltips and remain available. Routine
success notifications are still prohibited.

## Implementation

The opening animation uses a 320 ms back curve with a small overshoot; closing
uses a 220 ms ease. The channel sits behind the board, and the life/utility rails
translate beneath the stationary token layer. Its contents are the shared
workspace workflows, embedded with their existing save, error, draft and History
behavior. Drawer navigation has a local Back stack; it does not launch the old
game dialogs. Settings also embeds support content.

The original two-seat vertical reveal clipped the inner edge of its wide token
lanes. That behavior was rejected in subsequent feedback and is superseded by
the [horizontal two-player reveal](attached_controls_and_two_player_reveal_2026-10-30.md),
which retains full token widths inside deliberately resized seat viewports.
The three/four-seat token lanes remain stationary. The dismissal layer blocks token input
and accessibility actions while the drawer is open, consuming the closing tap.
Its semantic bounds use the visible token rectangle so web accessibility targets
cannot intercept drawer actions. The unused seat's old controls fade away while
the channel is open. Stable board/layer keys retain pending life receipts, save
warnings, token expansion and scroll position across opening and closing.

Life overlay rectangles now control both overlay placement and the stepper's
ink-only border exclusions. Hover, focus and splash paint share that geometry;
gesture bounds remain rectangular. Counter-free layouts allocate no extra hole.
Tooltip labels have become explicit semantics, with a root visibility guard
above the Navigator for framework-provided tooltips.

## Scope and validation

This batch begins from published main `f07eb65e9577129394bc4f8d2b20c39b6a63d9a1`.
It does not change release versions, stored schemas, OTA data, signing settings
or the original app. The published `AGENTS.md` is retained unchanged.

Validation includes meaningful widget/semantics/pixel checks, full tablet
analysis/tests, release Chrome interaction/rendering, iOS simulator compilation,
exact-commit CI and combined Pages deployment verification. Physical installation
and hands-on acceptance are recorded separately from automated evidence.

The regression coverage includes paint-only life exclusions for splash, hover
and focus; retained rectangular gesture bounds; tooltip-free holds and Paste;
named accessibility actions; 16 repeated animated openings with actual painted
text pixels; 2/3/4-player portrait/landscape geometry; save failure/pending-save
retention; drawer-local workflows and History undo; token dismissal without
click-through; and board expansion/scroll preservation. The release-browser
check uses a temporary profile and real UI input, including all six seat-count /
orientation cases and live accessibility trees during closing. It also checks
pixels independently of accessibility text.

Initial validation found and corrected a duplicate dismissal action, a two-seat
semantic rectangle extending into the channel, and board state being recreated
when an unkeyed drawer layer was inserted. Tests reproduce those failures before
the fixes. Intermittently blank-looking image previews were checked against the
actual PNG bytes; all labels were present, so no speculative repaint change was
made. Native responsiveness, picker and Paste acceptance require hands-on
testing and are not established by these automated checks.

Local checkpoint results: **971 tests passed, 5 intentional skips**, clean
analysis and a successful release web build. The complete release-browser pass
on the state-preserving drawer completed in 110.250 seconds with all six layout
cases and no runtime exceptions. The final empty-seat visual refinement passed a
fresh three-player portrait/landscape probe in 9.515 seconds, including actual
label pixels and dismissal hit targets. The default CI browser command always
runs the complete suite; the optional seat-count probe is diagnostic only.
