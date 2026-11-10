# Bounded read-only recovery backup validation

Date: 2026-11-10. Continues `ae96597` on
`feat/migration-safety-recovery-20261110`. Release and original-installation
cutover remain held.

## Purpose and authority boundary

The version-2 physical recovery exporter checks its own written file against
writer-known length and digest. An independently supplied backup also needs
bounded parsing, record-order checks and verification of its own declarations.
This slice adds that separate validation step. It does not import or restore.

The validator accepts an explicitly supplied byte stream and returns an aggregate
inspection result only after the complete stream passes. It has no filesystem,
Hive, destination, active-store or startup access. Entry paths, source labels,
link targets, coordination aliases and embedded migration control files remain
inert evidence. They cannot grant authority or cause any path to be opened.

A successful checksum is internal integrity, not authenticity. A sender can
rewrite the contents and recompute the hashes. `complete` describes consistency
with the exporter's coverage declarations, not proof of a quiescent snapshot,
coverage of an original installation, usability of an imported store, restore
safety or permission to migrate. Coordination bytes and unlisted stores are
still excluded, and literal links/coordination aliases remain metadata only.

## Validation contract

`LegacyRecoveryValidator.validate` uses byte-bounded line framing before UTF-8
or JSON decoding. It rejects nested objects/arrays, duplicate decoded JSON keys,
unknown fields, unsupported versions, malformed scalar values, invalid record
order, noncanonical base64, inconsistent counts and false completeness claims.
Each file's copied bytes and SHA-256 are checked independently, then the final
checksum is matched against the exact preceding bytes, including the summary.
The footer must be newline-terminated and followed by actual end of stream.

The default limits are explicit and caller-configurable:

- 8 GiB stream, 512 KiB per line and 1,000,000 input stream events.
- 4 GiB per file, 6 GiB total decoded payload, 10,000 entries and 32 sources.
- 4 MiB aggregate non-chunk record bytes and a separate 4 MiB path-index byte
  budget. Paths are at most 4 KiB and 64 components. The path-index budget follows
  `maxMetadataBytes`, preventing deep paths from multiplying retained metadata.
- Ten minutes total elapsed time, with cancellation while waiting on input and
  periodic checks during processing. Waiting for upstream cleanup cannot keep
  the validation result pending forever. The caller still owns upstream stream
  allocations and cleanup behavior; the validator cannot preempt hostile
  synchronous producer code.

These inspection limits are intentionally stricter than the exporter's overall
output budget: for example, the metadata budget counts all non-chunk records,
and the per-file limit is smaller than the stream limit. A valid export may
therefore be unsupported by the selected inspection limits. Refusal never
modifies the artifact or creates a usable partial-success result.

Source names are bounded unique labels, not path authority. Entry names are
screened for traversal, duplicate/lowercase collisions, conflicting ancestor
spellings, non-directory ancestors and common cross-platform reserved names.
This is not exhaustive Unicode normalization or filesystem case-folding
validation. Some genuine exporter filenames are deliberately unsupported.
Literal link and coordination targets stay inert, including absolute or parent-
relative targets; none are followed or recreated.

Partial exports are distinct from malformed streams. A readable file must match
its declared size. An incomplete file may be shorter or longer than the earlier
inventory size, but its actually copied byte count and hash must still agree.
Unavailable ancestors/entries, incomplete files and source instability produce
separate counts and must match the summary's problems and completeness. A file
cannot simultaneously be declared excluded coordination data and present as a
regular-file payload.

## Validation

Runtime and Flutter test source `3aff186444af97f0db1aa90dee21bcf5b402e568`, tree
`531ba8bd55d06dc10de70af5332fecbe1dbc80c7`, was fetched from the feature
branch and matched the local checkpoint exactly. The following tool/evidence
follow-up does not change app runtime or Flutter test sources.

Final checks use Flutter 3.41.2 / Dart 3.11.0 on Linux. Runtime and Flutter test
hashes are unchanged from the verified source checkpoint.

- Focused validator suite: **52 passed**.
- Full `flutter test --no-pub --reporter expanded`: **2,096 passed / 8 expected
  skips**, 5m55s.
- Standalone Dart-to-JavaScript/Node harness: **39 checks passed**.
- Final `flutter analyze --no-pub`: **no issues**, 1.6 seconds, including the
  standalone harness. Its intentional CLI result output has a line-scoped lint
  exemption; the initial tool-only analyzer notice is resolved.
- Explicit `phone_preview_v1` safety selection: **581 passed / 57 intentional
  same-app-only skips**, 32 seconds.
- Release JavaScript web compilation: **passed**, 39.0 seconds. Optional Wasm
  compiler dry run passed; Wasm runtime acceptance was not performed. The
  existing `--pwa-strategy` deprecation warning remains.
- Independent source and tooling review: no remaining blocking findings.
- The changed records/current plan have **40 valid local links**. Dependency
  lockfiles, original startup/native identity files and live data are unchanged.

No commit statuses or PR-triggered workflow runs were recorded for the runtime
source checkpoint. No PR, default merge, deployment or release occurred.

Review caught two resource-amplification risks during implementation: repeated
cancellation listeners and expanded path prefixes. A removable single waiter,
input-event budget, path-depth limit and measured path-index budget now cover
those cases. A separate JavaScript runtime check reproduced an integral-double
JSON discrepancy (`2.0` passed an `int` check under JavaScript). Pre-decode
canonical integer tokens within the exact shared numeric range now reject
fraction, exponent, negative-zero and unsafe-precision forms consistently.
The final JavaScript smoke passes after this fix. The permanent, in-memory
[standalone smoke tool](../tool/recovery_validator_smoke.dart) checks all five numeric fields with six raw
numeric forms each, including lexical forms that VM-only object serialization
would miss. It also checks complete and partial evidence, per-file/global
hashes, framing, traversal, limits, cancellation and inert numeric strings.
No data restore was attempted.

Reproduce from `apps/tablet` with Flutter 3.41.2 and resolved dependencies:

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test --no-pub --reporter expanded \
  --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 \
  test/legacy_*test.dart test/native_recovery_capacity_test.dart \
  test/historical_hive_fixtures_test.dart test/later_historical_hive_fixtures_test.dart \
  test/table_startup_gate_test.dart test/catalog_compatibility_test.dart \
  test/table_repository_compatibility_test.dart test/support_continuity_test.dart \
  test/storage_namespace_test.dart test/update_foundations_integration_test.dart
flutter build web --release --no-pub \
  --base-href /Doubling-Season/tablet/ --pwa-strategy=none
dart compile js --packages=.dart_tool/package_config.json \
  tool/recovery_validator_smoke.dart -o build/recovery_validator_smoke.js
node -e "globalThis.self=globalThis;require('./build/recovery_validator_smoke.js')"
```

The standalone JavaScript check exercises the dormant API that the app does not
yet import. Node execution and release compilation are not browser interaction,
native device, real-user-data or original-installation update acceptance.

## Remaining acceptance

No quarantine extraction, restore destination, overwrite, app activation or
recovery UI is introduced. Independent backup inspection must remain separate
from any later explicit, capacity-checked quarantine import and semantic
revalidation. Genuine shipped fixtures, live source quiescence, production
startup/authority and sizing, native low-space/power-loss behavior, original-
identity upgrades, real store restoration and device/feature acceptance remain
open. No default merge, deployment, store action or release is included.


The next isolated slice adds [retention of independently supplied evidence](recovery_retention_2026-11-10.md),
without changing this validator or granting imported data store authority.
