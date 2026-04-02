# Advanced Token Calculator

## Status: Todo

## Overview

<!-- Dump requirements here -->

## Requirements

### Rules Creator

The advanced token calculator includes a **rules creator** that lets users define persistent, toggleable rules. Each rule has a **condition** (trigger) and an **outcome** (effect). Rules are owned by the user and can be enabled, disabled, edited, or deleted.

#### Rule Structure

A rule reads as a sentence: **"Whenever you create a [trigger], instead create [value] [token]."**

A rule consists of:
- **Name** — User-defined label (e.g., "My Doubling Season", "Academy Manufactor")
- **Trigger** — What token creation this rule matches: a specific token definition, a type (e.g., "token with P/T"), a color, or "any token"
- **One or more outcomes** — What happens when the trigger matches (multiply quantity, or also create N of another token)
- **Enabled/Disabled** — Toggle without deleting

#### Rule Ordering & Execution

- Rules are stored in a user-defined **ordered list**
- The list is **reorderable** (drag to reorder)
- When a token is created, rules are evaluated **top-down, one at a time**, in list order
- **No upward chain triggering** — companion tokens created by an "also create" outcome continue evaluation from the **next rule down**, never re-entering from the top. This is loop-safe (finite by construction) and rules-accurate per 614.16.
- **Order matters significantly.** Doublers placed below "also create" rules will multiply companion tokens. Doublers placed above won't reach them. This mirrors MTG's 616.1 where the player chooses replacement effect order.

#### Trigger Types

The trigger is a single settable field — either a token definition or a type:

| Trigger | Description | Example |
|---------|-------------|---------|
| **A specific token** | Matches by token definition from the database | "Whenever you create a Food..." |
| **A token with P/T** | Matches any token that has power/toughness stats | "Whenever you create a creature token..." |
| **A token of a type** | Matches by token type (Creature, Artifact, Enchantment) | "Whenever you create an artifact token..." |
| **A token of a color** | Matches by color identity | "Whenever you create a green token..." |
| **Any token** | Matches all token creation | "Whenever you create any token..." |

Triggers reference the token database (913 tokens) so users can search for and select exact token definitions rather than free-typing names.

**Creature detection:** "Has P/T" is the canonical check for whether a token is a creature, NOT the type line. Some players create custom tokens without specifying the Creature supertype — anything with power/toughness should be assumed to be a creature. This aligns with how `Item.hasPowerToughness` already works elsewhere in the app.

#### Outcome Types

| Outcome | Description | Example |
|---------|-------------|---------|
| **Multiply** | Scale the quantity of the triggering token by N | "...instead create ×2" (Doubling Season) |
| **Also create** | Create N of a specific token alongside the triggering token | "...also create 1 Treasure" (Academy Manufactor) |

A rule can have **multiple outcomes** (e.g., Academy Manufactor: "when creating a Food → also create 1 Treasure + also create 1 Clue").

Outcomes that reference a token use the token database to resolve the exact TokenDefinition, ensuring correct name, P/T, colors, abilities, and type.

**Note:** Counter modification does NOT use the rules engine. See [Counter Modifier](#counter-modifier) below for the simpler handler.

#### UI Home

The advanced token calculator lives at the **existing multiplier entry point** in the FAB menu. Tapping it opens the rules management screen (sheets/modals as needed). This replaces the current multiplier UI entirely.

#### Preview

The rules screen shows a **live preview** that explains the final result of creating a single token with the current enabled rules:

**Default preview:** Shows the result for a generic token:
> "1 token → 4 tokens" (if two doublers are active)

**Conditional previews:** When rules are conditional on specific token types, an inline link opens a **preview modal** showing all scenarios:
> "Whenever you make **a token**: 1 token = 4 tokens"
> "Whenever you make **a Food**: 1 Food = 4 Food + 1 Treasure + 1 Clue"
> "Whenever you make **a Squirrel**: 1 Squirrel = 8 tokens + 1 Squirrel"

This lets users understand the combined effect of all their rules at a glance, especially when multiplicative and additive rules interact. The preview updates live as rules are enabled/disabled/reordered.

#### Persistence & Lifecycle

- Rules persist across app launches (not tied to a game session)
- Rules survive board wipes — they represent the user's card effects, not board state
- Users can enable/disable rules without deleting them (e.g., disable a rule when a permanent leaves the battlefield, re-enable if it comes back)

#### Preset Rules (Well-Known Cards)

Well-known cards have **hardcoded preset rules** that users can enable with a single tap. The user doesn't need to build these from scratch — they just check the card name and its rules activate. Presets are not editable (they represent the card's actual rules text), but users can create custom rules for anything not in the preset list.

**Token presets:**

| Preset Name | Trigger | Outcomes |
|-------------|---------|----------|
| **Doubling Season** | Any token | Multiply tokens ×2, Multiply counters ×2 |
| **Parallel Lives** | Any token | Multiply tokens ×2 |
| **Anointed Procession** | Any token | Multiply tokens ×2 |
| **Mondrak, Glory Dominus** | Any token | Multiply tokens ×2 |
| **Adrix and Nev, Twincasters** | Any token | Multiply tokens ×2 |
| **Primal Vigor** | Any token | Multiply tokens ×2, Multiply +1/+1 counters ×2 |
| **Ojer Taq, Deepest Foundation** | Token with P/T | Multiply tokens ×3 |
| **Academy Manufactor** | Food | Also create 1 Treasure, Also create 1 Clue |

**Counter presets:**

| Preset Name | Trigger | Outcomes |
|-------------|---------|----------|
| **Hardened Scales** | When placing +1/+1 counters | Add 1 additional +1/+1 |
| **Branching Evolution** | When placing +1/+1 counters | Multiply +1/+1 counters ×2 |
| **Corpsejack Menace** | When placing +1/+1 counters | Multiply +1/+1 counters ×2 |
| **Vorinclex, Monstrous Raider** | When placing any counters | Multiply counters ×2 |

Users can also create **custom rules** using the same trigger/outcome model for cards not in the preset list or for homebrew effects.

#### Example Custom Rules

**Simple (single outcome):**

| Rule Name | Trigger | Outcomes |
|-----------|---------|----------|
| "My Doubler" | Any token | Multiply by 2 |
| "Creature Tripler" | Token with P/T | Multiply by 3 |

**Multiple outcomes:**

| Rule Name | Trigger | Outcomes |
|-----------|---------|----------|
| "Custom Manufactor" | Treasure | 1. Also create 1 Food, 2. Also create 1 Clue |

**Stacking example (list order matters):**

Correct ordering — "also create" rules above doublers so companions get multiplied:
1. "Academy Manufactor" — Food → also create Treasure + Clue
2. "Doubling Season" — any token → ×2

Creating 1 Food: Rule 1 matches Food → queue 1 Treasure, 1 Clue (companions enter at Rule 2). Rule 2 doubles everything: Food ×2, Treasure ×2, Clue ×2. **Final: 2 Food, 2 Treasure, 2 Clue.** This matches real MTG where the player chooses Manufactor first, then Doubling Season doubles the full batch.

Wrong ordering — doublers above "also create" means companions miss them:
1. "Doubling Season" — any token → ×2
2. "Academy Manufactor" — Food → also create Treasure + Clue

Creating 1 Food: Rule 1 doubles Food to 2. Rule 2 matches Food → queue 1 Treasure, 1 Clue (no rules below). **Final: 2 Food, 1 Treasure, 1 Clue.** The user should reorder to get the correct result.

### Counter Modifier

Counter modification uses a **simpler handler** than the token rules engine. No ordered rule list — just two pairs of numbers across two scopes.

#### Two Scopes

Counter effects in MTG care about **what type of counter** is being placed. The app needs two independent tracks:

| Scope | Doublers (×2 each) | Extra (+1 each) | Applies to |
|-------|-------------------|-----------------|------------|
| **+1/+1 counters only** | Branching Evolution, Corpsejack Menace, Primal Vigor, The Earth Crystal | Hardened Scales, Conclave Mentor, High Score, Michelangelo | +1/+1 counter operations only |
| **All counters** | Doubling Season, Vorinclex, Innkeeper's Talent L3, Loading Zone | (none in current card pool) | +1/+1, -1/-1, custom counters, and any future counter types |

**All-counter doublers stack on top of +1/+1 specific doublers.** When placing +1/+1 counters, both tracks apply. When placing any other counter type (custom counters), only the all-counter track applies.

#### Formula

```
For +1/+1 counters:
  final = (base + extra_plus_one) × 2^(plus_one_doublers) × 2^(all_doublers)

For any other counter type:
  final = base × 2^(all_doublers)
```

#### Examples

| Active Effects | Placing | Result |
|---|---|---|
| Hardened Scales (extra=1) | 1 +1/+1 | (1+1) = **2** |
| Branching Evolution (×2 +1/+1) | 1 +1/+1 | 1×2 = **2** |
| Hardened Scales + Branching Evolution | 1 +1/+1 | (1+1)×2 = **4** |
| Hardened Scales + Doubling Season | 1 +1/+1 | (1+1)×2 = **4** |
| Hardened Scales + Branching Evolution + Doubling Season | 1 +1/+1 | (1+1)×2×2 = **8** |
| Doubling Season only | 1 charge counter | 1×2 = **2** |
| Hardened Scales + Branching Evolution | 1 charge counter | 1 = **1** (neither applies to non-+1/+1) |

#### Counter Presets

| Preset Name | Scope | Effect |
|-------------|-------|--------|
| **Doubling Season** | All counters | ×2 (also has token doubling — see token presets) |
| **Vorinclex, Monstrous Raider** | All counters | ×2 |
| **Innkeeper's Talent** (L3) | All counters | ×2 |
| **Loading Zone** | All counters | ×2 |
| **Branching Evolution** | +1/+1 only | ×2 |
| **Corpsejack Menace** | +1/+1 only | ×2 |
| **Primal Vigor** | +1/+1 only | ×2 (also has token doubling — see token presets) |
| **The Earth Crystal** | +1/+1 only | ×2 |
| **Hardened Scales** | +1/+1 only | +1 extra |
| **Conclave Mentor** | +1/+1 only | +1 extra |
| **High Score** | +1/+1 only | +1 extra |
| **Michelangelo, Weirdness to 11** | +1/+1 only | +1 extra |

**Shared presets:** Doubling Season and Primal Vigor appear in both the token presets and counter presets. Enabling "Doubling Season" activates both its token doubling rule AND its all-counter doubling. One checkbox, both effects.

#### UI

The counter modifier settings live alongside the token rules in the same screen (accessed from the FAB multiplier entry point). Since counters are just two pairs of numbers (doublers + extra for each scope), this can be a compact section — no need for a full rule list.

The user can either:
- Enable a **preset card** (e.g., check "Hardened Scales" → +1 extra +1/+1)
- Manually adjust the **doublers** and **extra** counts for custom setups

#### Resolved Design Decisions

- **Rule model**: Single trigger + one or more outcomes. No compound conditions, no negation. Simple sentence: "Whenever you create a [trigger], instead create [value] [token]."
- **Multiple outcomes**: Yes — a single rule supports multiple outcomes (e.g., Academy Manufactor)
- **Negation**: Out of scope for v1. Only Chatterfang truly needs it. Can be revisited later.
- **Chain triggering**: No upward re-entry — companion tokens evaluate against remaining rules *below* the one that created them, per 614.16. Loop-safe by construction.
- **Rule ordering**: Rules are reorderable and evaluated top-down. Order affects outcomes (mirrors 616.1 player-chosen order).
- **Rule stacking**: Multiplier rules stack multiplicatively. "Also create" rules fire independently. Companion tokens are subject to multiplier rules below them in the list.
- **Counter modifier**: Separate, simpler handler — not the full rules engine. Two scopes (+1/+1 only vs. all counters), each with a doublers count and an extra count. Formula: `(base + extra) × 2^doublers`.
- **Preset rules**: Well-known cards are hardcoded presets. Users check the card name to enable — no manual rule building required. Cards with both token and counter effects (Doubling Season, Primal Vigor) activate both from a single checkbox.
- **UI home**: Lives at the existing multiplier entry point in the FAB menu. Replaces the multiplier UI.
- **Preview**: Live preview shows calculated result of creating 1 token. Conditional rules show per-type breakdowns in a modal ("1 token = 4 tokens", "1 Food = 4 Food + 1 Treasure + 1 Clue").

#### MTG Rules Foundation

The rules engine is modeled on MTG's replacement effect system. Key comprehensive rules (sourced from French Vanilla's `comprehensive_rules.md`, effective Feb 27, 2026):

- **614.1** — Replacement effects watch for a particular event and replace it with a different event. They use the word "instead."
- **614.5** — A replacement effect doesn't invoke itself repeatedly; it gets only one opportunity per event. (One Doubling Season = one doubling per token creation.)
- **614.16** — Replacement effects that apply "if an effect would create one or more tokens" also apply when *another replacement effect* creates those tokens. This is why multiple doublers stack multiplicatively.
- **616.1** — When multiple replacement effects apply, the affected player chooses the order. Process repeats (616.1f) until no more apply.
- **616.1e** — Any applicable replacement effect may be chosen (catch-all after self-replacement, control-change, and copy effects).

**What this means for our rules engine:** The top-down ordered list models 616.1's "player chooses order" — the user arranges rules in their preferred application order. For pure multipliers (2×2 vs 2×2), order is commutative. But for mixed rule types (multiply + also-create), the user's chosen order determines the outcome.

#### Open Questions

- **~~Negative conditions~~**: **RESOLVED** — Out of scope for v1. The only card that truly needs negation is Chatterfang. "May" effects like Jinnie Fay are user choices (just pick the token), Brudiclad is a utility, Ojer Taq is a positive P/T check. Not worth the UI complexity for one card.
- **~~Counter rules~~**: **RESOLVED** — In scope for v1 with a simpler handler than token rules. Two scopes: "+1/+1 only" and "all counters." Each scope tracks doublers (×2 each) and extra (+1 each). No ordered rule list needed. Presets for 12 well-known cards. See [Counter Modifier](#counter-modifier) section.
- **~~Multiplier integration~~**: **RESOLVED** — Rules replace the existing multiplier entirely. The manual multiplier slider is removed. Flat doublers are expressed as rules. Existing users get a one-time migration converting their multiplier value to equivalent doubler rules.
- **~~"Also create" quantity and multipliers~~**: **RESOLVED** — Per 614.16, companion tokens ARE subject to replacement effects. Companion tokens evaluate against remaining rules below the one that created them (see Execution Flow). This is rules-accurate and loop-safe.

## Scoping

### Token Creation Entry Points

The codebase has **10 distinct entry points** where tokens get created or added. The rules engine can't live in all of them — it needs one centralized intercept. Here's every entry point and whether rules should apply:

| Entry Point | File | Multiplier Today | Rules Apply? | Reasoning |
|---|---|---|---|---|
| **Token Search** | token_search_screen.dart:931 | UI layer | **Yes** | Primary creation path |
| **Custom Token** | new_token_sheet.dart:400 | UI layer | **Yes** | Still "creating a token" |
| **Quick-Add (tap/long)** | token_card.dart:430, 441 | UI layer | **Yes** | Tapping "+" is creating tokens — rules apply. Only manual quantity editing (typing a number directly) bypasses rules. |
| **Scute Swarm** | token_provider.dart:503 | Provider layer | **Yes** | Doublers affect Scute in real MTG |
| **Krenko** | token_provider.dart:662 | None | **Yes** | Krenko creates tokens — doublers should apply to those tokens. Krenko itself stays as a utility (board-state ability), but its output flows through the rules engine. |
| **Academy Manufactor** | token_provider.dart:811 | Caller-dependent | **Removed — becomes a rule** | Was a stopgap utility. Replacement effect belongs in the rules engine. Hardcoded utility code will be deleted. |
| **Split Stack** | split_stack_sheet.dart:354 | None | **No** | Reorganizing, not creating |
| **Copy Token** | counter_search_screen.dart:273+ | None | **No** | Mechanical duplication |
| **Deck Load** | deck_provider.dart:604 | None (init to 0) | **No** | Restoring saved state |
| **Cathar's Crusade** | via GameEvents ETB | N/A (counters) | **Separate concern** | Counter rules, not token rules |

**Bypass principle:** The rules engine applies to all token creation actions (search, quick-add, utility outputs). The only bypass is **manual entry** — directly typing/editing a quantity number. This gives users an escape hatch for corrections without fighting the rules engine.

### Multiplier System Impact

**Decision: Rules replace the existing multiplier entirely.**

The current manual multiplier (int 1–1024 in SharedPreferences, applied at creation time) will be removed. Flat doublers become rules: Doubling Season = "any token → ×2". The rules list is the single source of truth for all token quantity modification.

To preserve ease-of-use for the common case ("I have 3 doublers"), the rules UI should offer a **quick-add shortcut** — e.g., "+ Add Doubler" creates a pre-filled "any token → ×2" rule in one tap. This keeps the simple case fast without maintaining two parallel systems.

**Migration:** Existing users with a multiplier > 1 will need a one-time migration that converts their multiplier value into equivalent doubler rules (e.g., multiplier=8 → three "any token → ×2" rules). The SharedPreferences key can then be retired.

### Existing Utility Overlap

| Current Utility | Disposition | Reasoning |
|---|---|---|
| **Academy Manufactor** (`createAcademyManufactorTokens`) | **Migrates to rules engine** | Academy Manufactor is a replacement effect — exactly the kind of thing this feature models. It was implemented as a standalone utility only because the rules engine didn't exist yet. It should become a rule: "When creating a Food → also create 1 Treasure + 1 Clue." The hardcoded utility code in TokenProvider will be removed. |
| **Krenko** (`createGoblinToken`) | **Stays as utility** | Krenko's ability ("tap: create goblins equal to goblin count") depends on board state (counting existing goblins). This is an activated ability, not a replacement effect — it doesn't modify token creation, it initiates it based on a board-state query. The rules engine's condition/outcome model doesn't cover this. Krenko remains a standalone utility. |
| **Cathar's Crusade** (via GameEvents) | **Stays as utility** | Cathar's Crusade is a triggered ability ("whenever a creature enters, put a +1/+1 counter on each creature you control"), not a replacement effect on counter placement. The counter rules in the calculator handle "when counters are being placed, modify how many" — not "trigger counter placement from ETB events." Cathar's Crusade initiates counter placement; Hardened Scales/Doubling Season modify it. Different layer. |

### Data Model Needs

New Hive models required (next available typeId: 8):

```
TokenRule       (typeId: 8)  — name, enabled, order, conditions, outcomes
RuleCondition   (typeId: 9)  — conditionType, targetTokenId, targetType, targetColor, negated
RuleOutcome     (typeId: 10) — outcomeType (multiply|also_create), multiplier, targetTokenId, quantity
```

Three new type IDs, one new Hive box (`tokenRules`). All new fields need `defaultValue` per existing schema rules.

### Architecture: Where the Engine Lives

The rules engine should be a **new provider** (`RulesProvider`) that:
- Owns the `Box<TokenRule>` Hive box
- Exposes an `evaluateRules(TokenDefinition, int quantity) → List<(TokenDefinition, int)>` method
- Returns the full list of tokens to create (original + companions, with quantities adjusted)
- Is injected into TokenProvider or called by the UI before `insertItem()`

Token creation flow becomes:
```
User selects token + quantity
  → RulesProvider.evaluateRules(token, quantity)
  → Walks rules top-down; companion tokens continue from next rule down (614.16)
  → Returns [(Food, 2), (Treasure, 2), (Clue, 2)]  // if doublers below also-create rules
  → Each tuple → tokenProvider.insertItem()
```

## Notes

### Token Database Integration
Rules reference TokenDefinitions from the 913-token database. The rule creator UI needs a token search/picker (similar to TokenSearchScreen) so users can select exact tokens for both conditions and outcomes. This ensures the correct token gets created with proper P/T, colors, abilities, and artwork.

### Execution Flow

Per MTG rule 614.16, replacement effects apply to tokens created by other replacement effects. Our engine models this by having companion tokens evaluate against **remaining rules below** the one that created them — never re-entering from the top.

When the user creates tokens through the normal flow (TokenSearchScreen → quantity → create):
1. Rules engine receives the token creation intent (token + quantity)
2. Enabled rules are evaluated **top-down in list order**
3. Each matching **multiply** rule adjusts the quantity of the triggering token
4. Each matching **also-create** rule queues companion tokens — these companions then continue evaluation from the **next rule down** (not from the top)
5. After all rules are evaluated: insert the original token and all companion tokens with their final quantities

**Example — order matters (per 614.16 + 616.1):**

Rule list:
1. Academy Manufactor — Food → also create Treasure + Clue
2. Doubling Season — any token → ×2

Creating 1 Food:
- Rule 1: matches Food → queue 1 Treasure, 1 Clue (companions enter at Rule 2)
- Rule 2: Food ×2 = 2 Food. Treasure ×2 = 2 Treasure. Clue ×2 = 2 Clue.
- **Final: 2 Food, 2 Treasure, 2 Clue** (rules-accurate)

If reversed (Doubling Season above Manufactor):
- Rule 1: Food ×2 = 2 Food
- Rule 2: matches Food → queue 1 Treasure, 1 Clue (no rules below → stays 1 each)
- **Final: 2 Food, 1 Treasure, 1 Clue** (doublers don't reach companions)

This means **the user's chosen rule order directly affects outcomes**, which mirrors MTG's 616.1 ("affected player chooses order"). The app should surface this clearly — perhaps with a preview showing the calculated result as rules are reordered.

## Research

Research compiled from Scryfall `oracletag:token-doubler` and counter-modifier searches. This covers the full landscape of token and counter modification effects in Magic: The Gathering.

---

### Token Modification

#### 1. Flat Doublers (Replacement Effects — Double ALL Tokens)

These use a replacement effect to double all token creation. No conditions beyond controlling the effect. This is what the app's current multiplier system models.

| Card | Type | Notable |
|------|------|---------|
| **Doubling Season** | Enchantment | Also doubles ALL counter types |
| **Parallel Lives** | Enchantment | Token-only |
| **Anointed Procession** | Enchantment | White Parallel Lives |
| **Mondrak, Glory Dominus** | Creature | Can gain indestructible |
| **Adrix and Nev, Twincasters** | Creature | Ward 2 |
| **Elspeth, Storm Slayer** | Planeswalker | Static doubler + makes tokens |
| **Exalted Sunborn** | Creature | Angel with Warp |
| **Primal Vigor** | Enchantment | **SYMMETRIC** — doubles for ALL players. Also doubles +1/+1 counters symmetrically |

**Key behavior:** Multiple flat doublers stack **multiplicatively**. Two doublers = 4x tokens. Three = 8x. This is already handled by the app's multiplier (1–1024).

**Wording note:** Older cards say "if an effect would create" while newer cards say "if one or more tokens would be created." Functionally identical after Oracle updates.

#### 2. Conditional Doublers / Replacers

These double tokens only under specific conditions or for limited duration.

| Card | Condition | Notable |
|------|-----------|---------|
| **Ojer Taq, Deepest Foundation** | **Creature tokens only** | **TRIPLER** (3x, not 2x). Misses Treasure, Food, Clue, Blood, etc. |
| **Kaya, Geist Hunter** | One turn only (−2 loyalty) | Temporary doubling |
| **Renewed Solidarity** | Chosen creature type only, end step trigger | Copies tokens of one type that entered this turn |
| **Ocelot Pride** | Needs city's blessing (10+ permanents) | End step — copies all tokens that entered this turn |

**Key insight:** Ojer Taq is the only **tripler** in the game. It also only affects creature tokens, so it doesn't triple Treasures/Food/Clues.

**Stacking with flat doublers:** A flat doubler + Ojer Taq = 6x creature tokens (replacement effects controlled by affected player choose order: 2×3 or 3×2 = same result).

#### 3. Incrementors (Triggered Abilities — "When You Make X, Also Make Y")

These don't replace token creation — they create additional copies via triggered or activated abilities.

| Card | Effect | Scope |
|------|--------|-------|
| **Rhys the Redeemed** | Activated: copy all creature tokens you control | Creature tokens only |
| **Second Harvest** | Instant: copy all tokens you control | ALL token types (broadest) |
| **Parallel Evolution** | Sorcery: copy all creature tokens on battlefield | **SYMMETRIC**, has flashback |

**Key distinction from doublers:** These copy what's already on the battlefield, not what's being created. They're one-shot effects, not ongoing multipliers.

---

### Counter Modification

#### 4. Counter Doublers (Replacement Effects — Double Counters as Placed)

##### All Counter Types

| Card | Type | Scope | Notable |
|------|------|-------|---------|
| **Doubling Season** | Enchantment | All counters on your permanents | The gold standard |
| **Vorinclex, Monstrous Raider** | Creature | All counters on permanents AND players | Also **halves** opponents' counters |
| **Innkeeper's Talent** (Level 3) | Enchantment (Class) | All counters on permanents AND players | Requires leveling to 3 |
| **Loading Zone** | Enchantment | All counters on creatures/Spacecraft/Planet | Universes Beyond restriction |

##### +1/+1 Counters Only

| Card | Type | Scope | Notable |
|------|------|-------|---------|
| **Branching Evolution** | Enchantment | +1/+1 on your creatures | Clean, simple |
| **Corpsejack Menace** | Creature (Fungus) | +1/+1 on your creatures | On a body |
| **Primal Vigor** | Enchantment | +1/+1 on ALL creatures | **SYMMETRIC** |
| **The Earth Crystal** | Artifact | +1/+1 on your creatures | Also cost reduction |

#### 5. Counter Incrementors (Replacement Effects — "+1 Additional")

These add one extra +1/+1 counter each time counters are placed. **These are the Hardened Scales family.**

| Card | Scope | Notable |
|------|-------|---------|
| **Hardened Scales** | +1/+1 on your creatures | The original, 1 mana |
| **High Score** | +1/+1 on your creatures | Also draws cards |
| **Conclave Mentor** | +1/+1 on your creatures | Death trigger: gain life |
| **Ozolith, the Shattered Spire** | +1/+1 on your artifacts AND creatures | Broader permanent types |
| **Kami of Whispered Hopes** | +1/+1 on ANY permanent you control | Broadest scope |
| **Solid Ground** | +1/+1 on any permanent you control | Clean enchantment |
| **Benevolent Hydra** | +1/+1 on OTHER creatures you control | Excludes itself |
| **Caradora, Heart of Alacria** | +1/+1 on creatures AND Vehicles | Vehicle support |
| **Michelangelo, Weirdness to 11** | +1/+1 on your creatures | Universes Beyond |
| **Mauhur, Uruk-hai Captain** | +1/+1 on Army/Goblin/Orc only | Type-restricted |
| **Mowu, Loyal Companion** | +1/+1 on ITSELF only | Narrowest scope |

**Also notable:**
- **Cursed Wombat** — Triggered ability (not replacement): gives each permanent "when counters placed, add one more, once per turn." Functionally similar but mechanically distinct.

#### 6. Active Counter Doublers (Activated/Triggered — Double Existing Counters)

These double counters already on permanents, rather than modifying placement. There are 40+ cards that do this. Most relevant archetypes:

**All counter types:** Deepglow Skate (ETB), Vorel of the Hull Clade (tap ability), Gilder Bairn (untap ability), Aetheric Amplifier

**+1/+1 only:** Kalonian Hydra (attack trigger, all your creatures), Bristly Bill (activated, all your creatures), Primordial Hydra (upkeep, itself), Solidarity of Heroes (instant, any number of creatures)

**These are less relevant to the calculator feature** since they're one-shot effects, not ongoing modifiers. But they may matter for utility cards.

#### 7. Counter Redistributors (Move/Copy)

Cards that move counters between permanents. Examples: Forgotten Ancient, Bioshift, The Ozolith. **Likely out of scope for the calculator** but worth noting for future utility cards.

---

### Stacking Rules Summary

Understanding how these effects interact is critical for the calculator:

1. **Multiple flat token doublers** stack multiplicatively:
   - 1 doubler = 2x, 2 doublers = 4x, 3 doublers = 8x
   - Formula: `base_tokens × 2^(number_of_doublers)`

2. **Ojer Taq (tripler) with doublers:**
   - Replacement effects chosen by affected player
   - Ojer Taq + 1 doubler = 6x (2×3), Ojer Taq + 2 doublers = 12x (2×2×3)
   - Formula: `base_tokens × 2^(doublers) × 3^(triplers)`

3. **Counter doublers + incrementors stack:**
   - Hardened Scales + Doubling Season: place 1 +1/+1 → Hardened adds 1 → 2 counters → Doubling Season doubles → 4 counters
   - Order matters with replacement effects (player chooses order):
     - Scales first: (1+1) × 2 = 4
     - Doubling first: (1×2) + 1 = 3
   - **Player will choose the order that benefits them most**

4. **Symmetric effects** (Primal Vigor, Parallel Evolution) affect ALL players — the calculator should flag these

---

### App Relevance Summary

| Category | Currently Handled? | Calculator Priority |
|----------|-------------------|-------------------|
| Flat token doublers | Yes (manual multiplier) | **HIGH** — automate this |
| Ojer Taq (tripler) | Partially (manual multiplier) | **HIGH** — add 3x support |
| Conditional doublers | No | **MEDIUM** — complex game state |
| Token incrementors | No | **LOW** — one-shot effects |
| Counter doublers (placement) | No | **HIGH** — affects +1/+1 Everything |
| Counter incrementors (+1 extra) | No | **HIGH** — Hardened Scales family is very common |
| Active counter doublers | No | **LOW** — one-shot/activated, not ongoing |
| Counter redistributors | No | **OUT OF SCOPE** |
