# Expanded Mana Pool: Disa's Diary design direction

## Scope

Feature branch based on `3ed1fde8f2daa49bb3f75c4204914e78a0aa6059`.
Only the expanded Mana Pool presentation changes. Shared utility shell, inline
utility cards, keyboard, controller, persistence, and other utilities are unchanged.

## Actual reference

Read the local `Disas-Diary` checkout at `bb8f79d`, specifically
`disas_diary_flutter/lib/widgets/mana_tile.dart`,
`lib/screens/mana_pool_screen.dart`, `lib/theme/mtg_colors.dart`, and
`docs/newrelease/mana_pool.md`. The implementation is authoritative where its
hold increment differs from older documentation. The reference checkout was not
modified. A temporary test harness rendered the unmodified ManaTile; this verified
tile/glyph geometry, but its numeric font rendered as test-font blocks, so numeric
styling was verified from source rather than claiming a native reference capture.

## Translation

- Two columns, W/U then B/R then G/C, at tablet and phone widths.
- Exact reference pastel tile/symbol palette, oversized background mana glyph,
  bold centered count, 8px corners, shadow, and amber locked outline.
- Full left/right half targets retain ±1 and hold-10 behavior.
- Explicit ±10, lock and conversion controls remain visible below each count;
  they wrap on narrow screens rather than becoming inaccessible.
- Retained exact full counts (scaled to fit), rather than adopting Disa's compact
  number abbreviations. No mana category or per-seat state was removed.
- Locks still protect Empty only. Conversion still moves all mana, even locked.
  Empty retains the existing confirmation and undo semantics.
- Extracted `mana_pool_panel.dart` as a focused part to avoid nearby utility work.

## Validation

New renderer/layout tests exercise 1133×744 and 744×1133 tablets plus 390×844 and
320×640 phones, with a large exact value and a locked color. They verify WU/BR/GC
positioning, palette/lock border, and scroll reachability for every color's ±1,
±10, lock, convert controls and Empty. Existing half-stepper regression retains
full-target taps, hold cancellation and seat isolation; only its obsolete fixed
48px height assertion changes to the new larger tile target minimum.

Screenshots are Flutter test-renderer evidence, not native-device acceptance.
No installation, deployment, default-branch merge, or Disa edit is part of this work.

Full-suite execution on macOS must use a canonical TMPDIR (`/private/var/...`),
because migration tests intentionally reject symlinked ancestors and macOS's
usual `/var/...` temporary directory is a symlink. The ordinary-path attempt
reported unrelated migration errors; canonical-path results are recorded below.

Verified on Flutter 3.41.2:
- `flutter analyze`: no issues.
- Focused layout / half-stepper / numeric persistence tests: 37 passed.
- Full tablet suite with canonical TMPDIR: 2,190 passed, 25 skipped, zero failures.
- `flutter build web --release`: succeeded; not deployed.
- `git diff --check`: clean.

Native acceptance remains pending. Feature checkpoint only; integrate with other
utility changes through a single assigned integrator.


## Compact all-controls layout

The dedicated Mana Pool modal drops its description and instruction line. On
supported portrait, landscape and rotated seat widths, all six Disa-inspired
tiles, their ±1 and ±10 halves, locks, conversion, and Empty are visible before
any scrolling. The miniature artwork/edit affordance and artist credit share
the footer with Empty. The ordinary artwork editor remains a separate view.
A short, wide split view can use more columns; only extreme windows that cannot
fit 44-pixel touch targets retain a bounded scroll fallback. No mana rules,
numeric limits, labels, persistence, or other utility layouts changed.
