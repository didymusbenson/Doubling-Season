# Measured conversion and promotion capacity

Date: 2026-11-10. Continues retained capture checkpoint `2e5c094` on an isolated
feature branch. Production startup, original application identity, signing,
store actions, default-branch merge, deployment and release remain held.

## Explicit rehearsal policy

`LegacyRehearsalCapacity` adds an optional measured-write policy to
`LegacyMigrationCoordinator.createRehearsal` and `reopenRehearsal`. The caller
supplies the destination-volume probe and a positive retained-byte ceiling.
The positive safety reserve defaults to 64 MiB. Each limit is capped at 8 GiB.
These are isolated test/rehearsal controls; no production sizing decision is
made. Capture's separate conversion reserve is headroom to fund this work,
not an extra permanent reserve silently added to the conversion policy.

Budgeted rehearsals retain a distinct marker and canonical versioned policy.
Writes require a fresh capacity callback with the same saved limits. Reopening
without a callback does not grant write permission. Existing unbudgeted fixture
rehearsals keep their prior behavior and cannot silently adopt a policy. Stale
handles recheck retained identity and policy before work under the writer lease.
No automatic expiration, deletion, truncation or cleanup is introduced.

Every physical file counts toward the retained ceiling, including incomplete
append tails. Logical record counts are not a substitute for physical bytes.
Checks cover creation, Hive opening, raw source transfer, journal source/media/
candidate/current records, control intent, production-format media, and the final
aggregate. The implementation checks before each append and after flush/readback.
It charges encoded JSON/base64 envelopes and Hive framing rather than only the
original source or image length. Unknown, invalid or failing capacity readings
refuse progress. Capacity errors appear as storage issues in rehearsal recovery.

The unencrypted Hive 2.2.3 String-key/String-or-Uint8List frame is exactly
`15 + utf8(key).length + payloadBytes`: length/CRC bytes, key framing, and typed
value/count framing are included. Real Hive append-growth regressions verify
this with Unicode and byte payloads. Empty box creation has no data header;
zero-growth checks surround opens. Compaction and crash recovery remain disabled.
Nonempty Hive coordination files are refused before Hive can truncate their
contents. The coordinator's separate append-only lease keeps its existing
cross-store alias validation.

These checks do not reserve filesystem blocks. Directory and filesystem metadata,
other processes consuming space, delayed allocation, quotas and power loss can
still produce failures. Native low-space and full-disk acceptance remain open.

## Retry, inspection and recovery

An insufficient reserve detected after the aggregate write is a failed or
uncertain acknowledgement. The aggregate remains intact. Retry checks its
receipt and preserves later gameplay and previous generations rather than
undoing or repeating promotion. Existing matching records are verified without
another append; damaged or missing authoritative artwork still requires review.

Inspection keeps the original physical evidence unchanged. Its temporary clone
inherits the same limits and a fresh probe, measures the actual clone destination,
and guards every copied file plus subsequent conversion writes. A no-probe or
recovery-only handle cannot use inspection as an unbudgeted mutation route.
Only the newly created disposable inspection clone is removed afterward.
Inspection still uses the existing in-memory physical snapshot; this slice does
not introduce streaming conversion or bounded-memory clone inspection.

`reopenForRecovery` retains physical export when a budget policy is missing or
damaged. It does not authorize semantic decoding, capture, inspection or
promotion. The separately budgeted streaming exporter includes damaged policy
bytes and other surviving evidence exactly. Marker/policy and content aliases
to coordination files are refused before opening them, preserving the POSIX
lease protections. A complete physical export is not proof of safe activation.

## Validation

Validated source: `8773a1cdba6983ba64f07b40baec50c011a76b7c`, tree
`98ef0befb99643e60d35e4d049d85d00d9799d3b`, on
`feat/migration-safety-recovery-20261110`. The remote source tree was fetched and
compared exactly with the local tree. Only this validation documentation changes
after the checks. Flutter 3.41.2 / Dart 3.11.0 on cloud Linux:

- `flutter analyze --no-pub`: **no issues**, 1.9 seconds.
- Capacity, coordinator and archive-integration selection: **66 passed**,
  14 seconds. Rich migration tests fail each successive capacity check and
  verify safe retry, unchanged source and retained prior evidence.
- Full `flutter test --no-pub --reporter expanded`: **2,017 passed / 8 expected
  skips**, 5m47s.
- Explicit `phone_preview_v1` safety selection: **502 passed / 57 intentional
  same-app-only skips**, 32 seconds.
- Release JavaScript web build: **passed**, 39.0 seconds. Optional Wasm compiler
  dry run passed; no browser or Wasm runtime acceptance is claimed. Flutter still
  warns that the existing `--pwa-strategy` option is deprecated.
- Independent source review: no blocking findings, including final lock handling
  and post-lease policy revalidation.
- Whitespace checks and all **36 local documentation links** in the changed
  records/current plan: passed. Both dependency lockfiles are unchanged.

Initial analysis reported two brace-style lints, corrected before the clean run.
An overly broad nonempty-lock guard changed four existing cross-store alias
diagnostics; restricting it to Hive's truncating lock files restored those
regressions. An earlier test command also named a nonexistent journal test file.
The corrected 66-test and full runs have no selection errors or failing tests.

The official SDK and 187 hosted dependency archives were checksum-verified;
normal offline resolution used the existing lockfiles. Online Dart dependency
resolution stalled, so it is not claimed as successful. No SDK source, package
version or lockfile was altered to obtain a test pass.

No commit statuses or PR-triggered workflow runs were recorded for the source
commit. No PR, default-branch merge, deployment, native build/update or store
action was performed. Prior native bridge/factory evidence remains tied to its
own earlier checkpoint, not these new guards.

Reproduce from `apps/tablet` with the pinned SDK and resolved dependencies:

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
```

## Remaining gates

Production limits still need evidence covering the complete capture, conversion,
promotion, export and host-save lifecycle. The coordinator remains confined to
temporary rehearsals; private retained production authority and startup are not
wired. A subsequent [retained rehearsal slice](retained_rehearsal_2026-11-10.md)
adds explicit budget-required isolated retained storage; the temporary-only
boundary above describes this earlier checkpoint. Live writer quiescence,
genuinely shipped source fixtures, original-
identity no-uninstall updates, recovery/save/restore UX, real store restoration,
platform/device/accessibility acceptance and feature-parity decisions remain
required. No collective migration/update-safe or release-ready claim is made.
