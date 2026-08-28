# Rhys the Redeemed Utility

## Card Reference

**Rhys the Redeemed** — {G/W} Legendary Creature — Elf Warrior (1/1)

- {2}{G/W}, {T}: Create a 1/1 green and white Elf Warrior creature token.
- {4}{G/W}{G/W}, {T}: For each creature token you control, create a token that's a copy of that creature.

## Overview

Add a utility for Rhys the Redeemed following the existing action tracker pattern (Krenko, Academy Manufactor). The utility's action button triggers Rhys's second ability: duplicate every creature token on the board.

## What the Utility Does

**Tracker purpose:** None — Rhys has no tracker value. He is a pure action button: tap "Copy Tokens" and it duplicates every creature token on the board. The first ability (create a 1/1 Elf Warrior) is trivial for the user to do manually.

### Layout Consideration: Action-Only Widget

The current `TrackerWidget` system assumes every utility has a counter value with +/- buttons. Rhys doesn't need any of that — just a name and an action button. This is new territory.

**Decision: Option B — Action-only layout mode.** Add a new `actionOnly` boolean field to `TrackerWidget` (`@HiveField` with `defaultValue: false`). When true, the card skips the counter display and +/- buttons entirely, rendering only the name + action button. Clean and reusable for any future action-only utilities.

### Token Duplication Logic

For every `Item` on the board that the app treats as a current creature token:
- **Eligibility heuristic:** every non-emblem `Item` with a nonempty P/T is
  eligible. In the app, assigning P/T to a normally noncreature token is how the
  user represents that it is currently animated.
- Copy the source's stored name, colors, type, abilities, and artwork identity as
  the user's intended token definition. Do not query the token database to recover
  a presumed "base" definition. Customized values are authoritative.
- **P/T copy heuristic:** if the source type line contains `Creature`
  (case-insensitive), preserve its P/T in the copy. If its type line does not
  contain `Creature`, create the copy with an empty P/T. This makes an animated
  Clue eligible while producing a normal noncreature Clue copy.
- Feed each source stack's `amount` and stored identity into
  `RulesProvider.evaluateRules()` independently. Its evaluated results determine
  final quantities, replacements, and companion tokens; do not use the removed
  legacy global multiplier.
- Copies enter untapped by default. Only an explicit, applicable policy that makes
  created tokens enter tapped may override this; the ordinary main-token creation
  flow must not implicitly force Rhys copies to enter tapped.
- Apply summoning sickness to the new copies if the setting is enabled
- Merge results into an existing compatible clean stack when possible. Only create
  a new stack adjacent to its source when no compatible stack exists.
- +1/+1 and -1/-1 counters are NOT copied (they represent modifications to the original, not the base token)
- Custom counters are NOT copied
- Power-only and toughness-only counters are NOT copied
- Never merge new copies into a stack carrying counters. A source with counters
  therefore produces or merges into a separate compatible clean stack with no
  counters.
- Subsequent activations include copies created by previous activations.
- Every created token with power/toughness fires the creature-ETB event, so it
  triggers Cathar's Crusade and any other creature-ETB listeners.

### Token Database Match

Rhys's first ability creates an Elf Warrior token already in the database:
- **Name:** Elf Warrior
- **P/T:** 1/1
- **Colors:** GW
- **Type:** Creature — Elf Warrior
- **Artwork:** Available from 2XM and SHM sets

### Rules-Correct Copy Semantics

Rhys only counts permanents that are creature tokens when the ability resolves.
What the resulting tokens look like is a separate question: copies use the
source's **copiable values**, not every characteristic the source currently has.

Example: a standard Clue token temporarily made into a creature is eligible for
Rhys. Unless the animation itself is copiable, Rhys creates a normal colorless
noncreature Clue artifact token with no P/T, not another animated Clue.

Because `Item` does not separately model current characteristics and underlying
copiable values, the implementation uses this deliberate approximation:

1. Nonempty P/T means the token is currently eligible for Rhys.
2. `Creature` in the stored type line means its P/T is part of the base identity
   and should be copied.
3. No `Creature` in the stored type line means its displayed P/T represents an
   animation and is stripped from the copy.

Known limitation: a naturally noncreature permanent with printed P/T (most notably
a Vehicle represented with its printed P/T) will be treated as animated and
eligible whenever it has P/T in the app. Likewise, the app cannot distinguish a
copiable animation effect from an ordinary temporary animation. This is accepted
as a pragmatic limitation until current state and copiable identity are modeled
separately.

For all other stored characteristics, the app intentionally trusts the user. Name,
colors, type, abilities, and artwork are copied exactly as stored, including custom
edits. The implementation does not attempt to infer whether an edit represents a
temporary game effect, and it does not perform a token-database lookup on action.

Under the game rules, ordinary continuous/type-changing effects, temporary or
set-P/T effects, counters, granted abilities, Auras/Equipment, tapped status, and
other history are not copiable. The app can enforce this for counters, tapped
status, sickness, and the documented noncreature P/T heuristic. For stored
name/colors/type/abilities, however, customized values are intentionally treated as
the user's desired copiable identity because the model has no separate temporary
state. Relevant rules exceptions include:

- A type/P/T/ability established by a copy effect is copiable.
- Characteristics defined by the effect that originally created the token are
  copiable. A token natively created as a creature Clue therefore remains one.
- Characteristic-defining abilities contained in the copied rules text are copied.
- Modifications and abilities added as part of a copy effect can be copiable.
- An ongoing global effect may independently animate or modify the newly created
  token as soon as it enters; that is the global effect applying to the new token,
  not Rhys copying the old token's temporary modification.

Rules basis (verified against French Vanilla's current Comprehensive Rules corpus):
CR 111.3 (token-defined characteristics become copiable values), CR 613.1 and
613.2a-c (copy effects/copiable values are layer 1; type, abilities, and P/T are
handled in later layers), and CR 707.2/707.9 (what copies include and exclude).
Rhys has no separate official card-specific ruling for this interaction.

## Implementation Steps

### 1. Widget Database Entry (`lib/database/widget_database.dart`)

Add a new `WidgetDefinition`:
- `id: 'rhys_the_redeemed'`
- `type: WidgetType.special`
- `name: 'Rhys the Redeemed'`
- `description:` TBD (see questions)
- `colorIdentity: 'GW'`
- `hasAction: true`
- `actionButtonText: 'Copy Tokens'`
- `actionType: 'rhys_the_redeemed'`
- `artwork:`
  - `ArtworkVariant(set: 'TLE', url: 'https://cards.scryfall.io/large/front/e/b/ebcf9ad6-5c1c-4b12-9778-2b9338bf49aa.jpg?1783904844')`
  - `ArtworkVariant(set: '2XM', url: 'https://cards.scryfall.io/large/front/b/9/b91dadcb-31e9-43b0-b425-c9311af3e9d7.jpg?1783930128')`

### 2. Action Dispatch (`lib/widgets/tracker_widget_card.dart`)

Add case to `_performAction()` switch:
```dart
case 'rhys_the_redeemed':
  _performRhysTheRedeemedAction(context);
  break;
```

### 3. Action Handler (`lib/widgets/tracker_widget_card.dart`)

Implement `_performRhysTheRedeemedAction()`:
- Read all creature tokens from `TokenProvider`
- Snapshot every eligible source stack before evaluation.
- For each source independently, call `RulesProvider.evaluateRules()` with the
  source's stored identity (using the P/T-copy heuristic above) and its full
  `amount`. Do not combine unlike source stacks before evaluation.
- Preserve structured groups mapping each source stack to its evaluated primary,
  replacement, and companion results. Reuse those exact grouped results for the
  preview and execution so they cannot diverge.
- If evaluation leaves the primary token identity unchanged, preserve the source's
  exact `artworkUrl`, `artworkSet`, and `artworkOptions`. If a replacement rule
  changes the identity, discard the source artwork and resolve artwork normally
  for the resulting token identity (preference, then database/default fallback).
  Companion tokens likewise resolve artwork from their own identities.
- Show a confirmation dialog with a per-token preview of every stack/quantity that
  will be created, including changes from active rules or multipliers
- If there are no eligible tokens, show an empty/no-tokens preview. Keep the action
  enabled and allow confirmation; confirming performs a successful no-op.
- For each previewed result, merge into a compatible clean stack when available;
  otherwise create a new stack adjacent to that result's source

### 4. Provider Method (`lib/providers/token_provider.dart`)

Add `duplicateAllCreatureTokens()` or `performRhysPopulate()`:
- Snapshot the current token list (avoid iterating over a mutating list)
- Consume the already-evaluated, source-grouped result snapshot from the dialog;
  do not recalculate rules after confirmation
- For each result, find a compatible existing stack with the same stored identity,
  no +1/+1, -1/-1, power-only, toughness-only, or custom counters, and compatible
  artwork; merge when found. Artwork compatibility requires the selected
  `artworkUrl` to match exactly (including both being null); otherwise keep the
  results in separate stacks so customized or selected artwork is never lost.
- When merging creature copies, add only the newly created quantity to the stack's
  summoning-sickness count (when enabled and the copied abilities do not include
  haste). Preserve the existing stack's tapped and sickness counts.
- When no compatible stack exists, insert a clean stack with fractional ordering
  adjacent to the relevant source
- Initialize every copy with `tapped: 0` unless an explicit applicable enters-tapped
  policy overrides it
- Apply summoning sickness after insert (existing two-step pattern)
- Fire creature-ETB events for every created token with power/toughness so Cathar's
  Crusade receives the full created quantity

## Clarifying Questions

### Behavior
1. ~~**Does the multiplier apply?**~~ **Resolved:** The removed legacy multiplier is
   not used. Evaluate each source stack independently through
   `RulesProvider.evaluateRules()` with `quantity: source.amount`; active rules
   determine the final primary, replacement, and companion results.
2. ~~**Should the tracker value be used for anything?**~~ **Resolved:** No tracker value — Rhys is action-only.
3. ~~**Action-only layout**~~ **Resolved:** Option B — new `actionOnly` HiveField on TrackerWidget with `defaultValue: false`.
4. ~~**Confirmation dialog?**~~ **Resolved:** Always show a confirmation dialog using the same evaluated results that execution will consume. Preview each token and quantity. With no eligible tokens, preview no tokens and allow a confirmed no-op; do not disable the action button.

### Copying Details
5. ~~**Tapped state**~~ **Resolved:** Copies enter untapped regardless of the source's tapped state. An explicit applicable enters-tapped policy may override this, but the ordinary main-token creation flow does not.
6. ~~**Existing copies**~~ **Resolved:** Every activation snapshots all currently eligible creature tokens, including copies made by prior Rhys activations. There is no deduplication across activations.
7. ~~**Representing current creature status vs. copiable identity**~~ **Resolved
   with an app-level heuristic:** nonempty P/T determines Rhys eligibility. Preserve
   P/T in the copy only when the source type line contains `Creature`; otherwise
   strip P/T from the copy. The Vehicle and copiable-animation edge cases described
   above are accepted limitations.
8. **Utility widgets on board** — TrackerWidgets and ToggleWidgets on the board are not creature tokens. Confirm these are naturally excluded (they should be, since we'd iterate `TokenProvider.items` only).

### UI
9. ~~**Button count**~~ **Resolved:** No +/- buttons. Action button only — just "Copy Tokens".
10. ~~**Action button disabled state**~~ **Resolved:** Never disable it based on board contents. With no eligible tokens, the confirmation dialog previews no tokens and confirming does nothing.

### Trigger Integration

11. ~~**Cathar's Crusade**~~ **Resolved:** Rhys-created tokens with power/toughness must fire the existing creature-ETB event and trigger Cathar's Crusade. The event count must equal the number of creatures actually created after active rules are evaluated.

12. ~~**Customized token characteristics**~~ **Resolved:** Treat stored name,
    colors, type, abilities, and artwork as authoritative and copy them without a
    token-database lookup. P/T alone uses the documented Creature-type heuristic.

13. ~~**Rules evaluation grouping**~~ **Resolved:** Evaluate every eligible source
    stack independently and preserve a source-to-results mapping through preview
    and execution.

14. ~~**Merging**~~ **Resolved:** Merge into compatible counter-free stacks when
    possible. New creature quantities receive summoning sickness when applicable;
    preexisting quantities retain their existing tapped/sickness state. Matching
    token characteristics are not enough: `artworkUrl` must also match exactly.

15. ~~**Artwork after replacement rules**~~ **Resolved:** An unchanged Rhys copy
    preserves the source artwork. A rule that replaces the token also replaces its
    visual identity: discard the source artwork and use normal artwork resolution
    for the resulting token. For example, Food replaced by Treasure creates a
    normal Treasure with Treasure artwork, never a Treasure displaying Food art.
    Companion tokens use their own normally resolved artwork as well.

---

## Implementation Status

**Implemented** — branch `codex/rhys-update-1-11`. Pending manual acceptance
testing for the 1.11 release.

### Files changed

| File | Change |
|------|--------|
| `lib/models/tracker_widget.dart` | New `actionOnly` field — `@HiveField(17, defaultValue: false)` |
| `lib/models/tracker_widget_template.dart` | New `actionOnly` field — `@HiveField(14, defaultValue: false)`, so the flag survives deck save/load |
| `lib/models/widget_definition.dart` | New `actionOnly` field, forwarded by `toTrackerWidget()` |
| `lib/database/widget_database.dart` | New `rhys_the_redeemed` definition (TLE + 2XM artwork) |
| `lib/services/rhys_copy_planner.dart` | **New** — builds the source-grouped, artwork-resolved activation plan |
| `lib/providers/token_provider.dart` | New `performRhysPopulate()`, counter/artwork-safe merging, and unified-board fractional placement |
| `lib/providers/deck_provider.dart` | Preserves `actionOnly` through duplication and schema-v3 export/import |
| `lib/screens/deck_detail_screen.dart` | Preserves `actionOnly` when adding Rhys through the deck editor |
| `lib/widgets/tracker_widget_card.dart` | Action-only layout, `rhys_the_redeemed` dispatch, `_performRhysTheRedeemedAction()` |
| `lib/screens/expanded_widget_screen.dart` | Help text reflects action-only utilities |

### How the pieces fit

`RhysCopyPlanner.build()` snapshots the board, applies the eligibility and
P/T-copy heuristics, evaluates **each source stack independently** through
`RulesProvider.evaluateRules()`, and resolves artwork for every result. The
resulting `RhysCopyPlan` is immutable and preserves the source → results
mapping.

That one plan object is what the confirmation dialog renders **and** what
`TokenProvider.performRhysPopulate()` consumes. Nothing is recalculated after
confirmation, so the preview and the board cannot diverge.

Artwork is resolved at plan time, not execution time: an unchanged primary
result carries the source's exact `artworkUrl`/`artworkSet`/`artworkOptions`;
a replaced identity and every companion resolve normally
(preference → database default).

### Acceptance test checklist

- [ ] Add Rhys from the utility picker — card shows name, description, and a
      full-width **Copy Tokens** button with no counter and no +/− buttons
- [ ] Empty board → dialog previews nothing; confirming is a clean no-op
- [ ] Two Soldier stacks (3 and 2) → preview lists both; board ends at 10 total
- [ ] Source stack with +1/+1 counters → copies land in a separate clean stack,
      never merged into the countered one
- [ ] Source with custom artwork → the copy keeps that exact artwork
- [ ] Animated Clue (P/T set on an `Artifact — Clue`) → eligible, and the copy
      is a plain Clue with no P/T
- [ ] Emblem on the board → ignored
- [ ] Doubling Season active → preview and board both show doubled quantities
- [ ] Food → Treasure replacement rule → copy is a Treasure with Treasure art
- [ ] Cathar's Crusade on the board → its counter rises by the number of
      creatures actually created
- [ ] Summoning sickness on: only the newly created quantity is sick; an
      existing merged stack keeps its tapped/sick counts
- [ ] Copies always enter untapped, even from a fully tapped source
- [ ] Second activation copies the tokens the first activation made
- [ ] Save a deck containing Rhys, load it → still renders action-only
- [ ] Duplicate, export/import, and add Rhys through the deck editor → still
      renders action-only
- [ ] Put a tracker or toggle immediately after a source token → new stacks stay
      between the source and that utility with no order collision
- [ ] Arrange negative/positive fractional orders around zero → copies remain
      adjacent instead of moving to the board's end
