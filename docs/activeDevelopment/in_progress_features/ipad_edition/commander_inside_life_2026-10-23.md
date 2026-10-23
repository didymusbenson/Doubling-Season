# Commander mini-tracker inside life chips

The latest correction places the existing source-ledger mini-grid inside each
colored life chip, centered below the slightly raised life total. Its 44px-high
target alone opens the expanded commander source grid. Name, total and all
surrounding chip padding retain the player-local life halves; neither opening
nor dismissing the commander workspace may change life.

The chip is 140–180px tall, retaining a separate name row, large fitted total and
44px mini-grid with bottom breathing room. The tools row below now contains
Monarch, City's Blessing, counters, rules, then Edit. Removing the ledger from
that row offsets the extra chip height on short landscape seats. The 60/40 lane
split, corner overlays, global hub, source identities/styles, damage commands,
life coupling and undo remain unchanged. The original phone app is untouched.

## Verification

Implementation checkpoint: validation pending while the cloud Flutter SDK is
restored after an executor filesystem reset. New tests cover 2/3/4-seat mini and
large portrait/landscape layouts, empty and partner sources, signed six-digit
life, chip containment/alignment, dedicated commander taps and life padding.
Existing regressions retain source styling, expanded-grid damage coupling,
undo, modal dismissal, hub clearance and lane/capacity checks.

Optional real-font Flutter widget-renderer evidence:

```sh
FLUTTER_ROOT=/path/to/flutter TABLET_CAPTURE_DIR=/tmp/commander-review \
  flutter test test/commander_life_chip_regression_test.dart
```

This is renderer evidence, not native hands-on acceptance. GitHub CI builds
Android and the iPad simulator. Publication follows parent pixel review and
validation through the existing combined original-plus-tablet Pages workflow.
