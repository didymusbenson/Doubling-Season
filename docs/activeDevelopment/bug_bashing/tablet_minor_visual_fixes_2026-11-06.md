# Tablet minor visual fixes

Date: 2026-11-06. Based on the two annotated native screenshots and
`feat/adaptive-five-six-seats-20261105` at `1d986872`.

- Custom starting life: the Cupertino wheel's default fade and gray selection
  overlay made the values hard to distinguish against the dark drawer. Use an
  outlined, elevated Material surface, a primary-container selection with bold
  paired foreground, and 85% opacity for neighboring values. Retain the bounded
  1–1,000,000 wheel, buttons, adjustable accessibility actions and keyboard-free
  draft behavior.
- Horizontal drawer: life cutouts used fixed X positions for all three shared
  controls on both rows. Opening separated Dice from Menu/Day-Night but left
  their old cutouts behind. Track each actual control center in both dimensions
  through the opening animation, restoring life surfaces where a control leaves.
  Move the upper drawer-wall notch to the actual Dice center rather than leaving
  an empty semicircle at the old Menu position. Keep the lower Menu notch and
  actual control clearances; surface fill, wall outline and board clipping share
  the same geometry.
- Regression coverage adds light/dark selected/adjacent contrast, accessible
  adjustment and scrolling, plus control-aligned clipping during repeated drawer
  open/close for narrow four-, five- and six-seat layouts in both orientations.

## Validation

Validated on 2026-11-06 with Flutter 3.41.2 / Dart 3.11.0 in an isolated Mac
worktree, preserving the existing Wi-Fi installation checkout.

- Changed Dart files formatted; `flutter analyze` passes with no issues.
- Full tablet `flutter test`: **1,287 passed, 7 existing opt-in skips**. This
  includes 1–1,000,000 life bounds, accessible adjustments, draft preservation,
  light/dark contrast, and repeated drawer animation geometry.
- Release web build passes with the existing Pages base path and
  `--pwa-strategy=none`. No publication was performed.
- Font-loaded widget captures reviewed in light and dark themes, including
  six-player portrait and landscape: selected and adjacent life values are
  readable; upper wall notch surrounds Dice; no empty centered semicircle or
  obsolete opposite-row control cutouts remain. Regression assertions check
  unused upper positions retain the board surface throughout animation.
- Drawer-surface tests pass all 12 cases. Horizontal notch assertions use the
  real Dice position; raster samples avoid the control's shadow. Vertical
  half-circle surface checks remain unchanged.

Local evidence: `/tmp/minor-visual-captures/`, `/tmp/minor-visual-analyze.log`,
`/tmp/minor-visual-full.log`, and `/tmp/minor-visual-build.log` on the validating
Mac. These are widget-rendered captures, not browser or native-device acceptance.
No device install, Firebase upload, merge or Pages publication was performed.
