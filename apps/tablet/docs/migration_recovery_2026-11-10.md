# Explicit migration-recovery surface

**Follow-up:** The [coordinator integration](migration_recovery_integration_2026-11-10.md)
adds a native rehearsal adapter and supersedes the missing-adapter status below.
The original component-only evidence remains historical. Production routing and
a real save-destination flow remain unwired.

This feature-only checkpoint adds a dormant recovery surface for copied-source
migration rehearsals. It does not wire original-installation startup, change
identities/storage, select a production source, activate migration at boot,
restore an old game, or authorize a release.

## Implemented contract

- `LegacyRecoveryReport` presents interrupted, blocked, ready and verified
  rehearsal states. Typed issues explain storage, integrity, unsupported data,
  missing artwork and destination-conflict next steps. A blocked/completed
  report or unresolved issue cannot expose retry, even when an adapter says it
  is retryable. Unsupported content is not silently skipped.
- `LegacyRecoveryController` serializes its check/retry/export operations.
  Duplicate clicks cannot start another operation. An uncertain operation
  requires a fresh inspection before retry; known transaction identity stays
  visible. Raw thrown exceptions are not copied into diagnostics, because they
  can contain complete private source records. Expected backend issues should
  be returned as controlled typed reports.
- `LegacyMigrationRecoveryView` exposes Check again, Retry safely when allowed,
  Save recovery copy and explicitly copied technical diagnostics. It has no
  reset, clear, skip, overwrite or forced activation action. The view scrolls on
  narrow screens and large text; the host owns its lifetime and controller.
  Dismissal does not cause a late backup collection to open a save dialog.
- `LegacyRecoveryBackup.capture` receives only read capabilities for explicitly
  named migration record stores. It preserves exact strings, including corrupt,
  unknown and opaque records, in a checksummed JSON envelope. It does not
  deserialize then re-encode original record contents. Every source inventory
  and available value is checked again for changes. Read/inventory failures and
  observed changes mark the copy incomplete while retaining all readable bytes.
  No source writes, cleanup or restore operation exists in this exporter.
- The host supplies an explicit save-new-file callback. Cancellation, failed
  saves and partial copies have distinct in-context results. No sharing or
  upload is automatic. The user is reminded that the copy contains private data
  and does not replace keeping the original installation and artwork files.

## Integration boundary

`LegacyRecoveryActions` is the small backend boundary: `inspect`, `retry`, and
`createBackup`. Inspection must be read-only; retry must inspect uncertain
outcomes before acting, be idempotent, and protect existing/later gameplay.
Backend locking is still required across multiple controllers or other writers.
The callback host must save to a new file and must never target original data or
migration stores. A `true` result means the save actually completed; cancelling
the destination picker must return `false`.

This checkpoint has **no concrete production or rehearsal adapter/route yet**.
The concurrent rehearsal coordinator is being implemented separately; its
adapter must expose every relevant retained store, serialize export with its
other work, and translate failures into typed reports. A real local save flow,
reopening the exported envelope, and integration against actual Hive records
remain to be validated after that adapter exists. Do not describe the standalone
widget as a released or end-to-end recovery flow.

A recovery envelope is a developer-readable retention artifact, not an
executable restore/import format. Its `complete` flag means all declared record
stores could be enumerated/read/rechecked without an observed change. It is
not a guarantee of an atomic multi-store snapshot or an original-installation
backup. Unprovided external files are out of scope. Keep the original records;
never clear storage just because a copy was saved.

## Validation

Flutter 3.41.2 / Dart 3.11.0, from `apps/tablet`:

- `flutter test --no-pub test/legacy_migration_recovery_test.dart`: 18 passed.
- Scoped `flutter analyze --no-pub` on the two new implementation files and
  recovery test: no issues.
- Regression cases cover opaque/corrupt retention, unreadable inventories and
  records, mutations during export, duplicate/empty source validation, blocked
  retries, uncertain outcomes, repeat clicks, disposal, cancelled/failed/partial
  saves, immutable reports, no destructive controls, and a 320×568 logical
  viewport with 2× text. These are automated widget/model checks, not native
  device acceptance.
- An external temporary widget harness renders the blocked recovery surface for
  a visual layout check. It is not a browser/native launch or a production route.
- No full-suite, web build, native installation/update, store acceptance, merge
  or deployment is claimed by these focused results. The integration checkpoint
  must record final combined validation separately.
