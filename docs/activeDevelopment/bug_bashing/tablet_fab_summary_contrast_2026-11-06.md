# FAB actions, Board Summary, and modal contrast

## Scope

Follow-up to build 14, based on integrated feature head `42b1109`:

- Remove the Rules text from the token-lane button, retaining the calculator,
  accessible player/action label, active indicator, and simple multiplier preview.
- Move Utilities/Player customization to the player-local right side and replace
  the intermediate tools dialog with a two-action FAB menu.
- Review and improve Board Summary's modal fit.
- Reproduce and fix contrast in custom-rule/utility steppers and game history.

No device installation, Firebase distribution, default-branch merge, or Pages
publication is part of this change.

## Implementation and review

`PlayerToolsFab` opens a transparent, tap-consuming popup route anchored to the
existing button. Both action labels and close button retain the player's facing
direction. Action bounds account for rotated safe-area insets. Outside taps,
Close, resize, lifecycle interruption, and presentation changes dismiss the
menu; choosing an action opens the existing player-scoped editor directly.
The obsolete tools workspace page has been removed.

Shortest utility sections reserve a trailing strip for the FAB so it cannot
cover the only reachable part of a mana stepper. Extremely narrow mana layouts
use one column rather than crushing the halves. Ordinary floating layouts retain
their 72px scroll gutter; regression coverage scrolls the green add/spend halves
clear of the FAB and executes both actions. Compact reorder retains its own Done
control and does not display the FAB.

Board Summary was the sole first child of the workspace list. The list reserved
the close-control gutter for that entire child, narrowing all summary content.
The heading now owns that gutter, while the body uses the full available width.
A 600px modal and grouped token/status/power panels replace the long undifferentiated
list. Values align, sections use two columns when space and text size permit,
and phones/enlarged text use one column. Computation is unchanged.

The contrast failure was in actual Card surfaces, not the FilledButton styles
covered by the earlier pass. Shared Cards now have an explicit highest-surface
fill, transparent surface tint, and 1.5px outline. This covers preset rules,
custom Copies, utility values, and other Card-based steppers. Real disabled
zero decrements remain disabled and dimmed. History separators use the full
outline color rather than a faint alpha-blended outline variant.

## Rendered evidence

Flutter-rendered images were inspected with real fonts and actual shadows.
No browser or native-device acceptance is claimed.

Actual raster contrast ratios (dark / light):

- Stepper edge versus fill: 5.73 / 4.69, previously no distinct edge (1.00).
- Enabled stepper icons: 9.56 / 13.25.
- Custom-rule text minimum: 7.25 / 5.00.
- Utility text minimum: 7.70 / 5.85.
- History text minimum: 7.70 / 6.46.
- History separators: 7.94 / 5.48, previously 1.40 / 1.29.

History was also opened through the actual TableScreen central control and
embedded drawer. Normal and undone rows retained the measured text/separator
contrast. The regression exercises Undo latest and closes the drawer normally.

Summary captures cover 320px/390px phones, small and large tablets, short modal,
90/180-degree facing, and 2x text. FAB captures cover compact 2/4/6-player layouts,
portrait and landscape, both facing directions, and enlarged text. Tests cover
all players, owner routing, action geometry, outside-tap consumption, repeated
opening, safe insets, lifecycle dismissal, resize, and utility access.

## Validation

Validated with Flutter 3.41.2 / Dart 3.11.0 in an isolated Mac worktree:

- `flutter analyze --no-pub`: no issues.
- Full tablet `flutter test`: 1,362 passed, 7 existing opt-in skips.
- Release web compilation passed with `/Doubling-Season/tablet/` base path and
  the existing `--pwa-strategy=none` setting (Flutter reports its deprecation).
- Changed Dart files formatted; `git diff --check` clean.
- Focused final FAB/rendered-contrast suite: 24 passed. Actual menu and summary
  screenshot reruns passed; independent UX review inspected both facing directions.

Local evidence on the validating Mac is under `/tmp/tripling-fab-captures/`,
`/tmp/tripling-summary-after/`, and `/tmp/modal-after/`.
