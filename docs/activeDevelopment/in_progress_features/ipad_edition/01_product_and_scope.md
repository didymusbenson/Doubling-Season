# Product and scope

**Status:** confirmed direction plus proposed release boundaries. See [decision status](09_decision_register.md).

**Accepted preset direction:** save/load reusable token lists and utility preferences through an evolution of Decks. Loading targets one seat with empty-state selected token entries and configured utilities. Optional deck image can update that seat’s saved life art; player name and other seats’ art remain independent. D38 accepts midgame replace and append for that seat’s preset-managed fields, each as one undoable action; neither resets life, commander damage, player counters or the timeline. Commander selection remains unapproved.

## Product intent

Place an iPad in the middle of a Magic game and let each player operate their own small Tripling Season board while everyone can see the central life tracker. Players should spend little time navigating and should recognize immediately whose state a control changes.

This is a **separate app / new product** with a different frontend composition (D01 accepted). The same repository is acceptable with proper directory isolation; exact packaging and shared-core extraction remain open. “iPad” remains the working name and design reference, while **Android, iOS and web** are accepted product targets (D03). Initial scope is **customizable 2–4 players**, with [expansion to six deferred](six_player_expansion.md) (D04). Two players use opposite-facing matched layouts (local token-left, life-upper-right, utilities below life). Three players use a four-seat base with any setup-selectable empty slot for expanded game controls. See the [accepted mockups](02_layout_and_interaction.md); exact dimensions and four-player composition remain open.

## Experience principles

| Principle | Observable consequence |
|---|---|
| The table is the primary screen | Normal token/life interactions retain the other players' context |
| Affected scope is visible | Name/seat identity accompanies menus, confirmations, creation and errors |
| Captured data scope is enforced | A stale callback cannot redirect output to whoever used the tablet most recently |
| Life stays easy to read | Lists scroll without scrolling the central life display away |
| Lists serve their content | Utilities and tokens reorder independently; life never participates in either order |
| Shared device, independent work | P1 changing life does not collapse P3's editor or consume P2's drag |
| Recovery is part of gameplay | Accidental local clears can be undone without rewinding someone else's later edits |
| Familiar domain, new shell | Preserve token arithmetic, artwork, counters and utility behavior where applicable |
| Manual control remains available | The app assists players without claiming full knowledge of the physical game |

## Primary journeys

1. **Start a table:** choose the supported active seat count (unused persistent seats are hidden, not deleted) and life preset, name/color each participant, set seating/orientation (including the empty control slot for three-player play), optionally load each player's token/utility deck, then start.
2. **Create while another player acts:** P1 opens token search; the whole table waits while the modal is open. Creation and companions retain P1 scope. Tapaway dismisses without changing P3 life or queuing its control; P3 may act with a fresh gesture afterward.
3. **Resolve a utility:** P2 runs Krenko using P2's token state, tracked non-token count and P2's rules. P4's identically named tokens and utilities remain unaffected.
4. **Rearrange a busy board:** P4 moves a token within P4's token lane and a utility within P4's utility lane. Other lanes keep their order and scroll position.
5. **Correct a mistake:** P1 reverses a grouped life/counter change, commander-ledger correction or local clear under the selected policy. P2’s subsequent changes survive. Shared monarch/day-night corrections retain their explicit table scope and cannot undo later unrelated transfers.
6. **Run it back:** choose Reset with board (zero token counts/no counters, preserve enabled utilities) or Complete reset (clear tokens/utilities), using the specified count/configuration. Both restore starting life and reset temporary/game statuses while preserving seat name/color/art. Removed seats lose game-specific tokens/utilities, and pre-reset full-state/timeline archives are restorable; save-current-before-restore and ten-snapshot retention are accepted under D33.
7. **Resume after interruption:** the app restores participants, life, boards, rules and orders after termination, and explains any incomplete operation that could not be recovered.

## Candidate first release

The product/platform/player-count boundaries below are accepted; the remaining capability cut is proposed, not an approved commitment. “Foundation” means prove the design before release scoping; it is not itself a smaller product release.

| Capability | Foundation prototype | Proposed first usable edition | Later / separate decision |
|---|---|---|---|
| Table | Four-seat reference plus 2/3-seat layout checks | Customizable 2–4 players (accepted); session resume proposal | [Expansion to six](six_player_expansion.md) deferred; teams unapproved |
| Life tracker | Life plus representative typed counter/status, shared state and self/partner damage fixtures | **Confirmed:** life, relevant player counters, city’s blessing, monarch, shared day/night, source damage including self; detailed policies open | Rich statistics; optional modes; reference-derived inventory additions require review |
| Tokens | One creation route and reorder | Search/custom/create, counts, tap, sickness, counters, copy/split, artwork | Explicit cross-player gifting/control transfer |
| Utilities | One manual tracker and Krenko | Existing utility parity where scoped safely; default-visible dismissible mana pool and storm counter; curated visibility/order | Additional unapproved automation / token-control transfers |
| Rules | Per-seat sample presets | Existing supported rule behavior isolated per player | New full-table rules and arbitrary opponent triggers |
| Decks | None required for touch spike | Load/save per player; compatible library reuse | Share an entire table setup / session export |
| Game controls | Safe sample reset | Clearly scoped reset/new game and recovery | Turn/phase engine, tournament tools |
| Platforms | Cloud visual/interactive inspection first, then physical iPad gate | Android, iOS and web targets accepted; device/browser floors and release sequence open | Windows/native macOS not added to product scope |
| Connectivity | Airplane-mode play | Local persistence and cached/bundled content | Sync, multiplayer networking, accounts |

Existing utilities must be inventoried individually before claiming parity. A release may explicitly omit a utility that lacks safe player scoping, but must communicate that omission rather than silently changing its behavior. D08 settles the release inventory; D27 settles the mana pool cut. D26 now accepts full tracker fundamentals and commander damage per source including self; coupled new damage/life with independent corrections, warning-only thresholds and manual shared-state claims are accepted. Detailed correction UI, counter extensions and remaining runtime/rule mappings and archive presentation/transaction details remain unresolved. The [sourced inventory](03_life_and_game_controls.md) separates confirmed capabilities from reference-derived candidates without copying Lifetap’s UI.

## Requirements and traceability

| ID | Requirement | Status | Primary design / validation |
|---|---|---|---|
| R01 | Central life display with each player's own total | Confirmed | [Life](03_life_and_game_controls.md), V01–V05 |
| R02 | A token lane and a utility lane for each player | Confirmed | [Layout](02_layout_and_interaction.md), V06–V09 |
| R03 | Player menu targets its originating player | Confirmed | [Isolation](04_player_isolation_and_rules.md), V10–V13 |
| R04 | Independent persistent ordering in both lanes | Confirmed | [Data](06_data_persistence_and_migration.md), V06–V09 |
| R05 | Generated/replacement tokens cannot accidentally cross spaces | Confirmed | [Isolation](04_player_isolation_and_rules.md), V14–V20 |
| R06 | Center owns intentional game-wide controls | Confirmed | [Life/reset](03_life_and_game_controls.md), V21–V25 |
| R07 | Reuse Flutter infrastructure and domain behavior | Confirmed direction | [Architecture](05_architecture_and_reuse.md), P0–P4 |
| R08 | Life and lists remain usable at a table | Proposed measurable gate | [Layout](02_layout_and_interaction.md), V30–V35 |
| R09 | Local undo preserves other players' later work | Proposed required safety contract | [Data](06_data_persistence_and_migration.md), V22/V29 |
| R10 | No phone data loss or accidental legacy reclassification | Proposed required compatibility contract | [Data](06_data_persistence_and_migration.md), V26–V28 |
| R11 | Core play and resume work without network | Proposed | V26/V36 |
| R12 | Mana pool and storm utilities | Accepted default-visible, dismissible/restorable; mechanics open | [Utilities](07_utilities_tokens_and_decks.md), V37–V39 |
| R13 | Any keyboard input faces the initiating player | Confirmed; custom Flutter panel direction, one keyboard at a time | [Layout](02_layout_and_interaction.md), V34 |
| R14 | Separate product; customizable 2–4 players; Android/iOS/web | Confirmed boundaries; detailed support gates open | D01/D03/D04, V30/V34/V35 |
| R15 | Full life-tracker counters/statuses/shared state and source damage including self/partners | Confirmed categories and bookkeeping policies; detailed UI/inventory extensions open | [Life inventory](03_life_and_game_controls.md), V05/V41–V44 |
| R16 | Persistent chronological game history and latest-global-action undo | Confirmed, including game-wide interruption; archive safety/ten-snapshot retention accepted; recovery implementation open | [History](game_history_and_undo.md), V45–V47 |
| R17 | Two full-reset modes and persistent seat customization | Confirmed; reusable setup retention, removed-seat clearing and archive restore accepted; detailed runtime/restore policies open | [Reset contract](03_life_and_game_controls.md), V23/V48–V49 |

## Boundaries

The proposed initial edition tracks public game state on one device. It does not infer a person's identity from touch, enforce hidden information, authenticate seats, or implement the entire Magic stack. “My menu” means a control is bound to a player, not that another person is prevented from reaching it.

Do not implicitly add networking, cloud synchronization, deck-list import services, an opponent rules engine, automatic combat resolution, automatic mana payment, or a native-framework rewrite to deliver this concept. Revisit any of these through a separately scoped decision. Dungeon support remains outside this project's roadmap, consistent with the existing queue.

## Product questions that affect the architecture

- D41 settles second-editor interaction: all background input is blocked while any modal is open, no request queue/toast/takeover. Finish/dismiss then open a new editor; keyboard/IME/native accessibility still needs validation.
- D06/D30 require complete 2/3/4-seat tablet layouts from iPad mini through full-size iPads and Android tablets. Measure dimensions/aspect ratios/orientations; no MVP focused-seat or phone fallback. Web remains supported at tablet-suitable sizes.
- Should the existing phone app share live games, only deck files, or no user data with this edition? D18/D23.
- New commander damage subtracts life as one undoable action; independent corrections are required and thresholds warn without auto-KO. Resolve detailed controls and reset retention, not whether to include this policy. D26/D22.
- Any player’s different action ends the active history group. One chronological game timeline, latest-action global undo and current-session persistence are accepted; exact timeout tuning remains open; D33 archive safety and ten-snapshot retention are accepted. D16/D17/D33.
- D25 accepts seat-owned local/global modifiers, with global sources affecting the table. Exact applicability/stacking fixtures and reset execution validation need validation/design; token-control transfers are not implied.
- Wipes are central app/game controls, not owned by an invoking seat. Which seats/boards a wipe affects and how targets are selected remain open under D22/D36; do not assume all players or the last active player.

## Success criteria

Proposed acceptance means groups of two, three and four can complete a representative game without losing track of whose controls they are using, without accidental cross-player mutations, and without abandoning the tablet when token or utility lists grow. The release must survive interruptions, recover its last acknowledged durable state, preserve local ordering, and expose errors where the affected player can see them.

Measure this in a real tabletop session. Record reach/legibility problems, accidental touches, time to create and adjust a token, menu interruptions, and recovery results. No usability or performance result is claimed by this documentation.

## Existing-design carryover

Use the [source-backed behavior audit](existing_behavior_audit.md) for search/form cancellation, inline commit, live existing-deck rename, artwork serving and token/utility presentation. Existing snackbars, nondismissible dialogs and unsafe global/cache coupling are expressly not carryover requirements. D41 blocks all background input for any modal; closing consumes its gesture and cannot queue another editor.

## Old-design inference checkpoint

The [granular baseline map](outstanding_behavior_baselines.md) supplies concrete starting points for remaining behavior questions, including what current design cannot settle. These are explicitly inferred defaults, not additional accepted requirements; D41 and all earlier explicit decisions take precedence.

## Tablet-first MVP boundary — D06/D30

MVP supports tablets from iPad mini through full-size iPads and Android variants, retaining the complete active 2–4-seat view. Android/iOS/web targets remain; web support uses tablet-suitable viewports. Exact minimum dimensions, model generations, OS/browser floors, aspect ratios and orientations require validation, not guesses. Small-tablet fit is mandatory; no MVP phone or focused-seat mode. The [closed-focus/unfolded-multiplayer foldable concept](foldable_phone_future_version.md) is deferred to another major version and does not add a standalone one-player game.

## Accepted archive safety and retention — D33

Save the current game before archive restore; keep the latest ten archived game-state snapshots, oldest evicted on new saves. Active working state is separate and each retained snapshot keeps its full timeline/undo information. Restore game-specific state without overwriting saved decks or permanent seat customization. Protect the selected archive from eviction during restoration and preserve the old active state on failure. See [transaction contract](game_history_and_undo.md).

## Explicit carryover clarification — 2026-10-22

Accepted: token-level creature/all-token wipes are distinct from game resets; both resets clear modifier activation per TS. Existing TS decklist import and the same token database/update feed are in scope. Dice support d4/d6/d8/d10/d12/d20 with chosen counts, individual results and total. Free/no ads, optional FV/TS-style non-consumable supporter cosmetics; working names remain candidates. See [source-backed decisions and limitations](implementation_carryover_clarifications.md).

## Full token parity correction — 2026-10-22

The entire original TS token functionality, deliberate density and direct controls must carry over. Reuse the existing token implementation where practical and adapt lane constraints/seat-session integration; a new board container is not a mandate to rebuild or simplify tokens. Any parity-reducing exception requires explicit justification and approval. Review [the source-backed token inventory and acceptance method](token_functional_parity.md), not just row aesthetics or generated mockup styling. No specific runtime mismatch is claimed without implementation evidence.

**Accepted compact-control direction (2026-10-22):** familiar controls are compact and icon-led, not large labeled toolbar rows; TS FAB patterns are precedent, not mandatory. Seat name appears in its life counter without redundant board “Seat N” labels. Preserve meaningful text, accessible semantic names and necessary shared-editor target identification. See [layout guidance](02_layout_and_interaction.md#compact-controls-and-restrained-chrome--accepted-2026-10-22).
