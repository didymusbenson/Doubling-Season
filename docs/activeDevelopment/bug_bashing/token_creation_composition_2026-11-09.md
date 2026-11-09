# Token creation composition

## Report
The supplied iPad screenshot shows a stretched Back to search button, a cropped
card preview without an artist credit, and a large empty lower portion of the
creation modal.

## Cause and fix
The selected-token form inherited the fixed 640 px search shell. Its first
button was stretched, and its artwork used a 160 × 150 cover box.

Size selected-token forms to their content within the existing bounded modal.
Keep full-height search and keyboard editing, with scroll fallback on small or
rotated screens. Use a compact Back action, full portrait artwork with contain
fit, and the existing accessible artist caption below. Keep metadata and
creation controls together beside the image, stacking on narrower screens.
No gameplay, persistence, or original phone-app changes are intended.

## Validation
- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 1,458 tests with 7 pre-existing skips.
- Nine focused regressions cover content height, compact Back, portrait contain
  fit, credit placement, no-art fallback, Back/reselection, creation quantity,
  keyboard draft retention, narrow/short/rotated layouts, 2× text, and native
  phone/landscape keyboard insets.
- `flutter build web --release --pwa-strategy=none`: passed.
- Inspected rendered Clue artwork with its catalog artist credit, plus narrow,
  short/native-landscape and enlarged-text layouts. The normal landscape form
  is 470 px tall rather than 640 px, with about 20 px below the Create action.
  Short or enlarged layouts scroll without hiding the dismissal action.
- Independent source review found no blocking defects. Its keyboard and
  realistic-art validation suggestions are covered above.

Native installation, signing and device acceptance are separate delivery steps.
No store, Firebase or Pages deployment was performed as part of this change.
