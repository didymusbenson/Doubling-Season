# Isolated native capacity validation — 2026-11-10

Source tested: `29a922eb89fc20ab19f0599aef6168e6f49c5c1a` on
`feat/table-migration-integration-20261110`. This follow-up records native
validation only. No bridge source changes were required. The original-installation,
release, default-branch merge and deployment hold remains in force.

## Environment and isolation

Validation ran in a fresh checkout on the connected Mac using Flutter **3.41.2**,
Dart **3.11.0**, Xcode **26.2 (17C52)**, CocoaPods **1.16.2**, Android SDK **36**
and the installed Android Studio JDK **21**. Dependency resolution did not change
tracked manifests or lockfiles. The existing SDKs were used without upgrades or
license acceptance.

The physical iPhone and iPad were reported unavailable; no physical Android device
was attached. Two new empty test devices were created instead:

- iPad mini (A17 Pro), iOS **26.2** simulator.
- Pixel 7 profile, Android **15 / API 35**, arm64 emulator from an installed image.

The temporary entrypoint imports only Flutter and `NativeRecoveryCapacity` and
uses synthetic directories, one text file and one symbolic link under its own
temporary directory. It does not import the app entrypoint, initialize Hive,
load repositories/preferences, select production destinations or run migration.
It invokes the repository's unmodified native channel registration and handlers.
Only this harness was installed on the new test devices. No existing app
installation, prior simulator, real app data, store or credential was modified.
The new test devices were shut down after the checks, not deleted.

## Completed checks

From `apps/tablet`:

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub test/native_recovery_capacity_test.dart
flutter build ios --simulator --debug --no-pub
flutter build apk --debug --no-pub
flutter build ios --debug --no-codesign --no-pub --target lib/main.dart
```

- Analyzer: **no issues**.
- Existing Dart bridge tests: **11 passed**. These include mocked results and
  filesystem checks, not native syscall evidence by themselves.
- Normal app entrypoint, iOS simulator debug build: **passed** (Xcode build 31.6s).
- Normal app entrypoint, unsigned iOS device debug build: **passed** (22.1s).
  The resulting executable is arm64; it was not installed.
- Normal app entrypoint, Android debug APK: **passed** (Gradle build 50.1s).
- Both built simulator and unsigned-device `Runner.app/PrivacyInfo.xcprivacy`
  files were parsed and contain
  `NSPrivacyAccessedAPICategoryDiskSpace` with reason **E174.1**.
- The real native handler and Dart wrapper: **18 assertions passed on each
  platform**, confirmed in iOS unified logs and Android logcat. The iOS harness
  was relaunched and all 18 assertions passed again.

Runtime assertions cover:

1. Native canonical-directory result echoes the exact requested path and returns
   a nonnegative integer byte count.
2. Dart wrapper successfully reads the same explicitly chosen directory.
3. A child directory on that same test volume is accepted through the wrapper.
4. Native null arguments are rejected with `capacity_unavailable`.
5. Native empty arguments are rejected.
6. Native non-string path is rejected.
7. Native relative path is rejected.
8. Native missing path is rejected.
9. Native file path is rejected.
10. Native symbolic-link path is rejected.
11. Native noncanonical dot-segment path is rejected.
12. Native NUL-containing path is rejected.
13. Unsupported method produces the expected not-implemented result.
14. Wrapper relative path returns unknown.
15. Wrapper missing path returns unknown.
16. Wrapper file path returns unknown.
17. Wrapper final symbolic-link path returns unknown.
18. Wrapper NUL-containing path returns unknown.

No capacity numbers or derived storage amounts were printed, copied into this
report or transmitted by the harness. Runtime logs record assertion names and
pass/fail only. The temporary standalone harness and local logs remain with the
isolated validation checkout. Harness SHA-256:
`42c48fef3d653b78535fb1efb1e4a346ccdf5275068b0b86e5555dd35aa99bb5`.

The harness is selected with `flutter run --debug --no-pub --no-resident
--target <temporary-harness.dart> -d <fresh-test-device>`. It is deliberately not
the production app startup path. Initial `--no-resident` console output did not
include Dart assertions; the named native logging sources above supplied the
actual runtime evidence. The full regression suite was not rerun for this
documentation-only follow-up; the source checkpoint's separate full-suite result
remains recorded in [bounded recovery integration](bounded_recovery_integration_2026-11-10.md).

## Remaining acceptance

These checks establish compilation, engine registration and basic real-platform
path/result behavior. They do **not** establish production migration safety.

- Physical-device execution is blocked by device availability. No install over
  an existing app, original-identity upgrade, real-store restore or real user
  data access was attempted.
- Independent comparison with the same volume's available-block measurement,
  genuinely different volumes, quotas and inaccessible-provider cases remain.
  Accepting parent/child paths is not proof of independent numerical accuracy.
- Genuine low-space exports, concurrent capacity consumption, write/flush failure,
  interruption/relaunch, recovery retention and user-facing restore flows remain.
  No disk was filled to force these conditions.
- This was not a signed archive, privacy report, App Store audit, deployment or
  publication. A manifest in a built debug app does not satisfy those gates.
- Existing toolchain warnings remain: Flutter doctor reports some Android SDK
  licenses unaccepted, but the installed components were sufficient for this
  debug build. No license prompt was accepted. Java dependency compilation
  emitted obsolete source/target 8 warnings. The iOS runtime logs a duplicate
  `FileUtils` class from `file_picker`/OSAnalytics; all scoped assertions still
  passed. Flutter also emitted a nonfatal native-assets `SdkRoot` diagnostic
  during the temporary simulator run. These are not counted as failed assertions
  or concealed as a warning-free release build.

See the [capacity contract](../../../docs/activeDevelopment/in_progress_features/native_recovery_capacity.md)
and [current migration plan](../../../docs/activeDevelopment/in_progress_features/tripling_season_update_plan.md)
for the wider acceptance boundary. No production policy or automatic activation
was selected by this validation.


## Application Support factory follow-up

The new retention-factory production source was tested at
`49409136c13c04651db24d0b4cc181b977d4afdb` on
`feat/migration-retention-policy-20261110`. This is a separate source checkpoint
from the earlier baseline builds. It introduces the dormant
`LegacySourceArchive.createInApplicationSupport(capacity: ...)` API.

The same two dedicated test devices were restarted. A new temporary entrypoint
reran all **18 bridge assertions**, then exercised the real `path_provider`
plugin and native capacity callback with a synthetic archive policy: 16 MiB
archive ceiling, 16 MiB conversion reserve and the default 64 MiB safety reserve.
Those are test parameters, not a production policy selection.

Both iOS 26.2 and Android 15 passed **17 factory assertions**, plus the **18
bridge assertions** each. The test-harness builds passed on iOS (25.7s) and
Android (9.1s); no normal-app startup or migration activation was invoked.

The factory assertions verify:

1. Archive parent equals the canonical directory returned by the actual native
   Application Support provider.
2. A newly created retained-source child has the required unique-name prefix.
3. Creation probes the canonical support parent, then the actual child.
4. The native capacity bridge succeeds on that exact support child.
5. The policy file round-trips the exact explicit test policy.
6. The budgeted marker and empty coordination file are present after creation.
7. Strict reopening with the same capacity policy succeeds.
8. Capture repeatedly probes the actual archive child through the native bridge.
9. The synthetic source remains byte-exact after capture.
10. A synthetic `<map/>` preferences file and seven explicitly absent Hive
    collections produce seven empty decoded collections.
11. Strict reopening preserves the snapshot and inventory digests.
12. Read-only reopening without a capacity callback preserves both digests.
13. That read-only handle refuses a capture without a fresh measured budget.
14. Recovery-only reopening refuses capture.
15. Recovery-only reopening refuses semantic decoding.
16. Recovery-only reopening can make a complete physical-evidence backup.
17. All archive file bytes remain identical after the read-only and recovery-only
    operations.

The capture input was a newly created, canonical temporary fixture with all its
writers closed. Only uniquely named synthetic archives in the dedicated test
apps' own Application Support directories were written. No installation search,
original Hive access, store restore, migration promotion, expiry or cleanup ran.
Archive artifacts remain preserved in these test identities. Both devices were
shut down again after collecting assertion-only logs. No capacity values,
original data or derived disk amounts appear in the logs.

Temporary factory harness SHA-256:
`ee987ed4f474449416771149232d1cfc5354acfd293202a9168a454503ef26af`.

### Mac host regression follow-up

The first focused Mac run at `4940913` produced **16 passes and 17 failures**.
The new test fixture supplied macOS's `/var/folders` ancestor alias to an API
that intentionally requires canonical caller-owned directories. Two mocked
support-path assertions likewise expected the alias rather than `/private/var`.
This was a fixture portability failure, not a passing run or a native-factory
failure. The production factory already canonicalizes the trusted OS location,
and both real-platform factory runs above passed.

Test-only fix `d13981cfe30005807b90a5fb2400871c6b5897cb` canonicalizes the created
fixture parent. Its only change from `4940913` is the test setup; production code
is identical. With the ordinary Mac environment, final analysis reported **no
issues** and the combined focused command passed **33 tests**:

```sh
flutter analyze --no-pub
flutter test --no-pub test/native_recovery_capacity_test.dart \
  test/legacy_archive_capacity_test.dart
```

This follow-up proves a small synthetic factory/capture/reopen path on native
test runtimes. It does not cover real Hive records, artwork, physical hardware,
real volume exhaustion, independent available-block comparison, crash/power-loss
durability, user restore UX, shipped-installation update or release acceptance.
The wider remaining gates above are unchanged.
