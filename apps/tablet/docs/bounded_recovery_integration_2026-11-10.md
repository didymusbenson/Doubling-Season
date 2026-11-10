# Bounded recovery integration — 2026-11-10

Feature branch: `feat/table-migration-integration-20261110`, continuing `698f1ce`
with bounded-export `6515ace`. This is isolated migration safety work. The
explicit original-installation/release hold remains in force.

## Cross-component evidence

The real-Hive archive integration suite now has eleven additional regressions:

- Captured immutable source → interrupted rehearsal → recovery controller →
  file-backed export → explicit host save → independent stream verification.
- The same path after promotion and later gameplay preserves current and prior
  repository files exactly. Exporting cannot replay migration over later play.
- Corrupt archive envelopes and unknown pending evidence remain byte-exact in a
  physically complete export while inspection continues to block activation.
- Independent test decoding checks the exact stream checksum, source names,
  per-file framing/length/hash, chunk bound and original physical bytes.
- Capacity disappearing after the first write prevents host delivery, preserves
  the pending artifact and source stores, and allows a new independent retry.
- Host cancellation or failure preserves the verified first output and inspection
  report. A second attempt creates a separate artifact without altering it.
- Simulated uncooperative source mutation yields only an explicitly partial copy
  and visible incomplete-copy message. The exporter retains the earlier bytes;
  it never claims its leases quiesce an unrelated writer.
- Both direct transfer and clone-only inspection reject archive layout/inventory
  records hard-linked to the original coordinator lease before opening them.

A complete export means the supplied physical stores were copied and verified.
It does not certify semantic validity, a consistent live-installation snapshot,
restorability through production UX, or a migration-safe update.

## Coordination hardening

Independent review identified a marker validation gap before ordinary export
alias screening. On POSIX, closing any descriptor for a locked inode releases
that process's locks on it. An archive marker linked to a held coordinator lock
could therefore release exclusion during `reopen()`.

Archive marker/lease identity checks now run before opening either file. Both
streaming and bounded-JSON APIs carry additional-source coordination identities.
Archive record reads reject aliases to the archive lock or passed outer locks;
coordinator transfer and clone inspection propagate their own/original identities.
Ordinary unknown-file aliases remain exportable as relationship metadata without
opening coordination bytes. No source record is repaired, removed or rewritten.

Two Linux regressions exercise archive marker and archive-lock aliases through
both export APIs and use a separate Python process to verify the held lock remains
excluded after refusal. The four transfer/inspection cases exercise the related
retained-record path. These tests are cooperative filesystem evidence, not an
adversarial filesystem/path-swap or mobile power-loss guarantee.

## Native measurement foundation

See [native recovery capacity](../../../docs/activeDevelopment/in_progress_features/native_recovery_capacity.md)
for the Android/iOS method channel and strict Dart result contract. It can supply
`LegacyRecoveryExportBudget.availableBytes` when a caller explicitly chooses it.
It never selects a destination or starts a migration. The iOS DiskSpace required-
reason declaration is registered in Runner's resource phase.

Eleven native-bridge tests validate mock responses and real temporary-directory
checks. They do not run `StatFs`/`statfs` on Android/iOS. No Android SDK or Xcode is
available in this cloud workspace. Native compile/runtime, same-volume and low-
space evidence, and built-archive privacy manifest inspection remain required.
No capacity values are logged, exported or sent off-device by the bridge.

## Validation

Flutter 3.41.2 / Dart 3.11.0 on cloud Linux. No package/lockfile update.

- Focused export, recovery actions, archive integration and native capacity:
  **84 passed** in 22 seconds.
- Independent final static review: no blocking findings after hardening.
- Final combined analyzer/full/namespace/web checks: running at this source
  checkpoint; completion will be appended with the validated source identity.

Environment for reproducible cloud checks uses writable HOME/XDG config,
existing PUB_CACHE, and Flutter's documented `BOT=true CI=true` mode. Bot mode
avoids the unrelated cloud-metadata detection request; no SDK modification or
metadata access is part of the tests.

From `apps/tablet`:

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
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

## Remaining acceptance

No production support-directory or retention policy is selected. Source capture,
conversion, media promotion and a second host-save copy still need appropriate
measured budgets; this exporter budget does not cover them. Live writer quiescence,
source authority, shipped fixtures, user save/restore flow, native original-
identity no-uninstall updates, real store restoration, device/OS/accessibility,
feature parity and deliberate release acceptance remain open. No cleanup,
original bootstrap change, PR, default merge, deployment or store action occurs.
