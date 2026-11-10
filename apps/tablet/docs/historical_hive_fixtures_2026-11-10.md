# Historical Hive fixture safety slice (2026-11-10)

## Result and scope

Added frozen real Hive 2.2.3 bytes produced from exact repository source at
`371577867932fed1643f809e4645b3a59d948b96` and
`d9e19b69b32d63b8e9b98af4d3cca991b66b131a`. Each archive includes original model,
adapter, constants, lockfile and live-board UI source bytes with SHA-256 provenance.
These are synthetic repository-history fixtures, **not shipped device captures**.

Artifacts and reproduction: `test/fixtures/historical_hive/README.md` and
`tool/generate_historical_hive_fixtures.py`. Generation verifies the actual Dart
3.11.0 executable and resolved Hive 2.2.3 package, not just a hardcoded label.

## Safety finding and narrow fix

The earliest historical screen sorted tokens by `createdAt`. Today's Item adapter
defaults missing order to zero, after which the modern migration key tie-break
would silently change a multi-record board's order. The fixture includes opposite
chronological/key ordering to expose this risk.

Copied-source acquisition now audits final surviving frames across all three live
board kinds before model decoding. If more than one live record survives and any
serialized order field is absent/null, it refuses with an explicit compatibility
error after retaining every original file. It does not infer a schema from caller
labels or guess a historical sort policy. A single old Item remains compatible;
this does not promise missing mandatory utility fields can decode. Explicit-order
multi-record data remains supported. Superseded/deleted frames do not block.

No startup wiring, platform acquisition, production storage selection or release
behavior changed. This guard is confined to the existing copied-source reader.

## Verification

- `flutter analyze --no-pub`: no issues found.
- 54 focused tests passed: historical fixtures, source reader and coordinator.
- Fixtures cover missing defaults, exact raw-byte retention, unchanged sources,
  real overwrite/tombstone frames, deterministic refusal and retained reopen,
  no destination promotion on refusal, explicit-order success, live quantities
  and counters versus fresh presets, and coordinator reopen/retry.
- Raw audit regressions cover absent/null order for Item, TrackerWidget and
  ToggleWidget across board kinds, plus superseded/tombstoned orderless frames
  with multiple explicit-order surviving records.
- All 22 archived files verified byte-for-byte against their exact Git commits.
- Repeated generation verifies all frozen files and provenance remain identical.
- Full combined integration validation belongs to the parent integration branch.

## Remaining release gates

Genuine shipped native installation copies remain unavailable. This slice does
not establish that either source commit was shipped, validate historical platform
runtimes, or complete the native update/release acceptance matrix. Later
artwork/utility/rule schemas still need historical coverage. Multi-record pre-order
boards now remain safely blocked pending an explicit supported compatibility
policy. Release remains held; no merge, PR, deployment or native installation.
