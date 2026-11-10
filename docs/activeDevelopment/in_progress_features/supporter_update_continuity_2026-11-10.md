# Supporter continuity for a future Tripling Season update

Status: implementation and focused validation complete on a feature branch;
full regression validation is in progress.
The release remains on hold. Nothing here changes bundle/application identity,
store product configuration, signing, version/build numbers or published sites.

## Scope

The current Table app is still a separate development product. Its ordinary
startup must not infer cross-app entitlements from phone preferences that happen
to exist in shared browser storage.

`TABLE_LEGACY_SUPPORT_CONTINUITY` is a dormant, false-by-default build option for
future same-app cutover work. It only admits legacy preferences when all checks
pass:

- Native Android or iOS, never web.
- Empty `TABLE_STORAGE_NAMESPACE`, never the feature preview namespace.
- Runtime package identity from `package_info_plus` is the original
  `com.loosetie.doublingseason` or `LooseTie.Doubling-Season` for that platform.
- All three explicitly configured product IDs exactly match the original
  thank-you, play and collector IDs, in tier order.

An explicit request with mismatched identity/products disables the support store
path rather than selling replacement products. This is not enabled in any
entry point, workflow, build invocation or store configuration in this change.
`package_info_plus` was already a root/transitive dependency; the Table app now
declares its existing version range directly for the runtime identity check.

## Ownership and storage

In verified same-app mode, the service unions the original boolean purchase
cache with Table's existing owned-product cache before contacting the store.
A store outage, thrown availability query, empty restore or lower-tier purchase
cannot erase a known owned tier. This preserves existing offline behavior; a
local cache is not new server-side receipt verification or evidence of a
cross-account/store transfer.

Successful purchased/restored callbacks retain the exact original product ID,
persist the merged Table ownership set and corresponding original boolean, and
only then acknowledge the store transaction. False writes and exceptions are
failures, not successful delivery. Callbacks are serialized to avoid overlapping
writes dropping ownership. Unknown IDs and pending/canceled/error states cannot
grant a tier. The original cache keys, unrelated preferences and unknown cached
Table product IDs are preserved; no migration deletes or resets preferences.

## Cosmetics

Original thank-you red and play blue hearts retain their original colors.
Collector badges retain all 26 named solid/gradient styles through the original
`HeartStyle`/`HeartIcon` rendering. The raw `collector_heart_style` value is never
rewritten. Unknown or missing style names retain the original rainbow fallback.
An existing or explicitly chosen Table solid color takes precedence without
erasing the old preference.

This preserves existing appearance, not full customization parity: Table still
has five selectable solid colors. A complete named/gradient picker remains a
separate release decision. No cosmetic removal has been approved by this change.

## Evidence and remaining release gates

Automated coverage lives in `apps/tablet/test/support_continuity_test.dart`,
alongside existing support-feedback and support-modal regressions. It covers
identity/configuration/preview rejection, each offline tier, merge/idempotency,
store errors, no false grants, exact restore IDs, completion ordering,
concurrent callbacks and preservation of every original collector style.

Validation with Flutter 3.41.2 / Dart 3.11.0:

- Focused continuity, existing support feedback and support geometry: 65 passed,
  one expected namespace-only skip.
- `flutter analyze`: no issues.
- Explicit `phone_preview_v1` namespace: 8 passed, 46 intentionally skipped
  same-app-only cases. Production media/support sentinels remain unchanged.
- Release JavaScript web build: passed. The optional Wasm dry run returned a
  non-fatal 247 warning; Wasm compilation is not verified.
- Full Table regression suite: still running at this checkpoint.

The existing `shared_preferences_platform_interface` version is now an explicit
Table dev dependency for false-returning and throwing persistence fixtures;
no dependency version was upgraded.

Still required before any production cutover: archived old-version native update
rehearsals on both platforms with real app data; sandbox purchase and restore
checks using the original listing/products and store account; receipt/refund
behavior verification; explicit identity/version/build/signing configuration;
cosmetic acceptance; and the user's separate release approval. Mocked tests and
web builds cannot establish any of these native/store outcomes.
