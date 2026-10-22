# Lifetap research for the Tripling Season iPad life tracker

**Research date:** 2026-10-21 UTC (2026-10-20 on the Mac). **Status:** usable research checkpoint with broad, partial hands-on coverage of Android 1.3.10; remaining UI checks blocked by a locked host. **Repository context:** `didymusbenson/Doubling-Season`, shared planning branch `codex/ipad-edition-planning`, inspected base `3ddb425`.

This is reference research, not an amendment to the iPad requirements or an implementation specification. The aim is to understand tabletop needs, interactions, and useful conveniences for an original Tripling Season life tracker. It does not authorize copying Lifetap branding, artwork, screen composition, or visual identity. Product choices remain in [03_life_and_game_controls.md](03_life_and_game_controls.md) and the open [decision register](09_decision_register.md), especially **D22** (resets), **D26** (life-tracker depth), and **D28** (universal tools).

## Evidence standard and current limit

| Tag | Meaning |
|---|---|
| **Observed** | Directly exercised in the installed app; record device/build, steps, outcome, and evidence. Seeing an official web page is not an observed app interaction. |
| **Listing-only** | Advertised by a cited official store/vendor source; may differ by platform, release, device, or configuration. |
| **Untested** | A research question or procedure not yet executed. This does not imply the feature exists. |
| **Absent (scope-limited)** | Not found after a named search of specified app surfaces on the tested build. This never means universally absent from all versions. |

**At this checkpoint the official Android app has been installed and explored.** Observed coverage includes both layouts for 2–6 players, orientation/settings, basic life/counter/commander edits, KO/manual restoration, reset/history/winner/draw flows, export share entry, randomizers/dice, countdown/pause, naming/colors/OLED, partner artwork/saved players, planar-deck editing and gameplay, scheme navigation, bounty rewards/claim/back, and mana/storm clear/reopen. The source inventory remains Listing-only wherever runtime behavior has not been verified. This is not exhaustive app coverage; the open checklist and gap list identify substantial remaining work. Screenshots document selected visible states, not every interaction.

## Official identity, acquisition, and version provenance

| Item | Verified source fact |
|---|---|
| App identity | **Lifetap Life Counter for MTG**, developer **Michael Bourkas**, Android package **`com.lifetap`**. [Google Play](https://play.google.com/store/apps/details?id=com.lifetap&hl=en_US) |
| Vendor | Play support links to [getlifetap.com](https://getlifetap.com/) and `hello@getlifetap.com`. |
| Android listing | Updated **October 6, 2026**. The rendered public listing does not establish the installed Android version; package inspection independently verified **1.3.10 (162)** below. |
| Apple counterpart | [App Store ID 1508241754](https://apps.apple.com/us/app/lifetap-life-counter-for-mtg/id1508241754), same developer; displayed latest version **1.3.10**, **October 5**. This is iOS provenance, not proof of Android parity. |
| Verified distribution | Official Google Play and Apple App Store listings. No official direct APK, simulator build, or public source repository was located in this source pass. That is a search result, not proof none exists. |
| Installation boundary | Use the official store/vendor channel. A third-party APK would require action-time permission; do not substitute an unverified mirror. Do not purchase, change account/security settings, establish persistent access, or accept new agreements without required permission. |

### Runtime record — observed installation

| Field | Value |
|---|---|
| Host / Android Studio version | Authorized Mac environment; **Android Studio Otter 2025.2.1**. A cloud/Gemini incompatibility notice did not block emulator use. |
| Emulator / AVD / device model | **`Medium_Phone_API_36.1`**, emulator **`emulator-5558`**. The AVD name differs from the runtime SDK reported below. |
| Android version / API / ABI | **Android 16**, `ro.build.version.sdk=36`, **arm64-v8a**. |
| Lifetap version / version code | **1.3.10 / 162**; package **`com.lifetap`**, minimum SDK **24**, target SDK **36**. |
| Acquisition path and install outcome | Installed successfully through official Google Play; installer **`com.android.vending`**; package install time **2026-10-20 21:08:22 Mac local**. Store identity matched Michael Bourkas. |
| App locale / display size / density | **English**, emulator **1080 × 2400**, density **420**. |
| First-launch agreements or permissions | Directly entered the board; no onboarding or new terms appeared in this first-launch flow. No account login was needed on the selected AVD. |
| Session / saved evidence | Exploration began on Mac local 2026-10-20; this checkpoint records the completed tests; selected screenshots are indexed below. No persistence or accessibility outcome inferred from installation. |

Android 13/API 33 and Android 15/API 35 AVDs were also booted. Both had zero Google accounts; the Android 13 store presented **Sign in** ([store state](reference/lifetap/ENV-01-play-sign-in.png)). The third AVD already had a Google account, so the official installation succeeded without a new login. These were distinct environment states, not a blanket emulator incompatibility. No third-party APK was used.

## Observed app findings — partial workflow coverage

The findings here are from Android **1.3.10 (162)** on the runtime above. A visible option establishes its presence and displayed default, not that every underlying effect was tested. Exact labels are quoted where captured; descriptions of icon-only controls are researcher descriptions.

### First launch, table, and orientation

| Surface / action | Observed result | Evidence / limitation |
|---|---|---|
| First launch | Four players at **40** life each; labels **Player 1–4**; pale blue gradient backgrounds. Commander mini-grids showed **me** and three zero values. | [Initial board](reference/lifetap/BOARD-01-first-launch.png), captured before life/damage edits. |
| Center controls | **Reset**, player count **4** with settings control, history, color, and die controls were visible. | Icon descriptions do not establish additional menus' contents. |
| Portrait table | Player areas faced the left and right sides of the emulated phone. | Physical seated reach/readability on an iPad remains untested. |
| Emulator rotation | Landscape reflowed the four-player grid and retained **40** totals. The settings view remained portrait-relative/sideways until rotated back. | This tests the emulator rotation path, not all camera/layout combinations. |
| Return after Mac unlock | Four-player board remained at **40** each, countdown displayed **Paused**, **27:52**. | This is a host interruption/resumption observation, not an app force-stop/reboot test. |
| Two-player presentation | After confirmed count change, top and bottom players faced opposite directions with starting life **40**. | Alternative layouts were subsequently exercised below. |

Both offered layout choices were exercised at every count **2–6**. The row descriptions below are researcher shorthand for visible arrangement, not app labels or an assurance that every seat's rotation was measured.

| Players | First layout observed | Alternate layout observed |
|---|---|---|
| **2** | Vertical top/bottom, facing opposite directions | Side-by-side rotated areas, with black unused space |
| **3** | One wide area + two areas | Two areas + one wide area |
| **4** | **2 × 2** grid | **1 + 2 + 1** rows |
| **5** | **2 + 2 + 1** rows | **1 + 2 + 2** rows |
| **6** | **2 × 3** grid | **1 + 2 + 2 + 1** rows |

All these boards were observed at **40** life, except a later four-player alternate-layout test where starting life was changed to **20**. That change showed the same inline reset warning; **Confirm** produced **20** for all players. **Absent (scope-limited):** no dedicated team/shared-life setting was seen in the traversed settings and 2–6-player layout controls. This does not establish the absence of every way to represent team play.

### Settings inventory and initial values

The settings screen was traversed top, middle, and bottom: [top](reference/lifetap/SETTINGS-01-top.png), [middle](reference/lifetap/SETTINGS-01-appearance.png), [bottom](reference/lifetap/SETTINGS-01-bottom.png). Unless a test is described separately, controls below were inspected, not functionally exercised.

| Group / label | Observed choices or initial state | What remains unverified |
|---|---|---|
| **Players** | **2, 3, 4, 5, 6**; **4** initially selected. Both offered layouts at each count tested. | One-player mode and all state-retention implications. |
| Four-player layout icons | Two icons: selected **2 × 2** and alternate **1–2–1** arrangement, both exercised. | All orientation/window-size combinations. |
| **Starting life** | **20, 25, 30, 40** plus a custom slot displaying **60**; **40** initially selected. Changing to **20** and confirming reset produced all-20 life. | 25/30, custom entry and accepted bounds. Displayed 60 does not prove a separate fixed preset. |
| **Planechase**, **Archenemy**, **Bounty** | All **off** initially; descriptions indicated internet required for the respective planar/scheme/bounty deck. All three were enabled simultaneously and exposed **three distinct toolbar icons**. Individual workflows are tested below. | Combined reset/retention behavior, complete format lifecycles, offline availability, and deck capacity. |
| **Auto-KO** | **On**; “From life, poison, or commander damage”. Poison **10** triggered KO; manual clearing tested below. | Life/commander thresholds, all downstream elimination effects. |
| **Commander damage life loss** | **On**; “Commander damage also reduces life”. One commander-cell tap **20 → 19** life verified coupling. | Toggle-off behavior, correction semantics, undo coupling, partners. |
| **Turn timer** | **Off** initially; expanded modes documented below. | Every mode beyond the partial countdown test. |
| **Game history** | **On**; current life events, winner archive and conversion to Draw tested below. | Full retention, undo, deeper filters, and delivered export contents. |
| **Starting player** | **Random** initially; expanded choices **Random / Choose / Off**. | Which reset/start flow applies the choice; indicator duration. |
| **Colorize commander mini-grids** | **On**; description says they reflect player backgrounds. | Color/art changes and readability with varied backgrounds. |
| **Player card layout** | **Default** selected; **Name only**, **Big font** alternatives. | Each layout's interaction and accessibility. |
| **Auto hide menu** | **Off**. | Hide delay, restoration gesture, and accidental-input implications. |
| **Dice & randomizer animations** | **On**. | Disabled-animation behavior and any reduced-motion integration. |
| **One-player mode** | **Off**; “Tracks only one player (yourself)”; a **?** help affordance was present. | Help text, one-player controls, and incoming-source setup. |
| **Camera mode** | **Off**; “All players face one direction”. | Mode choices and behavior. |
| **Language** | **English**. | Full language list, switching, and text fit. |
| **Keep display awake** | **On**. | Actual timeout behavior over a long session. |
| **Haptic feedback** | **On**. | Physical feedback; emulator interaction cannot establish tactile quality. |
| **Hide navigation and status bars** | **On**. | Every navigation/interruption path. |
| Support links | **Review Lifetap on Google Play**, **Donate via Paypal**, **Send feedback**, **Send diagnostics** were present and not activated. | External destinations and payloads deliberately untested. |
| Footer | **1.3.10**, **Michael Bourkas**, **Scryfall**, **Manafont** visible. | Credits are not an asset reuse license. |

**Location finding:** OLED was not a row in the main settings screen; it was subsequently found and exercised **inside the player color picker**, described below. **Absent (scope-limited):** no general sound setting row was seen in the traversed top/middle/bottom settings. The timer-specific **Turn time alert** option does mention sound; absence of a general row is not absence of all sound controls.

### Life adjustment, player panel, and counters

| Procedure / surface | Observed result | Limit |
|---|---|---|
| Tap Player 1 **+** | **40 → 41**, with a transient **+1** delta. | Hold/repeat acceleration, grouping window, multi-touch, and direct numeric input remain untested. |
| Two-player ± taps | Player 2 reached **41**, Player 1 **39**. A tap at the center-left life region decremented by **1** rather than opening numeric input. | This identifies one hit region; it does not prove no direct-entry route exists elsewhere. |
| Tap player name | A seat-oriented, rotated modal opened with tabs **Player / Counters**. **Player** showed a name field, **Load**, **Backgrounds / Colors**, and **Increase contrast** enabled. | Renaming/color changes tested separately below; saved profile and contrast effects remain open. |
| **Counters** tab | Hint: **“Tap to increment. Hold for additional options.”** Controls labeled **Monarch**, **Initiative**, **Ascend**, **Day/night**, **Energy**, **Exp**, **Treasure**, **Poison**, **Rad**, **C.Tax**, **K.O.**; three opponent commander cells at **0** plus **me**. Tapping a board commander mini-grid also opened this tab. | Long-press options, stable source identities, partners, and bounds remain untested. |
| Tap numeric counters | **Energy / Exp / Treasure / Rad / C.Tax** each incremented to **1**; decrement buttons appeared for nonzero numeric counters. | No negative/maximum limits or tax step semantics established beyond the displayed 0 → 1 change. |
| Tap status controls | **Monarch**, **Initiative**, **Ascend** were enabled; **Day/night** added a sun control to the central toolbar. | Cross-player exclusivity, subsequent transitions, and reset effects remain untested. |
| Increment **Poison** ten times | At **10**, Auto-KO dimmed the player area and showed a skull while life remained **41**. | This verifies the poison path on this build; do not infer game-rule completeness. |
| Decrement poison then clear KO | **10 → 9** did **not** clear KO. Tapping **K.O.** cleared the KO state manually. | Life-zero and commander-damage revival paths, input restrictions, and randomizer/timer treatment remain open. |
| Commander damage from a grid cell | On a four-player board starting **20**, tapping the top cell once displayed damage **1** and life **19**. Twenty further taps reached damage **21**; another cell was incremented to **1**. After manual KO clearing, board life was **−2**, with commander cells **21 / 1 / 0**. | This confirms per-cell values and associated life deduction, not a separately isolated 21-damage KO threshold. Life could have reached zero before damage 21 because starting life was 20. Source mapping remained spatial with default names; partners untested. |

[Counter-panel evidence](reference/lifetap/COUNTER-01-edited-state.png) shows the seat-oriented modal after these edits: poison **9**, the other numeric counters **1**, Player 1 life **41**, and countdown **Paused 27:52**. Screenshot state alone does not show the preceding ten increments or KO transition; those are procedural observations.

### Count changes, reset confirmation, history, and export entry points

| Procedure / surface | Observed result | Limit |
|---|---|---|
| Change players **4 → 2** | Inline **“Warning: this will reset the current game”**, **Cancel / Confirm**. Cancel was tested; a subsequent Confirm created the two-player board and closed settings. | No assumption about token/utility state in another app; Lifetap reset scope is evaluated only here. |
| Check archives after count change | **Past Games** remained empty. The prior four-player game was not present in the inspected archive. | Distinguish this setup change from the explicit reset flow below; not a general claim about every configuration change. |
| Open history toolbar | **Game History**, **Current Game / Past Games**. Current summary showed **Game 1**, date, **2 players**, **40** starting life. Player rows showed final totals and **“No profile selected”**. Life entries included **+1 → 41** and **−1 → 39**. | Tapping an entry showed no visible undo affordance in the attempted path; no global absence of undo is asserted. |
| Empty **Past Games** | **“No games recorded yet. Games are saved when you reset.”** | This hint was followed by one tested explicit reset. |
| Open **Reset** | Dialog **“Reset game”**; **“Select the winner (optional)”**; Player 1 / Player 2 with current totals; **Draw**; **“This will reset life back to 40. Proceed?”**; **Reset / Cancel**. | [Reset-dialog evidence](reference/lifetap/RESET-01-confirmation.png). Broader counter/profile/timer reset effects not fully measured. |
| Cancel reset | Board retained its tested state. | System Back/outside dismissal and active-editor interruption not yet tested. |
| Select Player 1, then **Reset** | Past Games gained **Game 1**, trophy for **Player 1**, **2 players**, start **40**, duration **1 min**. Archive detail retained changes and exposed **Edit Winner / Delete Game**. | Deletion, retention, and repeated-reset interactions remain untested. |
| **Edit Winner → Draw → Confirm** | The archived result changed to **Draw**. | No deletion or other result correction tested. |
| Open **Export game** | **Summary CSV** described overview/game/players/final statistics; **Full detail JSON** described player details/event history; **Cancel** available. | Option labels/descriptions observed; exported data not inspected. |
| Select **Summary CSV** | After a delay, Android's share UI opened and offered **`lifetap-game.csv`**. | This verifies a share handoff/name, not validated CSV contents or delivery. |
| Share-flow interruption | While aiming for Edit Winner before transitions settled, the researcher inadvertently selected **Save to Drive** in the delayed share UI. **Save** was never pressed; **Cancel upload** was confirmed and the app returned to Lifetap. | No upload completed or file contents were validated. This transition race is worth remembering when replaying the export procedure. |
| **Filter** | Expanded chips for **Player 1 / Player 2**. | Chip application and combinations not tested. |
| **Players** tab after Draw edit | Both players showed **0 W / 1 D / 0 L**, **0%**. | More games, naming/profile merges, and percentage definitions untested. |
| **Profiles** tab | Empty message **“No profile data yet. Set player profiles to track deck stats”**. | Profile/deck statistics require a configured profile and additional completed games. |
| **Insights** tab | **1 Games**, total **1 min**, average **1 min**; turn-order advantage **Goes first / Position 2**, each **0/1**, **0%**; game duration **Avg / Longest / Shortest**, each **1 min**. Feedback link present and not activated. | A single drawn game cannot validate statistical calculations across outcomes. |
| Archive navigation | Tabs **Games / Players / Profiles / Insights**, plus **Filter** and an export icon. | Aggregate export icon, deeper searching/filtering, and JSON remain untested. |

The count-change warning and explicit reset archive behavior are distinct findings. A convenient reset path can still discard a game when reached through a different setup control; the observed difference is a useful follow-up target, not a claim that all such paths were audited.

### Naming, player colors, OLED, and background picker

| Procedure / surface | Observed result | Limit |
|---|---|---|
| Edit player name | Player 1 was successfully renamed through its text field; the saved-player screenshot displays **Research A**. | Collision behavior and persistence across restart are not established. |
| Open **Colors** | **12 swatches** in visible groups **5 + 2 + 5**; text **“colors are added in the order that they are selected”**. Blue and purple selections showed checkmarks and produced a gradient. | All combinations, contrast, ordering after deselection, and saved profiles not tested. |
| **OLED black** in color picker | Initially **off**. Turning it **on** produced a pure-black player area with colored text/border; switching **off** restored the gradient. | Confirms this control's location and visible behavior on the emulator, not power consumption on a physical OLED device. |
| Open background picker | **“Customize background”**, **“Search for Magic cards...”**, Scryfall syntax hint including an artist example; **Search Partners / Search Companions / Search Backgrounds / Random Card** buttons; Scryfall API attribution. | Presence of quick filters does not verify partner ledger behavior. |
| Search **Tymna** | Search completed with **three printings**, each showing a thumbnail, set, artist/copyright information, and **Set**. Selecting **Tymna the Weaver**, **C16**, **Winona Nelson** applied its background and exposed a partner hint. | Catalog completeness, offline failure, and every printing's selection remain untested. |
| Artwork layout | Default **Cover** — “Crops to fill the player card”; **Contain** — “Shows full art with soft edge fill”. Selecting Contain and then Cover was exercised. **Image position** appeared only for Cover, initially **Center**. Five directional anchor icons were present; choosing the top icon exposed label **Top**. | Other anchor names are visual direction interpretations, not verified text labels; arbitrary/manual crop was not established. |
| Search and set partner | Searching **Thrasios** required a second Return before the intended names appeared; results and images updated after a delay. **Set as partner** on **Thrasios, Triton Hero**, **C16**, **Josu Hernaiz** produced two separate artwork controls, each with Cover/position settings, and a split-art player area. | Do not call the asynchronous search sequence a bug without a controlled reproduction. |
| Partner damage presentation | Other players' commander mini-grids now showed **two art-backed zero cells** for this player. | Independent partner damage increments/source labels/corrections remain untested. |

### Saved-player library and Planechase customization

| Procedure / surface | Observed result | Limit |
|---|---|---|
| **Load** before and after closing editor | Load was initially empty before closing the player editor. Closing, reopening, and entering Load then showed **Research A**, both commander names/art, **Selected**, expansion arrow, and star. | This supports the tested save/reopen sequence; it does not identify the exact persistence trigger or prove crash durability. |
| Library help | **“Lifetap saves every player with a unique name”**. UI says up to **20 players**, each up to **10 profiles/decks**; starred players are saved without counting toward the limit. | These are **Observed UI claims**, not capacity/eviction tests. |
| Star and expand player | Tapping Research A's star filled it. Expanding showed **“No other decks saved for this player”** and **Delete Player**. | Deletion was not activated; additional profiles, other seats' loading, and capacity remain open. |
| Enable **Planechase** | A customization button became available; opening it showed planar-deck groups and **Saved planar decks 0/5**, plus **Save current selection**. | Basic gameplay was subsequently exercised below; offline availability remains open. |
| Expand **Planechase Anthology** | Opened a scrolling two-column card-image/checkbox grid. Tapping a card body opened a magnified preview; **Back** closed it. | Full image/catalog audit and every card interaction untested. |
| Deselect **Academy at Tolaria West** | Group count changed **86/86 → 85/86**; group checkbox became indeterminate with a minus; the deselected card was dimmed. | Other card/group combinations and duplicate handling untested. |
| Save customized selection | Unchecked the other four entire groups. **Save current selection** opened an inline name field with **Cancel / Save**. Saved **Research deck**; UI then showed **Saved planar decks 1/5**, **Research deck**, **85 cards**, **Selected**, and a trash control. | Trash was not used; fifth/sixth preset, duplicate names, and actual shuffled-deck contents remain untested. |
| Unchanged selection | Save was disabled while the current selection was unchanged. | Validation after further edits/reloading a preset remains open. |

[Saved-player evidence](reference/lifetap/PROFILE-01-saved-partners.png) shows Research A with both commander names/art, filled star, expanded empty-other-decks state, help text, and the unused Delete Player action.

The planar customization UI initially had all five groups checked:

| Group label | Displayed selected / available |
|---|---|
| **Planechase Anthology (2016)** | **86/86** |
| **March of the Machine (2023)** | **50/50** |
| **Doctor Who (2023)** | **40/40** |
| **Black Lotus Unknown (2024)** | **46/46**, described as funny/joke cards |
| **Secret Lair Showcase (2024)** | **10/10** |

These are app-displayed group counts, not an independently audited unique-card total. They provide a more detailed current runtime view than the vendor page's compact “86 planar cards” claim; preserve the source distinction rather than treating the marketing number as the complete installed catalog.

### Planechase — plane navigation and planar die

| Procedure / surface | Observed result | Limit |
|---|---|---|
| Open Planechase mode | Card area with **Back / Flip plane / Planeswalk / Planar die** controls and **?** help. | Help/alternate inputs and every plane/phenomenon rule flow not fully tested. |
| **Planeswalk** | **Lair of Ashen Idol → Otaria**. | No deck-order or complete-history guarantee inferred from two cards. |
| Roll **Planar die** | Result **Planeswalk** exposed an explicit **“Click to Planeswalk”** action. Clicking advanced the displayed plane; the resulting capture shows **Mirrored Depths**. | Chaos/blank results, repeat-roll accounting, deck depletion, and reset behavior remain open. |
| Tap plane card | Toggled enlarged white Oracle text over the artwork; it was initially rotated 90° like the card. | All orientations, large text, and screen-reader behavior not tested. |
| Read help | A quick hold on the toolbar icon was described as a shortcut for rolling. | **Observed UI claim**; the hold shortcut was not successfully exercised. |

[Planechase evidence](reference/lifetap/PLANE-03-after-planeswalk.png) shows Mirrored Depths after the explicit planeswalk action and the four bottom controls. The screenshot does not establish the preceding die animation or all outcomes.

### Archenemy — basic scheme navigation

| Procedure / surface | Observed result | Limit |
|---|---|---|
| Enable **Archenemy**, open its mode | Header with **?** help, an **Ongoing schemes** empty state, and **Top of scheme deck** card area. Controls included **Back / Flip (180) / Next scheme**. | Ongoing-scheme placement/resolution, custom scheme decks, and reset interactions remain untested. |
| Advance schemes | Initially **My Genius Knows No Bounds**; **Next scheme** showed **Behold My Grandeur**; a later card was **Your Puny Minds Cannot Fathom**. | Three observed names are a navigation sample, not verification of full deck contents or randomization. |
| **Flip (180)** | Rotated the displayed card; rotation persisted while moving between cards. | All screen/orientation combinations untested. |
| Read **?** help | Described randomizing schemes for each game and on deck depletion, and magnifying a card. | These are **Observed UI claims**; game-reset/depletion randomization was not exhaustively exercised. |

### Bounty — reward ceiling, claim, and back behavior

| Procedure / surface | Observed result | Limit |
|---|---|---|
| Open Bounty | Began at reward **1**, **Bounty: The Outsider**, with **?** help and **Show Wanted Card**. | Initial randomization and full card inventory not audited. |
| **Show Wanted Card** | Opened a rules image including the reward ladder. | Reward-3 wording below was seen on this rules image, not separately on a live level-3 label. |
| Repeated **Pass** | Reward advanced **1 → 2 → 3 → 4**; an extra Pass stayed at **4**. | No game action outside the app was resolved. |
| **Claim** at reward 4 | Advanced to **Bounty: Lord Fajjal**, reward **1**. | Claim was not shown to automatically add mana, tokens, or cards to any player; no such effect is assumed. |
| **Back** after Claim | Returned to The Outsider but kept reward **1**, rather than restoring its prior reward **4**. | This is navigation behavior, not a full undo of the previous bounty state. |
| **Flip (180)** | Clicked during exploration. | Outcome was not isolated in a screenshot/controlled before-and-after, so rotation behavior remains partial. |

Observed reward meanings: **1** one Treasure; **2** two Treasures; **3** two Treasures **or** draw one; **4** both two Treasures **and** draw one. These are displayed instructions for the physical game, not verified automatic tracker actions.

### Mana Counter and Storm

| Procedure / surface | Observed result | Limit |
|---|---|---|
| Open five-colored-dots toolbar icon | **Mana Counter** with white, blue, black, red, green, colorless, and **Storm**, each initially **0**, with separate **+ / −** controls. | No player picker appeared on the inspected page; do not assume per-player attribution or shared scope from this alone. |
| Increment values | White, blue, and Storm incremented to **1**. | Red/green increments and numeric upper bounds not tested. |
| Decrement black at zero | Remained **0**. | Confirms this one zero-boundary path; not a general bound for life or other counter types. |
| **Clear** | Immediately reset all values without a confirmation dialog. | Undo and interruption behavior were not tested. |
| Close/reopen | Colorless **1** survived closing and reopening Mana Counter. | This is panel-level retention, not app restart/crash durability. No automatic turn/phase or game effects assumed. |

### Timer choices and partial countdown test

| Control / procedure | Observed result | Limit |
|---|---|---|
| Expand **Turn timer** | **Off**; **Turn counter** — “Track turn count only, no time”; **Stopwatch** — “Counts up each turn”; **Countdown** — “Time limit per player”; **Chess clock** — “Time limit per player, tracks priority”. | Mode descriptions do not establish complete behavior. |
| Select **Countdown** | **Mins per player** choices **5 / 10 / 15 / 30**, with **30** selected, and custom slot **60**. **Turn time alert** was **off** with “Sounds alert if turn time limit is reached”. | No audible alert or other timing mode exercised. |
| Attempt custom edit | Typing **1** produced **160** because Ctrl+A did not select existing text; **30** remained selected. | This is an input-attempt result, not validation of 160 minutes or any numeric bound. |
| Return to board | Player 1 displayed **Turn 1**, remaining time **28:16** after time spent in settings. An added pause icon successfully paused it. | Exact start moment, timer-in-settings accounting, restart persistence, resume, advancement, priority, and undo remain untested. |
| Later two-player interaction | Active timing changed from Player 1 to Player 2 after a Player 1 center-area tap. | Causality was not isolated: do not state that tapping life automatically advances the timer. Repeat with controlled inputs. |

### Dice and randomizer workflow

The **Dice & Misc** screen exposed **Randomize player**, **Randomize opponent**, **Flip coin** with a circular **2**, **Custom** with **Set**, numeric **7**, and **Roll**, plus **Roll d4 / d6 / d8 / d10 / d12 / d20**. The hint read: **“Hold the die button for instant access to all dice and randomizers”**. [Dice menu](reference/lifetap/DICE-01-menu.png)

| Procedure | Observed result | Limit |
|---|---|---|
| Activate each fixed die once | All six controls opened animated large modals with appropriate die shapes and numeric results. | Captures were during animation; stable final values, result duration, history, and statistical fairness were not established. |
| Flip coin | An animated result displayed numeric **2**, rather than a captured heads/tails word. | Do not infer exact outcome semantics from this single animation-state capture. |
| Set custom sides to **7**, then **Roll** | Modal label **“7-sided die”** and numeric **2** were visible. | Only that positive value was exercised; bounds were not tested. |
| Dismiss result | Modals were temporary and could be dismissed by tapping outside. | Timing was not measured; repeated/reentrant behavior remains open. |
| Attempt custom **0** | Last edit/outcome uncertain: the Mac locked before the next **Roll**. | No zero-sided-roll outcome claimed. The user subsequently unlocked the Mac and exploration resumed. |
| Attempt quick die access | A stationary drag input resolved as a tap. | No successful hold/radial shortcut was established; this input attempt is not proof the shortcut is absent. |
| **Randomize player** | Returned to the board with flashing white borders moving among seats. | Final selected player was not captured before the transient display disappeared. |
| **Randomize opponent** | Replaced seat controls with **“I'm Player N”** buttons. Choosing **“I'm Player 1”** invoked flashing selection among the other seats. | This establishes an explicit perspective-selection step; final selection, eliminated-player handling, and statistical fairness were not validated. |

Randomizer final-result visibility/timing, eliminated-player inclusion, verified radial-menu operation, and animation-off behavior remain untested.

## Workflow inventory — official claims, not runtime verification

The compact claims below deliberately avoid supplying undocumented defaults, numeric limits, or inferred behavior. Later observations should name the exact app label and explain whether they confirm, qualify, or contradict a claim.

### Setup, life, multiplayer, and recovery

**Listing-only — [Google Play description](https://play.google.com/store/apps/details?id=com.lifetap&hl=en_US):** 1–6 players; team formats; commander damage by source, including partners; saved named profiles with artwork/colors; Planechase, Archenemy, and Bounty; Infect, Treasure, Experience, Commander tax, Monarchy, Initiative, Energy, Day/Night, and City’s Blessing. Reset presets are **20/25/30/40**, with optional seating randomization. It advertises player/opponent/dice/coin randomizers, stopwatch/countdown/chess timers with alerts, mana/storm tracking, tablets, twelve languages, and crash/reboot recovery. Current Android release notes mention CSV/detailed JSON export and artwork layout/cropping.

### Detailed tabletop conveniences

**Listing-only — [vendor features](https://getlifetap.com/#features):** custom starting life; hold-to-accelerate adjustment; camera mode; radiation counters; **d4/d6/d8/d10/d12/d20/custom-sided dice**; player drag-and-drop; searchable game history and player/deck statistics. Artwork search uses Scryfall, with two images for partner/Background/Companion configurations. The site claims free use without advertisements or a required account. It lists 86 planar cards, 65 schemes, and 12 bounty cards; treat catalog completeness as an advertised snapshot, not a verified inventory.

### Release-history clues requiring Android confirmation

**Listing-only — [Apple version history](https://apps.apple.com/us/app/lifetap-life-counter-for-mtg/id1508241754):**

| Release | Interaction or option to investigate |
|---|---|
| 1.3.10 | Filtered or single-game CSV/JSON export; artwork **Cover**, **Contain**, crop. |
| 1.3.9 | Individual Planechase/Archenemy/Bounty card selection; up to five presets per mode; Scryfall search syntax; OLED option; portrait camera mode; history filters. |
| 1.3.3 | Long-press die opens radial randomizer menu; turns without timing; draws and W/D/L; 3-/5-player layouts; partner detection. |
| 1.3.2 / 1.3.1 | History; narrower two-player landscape; disable dice/coin animation. |
| 1.2.15 | Timer pause/resume; long-press undo. |
| Older entries | Name dragging swaps players; commander-damage/life coupling option; zero-life auto-KO reversal by adding life; ten-poison auto-KO; profile clearing on restart; alternate 4-/6-player layouts. |

These entries are investigation prompts, not exact Android settings labels. Dates without a displayed year must not be silently assigned one. Older behavior may have changed.

### Persistence and privacy qualification

**Listing-only — [privacy policy](https://getlifetap.com/privacy), updated March 18, 2026:** names, profiles, history, counters, and settings are described as local data; diagnostics are disclosed. Conditional wording about optional account/backup/sync features does **not** demonstrate that these features are currently available. App deletion, reset, export, and crash recovery require separate tests.

## Hands-on execution plan and coverage checklist

This is the comprehensive procedure, not a claim that every feature exists or every item has been completed. Checked items are covered at this checkpoint; unchecked items remain untested or partially tested as qualified in the observed findings. Use disposable research identities and synthetic game state. Record every reachable menu entry, toggle, picker choice, default, range, cancellation path, and confirmation verbatim. If an item is not found, record the surfaces searched before marking it Absent (scope-limited).

### Workflow coverage at this checkpoint

**Covered** means the specifically named procedure was completed, not that the whole app or every edge case was audited. **Partial** means meaningful hands-on work exists but named gaps remain. The detailed task boxes below stay open when a combined item contains unfinished checks.

| Workflow | Coverage | Completed hands-on scope / remaining qualification |
|---|---|---|
| Official installation and runtime identity | **Covered** | Play install, package/installer/version/code, Android/API/ABI, first launch. |
| Main settings inventory | **Covered for traversed screen** | Top/middle/bottom defaults/options transcribed; preference effects and secondary help/support paths only partly exercised. |
| 2–6-player layouts | **Covered for ten offered layouts** | Both choices at each count; initial four-player rotation. One-player/camera/window combinations and physical reach remain open. |
| Life adjustments | **Partial** | ±1 and transient delta; negative life reached through commander edits. Hold, direct input, large changes, interruption, and undo open. |
| Commander damage and partners | **Partial** | Per-cell life coupling, two source values, partner artwork/cell presentation. Independent partner increments, stable source labels, isolated threshold, corrections open. |
| Counters / shared states / KO | **Partial** | Every visible counter/status icon tapped, poison10 KO, poison9 retains KO, manual clearing. Bounds, hold options, cross-player exclusivity open. |
| Dice / coin / randomizers | **Partial** | Six fixed dice, seven-sided custom, coin, player/opponent selection flows. Final transient results, bounds, radial shortcut, animations-off open. |
| Timers / turns | **Partial** | All mode options inspected; countdown and pause used. Other modes, controlled advancement, alerts, undo, restart open. |
| Reset / history / export | **Partial** | Count-change warning/cancel/confirm; reset cancel/winner archive; Draw edit/stat tabs; CSV share handoff. Full reset matrix, deletion/retention, JSON and file contents/delivery open. |
| Names / profiles / colors / artwork | **Partial** | Rename, gradient/OLED, Tymna/Thrasios split art, Cover/Contain/Top, one starred saved-player entry. Multiple profiles/capacity/deletion/offline/cancel/restart open. |
| Planechase | **Partial** | Card/group selection, 85-card preset, preview, planeswalk and die-triggered explicit action. Other results, lifecycle, preset capacity/deletion/offline open. |
| Archenemy | **Partial** | Scheme advancement, flip persistence, help. Ongoing schemes, custom deck, reset/depletion open. |
| Bounty | **Partial** | Wanted rules image, reward1–4/ceiling, claim/back. Full deck, custom decks, reset/depletion and isolated flip open. |
| Mana / Storm | **Partial** | Selected increments, zero boundary, immediate Clear, panel-level retention. All colors/bounds/scope/undo/turn/restart open. |
| Persistence / recovery | **Partial, limited** | Host lock/resume and panel close/reopen only. No app force-stop, swipe-away, or emulator reboot outcome. |
| Accessibility / physical tabletop feedback | **Untested** | No screen-reader/large-text/multi-touch/physical reach or haptic/audio evaluation. Visible controls alone are not accessibility evidence. |

### 1. Installation and initial state

- [x] Inspect Android Studio, SDK tools, configured AVDs, running emulators, and connected devices before declaring a platform blocker.
- [x] Verify store title, developer, and package; install only through the authorized official channel.
- [x] Record installed version/code, OS/API/ABI, screen metrics, locale, and exact first-launch state.
- [ ] Capture the untouched initial board and all onboarding/help. Record preselected player count, life total, colors, enabled counters, toolbar icons, and visible hints.
- [ ] If blocked, record the exact action, target, message, and status: denied, pending, uncertain, or technically unavailable. A store listing is independent research, not a substitute for launch.

### 2. Player count, layout, and tabletop orientation

- [ ] Visit each reachable player count, including one-player mode; record total capacity and every layout choice. Both offered layouts at counts **2–6** are covered; one-player mode remains open.
- [ ] Test portrait/landscape, explicit camera mode, rotation while a panel is open, and narrow/tall viewport behavior. Distinguish rotating the whole app from rotating individual seats.
- [ ] Rename and reorder participants; track which identity keeps life, damage, counters, art, and history after a swap.
- [x] Look for team/shared-life modes without assuming a team claim means a dedicated team control. No dedicated setting found in the traversed main settings and 2–6-player layouts; scope-limited finding only.
- [ ] Evaluate reach and number readability from each seat. Test taps near borders and shared controls; record unintended neighboring-player changes.

### 3. Life changes, corrections, and numeric edges

- [x] Single-tap both sides; note hit areas, ±1 behavior, feedback, delta display, and whether controls remain visible. Partial hit-region sampling is documented above; this is not an exhaustive touch-target map.
- [ ] Hold for a measured short and long duration; note delay, repeat rate, acceleration, increments, release behavior, and cumulative delta grouping.
- [ ] Try any large-change, direct-entry, set-total, or increment-choice flow; distinguish change-by from set-to.
- [ ] Test 1 → 0 → negative, large values, malformed input, cancellation, and limits where input exists. Avoid extrapolating bounds from a few successful values.
- [ ] Interrupt a held gesture with Back, backgrounding, rotation, and a system overlay; verify it stops and does not resume unexpectedly.
- [ ] Search for undo/history and test one gesture, repeated taps, two different players, and corrections after unrelated changes. History visibility alone does not prove reversible undo.

### 4. Commander damage and counters

- [ ] With four distinct synthetic players, add incoming damage from each source; record attribution direction, life coupling, correction behavior, and visible source labels.
- [ ] Configure two commanders if possible; verify separate damage ledgers, tax, and labels before/after reordering or renaming players.
- [ ] Check boundary behavior around 20/21 commander damage and 9/10 poison; test manual recovery and any auto-KO preference.
- [ ] Open every counter/state selector. Record exact labels, numeric versus toggle behavior, bounds, defaults, reset effects, and whether inactive counters can be hidden.
- [ ] Transfer any shared marker between two players; check whether the previous holder clears and whether undo is possible. Check day/night and city’s blessing separately.
- [ ] Inspect mana/storm tools; exercise each reachable mana type, increment/decrement, clear, persistence, and relation to turns. White/blue/colorless/Storm edits, black-at-zero, immediate Clear, and panel close/reopen are covered; remaining colors, limits, restart, and turn relation are open.

### 5. Dice, coin, random selection, and timers

- [ ] Tap and long-press the die control; inventory all dice/randomizers and any quick-access configuration.
- [ ] Roll every fixed die, enter custom sides if supported, try boundary/invalid input, repeat rolls, dismiss during animation, and reopen. Record result duration and visibility to all seats.
- [ ] Flip coins repeatedly; inspect animation preference, sound/haptics, and whether previous results remain available.
- [ ] Exercise random player versus random opponent; identify whose perspective defines an opponent. Repeat after elimination and player-count changes. A handful of rolls cannot establish statistical fairness.
- [ ] Search for first-player selection and seat randomization. Confirm what changes and what stays fixed; note any persistent starter indicator.
- [ ] Inventory every timing/turn mode. Start, pause, resume, advance, undo, background, and reset; record defaults, time-entry limits, priority handling, alerts, and eliminated-player treatment.

### 6. Reset, restart, rematch, new game, and elimination

- [ ] Before each reset, create a recognizable state: distinct life totals, multiple damage sources, poison/energy, a shared marker, timer progress, customized profiles, and a history entry.
- [ ] Open each reset/new-game route; transcribe labels, preset/custom choices, default selections, warning text, confirmation buttons, and cancel/Back behavior.
- [ ] After execution, compare every field against the prepared state. Determine whether history archives, profiles persist, seating changes, counters clear, and timers stop.
- [ ] Try the same action again, reset while an editor is active, and cancel then reopen. Look for recovery/undo without assuming it exists.
- [ ] Trigger or mark elimination; observe retained data, input locking, overlays, randomizer/timer inclusion, restoration, and whether space is reclaimed.
- [ ] Keep separate findings for reset life, reset game, remove participant, delete profile, and erase data; these operations must not be conflated.

### 7. Profiles, customization, and optional formats

- [ ] Create two named players and multiple looks/decks if supported; load, edit, duplicate, and delete them. Record naming collisions and whether removing a seat deletes a saved profile.
- [ ] Exercise colors, artwork search, printing choices, two-image composition, crop/layout, cancel, and no-network states. Colors, Tymna/Thrasios printing selection, split artwork, Cover/Contain, and Top anchor are covered; cancellation/offline paths and remaining layout controls are open. Do not copy art into Tripling Season product assets.
- [ ] Inspect all Planechase, Archenemy, and Bounty screens if reachable: enablement, deck/set/card selection, presets, draw/advance/claim, history/discard, reshuffle, and reset interactions. Planar selection/preset/preview/planeswalk/die, scheme advance/flip/help, and bounty reward ceiling/claim/back are covered; full lifecycles, other outcomes, customization, and resets remain open.
- [ ] Record paywalls, account requirements, or inaccessible content precisely; do not accept new agreements or purchase to extend coverage.

### 8. Preferences, persistence, and accessibility

- [ ] Inventory all settings, including help/about/privacy/contact routes. Record defaults before changing them and whether scope is player, game, or device.
- [ ] Test sound, haptics, animation, brightness/theme, keep-awake, and orientation only if controls exist. Emulator-visible toggles do not establish physical haptic/audio quality.
- [ ] Change locale and large text where authorized and reversible; inspect clipping, contrast, semantics, screen-reader labels/traversal, touch targets, and rotated controls.
- [ ] Background/reopen, swipe away/relaunch, and force-stop/relaunch after known changes. Reboot the emulator only when safe; distinguish each persistence result.
- [ ] Inspect history search/filter/detail/export and recorded winners/draws. Keep export local; inspect file contents for identities, counters, timestamps, and unexpected data.
- [ ] Return research-only settings to an appropriate state; preserve the tested game where useful for follow-up.

## Execution log and evidence index

Times below are Mac local **2026-10-20**; the research/report date is **2026-10-21 UTC**. Capture times are retained in the table; evidence filenames use test IDs, not necessarily the start or end of a test. All runtime rows use Android **1.3.10 (162)** unless stated otherwise.

| Test ID / timestamp | Build / starting state | Exact steps and labels | Outcome / provenance | Screenshot or other evidence | Remaining gap |
|---|---|---|---|---|---|
| ENV-01 / 21:04:56 capture | Android 13 AVD; no Google account | Open official store | **Observed:** Sign in required in that AVD; no login undertaken | [Store sign-in](reference/lifetap/ENV-01-play-sign-in.png) | Distinct from successful third-AVD installation |
| INSTALL-01 / 21:08:22 package install | `Medium_Phone_API_36.1`; pre-existing store account | Official Play install; inspect package/installer | **Observed:** `com.lifetap`, 1.3.10/162, `com.android.vending` | Runtime package inspection recorded above | No blocker remains for installation |
| BOARD-01 / 21:09:52 capture | Fresh launch | Open app without onboarding; inspect untouched board | **Observed:** four named players, 40 each, gradient/minigrids/center controls | [Initial board](reference/lifetap/BOARD-01-first-launch.png) | Later tests are recorded separately |
| SETTINGS-01 / 21:14:17–21:17:58 captures | Initial four-player state | Open settings; traverse top/middle/bottom; expand mode and starter choices | **Observed:** options/defaults transcribed above | [Top](reference/lifetap/SETTINGS-01-top.png), [middle](reference/lifetap/SETTINGS-01-appearance.png), [bottom](reference/lifetap/SETTINGS-01-bottom.png) | Visible presence does not verify each option's effect |
| ORIENT-01 / during first exploration | Four players at 40 | Rotate emulator landscape and back; inspect settings | **Observed:** table reflow; settings portrait-relative; totals retained | Procedural observation | Rotation at other counts, camera and physical iPad untested |
| TIMER-01 / after settings exploration | Countdown selected; 30-minute choice | Attempt custom edit; return; tap pause | **Observed:** unselected custom 160 text; P1 Turn 1 at 28:16; pause succeeded | Procedural observation | Custom bounds, resume, other modes and persistence |
| DICE-01 / 21:21:16 menu capture and subsequent rolls | Animations on | Open Dice & Misc; activate six fixed dice, coin, custom seven-sided roll | **Observed:** animated result modals; outside dismissal; seven-sided label | [Menu](reference/lifetap/DICE-01-menu.png) | Stable result capture, radial shortcut, bounds/fairness; player/opponent flows recorded in RANDOM-01 |
| DICE-02 / interrupted attempt | Custom input being changed | Attempt 0; Mac locks before next Roll | **Untested/uncertain:** no roll outcome established; user unlocked afterward | No result evidence | Retry input validation only after inspecting current state |
| LIFE-01 / after unlock | Four players at 40; paused countdown | Tap +; open name; inspect Player and Counters | **Observed:** P1 41, +1 feedback; seat-oriented modal and available controls | [Counter state](reference/lifetap/COUNTER-01-edited-state.png) | Hold/numeric entry; later profile/color/artwork tests recorded separately |
| COUNTER-01 / 21:29:42 state capture | P1 life 41; Auto-KO on | Increment poison 10 times; decrement once; toggle K.O.; tap other controls | **Observed:** poison 10 caused KO; 9 retained KO; manual K.O. cleared it; other counters/statuses transcribed above | [Counters](reference/lifetap/COUNTER-01-edited-state.png) | Other thresholds, long-press options, cross-player marker exclusivity |
| COUNT-01 / after counter test | Four-player edited game | Select two players; Cancel, then repeat Confirm; inspect Past Games | **Observed:** reset warning; two-player board; prior game absent from archive | Procedural observation | Other count changes and state preservation |
| RESET-01 / 21:31:44 dialog capture | Two players at 39/41 | Open Reset; cancel; reopen, choose Player 1, Reset | **Observed:** cancellation preserved board; explicit reset archived Game 1 with winner | [Dialog](reference/lifetap/RESET-01-confirmation.png) | Full reset matrix, deletion/repeated reset; Draw editing covered in HISTORY-02 |
| HISTORY-01 / after reset | One archived two-player game | Inspect detail; open Export game; select Summary CSV | **Observed:** logs, export choices, delayed Android share UI with `lifetap-game.csv`; accidental Save to Drive selection canceled before Save | Procedural observation | Export contents/delivery and JSON unverified; no upload completed |
| HISTORY-02 / subsequent archive inspection | Archived game initially won by Player 1 | Edit Winner → Draw → Confirm; inspect Filter, Players, Profiles, Insights | **Observed:** Draw archive; both players 0W/1D/0L; one-game insight summary; profile empty state | Procedural observation | Aggregate calculations, deeper filtering, profile stats |
| LAYOUT-01 / subsequent setup exploration | Counts 2–6 at 40 | Exercise each of two offered layouts per count | **Observed:** all ten layouts, table above; no dedicated team setting in inspected controls | Procedural observation | One-player mode, physical reach, all rotation/window states |
| START-01 / four-player alternate layout | Starting life 40 | Select 20; read reset warning; Confirm | **Observed:** all four players at 20 | Procedural observation | 25/30/custom validation and complete reset field matrix |
| COMMANDER-01 / starting life 20 | Auto-KO and life-loss coupling on | Top damage cell to 21, another to 1; manually clear KO | **Observed:** damage cells 21/1/0; life −2; first cell tap deducted one life | Procedural observation | Isolated commander threshold, source mapping/corrections, partners |
| CUSTOMIZE-01 / later four-player state | Default labels/gradient | Rename; choose blue+purple; toggle OLED on/off; open card search | **Observed:** Research A label, gradient, black-mode effect, background controls | Procedural observation | Collision handling, other combinations, restart persistence |
| RANDOM-01 / later board state | Multiple seats | Randomize player; Randomize opponent → I'm Player 1 | **Observed:** flashing-seat selection and perspective step | Procedural observation | Final result capture, eliminated players, fair distribution, successful radial hold |
| ART-01 / subsequent search | Research A's player editor | Set Tymna C16; toggle Contain/Cover/Top; Set as partner Thrasios C16 | **Observed:** printing credits, layout controls, split art, paired source cells | Procedural observation | Partner damage increments, all anchors/crop, offline/failure behavior |
| PROFILE-01 / 21:57:58 capture | Research A with two artwork sources | Close/reopen editor; Load; star and expand player | **Observed:** saved entry, filled star, other-decks empty state; capacity help text | [Library](reference/lifetap/PROFILE-01-saved-partners.png) | Capacity, additional profiles, deletion, loading into another seat, restart |
| PLANE-01 / initial format customization | Planechase initially off | Enable; Customize; inspect groups; expand Anthology | **Observed:** five checked groups/counts, 0/5 saved presets, two-column card checkbox grid | Procedural observation | Catalog audit/offline; later gameplay recorded in PLANE-03 |
| PLANE-02 / subsequent customization | All five groups selected initially | Deselect Academy at Tolaria West; preview card/Back; uncheck other four groups; save Research deck | **Observed:** 85/86 and indeterminate group; saved 85-card preset, 1/5, Selected; unchanged save disabled | Procedural observation | Preset capacity/deletion, duplicate handling, shuffled contents/reset use |
| SCHEME-01 / subsequent variant exploration | Archenemy enabled | Open mode; advance schemes; flip 180; read help | **Observed:** empty Ongoing schemes area, three scheme names, rotation retained across cards | Procedural observation | Ongoing effects, full deck/reset/depletion lifecycle, custom deck |
| VARIANT-01 / concurrent enablement | Main settings | Enable Planechase, Archenemy and Bounty together | **Observed:** all three remained enabled with distinct toolbar icons | Procedural observation | Combined reset/retention and interaction behavior |
| PLANE-03 / 22:14:38 result capture | Planechase mode | Planeswalk Lair of Ashen Idol → Otaria; roll planar die; Click to Planeswalk; tap card text | **Observed:** explicit Planeswalk action; resulting Mirrored Depths; text overlay | [Plane](reference/lifetap/PLANE-03-after-planeswalk.png) | Other die outcomes, shortcuts, full deck/reset lifecycle |
| BOUNTY-01 / subsequent variant exploration | The Outsider at reward 1 | Show Wanted Card; Pass to 4 plus once; Claim; Back; attempt Flip | **Observed:** 4 ceiling, Lord Fajjal at 1, Back returned Outsider at 1 | Procedural observation | Complete deck, reset/depletion, isolated flip effect |
| MANA-01 / initial mana page | All seven values zero | Increment white/blue/Storm; black− at zero; Clear; colorless+; close/reopen | **Observed:** edits, black zero floor, immediate clear, colorless1 retained across panel reopen | Procedural observation | Other colors/limits, undo, per-player scope, restart/turn handling |

Supporting screenshots should be narrowly scoped, named by test ID, and linked here with a description of what they demonstrate. Avoid credentials, account details, unrelated Mac content, and unnecessary copyrighted artwork captures. A screenshot proves its visible state; a procedural log is still needed for gesture, reset, and persistence claims.

## QoL findings and important edge cases

These are observations and research interpretations, not requirements for Tripling Season.

- **Fast rematches need clear scope.** The explicit Reset dialog offers an optional winner/Draw and archives the game, while the tested player-count change discarded that game from the inspected archive. Two reset-shaped paths had different history outcomes.
- **Cancellation is part of the workflow.** Reset Cancel and player-count Cancel preserved the prepared state. A delayed export share handoff required special care: the accidental Drive destination was canceled before upload.
- **Correction and navigation differ.** Poison 10 caused KO, but lowering it to 9 left KO until manually cleared. Bounty Back returned to the previous card at reward 1, not its earlier reward 4. Neither interaction should be described as a complete undo.
- **Small tools have their own state.** Mana/Storm Clear applied immediately without confirmation; colorless mana survived closing its panel. Bounty reward level capped at 4. Planar-die Planeswalk exposed an explicit action before advancing the card.
- **Multiplayer context is a usability need.** Randomize opponent first asked which player was “me”; commander sources used spatial cells; partner art produced two source cells per opponent. Stable attribution after seating changes still needs verification.
- **Tabletop presentation has tradeoffs.** Seat-facing text, large totals, low-contrast zero counters, card flipping, and enlarged plane text offer useful patterns to evaluate. Emulator rotation also left settings sideways; physical iPad reach and accessible alternatives remain untested.
- **Customization can reduce setup work.** Closing and reopening the editor populated a saved named player; star and multiple-deck affordances were visible. The tested preset retained two commander images, while planar selection gave counts, indeterminate group state, and disabled unchanged saves.

## Questions and possible implications for original iPad work

The following are research questions and analytical directions, **not product decisions**. Refer proposed answers back to [03](03_life_and_game_controls.md) and the [decision register](09_decision_register.md); this file must not silently change their scope.

| Area / decision | User need to investigate | Question for Tripling Season after evidence |
|---|---|---|
| Reset clarity — **D22** | Start another game quickly without losing wanted setup or unexpectedly clearing a board. | Which named local and table actions are useful, and can each preview the precise affected players/fields? Measure the common rematch path separately from rare maintenance. |
| Life depth — **D26** | Enter ordinary and exceptional life changes with confidence and correct mistakes. | Which gestures save time, how are edits grouped, and can the current total/delta stay readable while another value is edited? |
| Damage attribution — **D26** | Record source-specific Commander information without double-subtracting life. | How should entry versus correction work, especially with partners and seat swaps? Preserve stable identities independently of layout. |
| Counters — **D26/D28** | Reach relevant values without crowding every quadrant. | Which values belong near life, in a detail panel, or in existing utilities? One authoritative value must survive multiple presentations. |
| Randomizers — **D28** | Resolve small table decisions without leaving the game. | Which dice and selection tools earn space, how is opponent context made explicit, and can results be read from all sides? |
| Timing — **D28** | Track pace without pretending to simulate the physical game. | Is a timer or simple turn marker worth its controls and persisted state? Advancing a marker must not imply untap/mana/other automation. |
| Saved setup — **D19/D34** | Resume familiar players or deck looks with little preparation. | What is a session participant versus a reusable profile, and which deletion/reset effects need explanation? |
| Recovery — **D17/D33** | Trust the table after interruption and inspect disputed changes. | Which acknowledgement and history guarantees can be demonstrated on actual iPad hardware? An advertised crash promise does not validate our storage approach. |
| Four-seat accessibility — **D05/D12** | Read and operate the tracker while seated around a tablet. | Which orientations, accessible alternative views, and touch boundaries work alongside independent token/utility lanes? Emulator results cannot settle physical reach. |

## Remaining gaps and completion criteria

Installation succeeded through official Play, and partial hands-on findings now establish selected Android defaults and workflows. The first transient Mac lock interrupted one custom-die attempt and was resolved by the user. No current installation blocker is claimed.

**Current access blocker — pending:** a subsequent native-control call to close **Mana Counter** and open settings stopped at its first **Close Mana** click. CUA returned **“The Mac is locked and automatic unlock could not unlock it”**; no new UI action was confirmed from that call, and the first click did not execute. The manual unlock request is pending again; UI exploration is paused pending that unlock. No installation approval is needed. This is an environmental access block, not a policy denial or uncertain mutation. Source/document work and the completed observations above remain usable. Do not infer that the pending settings action, app restart, or any further runtime test occurred.

Still open: hold/repeat life gestures, large changes/direct entry/undo; one-player mode and all camera/window/orientation combinations; stable commander-source attribution, independent partner damage, tax/corrections; isolated commander KO threshold; counter bounds/long-press options and cross-player marker exclusivity; randomizer final-result visibility, eliminated-player inclusion, and radial menu; full reset field matrix, new-game paths, deletion/archive retention; multiple saved profiles, capacity/deletion, and artwork cancellation/offline/all-anchor behavior; Planechase alternate die outcomes/preset capacity/deletion/reset/depletion, complete Archenemy ongoing lifecycle, Bounty custom decks/reset/depletion/isolated flip; remaining mana colors/limits/scope/undo/turn relation; eliminated-player downstream behavior; full timer workflows; deeper history filters/aggregate export, actual export content/delivery and JSON; app force-stop/reboot persistence; accessibility and physical tabletop checks. The tested life/KO, ten 2–6-player layouts, reset/history, customization/saved-player, dice/randomizer, variants, and mana paths do not close those broader workflows. Dice bounds and stable result timing remain unverified. OLED is confirmed inside the color picker; only a general sound row remains absent within the specifically traversed main-settings scope.

This checkpoint is reusable research, not a claim of exhaustive exploration. Resume the unfinished checklist after host access is restored, append meaningful outcomes and evidence, and retain the specific gap list for any inaccessible surfaces. The temporary Android Studio screenshot save directory still points to this evidence folder; restoring its prior Desktop destination is also pending host access. Emulator-visible controls alone cannot prove physical sound, haptics, reach, multi-touch behavior, or iPad accessibility.

## Product-decision reconciliation — 2026-10-21

The user subsequently accepted full life-tracker fundamentals and source-specific commander damage including self, asking that this research inform the design without directly copying Lifetap’s interface. See the [confirmed/candidate inventory](03_life_and_game_controls.md) and [D26](09_decision_register.md). The user later accepted new damage/life coupling with independent corrections, warning-only thresholds, manual shared-state changes, and persistent chronological history/latest-action undo; [history](game_history_and_undo.md) records the new product contract. This does not change any observation or testing limit above: the reference’s Auto-KO, damage/life coupling, reset defaults, optional modes and unverified partner/source behavior are not automatically this product’s requirements.
