# Retained capture capacity and storage policy

Date: 2026-11-10. Base: `29a922e`, migration integration feature branch.
Release remains held. This is dormant migration infrastructure, not a production
startup trigger, original identity change, native update or release approval.

## Explicit storage and retention

`LegacySourceArchive.createInApplicationSupport(capacity: ...)` is an opt-in
Android/iOS entry point. It uses `path_provider`'s private Application Support
location for the **currently running app identity**, resolves legitimate OS
ancestor aliases (including iOS `/var`), and creates a new uniquely named child.
It never falls back to temporary, cache, Documents, shared or another app's
storage. Unsupported platforms and failed location lookups refuse the operation.
The supplied root must be an absolute real directory, not a final symlink even
when the platform path has a trailing separator. No startup route calls it.
The existing caller-selected `createIn` entry point remains available for offline
fixtures and isolated rehearsals; it does not certify the supplied location.

The only implemented retention policy is **keep everything until explicit
review**. No automatic deletion, retention duration, expiry, cleanup, backup
exclusion setting, namespace migration or permission change is introduced.
Original sources, completed records and incomplete attempts are preserved.
The OS can still remove an app's data on uninstall, and support-directory choice
alone is not a claim of power-loss safety or cloud/OS backup behavior.

## Measured capture budget

New `LegacyArchiveCapacity` requires an explicit maximum total archive size and
an explicit positive conversion reserve. Safety reserve defaults to 64 MiB and
must remain positive. Each of these values is bounded at 8 GiB. The values are
caller-supplied planning limits, **not an approved production sizing policy**.
Use `const NativeRecoveryCapacity().availableBytes` for the actual destination
volume probe once native selection is authorized.

The archive records its canonical versioned policy and a distinct budgeted
marker before capture. A restart can read retained data without a probe, but
capture requires a fresh callback with exactly the same saved limits. Existing
unbudgeted archives cannot silently adopt a policy. Missing, malformed or changed
policies refuse semantic reading/capture through normal reopen. A stale handle
revalidates the saved policy before obtaining the existing archive lease on each
operation.

Checks run before creation, before each physical record write, and after verified
write/flush/readback but before publication. Available space must cover the
prospective write **plus both reserves**. Unknown/negative/failing measurements
refuse writes. Already retained files, policy/marker bytes, and every unfinished
attempt count toward the maximum archive size; retries do not reset accounting
or free old attempts. ENOSPC and other I/O failures retain their existing safe
failure behavior. No complete inventory is published before its final reserve
check.

This is a check, not a filesystem reservation. Directory blocks/filesystem
metadata, concurrent unrelated writes, delayed allocation and process/device
power loss can still cause failure. The acquisition still uses the reader's
bounded in-memory source handling; this change does not claim streamed capture.
The capacity ceiling is per archive, not across all archives. The measured free
space reserve constrains new attempts, and nothing is deleted to make room.
A failure during archive creation may leave an unmarked child; keep it for
physical review rather than treating it as a usable archive or deleting it.

## Recovery remains possible

`reopenForRecovery` validates the recognized archive marker and safe coordination
structure but does not decode a missing/damaged capacity policy. Its capability
is physical backup/export only: capture, decoded source access and rehearsal
transfer are refused. Ordinary archive objects also retain this forensic export
route if policy damage is discovered after opening. Policy bytes and unknown
files are retained exactly by the existing bounded exporter; coordination aliases
are never opened as ordinary files. A complete physical export does not mean the
source is valid or safe to activate.

## Validation and remaining gates

The Dart regression suite uses real filesystem archives with injected
measurements and mocked native location selection, not an actual full mobile
filesystem. Separate native smoke validation is recorded below. Tests cover
creation refusal, exact reserves,
interruption, retained-attempt ceiling, restart policy enforcement, native path
selection/refusal, coordination aliases, damaged-policy forensic recovery and
read-only transfer into the existing isolated rehearsal coordinator.

Still required: deliberately chosen production limits based on complete capture,
conversion, journal/media promotion, export and host-save sizing; independently
measured conversion/promotion writes; native support-location/OS retention
acceptance; live writer quiescence and source authority; genuinely shipped source
fixtures and original-identity no-uninstall updates; recovery/save UX; store and
feature-parity acceptance. Holding headroom during capture does not implement or
validate a conversion/promotion write budget.

No dependency/lockfile, original startup, native identity/version, permission,
cleanup, PR, default-branch merge, deployment or store action is changed.


## Final validation

Runtime source is `49409136c13c04651db24d0b4cc181b977d4afdb`. Test-only portability
fix `d13981cfe30005807b90a5fb2400871c6b5897cb` canonicalizes the macOS temporary
fixture parent; production source is identical. Final Linux verification ran
against that exact test checkpoint with Flutter 3.41.2 / Dart 3.11.0:

- `flutter analyze --no-pub`: **no issues**, 1.9 seconds.
- Full `flutter test --no-pub --reporter expanded`: **1,994 passed / 8 expected
  skips**, 6m14s. An earlier complete run also passed; this rerun includes the
  final macOS fixture correction.
- Explicit `phone_preview_v1` safety selection: **479 passed / 57 intentional
  same-app-only skips**, 46 seconds. This ran against `4940913`; the later change
  affects only the fixture's temporary-directory canonicalization.
- Release JavaScript web build: **passed**, 57.0 seconds, with successful optional
  Wasm compiler dry run. Browser/Wasm runtime behavior was not tested here. Same
  runtime source as the final checkpoint.
- Independent static review: no blocking findings. Its policy-corruption export
  finding was fixed with the recovery-only capability and regression tests before
  final validation.
- Whitespace checks and all local documentation links: passed.

[Native validation](native_capacity_validation_2026-11-10.md) is incorporated from
`bca234402a709b943bf0c4b6dac714da6577ac10`. Baseline normal-entrypoint Android debug,
iOS simulator and unsigned iOS device compilation passed. New factory runtime
source `4940913` was separately built and exercised on fresh iOS 26.2 and Android
15/API 35 test identities: **17 factory assertions + 18 bridge assertions passed
on each platform**. These cover the actual native Application Support provider,
actual-child native capacity measurements, exact persisted policy, synthetic
capture, strict/read-only/recovery-only reopening, and unchanged source/archive
bytes. Test archives remain preserved. Final Mac analysis was clean and all
**33 focused native-bridge + archive-policy tests passed** at `d13981c`.

The first Mac host test run had 17 fixture path failures; these are not counted
as passing. The test-only fix and successful rerun are recorded in the native
report. No production-code defect was found by that native follow-up. Neither
simulator/emulator runs nor unsigned compilation are physical-device, full-disk,
original-installation, signed-release or store acceptance.

Reproduce the namespace selection from `apps/tablet`:

```sh
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

The Git CLI lacked push credentials; the authorized GitHub connector published
identical trees, then branches were fetched and compared locally. No statuses or
PR-triggered workflow runs were recorded for source checkpoint `d13981c`.
No PR was opened. The feature branch also incorporates the native evidence docs;
these final validation additions do not change tested runtime or test code.
