# Soft player spaces — 2026-11-06

## Requested appearance

The approved interactive study's **Soft separation** option replaces the solid
5 px player dividers with an **8 px black river** and **14 px corner radius**.
The perimeter stays flush with the tablet canvas. Each player surface is one
rounded space; token/utility rows keep their existing square, full-width design.
This supersedes older tablet guidance to retain hard player borders.

## Implementation

- Black table underlay is exposed through real layout gaps and clipped corners.
  Player spaces have no border stroke or shadow.
- Seat widths, adaptive-view thresholds, and shared-control cutouts all use the
  new gap width, including unequal five-player rows.
- The vertical drawer's rounded inner edge follows the moving life/utility rail
  without resizing token lanes or remounting their retained state. Horizontal
  drawers retain their existing motion and two-player viewport behavior.
- The drawer keeps its existing 2 px seam, circular control cutouts, open/close
  curves, interaction lock, and dismissal behavior. The seam is black to match
  the approved study's negative-space treatment.
- Original phone app, persistence, storage namespaces, game actions, native
  installation and distribution are unchanged.

## Validation

Pending final execution. `soft_player_spaces_test.dart` checks 2–6-player gap and
corner geometry, black rendered pixels, populated four/six-player layouts at
mini portrait/landscape, 11-inch and large-tablet dimensions, both themes,
quantity controls, adaptive tabs, drawer animation, repeated open/close and
no-click-through dismissal. Optional `TABLET_CAPTURE_DIR` exports real Flutter
widget-renderer PNGs, not native-device acceptance.

Native iPad and Android hands-on validation remains separate. Safari was not
accessed, and no device build was installed or distributed by this change.
