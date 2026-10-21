# Decision register

**Last updated:** 2026-10-20. **All D01–D35 are open.** Recommended defaults are proposals, not approvals. Confirmed requirements C01–C10 are in [README](README.md). Flutter is the confirmed starting direction; framework pivot criteria are proposed.

Use stable IDs in later discussions, commits and acceptance notes. Answering one decision does not approve every downstream proposal. In particular, approving the screenshot layout does not choose the storage design, app distribution or release inventory.

## Suggested review order

1. **Product and physical table:** D01–D07, D26–D28. Establish what we are making, for whom, on what screen, and what the life centerpiece must do.
2. **Safety and technical boundaries:** D09–D25, D29. Settle isolation, concurrency, storage, undo, recovery and interoperability before domain implementation.
3. **Release cut and evidence:** D08, D30–D35. Choose utility parity, workloads, offline/update behavior, distribution details and final gates after the prototypes expose costs.

An initial discussion can be just D01, D03, D04, D05, D07 and D26. The dossier supports answering the rest incrementally; there is no need to answer 35 questions at once.

## Product, layout and interaction choices

| ID | Question | Recommended starting point | Alternatives / consequence | Needed by |
|---|---|---|---|---|
| D01 | How is the new project packaged and distributed? | Independently runnable Flutter app sharing selected infrastructure; confirm separate installation intent before assigning IDs | Existing-app edition reduces install friction but adds phone/coexistence risk; separate repository adds package coordination; fork drifts | P0 setup; lock before release config |
| D02 | Is “IPAD EDITION” a codename or public name? | Codename; continue referring to relationship with Tripling Season | Public branding/store identity needs a deliberate decision; do not copy screenshot names | Before public assets/store work |
| D03 | Which large-screen platforms ship first? | iPad primary, prove hardware behavior first | Android tablets and web add input/storage/picker/window validation; Windows is separate scope; no macOS release requirement | P0 device matrix |
| D04 | How many players are required? | Four for initial table prototype | 2/3 players need deliberate space allocation; 5+ makes current quadrant concept insufficient; team modes affect life model | P0 layout and P1 model |
| D05 | How do seats face the table? | Two on each long edge; top two 180°, bottom two 0°, as sketch | Four-edge 90°/270° layouts or user-selectable rotations require additional geometry/input work | P0 |
| D06 | What happens in a narrow/short window? | Constraint-based compact view, then named focused-seat fallback | Strict minimum + resize guidance preserves four-view promise but restricts multitasking/device floor | P0; final floor after P5 |
| D07 | Where do life and lanes sit? | Prototype layout A: life at inner-center, utilities farther outward in inner column, tokens outer lane | Layout B: life band above both lanes in local coordinates; compare reach and visible row count | P0 |
| D08 | Which existing features must reach first-release parity? | Inventory every utility and token workflow; explicitly approve omissions | All parity increases initial scope; a reduced cut needs clear unavailable features and no silent behavioral changes | Before P4 |
| D09 | How much simultaneous interaction is required? | Independent quick controls and local panels; one keyboard owner | One shared search panel is simpler but interrupts players; fully concurrent editors need more focus/overlay work | P0 |
| D10 | What can expand simultaneously? | One token or utility expanded per player | One per lane uses more space; one for whole table conflicts with independent use | P0/P3 |
| D11 | How do keyboard/native flows arbitrate? | Explicit device-level queue/focus handoff retaining origin | Setup-only photo/import could simplify play; silent focus stealing is unacceptable | P0 |
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
| D26 | How complete is the life tracker? | Life presets/direct entry/history grouping; decide commander damage, separate commanders, tax and player counters explicitly | Life-only is smaller; Commander-first expectations may make source-specific damage essential. Choose whether damage entry also changes life | P0/P1 and release cut |
| D27 | What does the mana pool support? | Six-type manual pool, explicit clear/undo, no inferred phase or token actions | Tagged restricted/snow buckets or payment assistant need much richer modeling/UI | Before P4 mana |
| D28 | Which universal tools beyond resets are useful? | Keep center focused; add tools only after layout evidence | Turn indicator, dice, timer, monarch/initiative all add state or affordances; turn highlight must not imply housekeeping | P0/P4 |
| D29 | Does the phone app expose this edition or share active data? | Preserve phone behavior; use explicit interchange until product shape chosen | Shared active data/mode switch adds migrations, libraries and regression obligations | P1/P2; depends D01 |
| D30 | What is the supported hardware/workload floor? | Measure proposed normal/heavy/stress workloads on oldest candidate iPad | A larger device floor simplifies layout but narrows audience; unbounded stacks/history are not a performance contract | P0/P5 |
| D31 | What works offline and when may catalog updates interrupt? | Core play/resume offline; defer noncritical maintenance during play | Online-only artwork/downloads must degrade cleanly; web storage needs separate guarantees | P2/P4/P5 |
| D32 | How is the edition priced and entitled? | Defer commercial decision; keep in-game players separate from purchase identity | Separate purchase, existing entitlement, free edition or upgrade each need store policy/product work | Before store implementation |
| D33 | What happens to completed games? | Keep current session until intentional new game; bounded local history proposal | Session archives, statistics and portable histories require privacy/storage/export scope | P2/P5 |
| D34 | What participant/media information is retained or exported? | Local guest labels; explicit export contents; no analytics/account requirement | Persistent profiles, analytics, custom photos and share bundles need deliberate retention choices | P2/P4 |
| D35 | What proves readiness and governs format upgrades? | Versioned formats, recorded manual/device acceptance, compatibility and recovery gates | Additional platforms/features each add a gate; current docs alone prove none | All phases, final P5 |

## Draft architecture decision records

These preserve rationale while choices remain reviewable. Their status is **proposed**.

### ADR-P01: retain Flutter for the first prototype

Context: current infrastructure is Flutter/Dart; requested changes concern presentation and player scope. Proposal: retain Flutter and prove the highest-risk interactions on hardware. Consequence: avoid spending the first iteration replacing reusable domain logic. Revisit on a reproducible critical framework/platform limitation, not merely because current phone widgets need redesign. References: C02, D03/D05/D11/D30, [research](10_research_sources.md).

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
| Rotated local overlays plus keyboard/native return | D09–D12 | Two concurrent panels; top-facing input; failed save and picker cancel |
| Durability under rapid life and multi-result creation | D14–D17 | Acknowledged-value log, controlled interruption points, recovery inspection |
| Full existing utility scope audit during extraction | D08/D25 | Two identical boards with different rule states; record every read/write/event |
| Legacy/format/media round trips | D18/D20/D23/D29 | Known phone v3 setup, both lane projections, missing upload bytes |
| Oldest candidate device long session | D30/D35 | Normal/heavy/stress runs, memory, frames, latency, heat and battery |

No experiment in this table has been run for IPAD EDITION.
