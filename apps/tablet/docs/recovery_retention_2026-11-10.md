# Retaining external recovery evidence

Date: 2026-11-10. Continues `dddf5c4` on
`feat/migration-safety-recovery-20261110`. Release and original-installation
cutover remain held.

## Concrete gap and scope

The read-only validator can inspect an explicitly supplied backup stream, but it
cannot keep those exact bytes after the external source disappears. This slice
adds a measured-capacity evidence copy into a new caller-selected private child,
followed by validation of the flushed, reopened local artifact. It does not
extract embedded files, import a store or restore any game.

Only application-generated fixed filenames are used. Imported source labels,
entry paths, links, archive markers, aggregate records and other control files
remain bytes inside the opaque backup. They cannot select filesystem targets,
open Hive, grant store authority or activate migration. Existing input stores,
prior attempts, current gameplay and original-installation data are not adopted
or overwritten. No startup caller or native identity change is introduced.

The caller owns the upstream stream and must select a private parent under its
exclusive control. Portable Dart does not provide an atomic no-follow/no-replace
filesystem transaction against a concurrent hostile directory writer. Observable
aliases and destination collisions must be refused; private-directory ownership
is still required. No permission changes are introduced.

## Retention and verification contract

`LegacyRecoveryRetention.retain` takes a byte stream and
`LegacyRecoveryRetentionOptions`: a real parent, explicit
`LegacyRecoveryExportBudget`, validation limits and optional cancellation.
There is no default destination, native factory, restored store or persisted
receipt authority. The selected parent is not automatically certified durable
or private; tests deliberately select their own temporary parent.

Copying uses at most 48 KiB owned buffers per write, with backpressure and fresh
capacity checks. Stream size/events, validation limits and a total elapsed
budget are explicit. Event length is fixed before awaiting writes, so a
producer growing its list cannot bypass the byte bound. No producer buffer is
hashed after it has been handed to an asynchronous writer.

The file is flushed and closed before validation. Length and whole-file SHA-256
are checked in the same read pass that feeds the strict validator, binding its
result to the exact incoming copied bytes. Readback checks are repeated before
and after rename, with fresh reserve checks after flush and around publication.
The validator's own digest excludes the checksum footer, so a separate
whole-file digest is retained in the result.

The new child contains `recovery.part`, renamed to `recovery.v2.jsonl` only after
verification. That filename is not migration authority. A pre-existing publish
target is refused, not overwritten. Failed or canceled attempts may include a
published-but-unverified file and remain evidence, never a success result.
No cleanup, expiry or automatic adoption of a prior attempt is introduced.

Every awaited operation is guarded before issuance and after completion.
Cancellation/deadline expiry cannot schedule later successful steps. Already
issued OS writes or renames cannot be revoked; they may complete after a failure
is reported. A busy file handle is closed after its outstanding operation
settles rather than issuing a conflicting close. The caller still owns upstream
allocation/cancellation behavior, and portable Dart cannot preempt hostile
synchronous producer code or guarantee completion of a hung OS operation.
Failure diagnostics are generic and do not reveal input contents or raw producer
exceptions. No directory-fsync, power-loss or OS-retention guarantee is made.

A valid partial export remains explicitly partial. Invalid, interrupted,
canceled and failed attempts remain evidence and are never silently removed.
A retry uses a new child. Integrity is not authenticity, a quiescent-source
snapshot, original-installation coverage or restore readiness.

## Validation

Before the full regression checkpoint, the focused retention suite passes
**23 tests** and full `flutter analyze --no-pub` reports **no issues** (1.5s).
Full/namespace regression, release web compilation and the unchanged standalone
JavaScript validator harness remain in progress. No update-safety or release
claim is made.

Focused coverage includes:

- Real exporter complete/partial/unstable artifacts; exact retained length and
  whole-file digest; forged control files remaining inside opaque evidence.
- Arbitrary framing, empty/invalid/truncated/trailing bytes, producer errors,
  all-limit preflight, mutable event growth and bounded event consumption.
- Unknown, insufficient and changing measured capacity, including final reserve
  loss; no input consumption on a failed initial preflight.
- Cancellation/deadline interruption of stalled input, capacity callbacks and
  fault boundaries, including synchronous cancellation followed by an exception.
- Kernel `ENOSPC` from `/dev/full` injected during a real pending write after a
  17-byte prefix, and during flush. Delayed write/flush futures prove handle
  closure waits for the outstanding operation to settle after cancellation.
- Abrupt subprocess exits after write, flush and publication, followed by a new
  successful attempt while the earlier bytes and original source stay intact.
- Readback/publication corruption, observed destination collisions, symlink
  parents/ancestors and exact-input verification. Boundary-thrown failures are
  distinguished from the actual write/flush fault injection above.

These are Linux fault tests, not a physical full volume, device power loss,
platform retention acceptance or an original installation update.

## Remaining acceptance

No opaque-file extraction, quarantine semantic decoding, restoration,
user-selected save/import UI or production authority is added. Those boundaries
must not be inferred from a successful retained-file result. Genuine shipped
fixtures, live all-writer quiescence, production sizing/startup policy, native
low-space and power-loss behavior, original-identity no-uninstall updates,
real store restoration and device/feature acceptance remain open. No default
merge, deployment, store action or release is included.
