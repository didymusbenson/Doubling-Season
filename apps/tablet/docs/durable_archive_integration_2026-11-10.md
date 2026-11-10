# Durable archive and rehearsal integration — 2026-11-10

Feature branch: `feat/table-migration-integration-20261110`. Integrates retained
source archive `e664313` atop validated checkpoint `4cf2441`. Release remains
held: no production startup/activation, original app store or identity change,
PR, default-branch merge, deployment, store upload or installation replacement.

## Verified contracts

- The coordinator accepts either a complete retained archive or an explicit
  offline copied directory, never both. Archive transfer runs under coordinator
  then archive leases. It verifies layout, capture intent, final inventory and
  every raw-file hash before staging. Supplying an archive on retry rechecks it,
  even when an internal copy or promoted table already exists.
- The isolated rehearsal receives all verified original raw records, including
  unknown files and unreferenced media. Transfer writes an immutable capture
  intent first and completed inventory last. A conflicting complete or partial
  source cannot be substituted, including by changing to the old directory-copy
  API. No missing source file is inferred to be an empty store.
- Once transfer is complete, the rehearsal has self-contained raw recovery data.
  It can retry without the original offline copy. Existing generation/receipt
  checks still preserve later gameplay and previous generations exactly.
- Recovery inspection runs in a disposable clone without changing either source
  archive or retained rehearsal. The adapter passes the archive through guarded
  retry. Combined backup holds both leases and retains exact physical records
  from both stores, including incomplete/corrupt records, pending attempts,
  opaque files, nested directories and literal link targets. Coordination lock
  inodes are excluded without opening extra descriptors.
- The physical-file recovery helper is now shared. It bounds individual reads,
  rejects unsafe paths and symlink roots/ancestors, preserves unknown entries,
  and performs a stable second read. Partial/unreadable exports are explicitly
  incomplete; no repair, reset, original-app writer or cleanup was added.

## Filesystem defect found and fixed

On the tested Linux filesystem, Dart's normalized directory URI adds a trailing
separator. `FileSystemEntity.type('link/', followLinks: false)` consequently
followed a directory link. Tests reproduced three defects before the fix:
archive creation wrote marker/lock files through a linked parent before refusing,
archive reopen accepted a linked root, and copied-source reading accepted a
linked root. Root normalization now strips non-root trailing separators before
all root/ancestor checks. The regressions assert refusal, no retained acquisition
records and byte-identical target directories. Root/drive separators remain valid.

## Verification

Flutter 3.41.2 (`90673a4eef`), Dart 3.11.0, cloud Linux filesystem. No package,
lockfile, application version, signing or original Hive schema changes.

- Analyzer: no issues.
- Coordinator/recovery/archive integration: **51 passed**, including all reported
  transfer/promotion interruption boundaries, source disappearance, genuine
  repository/media reopen, conflicting source, later gameplay, non-mutating
  inspection and combined exact backup of incomplete/unknown/pending evidence.
- Archive/source-reader/physical-file regressions: **55 passed**, including the
  three symlink-root cases that failed before the fix. Existing POSIX lease,
  abrupt-process-exit and ENOSPC component cases remain included.
- Full `flutter test --no-pub --reporter expanded`: **1,920 passed, 8 expected
  skips**, 6m55s.
- Explicit `phone_preview_v1` safety suite: **405 passed, 57 intentional
  same-app-only skips**, 48s.
- Release JavaScript web build: **passed** (59.5s), including the optional Wasm
  compiler dry run. Browser runtime, Wasm runtime and native acceptance were not run.
- Independent read-only review found no remaining blocker in the final code,
  including the normalization fix. All 26 canonical-plan local links resolve;
  authored diffs pass whitespace checks.

Published source commit: `7dfd489c427fc5f9a3d5036cd2c11298ec7200e1`, tree
`12c3d3b6faefa1f45993701641b0aa6859ebe8b5`. This exactly matches locally validated
source commit `00a8ffe3b5645667ea63ae3d99c669ec3973849b`. Command-line push could
not obtain credentials, so the connected GitHub API published the identical tree
and advanced the feature ref without force against the verified expected head.
The remote was fetched back and its tree matched. The local validation commit
was retained on a backup branch. This validation record is a docs-only follow-up;
no source/test files changed after validation started.

The source commit has no recorded commit statuses or PR-triggered workflow runs.
No PR or CI run was created. Android/iOS builds, native original-installation
updates, store restore and device acceptance were not run. Feature-branch
publication did not merge or deploy anything.

Commands from `apps/tablet`:

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test --no-pub --reporter expanded \
  --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 \
  test/legacy_*test.dart test/historical_hive_fixtures_test.dart \
  test/later_historical_hive_fixtures_test.dart test/table_startup_gate_test.dart \
  test/catalog_compatibility_test.dart test/table_repository_compatibility_test.dart \
  test/support_continuity_test.dart test/storage_namespace_test.dart \
  test/update_foundations_integration_test.dart
flutter build web --release --no-pub \
  --base-href /Doubling-Season/tablet/ --pwa-strategy=none
```

## Remaining work and acceptance limits

This closes explicit archive-to-rehearsal/recovery orchestration, not production
storage orchestration. The caller still chooses the archive parent. Durable
application-support selection, OS backup/data protection, discovery, capacity and
reserve policy, lifetime/retention policy, user save destination and production
startup remain unimplemented. No original live-writer quiescence or authority
handoff is claimed, and temporary rehearsal files remain evictable.

The combined JSON backup materializes all records in memory. Individual file
bounds do not bound aggregate export memory or disk requirements. Repeated
pending attempts remain retained and consume space. A bounded/streaming export
format, capacity failure UX and real full-device evidence are still needed;
these tests do not establish production large-archive or full-device safety.

Actual shipped-installation copies, native device/power-loss durability,
no-uninstall same-identity updates, real store restoration, device/OS coverage,
accessibility, parity decisions and deliberate release approval remain separate
open gates. No collective migration/update-safe or release-ready claim is made.
