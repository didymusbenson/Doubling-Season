# Native recovery capacity foundation

This read-only foundation is not production migration activation or native
acceptance. It adds no destination selection, automatic source discovery,
permissions, dependencies, retention/deletion, identity changes, or release.
The method channel is registered in the existing native engine setup; no probe
is invoked from app startup and no migration runner is connected to it.

## Contract

`NativeRecoveryCapacity().availableBytes` can be explicitly supplied to
`LegacyRecoveryExportBudget.availableBytes`. The caller must select an existing
private destination directory and supply the export policy (reserve and maximum
output size). The default export policy remains 64 MiB reserve / 8 GiB maximum;
these are policy bounds, not measured disk capacity.

Android uses `StatFs(destination).availableBytes` (blocks available to an ordinary
writer). iOS uses `statfs(destination)` and checked `f_bavail * f_bsize`, not total
volume size, total free space, or potentially reclaimable/purgeable capacity.
Both query the supplied directory's filesystem rather than a fixed app/home/root
volume. Results use signed 64-bit byte counts. Zero is a valid measurement which
the export budget rejects when the write/reserve requires more space.

Dart requires an absolute existing directory, rejects a final symbolic link,
and resolves ancestor aliases (including normal iOS `/var` aliases) before the
channel call. Native code requires that canonical path still identify a directory
and echoes the measured path. Dart rejects mismatched paths, non-integer/negative
results, malformed responses, missing plugins, and exceptions. Unsupported
platforms return unknown without calling a native channel. No fallback estimate
is substituted. Content URIs, remote providers, and security-scoped selection
are not supported by this directory-path bridge.

The probe reads metadata only. It cannot guarantee writability, reserve space,
account for every quota, prevent other processes consuming space, lock a mount,
or exclude all directory replacement races. Rechecking the path before/after
narrows races but is not an inode/volume identity guarantee. The exporter's
per-write capacity checks and retained partial evidence remain necessary. The
capacity method does not make fsync or power-loss durability claims.

## Validation and remaining gates

`apps/tablet/test/native_recovery_capacity_test.dart` tests mocked method-channel
results and actual temporary-directory validation. It covers both supported
platform dispatches, unsupported platforms, malformed values, path mismatch,
missing plugins/platform errors, zero and 64-bit counts, missing/relative/file/
URI/NUL/link paths, and removal during measurement. These tests do **not** execute
Android or iOS capacity APIs.

Before production use:

- Compile the actual Android and iOS app targets against supported SDKs and
  confirm channel registration with the actual Flutter engine lifecycle.
- Run on native Android and iOS devices, comparing the returned count with the
  same destination volume's native available-block measurement. Include separate
  volumes where accessible; do not substitute a root-filesystem measurement.
- Exercise missing/inaccessible directories, wrong path types, unsupported
  destinations and channel failures. All must remain unknown without fallback.
- Exercise genuinely low-space export, concurrent capacity loss, cancellation,
  write/flush failure, app interruption and relaunch while retaining all source
  evidence and incomplete artifacts. Do not fill a user's everyday device.
- Verify destination policy, writer exclusion, retention UX, source inventory,
  rollback/retry, and original-identity upgrade acceptance separately. Passing
  this bridge's unit tests does not satisfy any of those acceptance gates.

No native compile/runtime validation is claimed by this document. The current
cloud workspace has Flutter/Dart, but no Android SDK or Apple Xcode toolchain.

## iOS privacy declaration

Runner now includes `PrivacyInfo.xcprivacy` in its Xcode Resources phase, declaring
`NSPrivacyAccessedAPICategoryDiskSpace` reason `E174.1` for checking capacity before
file writes. Apple's [required-reason API list](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
includes `statfs` and this purpose. The capacity values and derived information
must stay on-device; the bridge adds no telemetry, logging or artifact fields.
Before activation, insufficient-space behavior must be visible to the user.
This scoped declaration is not a complete app/dependency privacy audit or an
App Store submission. Native archive inspection must confirm the manifest is
bundled, and privacy-report review remains a release gate.

Cloud validation on 2026-11-10: all 11 focused Dart tests passed and scoped Flutter
analysis reported no issues. Python parsed the privacy plist and checked the
project's resource reference counts. Native compilation/runtime tests and Xcode
archive privacy-report inspection were not run (SDKs unavailable).
