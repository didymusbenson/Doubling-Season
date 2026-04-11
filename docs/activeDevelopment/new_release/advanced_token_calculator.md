# Advanced Token Calculator

## Status: Implemented — Pending Testing

## Implementation Summary

### What Was Built

**Rules Engine** (`lib/providers/rules_provider.dart`)
- Full replacement effect engine compliant with MTG rules 614.16 and 616.1
- Top-down ordered evaluation; companion tokens from "also create" continue from next rule down (loop-safe by construction)
- `evaluateRules()` returns list of `TokenCreationResult` with all tokens to create
- `calculateCounterAmount()` applies counter modifier formula to any counter placement
- Quantity cap at 999,999 with user-facing alert modal
- Identity case: no enabled rules = pass-through (quantity in = quantity out)

**Data Models** (`lib/models/token_rule.dart`, `rule_trigger.dart`, `rule_outcome.dart`)
- Hive TypeIds 10, 11, 12 — all fields have `defaultValue` for upgrade safety
- `TokenRule` extends HiveObject, stored in `tokenRules` box with resilient boot
- `RuleTrigger` and `RuleOutcome` are nested objects (same pattern as TokenCounter inside Item)

**Preset System** (persisted via SharedPreferences, computed at evaluation time)
- Token Doublers (×2 each, quantity stepper) — Parallel Lives, Anointed Procession, Mondrak, Adrix and Nev, Elspeth Storm Slayer, Exalted Sunborn
- Doubling Season (×2 tokens + ×2 all counters)
- Primal Vigor (×2 tokens + ×2 +1/+1 counters)
- Ojer Taq (×3 creature tokens only)
- Academy Manufactor (Food/Treasure/Clue → also create the other two)
- +1/+1 Doublers, +1/+1 Extra, All-Counter Doublers

**Counter Modifier** (two-scope system)
- +1/+1 scope: `(base + extra) �� 2^(plus_one_doublers) × 2^(all_doublers)`
- All-counter scope: `base × 2^(all_doublers)` — applies to -1/-1, custom, +1/+0, +0/+1
- Integrated at ALL counter placement call sites: addPlusOneToAll, addMinusOneToAll, Cathar's Crusade, individual +1/+1, -1/-1, +1/+0, +0/+1, and custom counter edits
- Manual quantity typing bypasses the formula (escape hatch)

**UI** (`lib/widgets/rules_sheet.dart`, `lib/screens/rule_creator_screen.dart`, `lib/widgets/rules_preview_modal.dart`)
- Draggable bottom sheet with two-section layout: Replacements (reorderable) on top, Multipliers (flat) on bottom
- Full-screen rule creator with trigger picker (5 types), effect editor, token search integration
- Dynamic preview modal detecting trigger categories from enabled rules
- Sticky preview at top of rules sheet, tappable for detailed breakdown
- Quantity dialog shows per-token breakdown ("3 Food + 3 Treasure + 3 Clue")

**Integration** (all token creation entry points)
- Token Search, Custom Token, Quick-Add (tap + long-press), Scute Swarm, Krenko — all route through rules engine
- Companion tokens handled properly: stack merging, artwork resolution (preferences → database fallback → download), summoning sickness, ETB events
- `TokenCreationService` (`lib/services/token_creation_service.dart`) — shared companion token creation logic
- Split Stack, Copy Token, Deck Load correctly bypass rules
- Academy Manufactor hardcoded utility code removed from TokenProvider (preset rule replaces it)
- Board wipe gains "Delete All & Reset Rules" option

**Migration**
- Old `tokenMultiplier` auto-converted: power-of-2 → doubler count, other → custom rule
- Old `counterMultiplier` migrated similarly
- Silent SnackBar notification on first launch after migration
- Old SharedPreferences keys cleared after successful migration
- If tokenRules box wiped during resilient boot, migration flag cleared for re-run

**Entry Point**
- MultiplierView FAB replaced with rules entry point showing smart label + dot badge when rules active

### Files Created
- `lib/models/token_rule.dart` (+.g.dart)
- `lib/models/rule_trigger.dart` (+.g.dart)
- `lib/models/rule_outcome.dart` (+.g.dart)
- `lib/providers/rules_provider.dart`
- `lib/widgets/rules_sheet.dart`
- `lib/screens/rule_creator_screen.dart`
- `lib/widgets/rules_preview_modal.dart`
- `lib/services/token_creation_service.dart`

### Files Modified
- `lib/utils/constants.dart`, `lib/database/hive_setup.dart`, `lib/main.dart`
- `lib/screens/content_screen.dart`, `lib/widgets/multiplier_view.dart`
- `lib/screens/token_search_screen.dart`, `lib/widgets/new_token_sheet.dart`
- `lib/widgets/token_card.dart`, `lib/providers/token_provider.dart`
- `lib/screens/expanded_token_screen.dart`, `lib/widgets/tracker_widget_card.dart`
- `lib/database/token_database.dart`, `lib/providers/settings_provider.dart`
- `pubspec.yaml` (added `collection` dependency)

### Known Deviations from Spec (Intentional)
- Academy Manufactor board utility card kept (delegates to rules engine internally)
- Quick-add companion notification uses SnackBar (not custom fade-in/out widget)
- Academy Manufactor handles all three token types bidirectionally (more correct than spec's Food-only trigger)

---

## Testing Checklist

### Rules Sheet UI
- [ ] Tapping the calculator FAB opens the rules sheet
- [ ] Dot badge appears on FAB when any rule is enabled
- [ ] Dot badge disappears when all rules disabled
- [ ] Preset quantity steppers increment/decrement correctly
- [ ] Stepper `-` disabled at 0, `+` disabled at 10
- [ ] Academy Manufactor toggle enables/disables
- [ ] Counter modifier section expands/collapses
- [ ] Counter modifier shows correct summary when collapsed
- [ ] Sticky preview updates live when toggling/adjusting presets
- [ ] Tapping sticky preview opens detailed preview modal
- [ ] Preview modal shows correct per-trigger-category breakdown

### Custom Rules
- [ ] "Add Custom Rule" opens full-screen creator
- [ ] Can set rule name
- [ ] Trigger dropdown shows all 5 types (any token, has P/T, token type, color, specific token)
- [ ] Selecting "specific token" trigger opens token search picker
- [ ] Selecting "color" shows color buttons
- [ ] Selecting "token type" shows type chips
- [ ] Can add multiple effects per rule
- [ ] Can delete individual effects
- [ ] Multiply effect has number input
- [ ] Also-create effect has quantity input + token picker
- [ ] Save validation: name required, at least one effect, also-create needs token
- [ ] Created rule appears in correct section (also-create → Replacements, multiply → Multipliers)
- [ ] Can tap a custom rule to edit it
- [ ] Can swipe to delete a custom rule
- [ ] Can toggle a custom rule enabled/disabled
- [ ] Can drag-reorder custom rules in Replacements section

### Token Doublers (Presets)
- [ ] Set Token Doublers to 1 → creating 1 token produces 2
- [ ] Set Token Doublers to 2 → creating 1 token produces 4
- [ ] Set Token Doublers to 3 → creating 1 token produces 8
- [ ] Doubling Season at 1 → tokens doubled AND counters doubled
- [ ] Primal Vigor at 1 → tokens doubled AND +1/+1 counters doubled (not custom counters)
- [ ] Ojer Taq at 1 → creature tokens tripled, non-creature tokens unaffected
- [ ] Ojer Taq + Token Doublers → creature tokens get ×6 (2×3)
- [ ] Multiple preset types active simultaneously produce correct combined result

### Academy Manufactor
- [ ] Enable Academy Manufactor → creating 1 Food also creates 1 Treasure + 1 Clue
- [ ] Creating 1 Treasure also creates 1 Food + 1 Clue
- [ ] Creating 1 Clue also creates 1 Food + 1 Treasure
- [ ] Academy Manufactor + Token Doublers(1): 1 Food → 2 Food + 2 Treasure + 2 Clue
- [ ] Companion tokens appear as board items with correct artwork
- [ ] Companion tokens merge into existing stacks when matching stack exists

### Counter Modifier
- [ ] Hardened Scales (Extra +1): placing 1 +1/+1 → 2 counters
- [ ] Branching Evolution (Doubler): placing 1 +1/+1 → 2 counters
- [ ] Hardened Scales + Branching Evolution: 1 +1/+1 → (1+1)×2 = 4
- [ ] Doubling Season: 1 +1/+1 → 2 (all-counter scope applies)
- [ ] Hardened Scales + Doubling Season: 1 +1/+1 → (1+1)×2 = 4
- [ ] Vorinclex (All-Counter Doubler): 1 charge counter → 2
- [ ] Hardened Scales + Vorinclex: 1 charge counter → 1 (plus-one scope doesn't apply to non-+1/+1)
- [ ] -1/-1 counters only affected by all-counter scope
- [ ] +1/+1 Everything applies counter formula
- [ ] -1/-1 Everything applies counter formula
- [ ] Individual +1/+1 edit in expanded screen applies formula
- [ ] Individual -1/-1 edit in expanded screen applies formula
- [ ] Individual +1/+0 edit applies all-counter formula
- [ ] Individual +0/+1 edit applies all-counter formula
- [ ] Custom counter edit (charge, loyalty) applies all-counter formula
- [ ] Cathar's Crusade counter placement applies formula

### Token Creation Entry Points
- [ ] Token Search → quantity dialog → rules applied, preview shows breakdown
- [ ] Custom Token (New Token Sheet) → rules applied, preview shows breakdown
- [ ] Quick-add tap (+) → rules applied, companion notification shown
- [ ] Quick-add long-press (+10) → rules applied
- [ ] Scute Swarm doubling → rules applied, companions created
- [ ] Krenko goblin creation → rules applied, companions created
- [ ] Split Stack → rules NOT applied
- [ ] Copy Token → rules NOT applied
- [ ] Deck Load → rules NOT applied
- [ ] Manual quantity edit (typing a number) → rules NOT applied (bypass)

### Quantity Cap
- [ ] Set extreme doublers (e.g., 10 Token Doublers = ×1024) and create tokens
- [ ] If quantity exceeds 999,999, alert modal appears with correct message
- [ ] Tokens are capped at 999,999 despite higher calculated value

### Rule Ordering
- [ ] Academy Manufactor ABOVE Doubling Season: 1 Food → 2 Food + 2 Treasure + 2 Clue
- [ ] Doubling Season ABOVE Academy Manufactor: 1 Food → 2 Food + 1 Treasure + 1 Clue
- [ ] Reordering rules updates preview immediately

### Migration
- [ ] Fresh install: no migration notification, rules sheet is empty
- [ ] Upgrade from old multiplier=4: notification "Your multiplier has been converted to token rules", Token Doublers set to 2
- [ ] Upgrade from old multiplier=6: custom rule "Migrated ×6" created
- [ ] Old tokenMultiplier/counterMultiplier keys cleared after migration

### Board Wipe
- [ ] Standard board wipe clears tokens, rules stay active
- [ ] "Delete All & Reset Rules" clears tokens AND disables all rules
- [ ] Rules sheet confirms rules are disabled after reset wipe

### Persistence
- [ ] Rules persist after app restart
- [ ] Preset values persist after app restart
- [ ] Custom rules persist after app restart
- [ ] Enable/disable state persists

### Summoning Sickness
- [ ] Companion creature tokens get summoning sickness when setting is enabled
- [ ] Non-creature companion tokens (Treasure, Food, Clue) do NOT get summoning sickness

### Artwork
- [ ] Companion tokens show artwork from database
- [ ] Companion tokens respect user artwork preferences
- [ ] Artwork downloads in background without blocking creation

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

**Quantity scaling:** "Also create" outcomes scale proportionally to the triggering quantity. Creating 3 Food with Academy Manufactor active produces 3 Food + 3 Treasure + 3 Clue (per MTG rules, each token creation triggers independently).

Outcomes that reference a token use the token database to resolve the exact TokenDefinition, ensuring correct name, P/T, colors, abilities, and type. Token definitions are referenced by composite ID (`name|pt|colors|type|abilities`) and re-resolved from the database at runtime.

**Identity case:** When no enabled rules exist (or the rule list is empty), the rules engine returns the input unchanged — quantity in = quantity out. This is equivalent to multiplier = 1.

**Note:** Counter modification does NOT use the rules engine. See [Counter Modifier](#counter-modifier) below for the simpler handler.

#### UI Home

The advanced token calculator lives at the **existing multiplier entry point** in the FAB menu. Tapping it opens the rules management screen (sheets/modals as needed). This replaces the current multiplier UI entirely.

#### Preview

The rules screen shows a **calculated preview** — a dry-run of `evaluateRules()` that shows what *would* happen, without creating tokens. It recalculates whenever a rule is toggled, reordered, or edited.

**Default preview (sticky at top of rules sheet):** Shows the result for a generic token:
> "1 token → 4 tokens" (if two doublers are active)

**Conditional previews:** When rules are conditional on specific token types, the sticky summary is styled as tappable (visually indicating interactivity). Tapping opens a **preview modal** showing one row per distinct trigger category present in the enabled rules:
> "Whenever you make **a token**: 1 token = 4 tokens"
> "Whenever you make **a Food**: 1 Food = 4 Food + 1 Treasure + 1 Clue"
> "Whenever you make **a Squirrel**: 1 Squirrel = 8 tokens + 1 Squirrel"

**Quantity dialog preview:** Shown inline in the quantity dialog before "Create" is tapped (replaces the current "Final amount will be X" text). Lists every token that will be created with the actual selected token and quantity — e.g., "3 Food + 3 Treasure + 3 Clue", not a collapsed total.

#### Persistence & Lifecycle

- Rules persist across app launches (not tied to a game session)
- Rules survive board wipes — they represent the user's card effects, not board state
- Users can enable/disable rules without deleting them (e.g., disable a rule when a permanent leaves the battlefield, re-enable if it comes back)

#### Preset Rules (Well-Known Cards)

Well-known cards are **hardcoded preset rules** grouped by shared behavior. Cards that do the exact same thing are listed together under one rule with a **quantity** value (e.g., "Token Doublers: 2" means two ×2 effects active = ×4 total). This avoids redundant UI entries for cards with identical rules.

Each rule has a quantity. The quantity determines how many times that rule's effect applies: 2 doublers = ×4, 3 doublers = ×8, etc.

**Token presets:**

| Preset | Cards (grouped by identical effect) | Trigger | Outcome | Quantity = |
|--------|-------------------------------------|---------|---------|------------|
| **Token Doublers** | Parallel Lives, Anointed Procession, Mondrak, Adrix and Nev, Elspeth Storm Slayer, Exalted Sunborn | Any token | Multiply ×2 | Number of these cards in play |
| **Doubling Season** | Doubling Season | Any token | Multiply tokens ×2 + Multiply all counters ×2 | Own entry (has counter effect too) |
| **Primal Vigor** | Primal Vigor | Any token | Multiply tokens ×2 + Multiply +1/+1 counters ×2 | Own entry (has counter effect too) |
| **Ojer Taq** | Ojer Taq, Deepest Foundation | Token with P/T | Multiply ×3 | Own entry (unique multiplier) |
| **Academy Manufactor** | Academy Manufactor | Food | Also create 1 Treasure + 1 Clue | Own entry (unique outcome) |

**Counter presets:**

| Preset | Cards (grouped by identical effect) | Scope | Outcome | Quantity = |
|--------|-------------------------------------|-------|---------|------------|
| **+1/+1 Doublers** | Branching Evolution, Corpsejack Menace, The Earth Crystal | +1/+1 only | Multiply ×2 | Number of these cards in play |
| **+1/+1 Extra** | Hardened Scales, Conclave Mentor, High Score, Ozolith the Shattered Spire, Michelangelo | +1/+1 only | +1 additional | Number of these cards in play |
| **All-Counter Doublers** | Vorinclex, Innkeeper's Talent L3, Loading Zone | All counters | Multiply ×2 | Number of these cards in play |

**Shared presets:** Doubling Season and Primal Vigor have their own entries because they span both token and counter effects. Enabling "Doubling Season" activates token doubling AND all-counter doubling from one control.

**Custom rules:** Users can create custom rules using the same trigger/outcome model for cards not in the preset list or for homebrew effects. Custom rules support arbitrary multiplier values (×2, ×3, ×5, etc.) and arbitrary quantities.

#### Example Custom Rules

| Rule Name | Trigger | Outcomes |
|-----------|---------|----------|
| "My Doubler" | Any token | Multiply by 2 |
| "Creature Tripler" | Token with P/T | Multiply by 3 |
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

**Rules list structure enforces ordering:** The two-section layout (replacements on top, multipliers on bottom) ensures "also create" rules are always evaluated before multipliers by construction. No auto-ordering logic needed — the UI structure itself gives the rules-accurate result. Users can reorder within the replacements section; the preview updates live as rules are reordered.

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

Counter presets follow the same grouping model as token presets — cards with identical effects are grouped with a quantity value.

See token presets section above for the full grouped list. The counter-relevant groups are:
- **+1/+1 Doublers** (Branching Evolution, Corpsejack Menace, The Earth Crystal) — quantity = number in play
- **+1/+1 Extra** (Hardened Scales, Conclave Mentor, High Score, Ozolith the Shattered Spire, Michelangelo) — quantity = number in play
- **All-Counter Doublers** (Vorinclex, Innkeeper's Talent L3, Loading Zone) — quantity = number in play
- **Doubling Season** — own entry (token doubling + all-counter doubling from one control)
- **Primal Vigor** — own entry (token doubling + +1/+1 counter doubling from one control)

#### Counter Types and -1/-1 Behavior

- **+1/+1 counters:** Modified by both +1/+1 scope AND all-counter scope
- **-1/-1 counters:** Modified by all-counter scope ONLY. The +1/+1 scope (doublers and extra) does not apply. In MTG, Doubling Season doubles all counters YOU place, including -1/-1 on your own creatures — this is rules-accurate but potentially surprising.
- **Custom counters** (charge, loyalty, etc.): Modified by all-counter scope only. Same as -1/-1.

#### Integration Points

The counter modifier must be applied at **ALL counter placement call sites**, not just the ones the user interacts with directly:

| Call Site | Current Behavior | With Counter Modifier |
|---|---|---|
| **+1/+1 Everything** (`addPlusOneToAll`) | Hardcoded `addPowerToughnessCounters(1)` | Apply formula: `(1 + extra) × 2^doublers` |
| **Cathar's Crusade** (GameEvents ETB) | `token.plusOneCounters += triggerCount` | Apply formula to `triggerCount` before adding |
| **Individual +1/+1 edits** (expanded token screen) | Direct increment | Apply formula to the increment |
| **Individual custom counter edits** | Direct increment | Apply all-counter formula only |
| **Manual quantity typing** | Direct set | **Bypass** — no modifier (matches token rules bypass principle) |

**Cathar's Crusade interaction:** Cathar's Crusade INITIATES counter placement (triggered ability). The counter modifier MODIFIES the counters being placed (replacement effect). These are different layers that stack. Example: Cathar's Crusade fires for 3 creatures entering, with Hardened Scales + Doubling Season active → each creature gets `(3 + 1) × 2 = 8` counters.

**ETB count for Cathar's Crusade:** When token rules double token creation (e.g., Doubling Season doubles 1 Soldier to 2), Cathar's Crusade fires based on the FINAL token count after rules evaluation. Doubling Season doubles 1 Soldier to 2 → Cathar's sees 2 creatures entering.

#### UI

The counter modifier settings live alongside the token rules in the same screen (accessed from the FAB multiplier entry point). Presented as a collapsible section (collapsed by default, showing a one-line summary like "+1/+1: ×2 + 1 extra"). Since counters are just two pairs of numbers (doublers + extra for each scope), this is a compact section — no need for a full rule list.

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
- **Counter modifier**: Separate, simpler handler — not the full rules engine. Two scopes (+1/+1 only vs. all counters), each with a doublers count and an extra count. Formula: `(base + extra) × 2^doublers`. Applies to ALL counter placement call sites (addPlusOneToAll, Cathar's Crusade, individual edits). -1/-1 and custom counters go through all-counter scope only.
- **Preset grouping**: Cards with identical effects are grouped under one preset with a quantity value (e.g., "Token Doublers: 3" = Parallel Lives + Anointed Procession + Mondrak). Cards with unique multi-effect rules (Doubling Season, Primal Vigor) get their own entries.
- **Rules list structure**: Two sections — replacements (top, user-reorderable) and multipliers (bottom, flat non-reorderable list). Structure enforces correct evaluation order by construction. No auto-ordering logic needed.
- **UI home**: Lives at the existing multiplier entry point in the FAB menu. Replaces the multiplier UI. Draggable bottom sheet (not full screen). Rule creator is full-screen dialog.
- **Preview**: Calculated preview (dry-run of evaluateRules) shows result of creating 1 token. Sticky summary on rules sheet is tappable — opens modal with per-trigger-category breakdowns. Quantity dialog shows full token list for actual selected token and quantity.
- **Quantity scaling**: "Also create" outcomes scale proportionally to the triggering quantity (3 Food → 3 Treasure + 3 Clue).
- **Identity case**: No enabled rules = quantity in = quantity out (equivalent to multiplier=1).
- **Companion stacking**: Companion tokens add to existing board stacks when a matching stack exists.
- **TypeIds**: 10, 11, 12 (8 and 9 are taken by TrackerWidgetTemplate/ToggleWidgetTemplate).

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

**Migration:** Existing users with a multiplier > 1 will need a one-time migration:
- Power-of-2 values decompose into doubler rules (e.g., multiplier=8 → Token Doublers quantity = 3)
- Non-power-of-2 values (3, 5, 6, etc.) become a single custom rule with the exact multiplier value (e.g., multiplier=6 → custom rule "any token → ×6")
- The `counterMultiplier` SharedPreferences key (already in use in `token_card.dart` for the +1/+1 button) must also be migrated to the counter modifier system
- Migration runs in `RulesProvider.init()`. The old SharedPreferences keys are kept as backup until confirmed successful migration, then cleared on next launch. If the rules box is wiped during resilient boot, migration re-runs from the backup keys.
- Silent migration with a SnackBar notification: "Your ×N multiplier has been converted to token rules." No blocking dialog. If multiplier was 1 (default), skip the notification.

### Existing Utility Overlap

| Current Utility | Disposition | Reasoning |
|---|---|---|
| **Academy Manufactor** (`createAcademyManufactorTokens`) | **Migrates to rules engine** | Academy Manufactor is a replacement effect — exactly the kind of thing this feature models. It was implemented as a standalone utility only because the rules engine didn't exist yet. It should become a rule: "When creating a Food → also create 1 Treasure + 1 Clue." The hardcoded utility code in TokenProvider will be removed. |
| **Krenko** (`createGoblinToken`) | **Stays as utility** | Krenko's ability ("tap: create goblins equal to goblin count") depends on board state (counting existing goblins). This is an activated ability, not a replacement effect — it doesn't modify token creation, it initiates it based on a board-state query. The rules engine's condition/outcome model doesn't cover this. Krenko remains a standalone utility. |
| **Cathar's Crusade** (via GameEvents) | **Stays as utility** | Cathar's Crusade is a triggered ability ("whenever a creature enters, put a +1/+1 counter on each creature you control"), not a replacement effect on counter placement. The counter rules in the calculator handle "when counters are being placed, modify how many" — not "trigger counter placement from ETB events." Cathar's Crusade initiates counter placement; Hardened Scales/Doubling Season modify it. Different layer. |

### Data Model Needs

New Hive models required. **TypeIds 8 and 9 are already taken** by `TrackerWidgetTemplate` and `ToggleWidgetTemplate` in `constants.dart`. Next available is **10**.

```
TokenRule       (typeId: 10) — name, enabled, order, trigger, outcomes
RuleTrigger     (typeId: 11) — triggerType, targetTokenId (composite ID string), targetType, targetColor
RuleOutcome     (typeId: 12) — outcomeType (multiply|also_create), multiplier, targetTokenId, quantity
```

Three new type IDs, one new Hive box (`tokenRules`). `RuleTrigger` and `RuleOutcome` are nested inside `TokenRule` (same pattern as `TokenCounter` inside `Item` and `TokenTemplate` inside `Deck`) — they don't get their own boxes.

All new fields need `defaultValue` per existing schema rules (v1.7→v1.8 deck-loss bug).

**Preset storage:** Preset rules are computed at runtime (always available, never corrupted). Only the enabled/disabled state and quantity per preset is persisted (SharedPreferences or a lightweight Hive field). Custom rules are stored in the `tokenRules` Hive box.

**Resilient boot:** The `tokenRules` box must be added to `hive_setup.dart` using `_openBoxResilient()`, included in the backup list, and handled in web init. If the box corrupts and is wiped, the app functions with zero rules (identity transformation).

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
Rules reference TokenDefinitions from the 913-token database. The rule creator UI needs a token search/picker (reuse `TokenSearchScreen` in selector mode — it already returns a `TokenDefinition` via `Navigator.pop()`). This ensures the correct token gets created with proper P/T, colors, abilities, and artwork.

### Execution Flow

Per MTG rule 614.16, replacement effects apply to tokens created by other replacement effects. Our engine models this by having companion tokens evaluate against **remaining rules below** the one that created them — never re-entering from the top.

When the user creates tokens through the normal flow (TokenSearchScreen → quantity → create):
1. Rules engine receives the token creation intent (token + quantity)
2. Enabled rules are evaluated **top-down in list order**
3. Each matching **multiply** rule adjusts the quantity of the triggering token
4. Each matching **also-create** rule queues companion tokens (scaled proportionally to triggering quantity) — these companions then continue evaluation from the **next rule down** (not from the top)
5. After all rules are evaluated: insert the original token and all companion tokens with their final quantities
6. **Companion stacking:** If a companion token matches an existing stack on the board (same composite ID), add to that stack instead of creating a duplicate

### Implementation Notes

**Scute Swarm and Krenko bypass `insertItem()`.** Both `createScuteSwarmTokens()` and `createGoblinToken()` in `token_provider.dart` manage amounts directly and write to Hive without going through a centralized creation pipeline. Both must be refactored to route their output through `RulesProvider.evaluateRules()` before setting final quantities.

**Quick-add creates companions.** When "+" on a Food card triggers an Academy Manufactor rule, the Food stack increases AND new Treasure/Clue stacks appear (or existing ones increment). Notification appears as a fade-in/out text box (1 second fade, contained to text — NOT a sliding snackbar): "Created X Tokens — why?" Tapping the notification opens a modal summary listing everything created with type breakdown. Large numbers use 1k/1m notation. For multiply-only rules (just doublers), the "+" silently adds the modified quantity with no notification. **This fade-in/out text box style is the app-wide standard for all transient notifications.**

**Academy Manufactor utility migration.** The hardcoded `createAcademyManufactorTokens()` utility code in TokenProvider will be removed and the Academy Manufactor preset rule replaces it. Communication to users is handled by the "What's New in [version]" modal (see `todo_features/new_version_modal.md`) — release notes explain that Academy Manufactor is now available in the advanced token calculator. If an existing user still has an Academy Manufactor utility card on the board, standard Hive resilient boot handles orphaned data gracefully.

**Rules-active indicator.** The FAB button shows a simple dot badge when any rule is enabled. No number, no label — just a visual cue that rules are active, driving users to check their rules. Hidden when all rules are disabled or the rule list is empty.

**Board wipe and rules.** The board wipe dialog gains a second option: "Wipe everything, reset rules" which clears the board AND disables all rules. The existing board wipe option remains as-is (clears board, rules stay active). No post-wipe notification needed.

**Summoning sickness on companion tokens.** Companion tokens created by "also create" rules follow the same summoning sickness logic as any new creature token: applied if the setting is enabled AND the token has P/T AND doesn't have haste. No exceptions for rule-created tokens.

**Artwork for companion tokens.** All tokens created by the rules engine — both the original and companions — must follow the same artwork determination and download path as the main token creation flow (TokenSearchScreen). The Academy Manufactor utility has a known bug where companion token artwork doesn't render correctly on first creation; this is because it bypasses the standard artwork flow. The rules engine must not repeat this mistake. Reference Krenko's `createGoblinToken()` for the correct pattern (it loads the token definition from the database and downloads artwork in the background).

**Long-press quick-add.** Long-press on "+" currently adds 10×multiplier. With the rules engine, it adds 10 through `evaluateRules()` — same as tap, just with a larger base quantity. This is consistent with the rules engine being a full replacement for the multiplier. All quick-add paths (tap and long-press) route through the rules engine.

### UI Architecture

**Rules sheet:** Draggable bottom sheet (not full screen) — users toggle rules mid-game and need the board visible. Pull up to full screen for more space. Matches existing `showModalBottomSheet` pattern.

**Rule creator:** Full-screen dialog (`MaterialPageRoute(fullscreenDialog: true)`) — matches `NewTokenSheet` pattern. Single scrollable page: name → trigger picker → effects list → save.

- **Trigger picker:** Dropdown selects matcher type (specific token definition, creature/has P/T, token type, color, any token). Area below the dropdown adapts to the selection: token search picker for definitions, color buttons for color, type picker for type (artifact, enchantment, named subtype), nothing extra for creature or any token.
- **Effect editor:** Each effect has a dropdown for type (multiply / also create), a number input for the value, and (for also-create) a token search picker for the companion token. "+ Effect" button adds another effect to the rule. Swipe-to-delete removes individual effects.

**Rules list:** Two-section layout in the rules sheet. **Top section: Replacements** — user-reorderable `ReorderableListView` containing "also create" rules (presets and custom). **Bottom section: Multipliers** — flat, non-reorderable list of multiply rules. Both sections: presets show a badge, custom rules show edit/delete, all have leading `Switch` for toggle.

**Preview placement:** Sticky at top of rules sheet, styled as tappable — opens conditional preview modal. Quantity dialog shows full creation list inline.

**Counter modifier:** Collapsible `ExpansionTile` inside the rules sheet, below the token rules list. Shows one-line summary when collapsed.

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
