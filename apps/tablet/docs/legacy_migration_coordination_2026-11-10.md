# Guarded migration coordination (2026-11-10)

**Follow-up:** See [integrated recovery](migration_recovery_integration_2026-11-10.md)
for the native rehearsal adapter, physical export, additional authority checks
and final combined validation. This document records the original component.

**Release remains held. This is a native rehearsal, not production activation.**

`LegacyMigrationCoordinator` joins copied-source acquisition, conversion,
validated offline media and the actual Table aggregate format. It has no
production constructor, startup import, original-install writer, identity
change, release switch, sandbox discovery or deployment path. Only a new marked
`tripling-migration-rehearsal-*` direct child of the system temporary directory
can be created/reopened. No existing installation directory can be selected.

## Transaction and retry contract

1. Require a caller-owned offline copy and explicit source/version/capture
   evidence. Preserve the complete raw inventory before decoding through the
   unchanged original adapters. Two matching reads detect changes; they do not
   prove live multi-store quiescence. This component does **not** acquire a
   consistent snapshot from running original writers.
2. Reuse the complete retained raw archive on retry, including when the original
   copy was moved or removed. Missing/incomplete inventory still requires the
   same original offline copy. Verify layout, file paths, byte limits, lengths
   and hashes before decoding retained data. Never switch snapshots mid-retry.
3. Stage and verify conversion in the existing immutable journal. Unsupported
   mappings block activation. Informational mapping warnings are returned,
   including explicit four-seat/40-life fixture defaults and retained preferences.
   No purchase ownership is inferred from cached flags.
4. Retain an immutable promotion intent, tied to the transaction, source,
   inventory and initial aggregate digest. A prior Table, even an apparently
   blank fresh-install aggregate, is a conflict and is never replaced.
5. Decode every declared media asset with Flutter's image codec, reject invalid
   data, dimensions over 8192 on either axis / 16 megapixels total, animated
   images and data over 12 MiB. Publish content-addressed bytes to the actual
   Table media format, flush, hash-check readback and validate all local references.
   Missing files are a blocker, never an empty/default artwork substitution.
6. Promote exactly one aggregate `current` record using the same codec as normal
   `TableRepository` saves. That record includes the migration receipt. Media is
   flushed first, so interrupted staging cannot expose a partial game. No separate
   success flag is needed to decide whether promotion happened.
7. After uncertain acknowledgment, inspect the stored record. A matching valid
   receipt returns the existing game without rewriting it, even after later
   gameplay and rolling backups. Validate the returned game's media references.
   Conflicting receipts, unknown recovery authorities, damaged media or evidence,
   and unsupported records stop without reset, overwrite or silent repair.

Raw archive, conversion journal, intent and staged media have no automatic
cleanup. Original files are never opened with Hive or modified. Destination Hive
opens disable crash recovery and compaction, so corrupt tails are not truncated
and `.hivec` cleanup cannot occur. Unexpected files and symlinked boxes are refused
before opening storage. A paired concurrent observer drains Hive 2.2.3's internal
opening-error future; both failures are awaited, preventing a duplicate unhandled
error from bypassing a caller's recovery UI.

The `TableRepository` change factors its existing envelope encoder/strict decoder
into storage-free public methods. Normal gameplay continues using the same
format, checksum and schema validation. Encoding also refuses sequence exhaustion
before writing a generation that could not subsequently be decoded.

## Concurrency boundary

The coordinator serializes same-directory requests on the Flutter root isolate
and holds an OS file lock against cooperating separate processes. Background
isolate entry is rejected before file writes because POSIX advisory locks are
process-wide, while Dart static maps are isolate-local. This assumes one Flutter
root engine per process and exclusive use of the rehearsal directory. It is not
an all-writer production lease or protection against hostile filesystem mutation,
a second embedded Flutter engine, or unrelated code opening the same Hive files.

## Evidence

`test/legacy_migration_coordinator_test.dart` uses actual Hive source, archive,
journal, aggregate and media files. The successful result opens through the real
`TableRepository` and `TabletMediaStore` and retains original source file hashes.
The fixture image is a real decodable PNG; byte/hash-only fixture validation is
not evidence that an image can render.

Nineteen focused cases cover:

- Production-format aggregate/media readback, close/reopen and stable retry.
- Every reported capture/stage/media/promotion interruption boundary, including
  writes before acknowledgment, retried using fresh Hive instances.
- Later gameplay and its rolling previous generation unchanged on retry, even
  after the original source directory is moved.
- Missing/invalid source artwork, unsupported active rules, corrupt retained raw
  data, conflicting source identity/intent and pre-existing fresh tables.
- Missing/corrupt promoted media and missing new later-game media fail closed.
- Unknown coordinator/recovery records, overlapping source/destination paths,
  symlinked destination boxes, unsupported directories and foreign files.
- Concurrent root-isolate clients, rejection of background-isolate writers, and
  a physically corrupted Hive tail remaining byte-for-byte unchanged.

Fault callbacks model interruption/uncertain acknowledgments followed by Hive
close and reopen. They do **not** simulate process SIGKILL, power loss, fsync
ordering, disk exhaustion or native OS backup behavior. Cross-process exclusion
is an implementation contract, not yet a native subprocess/device acceptance test.

Validation in this checkpoint: 19 focused coordinator tests pass and analyzer
is clean. An earlier combined run before the last four coordinator regressions
passed 322 tests with one expected skip. Full-suite, preview-namespace and build
results are recorded below after completion, not inferred from focused checks.

## Remaining release gates

- Production archive location/retention/export policy, storage capacity handling,
  all-writer quiescence and same-identity startup orchestration remain unimplemented.
  Temporary rehearsal storage is not a durable user backup and may be OS-purged.
- An independent recovery view exists on another feature checkpoint; this engine
  has no UI adapter or production recovery routing yet.
- Actual shipped-version installation fixtures, every deployed historical schema,
  native process/device crash tests, real no-uninstall upgrades and supported
  platform/device floors remain unverified.
- Mapping warnings/defaults, unsupported semantics and missing/animated/oversized
  artwork need explicit product/recovery policy before production use.
- Real store purchase restoration, phone/tablet acceptance, accessibility and
  release authorization remain separate. The original app's existing startup
  implementation is not changed or made migration-safe by this dormant module.
