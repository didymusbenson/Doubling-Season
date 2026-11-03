# Phone mode — feature-branch implementation

Status: **WIP, not validated or released.** Branch: `feature/phone-mode`.

## Explicit direction

Fixed Player 1 of the N-player session. Fixed compact life above one scrolling
utilities-then-tokens body. Approved option C means direct Add Token, Utilities
jump and More. No generated concept image is used as design context or committed.
Tablets retain full-table presentation, phones compact; folding dismisses menus
and modals while preserving the complete session. Keep separate Table identity
until a later deliberate original-product cutover. Do not merge this feature into
stable main merely because a checkpoint builds.

## Current implementation and independent judgments

- Added a presentation-only host; it does not reset a game or alter player count.
  Physical display size, not a narrow tablet window, chooses native compact mode.
  Web compact preview requires an explicit build define. Threshold is provisional
  and requires foldable/native validation; hardware posture accuracy is not proven.
- Reuses actual Table token cards, utility controls, commander editor and command
  model. No generated-image token layout/style is carried into implementation.
- Keeps visited view trees at their last meaningful layout sizes offstage to retain
  item-local drafts and scroll state during reflow. This avoids a second state
  authority but needs memory/performance and stale-target tests.
- Added explicit non-committing posture dismissal for keyboard/workspace drafts,
  idempotent close handling, and numeric-hold cancellation epochs.
- Utilities action opens management when empty; otherwise scrolls to the actual
  utility section. More separates Player 1 tools from whole-game tools/history.
- Adapts selected-token and utility-detail layouts at compact content widths.
- iOS family includes iPhone and iPad under the unchanged Table bundle ID. No
  production original-app identity, release version or OTA data is changed.

## Validation and open work

Offline Dart formatting and whitespace checks run in cloud. Full SDK bootstrap
was blocked after dependency tooling attempted an unnecessary cloud metadata
request; no credentials/metadata access was pursued. Analyzer, runtime tests and
builds must run through authorized CI before claiming readiness.

Independent review identified draft recovery, duplicate route-pop, hidden hold,
reordering, small-modal overflow and action semantics issues; corrections are
being integrated. New tests cover presentation policy, Player 1 targeting, basic
posture continuity, non-committing keyboard dismissal and phone layout captures.
These are authored tests, not yet a claim of passing execution.

Still required: end-to-end phone routes, full existing tablet regression suite,
real rendered UX review, large text/keyboard stress, fold transitions during
pending saves and drafts, preview storage isolation, signed native feature build
and device validation. Migration/preset gaps are documented separately; no live
original-install migration or production cutover is implemented here.
