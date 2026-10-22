# Decision register

**Last updated:** 2026-10-22. **D01/D03/D04 have accepted product boundaries; D05/D07 have accepted two-player layout and three-player empty-slot decisions**, with implementation details still open; D26 accepts full tracker fundamentals, with detailed policy gates open; D09 accepts one keyboard at a time; D41 settles sequential modal use; native/IME validation remains. D19/D21 now accept persistent seat customization and D22 accepts two full-reset modes; removed-seat game-data clearing and pre-reset archive restore are also accepted; runtime field mapping and restore transaction/UI details remain open; D33 retention and safeguards are accepted. D37 accepts curated utility customization and default-visible dismissible storm/mana; shared-panel count mapping is accepted (three/four-player central strip/panel; two-player thin shortcut divider). Other decisions remain open unless explicitly noted below. Recommended defaults are proposals, not approvals. Confirmed requirements C01–C16 are in [README](README.md). Flutter with player-facing custom keyboards is the chosen direction, subject to prototype validation.

Use stable IDs in later discussions, commits and acceptance notes. Answering one decision does not approve every downstream proposal. In particular, approving the screenshot layout does not choose the storage design, app distribution or release inventory.

## Suggested review order

1. **Product and physical table:** D01–D07, D26–D28. Establish what we are making, for whom, on what screen, and what the life centerpiece must do.
2. **Safety and technical boundaries:** D09–D25, D29. Settle isolation, concurrency, storage, undo, recovery and interoperability before domain implementation.
3. **Release cut and evidence:** D08, D30–D35. Choose utility parity, workloads, offline/update behavior, distribution details and final gates after the prototypes expose costs.

With product boundaries, two/three-player layout direction, single-keyboard concurrency and D26 tracker categories settled, the next discussion can focus on remaining four-player geometry, keyboard handoff and remaining tracker/history details (correction UI, timeout tuning, reset/archive retention and inventory extensions). The dossier supports answering the rest incrementally; there is no need to answer every question at once.

## Product, layout and interaction choices

| ID | Question | Recommended starting point | Alternatives / consequence | Needed by |
|---|---|---|---|---|
| D01 | Separate product; exact packaging? | **Accepted:** separate app / new product; same repo acceptable with proper directory isolation | Existing-app mode not selected. Exact directories, packages, IDs and distribution mechanics remain open | P0 setup; lock before release config |
| D02 | Is “IPAD EDITION” a codename or public name? | Codename; continue referring to relationship with Tripling Season | Public branding/store identity needs a deliberate decision; do not copy screenshot names | Before public assets/store work |
| D03 | Which product platforms? | **Accepted:** Android, iOS and web | Device/browser floors, release order and platform-specific gates remain open; Windows/native macOS not added | P0 matrix; P5 release evidence |
| D04 | How many players are required? | **Accepted:** customizable 2–4 initially; **deferred:** expansion to six | Preserve design leeway; exact 2/3/4 layouts remain open. See [six-player expansion](six_player_expansion.md); teams not approved | P0 layout and P1 model |
| D05 | How do seats face the table? | **Two-player accepted:** matched opposite-facing 0°/180° layouts, local token-left/life-upper-right/utilities-below-life | Four-player arrangement remains proposed as original sketch; 90°/270° and selectable orientations remain open. See the [layout mockups](02_layout_and_interaction.md) | P0 |
| D06 | What device/layout scope must MVP support? | **Accepted:** tablet-first, iPad mini through full-size iPads and Android tablets; complete active 2–4-seat view, no MVP phone/focused-seat mode | Web retained at tablet-suitable viewport. Exact minimum geometry, orientation/aspect-ratio and below-floor resize handling need validation; foldable focus is a deferred major version | P0/P5 |
| D07 | Where do life and lanes sit? | **Two-player accepted:** token lane left, life top right, utilities below life in each player’s local perspective | Dedicated life corners and attached below-life commander/counter shortcuts accepted; separate utility list/shared panel. Two-player life uses opposite corners. Shared central strip/panel between paired seats for three/four players; thin shortcut divider for two. No one-player scope. Three-player selectable empty control slot remains accepted; dimensions open | P0 |
| D08 | Which existing features must reach first-release parity? | Inventory every utility and token workflow; explicitly approve omissions | All parity increases initial scope; a reduced cut needs clear unavailable features and no silent behavioral changes | Before P4 |
| D09 | How much simultaneous interaction is required? | **Accepted:** one keyboard at a time; no simultaneous keyboards | D41: any modal blocks all background controls; tapaway dismisses without click-through. No queued second editor or busy feedback; preserve operation-specific commit/cancel semantics | P0 |
| D10 | What can expand simultaneously? | D40 selects shared detailed-editing workspace; compact inline expansion limits remain proposed | Existing board uses collapse-first, then a fresh tap to expand another item. Adapt nonmodal expansion scope deliberately; all modals are sequential under D41 | P0/P3 |
| D11 | How do keyboard/native flows arbitrate? | **Input direction accepted:** any keyboard faces its initiating player, using a custom Flutter panel; one keyboard at a time accepted, D41 sequential modal use accepted; native/IME implementation needs validation | OS keyboards do not expose arbitrary per-seat rotation. Native fallbacks, drafts, accessibility and IME need validation; see [deferred options](custom_keyboard_options.md) | P0 |
| D12 | What accessibility view is needed? | Player-named semantics, large-text adaptation, accessible reorder; prototype focused single-orientation view | Four rotated traversal groups alone may be sufficient only after hardware review | P0/P3/P5 |
| D13 | Where do new/split/copied results go? | **Existing-design baseline:** append ordinary entries; source-adjacent split/copy; preserve route-specific companions/merge behavior | Adapt order allocation to seat/lane scope; do not reopen generic placement or merge every same-name stack. See audit | P1/P3 |

D07 geometry must be validated together with D05 orientation. A fixed local left/right order cannot simultaneously maintain the sketch's physical inner/outer lanes after every rotation without an explicit mirrored composition. D06 is a product promise, not a generic Flutter breakpoint.

## State, recovery and interoperability choices

| ID | Question | Recommended starting point | Alternatives / consequence | Needed by |
|---|---|---|---|---|
| D14 | What is the durable session representation? | Spike versioned aggregate semantics behind repository; compare to qualified records | Aggregate rewrites may be expensive; records need journal/reference consistency; per-player boxes alone do not solve scope | P1/P2 |
| D15 | How are commands, stale previews and rules revisions ordered? | Per-player intent ordering feeding one writer initially; stale scoped previews require refresh/reconfirmation | Independent writers require multi-player coordination; committing frozen rules is viable only with explicit UX | P1/P2 |
| D16 | What undo model is promised? | **Accepted:** game-wide chronological history with player attribution; undo walks latest action globally. Repeated like actions group; any player’s different action or a time gap starts a new line; token add/remove stay separate | Life may net rapid ± taps, settling about 1–2 seconds after inactivity. Exact tuning, undo presentation and reset interactions remain open; no arbitrary selected-entry or per-player undo stack | P1/P2/P3; V45–V47 |
| D17 | What resume/history guarantees are required? | **Accepted:** current game state and history persist and reload their last saved state | Concrete write/acknowledgement/recovery format and bounded retention need design; prior-games archive remains D33; no current implementation proof | P2; V47 |
| D18 | Is legacy phone-board import needed? | Explicit copy-only import to a chosen player if needed; no automatic Player 1 assignment | No live-board import is simpler; same-app mode switch still needs namespace isolation | P2, depends D01 |
| D19 | Which preferences belong to a player/profile/device? | **Accepted:** persistent seat player name and color/art presets survive between games and normal resets | Separate settings hard reset clears customization; exact scope/UI and other preference/rule retention remain open | P1/P2 |
| D20 | What libraries and media are shared? | Shared definitions/decks/download cache; explicit active selections; managed uploaded assets | Profile libraries add isolation; portable media packages add format/retention work | P2/P4 |
| D21 | What happens to seats when counts/placement change? | **Accepted:** player is a persistent seat; 2-player setup hides seats 3/4, later 4-player setup restores their customization | Visual slot/game participant and persistent seat are distinct responsibilities. Removed seats lose game-specific tokens/utilities but retain customization. Elimination/replacement behavior and exact ID schema remain open | P1/P3 |
| D22 | Which reset actions exist and exactly what do they change? | **Accepted:** Reset with board keeps entries at zero/no counters and enabled utilities; Complete reset clears tokens/utilities. Both restart configured player count/game config, restore life and clear temporary damage/counters/game statuses | Preserve seat name/color/art and reusable setup only when keep-board is explicit; removed seats lose game-specific tokens/utilities. Pre-reset full-state/timeline archive restore accepted; exact runtime/rule defaults remain open; D33 settles restore safeguards and ten-snapshot retention | P1/P2/P3; V23/V48–V49 |
| D23 | How do deck/session files interoperate? | Read phone v3 setups; stable-partition lanes; distinct versioned session artifact | Tablet subset export needs omission report; richer setup version needs compatibility/rejection strategy | P2/P4 |
| D24 | Where is the shared-core boundary? | Extract proven domain/catalog/planner interfaces incrementally after interaction spike | Immediate monorepo/package overhaul delays feedback; copy/fork reduces initial setup but accumulates drift | P1; depends D01 |
| D25 | Who owns modifiers and where do they apply? | **Accepted:** each seat owns its modifiers; local versus global applicability is explicit; global sources such as Primal Vigor affect the table | One source record, derived applicability; recipients cannot remove another seat’s source from their panels. Propagated indication versus read-only Other effects UI remains open; reset activation mapping and token control transfers remain separate unresolved details | P1 and release claims |

The persistence and concurrency decisions must agree. A single session writer can serve independent UI; it does not mean a global input lock. Conversely, independent visual quadrants do not make async writes atomic. D16 must name how a pending local undo interacts with the same player's later actions, not only other players' actions.

## Feature depth and release choices

| ID | Question | Recommended starting point | Alternatives / consequence | Needed by |
|---|---|---|---|---|
| D26 | How complete is the life tracker? | **Accepted:** life, relevant player counters (energy/poison/experience explicit), city’s blessing, monarch, shared game-level day/night, commander damage by source including self and distinct partners | **Accepted:** new damage also subtracts life as one undoable action, independent corrections, warning-only thresholds and manual monarch/day-night claims. Inventory additions, bounds/visibility, tax and detailed UI remain open; reset retention is D22. [Sourced inventory](03_life_and_game_controls.md) | P0 capacity; P1/P2 scope/state; P4/P5 acceptance |
| D27 | What does the mana pool support? | **Accepted:** default-visible dismissible/restorable utility. Proposed mechanics: six-type manual pool, explicit clear/undo, no inferred phase or token actions | Tagged restricted/snow buckets or payment assistant need much richer modeling/UI | Before P4 mana |
| D28 | Which universal tools beyond resets are useful? | Three-player empty slot provides quicker access to game controls, with dice named by the user; exact inventory/behavior remains open | Monarch/day-night tracking are confirmed by D26; initiative, turn indicator and timer remain candidates; dice rules/options are not settled; no implied automatic housekeeping | P0/P4 |
| D29 | Does the separate app share data with the phone app? | Preserve phone behavior; explicit interchange proposal | Shared active data adds migrations, libraries and regression obligations; an existing-app edition is not the selected product shape | P1/P2; within D01 |
| D30 | What is the supported hardware/workload floor? | **Accepted size scope:** small tablets including iPad mini through full-size iPads and Android variants; measure realistic workloads across that range | Exact generations, OS/browser versions, viewport dimensions and performance budgets require evidence; dropping small tablets or substituting focused-seat mode is not an approved escape | P0/P5 |
| D31 | What works offline and when may catalog updates interrupt? | Core play/resume offline; defer noncritical maintenance during play | Online-only artwork/downloads must degrade cleanly; web storage needs separate guarantees | P2/P4/P5 |
| D32 | How is the edition priced and entitled? | Defer commercial decision; keep in-game players separate from purchase identity | Separate purchase, existing entitlement, free edition or upgrade each need store policy/product work | Before store implementation |
| D33 | What happens to completed games? | **Accepted:** restorable archive of full state and timeline immediately before reset; restore historical seat game setup | **Accepted:** save current before restore; last ten archived game states, oldest evicted; active working game separate. Restore state/timeline without overwriting saved decks or permanent seat customization. Full history per snapshot; transaction/selection UI still needs design | P2/P5; V50 |
| D34 | What participant/media information is retained or exported? | Local guest labels; explicit export contents; no analytics/account requirement | Persistent profiles, analytics, custom photos and share bundles need deliberate retention choices | P2/P4 |
| D35 | What proves readiness and governs format upgrades? | Versioned formats, recorded manual/device acceptance, compatibility and recovery gates | Additional platforms/features each add a gate; current docs alone prove none | All phases, final P5 |

## Modal policy and existing-design carryover

| ID | Question | Accepted direction | Remaining work | Needed by |
|---|---|---|---|---|
| D41 | What happens while any modal is open? | Entire table waits; tapaway dismisses through an app overlay with no click-through. No queued second editor/takeover/busy message. No routine toasts/snackbars; exceptional use only if genuinely unavoidable | Validate pointer/keyboard/accessibility barriers, async save recovery and native surfaces; carry forward operation-specific current commit/cancel behavior per audit | P0–P5; V57–V59 |

[Existing behavior audit](existing_behavior_audit.md) classifies **every D01–D40 decision** and supplies code evidence. Existing behavior is the conceptual baseline, except where explicit tablet decisions override it; code quirks or bugs are not product requirements.

## Shared editing workspace

| ID | Question | Accepted direction | Still open | Needed by |
|---|---|---|---|---|
| D40 | Where do detailed seat editors/search open? | **C selected:** larger shared central workspace; target seat identified, player-facing editor/results/one keyboard. Replaces mandatory seat containment; central position does not change command scope | Dimensions, editor-by-editor use and rotation control remain open; D41 settles modal blocking/dismissal and no queued handoff. Not every quick adjustment requires a large modal; generated styling/board/keyboard details not normative | P0/P3; V56 |

## Token-art lifetime clarification

| ID | Question | Accepted direction | Still open | Needed by |
|---|---|---|---|---|
| D39 | How long do per-seat token-art preferences persist? | Current game only; save choices in deck preset, load into target seat. Fresh game does not inherit prior preferences. Keep-board retains chosen artwork as reusable board setup; archive restore restores historical choices | Exact fallback and custom-asset retention/reference isolation; midgame load semantics remain D38. Persistent seat name/life appearance is not revoked | P1–P5; V55 |

## Deck/preset evolution

| ID | Question | Accepted direction | Still open | Needed by |
|---|---|---|---|---|
| D38 | What does a saved deck/preset provide? | Reusable token list + utility preferences; chosen seat loads configured utilities and selected zero/empty-state token entries. Optional deck image can supply that seat’s saved life art; token-art choices saved in preset and applied per current-game seat (D39); player name separate | Midgame Replace/Append accepted for target-seat preset-managed fields only, each one undoable action; life/damage/player counters/timeline preserved. Exact preference/default/image UI/format remains design work. Commander selection not approved | P1–P5; V54 |

This evolves the existing Decks feature, not a live-game save. It refines D19/D20 artwork scope and D23 interchange, while preserving accepted reset/archive behavior and independent seat customization.

## Utility layout clarification

| ID | Question | Accepted direction | Still open | Needed by |
|---|---|---|---|---|
| D37 | How customizable are utilities? | Curated available kinds; per-seat visibility and hold-drag order; corner-X dismissal with confirmation modal; restore through Utilities. Storm and mana default visible but dismissible for game. Hiding preserves values; separate clear and discoverable hidden nonzero state | Exact inventory/mechanics, restored ordering, nonzero discoverability UI, reset/default/hidden-entry mapping and whether presentation changes enter history. Not arbitrary resizing or widget authoring | P0–P5; V52–V53 |

## Control context clarification

| ID | Question | Accepted direction | Still open | Needed by |
|---|---|---|---|---|
| D36 | Are seat and central controls strict ownership/permission zones? | **No.** Seat-context actions affect that seat (token search, customization); history, wipes and resets default to app/game context. Separate affected seats from meaningful player attribution; no actor inferred from placement | Wipe targeting and exact impact UI remain open. D41 now mandates a UI barrier for any modal; it is not a permission model or database transaction lock | P0–P3; V51 |

User clarification: “Central controls, or game level controls default to the app itself not a specific player like viewing the log or handling wipes and resets.” This refines data-scope isolation, not the accepted persistent seats, keyboard orientation, history order or reset semantics.

## Accepted product decisions — 2026-10-21

Source: direct user design discussion; quotations preserve the decision boundary, not an implementation claim.

- **D01 accepted:** “I think we need to build a separate app” and “consider it a new product”; “I'm okay with it living in the same repo if we isolate it properly in its own directories.” Rationale: the evolution warrants its own product. Same-repo isolation is permission, not a mandated packaging scheme. Affects product, architecture and legacy-data gates; identifiers and package extraction remain open.
- **D03 accepted:** “Cross platform, android, ios, web”. These are product targets, not evidence that all platforms build or ship together. Affects the platform matrix and P0/P5 validation; support floors and sequencing remain open.
- **D04 accepted / expansion deferred:** “Initial scope should be customizable 2-4 players with a deferred feature doc to expand to 6. The designs should have room and leeway to make 6 players possible.” Affects layout/model assumptions and validation. See [six-player expansion](six_player_expansion.md); six-player implementation awaits later review.
- **C02/C13 direction accepted; D09/D11 partially unresolved:** following the Flutter custom-panel solution discussion, the user said “document it as ANY keyboard” and requested later exploration of custom keyboard options including mana symbols. Record any keyboard input as player-facing, not merely search/rename. Flutter/custom panel is the chosen direction pending proof. The initial “ANY keyboard” answer did not itself settle concurrency. The subsequent explicit answer **“No simultaneous keyboards.”** now settles **one keyboard at a time** (D09). Preserve command scope and operation-specific edit resolution; D41 now requires finishing/dismissing the modal before a fresh next-player interaction, with no queued request or takeover. Affects layout/input host and V34; option inventory stays [deferred](custom_keyboard_options.md).

- **D05/D07 two-player layout accepted:** “In two player, we'll have matching layouts mirrored - token lane left, life total top right, utilities under life total.” Apply this in each opposite-facing player’s local perspective. The [two-player image](reference/two-player-concept.png) is concept evidence, not a measured layout.
- **D04/D07 three-player empty-slot controls accepted:** the user clarified “I meant 3 player yes. In 3 player, the 4th seat has controls.” The [three-player image](reference/three-player-concept.png) and original request establish a setup-selectable empty slot from the four-seat base, with expanded game controls such as dice/full reset. The pictured P4 slot is not mandatory. No empty seat is introduced into four-player play. Detailed control/geometry choices and D22 reset semantics remain open; faster access does not waive destructive-action safeguards.

- **D26 tracker depth accepted:** the user requests “life totals, all relevant counters (energy, poison, experience, etc), monarch, game level night and day, cities blessing, and so on” and “commander damage per source including self.” They explicitly ask to use Lifetap’s fundamentals without copying its interface. This settles categories and named examples, not every reference feature/default. The [inventory](03_life_and_game_controls.md) maps radiation, initiative, tax, Treasure and supporting tools to evidence and remaining decisions. Preserve distinct source/partner identities and intentional shared-state ownership. Subsequent accepted bookkeeping: new damage/life is coupled as one undoable action; either value can be corrected independently; thresholds warn without elimination/disabled controls; monarch/day-night are manual. Two reset modes are now accepted under D22; remaining runtime/rule mappings and archive presentation/transaction details and UI remain open. Affects layout, command isolation, persistence/history/export, architecture/reuse, V05/V41–V44 and future six-player capacity.

- **D16/D17 history accepted:** user requests a game history for undo with repeated-like-action spooling, separate token create/delete lines even at net zero, and net life adjustment settling after about 1–2 seconds. They clarified “Things that happen in a game are part of a GAME'S history” and “undo should walk back the last thing done”; state/history must persist and reload. They answered “correct.” to the explicit P1 Soldier → P2 life → P1 Soldier three-entry example: any player’s different action closes the active group. See [history and source audit](game_history_and_undo.md). Ten-snapshot retention and restore safeguards are accepted; exact timeout tuning, detailed UI and transaction design remain open; no arbitrary selected-entry undo is implied.

- **D19/D21/D22 reset and seat decisions accepted:** full resets restart using the specified player count/game configuration. “Reset with board” retains token entries at zero with no counters and currently enabled utilities/widgets; “complete reset” clears tokens/utilities and restores life. Temporary damage/counters and monarch/other game statuses reset. The user’s players are persistent seats retaining names and color/art presets unless separately hard-reset in settings. A two-player game hides seats 3/4 without deleting that customization, which returns in a later four-player game. See [reset contract](03_life_and_game_controls.md). Follow-up accepts reusable token properties on keep-board, clears game-specific tokens/utilities from removed seats, and permits loading the full pre-reset state/timeline from an archive. New games clear game setup by default unless keep-board is explicitly selected. Historical restore uses archived seat setup, not the cleared live setup. Saving the current game before restore is now required; retain ten archived states with full timelines, oldest evicted, and do not overwrite saved decks or permanent customization. Exact transaction/UI design remains open.

Revisit a settled boundary only through an explicit later decision. A prototype can expose constraints requiring that discussion, but does not silently change product scope. Cloud-first visual/interactive inspection must precede asking the user to install a build; physical iPad and target-platform acceptance remain separate gates in [delivery](08_delivery_validation_and_risks.md).

## Architecture decision records

ADR-P01 records the chosen framework direction, pending prototype evidence. ADR-P02–P04 remain **proposed** implementation contracts.

### ADR-P01: retain Flutter for the first prototype

Context: current infrastructure is Flutter/Dart; requested changes concern presentation and player scope. Chosen direction: retain Flutter with custom player-facing input panels for any keyboard input. Inspect the running prototype in the cloud first, then prove the highest-risk physical interactions on hardware. Consequence: avoid spending the first iteration replacing reusable domain logic. Revisit on a reproducible critical framework/platform limitation, not merely because current phone widgets need redesign. References: C02, D03/D05/D11/D30, [research](10_research_sources.md).

### ADR-P02: immutable command scope is a domain invariant

Context: current services are app-global and async flows can outlive route/session state. Proposal: explicit session/player/generation context required below the UI, with scoped queries, merges, events, writes and undo. Consequence: some direct Hive setters and card-owned actions must be adapted before reuse. This is the necessary implementation interpretation of C09; the exact API/storage shape remains D14/D15/D24.

### ADR-P03: three surfaces, two order domains per player

Context: the current frontend mixes tokens and utilities. Proposal: central life state plus independent token and utility lanes; preserve reuse at domain/rendering primitive level. Consequence: mixed deck order converts by stable partition, and life cannot be reordered with utilities. Exact geometry remains D07; shared utility polymorphism is allowed without reintroducing one universal list.

### ADR-P04: recovery is a first-class session feature

Context: current decks are setups and whole-board snapshots/boot backups do not establish coherent multiplayer restore. Proposal: dedicated durable session state with generations and explicit command recovery. Consequence: choose bounded history/storage and measure rapid input before promising zero acknowledged loss. Storage implementation remains D14/D17.

## How to record an answer

For each resolved decision, add:

```text
Decision: Dxx
Status: accepted / rejected / deferred / superseded
Chosen behavior:
Rationale and tradeoff:
Date and source of approval:
Documents / requirements affected:
Implementation and acceptance gates affected:
Follow-up or revisit trigger:
```

Only the user approves product choices. Technical implementation choices may be resolved within an approved scope, but must not silently redefine that scope. If an answer affects multiple documents, update them in one checkpoint. Preserve rejected/deferred reasoning briefly so it need not be rediscovered.

## Open research backlog

| Evidence needed | Resolves | Suggested experiment |
|---|---|---|
| Real seated reach/readability at both candidate layouts | D05–D07/D30 | Two physical layouts, identical long/short content, four people |
| Rotated local overlays plus any keyboard/native return | D09–D12 | Numeric and text input at every chosen seat orientation; verify one active keyboard and draft-preserving ownership; resolve handoff details; failed save and picker cancel |
| Durability under rapid life and multi-result creation | D14–D17 | Acknowledged-value log, controlled interruption points, recovery inspection |
| Full existing utility scope audit during extraction | D08/D25 | Two identical boards with different rule states; record every read/write/event |
| Legacy/format/media round trips | D18/D20/D23/D29 | Known phone v3 setup, both lane projections, missing upload bytes |
| Oldest candidate device long session | D30/D35 | Normal/heavy/stress runs, memory, frames, latency, heat and battery |

No experiment in this table has been run for IPAD EDITION.

## Old-design inference checkpoint

The [granular baseline map](outstanding_behavior_baselines.md) supplies concrete starting points for remaining behavior questions, including what current design cannot settle. These are explicitly inferred defaults, not additional accepted requirements; D41 and all earlier explicit decisions take precedence.

### D25 accepted follow-up: source ownership versus applicability

Each seat owns its modifiers, while global sources such as Primal Vigor affect the table. Recipient panels cannot remove another seat’s source; disabling the origin removes only that contribution. Linked propagated indication or read-only Other effects are allowed; source-labeled read-only presentation is recommended only. Independent source copies, atomic source/applicability history and reset mapping are documented in the [modifier contract](modifier_ownership_and_applicability.md). Token-control transfer remains separate and unapproved.

### D38 accepted follow-up: midgame Replace and Append

Both are available during play. Replace swaps only the loading seat’s preset-managed token/utility setup; Append adds without clearing existing items. Saved token art and optional deck life artwork apply under the existing preset contract. Neither resets life values, commander damage, player counters, the timeline or unrelated state. Each is one undoable action. See [load semantics and technical baseline](07_utilities_tokens_and_decks.md).

## Tablet-first MVP boundary — D06/D30

MVP supports tablets from iPad mini through full-size iPads and Android variants, retaining the complete active 2–4-seat view. Android/iOS/web targets remain; web support uses tablet-suitable viewports. Exact minimum dimensions, model generations, OS/browser floors, aspect ratios and orientations require validation, not guesses. Small-tablet fit is mandatory; no MVP phone or focused-seat mode. The [closed-focus/unfolded-multiplayer foldable concept](foldable_phone_future_version.md) is deferred to another major version and does not add a standalone one-player game.

### D33 accepted follow-up — 2026-10-22

Save the current game before loading an archive. Restore the archived game state and full timeline without overwriting saved decks or permanent seat customization. Retain the last ten archived game states, oldest evicted when new states are saved; active working state is separate. This is not a ten-action history/undo limit. Protect the selected snapshot through save-current/eviction and preserve the previous active game if the transaction fails. Ordering/deduplication and storage are implementation details. See [archive contract](game_history_and_undo.md).
