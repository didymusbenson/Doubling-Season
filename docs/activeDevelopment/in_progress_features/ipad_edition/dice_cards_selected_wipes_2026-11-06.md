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

Implementation checkpoint. Automated and visual validation are pending.
No app distribution, main merge or deployment is part of this feedback branch.
