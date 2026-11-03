# Counter-modified P/T backplate — 2026-11-03

## Request and observed failure

The user requested that the orange counter-modified power/toughness display
fill its entire existing region, covering the shaded base underneath. The supplied
photograph shows a rotated tablet Thopter with orange `2/2` and exposed dark
strips at both sides, including the rounded corners.

The actual JPEG was materialized with the current Library transfer helper and
visually inspected before changing the design. Its retained identity is
`libfile_2eb70c0d74488191be0227bd5af6335c`, version `0`, SHA-256
`c17333264424878007b14e7fdfe1a49bbff7f16babbda30f689fbcd470b496e1`.

## Cause and fix

`TabletTokenCard._field` wrapped P/T in a black 60% readability backplate with
five pixels of horizontal padding. `_PowerToughness` independently painted a
smaller orange rounded background. The two footprints exposed dark strips;
there was no duplicate base-stat text.

Modified P/T now paints orange on the outer backplate. The inner background is
transparent, retaining the existing field dimensions, text padding, 88-pixel
inner maximum width, rounded corners, taps and calculated values. Its value still
pops over a stable full orange surface. This is the implementation judgment used
to satisfy the user's full-fill request without changing the card's layout.

The neutral no-artwork P/T also retains a transparent outer wrapper. Independent
review caught that otherwise adding the first or removing the last modifier
would replace the widget subtree and suppress the existing pop animation.
Unmodified P/T and inline editing keep their existing appearance.

Phone and tablet share this component, including rotated seats. The original
root application's `TokenCard` was reviewed: it already selects a single P/T
background and does not have this nested-backplate bug. Utility rows have no
corresponding P/T overlay. No data, storage, counter calculations or interaction
commands changed.

## Verification

`pt_backplate_render_regression_test.dart` probes the full region's side and
corner pixels. Cases cover phone/tablet, artwork/no artwork, compact/expanded,
all seat orientations, positive/negative, zero, wide and symbolic P/T, separate
power/toughness modifiers, restoration to neutral, retained animation state,
and expand/edit actions. The identical test fails all 11 cases against the prior
`b37f1f6` source at the full-orange edge assertion. All nine compared
modified/editing badge footprints match the baseline exactly. Artwork-backed
edge probes change from gray `[102,102,102,255]` to orange `[239,108,0,255]`.

The actual local release web UI was exercised using semantic controls and
pointer/keyboard events, with fresh browser storage. The bundled Thopter artwork
reproduced the user's dark strips before the fix. Captures after the fix include
phone and four-player tablet `2/2`, wider `100/100`, unmodified `98/98`, and the
base P/T editor. Counter changes and edits survive reload and layout changes.

Local evidence is under
`/Users/didymusbenson/Documents/Codex/2026-10-30/task-4/verification/pt-mask-2026-11-03/`.
Rendered browser evidence is in `browser-before/` (14 before/after/final
captures, zero runtime exceptions); pixel-test evidence is in `before/` and
`after/`. The local release web build succeeds. The full tablet suite passes
1,131 tests with 7 existing skips; all 11 focused render tests pass with both
default test fonts and real UI fonts, using decoded fixture artwork. The analyzer
reports no issues. Independent code
review has no remaining findings after the no-art animation correction.
No physical device installation or native release acceptance is claimed for
this paint-only fix. No preview, Firebase/store release, signing changes or main
merge was performed.
