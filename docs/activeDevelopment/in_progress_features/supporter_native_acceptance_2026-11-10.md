# Supporter original-update acceptance packet

**Preparation only. No native upgrade, store login, purchase, refund, product
configuration, production identity change or release has been performed.**
Source baseline for this pass: `f01f9d4` on
`feat/tripling-update-foundations-20261110`.

This packet separates repeatable local evidence from the real-store evidence
still needed for M8/M9 in the [current update plan](tripling_season_update_plan.md).
The original 26-style picker remains an explicit later parity decision. Preserving
selected appearance and raw values does not close that feature acceptance gate.

## Read-only readiness report

| Check | Current evidence | Readiness |
|---|---|---|
| Exact original product IDs | Original source and guarded Table contract agree on `com.loosetie.doublingseason.thank_you`, `.play`, `.collector`, in that order. | Source checked, actual store product records unverified. |
| Original identity | Expected Android `com.loosetie.doublingseason`, iOS `LooseTie.Doubling-Season`. Current Table development identities remain separate. | Cutover intentionally disabled. |
| Explicit continuity configuration | `TABLE_LEGACY_SUPPORT_CONTINUITY` defaults to false. Product definitions remain empty unless explicitly supplied. Web and nonempty preview namespaces are rejected. | Default builds cannot stand in for an original update. |
| Source installation | Repository version labels are known; actual shipped source binary, signing identity, version/build and device OS are not captured. | Not ready for a native update rehearsal. |
| Billing startup | `main.dart` initializes the support service after the table controller is ready; the Support view also requests initialization. | Native pending-transaction replay and delayed/recovery startup remain untested. |
| Store environment | No matching App Store/Play sandbox account, previous purchase or restore record has been inspected. | Real restore/purchase acceptance not run. |
| Persistence | Original keys are retained. Local tests inject false writes, exceptions, missing readback and delayed/reordered operations. | Automated evidence only; not proof against device power loss. |
| Cosmetics | Original selected red/blue and 26 collector styles render; unknown style text remains untouched. Table color writes are separate. | Native appearance and complete customization parity still open. |
| Release | Separate app identity, signing, version, workflows and deployment stay unchanged. | Held. |

The `TABLE_SUPPORT_THANKS_ID`, `TABLE_SUPPORT_PLAY_ID` and
`TABLE_SUPPORT_COLLECTOR_ID` definitions must match the exact original IDs before
an explicitly approved original-update candidate can pass its runtime guard.
An enabled flag by itself is insufficient. Do not reuse a separate-app sandbox
result as evidence for the original listing or substitute renamed products.

## Prerequisites for a later authorized rehearsal

1. Identify a non-critical, backed-up source installation and an explicitly
   approved test device. Record actual installed version/build, OS, package ID,
   signing compatibility and original store listing. Keep the source backup and
   raw data intact. A repository version string is not this evidence.
2. Obtain a deliberately approved candidate signed for an in-place update of
   that same app. Increasing a build number, changing package/signing settings or
   installing over an original installation is outside this preparation task.
3. Verify the original products are non-consumable and accessible to the actual
   original listing in the intended sandbox/test environment. Use only accounts
   and store access approved for the rehearsal. Do not create replacement products,
   reset purchase histories, change pricing or use a production payment method.
4. Plan a genuinely data-preserving install. Do not use `flutter install` blindly:
   its uninstall behavior can remove source data. Select the platform's verified
   no-uninstall update route only after identity/signing and backup checks. A clean
   install on a separate test device is a different case, not an update proof.
5. Keep an independent recovery copy. A store downgrade/reinstall is not an
   assumed rollback path. Agree recovery and stopping conditions before execution.

## Cases to execute and record later

Every result needs platform, actual source/candidate versions, candidate commit,
store environment and observation evidence. Run both Android and iOS. “Not run”
is not a pass. A mocked callback, native local test store and real store sandbox
are distinct evidence classes and must not be mixed.

| Case | Setup and action | Required observation |
|---|---|---|
| S1: no ownership | Approved fresh test installation without original or Table ownership; launch offline. | No tier fabricated; all gameplay stays available. |
| S2: each original tier | For Thank You, Play and Collector, use a backed-up original installation with a genuine known purchase. Update in place, first launch offline, close/reopen. Repeat combined ownership where available. | Same highest-owned tier, exact original IDs, no repurchase requirement; original boolean evidence and unrelated preferences retained. |
| S3: original cosmetics | Capture selected original styles before update. Cover all 26 named styles across isolated test fixtures, plus missing and unknown values. Separate fixture results from genuine store ownership evidence. | Same chosen style/colors or original rainbow fallback; raw unknown value is unchanged. No automatic conversion to a five-color default. |
| S4: explicit Table override | On an approved test installation with a prior Table color choice, reopen and retry a failed new choice. | Confirmed Table color wins; failed writes do not change displayed/reopened choice; original named style is untouched. No full-picker parity claim. |
| S5: real restore | On a separate clean test installation using the same original package/listing and authorized sandbox account with prior non-consumable ownership, invoke Restore. Also restore on an in-place update. | Original product IDs arrive; both compatible local caches can be read back before transaction completion; reopen offline retains tier and original style. No new charge or replacement product. |
| S6: no-event/error/offline | Observe an empty restore, store outage, cancellation and a store-reported failure. Reopen and retry when available. | Existing tier/style is not revoked, reset or silently replaced. Error remains actionable; retry cannot clear an unrelated newer failure. |
| S7: pending/interrupted delivery | Use controlled test instrumentation where available to delay receipt delivery/acknowledgment, background/close/reopen, then resume/restore. Record which stages are simulated. | No overlapping purchase or restore while delivery is saving; successful replay is idempotent; no completion before readback; known ownership remains. A killed process before completion must be replayed/restorable by the real store. |
| S8: persistence faults | Use isolated test storage or a disposable backed-up simulator/device, never fill or damage the user's primary device. Exercise rejected writes, failed reopen and process restart. | Failure cannot be called a saved badge. A rejected color does not survive through a stale process cache. Source keys are never deleted. Retry restores a consistent saved result before acknowledgment. |
| S9: account/refund semantics | Only after separate authorization, inspect supported sandbox refund/revocation/account-switch behavior and document the chosen policy. Do not issue real refunds or account changes under this packet. | Product-owner decision and real-store evidence recorded. Current offline cache preservation is not server receipt validation and is not a tested revocation policy. |
| S10: wrong app/preview | Use the unchanged separate development app, a preview namespace or mismatched product configuration. | Guard rejects original continuity and prevents original-store actions; original preference keys and recovery archives cannot grant cross-app ownership. |

Current Table startup initializes billing after the table controller becomes
ready. Before S7 can establish replay after a process interruption, validate that
existing startup/listener timing, including delayed/recovery startup, on the real
original-listing candidate. Manual Restore in an already open Support view is not
proof of startup replay. No startup hook is changed in this preparation pass.

Do not mark S7/S8 fully accepted solely because local fault injection passes:
`SharedPreferences.reload()` checks the backing plugin's response, not an fsync
proof or a power-loss guarantee. Native restart and actual store replay evidence
are still needed. If stronger durable purchase evidence is required, agree and
implement that storage/receipt policy before cutover rather than interpreting a
mock as proof.

## Minimal evidence record

Copy this record per case and platform into the approved private test report.
Use descriptive test-account/device labels, not emails, serial numbers or receipt
contents. Never include passwords, codes, full receipts, purchase tokens, signing
keys or account credentials in repository notes or test logs.

- Case / platform / OS / result: **not run**
- Source installation version/build and original listing verified by:
- Candidate version/build, commit and installed package ID:
- Install route and no-uninstall confirmation:
- Backup/recovery location and checksum reference:
- Evidence class: mocked / native local test store / real store sandbox
- Authorized test account label and verified sandbox environment:
- Product IDs observed and tier/style before and after:
- Original preference keys retained; unrelated-data sentinel result:
- Readback, completion and offline relaunch observations:
- Interruption/error/retry observations and any instrumentation limits:
- Sanitized screenshots/log references:
- Reviewer, date and remaining blocker:

A test record is evidence, not release permission. Do not mark the app
“migration/update safe” until the complete source-data matrix, genuine no-uninstall
upgrade, native/store cases, parity choices and recovery policy have been accepted.
