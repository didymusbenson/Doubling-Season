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
| M1 | Complete source inventory and private consistent snapshot. Legacy `lib/database/hive_setup.dart` can recreate failed boxes; `lib/utils/constants.dart` assigns IDs 0–12. | Read copied fixtures without normal destructive recovery; inventory boxes, adapters, prefs, local files, source version and hashes; refuse corrupt/unknown sources without changing them. Obtain actual shipped-version fixtures later. | Partial: complete detached-model capture and versioned inventory are implemented; live/raw acquisition and shipped fixtures remain open. |
| M2 | Independent live-board and saved-deck conversion. `PresetService.importJson` accepts phone schemas 1–3; it is not installation migration. | Stable source-to-destination IDs, duplicate decks/stacks, order, counters including power-only/toughness-only, explicit utility counterpart map, report unsupported/ambiguous data. Never feed live state through zero-state preset load. | Partial: separate deterministic live/preset converter implemented and tested; built-in/action utilities, independent-axis counters and ambiguous mappings block fixture commit. |
| M3 | Owned artwork and credits. Table has immutable media and v4 embedded-asset imports; legacy deck JSON omits cover/bytes. | Copy/hash/reopen local bytes, remap all references including custom library/covers/preferences; preserve missing-file metadata with usable fallback. Validate offline reopening, corrupt/oversize assets and interruption. | Partial: fixture journal copies, hashes, remaps and reopens supplied bytes. Actual file acquisition, image validation and production media authority remain open. |
| M4 | Recoverable durable commit and idempotent restart. Table repository has checksummed generations; source data spans other stores. | Versioned journal, staging generation, durable marker and reopen verification; inject failure at every boundary. Retry cannot duplicate or replace later gameplay. Keep recovery material; retention/cleanup is not implicitly approved. | Partial: isolated durable journal, revisioned receipt, retry serialization and every-boundary fault injection implemented. No production coordinator or later-play protection integration yet. |
| M5 | Saved setup fidelity and scope. `PresetService` saves/renames/deletes/imports/exports and loads Replace/Append; loads are seat-scoped commands. | Preserve token `extra` display style, source identity and deck metadata or report limitations; rich-art roundtrip and failed writes; Save/Replace/Append/Undo on multiple seats, cover apply/undo, no life/history collateral reset. Audit original editing behavior before adding an editor. | Partial: legacy preset metadata/order/cover retained, artwork display style survives save/load, and fresh seat-scoped loads tested. [Audit gaps](../todo_features/unified_tripling_season/preset_audit.md) remain open. |
| M6 | Custom library, favorites/recents, preferences and rule definitions. Current Table and legacy scopes differ. | Explicit key/field map, unknown-key recovery, no global artwork preference silently applied to every seat/new game; preserve unsupported rules rather than enable/substitute them. | Partial: custom definitions, favorites/recents, theme and sickness mapped; all preferences and rules retained. Non-default multipliers, active built-ins and unsupported rules block activation. |
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
| P2 | Custom rule authoring is deliberately deferred in Table; source-owned built-in effects are implemented. | Preserve definitions and original enabled state in recovery; do not claim unsupported effects run, substitute built-ins by name, or silently activate them. A release needs restored behavior or an explicit disposition. |
| P3 | Original collector hearts have 26 styles (`lib/models/heart_style.dart`); baseline Table offers five solid colors (`ui/support_sheet.dart`). | Exact legacy style and entitlement are preserved; the original renderer now retains all 26 named/gradient styles in verified same-app mode. Table still only offers five selectable solids; full picker/native cosmetic acceptance remain open. No approved downgrade. |
| P4 | Table preset tools are not automatically equivalent to every original deck-edit flow. | Audit `lib/screens/deck_detail_screen.dart`, `decks_list_screen.dart`, `providers/deck_provider.dart` and actual Table UI. Record precise original operations and roundtrip loss before proposing missing editors/overwrite. |
| P5 | Legacy trackers store `longPressIncrement`; Table uses its current hold/acceleration interaction. Toggle on/off art can also differ. | Preserve raw non-default values and both artwork choices. Decide mapped behavior versus explicit compatibility handling; do not flatten configuration to a presumed default. |
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

**Next technical work:** raw consistent source acquisition and shipped adapters;
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

Combined validation is in progress. A final result will distinguish focused,
full, namespace and build checks from still-unrun native/store acceptance.

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
