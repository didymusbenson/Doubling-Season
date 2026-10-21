# Product and scope

**Status:** confirmed direction plus proposed release boundaries. See [decision status](09_decision_register.md).

## Product intent

Place an iPad in the middle of a Magic game and let each player operate their own small Tripling Season board while everyone can see the central life tracker. Players should spend little time navigating and should recognize immediately whose state a control changes.

This is a distinct project with a different frontend composition. “New project” does not yet decide whether it ships as a second app, a separate Flutter application in a shared workspace, or an edition exposed through the existing app. That distinction is D01. Likewise, “iPad” is the working name and primary design reference; support for Android tablets or large browser windows is D03.

## Experience principles

| Principle | Observable consequence |
|---|---|
| The table is the primary screen | Normal token/life interactions retain the other players' context |
| Player ownership is visible | Name/seat identity accompanies menus, confirmations, creation and errors |
| Player ownership is enforced | A stale callback cannot redirect output to whoever used the tablet most recently |
| Life stays easy to read | Lists scroll without scrolling the central life display away |
| Lists serve their content | Utilities and tokens reorder independently; life never participates in either order |
| Shared device, independent work | P1 changing life does not collapse P3's editor or consume P2's drag |
| Recovery is part of gameplay | Accidental local clears can be undone without rewinding someone else's later edits |
| Familiar domain, new shell | Preserve token arithmetic, artwork, counters and utility behavior where applicable |
| Manual control remains available | The app assists players without claiming full knowledge of the physical game |

## Primary journeys

1. **Start a table:** choose the supported participant count and life preset, name/color each participant, set seating/orientation, optionally load each player's token/utility deck, then start.
2. **Create while another player acts:** P1 opens their menu and searches for a token while P3 changes life. Creation and any follow-on tokens go to P1. P3 remains responsive.
3. **Resolve a utility:** P2 runs Krenko using P2's token state, tracked non-token count and P2's rules. P4's identically named tokens and utilities remain unaffected.
4. **Rearrange a busy board:** P4 moves a token within P4's token lane and a utility within P4's utility lane. Other lanes keep their order and scroll position.
5. **Correct a mistake:** P1 reverses a grouped life change or local clear. P2's subsequent changes survive.
6. **Run it back:** the central menu previews what “New game” resets, with an explicit keep-seats / reload-decks choice if supported. The table resumes in one coherent new session generation.
7. **Resume after interruption:** the app restores participants, life, boards, rules and orders after termination, and explains any incomplete operation that could not be recovered.

## Candidate first release

The following is a proposed cut, not an approved commitment. “Foundation” means prove the design before release scoping; it is not itself a smaller product release.

| Capability | Foundation prototype | Proposed first usable edition | Later / separate decision |
|---|---|---|---|
| Table | Four fixed placeholder seats | Four named seats; session resume | 2/3-player layouts, 5+ players, teams |
| Life | ±1, direct set, independent input | Starting-life presets, grouped undo, local history | Rich game history and statistics |
| Tokens | One creation route and reorder | Search/custom/create, counts, tap, sickness, counters, copy/split, artwork | Explicit cross-player gifting/control transfer |
| Utilities | One manual tracker and Krenko | Existing utility parity where scoped safely; mana pool candidate | Additional automation / shared global effects |
| Rules | Per-seat sample presets | Existing supported rule behavior isolated per player | New full-table rules and arbitrary opponent triggers |
| Decks | None required for touch spike | Load/save per player; compatible library reuse | Share an entire table setup / session export |
| Game controls | Safe sample reset | Clearly scoped reset/new game and recovery | Turn/phase engine, tournament tools |
| Device | Physical iPad prototype | Approved iPad/device floor | Android tablet/web release commitments |
| Connectivity | Airplane-mode play | Local persistence and cached/bundled content | Sync, multiplayer networking, accounts |

Existing utilities must be inventoried individually before claiming parity. A release may explicitly omit a utility that lacks safe player scoping, but must communicate that omission rather than silently changing its behavior. D08 settles the release inventory; D27 settles the mana pool cut. Rich commander support is D26 and should be resolved before marketing this as a full Commander life tracker.

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
| R12 | New mana-pool utility | User named direction; details open | [Utilities](07_utilities_tokens_and_decks.md), V37–V39 |

## Boundaries

The proposed initial edition tracks public game state on one device. It does not infer a person's identity from touch, enforce hidden information, authenticate seats, or implement the entire Magic stack. “My menu” means a control is bound to a player, not that another person is prevented from reaching it.

Do not implicitly add networking, cloud synchronization, deck-list import services, an opponent rules engine, automatic combat resolution, automatic mana payment, or a native-framework rewrite to deliver this concept. Revisit any of these through a separately scoped decision. Dungeon support remains outside this project's roadmap, consistent with the existing queue.

## Product questions that affect the architecture

- Must two people be able to search/edit at the same time, or is one local panel with all other players' quick controls still live sufficient? D09.
- Is four-player landscape the release requirement, or must every supported viewport preserve all four spaces? D04/D06.
- Should the existing phone app share live games, only deck files, or no user data with this edition? D18/D23.
- Is commander damage a release requirement, and should its entry also subtract life? D26.
- Are rules describing global cards intentionally local manual approximations, or must a table-wide effect be modeled? D25.
- Does “board wipe” mean the invoking player's tokens, all players' tokens, or an explicit participant selection? D22. Labels must settle this before implementation.

## Success criteria

Proposed acceptance means four people can complete a representative game without losing track of whose controls they are using, without accidental cross-player mutations, and without abandoning the tablet when token or utility lists grow. The release must survive interruptions, recover its last acknowledged durable state, preserve local ordering, and expose errors where the affected player can see them.

Measure this in a real tabletop session. Record reach/legibility problems, accidental touches, time to create and adjust a token, menu interruptions, and recovery results. No usability or performance result is claimed by this documentation.
