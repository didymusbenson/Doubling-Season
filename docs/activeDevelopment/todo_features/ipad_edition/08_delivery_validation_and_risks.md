# Delivery, validation and risks

**Status:** implementation plan and acceptance proposals. **No implementation validation has run.**
**Plan created:** 2026-10-20 (America/Phoenix). **Decision alignment:** 2026-10-21.
**Approval boundary:** C02 confirms Flutter as the starting point. The other confirmed user directions remain as recorded in the [dossier README](README.md). D01/D03/D04 now have accepted product boundaries; other open details remain in the register; this document approves none of them. A phase, workload, scenario, candidate target, or release checklist is not a new scope commitment.

This plan is deliberately dependency ordered: inspect a running cloud prototype, prove the physical interaction, establish player isolation, establish durable recovery, then complete the frontend and feature parity. A successful screenshot or a working token demo cannot substitute for those safety gates.

## Phase plan and exit gates

| Phase | Work and dependencies | Evidence required to leave the phase | Stop / revisit condition |
|---|---|---|---|
| **P0 — cloud-first interaction spike, then physical gate** | Chosen direction: Flutter with player-facing custom keyboards. First inspect and interact with the actual running UI in the cloud before requesting user installation; a compile result or static source review is insufficient. Build the smallest disposable tabletop experiment after resolving enough layout choices to compare them. Use the four-seat reference plus two/three-player arrangements, sample lanes, a local panel, numeric and text input, one drag, and a native picker return where supported. Compare the sketch-first geometry and its first alternative. Use a physical iPad and record available window constraints. | Demonstrate top/bottom rotations with correct taps; concurrent life input in different seats; isolated scroll/drag; bounded panels that leave other seats responsive; player-facing custom input at every selected orientation; one active keyboard at a time with retained player/draft ownership and evidence for the chosen handoff details; no panel/proxy stealing a neighbor's taps; safe cancel on rotation/backgrounding. Record minimum feasible geometry and plain failure cases. V01/V06/V09/V10/V30–V35 may have **prototype-only** evidence; that does not mean production cases pass. | Cannot fit useful token/utility controls at an acceptable target size, cannot keep input aligned through rotation/overlays, or cannot provide usable keyboard input to opposite-facing seats. Revisit geometry, fallback and interaction policy first. Only a demonstrated material blocker justifies reopening Flutter choice C02; discomfort with the old frontend is not such a blocker. |
| **P1 — domain scope foundation** | Depends on a viable P0 interaction approach. Define stable session/player/seat identity, immutable command origin, explicit targets, scoped repository writes, event envelopes, rules snapshots, lane order domains, and validation of ownership at mutation boundaries. Inventory every existing creation and utility path. Resolve the shared-global effect policy before claiming parity. | A trace for each command shows the same session/player through preview, primary/companion creation, rule/event reactions, ordering and persistence. Deliberately wrong-owner, stale-session and ambiguous-scope requests are rejected before mutation. Existing globals have an explicit adaptation or are inaccessible in the edition. Manually demonstrate the implemented foundation subset of V10–V20 using narrow command/repository fixtures; full utility/UI cases remain planned until their production features exist in P4. | Any gameplay API can silently default to a player, any event lacks a routable scope, or a card action still scans unfiltered global state. Visual filtering and provider nesting do not satisfy this gate. |
| **P2 — persistence and recovery foundation** | Depends on P1's identity/scope contract and the chosen storage boundary. Define schema/defaults, session generations/revisions, journal or equivalent recovery, operation acknowledgements, scoped snapshots, undo conflict behavior and legacy-data handling. Preserve existing Hive type IDs/boxes. | Termination/restart experiments demonstrate either complete recovery or a documented unacknowledged-operation rollback. Life, ownership, rules, lane orders and operation status agree after restart. Cross-player undo cannot restore a whole-table snapshot over unrelated work. Demonstrate foundation recovery/undo invariants represented by V21–V29, including manual interruption/failure injection. Deck/import and other absent production paths remain planned; do not mark full cases passed from foundation fixtures. | A success is shown before the promised durability point; recovery duplicates tokens or drops companions; a legacy box is repurposed; a reset permits a late callback to resurrect old state; undo rewinds another player. |
| **P3 — production tabletop frontend** | Depends on P0, P1 and P2. Implement the chosen adaptive shell, independent lanes, life centerpiece, local menus/panels, input queues, expansion, per-scope busy/error states, semantic traversal, and app-level coordination of native UI. Use owner-bound commands throughout. | Production builds reproduce P0 results, preserve state across resize/focus/seat changes, and pass implemented core scenarios V01–V04/V06–V10/V30–V35 on the agreed device/window floor. Commander V05 and artwork/custom/deck parity paths V11–V13 remain planned until approved and implemented in P4. The drag proxy, pointer area, overlay and accessibility hierarchy are checked, not only appearance. | Another player's action collapses an editor, a root sheet blocks ordinary play unexpectedly, lane controls overflow, or one fixed hero/navigation identity is reused across active seats. |
| **P4 — scoped feature parity** | Depends on the production shell and isolation/recovery boundaries. Add only the approved inventory of token operations, rules, utilities, artwork and decks. Mana and commander depth are decision-dependent. Review every reused card/action in both compact and expanded states. | Feature inventory maps each entry to an owner-bound command and manual result. All applicable production cases V01–V29 and approved V37–V39 pass; omitted/deferred features are explicitly listed and inaccessible rather than partly wired. V21–V29 are rerun where the new feature adds mutation paths. | A utility silently changes from its documented semantics, companion routing differs from primary routing, deck load leaks across players, or “Everything”/“global” is used without an explicit target policy. |
| **P5 — acceptance and release** | Depends on approved scope/platform/distribution decisions and completed applicable cases. Exercise representative real games, smallest/largest supported windows, offline resume, sustained load, accessibility and phone regression boundaries. Reconcile documentation, support limits and known issues. | Every applicable V01–V40 has objective evidence and pass status; deferred cases identify the approved omission and cannot be reached. No unresolved isolation, data-loss, stale-callback or undo-clobber defects. Real tabletop session and release/profile performance results are recorded. Platform packaging/store work follows the chosen project/distribution path. | An acceptance scenario remains unrun without an approved scope exclusion; only debug/simulator performance exists; app identifiers/data separation are unresolved; support claims exceed measured devices/windows; phone state or accepted phone behavior regresses. |

Phases may overlap in read-only research or component preparation. Do not bypass a dependency gate by integrating unscoped features into a release branch. Keep the current phone release workflow intact while a separate feature branch/project evolves.

## Decision and dependency map

The [decision register](09_decision_register.md) is authoritative. D01/D03/D04 have accepted product boundaries; remaining decisions/details stay open. Resolve a decision only through explicit review; record the choice, date, rationale, rejected alternatives and affected cases.

| Required before | Decision area | Consequence of leaving it open |
|---|---|---|
| P0 exit | Layouts for accepted 2–4-player scope, seating/orientations, sketch interpretation, minimum viewport/fallback, simultaneous panels, keyboard ownership and accessibility view | No meaningful physical feasibility claim or supported-size claim |
| P1 exit | Command ownership, rule/event scoping, intended shared/global semantics, cross-player operations, lane insertion and merge policy | Cannot prove that identical objects in different quadrants remain independent |
| P2 exit | New-project/data boundary, persistence layout, legacy behavior, durability promise, scoped/global undo, reset lifecycle | Cannot promise recovery or protect the phone app's data |
| P3 exit | Expansion limits, local overlay routing, native UI coordinator, resize policy and input cancellation | Competing gestures/routes may consume the wrong player's work |
| P4 exit | Approved first-release inventory, commander damage depth, mana pool behavior, deck/library scope | Cannot distinguish omitted features from incomplete implementations |
| P5 entry | Device/browser floors for Android/iOS/web, separate-app packaging/release sequence, purchase/entitlement treatment, release criteria | A working prototype remains a prototype, not a releasable edition |

Cross-reference [layout](02_layout_and_interaction.md), [isolation and rules](04_player_isolation_and_rules.md), and [data/migration](06_data_persistence_and_migration.md) before changing these gates.

## Validation method and evidence

Repository policy is **manual functional testing; do not generate automated test code**. Temporary Maestro/external flows may drive repeatable UI checks outside the repository when permitted by the existing policy. Do not commit a permanent automated suite or treat such a flow as evidence without checking rendered state. Use screenshots/hierarchy and direct device input to distinguish automation targeting failures from app defects.

### Cloud inspection before installation

Before asking the user to install a prototype, run it in an available cloud browser/emulator and actually inspect rendered screens and exercise interactions. Record commit, runtime, viewport, screenshots, actions and failures. Cover 2/3/4-player layout, rotated numeric/text entry, local draft/cancel behavior, and unaffected-player quick controls. If cloud inspection is blocked, report the exact blocker and untested cases rather than treating installation as the first inspection step.

Cloud visual/interactive evidence is an early quality gate, **not physical iPad acceptance**. Real simultaneous touch, seated reach, native keyboard/picker/fallback behavior, VoiceOver and release performance still need actual iPad evidence. Android device/browser testing must cover the corresponding Android and web targets. Product targets are accepted; minimum OS/browser/device floors and release order are not yet settled.

Each case below is **planned / not run**. The case ID is stable; add results rather than reusing IDs for a different scenario. Prototype evidence is labeled separately and production status stays not run until exercised on the implementation. The exact mechanics of features with pending decisions are acceptance branches to choose after review, not approved behavior.

Record for each execution: case ID; build/commit; date; device/OS; available logical viewport and orientation; physical seat; text scale; accessibility/input settings; online/offline state; starting session/player IDs; exact action; observed result; screenshot/hierarchy or command/event evidence where useful; unaffected-player check; and pass/fail/block reason. Do not store real personal information in fixtures. Mark **blocked by decision** rather than inventing an outcome when its prerequisite is still open.

A proposed common fixture is four stable players A/B/C/D in distinct seats. Repeat relevant layout/input/isolation cases with two and three players; the four-player fixture does not cover the accepted full participant range. All begin at life 40 unless a case says otherwise. Give each player identically named token stacks and utilities with different quantities and IDs: this catches name-based/global lookup mistakes. Before a scoped case, capture the other three players' life, counters, token/utility IDs, quantities, rules, lane orders and relevant pending operations. “Unchanged” below means those values and persistence remain identical; cosmetic timestamps unrelated to gameplay must not conceal a state mutation.

### Life and commander state — V01–V05

**V01 — independent life taps. Status: planned / not run.**
- **Preconditions:** Four players at 40; no pending command. Observe the actual persisted session, not just displayed labels.
- **Action:** Tap A −1 three times and C +1 twice; then return to both values after opening/closing their menus.
- **Expected:** A is 37 and C is 42 in UI and stored state; exactly those five deltas are attributable to their originating players. Opening panels introduces no delta.
- **Unaffected:** B and D remain 40; all players' tokens, utilities, orders and rules remain unchanged.

**V02 — simultaneous and overlapping life gestures. Status: planned / not run.**
- **Preconditions:** A/B at 40; enable only the chosen tap/repeat gesture policy. Capture emitted deltas during this run.
- **Action:** In the first fixture, two people make exactly 20 deliberate A −1 taps and 20 deliberate B +1 taps concurrently, counting physical taps as well as emitted commands. In a fresh fixture, overlap repeat gestures, including two opposite gestures on A; lift/cancel all pointers, then wait two seconds without touching.
- **Expected:** The counted-tap fixture ends at A=20/B=60, with every physical tap represented once. In the repeat fixture each final total equals 40 plus the signed sum of that player's emitted deltas, with no lost read/modify/write update. No delta occurs after its gesture has ended/canceled. Crossing a seam does not retarget a gesture. A missing command for a counted physical tap is a failure, not an excluded delta.
- **Unaffected:** C/D remain 40; no token/utility/rule/order changes anywhere.

**V03 — direct entry, presets and numeric boundaries. Status: planned / not run.**
- **Preconditions:** Approved input bounds selected within the proposed signed-life contract; A at 40. Negative life is editable, as specified in the life/data design.
- **Action:** Set A to 37; cancel an attempted set to 12; enter the approved minimum/maximum and one invalid/out-of-range entry. Exercise each approved starting-life preset on a new disposable session.
- **Expected:** Successful direct set is exactly 37; canceled draft leaves 37; signed limits round-trip exactly; invalid input never changes durable state and shows the defined local error. Presets initialize every selected participant to the exact configured value. Negative accepted values are never silently clamped to zero.
- **Unaffected:** B/C/D do not change during A's direct-entry attempts. The intentionally new session does not overwrite the prior session or phone board unless that behavior was explicitly chosen.

**V04 — life corrections and status thresholds. Status: planned / not run.**
- **Preconditions:** Chosen life undo/grouping and elimination-display policy recorded; A at 40.
- **Action:** Apply one grouped −5 change to A, undo it, then set A to 0 and to −1; correct it back to 40.
- **Expected:** The group reaches 35; its undo returns exactly 40 once, with no duplicate compensation. Zero and −1 both persist/display exactly. Threshold styling follows the selected policy and never deletes the player/board automatically. Correction restores 40.
- **Unaffected:** B/C/D values, boards, rules and histories remain unchanged; any history records distinguish original and correction rather than attributing A's correction to another seat.

**V05 — directional commander damage. Status: planned / not run; blocked until D26 scope is chosen.**
- **Preconditions:** If included, identify A's two commanders as distinct source IDs A1/A2; B at 40; all damage entries initially 0. Choose life coupling before running.
- **Action:** Record 7 A1→B damage and 3 A2→B damage; inspect reciprocal B→A and A1→C entries; undo only the A2→B entry. Also inspect the chosen 21-damage threshold behavior using a separate disposable fixture.
- **Expected:** Before undo B's incoming entries are A1=7/A2=3; afterward A1=7/A2=0. **Coupled policy:** B life is 30 then 33, with no second life subtraction. **Independent policy:** B life stays 40 throughout. Source commanders never merge by display name. Threshold marks only the approved status; it does not infer/delete unrelated game state. If excluded from release, the feature is absent and the omission is documented; do not mark this behavioral case passed.
- **Unaffected:** A/C/D life and boards, B's other damage sources, reciprocal B→A and A1→C entries stay unchanged.

### Independent lanes and reordering — V06–V09

**V06 — eight independent scroll positions. Status: planned / not run.**
- **Preconditions:** Every token and utility lane exceeds its viewport with uniquely identifiable top/bottom entries.
- **Action:** Scroll A tokens, A utilities and C tokens to different positions; adjust D life; expand one approved A entry.
- **Expected:** Only the manipulated lane scrolls each time; A's two positions and C's position persist through the later actions according to the chosen restoration policy. Central life stays visible. Expansion stays in A's lane without moving another player's content.
- **Unaffected:** Other five lanes retain their positions/order; D's life changes only by the requested amount; all gameplay values beyond that delta stay unchanged.

**V07 — persistent token-lane order. Status: planned / not run.**
- **Preconditions:** A token lane order is T1,T2,T3; A utility order is U1,U2. Other players have the same display names but distinct IDs.
- **Action:** Move A T3 before T1, confirm completion, restart the app and reopen that session.
- **Expected:** A tokens restore as T3,T1,T2 with the same identities/quantities/status; no token duplicates. A utilities remain U1,U2. Persisted order belongs to A's token domain.
- **Unaffected:** B/C/D lane orders, life, rules and contents remain unchanged.

**V08 — mixed utility types share only their utility order. Status: planned / not run.**
- **Preconditions:** A utilities are tracker U1, toggle U2, approved special utility U3; A tokens T1,T2.
- **Action:** Move U3 before U1; add a new utility U4; restart after acknowledged writes.
- **Expected:** A utilities restore in U3,U1,U2,U4 order under proposed append semantics, or the exact alternative recorded in D13; token order stays T1,T2. Values/action identity/artwork survive the move.
- **Unaffected:** B/C/D utility/token domains and rules remain unchanged; life does not acquire an order entry.

**V09 — drag boundary, cancellation and pointer contention. Status: planned / not run.**
- **Preconditions:** A has reorderable token and utility lanes; C can operate life. Include a top-facing seat.
- **Action:** Drag A token toward A utilities, the hub and B's space; release outside its lane. Repeat with pointer cancel, window resize and C touching life during the drag.
- **Expected:** No drop changes owner or lane type. Outside/canceled drag leaves the last acknowledged order intact unless a valid in-lane drop was committed. Proxy/touch area cannot activate another seat. Autoscroll affects only A's source lane; C's requested life delta still succeeds once.
- **Unaffected:** B/D state and every non-source order domain remain unchanged; no ghost card or permanently blocked gesture remains.

### Scoped UI callbacks and routes — V10–V13

**V10 — menu origin survives other-player activity. Status: planned / not run.**
- **Preconditions:** A/B have different rules; A menu opens a token search panel with visible A identity.
- **Action:** Open A search, let B open their menu and adjust life, then create two tokens from A's still-open panel.
- **Expected:** Creation uses A's selected quantity/rules and token lane; its preview and confirmation name A. B activity never becomes the destination. Local panels coexist or follow the exact approved D09 coordination policy without silently discarding A's draft.
- **Unaffected:** C/D remain unchanged; B changes only by the requested life delta and creates no token from A's command.

**V11 — custom token and custom utility destinations. Status: planned / not run.**
- **Preconditions:** A has empty lanes; shared custom-definition/library policy is recorded.
- **Action:** From A menu create a named custom token, a custom tracker and a custom toggle; B uses a menu between each definition and final submission.
- **Expected:** Exactly one of each selected board instance appears only in A's correct lane with saved fields. Selector/library updates follow the chosen definition policy and do not imply creation on other boards. Canceling a custom draft creates no board instance.
- **Unaffected:** B/C/D boards, life/rules/order remain unchanged; only explicitly shared library metadata may change.

**V12 — artwork, counter/status and delayed callback routing. Status: planned / not run.**
- **Preconditions:** A/B have identically named but distinct stacks; include an artwork download/picker delay and a local counter/status panel.
- **Action:** Edit A artwork, counter and tapped state; operate B during each wait; dismiss/cancel one picker; complete another. Revisit A and B after restart.
- **Expected:** Committed edits apply to A's captured item ID only; canceled work changes no selection. Failed download preserves selection metadata. Closing/error handling pops the correct panel once and never B's route. Artwork preference sharing, if chosen, does not mutate B's persisted board selection.
- **Unaffected:** C/D remain unchanged; B changes only through B's explicit operations, with no counter/status/artwork copied from A.

**V13 — deck load/save and stale panel identity. Status: planned / not run.**
- **Preconditions:** A and B have different populated boards. Prepare a deck with tokens plus tracker/toggle templates. Record append/replace and lane-order policy.
- **Action:** A saves their board, appends the fixture deck, then replaces A's board from that deck. Let B act while each panel is open. Swap seats before one final non-destructive selection returns.
- **Expected:** Saved deck contains only the chosen A board scope; append/replace affects only A's two lanes with the exact declared order. Returning after a seat swap still targets A's stable player ID. A stale removed-session panel is rejected rather than redirected to the new seat occupant.
- **Unaffected:** B/C/D boards/life/rules stay unchanged except explicit independent operations; shared deck-library creation is intentional metadata, not table-state mutation.

### Rules, companions and utility parity — V14–V20

**V14 — primary and companion token isolation. Status: planned / not run.**
- **Preconditions:** Enable only A's one-copy companion-creating rule, with a verified preview: quantity 2 requested yields primary 2 plus companion 2. B has identically named stacks.
- **Action:** A creates quantity 2 through search, custom creation where supported, and an existing-stack + action in separate reset fixtures.
- **Expected:** Each route commits exactly the previewed primary=2 and companion=2 to A under the selected merge policy, and dispatches only their intended scoped events. If the chosen rule produces different verified quantities, record those exact numbers before execution. No route omits/duplicates companions.
- **Unaffected:** B/C/D board quantities, utilities, rules, life and orders remain unchanged.

**V15 — per-player rule evaluation and preview stability. Status: planned / not run.**
- **Preconditions:** A has one supported doubling effect; B has none; identical requested quantity 3. Choose rules snapshot/reconfirmation behavior.
- **Action:** Preview creation for A and B; edit A's rules while A's earlier preview is still open; submit the earlier request.
- **Expected:** Initial previews are A primary=6 and B primary=3 with this isolated fixture. A commits its previewed 6 under snapshot policy, or blocks/reconfirms the newly calculated exact preview under live policy; it never silently commits a different amount from the approved preview. B remains unaffected by A's rule edit.
- **Unaffected:** C/D remain unchanged; no A rule is persisted into B's rule namespace.

**V16 — count/search algorithms remain player-local. Status: planned / not run.**
- **Preconditions:** Separate no-rule fixtures: A Scute amount=2 versus B Scute amount=100; A copy source is a non-haste creature amount=5,tapped=2,+1/+1 counters=3 with selected artwork and sickness setting enabled; A split source amount=5,tapped=2,sick=2 with +1/+1 counters=3. C/D have other creatures.
- **Action:** Use A's Scute action; copy A's copy source once; split two from A's split source with untapped-first selected, each in its separate fixture.
- **Expected:** Scute creates exactly 2 additional A Scutes, making A total 4, never using B's 100. Copy creates one fresh A token, amount=1,tapped=0,sick=1,counters=0, preserving base identity/artwork while source amount stays 5. Split produces original amount=3,tapped=2,sick=0 and new amount=2,tapped=0,sick=0; both retain +1/+1 counters=3 as separate counter state. New entries stay adjacent to the source in A's token lane under D13. These numeric expectations preserve current copy/split semantics; any proposed behavior change needs review before replacing the fixture.
- **Unaffected:** B's Scute remains 100; C/D and all other-player lane orders/rules/status remain unchanged.

**V17 — creature ETB, Cathars and counter modifiers. Status: planned / not run.**
- **Preconditions:** No replacement rules in the first fixture; A/B each have one Cathars utility with pending count=0, distinct 1/1 creature stacks and non-creature entries. Second fixture: A has one ordinary 1/1 stack with +1/+1 counters=2 and −1/−1 counters=0; B has no counter modifier. A separate replacement fixture records its exact approved multiplier/result before execution.
- **Action:** Create two A creatures and resolve A's Cathars action. In the second fixture, apply −1/−1 once to A, then +1/+1 once. Exercise the replacement fixture separately. If derived entry reactions are queued, hold consumption in another fixture, transform/delete the entered creature, then resume/replay its reaction.
- **Expected:** A Cathars pending count increases by exactly 2 and its no-rule resolution adds two +1/+1 counters per eligible A token; B's pending count stays 0. Second fixture net counters change 2→1→2 (effective P/T 3/3→2/2→3/3). The replacement fixture matches its declared result without applying A's modifier to B. Queued entry classification uses immutable entry-time characteristics or recorded effects, so later transform/delete cannot erase or reinterpret the earned reaction; an atomic design instead finalizes the reaction before exposing the later mutation. No double event/trigger is emitted through companion or restore paths.
- **Unaffected:** B/C/D Cathars counts, creature counters, rules, life and orders remain unchanged. Non-creature A entries excluded by the retained behavior remain unchanged.

**V18 — Academy Manufactor replacement. Status: planned / not run.**
- **Preconditions:** A has one active Manufactor effect, B has none; no other token modifiers; verify current three-result semantics. Search fixture requests two Treasure; utility fixture has one Manufactor and uses the retained one-unit action.
- **Action:** Submit the two-Treasure search request; in a separate reset fixture activate A's Manufactor utility once.
- **Expected:** Search yields A Treasure=2, Food=2, Clue=2. One retained utility activation yields A Treasure=1, Food=1, Clue=1. Each route has exactly its intended creation/event set; no separate unreplaced extra Treasure stack is added. Matching/merging cannot select B's stacks. A future utility quantity control would need a separately approved fixture.
- **Unaffected:** B/C/D token/utility quantities, rules, life and order remain unchanged.

**V19 — commander-specific utility inventory. Status: planned / not run.**
- **Preconditions:** Inventory every release-approved Krenko variant, Hare, Rhys and Brudiclad action; use fixtures with no rules and distinct non-token counts. Example Krenko Mob Boss fixture: A tracked non-token Goblins=1 plus token Goblins=2; B Goblins=100.
- **Action:** Run each action once from A. For the example Krenko fixture, create Goblins. For Rhys/Brudiclad, inspect every selectable candidate before confirming; include identical names on B.
- **Expected:** Example Krenko creates exactly 3 Goblins for A, producing A token Goblins total 5 under the chosen stack policy. Additional no-rule fixtures: Tin Street tracker power=4 creates exactly 4 Goblins; Hare tracked count=4 creates exactly 3 Rabbits. Rhys fixture with A creature-token amounts 2 and 3, plus A Treasure=5, adds exactly 2 and 3 corresponding creature tokens and leaves Treasure=5; no B candidate appears. Brudiclad fixture adds exactly one 2/1 Myr, then transforms only A's token set to the selected A token identity while preserving the chosen retained per-stack amount/status/counter behavior. Inspect its eligible target list and exact before/after snapshot. Deferred utilities are absent/disabled with an honest explanation rather than partly functioning.
- **Unaffected:** B's 100 Goblins and all B/C/D candidate stacks, triggers, artwork and counters remain unchanged.

**V20 — intentionally shared/global effect semantics. Status: planned / not run; blocked until D25 policy is chosen.**
- **Preconditions:** Record the approved handling of cards whose text describes effects beyond their controller; fixtures A/B each create one token. Do not treat card wording as authorization to automate all players.
- **Action:** Enable the candidate effect through its approved UI and create for A then B; inspect preview, effective targets and emitted events.
- **Expected:** **Local/manual policy:** A's effect changes only A's calculation; B request remains exactly its unmodified one-token result. UI describes the limitation. **Explicit shared-effect policy:** only the selected participants receive the approved single application; attribution/deduplication prevents the same physical effect being counted twice. Write the exact expected quantities/target IDs before running this branch. Unsupported shared effects cannot silently register globally.
- **Unaffected:** Every non-selected participant and every non-target field remains unchanged; ordinary local actions never opt another player into an effect.

### Reset, undo and lifecycle — V21–V25

**V21 — explicitly local board actions. Status: planned / not run.**
- **Preconditions:** Every player has tapped/sick stacks, counters, utilities and rules; A at 37 life. Record each approved action's impact preview.
- **Action:** In separate restored fixtures run A untap-all, clear sickness, counters-all, set-token-amounts-to-zero, delete tokens and approved player reset.
- **Expected:** Each result affects exactly the named A fields. Untap changes tapped values only; sickness clear changes sickness only; zero/delete follow the declared token/utility/rule/life inclusion. A life stays 37 unless that exact reset explicitly includes life. Hidden interpretation of “all” is disallowed.
- **Unaffected:** B/C/D values, IDs, orders, rules and histories remain unchanged.

**V22 — local destructive undo. Status: planned / not run.**
- **Preconditions:** A has a captured board including source IDs, quantities, counters/status/artwork/order and rules where included by the action. B at 40.
- **Action:** Clear A through the approved destructive action; B changes life to 39; choose A Undo. Attempt Back/outside tap on any mandatory completion UI.
- **Expected:** A's intended snapshot returns exactly, including rule state where reset was included; restore emits no new ETB/wipe events. B stays 39. Completion dismissal follows chosen policy; a mandatory Undo/Accept surface cannot be bypassed by system Back. Undo is recorded/applied once.
- **Unaffected:** B's board and C/D entire state remain unchanged; restored A artwork does not trigger metadata-destroying redownload behavior.

**V23 — whole-game reset / new game. Status: planned / not run.**
- **Preconditions:** Non-default life, boards, rules, mana and seats for all participants. Choose exact reset options and keep-seats/reload-deck behavior.
- **Action:** Open central reset, inspect named impact, cancel; then reopen and confirm one chosen preset.
- **Expected:** Cancel changes nothing. Confirm produces exactly the option's declared state across selected participants in one coherent session generation; retained names/seats/deck links remain only as selected. No old life history/utility/rule state survives accidentally. Every affected participant is visible in the impact description.
- **Unaffected:** Non-selected sessions, shared libraries and phone board remain unchanged. There is no claim that all participants are unaffected in a deliberately table-wide action.

**V24 — stale callbacks cannot resurrect a reset game/player. Status: planned / not run.**
- **Preconditions:** Pause A token/artwork/create flow and B delayed split after each captures origin; record session and player generations. Use an operation boundary that can be held deterministically. Prepare separate table-reset and A-local-reset fixtures.
- **Action:** First confirm a whole-game reset/new game, then release both old callbacks. In the second fixture, reset/replace only A, then release A's old work and B's still-valid split. Cancel remaining gestures and background/resume once.
- **Expected:** Table-reset fixture rejects old-session-generation mutations or completes them before the barrier under the chosen protocol; no late token/companion/split/artwork appears. Local-reset fixture advances A's generation and rejects A's old mutation, while B's valid pending split completes with its exact original player/source semantics. Repeat gestures stop when their affected scope is invalidated. A stale panel explains which game/player changed.
- **Unaffected:** No obsolete result appears in a replacement A or new session. C/D and unrelated sessions remain unchanged; A-local reset does not invalidate B's unrelated command.

**V25 — reset/undo failure and recovery. Status: planned / not run.**
- **Preconditions:** Choose documented manual failure points between journal write, multi-entity mutation, durable completion and undo restoration; retain a recoverable fixture copy.
- **Action:** Interrupt/fail each point in separate runs, reopen, then inspect operation status and all affected state.
- **Expected:** Each run reaches the documented complete-before or complete-after state; no acknowledged half-reset remains. Failure UI identifies local/global scope and whether restoration succeeded. Retrying/boot recovery does not duplicate items, events or life deltas. Unrecoverable failure is reported and prevents unsafe continuation.
- **Unaffected:** Any player/session outside the operation's declared target remains unchanged through failure, rollback and retry.

### Persistence and compatibility — V26–V28

**V26 — complete session resume. Status: planned / not run.**
- **Preconditions:** Four players with non-default life, approved directional damage/counters, two ordered lanes each, different rules, utility state and pending-completion metadata; every displayed success is acknowledged durable under the chosen promise.
- **Action:** Terminate normally and forcibly in separate fixtures, relaunch offline and resume. Include seat reorder and an interrupted order normalization.
- **Expected:** Stable player IDs, seat mappings, life/counters, object contents, lane orders, rules and operation records match the last acknowledged durable state. Incomplete unacknowledged work follows the documented recovery rule once; no entry changes owner. Scroll position restoration follows its separate UI policy.
- **Unaffected:** Other saved sessions and legacy phone data are unchanged; only intended recovery writes occur.

**V27 — legacy/upgrade data boundary. Status: planned / not run.**
- **Preconditions:** Copy representative old accepted phone data with token/artwork/deck/tracker/toggle/rule content and missing fields from prior versions. Record type IDs/box names and backup location. Select import/migration and D23 interchange policies. Prepare a phone-v3 setup ordered T1,U1,T2,U2; foreign file:// artwork; a tablet-only utility; malformed and future-version files.
- **Action:** Open the edition in its intended container; interrupt/retry any supported migration. Export the known phone setup, import it into the tablet library, then load it for A. Exercise approved export-back/subset behavior. Attempt foreign-art, malformed and future-version imports in separate fixtures.
- **Expected:** No phone box is renamed/reclassified and no type ID is reassigned. Supported copy migration is idempotent, applies defaults and preserves its source; unsupported live-board import is clearly unavailable. V3 setup import gives tokens T1,T2 and utilities U1,U2 in their respective lanes without claiming to restore a live session. Compatible export round-trips; tablet-only content produces the approved loss report or explicit format rejection. Foreign local paths degrade to reported missing art rather than reading arbitrary unrelated files. Malformed/unsupported future input produces no partial library or board mutation and preserves the original file.
- **Unaffected:** Original phone data and non-target edition sessions remain byte/logically intact according to the chosen migration contract; shared artwork cleanup never removes files still referenced elsewhere.

**V28 — accepted phone behavior and build regression. Status: planned / not run.**
- **Preconditions:** Baseline phone build/data captured; list intentional shared-code changes. Include iOS and Android phone coverage if their code path changes.
- **Action:** On the phone workflow, create primary+companion tokens, use a utility, reorder, expand/save/collapse, copy/split, load/save a deck, change artwork and perform undo; restart. Build the affected supported targets using normal dependency/plugin regeneration.
- **Expected:** Results match the accepted phone baseline except specifically reviewed shared fixes. Phone route selection, app identifiers, storage names/type IDs, orientation and data remain intentional; tablet scene never replaces the phone board by size alone without approved behavior. No development-only plugin leaks into release registration.
- **Unaffected:** Edition sessions and non-target phone data stay unchanged. No macOS native build is a release requirement.

### Concurrent undo — V29

**V29 — stale/conflicting undo preserves later work. Status: planned / not run.**
- **Preconditions:** A performs a destructive local action with undo record RA; B subsequently creates a token and changes life to 38. Create a same-scope conflict by applying a later A mutation only if the chosen UI permits it before RA resolves.
- **Action:** Request RA undo twice concurrently; if same-scope conflict is possible, request RA undo after that newer A mutation in a separate fixture.
- **Expected:** RA applies at most once. B remains at 38 with its newly created token and exact other state. With a newer A mutation, the chosen revision/conflict policy either safely compensates just RA or rejects/invalidates stale undo visibly; it never silently restores an old A snapshot over the newer change. If completion locks A until resolution, the later A command is refused/deferred and cannot slip through.
- **Unaffected:** C/D and all unrelated sessions remain unchanged. No whole-table restore is used to undo one player's action.

### Layout, accessibility and shared input — V30–V35

**V30 — viewport fit and adaptation. Status: planned / not run.**
- **Preconditions:** Approved support floor plus one below-floor window; populate longest names/abilities, large P/T/counts, many counters, seven/eight-action tokens and long utility action labels.
- **Action:** Visit smallest/largest supported windows, resize while a panel is open and compare both landscape directions; test the approved constrained/focused mode if any.
- **Expected:** All four required workspaces and central life meet chosen visibility policy; controls have no overflow/overlap/truncated critical values. Below-floor behavior is explicit and preserves state. No whole-card scaling shrinks touch targets below the chosen floor. Resize retains player IDs/drafts/order.
- **Unaffected:** Layout operations alone mutate no player's gameplay values or ownership.

**V31 — target sizing, reach, contrast and identity. Status: planned / not run.**
- **Preconditions:** Physical table seating, light/dark themes, bright/missing artwork, grayscale and chosen minimum target size (proposal: 48 logical pixels).
- **Action:** Measure primary targets, operate life/menu/reorder controls from each seat, and compare seat identity/errors without color cues; exercise reduced-motion mode.
- **Expected:** Measured targets meet the approved floor; neighboring controls are distinguishable and reachable. Seat name/icon identifies scope independently of color; text remains legible over artwork; reduced-motion behavior preserves state and feedback. Record accidental-touch/reach counts rather than assuming comfort from screen size.
- **Unaffected:** Neighboring seats receive no accidental mutations during intended scoped touches; visual preference changes do not alter game values.

**V32 — assistive technology and external input. Status: planned / not run.**
- **Preconditions:** VoiceOver/TalkBack as applicable, external keyboard/switch navigation and an approved single-orientation accessibility view if included.
- **Action:** Navigate player→life→menu→lanes, adjust A life, create/reorder A token through accessible alternatives, close panel, then move to C.
- **Expected:** Announcements include correct player/item/action/value; traversal is deterministic; changed A life does not cause full-table announcement floods. Long-press/drag actions have usable alternatives. Focus returns to the originating local control; escape/back closes only the intended surface.
- **Unaffected:** B/C/D gameplay state stays unchanged except a deliberate later C action; focus navigation cannot imply player reassignment.

**V33 — large text and inline editor safety. Status: planned / not run.**
- **Preconditions:** System default and largest supported text scales; long utility/token fields; an editable A card and expanded B card; ability to fail A save.
- **Action:** Enter a draft on A, trigger failed save/collapse, operate B tap-only controls, then retry successfully; repeat at constrained viewport.
- **Expected:** Failed save keeps A draft/editor visible and vetoes collapse; retry persists exact text once. Large text reflows or uses the approved alternative instead of hiding values/actions. B activity does not commit/collapse A. Expansion count follows chosen per-player policy.
- **Unaffected:** C/D and unrelated B fields remain unchanged; A draft never appears in another player's editor.

**V34 — any player-facing keyboard, focus and native UI. Status: planned / not run; handoff-specific cases blocked until D11 is chosen.**
- **Preconditions:** Cloud visual/interactive inspection first; physical iPad for device acceptance and separate Android/web coverage. Include every selected seat orientation and 2/3/4-player arrangements; text and numeric entry fields; a native picker/cropper where supported. One keyboard at a time is required. Record the chosen request/handoff behavior; mark that portion blocked while D11 remains open.
- **Action:** Enter search, custom-name/text and direct numeric drafts (life, quantities/counters and mana where included). A opens input, B requests input, then exercise close/cancel/submit and any handoff only according to the selected D11 policy. Do not invent automatic takeover or cancellation for the B request. Repeat from each orientation and with resize/backgrounding; trigger, cancel and complete native UI.
- **Expected:** Every keyboard, entry surface and related result/error faces the initiating player; input and draft ownership never switch accidentally. At most one keyboard is active at any moment. A second request never creates simultaneous keyboards or redirects A’s draft/edits into B’s state. Preserve drafts through the approved handoff; do not assume automatic takeover, cancellation or submission. No silent draft loss. Panels/insets preserve the chosen life-access policy without making all lanes unusable. Native UI returns to captured player/item without double-pop; any system/hardware fallback or IME limitation is recorded and explicitly resolved, not called a pass merely because text entry works upright.
- **Unaffected:** C/D gameplay state remains unchanged; B quick actions work only as allowed by the clearly defined local/app-modal boundary.

**V35 — rotation, hit tests and seat reassignment. Status: planned / not run.**
- **Preconditions:** Top/bottom rotations active, optionally side seats only if approved; A has open panel and pending gesture. Seat swap is enabled only if included.
- **Action:** Tap rendered +/- and menu edges in each orientation; drag/swipe locally; rotate/resize/background while a gesture is held; swap A and C seats, then finish an allowed A callback.
- **Expected:** Hit tests match rendered controls/proxies; local direction semantics are consistent. Canceled gesture stops with no delayed repeat. Device rotation changes layout only. Seat swap moves presentation while A retains all state and any valid captured callback still targets A; invalidated callbacks reject visibly.
- **Unaffected:** No other player gains A's contents, life, rules or event subscriptions; layout changes alone alter no gameplay values.

### Offline play — V36

**V36 — airplane-mode core gameplay and resume. Status: planned / not run.**
- **Preconditions:** Airplane mode before launch; bundled database available; some art cached and some intentionally missing. Use chosen offline first-release scope.
- **Action:** Start/resume a table; change life; create bundled/custom tokens; run approved utilities/rules; save/load local decks; restart. Attempt unavailable remote artwork/update action.
- **Expected:** Core scoped play and durable resume succeed without network. Missing art uses a usable placeholder and preserves selected metadata. Remote failure is local/retryable and cannot hold the table or clear content. No startup dependency waits indefinitely for network.
- **Unaffected:** Remote failures affect no other player's state; local operations mutate only their intended target scopes.

### Mana pool — V37–V39

**V37 — independent mana colors and quantities. Status: planned / not run; blocked until D27 behavior is chosen.**
- **Preconditions:** Approved mana utility included; A/B pools empty; separate W/U/B/R/G/C fields and any approved special categories defined. Do not represent generic cost as a seventh color unless explicitly chosen.
- **Action:** Add A W=2, U=1, C=3; add B R=4; decrement A W once; try invalid/negative entry under the chosen policy.
- **Expected:** A ends W=1,U=1,C=3 with other categories zero; B ends R=4 with other categories zero. Validation follows chosen range policy without wrapping/underflow or shifting amounts between colors. Persistence stores pool by stable player ID.
- **Unaffected:** C/D pools and all players' life/tokens/rules remain unchanged; token quantities are not interpreted as mana.

**V38 — mana clear, lifecycle and undo. Status: planned / not run; blocked until mana cleanup/retention policy is chosen.**
- **Preconditions:** A has W=2,C=3; B R=4. Choose manual clear, automatic boundary, retention exceptions and whether clear is undoable.
- **Action:** Clear A explicitly; undo if included; invoke the one approved turn/step/game boundary in a separate fixture; restart after acknowledgement.
- **Expected:** Explicit clear sets only A's selected pool fields to 0. If supported, undo restores exactly W=2,C=3 once. At a lifecycle boundary, only pools/categories declared by the chosen policy reset; retained exceptions survive and are visible. Manual-only policy performs no hidden turn-based clear. Resume matches acknowledged state.
- **Unaffected:** B/C/D pools remain unchanged during A-only clear/undo; an intentional global boundary affects only its declared pools and never life/boards implicitly.

**V39 — mana gestures, spending and restrictions. Status: planned / not run; blocked until advanced mana scope is chosen.**
- **Preconditions:** A W=2,U=1,C=3; B R=4. Spending/restricted mana support either explicitly included or excluded; simultaneous repeat policy selected.
- **Action:** Use simultaneous A/B mana controls, cancel a held gesture, then execute one supported A spending command with a recorded exact allocation. Attempt an unsupported automatic-payment/restricted category action.
- **Expected:** Totals equal the signed accepted deltas with no post-cancel changes. If spending is included, subtract only the confirmed per-category allocation atomically, reject insufficient/invalid allocation without partial mutation, and preserve any approved restriction metadata. If excluded, no hidden payment or rules-engine automation exists and the UI does not imply it does.
- **Unaffected:** C/D unchanged; B changes only by its own accepted gestures. No mana operation creates/sacrifices tokens, pays life or affects another pool without a separately approved explicit command.

### Load and sustained operation — V40

**V40 — measured workload, battery and thermal behavior. Status: planned / not run.**
- **Preconditions:** Chosen device/OS floor, release/profile builds, fixed brightness/network/charging conditions recorded; workload tiers below seeded with known identities/rules/artwork.
- **Action:** Run each workload, scroll/expand/reorder, create primary+companions, change life concurrently, reset/undo and background/resume; continue representative play for the agreed sustained duration. Measure frames, command latency/durability, memory trend, recovery, battery and thermal indicators.
- **Expected:** Meets only the approved measured budgets, with zero cross-player mutations, missing/duplicated accepted operations or data loss. UI remains responsive under the agreed supported tier; any stress-tier degradation is recorded honestly and does not corrupt state. Battery/thermal limits are conclusions from measured controlled runs, not guarantees from Flutter or this plan.
- **Unaffected:** Non-target players change only through their scripted actions; no load-triggered cache cleanup, event duplication or global rebuild changes gameplay values. Unrelated saved/phone data remains intact.

## Provisional workload and measurement budgets

These are experiment inputs and candidate acceptance budgets, **not validated capabilities, release promises, or approved device limits**. Resolve the support floor and workload in the decision register, then revise based on P0/P5 measurements.

| Tier | Fixture proposal | Purpose |
|---|---|---|
| Interaction spike | 4 players, 6 token stacks + 4 utilities per player, placeholder/cached art | Prove physical geometry, simultaneous input and routing without conflating token quantity with rendered count |
| Representative session | 4 players, 20 stacks + 8 utilities each, mixed full/fade/no art, 10 counters on several stacks, distinct rules | Main sustained usability, memory and battery baseline |
| Busy supported candidate | 4 players, 50 stacks + 15 utilities each, long text/large counts, many artwork variants, several companion results | Find meaningful operating limits and slow whole-state listeners |
| Stress / exploratory | 4 players, 100 stacks + 25 utilities each; repeated create/copy/split/undo; intermittent network and image failures | Identify graceful failure and leaks; passing is not automatically a support commitment |

Token **amount** and token **stack count** are different loads. A stack of 999,999 should not render 999,999 widgets. Also vary custom-rule count, rule result fan-out, image decode count, snapshot size, and session history length independently; a low visible row count can still trigger an expensive global scan or snapshot.

Candidate measurement targets for discussion:

- At the selected 60 Hz reference mode, inspect both UI/raster frame timing against the approximately 16.7 ms frame interval. Report percentile timings and visibly missed frames, not average FPS alone; do not assume every supported display has the same refresh rate.
- Aim for a visible life-tap acknowledgement within 100 ms at the representative tier and a local token-create response within 500 ms excluding explicit artwork/network work. These are proposed targets requiring measurement; UI acknowledgement and durable completion must be measured separately.
- A routine A-only update should not reconstruct all eight full lane trees or decode unrelated artwork. Use profiling evidence to identify rebuild/decode work; do not convert this into an absolute claim that zero other widgets rebuild.
- After a 10-minute warm-up, sample at least 30 minutes of representative play plus 100 create/delete or expand/collapse cycles. Memory should stabilize rather than grow monotonically with abandoned panels, listeners, image futures or undo snapshots; record start/peak/end memory and retained-object evidence before choosing a numeric ceiling.
- Measure cold/warm startup and offline recovery for all four players, not just first frame. Record time until controls are usable and until recovery is durably complete; choose startup budgets after the storage design exists.
- For battery, record device age/capacity context where available, starting/ending percentage, duration, brightness, radios, refresh mode and charging status. Compare with a life-only scene and the phone reference where useful. Do not infer meaningful battery percentage from a short plugged-in simulator run.
- For thermal behavior, record available OS thermal state, frame degradation, brightness throttling and time-to-onset during an unplugged sustained run. Do not require unsupported temperature probes or promise a universal temperature/battery drain number.
- Consider an optional reduced-motion/artwork mode if measured sustained use benefits. Whether that mode is default, automatic or user-chosen is a product decision; do not silently change a player's saved artwork preference under load.

All workloads remain **not run**. Hardware results must include a physical iPad; simulator/debug data can diagnose problems but cannot establish battery, multitouch or production performance acceptance.

## Risk register

| Risk | Impact / early signal | Mitigation and required evidence | Gate / linked cases |
|---|---|---|---|
| Implicit global player/provider/state | Tokens, rules, ETBs or utilities affect another quadrant despite correct visual filtering | Explicit scope at command/repository/event boundaries; full entry-point inventory; identical-name adversarial fixtures | P1; V10–V20 |
| Stale async callback / gesture | Old search, picker, split or repeat mutates a new session or changed seat | Immutable origin, generation/revision checks, cancel lifecycle and idempotent commands | P1/P2; V12/V13/V24/V35 |
| Whole-table undo snapshot for a local action | Rewinds another player's later work | Scoped snapshots or safe compensation/conflict checks; reject stale restore; explicit global barrier | P2; V22/V25/V29 |
| Unproven journal/multi-box transaction semantics | Half-created companions, half-reset state, duplicate recovery | Document acknowledgement and recovery protocol; controlled interruption at each boundary; replay once | P2; V14/V25/V26 |
| Narrow lane with dense existing action rows | Overflow, illegible state, accidental touches | Purpose-built compact frontend, measured minimum sizes, approved fallback; no blanket scale-down | P0/P3; V30/V31/V33 |
| Rotated overlay/drag semantics | Visible control and hit region diverge or escape into neighbor | Physical input spike, bounded overlay host, local coordinate audit and semantics inspection | P0/P3; V09/V32/V35 |
| Root dialogs/fixed hero IDs/navigation pops | Another panel closes or whole table blocks unexpectedly | Unique identities, typed local close/result contracts, audited native/root UI coordinator | P0/P3; V10/V12/V34 |
| Shared keyboard/system-native UI | Focus theft, lost drafts, poor top-seat input, competing picker routes | Explicit device-global focus/native coordination, usable alternate input surface; actual iPad test | P0/P3; V33/V34 |
| Magic global-effect ambiguity | Incorrect rules claims or accidental table-wide automation | Resolve local approximation vs explicit shared effect policy and label limitations | P1/P4; V20 |
| Commander damage/mana complexity expands scope | First release cannot meet newly implied game-engine promises | Select exact depth and exclusions before release inventory; no auto-pay/turn inference by implication | P4; V05/V37–V39 |
| Legacy/phone storage collision | Corruption or reclassification of existing user data | Decide project/container boundary; additive safe schema/defaults; preserve type IDs/boxes; explicit import only | P2/P5; V27/V28 |
| Shared artwork preference/file cleanup | One player's removal deletes another reference or loses credits | Separate preference from board selection; reference-safe cleanup; retain metadata on download failure | P4; V12/V27/V36 |
| Global listeners/rebuilds/snapshots multiply cost | Jank, battery drain, memory growth after several players act | Scope subscriptions; profile both interaction and persistence paths; cache reuse; bound history/snapshot policy | P3/P5; V40 |
| Small-window/OS changes contradict orientation assumptions | Four-player layout fails in resized windows despite intended orientation | Constraint-driven adaptation and supported-floor policy; build/OS checks and resize prototype | P0/P5; V30/V34/V35 |
| Mistaking automation miss for app defect | False regression reports or false pass | Render/hierarchy confirmation and direct-input fallback under repository policy | Every UI case |
| Planning document mistaken for implementation | Future session assumes safety or features are already present | Keep proposed/not-run labels, update decision/result ledger, re-audit source baseline | Every phase |

## Regression and release policy

- Run the cases touched by a meaningful change plus the isolation/recovery cases its command path could affect. A shared creation-service change requires primary/companion, rule, event and restore coverage; a lane-only style change needs the relevant layout/accessibility/parity checks, not an invented automated suite.
- Review token, tracker, toggle and future board presentations whenever a shared card behavior changes, including compact/expanded states, artwork, editing, hit regions, spacing and save errors. The new shell changes composition; it does not remove behavioral parity obligations.
- For shared-code changes, compare phone outcomes with accepted baseline and document intentional differences. New-project work must not silently change the existing release candidate, bundle identifiers, Hive boxes/type IDs, phone orientation or deployment workflow.
- Re-run failure/recovery cases when transaction boundaries, schema, event routing, reset or undo changes. A prior pass is not evidence for a changed write protocol. Re-run physical input cases when rotation, overlay, keyboard or gesture handling changes.
- Treat unintended cross-player mutation, acknowledged data loss/duplication, unsafe stale callback, incorrect scoped undo and legacy data damage as release blockers. Disable an optional unsafe feature explicitly if its omission is approved; do not downgrade the severity because it is hard to reproduce.
- Honor accepted Android/iOS/web targets and customizable 2–4-player scope. Device/browser/window floors, release sequence, accessibility fallback, networking and multi-window sessions still need chosen boundaries and evidence. Expansion to six is deferred. No native macOS or Windows release requirement is introduced.
- Capture real tabletop feedback after technical acceptance: reach, legibility, incorrect-seat taps, life correction frequency, search interruption, error recovery, and time spent on the device. Report observation counts and context; no usability claim is established yet.
- Keep results, known failures and remaining decisions together. Update [09_decision_register.md](09_decision_register.md) and linked design files when review changes a contract. Move the directory through the repository docs workflow only when work actually starts and later passes agreed acceptance.
- Preserve meaningful checkpoints on the authorized repository branch under the user's standing commit/push instructions. A pushed checkpoint does not imply merge, release or acceptance. This planning document itself introduces no deployment authorization.
