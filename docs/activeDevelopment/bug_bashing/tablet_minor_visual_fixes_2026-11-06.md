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
  Preserve the intentional centered drawer-wall notch and actual control clearances.
- Regression coverage adds light/dark selected/adjacent contrast, accessible
  adjustment and scrolling, plus control-aligned clipping during repeated drawer
  open/close for narrow four-, five- and six-seat layouts in both orientations.

Validation pending. No device install, Firebase upload or Pages publication.
