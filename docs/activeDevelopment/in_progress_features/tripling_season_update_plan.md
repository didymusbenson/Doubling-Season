# Tripling Season update: implementation and acceptance plan

**Current plan: 2026-11-10. Source baseline: `0273043` on `fix/tripling-card-corners-20261109`.**
This is the current cross-product plan. It supersedes stale status/scope claims in
the October tablet and phone proposals, while preserving their accepted behavior
and historical evidence. Source implementation, automated checks, native acceptance
and release permission are separate states.

The owner asked: “Get the plans coherent and up to date then begin the work. Once
it’s migration/update safe I’ll keep working on the feature set before we release
it.” The immediate milestone is safe migration/update foundations, followed by
continued feature work. **This milestone is not a release, main merge, deployment,
store upload, or permission to replace an original installation.**

## Current product and implementation baseline

- Original Tripling Season remains the root app. Keep its code, bundle/application
  IDs, Hive adapters/field numbers, box names and installed user data intact.
- `apps/tablet` is the separately identified Tripling Table development app. It
  already contains both full-table and fixed-Player-1 phone presentation. Phone
  work is not merely a proposal at this baseline; original-app cutover is absent.
- New games support **2–6 players**. Narrow player spaces choose local Tokens or
  Utilities while keeping life visible; wider spaces retain the 60/40 lanes.
  This is not the phone view and does not reduce the session's player count.
- Native phone presentation is selected by physical display size (provisional
  shortest side below 600 logical pixels). Stable tablet web stays full-table;
  phone web preview requires its explicit build flag/namespace. Fold/resize is
  presentation only. Physical foldable classification remains unverified.
- Development IDs stay `LooseTie.Tripling-Table` and
  `com.loosetie.triplingtable`. iOS admits family `1,2`, target 15. Original iOS
  targets 13. This difference is an unresolved update compatibility gate, not
  approval to drop original users. Android signing and minimum-device coverage
  also need a real original-update comparison.
- Root `1.11.0+19` and Table `0.1.0+3` are repository labels, not proof of the
  latest shipped store versions. No production source-version matrix is claimed.
- Current Table aggregate, catalog, media and supporter names remain unchanged.
  URL paths do not isolate browser storage; the optional `phone_preview_v1`
  namespace is for the temporary preview, not a migration mechanism.

Evidence: [Table README](../../../apps/tablet/README.md),
[adaptive 5/6 implementation](ipad_edition/adaptive_five_six_seats_2026-11-05.md),
[phone implementation](phone_mode/implementation.md),
[preview contract](../todo_features/unified_tripling_season/preview_workflow.md).

## Non-negotiable data contract

1. Convert saved decks into reusable presets and the active board into Player 1
   through **different paths**. A preset load intentionally creates zero/default
   gameplay values; it cannot migrate a live match.
2. Preserve every live token instance, quantity, tap/sickness state, counters,
   custom identity, selected art/style/credit and stable within-lane order.
   Duplicate names/stacks are not duplicate records to discard.
3. Preserve enabled utilities with supported semantic counterparts. Canonical
   life/counter/status projections must not become hidden duplicate authorities.
   Ambiguous or unsupported data stays recoverable and is reported explicitly.
4. Retain original decks, custom definitions, rules, preferences, artwork bytes,
   support ownership evidence and raw unsupported fields. Preserving recovery
   data alone does not establish functional parity for an existing feature.
5. No original destructive-recovery bootstrap, source cleanup, schema renumbering,
   new production namespace, automatic migration trigger or default board reset.
   An interrupted attempt must not mutate the source or overwrite later play.
6. Unrepresented opponent/life defaults must be explicit in a conversion report.
   Do not fabricate old match history or infer a one-player game from phone view.

Detailed contracts: [migration](../todo_features/unified_tripling_season/migration.md),
[board continuity](../todo_features/unified_tripling_season/fresh_board.md),
[preset audit](../todo_features/unified_tripling_season/preset_audit.md).

## Implementation and acceptance matrix

`Source present` means inspected code, not a new test pass. `Recorded checks`
means the linked historical evidence and only its stated scope. `Open` and
`In progress` are not acceptance. Each implementation checkpoint must append its
commit, exact tests/results and remaining limits to the relevant row or record.

| ID | Requirement and current evidence | Next work / required acceptance | Current checkpoint state |
|---|---|---|---|
| M1 | Complete source inventory and private consistent snapshot. Legacy `lib/database/hive_setup.dart` can recreate failed boxes; `lib/utils/constants.dart` assigns IDs 0–12. | Read copied fixtures without normal destructive recovery; inventory boxes, adapters, prefs, local files, source version and hashes; refuse corrupt/unknown sources without changing them. Obtain actual shipped-version fixtures later. | Partial: [copied native source acquisition](../../../apps/tablet/docs/legacy_source_acquisition_2026-11-10.md), raw retention, preference decoding and existing-adapter capture are implemented. Live quiescent acquisition and actual shipped fixtures remain open. |
| M2 | Independent live-board and saved-deck conversion. `PresetService.importJson` accepts phone schemas 1–3; it is not installation migration. | Stable source-to-destination IDs, duplicate decks/stacks, order, counters including power-only/toughness-only, explicit utility counterpart map, report unsupported/ambiguous data. Never feed live state through zero-state preset load. | Partial: mapping revision 2 supports separate live/preset paths, independent passive utilities, known actions and axis counters. Unsupported/ambiguous cases still block commit; [combined acquisition-to-map evidence](../../../apps/tablet/docs/migration_integration_2026-11-10.md). |
| M3 | Owned artwork and credits. Table has immutable media and v4 embedded-asset imports; legacy deck JSON omits cover/bytes. | Copy/hash/reopen local bytes, remap all references including custom library/covers/preferences; preserve missing-file metadata with usable fallback. Validate offline reopening, corrupt/oversize assets and interruption. | Partial: copied-file acquisition and fixture journal copy/hash/remap/reopen are integrated, including covers and toggle-state art. The isolated coordinator now decodes images and promotes production-format media; missing-file recovery acceptance and live-installation media authority remain open. |
| M4 | Recoverable durable commit and idempotent restart. Table repository has checksummed generations; source data spans other stores. | Versioned journal, staging generation, durable marker and reopen verification; inject failure at every boundary. Retry cannot duplicate or replace later gameplay. Keep recovery material; retention/cleanup is not implicitly approved. | Partial: isolated durable journal, revisioned receipt, retry serialization and every-boundary fault injection implemented. The isolated coordinator now protects later gameplay and connects to a read-only rehearsal recovery adapter; production startup/authority remains unwired. |
| M5 | Saved setup fidelity and scope. `PresetService` saves/renames/deletes/imports/exports and loads Replace/Append; loads are seat-scoped commands. | Preserve token `extra` display style, source identity and deck metadata or report limitations; rich-art roundtrip and failed writes; Save/Replace/Append/Undo on multiple seats, cover apply/undo, no life/history collateral reset. Audit original editing behavior before adding an editor. | Partial: legacy preset metadata/order/cover retained, artwork display style survives save/load, and fresh seat-scoped loads tested. [Audit gaps](../todo_features/unified_tripling_season/preset_audit.md) remain open. |
| M6 | Custom library, favorites/recents, preferences and rule definitions. Current Table and legacy scopes differ. | Explicit key/field map, unknown-key recovery, no global artwork preference silently applied to every seat/new game; preserve unsupported rules rather than enable/substitute them. | Partial: native preference decode, custom definitions and recognized built-in/custom rule mapping are integrated; all raw preferences/rules remain retained. Obsolete non-default multipliers and unknown/ambiguous semantics still block activation. |
| M7 | Data OTA compatibility. Table now declares reader/schema v1 independently of product display version, with a conservative legacy minimum-app bridge. | Bundled/cached/remote verification, future/malformed refusal, retained offline fallback and restart/retry tests are implemented. Actual old-client/publisher compatibility, native storage failures and rollout policy remain required. | Partial: [catalog safety implementation](../../../apps/tablet/docs/catalog_update_safety_2026-11-10.md); not production compatibility certification. |
| M8 | Original supporter ownership and cosmetics. Root IAP owns three `com.loosetie.doublingseason.*` products; Table uses configured separate IDs and keys. | Explicit original-update configuration with original IDs, cached legacy continuity plus real restore evidence; failed/offline/pending restore cannot revoke access or require repurchase. Never grant cross-app ownership by conflating keys. Track cosmetic parity separately as P3. | Partial: dormant native identity/product guard, offline ownership union, serialized durable restore callbacks and legacy cosmetic renderer implemented. Real store restoration/cutover untested. |
| M9 | Genuine original-install update. Current separate Table builds cannot prove it. | Approved backed-up source installation, actual shipped binary/version/signing identity, no uninstall, successful launch/reopen, all M1–M8 checks, compatibility/device floor and recovery/rollback evidence. | Blocked on future deliberate cutover and native evidence; not authorized now. |
| F1 | Full-table 2–6, partner commander sources and local adaptive views exist. | Preserve existing scoped commands, all-modal input, history/archive and no reset on layout. Native small-tablet/Android usability, accessibility and stress remain separate acceptance. | Source present; [recorded checks](ipad_edition/adaptive_five_six_seats_2026-11-05.md), native gates open. |
| F2 | Fixed Player 1 phone, option C controls and native keyboard paths exist. | Full session/hidden seats remain intact during fold, keyboard, pending saves, interruption and later edits; realistic phone, large text and physical foldable QA. | Source present; [recorded phone checks](../todo_features/unified_tripling_season/implementation_summary.md), native/foldable gates open. |
| F3 | Original token functionality is the required baseline. | Maintain the [50-row parity inventory](ipad_edition/corrective_iteration.md#fifty-row-token-inventory) and route-specific semantics; new migration/presentation work needs relevant regressions. Historical source-corrected rows are not a full native pass. | Existing correction/validation evidence; no blanket parity certification. |

## Explicit parity choices and deferred feature work

These are visible decisions to resolve before a Season update, not implied scope
for the foundation implementation and not silently approved feature removals.
Data preservation work proceeds while these choices remain open.

| ID | Difference / existing decision | Current disposition |
|---|---|---|
| P1 | Curated utilities intentionally exclude arbitrary tracker/toggle authoring under D37. Original users may have custom configurations. | Preserve those records, identity and fields. Decide whether to restore authoring/behavior before Season cutover; do not recreate an editor merely because migration was requested. Unsupported live entries must be reported. |
| P2 | Custom rule authoring is deliberately deferred in Table; source-owned built-in effects are implemented. | Recognized imported rules now retain enabled state and execute through the existing scoped calculator; authoring remains deferred. Unsupported/ambiguous rules remain blocked and recoverable. No name-based substitution or silent activation; remaining feature/native parity needs acceptance. |
| P3 | Original collector hearts have 26 styles (`lib/models/heart_style.dart`); baseline Table offers five solid colors (`ui/support_sheet.dart`). | Exact legacy style and entitlement are preserved; the original renderer now retains all 26 named/gradient styles in verified same-app mode. Table still only offers five selectable solids; full picker/native cosmetic acceptance remain open. No approved downgrade. |
| P4 | Table preset tools are not automatically equivalent to every original deck-edit flow. | Audit `lib/screens/deck_detail_screen.dart`, `decks_list_screen.dart`, `providers/deck_provider.dart` and actual Table UI. Record precise original operations and roundtrip loss before proposing missing editors/overwrite. |
| P5 | Legacy trackers store `longPressIncrement`; Table uses its current hold/acceleration interaction. Toggle on/off art can also differ. | Imported utilities now retain single-shot original hold amounts and active/inactive artwork/descriptions through live state and presets. Ordinary Table utilities keep accelerating holds. Functional regressions pass; native interaction acceptance remains open. |
| P6 | Separate token/utility lanes and zero-state preset loads are intentional accepted changes. | Preserve stable order within each kind and source mixed order in recovery. Do not restore a mixed gameplay lane or treat zero-state preset behavior as a bug. Live-board conversion remains stateful. |
| P7 | Recovery-retention duration, original supported versions/device floor, rollout and rollback are open. | Keep source/recovery data now. No automatic irreversible cleanup or store downgrade assumption. Decide release policy using captured evidence. |

## Work sequence and handoff gates

1. **Reconcile and checkpoint this plan.** Keep dated historical findings and
   current authority links; do not convert proposals into approvals.
2. **Build isolated safety foundations.** Implement and test source snapshots,
   mappings/reports, supporter continuity and recoverable staging using copied
   fixtures. No production startup wiring, app-ID changes, merge or deployment.
3. **Close the technical safety matrix.** Complete missing M1–M8 pieces and fault
   injection with rich fixtures. Report exact partial results. A converter unit
   test alone is not “migration/update safe.” Genuine update acceptance remains M9.
4. **Continue feature work.** Resolve P1–P7 and remaining phone/tablet acceptance
   with the owner. Foundation progress does not freeze or finish the feature set.
5. **Later explicit release preparation.** Select cutover builds/fixtures and
   run M9, native/platform/accessibility/store restoration checks; resolve temporary
   preview cleanup and release plan. This step is held, not started by this task.

## Integrated foundation checkpoint (2026-11-10)

Feature branch: `feat/tripling-update-foundations-20261110`. The integration keeps
`0273043` as its requested source baseline and combines documentation `42ebc7d`,
migration `8183af8` and supporter continuity `5c42e4e`. These are source changes on
a feature branch, **not shipped or migration/update-safe acceptance**. The
separately observed `origin/main` at `f441f6a` is not merged into this checkpoint.
No original adapters, application identities, signing, release/build versions or
startup migration hooks were changed.

- [Migration implementation and limits](../../../apps/tablet/docs/legacy_migration_foundation.md)
- [Support continuity implementation and limits](supporter_update_continuity_2026-11-10.md)
- Cross-component regression: `apps/tablet/test/update_foundations_integration_test.dart`
  drives detached legacy models through snapshot, fixture commit and reopen, then
  confirms live gameplay and fresh presets stay separate. It also proves archived
  supporter evidence cannot grant ownership and a stale archive cannot revoke
  current same-app offline ownership. Preview namespaces reject legacy support.

### Combined validation

Validated integrated source/test commit `18965405d44673783f0fa46a22f6517da6b92fb6`
with Flutter 3.41.2 / Dart 3.11.0. This record changes documentation only after
that source validation; it does not certify a production update.

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: **1,546 passed, 8 expected skips**, 8m36s. The skips
  comprise seven pre-existing cases plus the namespace-only support guard case.
- `flutter test --no-pub test/update_foundations_integration_test.dart`:
  **3 passed**. These cases also passed in the full suite.
- Namespaced snapshot, migration, supporter, storage and integration tests:
  **42 passed, 46 expected same-app-only skips** under `phone_preview_v1`.
  Production support/media sentinels remain unchanged.
- Release JavaScript web build with the existing `/Doubling-Season/tablet/`
  base path and `--pwa-strategy=none`: passed. The optional Wasm compiler dry run
  also succeeded; no Wasm runtime or browser acceptance is claimed.
- Independent read-only boundary review found no correctness issue. Fourteen
  canonical-plan local links resolve and `git diff --check` is clean.
- The feature branch is published and its source tree matches the validated local
  tree. No PR or CI run was created; the exact source commit has no recorded
  workflow runs/statuses. Android/iOS builds, native update rehearsals and real
  store restoration were not run. No default-branch merge or deployment occurred.

Reproduce the explicit namespace check from `apps/tablet`:

```sh
flutter test --no-pub --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 \
  test/legacy_snapshot_capture_test.dart test/legacy_migration_test.dart \
  test/support_continuity_test.dart test/storage_namespace_test.dart \
  test/update_foundations_integration_test.dart
```

**Next work recorded at this historical checkpoint:** raw consistent source acquisition and shipped adapters;
built-in/action utility, rule and independent-counter mappings; production
aggregate/media authority integration with later-game protection; image decoding,
large/full-disk recovery fixtures; catalog compatibility; and user-visible
recovery. These must precede any migration-safe claim. Native no-uninstall
upgrades, actual store restores, device/OS floor, retained-recovery policy and the
explicit release decision remain separate later gates.

## Continued safety integration (2026-11-10)

Feature branch: `feat/table-update-safety-integration-20261110`. This continues
`f01f9d4`, integrates save compatibility `ec614a3` and supporter acceptance
preparation `1bc5f52`, and adds the M7 catalog reader/cache contract. The source
baseline and release hold above remain in force. The previous legacy source
reader worktree was not available; no unpublished raw acquisition implementation
is claimed or duplicated by this checkpoint.

- [Retained saves and historical-reader rollback](../../../apps/tablet/docs/save_compatibility_2026-11-10.md)
  adds schema upgrades/refusal, historical aggregate checksum handling and
  retained recovery. This is Table save safety, not production legacy cutover.
- [Supporter persistence and native acceptance preparation](supporter_update_continuity_2026-11-10.md)
  adds callback/restore failure protections and an explicit native checklist.
  No real store restoration or original-identity update was performed.
- [Catalog update safety](../../../apps/tablet/docs/catalog_update_safety_2026-11-10.md)
  covers M7's isolated technical reader/cache foundation. No shared publisher,
  original app, catalog payload, identity, signing or release change is included.

Validated source `8829688c48737e01c0bd82e3f6d5b474272ca1f3` with Flutter 3.41.2 /
Dart 3.11.0. The remote source tree matches the tested local tree. Analyzer is
clean; **176 focused checks passed / one expected skip**; the full suite passed
**1,669 tests / 8 expected skips** in 5m33s. Explicit preview-namespace checks
passed **154 / 57 intentional same-app-only skips**. Release JavaScript web build
and optional Wasm compiler dry run passed. Independent static review found no
remaining correctness issue after fixing direct retry and failed-bundle revert
cases. All 18 local links in this plan resolve, and `git diff --check` is clean.

The source commit had no recorded statuses or PR workflow runs. No PR,
default-branch merge, deployment, native build/update, store restore or release
occurred. See the catalog record for exact commands and limits. This is a
validated development checkpoint; M1–M9 and parity/device/store gates are still
not collectively accepted. Next work remains raw copied-source acquisition,
unsupported mapping parity, production journal/media coordination with later-play
protection, and user-visible recovery, followed by deliberate native acceptance.

## Copied-source and mapping integration (2026-11-10)

Feature branch: `feat/table-migration-integration-20261110`. Source acquisition
`7dc28a8` and semantic utility/counter/rule mapping `b62852a` now join `60ff248`.
The [combined integration record](../../../apps/tablet/docs/migration_integration_2026-11-10.md)
documents exact boundaries and eight real-Hive end-to-end cases. An older
happy-path source fixture's tied integer/string board keys are now separated;
the ambiguous tied source itself is tested as a retained activation blocker.

Validated source `7d01314254fe5ed0c06c90d0ad352e376c26537e` has an exact
remote/local tree match. Analyzer is clean; **307 focused tests passed / one
expected skip**; full regression passed **1,769 / 8 expected skips** in 5m56s;
preview-namespace checks passed **254 / 57 intentional same-app-only skips**.
Release JavaScript web build and optional Wasm compiler dry run passed. Independent
review found no correctness issue; all 21 local links resolve and diff checks pass.
No commit statuses or PR workflow runs were recorded for that source commit.
No original startup, identity, production store, native installation, PR,
default-branch merge or deployment changed. No original-install/store acceptance
or collective migration-safe status is claimed.
The previous checkpoint's missing raw-source worktree is historical: this named
published source branch is now integrated, with actual shipped-version/native
acquisition and production authority still outstanding.

## Validation record and commands

The inspected baseline's [corner-fix record](../bug_bashing/token_creation_corners_2026-11-09.md)
reports analyzer clean, **1,462 tests passed / 7 existing skips**, release web
build and pixel review. This is historical baseline evidence, not tests executed
by the documentation reconciliation or proof of native migration safety.

For implementation checkpoints, use Flutter 3.41.2 from `apps/tablet`:

```sh
flutter analyze
flutter test
flutter test --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 test/storage_namespace_test.dart
flutter build web --release --base-href /Doubling-Season/tablet/ --pwa-strategy=none
```

Add focused migration/store/catalog/media tests and fault injection for changed
paths. `.github/workflows/tablet-build.yml` provides Android/web/simulator jobs;
record results for the exact commit, not an older green run. Source-only or
in-memory checks do not replace native filesystem, store or no-uninstall upgrade
acceptance. No release workflow should run for this documentation checkpoint.

## Documentation precedence and reconciliation

1. Latest explicit owner direction, then this current matrix and linked updated
   implementation records, then dated decision/specification records.
2. The October tablet dossier is the origin of enduring behavior, not a current
   assertion that the app is discovery-only or restricted to 2–4.
3. October phone branch/CI obstacles remain historical evidence. Phone source is
   present at the pinned November baseline; no inference about current `main`,
   live preview SHA or installed devices is made without checking them.
4. `fresh_board.md` retains its historical filename but requires preservation,
   not clearing the first migrated board. Preview cutover text follows that rule.
5. The old `todo_features/unified_tripling_season` path is retained for existing
   links. Its migration work is active here, not deferred merely by directory name.

## Rehearsal coordination and recovery integration (2026-11-10)

Feature branch `feat/table-migration-integration-20261110` joins recovery
`7a76233` and coordinator `a32a91f`. The
[integrated recovery record](../../../apps/tablet/docs/migration_recovery_integration_2026-11-10.md)
describes clone-only inspection, exact physical-file retention, guarded retry,
unknown-authority refusal and generation-order conflict checks. Source `e453ee2`
passes analysis, **1,825 full tests / 8 expected skips**, **310 preview safety
checks / 57 intentional skips**, and the release web build. The record separates
these combined results from earlier component counts. No original
startup route, main merge, deployment, identity cutover or release is included.

Remaining priority is production archive/export/retention and disk-capacity
policy, actual shipped-version copies, all-writer quiescence, native process and
no-uninstall update evidence, store restore and device/accessibility acceptance.
Temporary fixtures and passing web builds cannot satisfy those release gates.

## Historical-source and dormant-startup safety checkpoint (2026-11-10)

Feature branch `feat/table-migration-integration-20261110` integrates source
`5c881bd`. The [combined history/startup record](../../../apps/tablet/docs/migration_history_startup_integration_2026-11-10.md)
adds frozen bytes from exact historical repository adapters and a dormant,
non-activating inventory gate. The historical fixtures exposed a silent
creation-time-to-Hive-key ordering change; multi-record sources with absent/null
live order now fail closed after exact raw retention. Single-record old Item
fixtures and explicit-order sources remain supported within the recorded limits.

The fixtures are synthetic, not copies from shipped installations. The gate is
not wired into either startup and cannot activate any candidate. Actual shipped
copies, production retention/lease/activation and native/store/device acceptance
remain open; release stays held. See the linked record for exact final validation
and outstanding gates rather than treating earlier component counts as acceptance.

The complete recovered validation of `5c881bd` passed: analyzer clean,
**1,876 tests / 8 expected skips**, **361 namespace checks / 57 intentional
same-app skips**, and release JavaScript web compilation (including the optional
Wasm compiler dry run). An earlier interrupted run's intermittent artwork-pixel
failure is documented rather than counted as a pass.

### Later historical coverage and final verification

Published source `af94b82` adds frozen `fa577ac` artwork metadata, utility/template
and initial-rule schemas, plus image-readiness synchronization for the existing
strict drawer pixel test. All 50 archived source files match their exact Git
blobs; fixture generation is repeatable. These are synthetic repository-history
fixtures, not shipped-device or native artwork-file evidence.

The final integrated source tree passed analyzer, **1,879 tests / 8 expected
skips**, **364 preview-namespace checks / 57 intentional same-app skips**, and
release JavaScript web compilation with optional Wasm dry run. See the
[combined record](../../../apps/tablet/docs/migration_history_startup_integration_2026-11-10.md)
for the exact source tree, commands and publication verification. Runtime code
and entrypoints are unchanged by this follow-up. Production inventory/lease,
recovery-retention and disk-capacity policy, actual shipped native updates,
store restoration and device/accessibility acceptance remain open. No release,
PR, default merge, deployment or store action occurred.
