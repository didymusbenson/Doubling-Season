# Utilities, tokens and decks

**Status:** proposed tablet workflows. Existing behavior is described in the [current-code audit](../../../../ai_docs/research/2026-10-20-ipad-edition-current-architecture.md); initial release inventory is D08.

## Utility lane contract

Each player owns one independently ordered lane containing all their supported utility instances. Internal `TrackerWidget` and `ToggleWidget` names may remain; user-facing language remains **Utilities**. Shared utility definitions do not mean shared active counts or toggles. Loading the same definition for P1 and P3 creates separate runtime identities and state.

Keep recurring actions reachable without opening full detail editors. Narrow cards may use a title, relevant value/state and one primary action, with descriptions, artwork and secondary fields revealed inline or through a local editor. Long action labels must wrap or reflow without covering the other lane. Reordering is an explicit utility-lane operation and cannot transfer the utility's owner.

## Existing utility adaptation inventory

| Utility family | Preserve | Player-scoped adaptation / open behavior |
|---|---|---|
| Generic trackers | Name/description/value/step customization | Independent values; signed versus nonnegative constraints chosen by kind |
| Generic toggles | Name, ON/OFF text, artwork | Separate state per instance/player; no ambient global toggle target |
| Life Total | Useful quick access | Central life is authoritative; avoid duplicate independent total |
| Poison / energy / radiation | Reusable counter UI/behavior where appropriate | D26 requires relevant player counters, with poison/energy/experience explicit and radiation sourced for review. Use the authoritative typed player-counter store; utility projections must not duplicate values; explain any mapping |
| Krenko, Mob Boss | Controlled Goblin count plus tracked nontoken count and existing rule behavior | Read only that player's eligible board, and create all results there |
| Krenko, Tin Street | Tracked action count and Goblin creation | Scope utility count, rules, merge and companions |
| Hare Apparent | Count-derived Rabbit plan | Scope count, preview, primary and companion outputs |
| Academy Manufactor | Existing forced-count/preset interaction and peer-result semantics | Preserve calculation without applying the same effect twice; all results local |
| Cathars' Crusade | Pending trigger tracking, resolve and direct counter action | Scoped event applicability, counters, rollback and reset; no opponent ETB accumulation |
| Rhys the Redeemed | Existing copy planner/preview behavior | Local source set and eligible merges; validate source/rules changes before commit |
| Brudiclad | Existing virtual choice/transform/Skip behavior | Local choices, transforms, sickness cleanup and undo; no global snapshot restoration |
| Mana pool | New utility direction | Specialized multi-value UI and clear semantics below |

This is an adaptation list, not a guarantee all utilities ship in release one. Record support explicitly during P4. No feature may be enabled merely because its old action button renders in a quadrant.

## Tracker overlap boundary

The accepted life tracker owns life, typed player counters, city’s blessing and recipient/source damage; monarch/day-night are shared session state. Reused utilities may project these values but cannot create divergent copies. Lifetap’s `Treasure`, `C.Tax`, Initiative and mana/storm controls are inventory evidence, not blanket commitments: review Treasure against the token lane, tax against CommanderId, initiative separately, and mana under D27. No token change automatically applies life, poison, radiation effects, commander damage, monarch transfer or day/night. See the [confirmed/candidate inventory](03_life_and_game_controls.md).

## Mana pool proposal — D27

### Purpose and basic model

Give each player a fast way to track floating mana without forcing six full tracker cards into the utility lane. Start with white, blue, black, red, green and colorless integer quantities. Generic cost is not a seventh mana type; snow describes a source/property rather than another color. Restricted mana cannot always be represented by six totals alone. [Comprehensive Rules 106.1b / 106.6 / 107.4h](https://media.wizards.com/2026/downloads/MagicCompRules%2020260925.txt).

Proposed first version: one authoritative pool per player, one utility instance that projects it, six nonnegative counters, total shown as a convenience, explicit reset, no automatic spending or payment solver. Duplicate mana utilities should link to the same pool or be rejected with an explanation; two invisible competing pools would be confusing. If independent named pools are desired, define that as a different feature.

### Interaction

- Compact view: a measured 2 × 3 or 3 × 2 arrangement with symbol, value and accessible add/remove affordances; avoid twelve tiny targets jammed into one row.
- Expanded view: direct numeric edit, ±1 and optional ±5, clear one type, clear entire pool, and a recent-change undo group.
- Decrement at zero stays zero. Overflow/invalid input preserves the previous durable value and explains the limit.
- Repeat gestures capture their player/type/direction and stop on all cancel paths, just like life.
- Pool actions live in the owning player's utility/menu area. A global reset can include pools only when its preview says so.

### Emptying and exceptions

Unspent mana normally empties at step/phase boundaries. Since the proposed edition has no phase engine, **manual clear is the safe initial control**. No timer, life edit, next-player highlight, token tap or app background event should clear it implicitly. [Rule 106.4](https://media.wizards.com/2026/downloads/MagicCompRules%2020260925.txt).

D27 must choose one release boundary:

| Option | Capability | Cost |
|---|---|---|
| Simple manual pool, proposed start | Six counters with clear/undo; clearly manual | Cannot encode restrictions/snow/source identity faithfully |
| Tagged buckets | Type + restriction/source tags + retention behavior | More complex add/spend UI and persistence |
| Full payment assistant | Select a cost, choose buckets, apply spending and special rules | Large rules surface and validation burden; separate project scope |

If tagged buckets are deferred, label the pool's limits and allow manual notes if useful. Do not claim correctness for restricted mana, snow costs, persistent unspent mana or mana conversion. The existing Mana symbol renderer may be reused for symbols, but it supplies no pool semantics.

### Token/utility integrations

Treasure editing must not automatically add mana, decrement life or pay costs. A future “Sacrifice Treasure → add chosen mana” command would need source quantity, chosen mana type, explicit target pool, any applicable rules, and one coherent undo/recovery unit. Food → life and other cross-domain conveniences have the same requirement. These integrations are proposed later work, not implied by a mana pool's existence.

## Token lane and creation

Retain core token identity, quantity, tapped/untapped state, summoning sickness, counters, P/T, emblems, copy/split, artwork, credits and rules previews. Redesign compact controls for available width rather than scaling down the phone card.

Proposed creation flow:

1. Player opens their Add action; panel title names the destination.
2. Search offers current All/Recent/Favorites/Custom content and existing filters. Library/profile preference scope is D19/D20.
3. Selection returns a definition to an owner-bound flow; quantity and artwork choice remain associated with that player.
4. Preview uses their rules and shows the complete resulting set, including companions and limits.
5. Commit once through the scoped creation boundary; apply agreed merge/insertion policy within their token lane.
6. Close only that flow's panel and show feedback locally. Do not rely on a fixed number of route pops.

Custom definition creation and “add this definition to my board” are distinct mutations. A saved definition may belong to a shared library even if board creation later fails. Tell the player what succeeded; retrying board creation must not duplicate library entries or token results.

## Copy, split, merge and transform

- **Copy** must preserve the current app's defined creation semantics, not assumptions from stale documentation. Audit current counters/status and rule behavior before extraction.
- **Split** redistributes one stack. It stays in the source player's token lane, preserves intended status/counters/artwork and does not create spurious entry triggers. Retain the current dismiss-before-mutate safety where applicable, but replace stale delayed-object assumptions with scope/revision checks.
- **Merge** is allowed only within eligible player/session scope, then existing identity/artwork/counter compatibility. Identical printed cards across players never merge automatically.
- **Transform** works on explicit local targets and preserves existing Brudiclad event/sickness semantics. In-place transformation is not a new entry event.
- **Order** defaults are D13: append new distinct search results; keep merges in place; put split/copy outputs beside source; preserve relative source order for multi-result planners. Companion order must be deterministic and documented.

A player's token controls cannot call existing unqualified provider bulk methods. Explicitly scope +1/+1 all, -1/-1 all, untap, clear sickness, copy-many, delete, replace and planner cleanup.

## Deck library and setup semantics

Current decks are reusable **setups**: save deduplicates token templates; load produces amount-zero stacks and default utility state. They are not live-game saves. Preserve that distinction in labels: “Load setup for Alex” is different from “Resume saved game.” Do not promise a deck load restores life, counters, tapped values, mana, rules or pending triggers.

Proposed player flow:

| Action | Contract |
|---|---|
| Browse library | Read shared/profile deck templates; no live board mutation |
| Load append | Instantiate into named player's two lanes; keep other players and life unchanged |
| Load replace | Preview the named player's affected content; scoped snapshot/undo; other seats continue |
| Save my setup | Capture only that player's templates, with independent token/utility ordering mapped to chosen format |
| Duplicate for another player | New runtime entity IDs and active state; template may be shared |
| Change library deck mid-game | Does not retroactively alter instantiated boards unless explicitly applied |

Converting existing mixed order to two lanes uses stable partition: keep the relative order of token templates in the token lane and of utility templates in the utility lane. Cross-type adjacency is intentionally lost. Do not invent shared fractional positions between the lanes merely to retain the old archetype.

## File interchange and art

Current phone JSON schema is v3. Proposed support: import compatible v3 setups into the tablet library, then explicitly select a player destination. Tablet-only utility/state fields require either a new version or a lossy subset export with a clear omission report. Never put session state into v3 fields older phones interpret differently.

Define whole-table save/export separately: session format, participants/identities, CommanderId/recipient ledgers including self/partners, life and typed counters/statuses, shared monarch/day-night, boards, rule states, independent orders, optional history and asset manifest. Cross-device `file://` URLs do not transfer user art. Package uploaded bytes using managed asset references or explicitly report missing media; downloaded art may remain a cacheable reference where appropriate.

Sharing, native file pickers and custom artwork selection are device-wide surfaces; queue them and return to the original player. A reset, source deletion or incompatible session change while away must reject obsolete results without assigning them to a replacement seat. Preserve artist metadata and selected art on download/cache failure.

## Full-reset token/utility contract

Reset with board retains token entries while setting counts to zero/removing counters and keeps the currently enabled utilities/widgets for each player. Complete reset clears both token entries and utilities. These restart configured gameplay, not the persistent seat name/color/art presets. Keeping a utility selection does not promise keeping every temporary runtime value; rules/default mapping remains explicit design work. Keep-board preserves reusable token custom properties for remaining seats; removed seats’ game-specific token/utility setup is cleared. Restore pre-reset historical setup from its full-state/timeline archive, not current cleared live records. Do not conflate retained board entries with immutable library templates, or use deck loading as a silent substitute reset.

## History integration

Token additions and removals retain separate chronological history entries even at net zero; compatible repeats may update the current entry until a different action by any player or a time gap closes it. Preserve underlying creation/companion/rule effects for latest-global-action undo rather than reducing everything to a display delta. Removal history supports manual trigger bookkeeping but does not prove death or authorize automated triggers. Utility/counter/shared-state changes join the same persistent game timeline. See [history](game_history_and_undo.md).

## Required behavior review before parity is claimed

For each utility/token workflow, record: all reads, every direct model write, rules snapshot, all created results, emitted events, lane allocation, route/panel owner, failure outcome, undo write set and recovery behavior. Run with two players owning identical definitions and differently configured rules. The [validation matrix](08_delivery_validation_and_risks.md) contains the corresponding scenarios; none has been executed for this edition yet.
