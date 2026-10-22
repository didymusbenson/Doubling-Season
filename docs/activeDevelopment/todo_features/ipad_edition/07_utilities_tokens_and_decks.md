# Utilities, tokens and decks

**Status:** curated per-seat utility customization, default-visible storm/mana, hold-drag ordering and confirmed corner-X hiding/restoration are accepted; remaining mechanics are proposed tablet workflows. Existing behavior is described in the [current-code audit](../../../../ai_docs/research/2026-10-20-ipad-edition-current-architecture.md); initial release inventory is D08.

## Utility lane contract

Each player owns one independently ordered lane containing all their supported utility instances. Internal `TrackerWidget` and `ToggleWidget` names may remain; user-facing language remains **Utilities**. Shared utility definitions do not mean shared active counts or toggles. Loading the same definition for P1 and P3 creates separate runtime identities and state.

Keep recurring actions reachable without opening full detail editors. Narrow cards may use a title, relevant value/state and one primary action, with descriptions, artwork and secondary fields revealed inline or through the shared player-facing workspace for detailed editing (exact per-editor mapping remains open). Long action labels must wrap or reflow without covering the other lane. Reordering is an explicit utility-lane operation and cannot transfer the utility's owner.

## Accepted curated utility customization

The app offers a curated list of useful utility kinds. Within that list each seat freely customizes visibility and order using hold-and-drag. Each visible utility has a corner X; dismissal requires a confirmation modal and hides it for the game. Restore it through the utilities menu. This is not arbitrary region resizing, an unlimited widget builder, or automatic approval of every legacy/candidate utility.

Storm counter and mana pool are default-visible utilities, not compulsory always-visible panels. Their availability/default visibility is accepted; exact storm behavior and mana mechanics still need design (D27/D37). Do not infer automated spell counting, phase handling, payment or clearing. Hiding is not deletion or zeroing: retain stored values, provide separate clear actions, and keep nonzero hidden values discoverable. The precise discoverability treatment, restored position and hidden-utility interaction with setup formats remain open.

Life and its directly attached commander-damage/player-counter shortcuts are outside this reorderable list. Utilities that project player counters or mana must use the same authoritative values. Existing reset semantics remain unchanged: keep-board retains enabled reusable setup for remaining seats, complete reset clears utilities, removed seats clear game-specific setup, and archived games restore historical setup. Default-visible provisioning at new-game/reset boundaries must be reconciled explicitly with those rules, not silently override a complete reset or restore hidden temporary values.

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
| Mana pool | Accepted default-visible, dismissible utility | Specialized multi-value UI and clear semantics below |

This is an adaptation list, not a guarantee all utilities ship in release one. Record support explicitly during P4. No feature may be enabled merely because its old action button renders in a quadrant.

## Tracker overlap boundary

The accepted life tracker owns life, typed player counters, city’s blessing and recipient/source damage; monarch/day-night are shared session state. Reused utilities may project these values but cannot create divergent copies. Lifetap’s `Treasure`, `C.Tax` and Initiative are inventory evidence, not blanket commitments: review Treasure against the token lane, tax against CommanderId and initiative separately. Mana pool and storm counter are now explicitly accepted as dismissible default-visible utilities, with detailed mechanics under D27/D37. No token change automatically applies life, poison, radiation effects, commander damage, monarch transfer or day/night. See the [confirmed/candidate inventory](03_life_and_game_controls.md).

## Mana pool — accepted utility, proposed mechanics (D27)

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

Carry over the original TS token object’s **entire functionality**, including identity, quantity, status, counters, P/T, emblems, copy/split, artwork/credits and rule-aware actions. Reuse its implementation where practical and fit it into the token lane without stripping direct controls or deliberately tight density. Adapt constraints and seat/session command plumbing; do not mandate a compact-control redesign. See the [full parity inventory](token_functional_parity.md).

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
- **Order** carries the verified D13 baseline: append new distinct search results; keep merges in place; put split/copy outputs beside source; preserve route-specific companion order. Adapt allocation to each seat/lane, not a global mixed list.

A player's token controls cannot call existing unqualified provider bulk methods. Explicitly scope +1/+1 all, -1/-1 all, untap, clear sickness, copy-many, delete, replace and planner cleanup.

## Accepted deck/preset evolution — D38

A deck evolves the existing Decks feature into a reusable token list plus utility preferences. Save that setup as a preset; a chosen seat loads it to configure its utilities and initialize its board with the selected token entries at zero/empty gameplay state. This is reusable setup, not a saved live game or archived timeline. Exact preference fields/default resolution still need schema design; do not save transient counter/mana values as setup merely because a utility is visible.

If the deck has an image, it can optionally supply the seat life tracker’s saved image. Art selection is scoped per seat: one seat’s choice must not rewrite another seat’s selected art or a shared global token-art preference. Shared definitions and cached image bytes may be reused without sharing mutable selections. Persistent seat name stays separate from deck/preset name and is not overwritten on load. Existing seat name/color/art persistence remains accepted; explicitly applying a preset image is a supported way to update that seat’s saved art, not an automatic reset of all customization. Exact image opt-in/default behavior and the no-image fallback require design.

Commander selection is not part of the accepted preset contents. Whether it should be added needs a separate decision. **Midgame Replace and Append are accepted.** Replace swaps only the loading seat’s preset-managed tokens/utilities for the preset’s zero-state setup. Append adds the preset without clearing existing items. Both touch only preset-managed fields, including loaded token-art preferences and optional deck life artwork under the prior contract; neither resets life value, commander damage, player counters, the existing timeline or unrelated state. Each is one undoable action. Loading is neither a full reset nor archive restore. Existing reset/hidden-seat/archive rules remain unchanged.

### Token-art preference lifetime — accepted D39

Token-art preferences are scoped to a seat **within the current game only**, not its persistent seat profile. Saving a deck snapshots those choices; loading it applies the saved choices only to the target seat. A fresh game does not inherit the previous game’s token-art preferences. Explicit keep-board preserves chosen artwork as reusable board configuration, not an everlasting seat preference. Archive restore recovers that historical game’s choices, not defaults for future games. Persistent player name and life-tracker color/art customization remain separate and unchanged by this clarification.

Persist current-game choices for ordinary reload/recovery without promoting them to cross-game defaults. Shared catalog/cache data may remain shared; mutable preference lookup must include game and seat context. Exact initial fallback art and custom-file retention still need technical design; midgame replace/append scope and undo are accepted.

### Existing implementation evidence, not tablet implementation

Read-only review of the repository baseline: [Deck model](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/models/deck.dart) stores token templates, tracker/toggle templates and optional customArtworkUrl. [DeckProvider loading](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/providers/deck_provider.dart#L536-L625) offers clear-and-load and add-to-board, orders mixed template kinds, and creates token Items with amount 0. Its existing providers are single-board, not proof of seat isolation. Its v3 export carries template artwork metadata but not the custom deck image as a portable asset. Reuse these concepts through the new scoped boundary; do not claim the accepted utility preferences, life-image application or seat-scoped artwork are already implemented.

### Verified existing artwork save/load behavior

Remote main was reverified at d30050bd7a1067058fcdf7e707d3a223124a79fb on 2026-10-21. [Save deduplication](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/decks_list_screen.dart#L796-L843) includes artwork URL; [TokenTemplate conversion](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/models/token_template.dart#L55-L83) snapshots/restores artworkUrl, artworkSet and artworkOptions. Deck load uses those saved fields, not a fresh global-preference lookup. Hive and JSON v3 retain this metadata; older absent fields remain null. This is a real saved selection, not merely global-default persistence.

However, custom art is a **file reference**, not a deck-owned immutable image copy. [Custom upload](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/artwork_selection_sheet.dart#L1123-L1147) uses a filename derived from token identity; replacing that file can change old decks referencing it. JSON does not package the bytes. The deck cover is separate from token selections. The new product must deliberately design asset retention/reference isolation so seat choices and archives are not accidentally changed by shared-path overwrite; this audit does not implement a fix or settle a storage strategy.

## Deck library and setup semantics

Current decks are reusable **setups**: save deduplicates token templates; load produces amount-zero stacks and default utility state. They are not live-game saves. Preserve that distinction in labels: “Load setup for Alex” is different from “Resume saved game.” Do not promise a deck load restores life, counters, tapped values, mana, rules or pending triggers.

The accepted setup-load direction above is settled. The following additional operation variants remain proposals, especially for an already active game:

| Action | Contract |
|---|---|
| Browse library | Read shared/profile deck templates; no live board mutation |
| Load append | Accepted during play: add zero-state preset entries/configured utilities to the loading seat without clearing existing items; one undoable action, unrelated values/timeline preserved |
| Load replace | Accepted during play: swap loading seat’s preset-managed tokens/utilities for zero-state setup; one undoable action, life/damage/player counters/timeline and unrelated state preserved |
| Save my setup | Capture only that player's templates, with independent token/utility ordering mapped to chosen format |
| Duplicate for another player | New runtime entity IDs and active state; template may be shared |
| Change library deck mid-game | Does not retroactively alter instantiated boards unless explicitly applied |

Converting existing mixed order to two lanes uses stable partition: keep the relative order of token templates in the token lane and of utility templates in the utility lane. Cross-type adjacency is intentionally lost. Do not invent shared fractional positions between the lanes merely to retain the old archetype.

## File interchange and art

Current phone JSON schema is v3. Proposed support: import compatible v3 setups into the tablet library, then explicitly select a player destination. Tablet-only utility/state fields require either a new version or a lossy subset export with a clear omission report. Never put session state into v3 fields older phones interpret differently.

Define whole-table save/export separately: session format, participants/identities, CommanderId/recipient ledgers including self/partners, life and typed counters/statuses, shared monarch/day-night, boards, rule states, independent orders, optional history and asset manifest. Cross-device `file://` URLs do not transfer user art. Package uploaded bytes using managed asset references or explicitly report missing media; downloaded art may remain a cacheable reference where appropriate.

Sharing, native file pickers and custom artwork selection are device-wide surfaces; finish/dismiss the current flow before a fresh next request, without queuing another player’s editor. Return results to the captured original player. A reset, source deletion or incompatible session change while away must reject obsolete results without assigning them to a replacement seat. Preserve artist metadata and selected art on download/cache failure.

## Full-reset token/utility contract

Reset with board retains token entries while setting counts to zero/removing counters and keeps the currently enabled utilities/widgets for each player. Complete reset clears both token entries and utilities. These restart configured gameplay, not the persistent seat name/color/art presets. Keeping a utility selection does not promise keeping every temporary runtime value; rules/default mapping remains explicit design work. Keep-board preserves reusable token custom properties for remaining seats; removed seats’ game-specific token/utility setup is cleared. Restore pre-reset historical setup from its full-state/timeline archive, not current cleared live records. Do not conflate retained board entries with immutable library templates, or use deck loading as a silent substitute reset.

## History integration

Token additions and removals retain separate chronological history entries even at net zero; compatible repeats may update the current entry until a different action by any player or a time gap closes it. Preserve underlying creation/companion/rule effects for latest-global-action undo rather than reducing everything to a display delta. Removal history supports manual trigger bookkeeping but does not prove death or authorize automated triggers. Utility/counter/shared-state changes join the same persistent game timeline. See [history](game_history_and_undo.md).

## Required behavior review before parity is claimed

For each utility/token workflow, record: all reads, every direct model write, rules snapshot, all created results, emitted events, lane allocation, route/panel owner, failure outcome, undo write set and recovery behavior. Run with two players owning identical definitions and differently configured rules. The [validation matrix](08_delivery_validation_and_risks.md) contains the corresponding scenarios; none has been executed for this edition yet.

## Existing-design carryover

Use the [source-backed behavior audit](existing_behavior_audit.md) for search/form cancellation, inline commit, live existing-deck rename, artwork serving and token/utility presentation. Existing snackbars, nondismissible dialogs and unsafe global/cache coupling are expressly not carryover requirements. D41 blocks all background input for any modal; closing consumes its gesture and cannot queue another editor.

## Old-design inference checkpoint

The [granular baseline map](outstanding_behavior_baselines.md) supplies concrete starting points for remaining behavior questions, including what current design cannot settle. These are explicitly inferred defaults, not additional accepted requirements; D41 and all earlier explicit decisions take precedence.

## Modifier scope checkpoint — D25

A global modifier’s recipient indicator is not a removable locally owned utility. Hiding a view cannot disable its source. Accepted preset token/utility contents do not automatically include modifier-source configuration; that mapping remains open. See [modifier ownership and applicability](modifier_ownership_and_applicability.md).

### Midgame load implementation baseline (D38)

Capture the target seat and preset revision before selection/async art work. Plan a complete load write set, commit it coherently with one history action and retain its before-state for latest-global-action undo. A load is setup initialization, not a batch of gameplay token creations/deaths; do not emit false entry/death effects from zero-state templates. Every modal blocks the table, and tapaway consumes the gesture. Async-dismissal recovery follows the established command contract, not a newly queued editor request.

**Technical inference for Append:** preserve existing instances and their selected artwork/values; initialize new instances with the preset’s saved selections and configured utilities, after existing lane order, without automatic identity merging. If a loaded preference shares a catalog identity with an existing entry, keep the existing instance’s explicit selection rather than retroactively repainting it. Store loaded-instance selection/provenance separately as needed; this is a conservative implementation starting point consistent with “not anything else,” not a new permanent seat-art lifetime. Optional deck life artwork can update saved life appearance under the accepted contract; life numeric value is untouched. The whole load’s art/preference write set participates in undo. Do not overwrite persistent player name, another seat, unrelated modifier sources or game state. Dedicated life/player-counter bindings must never become a second authority through a loaded generic utility.

## Explicit carryover clarification — 2026-10-22

Dice: d4/d6/d8/d10/d12/d20, selectable types/quantities, all individual results and sum. Mana: use audited Disa manual six-color pool/Empty/lock/convert behavior as the starting point, not a payment or phase engine. TS decklist import and same token database/update path are accepted. See [source-backed decisions and limitations](implementation_carryover_clarifications.md).

## Full token parity correction — 2026-10-22

The entire original TS token functionality, deliberate density and direct controls must carry over. Reuse the existing token implementation where practical and adapt lane constraints/seat-session integration; a new board container is not a mandate to rebuild or simplify tokens. Any parity-reducing exception requires explicit justification and approval. Review [the source-backed token inventory and acceptance method](token_functional_parity.md), not just row aesthetics or generated mockup styling. No specific runtime mismatch is claimed without implementation evidence.
