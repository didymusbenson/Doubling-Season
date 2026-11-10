# Retained source archive checkpoint — 2026-11-10

Status: isolated safety foundation, not production migration or release
acceptance. Branch `feat/durable-migration-capture-20261110`, based on integrated
checkpoint `4cf2441`. Original application startup, schemas, IDs, signing,
production stores, default branch and deployments are unchanged.

## Implemented boundary

`LegacySourceArchive` creates a new marked child beneath an explicitly supplied
private recovery parent. It does not choose temporary storage, discover a live
installation, or open the original Hive boxes. A future caller must choose a
real durable application-support location. Tests deliberately use temporary
parents; those test locations are not proposed production retention locations.

Capture takes only a caller-owned, quiescent offline directory plus the existing
explicit `LegacySourceLayout`. The existing source reader inventories and hashes
all files twice, preserving unknown files, old backups and unreferenced media.
It retains exact bytes before attempting adapter/schema/preference decoding.

- An immutable source layout and full capture manifest are retained before the
  first raw file. A retry with changed, added or removed source files cannot
  silently replace an interrupted capture's identity.
- Raw data, intent and final inventory use individual checksummed envelopes.
  Each new record uses an exclusive random pending file, followed by write,
  flush, close, independent readback, same-directory rename and final readback.
  A partial write cannot corrupt previously completed records.
- The final inventory is the completion boundary. It must match the original
  capture intent, and every referenced raw record must pass length/hash checks.
  This is rechecked during later journal preparation. A corrupt or unknown
  source can be wholly retained while still being refused for conversion.
- Complete archives reopen without the source directory. Incomplete archives
  require the same offline copy. Pending files remain available as evidence and
  are never mistaken for committed records, overwritten, promoted or cleaned up.
- A root-isolate restriction plus a per-path queue serializes same-process
  operations. A separate `archive.lock` inode excludes cooperating processes.
  Contention fails closed. The lock covers the whole capture or reopen operation;
  it is not a lease on the original installation's writers.
- Root/source overlap, symlink ancestors, record/lock links, unknown entries,
  incompatible layouts and invalid/corrupt envelopes are refused without repair.
  Publication assumes private app-owned storage and cooperating archive writers;
  hostile external path replacement is not a supported threat model.

The only change to the existing `LegacySourceReader` is an opt-in immutable
capture-intent write. Existing rehearsal storage formats and callers retain their
prior behavior. No coordinator/startup wiring or automatic activation is added.

## Validation

Flutter 3.41.2 / Dart 3.11.0 on the cloud Linux filesystem. Commands are run from
`apps/tablet`, with `BOT=true CI=true`, writable temporary HOME/XDG directories,
and the existing workspace PUB_CACHE. Flutter's documented bot mode was checked
against its source: it skips optional cloud metadata detection. Offline dependency
resolution succeeded without any dependency or lockfile changes.

- `flutter analyze --no-pub`: **no issues found**.
- `flutter test --no-pub test/legacy*test.dart
  test/historical_hive_fixtures_test.dart
  test/later_historical_hive_fixtures_test.dart
  test/table_startup_gate_test.dart`: **259 passed** (24s).
- Namespace check with `--dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1`
  covering archive, source reader, coordinator, rehearsal recovery, startup gate
  and storage namespace tests: **121 passed** (18s). The explicit file archive
  has no namespace selection and no production-store access.
- Formatting and `git diff --check`: passed.
- Independent read-only review identified changed-source retries and filesystem
  root overlap; both were fixed and re-reviewed with no remaining blocking issue.

New archive coverage uses real serialized Hive files and physical archive files:
exact source-byte preservation; copied preferences/media/unknown files; every
capture/write/flush/readback/publication/decode boundary; incomplete-file retry;
changed/added/removed source refusal; conflicting layout; invalid records and
missing capture intent; root overlap and links; same-process serialization and
non-root-isolate refusal; actual cross-process POSIX exclusion and lock release.

Three subprocess cases exit the Flutter tester immediately, without Dart cleanup,
after capture-intent write, final-inventory write and final-inventory publication.
The next process retains existing evidence and either finishes or reopens the
same capture. These prove process-exit handling on the tested Linux filesystem,
not device power-loss behavior.

Linux `/dev/full` produces actual kernel ENOSPC in two forms: injected boundary
failures before final-inventory publication, and test-only I/O wrappers around the
actual archive write/flush awaits. The write case first writes a real truncated
pending file, then propagates ENOSPC. In every case prior retained files and the
source remain byte-identical, no completed inventory is reported, and retry
succeeds without deleting evidence. **The destination volume was not filled.**
These tests prove error handling, not a physical full-device, OS quota or native
mobile storage acceptance case. Non-Linux platforms skip these Linux-only cases.

## Remaining release gates

- Production private support-directory selection, OS backup/data-protection
  configuration, free-space/reserve estimation, capacity UX, archive discovery,
  user export/recovery integration and retention duration are not implemented.
  There is no automatic cleanup. Repeated failed attempts can consume space and
  must fail closed until space or a new recovery destination is available.
- Dart file flush plus rename does not expose directory fsync guarantees.
  Directory-entry persistence and device/power-loss ordering require platform
  evidence before production durability claims. OS eviction protection depends
  on the future chosen support directory, not this API's name.
- The archive writer lease does not quiesce Hive, SharedPreferences, media writes
  or other live original-app writers. Cross-store production inventory/lease and
  authority handoff remain separate work.
- Actual shipped-installation copies, original-identity no-uninstall updates,
  native full-disk/process/device tests, store restoration, minimum-device/OS
  compatibility, rollout/rollback and acceptance of unresolved feature parity
  remain open. Full suite, web build and native checks are not claimed by this
  component record unless explicitly recorded later by integration.

No PR, main merge, deployment, store upload or original installation replacement
is part of this checkpoint. Migration/update safety is not collectively accepted.
