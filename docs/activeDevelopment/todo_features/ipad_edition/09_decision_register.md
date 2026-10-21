# Decision register

**Last updated:** 2026-10-21. **D01/D03/D04 have accepted product boundaries; D05/D07 have accepted two-player layout and three-player empty-slot decisions**, with implementation details still open; D26 accepts full tracker fundamentals, with detailed policy gates open; D09 accepts one keyboard at a time; D11 handoff details remain open. Other decisions remain open unless explicitly noted below. Recommended defaults are proposals, not approvals. Confirmed requirements C01–C14 are in [README](README.md). Flutter with player-facing custom keyboards is the chosen direction, subject to prototype validation.

Use stable IDs in later discussions, commits and acceptance notes. Answering one decision does not approve every downstream proposal. In particular, approving the screenshot layout does not choose the storage design, app distribution or release inventory.

## Suggested review order

1. **Product and physical table:** D01–D07, D26–D28. Establish what we are making, for whom, on what screen, and what the life centerpiece must do.
2. **Safety and technical boundaries:** D09–D25, D29. Settle isolation, concurrency, storage, undo, recovery and interoperability before domain implementation.
3. **Release cut and evidence:** D08, D30–D35. Choose utility parity, workloads, offline/update behavior, distribution details and final gates after the prototypes expose costs.

With product boundaries, two/three-player layout direction, single-keyboard concurrency and D26 tracker categories settled, the next discussion can focus on remaining four-player geometry, keyboard handoff and tracker policies (coupling/correction, KO, reset retention and inventory extensions). The dossier supports answering the rest incrementally; there is no need to answer 35 questions at once.

## Product, layout and interaction choices

| ID | Question | Recommended starting point | Alternatives / consequence | Needed by |
|---|---|---|---|---|
| D01 | Separate product; exact packaging? | **Accepted:** separate app / new product; same repo acceptable with proper directory isolation | Existing-app mode not selected. Exact directories, packages, IDs and distribution mechanics remain open | P0 setup; lock before release config |
| D02 | Is “IPAD EDITION” a codename or public name? | Codename; continue referring to relationship with Tripling Season | Public branding/store identity needs a deliberate decision; do not copy screenshot names | Before public assets/store work |
| D03 | Which product platforms? | **Accepted:** Android, iOS and web | Device/browser floors, release order and platform-specific gates remain open; Windows/native macOS not added | P0 matrix; P5 release evidence |
| D04 | How many players are required? | **Accepted:** customizable 2–4 initially; **deferred:** expansion to six | Preserve design leeway; exact 2/3/4 layouts remain open. See [six-player expansion](six_player_expansion.md); teams not approved | P0 layout and P1 model |
| D05 | How do seats face the table? | **Two-player accepted:** matched opposite-facing 0°/180° layouts, local token-left/life-upper-right/utilities-below-life | Four-player arrangement remains proposed as original sketch; 90°/270° and selectable orientations remain open. See the [layout mockups](02_layout_and_interaction.md) | P0 |
| D06 | What happens in a narrow/short window? | Constraint-based compact view, then named focused-seat fallback | Strict minimum + resize guidance preserves four-view promise but restricts multitasking/device floor | P0; final floor after P5 |
| D07 | Where do life and lanes sit? | **Two-player accepted:** token lane left, life top right, utilities below life in each player’s local perspective | Four-player A/B geometry remains open; three-player setup accepts any empty one of four slots for expanded game controls; dimensions and detailed occupied-seat geometry remain open | P0 |
| D08 | Which existing features must reach first-release parity? | Inventory every utility and token workflow; explicitly approve omissions | All parity increases initial scope; a reduced cut needs clear unavailable features and no silent behavioral changes | Before P4 |
| D09 | How much simultaneous interaction is required? | **Accepted:** one keyboard at a time; no simultaneous keyboards | Other players’ non-typing quick controls remaining usable is the recommendation. Drafts and player ownership must be preserved; detailed request/handoff policy remains D11 | P0 |
| D10 | What can expand simultaneously? | One token or utility expanded per player | One per lane uses more space; one for whole table conflicts with independent use | P0/P3 |
| D11 | How do keyboard/native flows arbitrate? | **Input direction accepted:** any keyboard faces its initiating player, using a custom Flutter panel; one keyboard at a time accepted, request/handoff and native arbitration open | OS keyboards do not expose arbitrary per-seat rotation. Native fallbacks, drafts, accessibility and IME need validation; see [deferred options](custom_keyboard_options.md) | P0 |
| D12 | What accessibility view is needed? | Player-named semantics, large-text adaptation, accessible reorder; prototype focused single-orientation view | Four rotated traversal groups alone may be sufficient only after hardware review | P0/P3/P5 |
| D13 | Where do new/split/copied results go? | Append new distinct stacks; source-adjacent split/copy; deterministic companions; merges stay put | Always append is simpler but changes familiar source relationships; manual sorting mode adds scope | P1/P3 |

D07 geometry must be validated together with D05 orientation. A fixed local left/right order cannot simultaneously maintain the sketch's physical inner/outer lanes after every rotation without an explicit mirrored composition. D06 is a product promise, not a generic Flutter breakpoint.

## State, recovery and interoperability choices

| ID | Question | Recommended starting point | Alternatives / consequence | Needed by |
|---|---|---|---|---|
| D14 | What is the durable session representation? | Spike versioned aggregate semantics behind repository; compare to qualified records | Aggregate rewrites may be expensive; records need journal/reference consistency; per-player boxes alone do not solve scope | P1/P2 |
| D15 | How are commands, stale previews and rules revisions ordered? | Per-player intent ordering feeding one writer initially; stale scoped previews require refresh/reconfirmation | Independent writers require multi-player coordination; committing frozen rules is viable only with explicit UX | P1/P2 |
| D16 | What undo model is promised? | Grouped life undo; local destructive Undo/Accept with affected-player barrier; table reset barrier | Deep conflict-aware history allows continued same-scope writes but is substantially more work | P1/P2/P3 |
| D17 | What resume/history guarantees are required? | One active durable session; bounded coherent recovery generations; last acknowledged durable state retained | Archive/replay history and multiple open sessions/windows require retention/writer rules | P2 |
| D18 | Is legacy phone-board import needed? | Explicit copy-only import to a chosen player if needed; no automatic Player 1 assignment | No live-board import is simpler; same-app mode switch still needs namespace isolation | P2, depends D01 |
| D19 | Which preferences belong to a player/profile/device? | Gameplay options/rule state per player-session; theme/update/purchases device scope | Shared recents/favorites simpler; profiles offer personalization but add setup and retention work | P1/P2 |
| D20 | What libraries and media are shared? | Shared definitions/decks/download cache; explicit active selections; managed uploaded assets | Profile libraries add isolation; portable media packages add format/retention work | P2/P4 |
| D21 | What happens on elimination, replacement or seat swap? | Seat swap preserves PlayerId; elimination preserves state; replacement gets a new identity | Collapsing freed space and resolving leave-game effects are additional behaviors | P1/P3 |
| D22 | Which reset actions exist and exactly what do they change? | Named local clear/reset and central restart/new-table; preview recipients and fields | “Board wipe” with unspecified recipients is not an acceptable final contract; matrix must be approved | P1/P2/P3 |
| D23 | How do deck/session files interoperate? | Read phone v3 setups; stable-partition lanes; distinct versioned session artifact | Tablet subset export needs omission report; richer setup version needs compatibility/rejection strategy | P2/P4 |
| D24 | Where is the shared-core boundary? | Extract proven domain/catalog/planner interfaces incrementally after interaction spike | Immediate monorepo/package overhaul delays feedback; copy/fork reduces initial setup but accumulates drift | P1; depends D01 |
| D25 | Are effect scopes/control transfers fully modeled? | Local manual calculator semantics first; no implicit opponent effects/transfers | True table effects need controller/applicability/lifetime; owner versus controller and transfers require explicit multi-target model | P1 and release claims |

The persistence and concurrency decisions must agree. A single session writer can serve independent UI; it does not mean a global input lock. Conversely, independent visual quadrants do not make async writes atomic. D16 must name how a pending local undo interacts with the same player's later actions, not only other players' actions.

## Feature depth and release choices

| ID | Question | Recommended starting point | Alternatives / consequence | Needed by |
|---|---|---|---|---|
| D26 | How complete is the life tracker? | **Accepted:** life, relevant player counters (energy/poison/experience explicit), city’s blessing, monarch, shared game-level day/night, commander damage by source including self and distinct partners | Detailed inventory additions, bounds/visibility, damage/life coupling and correction, KO/enforcement, tax and UI remain open; reset retention is D22. [Sourced inventory](03_life_and_game_controls.md) | P0 capacity; P1/P2 scope/state; P4/P5 acceptance |
| D27 | What does the mana pool support? | Six-type manual pool, explicit clear/undo, no inferred phase or token actions | Tagged restricted/snow buckets or payment assistant need much richer modeling/UI | Before P4 mana |
| D28 | Which universal tools beyond resets are useful? | Three-player empty slot provides quicker access to game controls, with dice named by the user; exact inventory/behavior remains open | Monarch/day-night tracking are confirmed by D26; initiative, turn indicator and timer remain candidates; dice rules/options are not settled; no implied automatic housekeeping | P0/P4 |
| D29 | Does the separate app share data with the phone app? | Preserve phone behavior; explicit interchange proposal | Shared active data adds migrations, libraries and regression obligations; an existing-app edition is not the selected product shape | P1/P2; within D01 |
| D30 | What is the supported hardware/workload floor? | Measure proposed normal/heavy/stress workloads on oldest candidate iPad | A larger device floor simplifies layout but narrows audience; unbounded stacks/history are not a performance contract | P0/P5 |
| D31 | What works offline and when may catalog updates interrupt? | Core play/resume offline; defer noncritical maintenance during play | Online-only artwork/downloads must degrade cleanly; web storage needs separate guarantees | P2/P4/P5 |
| D32 | How is the edition priced and entitled? | Defer commercial decision; keep in-game players separate from purchase identity | Separate purchase, existing entitlement, free edition or upgrade each need store policy/product work | Before store implementation |
| D33 | What happens to completed games? | Keep current session until intentional new game; bounded local history proposal | Session archives, statistics and portable histories require privacy/storage/export scope | P2/P5 |
| D34 | What participant/media information is retained or exported? | Local guest labels; explicit export contents; no analytics/account requirement | Persistent profiles, analytics, custom photos and share bundles need deliberate retention choices | P2/P4 |
| D35 | What proves readiness and governs format upgrades? | Versioned formats, recorded manual/device acceptance, compatibility and recovery gates | Additional platforms/features each add a gate; current docs alone prove none | All phases, final P5 |

## Accepted product decisions — 2026-10-21

Source: direct user design discussion; quotations preserve the decision boundary, not an implementation claim.

- **D01 accepted:** “I think we need to build a separate app” and “consider it a new product”; “I'm okay with it living in the same repo if we isolate it properly in its own directories.” Rationale: the evolution warrants its own product. Same-repo isolation is permission, not a mandated packaging scheme. Affects product, architecture and legacy-data gates; identifiers and package extraction remain open.
- **D03 accepted:** “Cross platform, android, ios, web”. These are product targets, not evidence that all platforms build or ship together. Affects the platform matrix and P0/P5 validation; support floors and sequencing remain open.
- **D04 accepted / expansion deferred:** “Initial scope should be customizable 2-4 players with a deferred feature doc to expand to 6. The designs should have room and leeway to make 6 players possible.” Affects layout/model assumptions and validation. See [six-player expansion](six_player_expansion.md); six-player implementation awaits later review.
- **C02/C13 direction accepted; D09/D11 partially unresolved:** following the Flutter custom-panel solution discussion, the user said “document it as ANY keyboard” and requested later exploration of custom keyboard options including mana symbols. Record any keyboard input as player-facing, not merely search/rename. Flutter/custom panel is the chosen direction pending proof. The initial “ANY keyboard” answer did not itself settle concurrency. The subsequent explicit answer **“No simultaneous keyboards.”** now settles **one keyboard at a time** (D09). Preserve drafts and prevent cross-player editing; request/handoff details (D11) remain open, with no automatic takeover, cancel or submit behavior implied. Affects layout/input host and V34; option inventory stays [deferred](custom_keyboard_options.md).

- **D05/D07 two-player layout accepted:** “In two player, we'll have matching layouts mirrored - token lane left, life total top right, utilities under life total.” Apply this in each opposite-facing player’s local perspective. The [two-player image](reference/two-player-concept.png) is concept evidence, not a measured layout.
- **D04/D07 three-player empty-slot controls accepted:** the user clarified “I meant 3 player yes. In 3 player, the 4th seat has controls.” The [three-player image](reference/three-player-concept.png) and original request establish a setup-selectable empty slot from the four-seat base, with expanded game controls such as dice/full reset. The pictured P4 slot is not mandatory. No empty seat is introduced into four-player play. Detailed control/geometry choices and D22 reset semantics remain open; faster access does not waive destructive-action safeguards.

- **D26 tracker depth accepted:** the user requests “life totals, all relevant counters (energy, poison, experience, etc), monarch, game level night and day, cities blessing, and so on” and “commander damage per source including self.” They explicitly ask to use Lifetap’s fundamentals without copying its interface. This settles categories and named examples, not every reference feature/default. The [inventory](03_life_and_game_controls.md) maps radiation, initiative, tax, Treasure and supporting tools to evidence and remaining decisions. Preserve distinct source/partner identities and intentional shared-state ownership. Damage/life correction policy, KO/enforcement, exact reset retention and detailed UI remain open. Affects layout, command isolation, persistence/history/export, architecture/reuse, V05/V41–V44 and future six-player capacity.

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
