# Brudiclad, Telchor Engineer Utility

**Status:** Implemented on `codex/rhys-update-1-11`; simulator build passes.
Pending manual acceptance testing.

## Card Reference

**Brudiclad, Telchor Engineer** — {4}{U}{R} Legendary Artifact Creature — Phyrexian Artificer (4/4)

> Creature tokens you control have haste.
>
> At the beginning of combat on your turn, create a 2/1 blue Phyrexian Myr
> artifact creature token. Then you may choose a token you control. If you do,
> each other token you control becomes a copy of that token.

Oracle text verified against Scryfall across all 10 printings (C18, PZ2, 2XM,
BRC, MUL ×4, M3C, SOC) — text, mana cost, type line, and P/T are identical on
every one. Note for anyone working from memory: this card is **not** a Vedalken,
is **not** {3}{U}{R}, and the token it makes is a **Phyrexian** Myr.

### Official Rulings

Unlike Rhys, Brudiclad has six official rulings, and they settle most of the
design questions outright. Retrieved from Scryfall's rulings endpoint.

1. *(2018-07-13)* "All other tokens you control become a copy of the chosen
   token, **even those that aren't of the same type**. For example, if you
   control a Treasure artifact token and choose the Myr token Brudiclad just
   created, your Treasure will become a copy of the Myr."
2. *(2018-07-13)* "Brudiclad copies **only the values defined as the original
   token was created** (unless that token is copying something else). It doesn't
   copy whether that token is tapped or untapped, whether it has **any counters**
   on it or any Auras and Equipment attached to it, or any **non-copy effects**
   that have changed its power, toughness, types, color, or so on."
3. *(2018-07-13)* "The last effect of Brudiclad's triggered ability affects all
   tokens you control other than the chosen token, **including the token that was
   just created** if that isn't the chosen token."
4. *(2018-07-13)* "If the chosen token is copying something else (for example, if
   the chosen token was previously affected by Brudiclad's triggered ability),
   then your tokens become copies of **whatever the chosen token copied**."
5. *(2018-07-13)* "The effect of Brudiclad's triggered ability **lasts
   indefinitely**. It continues to apply after Brudiclad leaves the game."
6. *(2023-04-14)* "Once a creature token that came under your control this turn
   has legally attacked, causing it to lose haste by removing Brudiclad from the
   battlefield won't cause that token to stop attacking."

Rulings 1 and 2 are the two most commonly misplayed points and are the backbone
of this spec.

## Overview

Add a Brudiclad utility following the established commander-utility pattern
(Krenko, Academy Manufactor, Hare Apparent, Rhys). It reuses the `TrackerWidget`
model with an `actionType` string — no new model, no new Hive type ID.

Brudiclad is the first utility whose action **mutates existing stacks in place**
rather than creating new ones. Rhys reads the board and adds to it; Brudiclad
rewrites it. Nearly every requirement below follows from that one fact, and it is
why the execution path, the event behavior, and the rules-engine involvement all
differ from Rhys even though the copy *semantics* are shared.

## What the Utility Does

Resolves Brudiclad's beginning-of-combat trigger in two steps:

1. **Create** a 2/1 blue Phyrexian Myr artifact creature token.
2. **Optionally choose** a token you control; every *other* token you control
   becomes a copy of it.

The static haste ability is a separate concern — see
[Haste Integration](#haste-integration).

### Layout Consideration: Action-Only Widget

Brudiclad has no tracker value. Use the existing `actionOnly: true` mode added
for Rhys (`lib/widgets/tracker_widget_card.dart:212`) — no counter, no +/−
buttons, one intrinsic-width action button.

**Recommended:** a single button, **`Resolve Trigger`**, running both steps in
one flow. This matches the card — it is one trigger, and per ruling 3 the choice
happens after the Myr exists, so the Myr must be a candidate. The picker carries
a **Skip** affordance for the "you may" clause.

Rejected alternative: two buttons (`Make Myr` / `Copy Tokens`). `actionOnly`
renders exactly one button today, so this needs a layout change, and it lets the
user resolve the steps out of order or skip the Myr entirely — which the card
does not permit. See Q1.

### Step 1: Create the Myr

Ordinary token creation, and the **only** part of the trigger that creates
anything. It goes through the rules engine like every other creation path, so
Doubling Season and friends apply:

```dart
final myrParts = GameConstants.phyrexianMyrCompositeId.split('|');
final results = rulesProvider.evaluateRules(
  myrParts[0], myrParts[1], myrParts[2], myrParts[3], myrParts[4], 1,
);
```

- The complete rules-engine result list is created via
  `TokenCreationService.createAllFromResults()` — the shared service Academy
  Manufactor uses. Multipliers, replacement results, and companion tokens are
  all peers in the preview and eventual commit; do not assume the primary result
  is still a Myr after replacement effects.
- Insertion order: end of the unified board (`maxOrder.floor() + 1.0`), matching
  the Academy Manufactor pattern. The Myr has no source stack to sit beside.
- Fires creature-ETB events for every creature in the evaluated creation result
  list. Ordinarily this is only the Myr; replacement or companion rules may
  produce other creature results. Step 2 never fires ETB (see Step 2).
- Summoning sickness may be assigned normally during creation, then is cleared
  from every creature-token stack after successful trigger resolution because
  pressing **Resolve Trigger** affirmatively represents Brudiclad being present.
  See [Haste Integration](#haste-integration).
- Quantity capped by the engine at `GameConstants.maxTokenQuantity`.

**Prerequisite — ETB does not fire when the service merges.** The Myr merges into
an existing clean Phyrexian Myr stack when one is present, and
`TokenCreationService`'s merge branches do **not** fire
`GameEvents.notifyCreatureEntered()`. Both `createCompanionTokens()` (~line 60)
and `createAllFromResults()` (~line 181) increment `amount` and `save()` and stop;
only their new-stack branches fire the event, indirectly via `insertItem()`.

Every merge path in `TokenProvider` does fire it explicitly — `addTokens()`
(line 183), `copyToken()` (538), Krenko (671), and `performRhysPopulate()` (806) —
so the service is the odd one out, and the app's clear convention is that tokens
joining an existing stack have entered the battlefield and must fire ETB.

**Existing impact, independent of Brudiclad:** any *companion* creature token that
merges into an existing stack is already missing its Cathar's Crusade trigger
today. This has gone unnoticed because Academy Manufactor — the only current
`createAllFromResults()` caller — makes Food/Clue/Treasure, which have no P/T and
so would not tick Cathar's Crusade either way. Companion tokens created from
`new_token_sheet`, `token_search_screen`, `token_card`, Krenko, and Hare Apparent
all route through `createCompanionTokens()` and *can* be creatures.

Brudiclad's Myr is a 2/1 creature token that merges, so it would hit this
directly: **make the Myr, land it on an existing Myr stack, and Cathar's Crusade
silently misses it.**

Fix in `token_creation_service.dart` before building this utility. Both service
methods must use the same clean-stack compatibility rules as Rhys:

- exact token identity
- no +1/+1, -1/-1, power-only, toughness-only, or custom counters
- exact `artworkUrl` match, including both being null

After a successful creature merge, emit the event just as `addTokens()` does:

```dart
if (existingStack.hasPowerToughness) {
  GameEvents.instance.notifyCreatureEntered(existingStack, result.quantity);
}
```

This is a shipped-behavior change beyond Brudiclad's scope, so implement it as a
focused prerequisite commit, with companion-token ETB and merge-compatibility
regression coverage. See Q10.

### Step 2: The Copy Transformation

**No tokens are created.** Existing stacks are rewritten in place.

The mental model: **the user picks one token definition from the board, and
every stack on the board flattens to become that definition.** Whatever can then
merge, merges; anything carrying unique modifiers stays as its own stack.

**The user chooses a token *definition and visual identity*, not a stack.** The
picker lists the distinct copiable identities present on the board, deduplicated
by base characteristics plus `artworkUrl`. Three Soldier stacks with the same
art contribute one `Soldier 1/1` row; a Soldier stack using different art is a
separate row. Artwork is user-selected identity throughout the app, so silently
choosing one of several variants would be lossy and surprising.

This is not a UI shortcut — it is what the rules mean here. The player chooses
one token and everything else becomes a copy of its *copiable values*, so two
stacks sharing a definition produce an identical end state no matter which is
picked. Presenting them as separate choices would be a distinction without a
difference.

**Every stack flattens** — every `Item` that is:
- not an emblem (`!item.isEmblem`) — emblems are not tokens
- has `amount > 0`

There is no "chosen stack" to exclude. A stack already matching the chosen
definition flattens to itself, which is a no-op. This is simpler than excluding
one stack and exactly equivalent, because the only thing the card excludes is the
one stack containing the single chosen token — and every other token in that same
stack becomes a copy of it anyway, with no visible effect.

Per ruling 1 this is **every token, not just creature tokens.** Treasures, Clues,
Food, and Blood all flatten too. This is the single biggest divergence from Rhys
and the most commonly misplayed part of the card.

**Definitions are base identities.** A stack of Soldiers bearing +1/+1 counters
contributes the definition `Soldier 1/1`, not `Soldier 2/2` — counters are not
copiable (CR 707.2). This is why a definition list is also the clearer UI: the
user picks the thing that actually gets copied, so the "I chose a 2/2 and got a
1/1" surprise never arises.

The evaluated creation results are included in the virtual board used by the
picker. The freshly created Myr is therefore available when the rules engine
still produces it (ruling 3). If a replacement effect replaces it, the picker
shows the actual replacement result instead of inventing a Myr; companion
results are likewise included.

The ability says "choose," not "target." It does not target, so no
shroud/hexproof/protection filtering applies — the picker lists everything.

### Copiable Values, Not Current State

What the other tokens become is the chosen token's **copiable values** (CR 707.2,
CR 111.3), not everything it currently looks like.

**Copied from the chosen definition:**

| Field | Note |
|---|---|
| `name` | verbatim |
| `pt` | subject to the animated-noncreature heuristic below |
| `colors` | verbatim |
| `type` | verbatim |
| `abilities` | verbatim |
| `artworkUrl` / `artworkSet` / `artworkOptions` | verbatim — a copy shares the chosen token's visual identity |

**NOT copied — and preserved on each transformed stack:**

| Field | Why |
|---|---|
| `plusOneCounters` / `minusOneCounters` | Counters are not copiable (CR 707.2; ruling 2). They stay on the permanents that have them. |
| `plusOnePowerCounters` / `plusOneToughnessCounters` | Same. |
| `counters` (custom) | Same. |
| `tapped` | Status is not a characteristic (CR 110.5a) and is not copied (CR 707.2; ruling 2). Becoming a copy does not untap. |
| `summoningSick` | Continuity of control is unchanged (CR 302.6), so sickness carries over as-is. |
| `amount` | Stack size does not change — nothing is created or destroyed. |
| `order` | Transformation is in place; stacks do not move. |

**Critical consequence.** Definitions must be derived from **base** identity. If
the board's only Soldiers are a stack of 1/1 Soldiers bearing +1/+1 counters
(displayed 2/2), the definition is `Soldier 1/1` and everything flattens to a
**1/1**, not a 2/2 — the counter is not part of what gets copied. Meanwhile a
flattened stack that had its *own* +1/+1 counter keeps it and displays 2/2 under
the new identity. Building the picker from displayed P/T instead of base P/T is
the most likely implementation bug in the feature.

**Animated-noncreature heuristic.** Reuse the rule Rhys already uses. If the
chosen definition's type line contains `Creature`, its P/T is copiable and is copied.
If not, the P/T represents a temporary animation and copies get an empty P/T — an
animated Clue is a legal choice, and everything else becomes a plain,
non-animated Clue.

This is not an app-specific fudge; it is what CR 707.2 requires, and the rule's
own example is the exact shape:

> Chimeric Staff is an artifact that reads "{X}: This artifact becomes an X/X
> Construct artifact creature until end of turn." … After a Staff has become a
> 5/5 Construct artifact creature, a Clone enters the battlefield as a copy of
> it. **The Clone is an artifact, not a 5/5 Construct artifact creature.**

Ruling 2 says the same thing in card-specific terms: non-copy effects that
changed power, toughness, types, or color are not copied.

Implementation-wise this is `RhysCopyPlanner.copiedPtFor()` verbatim. **Extract
it** to a shared `TokenCopySemantics` helper and have Rhys call the shared
version, rather than duplicating the heuristic in two planners.

**Transitive copies (ruling 4)** need no special handling. Once a stack has been
transformed, its stored identity *is* the copied identity — the app has no
"originally was" memory. Choosing an already-transformed stack therefore copies
what it copied, which is exactly what CR 707.3 specifies. This falls out of the
model for free; worth a comment so nobody "fixes" it later.

**Indefinite duration (ruling 5)** likewise falls out. The app persists the
rewritten identity to Hive; there is no expiry to model.

### Merge Semantics

After transformation many stacks share one identity, so they should collapse.
Merging follows the existing rules in `TokenProvider._findRhysMergeTarget()`
(`lib/providers/token_provider.dart:870`), with one deliberate relaxation.

**Merge two transformed stacks when:**
- identity matches exactly (guaranteed post-transform), **and**
- both carry **no counters of any kind** — `plusOneCounters`,
  `minusOneCounters`, `plusOnePowerCounters`, `plusOneToughnessCounters`, and
  `counters` all zero/empty, **and**
- `artworkUrl` matches (guaranteed post-transform because artwork is part of the
  chosen picker identity and every transformed stack receives it)

**No-op stacks still merge.** A stack is a true no-op only when both its base
characteristics and `artworkUrl` already match the chosen picker identity. It
may skip the identity write, but remains a full merge participant. Three clean
matching Soldier stacks end as one stack of 9. A characteristic match with
different artwork is not a no-op and must receive the chosen artwork.

**On merge:** `amount`, `tapped`, and `summoningSick` all **sum**. After the full
trigger resolves, clear `summoningSick` on every stack whose resulting identity
has P/T; Brudiclad is necessarily present when the user invokes the ability and
therefore grants those creature tokens haste.

Summing before the final clear preserves a coherent intermediate state and lets
Undo restore the exact pre-trigger counts. Rhys merges a batch of brand-new untapped tokens
into an existing stack, so it only ever adds to `amount` and `summoningSick` and
never touches `tapped`. Brudiclad merges two pre-existing stacks that may each be
partially tapped, and tapped status must survive (ruling 2). `Item.tapped` and
`Item.summoningSick` are per-stack **counts**, not booleans, so summing is
well-defined. `Item`'s `amount` setter already clamps `tapped` and
`summoningSick` down if they would exceed the new amount, so assign `amount`
first and the invariant holds.

**Never merge a stack carrying counters.** Its counters apply to the specific
permanents in it; folding clean tokens in would silently grant them counters they
do not have. A board with three countered stacks ends with three separate
countered stacks plus one clean merged stack, all sharing the chosen identity.

**Anchor:** the **lowest-`order` clean stack** after flattening. It keeps its
`order` and its Hive key; every other clean stack folds into it and is deleted
via `tokenProvider.deleteItem()`. Because the choice is a definition rather than
a stack, there is no "chosen stack" competing to be the anchor — the rule is one
line with no special case. The merged stack lands at the topmost board position
that already held a clean stack, which keeps the board from reshuffling.

### No ETB, No Replacement Effects

Two hard requirements:

1. **Transformed tokens must NOT fire `GameEvents.notifyCreatureEntered()`.**
   Nothing enters the battlefield — the permanents were already there. Cathar's
   Crusade must **not** tick for them. Only the Step 1 Myr fires ETB.
2. **The rules engine must NOT be consulted for the transformation.** Doubling
   Season and every replacement rule apply to token *creation*; "becomes a copy"
   creates nothing. Calling `evaluateRules()` on the transformation would
   multiply the board every combat — a catastrophic and very plausible bug.
   `evaluateRules()` is called **once**, for the Myr.

Testable invariant: **board token total after = board token total before + the
sum of every evaluated Step 1 creation result.** Step 2 changes identities and
stack grouping, never the token total.

### Relationship to Rhys

The two share copy *semantics* (the copiable-values rules, the animated-
noncreature heuristic, the counter-merge restriction) and should share code for
them. They differ in mechanics:

| | Rhys | Brudiclad |
|---|---|---|
| Operation | creates new stacks | rewrites existing stacks in place |
| Scope | creature tokens only | **all** tokens, creature or not |
| User input | none | picks a target token |
| Rules engine | per source stack | once, for the Myr only |
| Doubling Season | doubles everything | doubles the Myr only |
| Cathar's Crusade | ticks per created token | ticks for the Myr only |
| Counters | not copied; copies are clean | preserved in place on each stack |
| Tapped | copies enter untapped | preserved |
| Summoning sickness | new copies are sick | preserved through copying/merge, then cleared from creatures by Brudiclad's haste |
| Board total | grows | unchanged (+ the Myr) |
| Stack ordering | new stacks placed adjacent to source | unchanged; stacks stay put |
| Reversibility | additive | destructive — prior identities are gone |

### Token Database Match

The Myr is already in the bundled database (948 tokens):

- **Name:** Phyrexian Myr
- **P/T:** 2/1
- **Colors:** U
- **Type:** Artifact Creature — Phyrexian Myr
- **Abilities:** (none)
- **Composite ID:** `Phyrexian Myr|2/1|U|Artifact Creature — Phyrexian Myr|`

Add alongside the existing Food/Treasure/Clue IDs in `lib/utils/constants.dart`:

```dart
static const String phyrexianMyrCompositeId =
    'Phyrexian Myr|2/1|U|Artifact Creature — Phyrexian Myr|';
```

Artwork available from BRC (default), M3C, MUL, and SOC. The database entry
already lists `Brudiclad, Telchor Engineer` in its `reverse_related` field. A
colorless **1/1** Phyrexian Myr also exists in the database (from Phyrexian
Rebirth) — do **not** match it.

## Rules Basis

Verified against the current Comprehensive Rules text. Copying lives in **rule
707**, not 706 (706 is dice rolling) — worth stating because older references and
memory both tend to say 706.

- **CR 111.3** — "The spell or ability that creates a token may define the values
  of any number of characteristics for the token… they define the token's
  copiable values. A token doesn't have any characteristics not defined by the
  spell or ability that created it." This is why a token's created-at
  characteristics are what Brudiclad hands out.
- **CR 707.2** — "The copiable values are the values derived from the text
  printed on the object (that text being name, mana cost, color indicator, card
  type, subtype, supertype, rules text, power, toughness, and/or loyalty), as
  modified by other copy effects… **Other effects (including type-changing and
  text-changing effects), status, counters, and stickers are not copied.**"
  This single sentence is the authority for the counters, tapped, and animated-
  noncreature requirements above.
- **CR 707.3** — "The copy's copiable values become the copied information…
  Objects that copy the object will use the new copiable values." This is the
  transitive-copy case (ruling 4).
- **CR 613.2a** — "Layer 1a: Copiable effects are applied. This includes copy
  effects (see rule 707)." Copy effects resolve before type-changing and P/T
  effects in later layers, which is why a temporary animation never rides along.
- **CR 110.5 / 110.5a** — status categories are tapped/untapped, flipped,
  face up/down, phased; "Status is not a characteristic." Confirms tapped is
  outside the copy.
- **CR 302.6** — the summoning-sickness rule is about *continuous control*, which
  becoming a copy does not interrupt. A token that has been under your control
  since the turn began stays able to attack; a freshly made one does not become
  able to attack merely by being transformed.

No rules exception applies here that would let counters, Auras/Equipment, or
tapped status ride along — ruling 2 states all three exclusions explicitly.

## Known Limitations

Carried over from the Rhys spec, plus two specific to Brudiclad. All are
deliberate approximations, not defects to fix in this feature.

1. **No separation of current state from copiable values.** `Item` stores one
   identity per stack. CR 707.2 excludes type-changing and text-changing effects
   from the copy, but the app cannot tell a user's deliberate customization from
   a temporary game effect. As with Rhys, stored name/colors/type/abilities are
   trusted as the user's intended copiable identity. The P/T heuristic is the one
   place the app *does* enforce the rule, because the type line gives it a signal.
2. **Vehicles and other printed-P/T noncreatures.** A permanent represented with
   printed P/T but no `Creature` in its type line is treated as animated, so
   choosing it copies an empty P/T. Same known limitation Rhys documents.
3. **The picker chooses a definition, not a single token.** Rules-wise the
   player chooses one specific token. Because every token sharing a definition
   yields the same copiable values, and a stack is never internally
   heterogeneous, choosing "the definition" is equivalent for every case the app
   can represent. The only thing an individual choice would additionally
   determine is board position, which the anchor rule settles deterministically.
4. **Auras and Equipment are not modeled**, so ruling 2's exclusion of attached
   permanents is moot.
5. **No persistent "originally was" memory.** Once the user accepts the
   post-merge modal, each stack's prior identity is gone. This makes transitive
   copying (ruling 4) automatically correct. The reusable undo snapshot provides
   one immediate rollback opportunity and is discarded on Accept.

## Trigger Integration

The app does not track turns, phases, or priority, so nothing fires this
automatically; it is a manual button like every other utility. Notes on how it
meets the systems that do exist:

- **Cathar's Crusade utility** — listens on `GameEvents`. It must see exactly one
  ETB batch (the Myr) per activation and nothing from the transformation.
- **Rules calculator / Doubling Season** — participates once, in Step 1. The
  transformation is invisible to it.
- **Academy Manufactor** — if a Food/Clue/Treasure replacement rule is active it
  applies to the Myr only if the Myr matched that rule's trigger, which it does
  not. No interaction expected; worth an explicit test since the Myr is an
  artifact creature token.
- **Trackers and toggles** — never transformed, never listed in the picker. They
  are not `Item`s and are not tokens.
- **Board wipe / clear sickness / untap all** — unaffected; transformed stacks
  are ordinary `Item`s afterward.
- **Repeat activations** — fully supported. The second activation sees the first
  activation's results, which is both rules-correct and the normal play pattern.

## Implementation Steps

### 1. Widget Database Entry (`lib/database/widget_database.dart`)

```dart
WidgetDefinition(
  id: 'brudiclad_telchor_engineer',
  type: WidgetType.special,
  name: 'Brudiclad, Telchor Engineer',
  description: 'Make a Myr, then copy a token across the board',
  colorIdentity: 'UR',
  defaultValue: 0,          // Action-only — no tracker value
  hasAction: true,
  actionButtonText: 'Resolve Trigger',
  actionType: 'brudiclad_telchor_engineer',
  actionOnly: true,
  artwork: [
    ArtworkVariant(set: '2XM', url: 'https://cards.scryfall.io/large/front/2/5/25eff27a-eb58-4a95-b2df-4a341cf9bef6.jpg?1783930137'),
    ArtworkVariant(set: 'C18', url: 'https://cards.scryfall.io/large/front/c/8/c8f6fd4d-7761-482c-a641-97eab1553e6a.jpg?1783934329'),
  ],
)
```

2XM first for consistency with Rhys's preferred set; C18 is the original
printing. M3C, BRC, and four MUL variants are available if a third is wanted.
`colorIdentity: 'UR'` — confirm `ColorUtils.gradientForColors()` handles the
two-color string; Rhys's `'GW'` is the only existing multicolor utility.

### 2. Action Dispatch (`lib/widgets/tracker_widget_card.dart`)

Add to the `_performAction()` switch (near line 528):

```dart
case 'brudiclad_telchor_engineer':
  _performBrudicladAction(context);
  break;
```

### 3. Shared Copy Semantics (`lib/services/token_copy_semantics.dart`)

Extract from `RhysCopyPlanner` so both utilities share one implementation:

```dart
/// P/T the copy should be created with, per CR 707.2 — a temporary animation
/// is not copiable, so a noncreature type line yields an empty P/T.
static String copiablePtFor(Item item);

/// A token Brudiclad can transform or choose: any non-emblem stack with
/// tokens in it. Rhys additionally requires a nonempty P/T.
static bool isToken(Item item);
static bool isCreatureToken(Item item);
```

Update `RhysCopyPlanner` to call these; its behavior must not change.

### 4. Planner Service (`lib/services/brudiclad_transform_planner.dart`)

Mirror `RhysCopyPlanner`'s *design* — a complete immutable plan built up front so
the preview and the board mutation read one snapshot and cannot diverge.

```dart
/// A distinct copiable identity present on the board — one picker row.
class BrudicladTokenDefinition {
  final String name, pt, colors, type, abilities;
  final String? artworkUrl, artworkSet;
  final List<ArtworkVariant>? artworkOptions;

  /// Every stack currently matching this definition, for the "×N" count.
  final List<Item> sourceStacks;

  String get compositeId => '$name|$pt|$colors|$type|$abilities';
  String get pickerId => '$compositeId|${artworkUrl ?? ''}';
  int get totalTokens;
}

/// One stack that will be rewritten.
class BrudicladTransformTarget {
  final Item source;
  final bool willMerge;      // clean → folds into the anchor
  final bool keepsCounters;  // countered → stays separate
  final bool isNoOp;         // already matches the chosen definition
}

class BrudicladTransformPlan {
  final BrudicladTokenDefinition chosen;
  final List<BrudicladTransformTarget> targets;
  final Item? mergeAnchor;

  int get affectedStacks;   // excludes no-ops
  int get affectedTokens;
  int get separateStacks;   // countered stacks staying on their own
}
```

Two entry points:

```dart
/// Distinct definitions on the board, deduplicated by base identity plus
/// artworkUrl and built from BASE identities (counters excluded), for the picker.
static List<BrudicladTokenDefinition> definitionsOnBoard(List<Item> items);

static BrudicladTransformPlan build({
  required List<Item> items,
  required BrudicladTokenDefinition chosen,
});
```

`build` deliberately takes **no** `RulesProvider` and **no** `TokenDatabase`,
because neither is consulted. Comment that omission so a later refactor doesn't
helpfully wire the rules engine back in.

The picker key extends the normal composite ID with `artworkUrl`. The base portion
remains `name|pt|colors|type|abilities`, with `pt` already passed through
`copiablePtFor()`. An animated Clue and plain Clue using the same art collapse to
one row; otherwise-identical tokens with different user-selected art remain
separate choices.

### 5. Picker + Resolution UI

The flow is preview-first and atomic: no Hive mutation occurs until Skip or the
picker's **Resolve** action. This is required so Cancel at any pre-commit
stage can truthfully leave the board untouched, even when Step 1 would merge
into an existing stack or fire ETB listeners.

**Stage A — creation preview.** Evaluate Step 1 without committing it and reuse
the Academy Manufactor dialog shape to show the complete result list (`2×
Phyrexian Myr` under Doubling Season, or any replacement/companion results).
Cancel exits with no mutation. Skip this stage only when the engine returns
exactly one unchanged Myr — it would add a tap conveying nothing (Q5).

**Stage B — definition picker.** Build a virtual post-creation board from the
current board plus the evaluated Step 1 results, without inserting or merging
anything yet. Show a `showModalBottomSheet` list of its distinct token
definitions from `definitionsOnBoard()`:

- full-width artwork definition cards matching the established deckbuilding
  menu presentation, with name/rules text in `BackgroundText` and base P/T in
  the trailing badge
- `×N` total tokens across every stack matching that definition, so the user sees
  `Soldier 1/1 ×7` rather than three separate Soldier rows
- **no counter badges** — definitions are base identities, so there is nothing
  counter-related to disclose at pick time
- Step 1 results sorted first and visually marked; ordinarily this is the
  just-created Myr, but replacement and companion results must be represented
  exactly as evaluated
- a **Skip** action for the "you may" clause; skipping is a clean, successful
  no-op for Step 2 that commits the evaluated Step 1 results
- empty state when the Myr is the only token: "Nothing else to copy."

The selector uses explicit select-then-resolve behavior:

- no definition is selected by default; the user must make an affirmative choice
- tapping a row marks it active with a persistent primary-color highlight,
  outline, and check indicator
- tapping another row moves the active selection; tapping the active row does
  not silently deselect it
- a primary **Resolve** button remains disabled until a definition is active
- **Cancel** closes the flow with no changes
- **Skip** commits Step 1 and declines the optional copy transformation
- **Resolve** builds the immutable plan against the virtual snapshot and performs
  the complete action immediately; selecting a row alone never mutates the board

#### Shared Definition Preview Card

Do not build a Brudiclad-only token row. Extract the existing visual and artwork
handling from `DeckDetailScreen._buildItemWithArtwork()` into a reusable widget,
for example `lib/widgets/definition_preview_card.dart`, then refactor the deck
detail screen to use it before wiring it into Brudiclad.

The shared widget owns:

- full-width cached/local artwork background
- `ArtworkManager.getCachedArtworkFile()` loading
- `ArtworkManager.getCropPercentages()` and `CroppedArtworkWidget` rendering
- rounded clipping and the existing color-identity gradient border
- `BackgroundText` treatment for name and subtitle
- optional trailing base-P/T badge
- optional leading icon for existing tracker/toggle deck rows
- optional selected state and tap callback

Suggested interface:

```dart
DefinitionPreviewCard(
  artworkUrl: definition.artworkUrl,
  colorIdentity: definition.colors,
  name: definition.name,
  subtitle: definition.abilities,
  trailing: definition.pt.isNotEmpty ? definition.pt : null,
  selected: definition.pickerId == selectedPickerId,
  onTap: () => selectDefinition(definition),
)
```

Deckbuilding passes `selected: false` during ordinary display and preserves its
existing checkbox/leading-icon affordances through optional slots. Brudiclad
uses the same card with selection enabled. The active state adds a teal surface
tint/outline and check indicator without replacing the token's color-identity
border. Keep those selection decorations outside the artwork/text renderer so
deck cards remain visually unchanged.

The shared card displays cached artwork; its parent remains responsible for
pre-caching. `DeckDetailScreen` keeps its existing pre-cache behavior. The
Brudiclad sheet pre-caches artwork for virtual Step 1 results and any definition
whose selected URL is not already cached, then rebuilds when downloads complete.

When a row is active, show only a compact impact summary in the selector:

> **4 stacks (11 tokens)** become copies of **Phyrexian Myr 2/1**
> 2 stacks with counters stay separate
> Tapped status and counters are preserved

Do not show a complete before/after board. The compact summary provides the
useful consequence without duplicating the board UI or introducing a second
confirmation step.

On **Resolve**, capture a reusable unified-board undo snapshot, commit all Step 1
creation results, then apply the transformation. Present one completion modal:

> **Tokens Modified**
> **Undo** / **Accept**

**Accept** discards the snapshot. **Undo** restores the complete pre-trigger
unified board, including token identities, amounts, counters, tapped/sick counts,
artwork, order, stacks removed by merging, Step 1 creations, and utility state
changed by resulting events (notably Cathar's Crusade counters). Restoration must
use silent/batched persistence and must not fire ETB or board-wipe events. This
undo facility should be board-operation infrastructure rather than
Brudiclad-specific logic so board wipe and other destructive actions can adopt
it later.

**Skip** commits only the evaluated Step 1 creation results, clears sickness
from all creature-token stacks, and does not show the Tokens Modified modal.
**Cancel** before commit changes nothing.

### 6. Provider Method (`lib/providers/token_provider.dart`)

```dart
Future<int> performBrudicladTransform(BrudicladTransformPlan plan) async
```

Returns the number of tokens transformed. Follows `performRhysPopulate`'s
error-handling shape exactly — `HiveError` catch, `_errorMessage`, `rethrow`,
one `notifyListeners()` at the end.

**Write discipline.** `Item` auto-saves on the `colors`, `type`, and `amount`
setters, but `name`, `pt`, `abilities`, and the three artwork fields are plain
fields with no save. A naive rewrite fires three redundant Hive writes per stack.
Add a batched mutator to `Item`:

```dart
/// Rewrites this stack's copiable identity in one write. Counters, tapped
/// status, summoning sickness, amount, and order are deliberately untouched.
void becomeCopyOf(Item source, {required String copiedPt}) { ... }
```

Assign the private backing fields (`_colors`, `_type`) directly and call `save()`
exactly once — mirroring the `updateArtwork()` batching convention in CLAUDE.md.

**Execution order:**

1. Rewrite identity on every target stack via `becomeCopyOf()`.
2. Fold clean stacks into the anchor, summing `amount` / `tapped` /
   `summoningSick` (set `amount` first so the setter's clamps behave).
3. Delete the emptied stacks through a silent/batched provider path.
4. Clear `summoningSick` on every resulting creature-token stack.
5. `notifyListeners()` once.

Do not call the existing public `deleteItem()` inside the loop: it notifies for
every deletion and contradicts the single-notification bulk-operation contract.

No `GameEvents` call anywhere in this method. A `GameEvents` import appearing in
it during review is a bug.

### Files to Change

| File | Change |
|---|---|
| `lib/database/widget_database.dart` | new `WidgetDefinition` |
| `lib/utils/constants.dart` | `phyrexianMyrCompositeId` |
| `lib/models/item.dart` | `becomeCopyOf()` batched mutator |
| `lib/services/token_copy_semantics.dart` | **new** — shared copy heuristics |
| `lib/services/rhys_copy_planner.dart` | call the shared helper (no behavior change) |
| `lib/services/brudiclad_transform_planner.dart` | **new** — plan builder |
| `lib/services/board_undo_snapshot.dart` | **new** — reusable pre-operation unified-board snapshot and silent restore |
| `lib/widgets/definition_preview_card.dart` | **new** — shared deck/Brudiclad artwork-backed definition card |
| `lib/screens/deck_detail_screen.dart` | refactor existing item preview onto `DefinitionPreviewCard`; no visual behavior change |
| `lib/widgets/tracker_widget_card.dart` | dispatch case, two-stage flow, picker |
| `lib/providers/token_provider.dart` | atomic commit, silent batch deletion, transform, snapshot restore |

No Hive schema change, no new type ID, no migration. `TrackerWidget.actionOnly`
already exists and is already persisted through decks
(`lib/providers/deck_provider.dart:165`).

## Haste Integration

"Creature tokens you control have haste" is a real effect the app models through
summoning sickness, and it is why Brudiclad decks function — the copied tokens
attack the turn they transform.

Brudiclad's first ability continuously grants haste to creature tokens. Merely
placing the utility on the app board does **not** prove the card is currently on
the battlefield, so utility presence alone must never suppress sickness.
Invoking **Resolve Trigger**, however, is affirmative evidence that Brudiclad is
present for that resolution. MVP can therefore model the relevant gameplay
state without a separate toggle.

After Step 1 creation and any Step 2 transformation/merging complete, clear the
`summoningSick` count on every `Item` whose resulting identity has P/T. This
includes existing creature tokens, newly created creature results, the chosen
creature definition, transformed noncreatures that became creatures, and merged
creature stacks. If the chosen definition is noncreature, its resulting stacks
retain their sickness counts because the haste static applies only to creature
tokens; those counts may matter if the token becomes a creature again later.

Skip still represents a successful trigger resolution with Brudiclad present:
commit Step 1 and clear sickness from all creature-token stacks even though no
copy transformation occurs. Cancel represents no resolution and changes
nothing.

Ruling 6 (a token that already attacked keeps attacking if Brudiclad leaves) is
below the app's resolution — it does not model attacking — and needs no handling.

**MVP scope:** no haste toggle and no global creation-path integration. Preserve
and sum sickness counts during transformation/merge, then clear them from the
resulting creature-token stacks at the end of successful resolution. The undo
snapshot retains the original counts and restores them if the user chooses Undo.

## Clarifying Questions

### Behavior

1. ~~**One button or two?**~~ **RESOLVED:** one `Resolve Trigger` button doing
   both steps. The picker supplies Skip for the optional copy effect.
2. ~~**Board with only countered stacks.**~~ **RESOLVED:** every stack transforms
   but none merge. The compact selector summary states that the countered stacks
   stay separate; no alternate completion messaging is used.
3. ~~**Does Skip still create the Myr?**~~ **RESOLVED:** yes. Skip commits every
   evaluated Step 1 result but does not transform the board.

### Copying Details

4. **Anchor choice.** ~~Chosen stack vs. lowest-order clean stack.~~
   **RESOLVED** by the definition-based picker — with no "chosen stack" there is
   no competing anchor, so it is always the lowest-`order` clean stack.
5. ~~**Skip Stage A when nothing modifies the Myr?**~~ **RESOLVED:** yes — go
   straight to the virtual-board picker when evaluation returns exactly one
   unchanged Myr.

### UI

6. ~~**Should the picker show a preview of the resulting board?**~~ **RESOLVED:**
   no. Show only the compact impact summary beneath the active selection.
7. **Counter badges in the picker.** ~~Choosing a countered stack copies its
   base P/T, surprising users who see 2/2 and get 1/1.~~ **RESOLVED** by the
   definition-based picker — rows show base identities, so a countered stack
   never appears as `2/2` and the surprise cannot occur.

### Scope

8. ~~**Is the haste toggle in scope for the first release?**~~ **RESOLVED:** no.
   Utility presence proves nothing, but invoking Resolve Trigger proves
   Brudiclad is present. MVP clears sickness from all resulting creature-token
   stacks after successful resolution.
10. ~~**The `TokenCreationService` ETB gap.**~~ **RESOLVED:** fix first in a
    focused prerequisite commit, including full counter/artwork merge
    compatibility and companion-token regression coverage.

9. ~~**Undo.**~~ **RESOLVED:** after commit, show **Tokens Modified** with
   **Undo / Accept**. Implement the snapshot/restore mechanism as reusable board
   operation infrastructure so board wipe can adopt it later.

## Implementation Record

Implemented 2026-08-27 with no Hive schema change.

- Added the action-only Brudiclad utility and `Resolve Trigger` dispatch.
- Extracted shared copy semantics, clean-stack merge compatibility, and rules-
  result artwork resolution; Rhys now consumes the shared copy/artwork helpers.
- Fixed both `TokenCreationService` merge paths to require full clean/artwork
  compatibility and emit creature-ETB events for merged creature results.
- Added an immutable Brudiclad definition/transform planner and batched `Item`
  identity/count mutation methods.
- Added a typed unified-board snapshot that restores tokens, trackers, and
  toggles directly through Hive without replaying game events.
- Extracted deckbuilding's artwork-backed row into `DefinitionPreviewCard` and
  reused it in the select-then-Resolve bottom sheet.
- Implemented creation preview, virtual post-creation definitions, Skip,
  compact impact summary, commit/rollback, global creature-token sickness clear,
  and the exact `Tokens Modified` Undo/Accept completion modal.

Atomicity means no mutation before commit and complete snapshot rollback on
failure or Undo. It does not promise a single rendered frame: `ContentScreen`
listens directly to the three Hive boxes, so individual box writes can rebuild
the board even when provider notifications are batched.

Verification completed:

- `flutter analyze` — no new diagnostics; only existing project lints remain.
- `flutter build ios --simulator --debug` — succeeded.

The detailed checklist remains unchecked except where a focused simulator pass
has explicitly covered the behavior.

### Manual validation log — 2026-08-27

- [x] Smoke transformation across several unmodified token definitions.
- [x] Skip path committed Step 1 without applying Step 2.
- [x] Undo restored the smoke-test board.
- [x] Stacks carrying counters remained separate.
- [x] Tokens distinguished by abilities appeared as separate definitions and
      remained separate counter-bearing piles after transformation.
- [x] Rechecked the completion modal after feedback adjustment: **Undo** on the
      left, primary **Accept** on the right.
- [x] Rechecked the compact summary after removing the “Nothing is created” clause.
- [x] Confirmed compact-summary grammar uses “1 stack” / “1 token” / “stays” and
      plural “stacks” / “tokens” / “stay” for every other count, including zero.
- [x] Picker Cancel smoke path left the board unchanged.
- [x] Animated Clue with P/T produced basic Clue copies with no P/T.
- [x] Companion Squirrels appeared correctly from the active creation rule.
- [x] Creature-token summoning sickness cleared after successful resolution.

## Acceptance Test Checklist

**Layout & persistence**
- [ ] Add Brudiclad from the utility picker — card shows name, description, and
      an intrinsic-width **Resolve Trigger** button, no counter, no +/− buttons
- [ ] `UR` color identity renders a blue/red gradient border
- [ ] Save a deck containing Brudiclad, load it → still renders action-only
- [ ] Duplicate, export/import, and add through the deck editor → still
      action-only

**Step 1 — the Myr**
- [ ] Empty board → creates exactly one 2/1 blue Phyrexian Myr with BRC artwork
- [ ] Myr merges into an existing clean Phyrexian Myr stack rather than making a
      second one
- [ ] **Myr merging into an existing stack still ticks Cathar's Crusade** — the
      `TokenCreationService` ETB gap is fixed
- [ ] Companion creature token merging into an existing stack also ticks
      Cathar's Crusade (regression test for the same fix)
- [ ] Doubling Season active → two Myr, and the picker opens after they exist
- [ ] Cathar's Crusade on the board with no replacement/companion rule → its
      counter rises by the Myr quantity only
- [ ] A rule replacing the Myr → preview, virtual picker, and committed board all
      show the replacement identity; no phantom Myr is offered
- [ ] A rule also creating a companion → both results appear in the preview and
      virtual picker, and every creature result fires its own ETB batch
- [ ] Academy Manufactor rule active → does not fire on the Myr
- [ ] The 1/1 colorless Phyrexian Myr is never matched

**Step 2 — the transformation**
- [ ] Brudiclad definitions use the same full-width artwork preview treatment as
      deckbuilding menus, including crop, `BackgroundText`, P/T badge, and border
- [ ] Deck detail token/tracker/toggle rows remain visually and behaviorally
      unchanged after extraction to `DefinitionPreviewCard`
- [ ] Uncached artwork for virtual Step 1 results downloads and appears without
      closing/reopening the selector
- [ ] Picker opens with no active definition and **Resolve** disabled
- [ ] Tapping a definition highlights it as active and enables **Resolve**
- [ ] Tapping another definition moves the highlight; selection alone makes no
      board changes
- [ ] Active selection shows only the compact affected-stack/token summary; no
      complete before/after board is rendered
- [ ] Pressing **Resolve** performs Step 1 and the selected transformation
- [ ] Board total before + sum of all evaluated Step 1 result quantities == board
      total after, every time
- [ ] Choosing the Myr → every other stack becomes a 2/1 Phyrexian Myr
- [ ] **Ruling 1:** choosing a Soldier → Treasures and Clues become Soldiers too
- [ ] **Ruling 3:** not choosing the Myr → the Myr itself is flattened
- [ ] Three separate Soldier stacks → picker shows **one** `Soldier 1/1` row with
      the combined `×N` count, not three rows
- [ ] Soldier stack with +1/+1 counters → picker row reads `Soldier 1/1`, never
      `Soldier 2/2`
- [ ] Animated Clue and a plain Clue both on board → collapse to one picker row
- [ ] Choosing a definition that already matches some stacks → those stacks are
      no-ops and are not double-counted in the compact impact total
- [ ] Skip → Step 1 results are created and all creature-token stacks have
      sickness cleared, but no copy transformation occurs
- [ ] Cancel at either stage → nothing changes at all, including no Myr
- [ ] Emblem on the board → never listed in the picker, never transformed
- [ ] Zero-amount stack → never listed, never transformed
- [ ] Trackers and toggles → never listed in the picker

**Copiable-values correctness**
- [ ] **Ruling 2:** the only Soldier source is a stack with +1/+1 counters →
      definition reads `Soldier 1/1` and everything flattens to **1/1**, not 2/2
- [ ] Flattened stack had its own +1/+1 counter → keeps it, displays modified
      P/T under the new identity
- [ ] Transformed stack has a custom counter → preserved
- [ ] Transformed stack was tapped → stays tapped, same tapped count
- [ ] Sickness counts are preserved and summed during merging, then every
      resulting creature-token stack is cleared to zero after resolution
- [ ] Choosing a noncreature definition → resulting noncreature stacks retain
      their sickness counts
- [x] Chosen stack is an animated Clue (`Artifact — Clue` with P/T) → others
      become plain Clues with no P/T
- [ ] Chosen stack has custom artwork → every copy takes that exact artwork
- [ ] Chosen stack has a user-edited custom name → copied verbatim, no database
      lookup second-guesses it
- [ ] **Ruling 4:** transform once, then choose an already-transformed stack →
      others copy that stack's current identity

**Merging**
- [ ] Three clean stacks (2, 3, 4) transform → single stack of 9 at the
      lowest-order clean stack's board position
- [ ] Partially tapped stacks merge → tapped counts sum and never exceed `amount`
- [ ] Summoning-sick counts sum and never exceed `amount` before the final
      creature-token haste clear
- [x] Countered stacks never merge into the clean stack, nor into each other
- [ ] Merged stack lands at the lowest `order` that held a clean stack
- [ ] Every stack on the board carries counters → nothing merges, stack count
      unchanged, all sharing one identity
- [ ] Emptied stacks are deleted, leaving no zero-amount ghosts

**Undo**
- [x] After transformation, completion modal always says **Tokens Modified** and
      offers **Undo / Accept** in that order
- [ ] Undo restores the exact pre-trigger board, including Step 1 creations,
      deleted stacks, identities, artwork, counters, tapped/sick counts, order,
      and Cathar's Crusade utility values changed by Step 1 ETBs
- [ ] Undo restoration itself fires no ETB or board-wipe events
- [ ] Accept discards the snapshot; the transformed state remains persisted
- [ ] Skip commits Step 1 only and does not show the Tokens Modified modal
- [ ] Snapshot/restore is implemented independently of Brudiclad so a later board
      wipe integration can reuse it

**Non-regression**
- [ ] Cathar's Crusade does **not** tick for transformed tokens
- [ ] Rhys behaves identically after `copiablePtFor` / eligibility are extracted
      to `TokenCopySemantics` — re-run the full Rhys acceptance checklist
- [ ] Running the trigger twice in a row works, the second seeing the first's
      results
- [ ] Board wipe, untap all, and clear sickness behave normally on transformed
      stacks
