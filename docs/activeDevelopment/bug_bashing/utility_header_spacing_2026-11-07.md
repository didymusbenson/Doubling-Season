# Utility action rows and labels

## Report and cause

The supplied screenshot shows Squirrel Girl's numeric control comfortably inside
its row, but Krenko and Cathars' Crusade touching the top divider. `_UtilityRow`
centered a 46 px numeric surface beside the title without vertical padding. A
wrapped two-line title incidentally created clearance; a single-line title was
shorter than the control, so the control defined the row height and touched the
edge. A regression reproduced Krenko's exact 0 px upper inset before the fix.

The user's follow-up explicitly replaced this header arrangement: put utility
steppers inline with their action buttons, remove the mana cost from Squirrel
Girl's button, and change the Ring action to "Tempt".

## Correction

- Actionable utility values now follow the primary action, centered in the same
  wrap row. Cathars' secondary Quick +1/+1 action remains available. Narrow lanes,
  larger text, and very large values can wrap without clipping labels or reducing
  the stepper's 44 px hit height. The title has its full width for details/editing.
- The Ring uses its existing inline trailing slot for its numeric control.
- Non-action counters retain their existing compact header control and capacity.
- Squirrel Girl says "Make Squirrels" on the board and in details, including
  existing saved utilities with the old action-text configuration. New utility
  definitions use that label. The 1GGG ability's mechanics are unchanged.
- The Ring action and accessible label say "Tempt". Its next-ability reminder,
  optional bearer, cumulative rules and progression are unchanged.
- No saved-state migration, root phone-app changes, device installation, or
  deployment is part of this change.

## Validation

- Focused suite: 68 tests passed before final detail-label/semantics coverage.
- New geometry/interaction matrix: phone 390x844 and 320x700 at 1.5x text;
  2/3/4/5/6 seats at 1133x744 and 744x1133. Assertions cover action/value alignment,
  header separation, accessible increment controls, preserved hit height and undo.
- Real-font widget captures passed the same 12-case matrix. Inspected phone,
  four-seat landscape, and six-seat portrait renders: action/value pairs align,
  Cathars' secondary action wraps below when needed, and controls remain readable.
- Final focused layout/label suite: 19 passed, including Ring alignment,
  six-digit value wrapping, accessible Tempt text and saved Squirrel labels.
- Combined feedback integration: `flutter analyze` reports no issues and the
  full tablet suite passes **1,449 tests with 7 existing skips**.
- `flutter build web --release --base-href /Doubling-Season/tablet/
  --pwa-strategy=none` passes. Subsequent changes are test assertions and
  documentation only; application sources are identical to the built tree.
- Independent read-only review found no actionable utility code or visual issue.

Widget renders are automated Flutter evidence, not native device acceptance.
