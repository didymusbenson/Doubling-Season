# Life tracker and game controls

**Status:** proposed functional specification. Central life and central game controls are confirmed; feature depth and defaults remain open (D22/D26).

## Dedicated life state

The centerpiece is a projection of each player's life state, not four ordinary tracker utilities. Current Tripling Season offers a generic Life Total utility; it does not supply the proposed session model. Avoid two authoritative life totals if that utility is loaded from a deck. Proposed behavior is to offer a linked life shortcut or omit the duplicate with an explanation; never silently add its default value to the central total.

Each life panel should show player name, current life, accessible increase/decrease controls, a recent delta, and an entry point for player counters/history. Keep the current total readable while editing counters. Artwork and decorative backgrounds are optional and must not compromise the most important number.

## Core life operations

| Operation | Proposed behavior | Persistence / interaction contract |
|---|---|---|
| Tap ± | Apply one signed increment to that player | Serialize increments; no lost updates from two fingers |
| Hold ± | Repeat with an explicitly measured delay/rate; preview accumulated delta | Bind player/direction at start; cancel on every interruption path |
| Large change | Enter signed delta or use ±5/±10 controls in a local panel | Distinguish “change by” from “set to” in labels |
| Set total | Direct signed-integer entry | Show old → new; do not interpret entered 20 as +20 |
| Undo recent change | Reverse one completed gesture/edit group | Revert only its write set; preserve other players and later unrelated events |
| Local history | Show recent before/after/delta and source labels | Bounded retention and durable history policy are D17 |
| Reset this life total | Restore configured starting life | Explicit local operation; no token, mana or opponent changes |

Proposed numeric representation is a signed integer with defined storage/export bounds. Life must permit zero and negative values. Choose input/display caps deliberately rather than inheriting the token-quantity limit. Do not parse decimals, exponent notation, malformed signs or locale separators ambiguously; preserve the draft and explain invalid input.

Gesture grouping is a UI/history concept, not permission to keep acknowledged changes only in memory until release. If repeats are acknowledged before durable storage, expose that pending state and define the crash-loss window. Prefer durable incremental commands with a shared history-group ID, or a bounded flush design measured under load. Never wait solely for a background lifecycle callback to save the game.

## Starting-life presets and status

Proposed setup presets: Commander 40, ordinary casual 20, and a custom value. Commander starts at 40; ordinary loss thresholds include life at or below zero, ten poison, and 21 combat damage from one commander. These should be **advisory indicators**, since the tracker does not model exceptions or all game rules. [Comprehensive Rules, 903.7, 704.5a/c, 903.10a](https://media.wizards.com/2026/downloads/MagicCompRules%2020260925.txt).

Do not automatically delete a player, clear their board or declare a winner at a threshold. Proposed state is manually controlled active/eliminated, with an optional “check player status” prompt. Losing a game can involve more than the values being tracked. Negative life remains editable to represent corrections and relevant effects.

## Commander damage: candidate detailed design

If included, a single “commander damage taken” scalar is inadequate. Record damage by **recipient player ID and stable commander identity**. Two commanders belonging to one player must remain distinguishable. Commander identities survive seat moves and label changes; a displayed name is not their key. Independent commanders and commander tax are supported by the official rules. [Rules 702.124d / 903.8](https://media.wizards.com/2026/downloads/MagicCompRules%2020260925.txt).

Proposed interaction:

1. Recipient opens their commander-damage panel.
2. Select source commander from named commander slots; show its owner label separately from current seat.
3. Enter combat damage amount.
4. Choose “also subtract life” or “record only,” with a persistent, explicit default if approved.
5. Commit damage and optional life delta as **one command and undo unit**.

Never subtract life again merely because a recorded commander-damage value is corrected. An edit must distinguish correcting the ledger from applying new damage. Partner commanders, commander changes during setup, and damage from a commander temporarily controlled by someone else require stable source identity. If control-transfer gameplay is outside the release, allow manual source selection without claiming to model the permanent's location.

Commander cast count / calculated tax is a separate per-commander utility or life-detail field. It must not be tied to the damage recipient. Decide whether to display it in the centerpiece, utility lane, or neither in D26. A four-player table with two commanders each creates enough source rows that a secondary panel is preferable to eight tiny center buttons.

## Player counters and shared markers

Proposed player-detail counters: poison, energy, experience, radiation, and optionally custom counters. Choose one authoritative location per value. A utility may project a value from that store, but must not maintain an unsynchronized duplicate. Counter-on-player mutations must not automatically pass through existing token-counter multipliers; applicability differs.

Shared markers such as monarch or initiative need a single table-level holder if implemented. Do not represent four independent “I am monarch” booleans and hope they remain consistent. Holders refer to stable player IDs; changing holder is an explicit multi-player command with one history record. These are optional D28 features, not part of the initial life requirement.

No automatic Food sacrifice → life gain, lifelink, poison from infect, mana burn, death, or combat damage is implied by editing tokens. A future action combining domains must state every effect and commit them together. Manual tools must remain correct when players resolve the physical game themselves.

## Game lifecycle

Proposed states: setup → active → ended/archived, with a recoverable active session after restart. “Paused” may describe blocked input during global operations; do not invent a turn/priority simulation merely to pause a tracker.

Setup contains participants, seats, starting-life configuration, optional commanders and optional selected deck templates. Starting creates a session generation and initial durable state. A rematch can preserve seating/configuration while creating a new game identity or generation; D17 decides whether previous games remain browsable.

Seat swap changes presentation only. Replacing a participant creates a new player identity and requires an explicit choice about the old board. Eliminating a participant preserves history and commander references; whether their area collapses, stays visible, or is locked is D21. Do not infer the complete multiplayer leave-game rules from a single “eliminated” flag.

## Reset vocabulary and matrix

“Reset” is too ambiguous for a final label. Proposed named commands:

| Command | Location / recipients | Tokens | Utilities | Rules | Life / counters | Seating / library |
|---|---|---|---|---|---|---|
| Clear my tokens | Player menu / one player | Delete selected player's stacks | Keep | Keep unless explicitly chosen | Keep | Keep |
| Reset my utilities | Player menu / one player | Keep | Reset documented values; keep definitions/order | Explicit choice, default keep | Keep central values | Keep |
| Reset my board | Player menu / one player | Preview clear or reset-to-setup | Preview reset/clear | Separate named option | Keep by default | Keep |
| Reset my life | Life detail / one player | Keep | Keep | Keep | Starting life; other counters only if named | Keep |
| Clear table tokens | Game menu / explicit all/current players | Clear recipients | Keep, except explicitly coupled derived state | Keep by default | Keep | Keep |
| Restart game | Game menu / entire session | Clear or reload chosen setup | Reset/reload chosen setup | Reset or restore setup, explicitly selected | Reset life/counters/damage/history according to preview | Keep participants/seats; library stays |
| New table | Game menu / new session | Fresh | Fresh | Fresh | Fresh | New participants/setup; shared library stays |
| Erase app data | Device/settings maintenance | Separate maintenance operation | Separate | Separate | Separate | Never disguised as a game reset |

This matrix is a recommended vocabulary, not seven required release buttons. D22 chooses the minimum useful actions and exact effects. A generic “board wipe” from the current app cannot be reused without declaring recipients and rules/utility effects.

## Global operation protocol

1. Open a center panel with a plain-language effect preview naming the participants and values affected.
2. Resolve active editors and pending native flows. Cancel repeated gestures. Reject duplicate submissions.
3. Acquire the table barrier; drain or invalidate pending commands under a documented policy.
4. Capture a coherent session checkpoint including life, both lanes, derived utility state, rule configuration, and order domains being changed.
5. Commit a recoverable operation. Only report success once its required state is durable.
6. Invalidate old callbacks with a new generation. If undo is allowed, hold the global barrier through the explicit Undo / Accept completion, or use conflict-aware history instead.
7. Release the barrier after the resulting state is coherent. A failed operation restores/reconciles the captured scope and reports what was recovered.

The existing non-dismissible destructive completion pattern is a useful starting point: Undo left, primary Accept right, system Back blocked while unresolved. Adapt player operations to a local barrier so other seats can continue. Root-level completion must be reserved for true table operations.

## Candidate center controls

Required direction: game-level reset controls. Proposed additions for discussion: start/new game, seating/setup, table settings, last-game summary. Dice/coin, starting-player selection, timer, turn indicator, and shared markers are D28; none is required just because the reference tracker includes icons.

If a turn indicator is added, changing it must not silently untap, clear sickness, or empty mana across all players. “Next player” and “apply beginning-of-turn housekeeping” are different actions. Exceptions, extra turns, skipped turns and manual corrections must be possible before any such automation is marketed.
