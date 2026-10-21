# Life tracker and game controls

**Status:** D26 accepts a full life-tracker foundation: life totals, relevant player counters (explicitly energy/poison/experience), player statuses including city’s blessing, monarch ownership, shared game-level day/night, and commander damage by source including self. New damage/life coupling with independent corrections, warning-only thresholds and manual monarch/day-night changes are accepted. Two full-reset modes and persistent seat customization are now accepted below; reusable setup retention, removed-seat game-data clearing and restorable pre-reset archives are accepted; exact runtime/rule defaults, restore conflict handling and UI remain open; [persistent chronological history and global latest-action undo](game_history_and_undo.md) are required. No implementation is claimed.

## Dedicated life state

The centerpiece is a projection of each player's life state, not four ordinary tracker utilities. Current Tripling Season offers a generic Life Total utility; it does not supply the proposed session model. Avoid two authoritative life totals if that utility is loaded from a deck. Proposed behavior is to offer a linked life shortcut or omit the duplicate with an explanation; never silently add its default value to the central total.

Each life panel should show player name, current life, accessible increase/decrease controls, a recent delta, and an entry point for player counters/history. Keep the current total readable while editing counters. Artwork and decorative backgrounds are optional and must not compromise the most important number.

## Core life operations

| Operation | Proposed behavior | Persistence / interaction contract |
|---|---|---|
| Tap ± | Apply one signed increment to that player | Serialize increments; no lost updates from two fingers |
| Hold ± | Repeat with an explicitly measured delay/rate; preview accumulated delta | Bind player/direction at start; cancel on every interruption path |
| Large change | Enter signed delta or use ±5/±10 controls in a player-facing editor; compact versus shared workspace mapping remains open | Distinguish “change by” from “set to” in labels |
| Set total | Direct signed-integer entry | Show old → new; do not interpret entered 20 as +20 |
| Undo latest game action | Walk backward through the game-wide chronological history; a settled group is one unit | Revert its complete write set, not an arbitrary selected player entry; preserve unaffected state |
| Game history | One chronological timeline with player attribution, repeated-like-action grouping and latest-action undo | Current-session history/state persist together; any player’s different action closes the group; pre-reset archive restore is required, with exact retention/UI open |
| Reset this life total | Restore configured starting life | Explicit local operation; no token, mana or opponent changes |

Proposed numeric representation is a signed integer with defined storage/export bounds. Life must permit zero and negative values. Choose input/display caps deliberately rather than inheriting the token-quantity limit. Do not parse decimals, exponent notation, malformed signs or locale separators ambiguously; preserve the draft and explain invalid input.

Rapid life taps in either direction settle as one net adjustment roughly 1–2 seconds after tapping stops. Immediate display feedback is a recommendation, not a settled rendering/commit-timing choice. See [history grouping](game_history_and_undo.md). Grouping is a UI/history concept, not permission to keep acknowledged changes only in memory until release. If repeats are acknowledged before durable storage, expose that pending state and define the crash-loss window. Prefer durable incremental commands with a shared history-group ID, or a bounded flush design measured under load. Never wait solely for a background lifecycle callback to save the game.

## Starting-life presets and status

Proposed setup presets: Commander 40, ordinary casual 20, and a custom value. Commander starts at 40; ordinary loss thresholds include life at or below zero, ten poison, and 21 combat damage from one commander. The accepted behavior is **warning indicators only**, since the tracker does not model exceptions or all game rules. [Comprehensive Rules, 903.7, 704.5a/c, 903.10a](https://media.wizards.com/2026/downloads/MagicCompRules%2020260925.txt).

Do not automatically eliminate a player, disable controls, clear their board or declare a winner at a threshold. Proposed state is manually controlled active/eliminated, with an optional “check player status” prompt. Losing a game can involve more than the values being tracked. Negative life remains editable to represent corrections and relevant effects.

## Commander damage: required capability, proposed detailed interaction

Commander damage is required, including damage from a player’s own commander. A single “commander damage taken” scalar is inadequate. Record damage by **recipient player ID and stable commander identity**. Two commanders belonging to one player must remain distinguishable. Commander identities survive seat moves and label changes; a displayed name is not their key. Independent commanders and commander tax are supported by the official rules. [Rules 702.124d / 903.8](https://media.wizards.com/2026/downloads/MagicCompRules%2020260925.txt).

Proposed interaction:

1. Recipient opens their commander-damage panel.
2. Select source commander from named commander slots **including the recipient’s own commander(s)**; show source owner, recipient and commander label distinctly. Never filter the selector to opponents only.
3. Enter combat damage amount.
4. **Accepted:** entering new commander damage also subtracts life. Provide distinct corrections to either value independently; correction must not silently repeat the coupled effect.
5. Commit new damage and its life delta as **one command and undo unit** in the chronological game history. Exact correction affordances remain open, not the coupled-entry policy.

Never subtract life again merely because a recorded commander-damage value is corrected. An edit must distinguish correcting the ledger from applying new damage. Partner commanders, commander changes during setup, and damage from a commander temporarily controlled by someone else require stable source identity. If control-transfer gameplay is outside the release, allow manual source selection without claiming to model the permanent's location.

A source is a stable `CommanderId` associated with its owning `PlayerId`, not that PlayerId itself, a seat, a name or a damage recipient. Each recipient’s ledger includes self-source entries, and partner sources remain distinct even with matching labels/artwork. Reseating, renaming or temporarily changed control must not rekey the ledger. Commander replacement after setup and retained historical source records need explicit policies.

Commander cast count / calculated tax is a reference-derived candidate, not automatically settled by source-specific damage support. If included it is per commander, not per recipient or generic player scalar. Exact availability/placement remains D26. At four players with two commanders each, each recipient may need eight source entries **including their own two**: up to 32 recipient/source pairs, not six opponent-only rows or one count per player. This is a capacity fixture, not a requirement to display every row permanently.

## Functional inventory and approval boundary

The user requested the relevant life-tracker fundamentals, not a life-only minimum and not a direct copy of Lifetap’s interface. The [Lifetap research](lifetap_research.md) is the source inventory; its observations describe that app, not acceptance results for this product. “All relevant counters” is an accepted category; the examples are not a closed whitelist. Complete the inventory during design rather than asking the user to repeat the documented basics.

| Capability / source evidence | This product’s status | Scope and remaining decisions |
|---|---|---|
| Life totals; tap/delta and negative totals observed in research “Life adjustment, player panel, and counters” | **Confirmed** | Per player. Detailed gestures, presets, bounds, history grouping and direct-entry UX remain design choices. |
| Energy, poison, experience (`Exp`) numeric controls observed in COUNTER-01 | **Explicitly confirmed examples** of relevant player counters | Typed values per player; visibility/defaults, bounds and correction controls remain open. Do not confuse poison with an automated infect calculation. |
| Radiation (`Rad`) observed in COUNTER-01 | **Sourced candidate** within the confirmed relevant-counter category | Carry into the inventory for suitability/default review, not silently omit it; no automated milling, life loss or turn effects implied. |
| City’s blessing (reference label `Ascend`) observed as a status control | **Explicitly confirmed** | Independent player status, not a numerical counter or exclusive holder. UI naming/placement and manual correction behavior remain open. |
| Monarch observed as status control; reference exclusivity was not tested | **Explicitly confirmed ownership tracking** | One authoritative table-level holder reference, projected into player views; never independent conflicting booleans. Transfer/correction history and elimination handling need explicit UX. |
| Day/night control observed adding a central sun indicator | **Explicitly confirmed game-level state** | One shared designation with an initial neither state; no per-player copies and no automatic spell/turn inference. Placement/transition controls remain open. |
| Source damage and life coupling observed; `me` cell visible; two partner cells observed but independent partner edits untested | **Confirmed per-source damage including self** | Stable recipient/source identities, distinct partner sources. New damage subtracts life as one undoable action; independent corrections are required; thresholds warn without automatic elimination. Detailed UI remains open. Our required support exceeds the reference’s verified source/partner behavior. |
| Initiative observed as a status control | **Reference-derived candidate**, not an explicit named commitment | Decide whether a simple holder tracker belongs in the relevant-status set. Does not authorize dungeon/Undercity implementation or automatic venture. |
| `C.Tax` increment observed; partner configuration observed | **Reference-derived candidate** | If selected, use per-commander cast/tax state; exact tax UX/automation and inclusion still need decisions. |
| `Treasure` increment observed | **Reference-derived candidate / overlap review** | A reference numeric convenience is not proof that Treasure is a player counter. Prefer existing token-lane truth or an explicitly defined projection; do not add a divergent duplicate count. |
| Custom named counters | **Prior design candidate**, not observed in the reference inventory | Decide extensibility, type identifiers, names and bounds; do not promise arbitrary automation. |
| `K.O.` and Auto-KO observed (including poison decrement not reviving) | **Warning-only policy accepted**, Auto-KO not adopted | Life/poison/commander thresholds warn without eliminating players or disabling controls. Manual elimination UI remains a separate choice. |
| Mana/storm page observed; randomizers/dice and timer modes researched | **Mana/storm now accepted separately from D26** | Mana pool and storm counter are default-visible but dismissible utilities (D27/D37). Detailed mechanics remain open; timers/randomizers are not blanket commitments. |
| Saved players/partner artwork, reset/history/export flows researched | **Supporting candidates with separate policies** | Identity, setup, history, persistence and export inform D17/D19/D20/D22/D23/D33/D34. No account, analytics or full profile/statistics system is implied. |
| Planechase, Archenemy, Bounty, teams and other advertised modes | **Not approved by this tracker-depth decision** | Reference inventory is not a commitment to optional modes or interface parity. |

### State ownership and manual operation

Choose one authoritative location per player counter. A utility may project it but must not maintain an unsynchronized duplicate. Counter-on-player changes must not automatically pass through existing token-counter multipliers. City’s blessing belongs to each player independently; monarch belongs to the table with an optional stable holder `PlayerId`; day/night belongs to the game. Distinguish a player’s local change from an intentional shared-state command regardless of which seat opens the controls.

Official rules rechecked on 2026-10-21 through the [Wizards rules page](https://magic.wizards.com/en/rules), which links the [2026-09-25 rules](https://media.wizards.com/2026/downloads/MagicCompRules%2020260925.txt): monarch is exclusive and initially absent (725.1/725.3); city’s blessing can belong to multiple players (702.131); day/night is game-wide and starts neither (731.1); partner damage is separate (702.124d), and the commander-damage rule is source-specific (903.10a). These support data distinctions, not automatic game enforcement. Wizards also explicitly discusses [damage from one’s own commander](https://magic.wizards.com/en/news/feature/commander-masters-release-notes).

Monarch is claimed manually by a player, explicitly transferring the shared holder; day/night is manually set, without inferring combat or spells cast. Manual changes record origin/context, meaningful player attribution when available, affected target/scope, before/after and operation identity. Game-level actions do not invent a player actor from their control location. A monarch transfer changes one shared holder atomically; undo must not restore a stale holder over a later transfer. Day/night correction changes only the shared designation. Blessing/counter corrections are local and cannot clear another player’s state. Exact correction UI and remaining runtime/rule, archive-retention and restore-conflict details remain open. History is persistent and game-wide chronological; undo walks the latest action globally, with any player’s different action closing the group; exact timeout, archive retention/UI and restore conflict policies still open in [D16/D17/D33](09_decision_register.md).

No automatic Food sacrifice → life gain, lifelink, poison from infect, mana burn, death, or combat damage is implied by editing tokens. A future action combining domains must state every effect and commit them together. Manual tools must remain correct when players resolve the physical game themselves.

## Game lifecycle

Proposed states: setup → active → ended, with a recoverable active session after restart. A restorable pre-reset game archive is now accepted. Every modal blocks the whole table under D41. Nonmodal command-in-flight safety is a technical recovery concern, not an open permission for background interaction through modals; no turn/priority simulation is implied.

Setup contains participants, seats, starting-life configuration, commander-source configuration when relevant, and optional selected deck templates. Initialize the accepted counters/status/shared-state model explicitly; defaults and optional visibility do not erase the stored identity of a value. Starting creates a session generation and initial durable state. A rematch can preserve seating/configuration while creating a new game identity or generation; pre-reset archives are restorable under D33, with browsing UI and retention limits still to design.

The user’s “player” is a **persistent seat**, retaining its player name and color/art presets between games. A two-player game hides seats 3 and 4 rather than deleting them; a later four-player game restores their prior customization. Distinguish this persistent seat identity from its visual slot/orientation and game-local mutable state. Exact internal ID names and participant lifecycle remain proposals. Moving a seat’s presentation must not reassign its customization or history. A separate settings hard reset can clear customization; normal game resets cannot. Eliminating a participant preserves history and commander references; whether their area collapses, stays visible, or is locked is D21. Do not infer the complete multiplayer leave-game rules from a single “eliminated” flag.

## Reset vocabulary and matrix

### Accepted full-reset modes

A full reset starts the game over using the specified player count and game configuration. It is not merely a board wipe. Both modes restore starting life and clear temporary damage/counters and game-status state, including commander damage, monarch and other applicable statuses. Detailed per-field initialization should be explicit rather than inferred from a generic utility default.

| Mode | Token boards | Enabled utilities/widgets | Life and game state | Persistent seats |
|---|---|---|---|---|
| **Reset with board** | Keep token board entries; set counts to zero and remove counters | Keep each player’s currently enabled utilities/widgets | Starting life; temporary damage/counters and monarch/other statuses reset | Keep name and color/art presets; unused seats hidden, not deleted |
| **Complete reset** | Clear token board entries | Clear utilities/widgets | Starting life and reset game-state baseline | Keep name and color/art presets; this is not the settings hard reset |

“Keep utilities” confirms the enabled utility/widget selection, not retention of every runtime value. Field-by-field defaults/rule settings and how temporary utility values reset still need explicit design. Reusable token custom properties are retained by keep-board; temporary values are not retained merely because the entry survives.

**Accepted follow-up:**
- Reset with board retains reusable token setup/custom properties (for example name, artwork, abilities and base P/T) while zeroing counts and clearing counters/temporary gameplay state, so the same decks need not be set up again. Precise runtime-field/default mapping still needs implementation review.
- A fully new game clears game-specific tokens/utilities by default unless the user explicitly chooses keep-board. Seats removed from the next game lose their game-specific tokens/utilities **even if remaining seats use keep-board**. Their persistent name/color/art survives; bringing a removed seat back must not resurrect its old live board from a template.
- Preserve a restorable archive of the full game state and chronological timeline immediately before reset. Loading it restores that historical game’s seat-specific setup and state, not the newly cleared live token/utility setup. Archive browsing/selection UI and retention limits still need design.

**Proposed safeguard, not accepted yet:** preserve the current game before loading an archive. Exact conflict handling between historical seat customization and current persistent presets also remains open. Archive restoration is a separate workflow from latest-action undo inside a game; do not imply unrestricted cross-game undo.

Normal game resets do not erase persistent seat customization. The separate settings hard-reset scope/confirmation and any other retained setup fields still need design. Detailed reset previews and destructive confirmation safeguards remain; quicker three-player control access is not one-tap permission to discard state.

### Other action vocabulary remains proposed

The following vocabulary is retained for discussion, not a replacement for the two accepted full-reset modes:

| Command | Location / recipients | Tokens | Utilities | Rules | Life / counters | Seating / library |
|---|---|---|---|---|---|---|
| Clear selected seat tokens | Central game control / target UI open | Delete selected player's stacks | Keep | Keep unless explicitly chosen | Keep | Keep |
| Reset selected seat utilities | Central game control / target UI open | Keep | Reset documented values; keep definitions/order | Explicit choice, default keep | Keep central values | Keep |
| Reset selected seat board | Central game control / target UI open | Preview clear or reset-to-setup | Preview reset/clear | Separate named option | Keep by default | Keep |
| Reset selected seat life | Game-level reset context / target UI open | Keep | Keep | Keep | Starting life; other counters only if named | Keep |
| Clear table tokens | Game menu / explicit all/current players | Clear recipients | Keep, except explicitly coupled derived state | Keep by default | Keep | Keep |
| Full reset (two accepted modes above) | Game menu / configured participants; removed seats’ game-specific boards cleared | Keep zeroed/no-counter entries or clear, by mode | Keep enabled selection or clear, by mode | Exact rules/settings retention pending | Starting life; temporary damage/counters and game statuses reset; pre-reset full-state/timeline archive restore accepted | Preserve persistent seat name/color/art; hide unused seats |
| New game/setup | Game menu / configured session | Follow chosen full-reset mode | Follow chosen mode | Explicit configuration | Defined new-game baseline | Reuse persistent seats; do not delete hidden customization |
| Erase app data | Device/settings maintenance | Separate maintenance operation | Separate | Separate | Separate | Never disguised as a game reset |

The two full-reset modes are accepted. Other matrix rows are a recommended vocabulary, not required release buttons. D22 now also settles removed-seat board clearing and pre-reset archive restore; exact runtime/rule field mappings, archive retention/UI and restore safeguards remain open. Do not inherit Lifetap reset behavior or assume a local life/board reset clears shared designations. A generic “board wipe” from the current app cannot be reused without declaring recipients and rules/utility effects.

## Game-level operation contract and open interaction policy

**Accepted:** history access, wipes and resets default to app/game context. Affected seats are targets, not automatically actors. Seat-context actions such as token search and seat customization keep their seat context. These are not strict human permissions or segregated touch zones.

**Safety design requirements:** define the affected write set, take a coherent recovery checkpoint where needed, reject duplicate/stale mutations, and preserve the accepted full-reset/archive and latest-global-undo semantics. Report success only according to the chosen durability contract; recover failures without mixed state. Read-only viewing of history is not a gameplay mutation.

**Settled by D41:** every modal blocks the entire table and tapaway dismisses without click-through. Existing non-dismissible Undo/Accept must not be copied unchanged. Unconfirmed cancellation makes no requested mutation; dismissal after a completed command does not undo it. Wipe targets and exact impact/confirmation presentation still need design; transaction safety is separate from UI blocking.

## Preset art does not imply gameplay reset

D38 permits a saved deck/preset image to supply the chosen seat’s saved life-tracker image. This explicit art application coexists with persistent seat customization and leaves player name separate. Loading the accepted token/utility setup does not decide whether a midgame load resets life or changes history; those policies remain open. It does not select commanders or invoke full-reset/archive behavior by implication.

**Token-art lifetime clarification (D39):** fresh games discard previous-game seat token-art preferences; keep-board retains chosen artwork as part of reusable board setup, and archive restore recovers historical selections. This does not clear persistent player names or saved life-tracker appearance. Deck load explicitly applies saved token-art choices to the chosen seat; exact midgame life/history effects remain open.

## Fixed life shortcuts versus utilities

Life is an individual corner-region item (opposite corners for two players). Directly attached below it, quick shortcuts open commander damage and player counters. Neither those shortcuts nor life participates in utility hold-drag order or corner-X hiding. A separate shared-controls panel fits in/around life: a central strip/panel between paired seats for three/four players, and a thin shortcut divider between the two boards for two players (D07). Three-player empty-slot expanded controls remain available alongside it. This does not change D36 app/game origin or approve one-player scope.

## Game-control placement and candidates

Required direction: game-level reset controls. In the accepted three-player arrangement, setup selects any empty one of the four seat slots for expanded, quicker game-control access; the user names dice and complete resets as examples. The control slot is not a player. This augments game-control access, not reset authority: keep explicit affected-scope preview, confirmation and recovery/undo semantics; do not turn a prominent reset control into a one-tap destructive shortcut. D22 now includes two accepted full-reset modes; pending details above must be resolved without silently changing their scope.

Proposed additions for discussion: start/new game, seating/setup, table settings, last-game summary. Dice implementation/options and the exact control inventory remain D28. Monarch and day/night are now confirmed shared tracking capabilities. Initiative, coin, starting-player selection, timer and turn indicator remain candidates, not approved merely because reference icons exist. Exact placement outside three-player mode and control orientation/dimensions still need layout review.

If a turn indicator is added, changing it must not silently untap, clear sickness, or empty mana across all players. “Next player” and “apply beginning-of-turn housekeeping” are different actions. Exceptions, extra turns, skipped turns and manual corrections must be possible before any such automation is marketed.

## Old-design inference checkpoint

The [granular baseline map](outstanding_behavior_baselines.md) supplies concrete starting points for remaining behavior questions, including what current design cannot settle. These are explicitly inferred defaults, not additional accepted requirements; D41 and all earlier explicit decisions take precedence.
