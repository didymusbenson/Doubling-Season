# Feature: Academy Manufactor Utility

**Status:** In Progress — Requirements / Design
**Card:** Academy Manufactor (MH2)

---

## What It Is

Academy Manufactor is a **Utility** (internal: widget) displayed on the game board like TrackerWidget/ToggleWidget. It represents owning one or more copies of the Academy Manufactor card during gameplay.

---

## Card Rules Text

> "If you would create a Clue, Food, or Treasure token, instead create one of each."

### Official Rulings (2021-06-18)

> If you control **one** Academy Manufactor and would create some number of Clue, Food, or Treasure tokens, you will instead create **that many** Clue tokens, **that many** Food tokens, and **that many** Treasure tokens.

> If you control **two** Academy Manufactors and would create some number of Clue, Food, or Treasure tokens, you will instead create **three times that many** Clue, **three times that many** Food, and **three times that many** Treasure tokens.

> If you control **eighteen** Academy Manufactors, you will instead create **129,140,163 times that many** of each.

### The Math

The multiplier per "copy count" N follows the pattern:

| Copies (N) | Per-type multiplier |
|------------|-------------------|
| 1 | 1× (3^0) |
| 2 | 3× (3^1) |
| 3 | 9× (3^2) |
| N | 3^(N-1) |

Formula: **tokens of each type = app_multiplier × 3^(N-1)**

where `N` = the utility's value (number of copies), and `app_multiplier` = the global multiplier setting.

---

## Core Behavior

### The Utility Card

- Displays on the board alongside tokens and other utilities
- Has a **value field**: the number of copies of Academy Manufactor the player controls (minimum 1, since having 0 means you'd remove the utility)
- Increasing/decreasing the value does **NOT** trigger death triggers — this is a card, not a token
- No tapped/untapped state (it's a permanent, but tapping isn't relevant to this utility's tracking purpose)

### "Make Tokens" Action

Pressing **"Make Tokens"** simulates ONE Academy Manufactor trigger firing:
- Creates `app_multiplier × 3^(N-1)` **Clue** tokens
- Creates `app_multiplier × 3^(N-1)` **Food** tokens
- Creates `app_multiplier × 3^(N-1)` **Treasure** tokens

These tokens are added to the board as standard `Item` entries, looked up from the token database by name.

**Note from rules:** Creating a Clue this way is NOT the same as investigating. The Manufactor's replacement effect creates Clue tokens directly — it doesn't trigger "whenever you investigate" abilities. This is flavor context and doesn't affect app behavior, but documents why the trigger count is always 1.

---

## Token Lookup

Clue, Food, and Treasure all have definitions in `assets/token_database.json`. The implementation should look these up by name to get the correct P/T, abilities, and type — same pattern as any token creation flow.

---

## Open Questions / Design Decisions Needed

### 1. Multiplier Interaction — Where Does App Multiplier Apply?

**✅ RESOLVED:** Formula is `app_multiplier × 3^(N-1)` per token type per button press.

Layering order: **event → Manufactor → doublers.**

- **Event:** Button press triggers creation of 1 Clue.
- **Manufactor (replacement):** Each Clue/Food/Treasure being created gets replaced by one of each — this cascades N-1 times, resulting in `3^(N-1)` of each type. The `3^(N-1)` factor comes from the cascade of replacements, not a simple multiplier.
- **Doublers (app_multiplier):** Applied after Manufactor math to the output, yielding `app_multiplier × 3^(N-1)` of each type.

---

### 2. Minimum Value — Can You Have 0 Copies?

**✅ RESOLVED:** Minimum value is 0. At 0, the "Make Tokens" button is disabled and the card gets the greyed-out treatment (same visual as a token at 0 count). The utility stays on the board — the player removes it manually if they want it gone.

---

### 3. Data Model — New Type or Extend TrackerWidget?

**✅ RESOLVED:** Use the existing `TrackerWidget` model with `hasAction: true`, `actionButtonText: 'Make Tokens'`, and `actionType: 'academy_manufactor'`.

This is exactly how Krenko and Cathar's Crusade are implemented. The `actionType` string dispatches to the correct behavior in the UI/provider layer. No new Hive model needed.

---

### 4. What Happens to Existing Clue/Food/Treasure Tokens on the Board?

**✅ RESOLVED:** Match Krenko's pattern — for each of the three token types (Clue, Food, Treasure), check for an existing stack without counters first. If found, add to it. If not, create a new stack. This runs independently for each type, so you may end up adding to some existing stacks and creating new ones for others.

---

### 5. Summoning Sickness on Created Tokens?

Clue, Food, and Treasure are artifact tokens — they have no power/toughness. Summoning sickness only applies when `hasPowerToughness` is true, so this should be a non-issue automatically. Confirm this is handled correctly by the existing token creation flow.

**Non-decision (probably):** Verify the existing creation logic handles this edge case correctly.

---

### 6. Visual Design — Where Does "Make Tokens" Live?

**✅ RESOLVED:** Inline on the card, matching Krenko's pattern. In `tracker_widget_card.dart`, action trackers display their action button directly in the card body alongside the +/- controls. The user can trigger the action without opening the expanded view. Academy Manufactor follows the same layout.

---

### 7. What Does the Utility Card Look Like?

**✅ RESOLVED:** Standard action tracker layout (value + controls + action button), matching Krenko. No live preview on the card itself.

On button press, a **confirmation dialog** appears showing:
- Headline: "Creating X Food, Treasure, and Clue tokens" (where X = `app_multiplier × 3^(N-1)`)
- Breakdown of effects:
  - Academy Manufactors — [N]
  - Token Multiplier — [M]

This follows the Krenko confirmation pattern but adds an effects breakdown so the user can see how the count was calculated before confirming. Dialog has Confirm and Cancel buttons.

---

### 8. Artwork?

**✅ RESOLVED:** Yes, artwork supported. Two variants available:

| Set | URL | Default? |
|-----|-----|----------|
| SLD | `https://cards.scryfall.io/large/front/5/f/5f0d37b6-c092-439b-ba8e-e297ad35f155.jpg?1758777214` | **Yes** |
| MH2 | `https://cards.scryfall.io/large/front/b/6/b67c27f1-12d1-4c48-9e22-31c43a9ecbbc.jpg?1681082373` | No |

These should be baked into the `WidgetDefinition` in `widget_database.dart` as `ArtworkVariant` entries, with SLD listed first (default).

---

## Files Likely Involved

| File | Change |
|------|--------|
| `lib/models/academy_manufactor_widget.dart` | New Hive model (if Option A) |
| `lib/utils/constants.dart` | Add typeId: 8 |
| `lib/database/hive_setup.dart` | Register new model |
| `lib/screens/content_screen.dart` | Render new utility type in board list |
| `lib/widgets/academy_manufactor_card.dart` | New card widget |
| `lib/database/token_database.dart` | Lookup Clue/Food/Treasure by name |
| `lib/providers/token_provider.dart` | Token creation on button press |
