# Dice cards and selected board wipes

User feedback on 2026-11-06: dice quantities belong in cards with full left/right
stepper regions, and the existing roll animation should take half as long.
Board-wipe categories should toggle a selection before choosing whether to keep
empty stacks or remove them.

## Implementation

- Dice use the shared HalfStepper inside a bordered card. The die painting does
  not intercept taps; the complete left/right halves decrement/increment, with
  existing holds, 0–20 limits, semantics and interruption protection.
- Roll animation is 375 ms instead of 750 ms. Result generation, repeat lock and
  reduced-motion behavior are unchanged.
- Board-wipe choices toggle without mutating the game. All tokens selects every
  option; tapping it again clears them. Selected categories are OR-combined.
- Explicit Set to 0 / Delete selected (Delete All for all tokens) actions follow
  the original app's wording. Set to 0 matches TokenProvider.boardWipeZero:
  amount, tapped and summoning sickness become zero; stack IDs, artwork, counters,
  order and other metadata remain. Deletion removes only matched token stacks.
- Both modes remain one atomic global command and one History Undo. Type-based
  selection protects emblems; All tokens includes them. Utilities, life, player
  counters, rules, archived games and saved profiles are not changed.

## Validation

- Flutter 3.41.2 analysis passes with no issues. Full tablet suite passes:
  1,309 tests, 7 opt-in skips. Release web compilation passes.
- Dice tests cover complete half-card hit areas including taps over the die
  painting, enabled/disabled semantics, light/dark contrast, 0–20 clamping,
  holds/cancellation, focused results and 375 ms completion. Reduced motion,
  lifecycle interruption, repeated Roll and Back/Close remain covered.
- Wipe tests cover multitype union selection, toggle-only changes, All tokens
  selecting/clearing all options, Cancel preserving selection and board state,
  Set to 0 retaining full stack metadata, matching deletion, unchanged profiles
  and archives, persistence failure atomicity, repeated wipes without extra
  history, and one Undo after reopening restoring every affected board.
- Font-loaded Flutter-rendered screenshots reviewed at phone/tablet dimensions,
  1.0/1.3 text scales, wide and narrow drawers. Dice are cards with internal
  indicators and full tap halves; category checkboxes and separate zero/delete
  actions are legible. Evidence: /tmp/dice-card-captures/ and
  /tmp/dice-wipe-captures/ on the validating Mac.
- Live browser inspection was not completed: the in-app browser was unavailable
  and Safari access was not approved. No alternate browser route was attempted.
  Widget captures do not establish native-device or browser acceptance.

No app installation, Firebase distribution, main merge or deployment was made.
