# Catalog compatibility and offline update safety

This is a feature-branch M7 implementation checkpoint, not migration-safe or
release acceptance. Original app sources, shared catalog URLs, published
manifests/payloads, app identities, store configuration and startup migration
remain unchanged. No release or deployment is part of this work.

## Reader contract

`CatalogCompatibility` declares a **data reader version 1** and **payload schema
version 1**, independent of Table's `0.1.0` display version. Existing manifests
without `schema_version` / `min_catalog_reader_version` mean the existing v1
JSON list. Optional fields, when present, must be positive integers. Unknown
schema or newer required reader values fail before download or cache writes.

The shared legacy `min_app_version` remains honored. `1.11.0` is the explicit
historical legacy compatibility ceiling already used by this reader, not a
claim about Table's store version or an inferred shipped version. The floor must
be a strict three-component numeric version. Unknown future floors and malformed
values are rejected rather than normalized into a falsely compatible version.
Raising the ceiling needs reviewed schema/field evidence and tests.

Both manifest checks and direct apply calls validate positive integer catalog
versions, hashes, optional byte lengths and compatibility. Bundled, cached and
remote payloads all undergo the same length/hash/shape/name validation. A 16 MiB
payload ceiling rejects oversized input before parsing or persistence. HTTP is
still buffered by the existing client; this is not a streaming network-memory
limit. Missing optional fields remain compatible with legacy manifests.

## Cache and restart behavior

- Physical catalog names and the optional preview namespace are unchanged.
- The current `override` key keeps the historical `version`, `sha256`, `payload`
  fields. New records also carry the complete minimum-app/schema/reader contract
  and cache `record_version: 1`. Old readers of the compatible v1 payload still
  understand the existing fields. Pre-contract cached records remain accepted
  as the historical v1 representation without rewriting them; metadata that was
  never stored cannot be retrospectively recovered or authenticated.
- Loading performs no cache writes. It validates the bundle and both retained
  downloaded generations, selecting the highest compatible version. Older cache
  data cannot shadow a newer bundle. Current in-memory known-good data is not
  downgraded by a transient read failure.
- Invalid/future cache records remain intact. A compatible prior generation or
  bundle provides a readable fallback with an explanation. Apply refuses to
  overwrite unrecognized current or retained records. The existing explicit
  Revert action is available; it is never run automatically on a read failure.
- Apply serializes against load/revert within the app's catalog service, retains
  the current validated record as `previous`, flushes and reads it back before
  replacing `override`, then flushes/read-verifies the new record before reporting
  activation. A failed write/flush never advances the active in-memory version.
  A retry after an uncertain flush acknowledges and activates the compatible
  existing record rather than silently returning with stale active data.
- Explicit revert validates the bundled replacement before touching downloads.
  It clears both downloaded keys so a retained generation cannot reappear on the
  next offline launch, flushes, and only then activates bundled data. A failed
  bundled validation leaves both generations unchanged. Hive deletion/flush is
  not a cross-store transaction and a failing flush can have an uncertain disk
  outcome; failures propagate rather than claim success.
- Catalog operations never save game state, libraries, presets or supporter
  ownership. Tests compare the aggregate before/after and verify artist credits.

## Compatibility of the shared publisher

This change does **not** modify the manifest generator, root OTA client, shared
endpoint, current manifest or payload. Existing original/Table clients continue
receiving the same v1 data. An additive reader field alone cannot protect an old
client that does not inspect it. A future incompatible payload must not be
published at the existing URL merely by setting `schema_version`; the old
`min_app_version` gate and a deliberate versioned-endpoint/publisher strategy
must first be validated against actually shipped clients. No such publication or
policy decision is authorized or claimed here.

## Verification and remaining limits

Regression coverage: legacy/additive manifests, strict malformed/future values,
bundled/cache/remote validation, stale cache, offline and failed bundle fallback,
retained unknown records, no game writes, artwork credits, queued/repeated updates,
load/revert races, failed put/flush/readback, direct retry, actual oversized input,
explicit revert, real Hive close/reopen and preview production sentinels.

Validated source checkpoint `8829688c48737e01c0bd82e3f6d5b474272ca1f3` on
`feat/table-update-safety-integration-20261110` with Flutter 3.41.2 / Dart 3.11.0.
The remote tree exactly matches the locally tested source; this follow-up record
changes documentation only.

- `flutter analyze --no-pub`: no issues.
- Combined catalog, save compatibility, supporter and integration checks:
  **176 passed, one expected namespace-only skip**. The catalog file contributes
  **60 passing cases**, including both revert deletion and flush failures.
- Full `flutter test --no-pub`: **1,669 passed, 8 expected skips**, no failures
  (5m33s). Seven skips are pre-existing and one is the namespace-only guard.
- Explicit `phone_preview_v1` catalog/save/snapshot/migration/support/storage/
  integration checks: **154 passed, 57 intentional same-app-only skips**.
  Real Hive close/reopen preserves the catalog and production sentinels.
- Release JavaScript web build with `/Doubling-Season/tablet/` base path and
  `--pwa-strategy=none`: passed. The optional Wasm compiler dry run succeeded;
  no browser or Wasm runtime acceptance is claimed.
- Independent static review verified the retry/revert fixes and found no further
  correctness issue. Canonical-plan local links resolve; `git diff --check` is
  clean. No source dependency versions or original application files changed.
- The source commit had no recorded commit statuses or PR workflow runs. No PR,
  default-branch merge, deployment, Android/iOS build, actual native upgrade or
  real store restoration was performed.

Reproduce from `apps/tablet`:

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 \
  test/catalog_compatibility_test.dart test/table_repository_compatibility_test.dart \
  test/legacy_snapshot_capture_test.dart test/legacy_migration_test.dart \
  test/support_continuity_test.dart test/storage_namespace_test.dart \
  test/update_foundations_integration_test.dart
flutter build web --release --base-href /Doubling-Season/tablet/ --pwa-strategy=none
```

Remaining M7 gates include actual old-client/publisher compatibility fixtures,
platform-specific filesystem/IndexedDB failure acceptance, and a production
catalog rollout/versioning policy. Native migration, original-identity updates,
real store restoration, minimum-device support and release permission are
separate unresolved gates in the canonical plan.
