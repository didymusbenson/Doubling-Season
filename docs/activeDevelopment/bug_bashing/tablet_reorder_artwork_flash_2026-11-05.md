# Tablet artwork flash after reordering — 2026-11-05

## Status and scope

Implemented and automatically validated; native iPad acceptance is pending.
The user is continuing to collect feedback against the last installed iPad
build. Firebase distribution is explicitly delayed while fixes are batched.
No default-branch merge, Pages deployment or device distribution is part of
this checkpoint.

Work starts from `feature/phone-mode` at `2cf9f45`, preserving its seat-facing
drag behavior and separation from stable main. The artwork defect is also
present in the older stable implementation.

## Findings

The original Tripling Season fix (`7b15e20`) avoided repeated artwork fades.
Tripling Table shares `TableArtwork` across tokens, utilities and player art.
It cached remote Futures, but a freshly mounted FutureBuilder still starts
with a waiting frame even when its Future has already completed. Reorder
proxies and dropped rows can mount fresh artwork subtrees. Native artwork
also added a 160 ms frame fade. Uploaded art had synchronous cached bytes hidden
behind an async read; inline image URLs decoded new byte objects on every
rebuild, defeating MemoryImage's identity-based decoded-image reuse.

## Fix

- Keep resolved immutable bytes available synchronously and seed fresh
  FutureBuilders, including derivative/fallback requests, from those bytes.
- Reuse inline-image byte objects through a bounded cache.
- Remove repeat native image-load fades. The existing intentional artwork
  selection/style transition remains in `TableArtworkSurface`.
- Key loaders by source/policy so changing selected art cannot retain the old
  snapshot. Preserve missing-media selections and all persistent artwork data.
- Evict resolved bytes together with pending Futures and failures. Late
  completions cannot resurrect evicted entries. Native capacity accounts for
  both a derivative policy and its underlying source.

The shared artwork path applies equally to token, utility and player surfaces
in compact/expanded and full/fadeout presentations. The original phone app is
unchanged. This does not modify ordering, rotation, game state, undo or storage
schemas. Device-system-bar work is documented separately in
[device_system_bars_2026-11-05.md](../in_progress_features/ipad_edition/device_system_bars_2026-11-05.md).

## Validation (Flutter 3.41.2 / Dart 3.11.0)

- Reproduction: the three new warmed-art proxy tests fail against the previous
  renderer at the first proxy frame: uploaded/remote images disappear and the
  inline image has no decoded frame. The fixed renderer passes before settling.
- Regression coverage: stable byte identity across rebuild, simultaneous proxy,
  fresh remount and repeated remount; uploaded/remote URL changes; synchronous
  fallback; bounded eviction and stale successful completion.
- Real gestures: repeated forward/reverse token reorders on upright and rotated
  seats check every drag/drop frame for a painted image and verify final order.
- Full tablet suite: **1,164 passed, 7 intentional skips**, no failures.
- `flutter analyze --no-pub`: **no issues**.
- Release web build with `/Doubling-Season/tablet/` and `--pwa-strategy=none`:
  **passed**, including the toolchain's Wasm compatibility dry run.
- Formatting and `git diff --check`: **passed**.
- Browser smoke: **not executed successfully**. Chrome could not create its
  temporary profile socket in this execution environment, failing before the
  app launched. No browser interaction or screenshot acceptance is claimed.
- Native Android/iOS builds and actual device/system-bar behavior: **not run**
  here. The new native-channel lifecycle tests pass, but do not prove OS UI.

## Next device check

On the next approved iPad build, reorder artwork-bearing tokens repeatedly in
both seat orientations, including uploaded and remotely cached art. Check that
selected artwork, order and undo remain intact. Check native system bars using
the separate checklist. Do not distribute until the user resumes that step.
