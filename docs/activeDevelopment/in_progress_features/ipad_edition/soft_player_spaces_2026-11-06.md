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

Validated locally with Flutter 3.41.2 / Dart 3.11.0:

- `flutter analyze --no-pub`: no issues.
- `soft_player_spaces_test.dart`: all 26 tests pass, both with real-font PNG
  capture and with the standard test renderer. Checks cover 2–6-player gap and
  corner geometry, black pixels, populated four/six-player layouts at mini
  portrait/landscape, 11-inch and large-tablet dimensions, both themes, quantity
  controls, final-token reachability, adaptive tabs, animated inner corners,
  repeated open/close, and no-click-through dismissal against live state.
- All 23 life/stepper tests and all 17 rotation/reorder tests pass. Expectations
  now distinguish black trimmed corners from visible life padding and measure
  the actual available drag travel before asserting pointer anchoring.
- All 3 explicit preview storage-namespace tests pass.
- Release tablet web build passes with the existing Pages base path and no PWA
  service worker (`--base-href /Doubling-Season/tablet/ --pwa-strategy=none`).
- Complete regression suite: all 104 test files ran exactly once across four
  tracked batches, **1,388 passed / 7 conditional skips / 0 failed**. Skips are
  the opt-in network-artwork and latency diagnostics plus the default run's
  preview-namespace cases (the latter passed in their explicit run above).

Optional `TABLET_CAPTURE_DIR` produced 64 real Flutter widget-renderer PNGs.
Visual review covered four/six-player mini portrait/landscape in both themes,
closed, opening, and drawer states. No new material content clipping was found.
Six-player landscape retains its existing scrollable drawer and compact-board
viewport behavior; this change does not promise that every row fits at once.

Native iPad and Android hands-on validation remains separate. Safari was not
accessed, and no device build was installed or distributed by this change.
