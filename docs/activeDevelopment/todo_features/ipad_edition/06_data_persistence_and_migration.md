# Data, persistence and migration

**Status:** current-game state/history persistence and latest-action global undo are required; concrete storage engine, migration, session format, acknowledgement and preference policies remain proposals. Resolve D14–D24 in the [decision register](09_decision_register.md). Current-code statements refer to baseline `8894640543833eaf37bd62b971a0955c26bafa49`; see the [evidence audit](../../../../ai_docs/research/2026-10-20-ipad-edition-current-architecture.md).

## Existing behavior that constrains reuse

The current app has one active board. Token, tracker and toggle providers open hardcoded global boxes and enumerate all their contents. Models have no session/player field. Four provider instances would still operate on the same data. Rules have the same problem: preset counts use unqualified SharedPreferences keys and custom rules occupy one `tokenRules` box. Storage filtering alone cannot make those services player-safe. See [player isolation](04_player_isolation_and_rules.md).

Current `BoardUndoSnapshot` clones the entire board and restores by clearing/repopulating all three boxes. It deliberately emits no game events, which is worth preserving, but its restoration scope could erase another player's newer work. Rules undo separately captures preset counts and enabled flags for existing custom-rule keys; it does not recreate deleted definitions.

Existing native recovery tries backup restore, then recreates an unreadable box empty. Boot backups copy seven files sequentially into one overwritten generation; preferences, uploaded media and the `boardOrderOperations` journal are outside that allowlist. Web does not use this filesystem recovery. These mechanisms do not establish coherent multi-player session recovery.

**Schema correction:** Hive IDs 0–12 are assigned, including utility templates at 8/9 and rules at 10–12. The next currently unallocated ID is 13, **not an allocation for this feature**. Recheck before implementation. Preserve existing IDs, field indexes, box names and generated-adapter compatibility. Current `Item` fields extend through 17; legacy token/counter multipliers are intentionally removed in favor of rules. Do not propagate stale AGENTS summaries into new schemas.

## Proposed identity and state model

The following names describe responsibilities, not approved classes or adapter assignments.

| Identity/state | Proposed contract |
|---|---|
| `SessionId` | Stable identity for one saved game; independent of active screen/window |
| Persistent seat ID (name proposed) | Stable user-facing seat customization across games: player name and color/art presets; not a user account or visible quadrant |
| `PlayerId` | Game-local participant/value identity linked to its persistent seat; exact ID reuse schema pending |
| Visual slot ID / orientation | Presentation mapping for active persistent seats; not their customization storage key |
| `CommanderId` | Stable source identity linked to an owning PlayerId; distinct from recipient and seat; separate partner records |
| `EntityId` | Stable token-stack/utility instance identity; separate from token-definition composite ID |
| Session generation | Invalidates work from a previous game/reset boundary even if seats are reused |
| Player generation | Invalidates delayed work after a player-local replacement/reset when appropriate |
| Revision | Version used to order accepted changes and detect stale commands/undo |
| `CommandId` | Distinguishes retries from separate intentional identical actions |

Keep a persistent seat roster outside destructive game-value clearing. It stores name/color/art customization even when the seat is inactive. A session contains active-seat membership, participant mappings, visual placement, game configuration, table-level state, revision/generation and recovery metadata. Each participant contains life, typed player counters, city’s blessing status, active token stacks, active utilities, mana if enabled, rules state and relevant gameplay options. Source commander records associate CommanderId with owner PlayerId; incoming damage is keyed by recipient PlayerId and CommanderId, including self. Session-level monarch stores one optional holder PlayerId; day/night stores one shared designation including initial neither. These are required state responsibilities; concrete schema/classes remain proposals. Reusable definitions belong in libraries; active values belong in the session.

Each player has **two independent ordered sequences**: token entity IDs and utility entity IDs. Life has its own fixed-purpose state/surface. Model-type IDs do not identify a lane. Enforce one membership per runtime entity, valid references and deterministic order after recovery. Reordering one lane never renumbers another player's lane. Across-lane or across-player dragging requires a separately designed transfer command; it is not implied by reorder support.

Life requires signed integer semantics; current generic tracker decrement clamps at zero. Starting life is configuration, current life is active state. Commander damage is required: reference source commander identity and recipient PlayerId, including self, not only opponent seat. This avoids losing partner-commander distinctions or relabeling damage after reseating. Retain eliminated participants and their references unless D21 explicitly chooses otherwise; elimination must not silently delete history, tokens or cross-player references.

Mana is a typed quantity collection rather than an unstructured life counter. Its categories, restrictions and clearing rules are D27 in [utilities](07_utilities_tokens_and_decks.md). Storage must preserve whichever semantics are approved without assuming a turn/phase engine exists.

## Tracker integrity, history and export

Persist accepted tracker values together with their scope and identity, not only visible/nonzero counters. Distinguish disabled/hidden presentation from a zero/false value. Keep typed counter identifiers separate from localized labels and avoid merging same-named sources. Schema/version validation must check that holder/source/recipient references belong to this session; an empty three-player control slot cannot own player state. Source replacement and eliminated-player historical reference retention need explicit policies, not cascading deletion.

Record command origin/context, optional meaningful player attribution, affected seat(s)/shared scope, before/after values and operation/group identity for life, counters, blessing, damage and shared state. New commander damage/life is coupled and must be treated atomically by persistence/recovery/history; explicit ledger-only or life-only corrections are independent. Preserve shared-state revisions for safe monarch/day-night undo. Session export, if approved, includes these identities and active values; phone deck/setup v3 cannot represent them and must not be described as a full session backup. One chronological game timeline and global latest-action undo are accepted. Persist current history, undo information and game state coherently; preserve constituent commands beneath grouped rows. Any player’s different action closes the active group. Exact timeout tuning, retention bounds, archive/privacy/export fields and reset retention remain D16/D17/D22/D23/D33/D34. See [history and existing snapshot limits](game_history_and_undo.md).

## Persistent seats and reset boundaries

The accepted 4→2→4 behavior preserves seats 3/4 name/color/art through hiding and later reuse, including restart. Active membership/visibility must not be modeled as deletion of their persistent records. Normal Reset with board and Complete reset preserve that roster; a separate settings hard reset is the intentional customization-clearing route, whose exact scope still needs design. Do not relabel all existing source/recipient/history IDs by visible position.

Reset with board preserves active token entries but zeros counts/removes counters and preserves enabled utility selection. Complete reset clears tokens/utilities. Both restart configured gameplay values. Keep-board retains reusable token custom properties and enabled utility selection for remaining seats while zeroing/clearing temporary state. A removed seat loses live game-specific token/utility setup, even when remaining seats keep boards; a fully new game clears that setup by default unless keep-board is explicit. Persistent customization remains. Capture a coherent full-state/timeline archive before reset and restore historical game setup from it, not cleared live templates. Exact runtime/rule defaults, archive retention and customization-conflict policy remain open. Preserving the current game before archive loading is a proposed safeguard, not an accepted requirement.

## Storage alternatives — D14 and D24

**Proposal A: versioned session aggregate.** Store one serializable session envelope per SessionId in a dedicated tablet namespace, with in-memory player selectors and one command writer. Shared libraries remain separate. This simplifies consistent revisions, ownership, export and rollback. DTO conversion separates session logic from `HiveObject.save()` setters.

The cost is rewriting larger values during rapid taps or large games. Measure serialization, allocation, save latency and maximum session size on hardware. A single Hive value write reduces multi-record coordination; it does not justify an unconditional claim of crash-proof transactions. Define and validate durability before promising it.

**Proposal B: qualified records plus a recovery journal.** Store entities under session/player/entity keys, with ownership in records and lane indexes. This reduces granular write sizes and suits larger histories. It requires explicit multi-record consistency, reference checks, replay and cleanup. Awaiting several Hive writes sequentially does not make them one transaction.

**Proposal C: injected per-player repositories as a bridge.** Parameterizing current providers can help incremental extraction. It still requires replacing global events, rules preferences, order snapshots and undo. Per-player boxes alone are not an isolation architecture, and unbounded box creation needs a cleanup/recovery plan.

**Recommendation for a spike, unapproved:** start with aggregate semantics behind repository interfaces, retaining Hive as a viable implementation. Compare aggregate and record approaches against measured interaction/recovery scenarios before selecting the durable format. Flutter does not require keeping Hive; changing a local store does not require leaving Flutter. Shared-core extraction and distribution identity remain distinct decisions.

## Command persistence and crash recovery — D15/D17

A proposed single session writer serializes accepted changes initially. Logical concurrency still exists on one UI isolate because gestures, downloads, modals and persistence interleave. Commands carry explicit session/player context, generation, command ID, affected entities and defined revision expectations. Resolve current entities after awaited work; do not finish through a mutable “last active player.”

Proposed lifecycle:

1. Validate ownership, generation, references, supported types, bounds and revision policy before mutation.
2. Evaluate against a defined rules snapshot and produce explicit effects, including generated token identities and affected players.
3. Retain sufficient durable information to finish or restore a consistent revision. With records, write a validated operation plan before partial effects; with aggregates, preserve a known-good generation before promotion.
4. Persist/flush according to the selected store's proven guarantees, then acknowledge durable success and retire recovery information safely.
5. Recover idempotently on launch before exposing mutable gameplay state.

This is a proposed contract, not a ready-made algorithm. Specify each crash boundary, promotion rule and failure outcome during implementation. Replay applies recorded effects; it must not rerun token rules against changed presets and produce extra companion tokens. Repeating a CommandId yields the recorded result; a second intentional creation has a new ID even when its contents match.

If optimistic rendering is used, failed saves must expose retry/rollback state coherently. Coalescing rapid life taps needs an explicit allowable loss window; “autosave” is insufficient. Backgrounding can request a flush, but process termination may precede a lifecycle callback. Recovery cannot depend on receiving pause/detach.

Proposed generation backups retain a small bounded set of validated coherent session revisions with format version and integrity metadata. Corrupt or unsupported input is quarantined while the prior valid session remains available. Do not automatically wipe an entire table because one utility/image/import is unreadable. A recovery message distinguishes restored older revision, isolated damaged content and unrecoverable loss.

Multiple windows are a separate writer-ownership decision: initially one live writer per session is a plausible proposal. Independent windows must not silently compete through cached preferences or global singletons. Future-friendly IDs do not promise networking or cloud sync.

## Utility visibility versus gameplay state

Persist each seat’s curated utility order and visibility separately from its authoritative runtime values. Corner-X hiding after confirmation does not clear a value; restoration through Utilities must not create a second mana pool/counter. Keep hidden nonzero values discoverable after reload. Storm/mana are default-visible but dismissible for the game. Reset-with-board, complete reset, removed-seat clearing and archive restore retain their accepted semantics; exact initialization of defaults and hidden entries at reset/setup boundaries still needs a field-level mapping. Visibility changes are not gameplay counter changes. Whether visibility/order changes enter the undo timeline requires design; do not silently log hiding as zeroing.

## Undo and game-level operation policy — D16/D22/D36

**Latest-action undo requirement:** select the global latest action, then restore only its affected participant/entity/shared write set using command inverses or version-checked snapshots. This is not a per-player undo stack or arbitrary selected-entry undo. Include rules/life/mana only when the command changed them. Another player's later actions survive. Existing whole-board snapshot restore cannot be reused unchanged.

A local snapshot still has conflicts if the same player's subsequent action depends on the removed state. Define revision checking, retained undo depth and conflict handling within the latest-action contract. Repeated-like-action grouping and rapid-life net settling are accepted; any player’s different action interrupts the active group. Never claim unconditional undo while silently overwriting newer state.

**Game-level design:** a reset/new-game operation captures its complete affected state, invalidates stale work and commits one recoverable transition. A table-wide barrier and active-editor resolution are possible approaches only; D36 leaves global-input pause and exact confirmation/finalization open. The UI previews exactly what resets: life, each typed counter, city’s blessing, self/partner source-damage entries, monarch, day/night, tokens, utilities, rules, mana, history, seating and setup are separate choices. Apply the two accepted full-reset modes; removed-seat board clearing, reusable setup retention and pre-reset archive restoration are accepted; exact runtime/rule mappings and archive restore/retention details remain unresolved. A local life/board reset must not silently clear shared state. Recovery/undo checkpoints include every field actually changed, preserving unrelated player and shared revisions. Resetting gameplay does not delete library decks or custom art implicitly.

The existing non-dismissible Undo/Accept completion dialog is a phone reference, not automatically the tablet interaction. A table-wide modal blocks four players. D16/D22 must choose finalization and interruption behavior. Any restore writes state without firing ETB, board-wipe, replacement or utility triggers; commands/history identify it as restoration.

## Decks, legacy import and phone safety — D18/D23

A current deck is a **setup template**, not a session save. Save deduplicates token stacks and preserves a mixed template order; load creates tokens at amount zero, trackers at defaults and toggles OFF. It does not preserve life, active counters/status, mana or rules. Current export schema is v3 and contains template artwork URLs/options, but not embedded media or the deck's custom box artwork. Foreign `file://` paths are not portable.

**Accepted tablet evolution (D38):** presets contain a reusable token list and utility preferences; seat load creates zero/empty-state selected token entries and configured utilities. Store this setup separately from active gameplay and archived sessions. Optional deck image application updates only the target seat’s saved life art, never its player name or another seat’s art. Commander selection is not included by this decision. Midgame merge/replace, life/history effects and exact preference/default mappings remain open. Existing v3 is not automatically a lossless format for these additional fields or image assets.

Proposed compatibility contract:

- Continue supporting phone v3 setup import through an adapter; importing to a library does not mutate a player board.
- Choose the target player explicitly when loading. Deep-copy runtime entities when two players use one setup.
- Stable-filter old mixed order into token and utility lanes, preserving relative order within each. Mixed-lane adjacency cannot be preserved.
- Define append/replace by lane and player. Loading a setup must not reset another player, life, mana or rules as a hidden side effect.
- Give whole-session export a distinct artifact type and version containing ownership, generations/references, active values, lanes, configuration and approved history.
- Tablet-only utilities cannot pass losslessly through phone v3. Choose explicit subset export with a loss report or a new format that older apps reject.
- Validate complete imports before commit: types, limits, uniqueness, ownership, references, utilities and asset manifest. Unknown future versions preserve original input and explain incompatibility.

No destructive phone migration is authorized. A separate installable app needs deliberately chosen identifiers/storage and explicit interchange; a new repository alone does not create a new app sandbox. D01 now selects a separate app, not a mode in the existing distributable. Preserve legacy boxes/adapters and isolate the new product’s sessions even when source is shared in this repository. Copy-first conversion verifies destination counts/content before marking completion, is idempotent on retry, retains its source, and emits no gameplay events. Do not invent automatic assignment of an old board to Player 1.

## Preference and library scopes — D19/D20

Persistent seat name/color/art retention is accepted; remaining scopes below are proposals. A persistent seat, optional saved profile, game-local participant and visual slot are distinct responsibilities; guests need no account.

| Existing value | Proposed scope / open choice |
|---|---|
| Seat name / life color and art presets | Persistent per-seat customization; normal resets/hiding preserve it. Optional explicit preset-image application can update that seat’s saved life art; player name stays separate |
| Summoning sickness enabled | Player session option, optionally copied from profile default |
| Rules preset counts; active custom-rule enabled/count state | Player session gameplay state |
| Custom rule definitions | Shared library or profile library; active instances remain player-scoped |
| Artwork style | Device default with optional player override; current default is `fullView` |
| System/manual theme | Device/app |
| Favorites and recents | Shared library or profile/player view; decide whether one player's activity displaces another's recents |
| Experimental feature switch | Device capability; disabling it must not silently destroy other players' active rules |
| Artwork preferences | Accepted per-seat selections; shared image bytes/catalog definitions do not imply globally shared mutable choices |
| Custom token definitions and decks | Shared reusable library initially proposed, with distinct runtime copies |
| Token database versions/checks/dismissals | Installation-wide data-source management |
| What's New dismissal | Installation/release |
| Purchase cache and collector appearance | Installation/account/store; not in-game PlayerId or portable entitlement proof |
| Compaction timestamps and migration gates | Store/installation maintenance |
| Legacy multiplier keys | Compatibility-only removal metadata; do not revive gameplay controls |

Downloaded art can share a content-addressed/URL-keyed cache without sharing mutable selection. Custom uploads are user assets, not disposable downloads: managed IDs, retention/reference rules and portable packaging need D20. Export must package bytes or report omitted assets; a missing image degrades rendering without erasing selected metadata. Never redownload art solely to enrich attribution.

## Operational completion criteria

Before implementation acceptance, demonstrate restart recovery at each save/reset/import/reorder boundary, disk-full handling, invalid imports, interrupted migration and stale callbacks. Verify stale local undo cannot bypass newer game actions and each eligible global undo preserves unrelated state and that seat changes preserve ownership/damage references. Measure rapid life/counter input, self/partner damage edits, shared-state transitions and large boards on actual hardware. Verify monarch, blessing, day/night and source/recipient ledgers survive restart without duplicate authority or broken references. Confirm legacy phone decks/data remain unchanged. These are planned manual/device checks, not completed results; the validation plan owns detailed scenarios.
