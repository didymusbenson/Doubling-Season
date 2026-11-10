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
