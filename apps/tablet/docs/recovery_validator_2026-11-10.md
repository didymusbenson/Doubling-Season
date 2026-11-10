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

Before the full regression checkpoint: **52 focused tests pass**, analysis is
clean, and **9 standalone Dart-to-JavaScript/Node checks pass**. Full tests,
namespace regression and the release web build are in progress. No completed
update-safety or release claim is made.

Review caught two resource-amplification risks during implementation: repeated
cancellation listeners and expanded path prefixes. A removable single waiter,
input-event budget, path-depth limit and measured path-index budget now cover
those cases. A separate JavaScript runtime check reproduced an integral-double
JSON discrepancy (`2.0` passed an `int` check under JavaScript). Pre-decode
canonical integer tokens within the exact shared numeric range now reject
fraction, exponent, negative-zero and unsafe-precision forms consistently.
The final JavaScript smoke passes after this fix. No data restore was attempted.

## Remaining acceptance

No quarantine extraction, restore destination, overwrite, app activation or
recovery UI is introduced. Independent backup inspection must remain separate
from any later explicit, capacity-checked quarantine import and semantic
revalidation. Genuine shipped fixtures, live source quiescence, production
startup/authority and sizing, native low-space/power-loss behavior, original-
identity upgrades, real store restoration and device/feature acceptance remain
open. No default merge, deployment, store action or release is included.
