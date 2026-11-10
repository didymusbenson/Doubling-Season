# Rehearsal coordinator and recovery integration

Feature branch: `feat/table-migration-integration-20261110`.
This joins recovery checkpoint `7a76233` with coordinator checkpoint `a32a91f`.
**Release remains held.** No default-branch merge, deployment, original-identity
cutover, startup migration, or native installation is part of this work.

## Integrated behavior

`LegacyRehearsalRecoveryActions` is an explicit native adapter for the dormant
recovery view. It receives an already-created isolated rehearsal directory, the
same explicit source layout, and an optional caller-owned offline source copy.
There is no discovery of live installations or app-startup wiring.

- Inspection captures exact physical files under the coordinator's shared
  root-isolate and process lease. It opens no retained Hive boxes. A disposable
  marked clone is replayed through the real coordinator, image decoder and
  aggregate codec. A new promotion in that clone means **ready**, not complete.
  Only an already-promoted valid original receipt means **completed**.
- Retry inspects again, rejects a changed transaction, and checks the expected
  transaction before real journal commit or aggregate promotion. The normal
  coordinator still rechecks destination authority and media under its lease.
  It preserves later gameplay and never resets, silently repairs, or forces a
  conflicting destination. Inspection is not a reusable authorization token.
- The separate precreated `coordinator.lock` inode is never read during capture.
  This matters on POSIX: closing another descriptor for a locked inode can drop
  process-associated locks. An older rehearsal lacking the lock may gain this
  empty coordination file; retained record contents are never changed by checks.
- Backup captures every physical retained file, including raw archive, journal,
  control, aggregate, previous/recovery and media stores. Unknown/corrupt Hive
  bytes survive without decoding. Records in `rehearsal_files_base64_v1` are JSON
  objects containing `kind: file` and exact base64 bytes. Directory metadata and
  literal symlink targets are retained without following links. Known regular
  lock files are excluded. Files larger than 512 MiB are explicitly unavailable,
  making the export partial instead of attempting an unbounded individual read.
- The existing exporter rechecks the inventory and values and reports partial
  copies honestly. `complete` covers the supplied rehearsal files only, not the
  original installation, uncaptured source files, external link targets, a live
  multi-store atomic snapshot, or power-loss durability. Export uses the original
  retained files, never newly generated clone output. The envelope is retention
  evidence, not a restore/import program.
- Raw exception text is not displayed. Storage errors and unsupported Table
  formats receive controlled categories; other validation errors conservatively
  block as integrity/review issues. A real private save-new-file destination and
  production recovery routing remain unwired.

## Additional fail-closed checks

Review found and closed two gaps before exposing a verified report:

1. Unknown raw archive or journal keys now block coordination. They remain
   physically exportable. No future authority is guessed or ignored.
2. Previous/current generations must have compatible ordering. A newer previous
   record or equal-sequence different record blocks without selecting a winner.
   Identical pairs remain valid for an interrupted ordinary save.

The marker must be a regular file, never a symlink. Foreign entries, linked
stores, corrupt tails and unsupported data stay intact even when replay fails.
The lease protects cooperating clients of this implementation, not arbitrary
writers, hostile filesystem changes, or a second embedded Flutter engine.

## Validation

Validated source `e453ee2fd62f2cb05214e2a3f72bdea1283612f3`, tree
`1151604f3192140d708fe79f11f590d881911794`, using Flutter 3.41.2 / Dart 3.11.0.
The final validation follow-up changes documentation only. Remote and local
source trees match exactly. Earlier component-only counts remain historical.

- `flutter analyze --no-pub`: no issues. Three initial brace-style lints were
  corrected before restarting final full-suite and web-build validation.
- Focused coordinator/recovery/adapter tests: **56 passed** (37 existing plus
  19 new integration cases). They include empty/incomplete capture readiness,
  close/reopen retry, exact original inventory/hash retention, later gameplay
  and media, unknown/corrupt raw/journal/aggregate bytes, changed offline source,
  conflicting generation ordering and overlapping operations.
- A separate Dart subprocess confirms the POSIX lease remains held after a
  marker read and becomes available after the coordinator closes. This is a
  Linux host lock check, not a native device crash/power-loss test.
- Explicit `phone_preview_v1` combined legacy/catalog/save/support/storage
  tests: **310 passed, 57 intentional same-app-only skips**, no failures (20s).
- Release JavaScript web build passed with `/Doubling-Season/tablet/` and
  `--pwa-strategy=none` (72.8s). The optional Wasm compiler dry run also passed;
  neither result establishes browser interaction or Wasm runtime acceptance.
- Independent static review found no remaining must-fix correctness issue
  within the documented rehearsal/cooperating-writer boundary after resolving
  the authority-order, unknown-record and lock-inode findings.
- Full `flutter test --no-pub`: **1,825 passed, 8 expected skips**, no failures
  (7m18s). This run includes all 56 coordinator/recovery/adapter cases on the
  final source. The 8 skips are pre-existing/namespace-specific checks.

Commands from `apps/tablet`:

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 \
  test/legacy_*test.dart test/catalog_compatibility_test.dart \
  test/table_repository_compatibility_test.dart test/support_continuity_test.dart \
  test/storage_namespace_test.dart test/update_foundations_integration_test.dart
flutter build web --release --base-href /Doubling-Season/tablet/ --pwa-strategy=none
```

The source commit had no recorded GitHub commit statuses or PR-triggered
workflow runs. All 44 local links checked in the current plan, Table README and
integration record resolve, and `git diff --check` passes. No PR, default-branch
merge, deployment, Android/iOS build, native installation update, real purchase
restoration or release was performed.

## Remaining release gates

Temporary rehearsal storage can be purged by the OS. Durable production archive
location/export/retention policy, full-disk behavior, original all-writer
quiescence, actual shipped-version fixtures and same-identity startup routing
remain open. Process kill/power-loss behavior, physical no-uninstall upgrades,
real purchase restore, supported OS/device floors, phone/tablet accessibility
and hands-on acceptance remain separate. The original application's existing
startup recovery path is unchanged. This is not a migration-safe release claim.
