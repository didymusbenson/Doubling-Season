# Commander mini-tracker inside life chips

The latest correction places the existing source-ledger mini-grid inside each
colored life chip, centered below the slightly raised life total. Its 44px-high
target alone opens the expanded commander source grid. Name, total and all
surrounding chip padding retain the player-local life halves; neither opening
nor dismissing the commander workspace may change life.

The chip is 140–180px tall, retaining a separate name row, large fitted total and
44px mini-grid with bottom breathing room. Narrow lanes cap at 148px to retain
portrait utility capacity. A lone source cell is visibly centered within its
mini-grid target, while multiple sources retain their established order. The tools row below now contains
Monarch, City's Blessing, counters, rules, then Edit. Removing the ledger from
that row offsets part of the extra chip height on short landscape seats.
Mini-landscape utilities can scroll by at most one mana row (48px), now including
two-player tables; full-size mana targets remain reachable. Portrait and larger
landscape presets retain default utilities without scrolling. The 60/40 lane
split, corner overlays, global hub, source identities/styles, damage commands,
life coupling and undo remain unchanged. The original phone app is untouched.

## Verification

Flutter 3.41.2 / Dart 3.11.0 on the assistant cloud workspace:

- Clean `flutter analyze`.
- 32 layout/capacity regressions passed.
- 36 real-font renderer/interaction scenarios passed: 2/3/4 seats at
  1133×744, 744×1133, 1366×1024 and 1024×1366, with empty, single and partner
  source lists, signed six-digit life, containment/alignment and no tap-through.
- 6 additional normal-40 renders passed for mini 4-seat portrait/landscape.
- Full tablet suite: **369 tests passed**.
- Release web build passed with the existing tablet base path and no PWA worker.
- Final native CI remains a publication gate; native hands-on acceptance is
  still unperformed.

The existing regressions retain source styling, expanded-grid damage coupling,
undo, modal dismissal, hub clearance and lane/capacity checks. Parent pixel
review approved normal 40-life landscape and portrait, single/partner sources
and large signed-life scenes. Screenshots are unmodified Flutter-renderer pixels
(with optional chip crops), using Roboto, Material Icons and the bundled Mana
font; no image generation or browser/native simulation is involved.

Optional real-font Flutter widget-renderer evidence:

```sh
FLUTTER_ROOT=/path/to/flutter TABLET_CAPTURE_DIR=/tmp/commander-review \
  flutter test test/commander_life_chip_regression_test.dart
```

Set `TABLET_CAPTURE_NORMAL_LIFE=true` to capture the same fixtures with normal
40-life totals. The default fixtures deliberately use ±999999 for stress checks.

This is renderer evidence, not native hands-on acceptance. GitHub CI builds
Android and the iPad simulator. Publication follows parent pixel review and
validation through the existing combined original-plus-tablet Pages workflow.
