# Full-card preview corners

## Report and cause
The supplied iPad photo shows white wedges at all four Treasure preview corners.
The catalog's 2X2 Treasure source is a 672 × 936 JPEG with no alpha channel.
Its white pixels are baked outside the printed card's rounded outline. The
creation preview displayed the full rectangular image without clipping.
Neither the modal background nor image-cache conversion caused the wedges.

## Fix
Clip only the creation preview to rounded corners proportional to its width,
with enough inset to cover the source's corner matte and the small contain-fit
letterbox. Preserve contain fit, portrait bounds, artist credit, source URL and
cached bytes. The corners reveal the surrounding surface in either theme.
This is not a change to board token/utility art crops or user media.

## Validation
- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 1,462 tests with 7 pre-existing skips.
- `flutter build web --release --pwa-strategy=none`: passed.
- All 13 creation composition regressions pass. Four new pixel regressions
  cover dark/light surfaces and both 140/180 px previews, verifying all four
  corners reveal the modal while real white content stays intact.
- Temporarily disabling the clip made all four new regressions fail; the
  restored implementation passed the full suite.
- Inspected a rendered landscape preview using the actual 2X2 Treasure JPEG.
  White corner wedges are gone; the full card and separate artist caption fit.
  Existing narrow, short, rotated, large-text, keyboard, Back/reselection and
  creation tests remain green.

Native installation and device acceptance were not run. No Firebase, Pages,
store distribution, signing, storage or cached-artwork changes were made.
