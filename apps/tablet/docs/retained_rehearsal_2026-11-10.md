# Retained isolated migration rehearsals

Date: 2026-11-10. Continues `e020c9b` on
`feat/migration-safety-recovery-20261110`. Release and original-installation
cutover remain held.

## Purpose and boundary

The raw source archive already has an explicit private retained-storage factory.
The coordinator's converted journal, media, aggregate and recovery receipt were
still limited to system temporary storage. This slice adds a separate retained
rehearsal destination so those converted copies can survive ordinary temporary
directory cleanup. It does not make a rehearsal the running app's live table.

Creation requires an explicit real parent directory and the existing measured
`LegacyRehearsalCapacity` policy. A dormant Android/iOS wrapper selects the
currently running app's private Application Support directory. Neither route
discovers an original installation, adopts an existing store, changes native
identity or permissions, nor runs from startup. The caller-selected parent API
cannot certify that its caller chose a durable private location.

Each retained rehearsal is a new uniquely named child with a distinct marker
and prefix. Retained and temporary reopen APIs preserve their own storage mode;
the temporary API does not gain access to arbitrary retained directories.
The mode, marker and canonical saved policy are checked before and after taking
the writer lease. Budgeted writes still require matching limits and a fresh
destination-volume probe. Unbudgeted retained creation is unavailable.

Retained files use the existing keep-all-until-explicit-review policy. Failed
attempts, prior evidence and later gameplay are preserved. No automatic expiry,
cleanup, migration trigger or rollback is introduced. Application Support is
still app-owned data: uninstall, OS behavior and device failure can remove it.
This is not a directory-fsync, power-loss, OS-backup or retention guarantee.

## Inspection and recovery

Inspection creates a new temporary clone, preserving its temporary identity
instead of copying the retained marker into it. Clone writes use the existing
measured policy; clone cleanup never removes the retained source. Physical
exports continue to include surviving data when a policy is damaged, through
the explicit recovery-only reopen path. Recovery-only and no-probe handles
cannot authorize semantic writes or promotion.

Canonical-path, symlink, coordination-alias, process-lease, source/destination
containment and later-game protection remain in force. The trusted native
Application Support path may resolve OS ancestor aliases such as iOS `/var`;
arbitrary caller-supplied parent aliases are refused.

## Validation

Frozen-source analysis is clean and 44 retained/dual-mode capacity tests pass.
An earlier broader 169-test run passed before the final creation-readback
refinement; it does not replace validation of the final source. Independent
review found no blocking issue after the native path correction. Full regression,
preview-namespace checks and web compilation are in progress. The prior
2,017-test checkpoint does not validate these factories. Final source identity
and results will be recorded before combined validation is claimed.

Review identified a trailing-separator final-symlink check in the initial native
factory. New Android/iOS path-provider regressions reproduced it before the
normalization fix. Retained creation now also strictly rereads the saved controls
before returning success; tests corrupt either policy or marker and verify that
the factory refuses while keeping the failed child.

## Remaining acceptance

Retained rehearsal storage closes the temporary-only development limitation.
It does not select production aggregate authority or a startup migration path.
Production sizing, live all-writer quiescence, actual shipped fixtures, native
support-directory/low-space/power-loss behavior, real original-identity updates,
store restoration, recovery save/restore UX and feature-parity decisions remain
open. External backup parsing/import needs a separate bounded untrusted-stream
validator before any quarantine restoration can be considered. No default
merge, deployment, store action or release is part of this checkpoint.
