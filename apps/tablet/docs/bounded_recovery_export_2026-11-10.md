# Bounded recovery export — 2026-11-10

Feature branch: `feat/bounded-recovery-export-20261110`, based on `698f1ce`.
This advances isolated M1/M4 recovery only. Production startup, source discovery,
original application identity/stores, schemas, versions, signing, default branch,
release and deployments are unchanged.

## Export and scope

`LegacyRecoveryExport` writes a new private child under an explicitly selected
parent. `LegacySourceArchive.exportRecoveryBackup` holds the archive lease;
`LegacyMigrationCoordinator.exportRecoveryBackup` holds coordinator then archive
leases throughout inventory, writing, source recheck and output verification.
The caller must supply quiescent source stores. These leases do not quiesce an
original installation's Hive, preferences, artwork or other writers.

Version 2 is an independently framed UTF-8 JSON Lines artifact:

1. Header: format `tripling-season-migration-recovery-stream`, version 2, UTC
   capture time, explicit scope and raw chunk size.
2. Named source: exact excluded top-level coordination lock names. Their bytes
   are deliberately excluded because opening/closing another descriptor can
   release process-wide POSIX locks.
3. Entry: exact relative key, kind and byte length for files, literal target for
   links, directory metadata, or an unavailable marker. Files are copied as
   ordered base64 chunks of at most 48 KiB raw bytes, followed by byte count,
   SHA-256 and a readable flag. Unknown/corrupt envelopes and pending files are
   opaque bytes; Hive, JSON records and original app recovery are not opened.
4. Source footer: stable-read result after rechecking keys, kinds, link targets,
   lengths and content hashes.
5. Hashed summary: complete/partial status, bounded problems and entry count.
6. Checksum-only trailer: SHA-256 of every exact preceding output byte, including
   the summary and all newlines. Completeness metadata is therefore independently
   verifiable too. Checksums provide integrity, not authenticity.

Hard-link aliases of coordination inodes are detected using filesystem identity
without opening them. Their relative key and coordination target are retained as
`coordination-alias` metadata, not copied lock bytes. Both physical stores share
lock identities, so an alias in the rehearsal cannot release the archive's lock,
or vice versa. This applies to combined legacy JSON diagnostics too.

The source trees and all prior outputs remain unchanged. Symlink roots/ancestors
and destination-inside-source overlap are refused before export creation.
Canonical paths are compared, with conservative case folding on Windows and
Apple platforms; distinct case-only paths can be refused rather than risking
self-inclusion. Private storage and cooperating writers remain required; hostile
path replacement or mount changes are not a supported threat model.

## Bounded resources and capacity

Payload memory is independent of file size and total archive size. Each read,
base64 conversion and awaited write is bounded and backpressured. Metadata is
bounded to 10,000 entries, 4 MiB, 32 named sources, 4 KiB per relative key and
64 KiB per literal link target. Exclusion metadata is also bounded. Exceeding an
inventory bound aborts before writing instead of silently omitting entries.

The required `LegacyRecoveryExportBudget` takes a caller-provided measurement of
available bytes on the **actual destination filesystem**. Unknown, negative or
failed measurements refuse export. A conservative encoded-size preflight includes
base64, chunk framing, metadata and completion overhead. Every write rechecks
remaining bytes and the reserve, as do flush and final verification. Defaults are
a 64 MiB reserve and 8 GiB output ceiling; callers can explicitly choose limits.
A probe is not an atomic reservation and cannot prevent another process using
space. I/O/flush errors remain authoritative and never report success.

There is no native free-space oracle in this checkpoint. Production must supply
and validate one for each supported platform and chosen private support volume.
A constant fake probe is appropriate only in tests. This budget also does not
reserve space for source capture, conversion, media promotion, a second user-save
copy or unrelated app operations.

The old JSON diagnostic path is now deliberately bounded: at most 1 MiB per
physical file, 10,000 keys, and 4 Mi UTF-16 code units of combined keys/values.
Oversize physical files are explicitly unavailable/partial; exceeding the
aggregate bound refuses serialization. It is not the full-archive solution.
The rehearsal adapter accepts explicit export options and returns a file-backed
`LegacyRecoveryBackup`; save hosts consume `openRead()`. Its `bytes` getter
refuses materialization, so an existing host cannot accidentally load the archive
into memory. No production destination picker or native save/share flow is added.

## Failure, cancellation and publication

- Each attempt uses a new child and `recovery.part`. No source or previous output
  is truncated, replaced or automatically deleted.
- Write, flush, capacity or cancellation failure preserves the attempt. Retry
  creates a separate attempt, never resumes an uncertain output in place.
- Only after flush, close, independent length/hash/trailer reread is the pending
  file renamed to `recovery-complete.jsonl` or `recovery-partial.jsonl`. The final
  file is independently rechecked again before success is returned.
- A cancellation or process exit after publication can leave a verified final
  file without an acknowledged result. Retry still preserves it and uses a new
  child. A `.part` file is never authority even if it contains a trailer.
- Source-read failure or change retains available bytes and publishes only an
  explicitly partial artifact. Destination failures are not caught as source
  failures. Footer problems are grouped/bounded and do not expose raw exceptions.
- Recovery-controller messages distinguish cancellation, unknown capacity,
  insufficient reserve, size limit and generic I/O failures. None suggests
  deleting source data, reset, repair, forced activation or clearing app storage.

Dart flush/rename does not expose directory fsync. No device power-loss,
filesystem crash ordering or OS data-protection guarantee is claimed. Repeated
failed attempts consume space; retention cleanup is intentionally not authorized.

## Validation

Flutter 3.41.2 / Dart 3.11.0 on cloud Linux. Published source `bc91c7a` has
exactly the locally validated tree `c4564e570365255fe238d179190a87c72e936946`
(local source commit `e8b74d6`). No package or lockfile change.

- `flutter analyze --no-pub`: no issues.
- New export suite: **27 passed**, including independent tampering of each
  hashed summary field.
- Full `flutter test --no-pub --reporter expanded`: **1,948 passed, 8 expected
  skips**, 6m25s.
- Explicit `phone_preview_v1` safety suite: **433 passed, 57 intentional
  same-app-only skips**, 28s.
- Release JavaScript web build: **passed**, 36.7s, including the optional Wasm
  compiler dry run. Browser and Wasm runtimes were not exercised.
- Formatting, whitespace checks and all 27 canonical-plan local links: passed.
- Independent final read-only review: no blocking findings. Identified path-case,
  coordination hard-link and exclusion-manifest concerns were addressed and
  re-reviewed before final validation.

No source or test changes occurred after the final validation run began. Earlier
checkpoints had a repeated adapter-test registration; it was moved outside its
unrelated boundary loop before this final run. The numbers above describe unique
registrations on the final source, not a sum of earlier runs. Native runtime,
original-identity updates and device/store acceptance are not claimed.

New coverage includes exact binary/corrupt/nested/link bytes, a 10 MiB file with
fixed chunks and a forbidden whole-file API, capacity preflight and reserve loss,
all cancellation/publication boundaries, source mutation, checksum corruption,
path rejection, aggregate JSON limits, both same-process leases, local/cross-store
hard-link aliases with actual cross-process POSIX exclusion probes, file-backed
adapter integration, and recovery-controller failure messages.

Linux `/dev/full` injects real kernel ENOSPC at the actual pending write/flush
awaits. Three subprocess cases exit the Flutter tester without Dart cleanup after
write, flush and publication, then verify retained attempts and reacquired leases.
These are not a physically exhausted destination volume or device power-loss test.

## Remaining acceptance gates

Production support-directory selection and backup/data-protection policy; a real
platform capacity probe and capture/conversion reserve budgets; retention and
user export/restore UX; live-writer quiescence and authority handoff; actual
shipped-installation fixtures; original-identity no-uninstall updates; native
full-device/quota/power-loss tests; real store restoration; platform/OS/device and
accessibility acceptance; parity decisions; and deliberate release approval all
remain open. A bounded rehearsal export does not collectively make updates safe.


## Publication

CLI push could not obtain credentials. The connected GitHub API published an
identical tree on `feat/bounded-recovery-export-20261110`; the remote ref was
fetched back and tree identity verified. The local source commit remains on a
checkpoint branch. The source checkpoint has no recorded statuses or GitHub Actions runs. No PR, default-branch merge, deployment, store action or release occurred.


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
