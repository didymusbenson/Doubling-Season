# Historical-source and startup-guard integration (2026-11-10)

Feature branch: `feat/table-migration-integration-20261110`.
Source checkpoint: `5c881bd062631a53fbc625d16d4804c3c7d3f9b5`, tree
`3fa8455c19238ff65a266e106cf3832ca89525a5`.

This integrates historical fixtures `1fb93c2` and dormant startup routing
`1af4b84` after recovery checkpoint `633cb92`. Release remains held. No default
branch merge, PR, deployment, application identity change, original startup
change, production migration activation or native installation occurred.

## What changed

- [Historical Hive fixtures](historical_hive_fixtures_2026-11-10.md) preserve
  exact older repository models/adapters and real frozen Hive bytes, with
  source/runtime provenance and repeatable generation. These are synthetic
  historical-schema fixtures, not genuine shipped-device copies.
- An actual compatibility defect is now refused safely: pre-order boards could
  silently change creation-time order into Hive-key order. The copied-source
  reader audits all surviving board records before model decoding and blocks
  multi-record boards containing an absent/null order field. It first retains
  all source bytes. Superseded/tombstoned frames do not falsely block a valid
  explicit-order board. No historical behavior is guessed from a version label.
- [Dormant startup routing](startup_gate_foundation_2026-11-10.md) inventories
  all declared evidence domains and sends source, migration, unknown, incomplete,
  corrupt or retained-data cases to recovery. Repeated checks coalesce, retries
  inspect again, and disposal suppresses late results. Even empty/valid-existing
  candidates cannot authorize activation. No production inventory adapter or
  inspect-and-activate lease exists, and neither entrypoint is wired to this code.

## Combined verification

Validation uses the official Flutter 3.41.2 Git tag `90673a4eef`, engine
`6c0baaebf7`, and Dart 3.11.0. The reset workspace's SDK/dependency caches were
restored; repository lockfiles remain unchanged. Remote/local source trees
match exactly. The validation documentation is a later docs-only follow-up.

- `flutter analyze --no-pub`: no issues found (3.1s).
- `flutter test --no-pub --reporter expanded`: **1,876 passed, 8 expected
  skips**, 7m36s. This was a complete rerun after the environment reset, not
  an inference from the interrupted process.
- Explicit `phone_preview_v1` migration, history, startup, catalog, repository,
  support, storage and integration checks: **361 passed, 57 intentional
  same-app-only skips**, 40s.
- Release JavaScript web build: passed (79.4s). The optional Wasm compiler
  dry run also succeeded; no Wasm runtime or browser acceptance is claimed.
- Regeneration is byte-identical, all 22 archived source files match their exact
  Git blobs, all 23 local plan links resolve, and the working diff check passes.
- Exact source commit has no recorded commit statuses or pull-request workflow
  runs. No PR or CI run was created. Android/iOS builds and native acceptance
  were not run.

The earlier interrupted run included one artwork-pixel test failure. The complete
unchanged rerun passed, as did three isolated repetitions. Its fixed 100ms wait
can race asynchronous image decoding; the following test-only checkpoint replaces
that delay with actual provider/image readiness while retaining the exact pixel
assertion. The race is strongly supported, not claimed as deterministically
reproduced.

Commands from `apps/tablet`:

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 \
  test/legacy_*test.dart test/historical_hive_fixtures_test.dart \
  test/table_startup_gate_test.dart test/catalog_compatibility_test.dart \
  test/table_repository_compatibility_test.dart test/support_continuity_test.dart \
  test/storage_namespace_test.dart test/update_foundations_integration_test.dart
flutter build web --release --no-pub \
  --base-href /Doubling-Season/tablet/ --pwa-strategy=none
```

The archived source matches all 22 historical Git blobs. Repeated fixture
regeneration produces identical bytes and provenance. Independent read-only
review found no remaining correctness issue in the final copied-source guard
or dormant gate after the requested null/order/tombstone regressions were added.
Component checks were 54 historical/source/coordinator tests and 35 startup
checks; the combined results above supersede component-only counts.

## Still held

Real shipped-version installation copies, broader historical variants and native
artwork-file coverage, explicit support policy for pre-order boards, live all-writer
quiescence, durable production archive/export/retention and full-disk policy,
leased startup activation, process/power-loss evidence, same-identity
no-uninstall native upgrades, store restoration, device/OS/accessibility and
hands-on acceptance remain open. Passing this checkpoint does not establish
migration/update-safe release status.

## Later-schema and test-readiness follow-up

Published source checkpoint: `af94b82ebd4ffe884192df46a999ec8e0afcfbaa`, tree
`13725b1f689e983251a66c5357cba28f1963495b`. This is byte-identical to local
validation commit `2804b7d2c917698f86cbba45a4faaf3fa141e1a4`. The connected
GitHub API published the identical tree when command-line Git push could not
obtain credentials after the environment reset. The feature ref was advanced
without force, against the expected prior head, and fetched back for verification.
The original local history is retained as a backup; no work was discarded.

The follow-up adds exact `fa577ac` repository models/adapters for types 0–12:
artwork metadata, trackers/toggles and saved templates, and initial rule schemas.
It verifies raw-file retention, defaults for subsequently added fields, separate
live state/fresh presets, and idempotent coordinator reopen. All 28 new archived
sources match their exact Git blobs; repeated generation is byte-identical.
Together with the initial fixtures, all **50 source archives** and every frozen
fixture hash were checked. These are synthetic fixtures, not shipped captures;
this extension tests artwork metadata, not historical native artwork-file access.

The drawer regression now awaits the actual image providers and verifies rendered
images before its unchanged strict pixel checks. No runtime code changes are in
this follow-up. The 44 drawer cases passed; three isolated repetitions passed
both before and after the synchronization change. The migration fixture/source/
coordinator component check passed 57 tests.

Final combined verification with Flutter 3.41.2 / Dart 3.11.0:

- Analyzer: **no issues** (3.4s).
- Full `flutter test --no-pub --reporter expanded`: **1,879 passed, 8 expected
  skips**, 6m24s.
- Explicit preview namespace suite: **364 passed, 57 intentional same-app-only
  skips**, 18s. Use the namespace command above with the additional
  `test/later_historical_hive_fixtures_test.dart` argument.
- Release JavaScript web build: **passed** (59.2s), including the optional Wasm
  compiler dry run. No runtime browser or native acceptance is claimed.
- Authored-code/documentation diff checks pass. The byte-exact archived
  `fa577ac` constants intentionally retain five original trailing-whitespace
  lines rather than altering their source provenance.
- No root/Table runtime files, lockfiles, app identifiers, entrypoints, signing
  or release configuration changed after `5c881bd`.
- Published source commit has no recorded statuses or PR workflow runs. There
  was no PR, default merge, deployment, native install, store restore or upload.

This closes the interrupted validation and expands isolated historical coverage.
It does not close the production/native acceptance gates listed above. Priority
remains complete read-only production inventory, all-writer quiescence and leased
activation, durable recovery/export/retention and disk-capacity policy, followed
by deliberately authorized real-installation and store acceptance.
