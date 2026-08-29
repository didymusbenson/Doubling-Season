# Inline Artwork Branch Code Audit

Date: 2026-08-29  
Branch: `codex/inline-artwork`  
Audited revision: `c5aeb27`

## Executive summary

The branch represents a substantial and generally coherent UI improvement, but it is not ready for a release cutover yet. The most serious risks are primarily in pre-existing persistence and migration infrastructure exposed by the enlarged unified board, rather than in the visual overhaul itself.

Before release, fix the unified-order migration, artwork metadata deletion behavior, non-atomic token-database update path, unsafe Hive backup/restore paths, non-transactional board undo/Rhys operations, and the known-red test target. The remaining findings are valuable hardening and architectural cleanup, but do not all need to block acceptance testing.

No production code was changed during this audit.

## Release blockers

### P0 — Startup can silently rewrite unified board order

The three providers independently interpret any item whose `order` is `0` as proof that ordering has not been migrated:

- `lib/providers/token_provider.dart:55-73`
- `lib/providers/tracker_provider.dart:87-103`
- `lib/providers/toggle_provider.dart:39-55`

Zero is both the legacy/default value and a legitimate first position. Consequently, a correctly ordered board can continue satisfying the migration condition on later launches. Each provider then renumbers only its own item type, creating cross-type ties and potentially changing the token/utility interleaving.

Recommendation: replace the heuristic with an explicit migration version and perform one unified migration over all board item types. Do not infer schema state from a valid domain value.

### P1 — Transient artwork failures can erase valid user selections

Artwork recovery conflates “not available right now” with “the selection is invalid”:

- `lib/widgets/mixins/artwork_display_mixin.dart:70-88` clears artwork when redownload fails.
- `lib/widgets/token_card.dart:176-180` clears the URL, set, and options.
- `lib/providers/token_provider.dart:1090-1106` also persists removal after a failed background download.

An offline launch, cache miss, temporary CDN failure, or storage error can therefore permanently remove valid artwork metadata. In the opposite direction, all three pickers can persist a remote URL even when the prerequisite download returned null:

- `lib/widgets/token_card.dart:1015-1021`
- `lib/widgets/tracker_widget_card.dart:540-548`
- `lib/widgets/toggle_widget_card.dart:501-509`

Recommendation: preserve the canonical selection independently from cache state. A failed download should show a fallback and retain a retryable error state; selection should be committed only after required validation succeeds.

### P1 — Token database updates do not enforce their compatibility or atomicity contract

`lib/services/token_update_service.dart` parses `min_app_version`, but availability checks only compare database versions (`:67-81`). The download prompt then proceeds unconditionally (`lib/utils/token_update_prompt.dart:36-44`). An older app can install a database that explicitly requires newer semantics.

The service also accepts an expected byte size without checking it (`token_update_service.dart:98-115`) and overwrites the active override directly (`:122-138`). A crash, full disk, or interrupted write can destroy the last valid override despite comments implying partial writes are avoided.

Recommendation: enforce the minimum application version, verify size/hash/parseability in a temporary versioned location, then atomically switch a pointer or rename the verified payload and manifest together.

### P1 — Hive backup and restore can amplify data loss

`lib/database/hive_setup.dart:203-236` asynchronously copies live, open Hive files and replaces the sole previous backup. Concurrent writes or process termination can produce a torn backup and eliminate the last known-good generation. Restoration deletes the live database before validating the backup (`:166-185`).

Recommendation: create a consistent snapshot, write and validate a temporary backup, atomically promote it, and retain at least one prior generation. Restore into a staged location and validate it before replacing live data.

### P1 — Board undo is destructive and non-transactional

`lib/services/board_undo_snapshot.dart:31-45` clears all three live boxes sequentially and then repopulates them sequentially. Any exception or termination between those operations can leave the board empty or partially restored. This is especially concerning because the mechanism is presented as the safety net for destructive board operations.

Recommendation: stage and validate the replacement or maintain a durable rollback generation. Never clear every live collection before a recoverable replacement exists.

### P1 — Rhys can persist only part of a confirmed operation

`lib/providers/token_provider.dart:907-980` merges, saves, and inserts Rhys results one at a time. Its error path acknowledges that some copies may be missing, but the caller at `lib/widgets/tracker_widget_card.dart:1387-1390` has no snapshot rollback comparable to Brudiclad.

Recommendation: calculate the complete result first, persist it as one recoverable operation, and restore the pre-action snapshot if any write fails.

### P1 — The checked-in test target is knowingly red and unrelated to the app

`test/widget_test.dart:14-29` is the untouched Flutter counter template. It pumps the production `MyApp` without Hive initialization, expects deleted sample-counter UI, and fails with provider/Hive initialization exceptions followed by a missing `0` assertion.

Verified command: `flutter test --reporter compact` → exit code `1`.

The repository follows a manual-testing policy, so the immediate remedy can be either removing the misleading template or replacing it with a meaningful supported smoke test. A known-red default test should not remain as a false release gate.

## High-priority hardening

### Persistence calls are inconsistent and frequently fire-and-forget

Status and counter sheets mutate a model, initiate provider persistence without awaiting it, and immediately rebuild or dismiss:

- `lib/widgets/token_status_sheet.dart:25-30`
- `lib/widgets/token_counter_management_sheet.dart:28-34`
- A custom counter path adds another direct save at `token_counter_management_sheet.dart:181-189`.

At the same time, many `Item` setters trigger unawaited `save()` calls (`lib/models/item.dart:24-27,35-42,49-58,65-74,81-95,110-113,129-141`), after which callers often save again. This produces write storms, unhandled asynchronous errors, and unreliable rollback boundaries.

Recommendation: choose one ownership model. Prefer pure validated setters plus explicit awaited mutation methods that batch related fields into one persistence operation.

### Utility inline commits can race or duplicate saves

Focus listeners launch commits without awaiting them (`tracker_widget_card.dart:314-325`, `toggle_widget_card.dart:280-283`), while collapse can invoke the same commits again (`tracker_widget_card.dart:432-435`, `toggle_widget_card.dart:401-404`). Name and description edits do not consistently share an in-flight future; the tracker value guard rejects a concurrent request rather than joining it (`tracker_widget_card.dart:763-766`).

Recommendation: use the same serialized commit-session abstraction already established for token editing across every editable board type.

### Artwork loading needs memory and network bounds

`lib/widgets/cropped_artwork_widget.dart:147-164` reads full payloads and decodes images without target dimensions. During expansion, compact and expanded decoded surfaces intentionally coexist (`token_card.dart:296-315`). Large custom images or several visible cards can therefore create significant native image-memory pressure.

Downloads in `lib/utils/artwork_manager.dart:211-244` have no timeout or response-size cap and accumulate response bytes in a growable list. The web crop path has the same broad risk.

Recommendation: bound download time and bytes, validate content type, decode near rendered dimensions, dispose codecs deterministically, and consider a shared decoded-image cache rather than one `ui.Image` per widget instance.

### Async `BuildContext` analyzer warnings include real lifecycle hazards

Several utility flows access `context` after dialogs or asynchronous work without rechecking `mounted`. A representative path is `lib/widgets/tracker_widget_card.dart:1473-1537`. Similar warnings occur around the other utility actions and artwork/new-token sheets.

Verified command: `flutter analyze` reports 20 findings, including multiple `use_build_context_synchronously` warnings.

Recommendation: resolve all warnings before cutover or document narrowly justified exceptions. Capture dependencies before awaiting and check the relevant state/context after each asynchronous boundary.

### Event subscriptions are append-only

`lib/utils/game_events.dart:16-25,38-43` stores process-wide listener arrays without an unsubscribe API. `TrackerProvider` registers closures during initialization (`lib/providers/tracker_provider.dart:38-47`) and does not remove them in `dispose`.

Recommendation: return subscription handles or removal callbacks and unregister them. Reinitialization and lifecycle churn should not retain disposed providers or duplicate effects.

## Medium-priority correctness and UX issues

- `lib/screens/content_screen.dart:69-78`: the collapse lock is not reset in `finally`. An unexpected exception can leave collapse/navigation disabled until the screen is recreated.
- Color editing mutates persisted models before the awaited provider operation and does not consistently roll back (`token_card.dart:541-556`, `tracker_widget_card.dart:512-519`, `toggle_widget_card.dart:473-480`).
- Empty utility names can restore text and veto collapse without visible feedback, leaving a logically active but unfocused editor (`tracker_widget_card.dart:339-346`, `toggle_widget_card.dart:295-302`). This should follow the recently requested “invalid focus loss reverts silently” rule while also ending the edit session cleanly.
- `lib/widgets/token_status_sheet.dart:50-104` uses a non-scrollable, minimum-size column plus keyboard insets. Small screens and landscape orientation can overflow.
- Counter two-row measurement should continue to be checked against the trailing add control and text scaling. It is easy for measurement logic and the actual composed row to diverge.
- Android release signing always binds a signing configuration whose properties can be null when `key.properties` is absent (`android/app/build.gradle.kts:12-17,43-55`). Fail early with a precise configuration message.
- `lib/main.dart:40-46` awaits in-app-purchase initialization before `runApp` despite describing the work as non-blocking. Store initialization latency can delay the first frame.
- Hive bootstrap broadly catches initialization failures (`lib/database/hive_setup.dart:40-101`) and can return a normal-looking result, moving the failure into later provider construction and obscuring the true recovery state.

## Architectural observations

### The unified board is correct in direction but over-concentrated

The state-stable wrapper chain in `ContentScreen` is important: keeping reorder, dismiss, identity, and `TokenCard` ancestry stable fixed the expansion snap and should be preserved. The explicit Hive-key `ValueKey` is also good defense against state reuse.

However, the board and item widgets now carry substantial responsibility:

- `lib/screens/content_screen.dart`: approximately 1,105 lines
- `lib/widgets/token_card.dart`: approximately 1,725 lines
- `lib/widgets/tracker_widget_card.dart`: approximately 1,947 lines
- `lib/widgets/toggle_widget_card.dart`: approximately 606 lines
- `lib/widgets/artwork_selection_sheet.dart`: approximately 1,198 lines

`_BoardItem.item` is also `dynamic`, so the central board dispatches through runtime type branches rather than a typed board-item contract.

Recommendation: do not perform a large refactor immediately before acceptance testing. After the release blockers are closed, extract typed board-row adapters and shared edit/artwork/control primitives incrementally, preserving the invariant wrapper/key structure with each step. The strongest first target is a common serialized edit session for tokens, trackers, and toggles.

### TokenCard remains the right visual reference, but shared behavior is incomplete

The branch successfully brought utility artwork, identity rails, contrast surfaces, full-width geometry, and inline editing closer to TokenCard. Some implementations remain duplicated or behaviorally inconsistent, particularly artwork selection and utility commit handling. Convergence should happen through small shared components and persistence contracts, not by copying more methods out of TokenCard.

### Documentation has operational drift

Active documentation disagrees about branding, database size, and deleted detailed screens:

- `AGENTS.md` states 942 tokens; the validated asset contains 948.
- Branding references alternate between Tripling Season and Doubling Season, while platform configuration is not uniformly described.
- `CLAUDE.md` and active planning documents still describe deleted `ExpandedTokenScreen`/expanded utility screens.
- Stale references appear in `docs/activeDevelopment/FeedbackIdeas.md`, `in_progress_features/ManaSymbolRendering.md`, `todo_features/EntersTappedToggle.md`, `todo_features/busTriggers.md`, and `new_release/RhysUtility.md`.
- The README still describes the older database source/count and pre-overhaul UI.

This is not merely editorial: these files guide future implementation and can cause removed navigation patterns or incorrect release configuration to be reintroduced. Update `AGENTS.md` and active development docs as part of the stabilization pass; label historical release documents explicitly when preserving old implementation notes.

## Verified strengths

- The token database is valid JSON with 948 records, and its manifest checksum and size match.
- New sampled Hive fields have `defaultValue` annotations and matching generated adapters; registered type IDs are unique.
- No deleted expanded-screen imports or routes remain in `lib/`.
- The web release and Wasm dry-run builds succeed. The web build emits a low-risk CupertinoIcons font warning that should be checked visually.
- The new token edit session has a useful commit-or-veto contract and restores values on persistence failure.
- Artwork load generations reject stale asynchronous completions, and keeping a stable compact art layer under the expanded overlay materially reduces blank flashes.
- The stable keyed board subtree is the correct solution to the former snap-open/state-destruction bug.
- No new dependency or obvious credential exposure stood out in the branch audit.

## Recommended stabilization order

1. Replace the order migration heuristic with one explicit unified migration.
2. Decouple artwork selection metadata from cache/download availability.
3. Make token DB installation staged, verified, compatibility-gated, and atomic.
4. Redesign Hive backup/restore and board undo so live data is never cleared before a validated replacement exists.
5. Make Rhys all-or-rollback.
6. Remove or replace the stale failing template test and bring analyzer warnings to an intentional baseline.
7. Standardize awaited persistence and edit-session serialization across all board item types.
8. Bound artwork download/decode memory and network behavior.
9. Correct active documentation and `AGENTS.md` before version cutover.
10. Only then begin incremental widget extraction; avoid a broad board rewrite during acceptance testing.

## Validation performed

- Read-only review of persistence, provider, UI, artwork, platform, build, and documentation paths.
- Independent parallel audits of database/platform behavior, inline editing/UI behavior, and whole-branch release readiness.
- `flutter analyze` — completed with 20 findings.
- `flutter test --reporter compact` — failed with exit code 1 because the sole test is the obsolete Flutter template and the app is pumped without Hive initialization.
- Web release and Wasm build verification — succeeded.
- Token database parse, record count, manifest size, and checksum verification — succeeded.
- Hive type/default/generated-adapter spot checks — passed.
- Working tree was clean at the start of the audit.
