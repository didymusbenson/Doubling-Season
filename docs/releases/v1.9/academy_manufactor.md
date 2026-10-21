# Feature: Academy Manufactor Utility

**Status:** Implemented
**Card:** Academy Manufactor (MH2)

---

## What It Is

Academy Manufactor is a **Utility** (internal: TrackerWidget with `actionType: 'academy_manufactor'`) displayed on the game board. It represents owning one or more copies of the Academy Manufactor card during gameplay.

---

## Card Rules Text

> "If you would create a Clue, Food, or Treasure token, instead create one of each."

### The Math

Layering order: **event → Manufactor replacement → doublers.**

| Copies (N) | Per-type multiplier |
|------------|-------------------|
| 1 | 1× (3^0) |
| 2 | 3× (3^1) |
| 3 | 9× (3^2) |
| N | 3^(N-1) |

Formula: **tokens of each type = app_multiplier × 3^(N-1)**

The `3^(N-1)` comes from the cascade of replacement effects — each Clue/Food/Treasure being created gets replaced by one of each, and this cascades N-1 times. The app multiplier (Doubling Season, etc.) is applied after Manufactor math.

---

## Implementation Summary

### Data Model
- Uses existing `TrackerWidget` model (typeId: 6) — no new Hive type
- `hasAction: true`, `actionButtonText: 'Make Tokens'`, `actionType: 'academy_manufactor'`
- `defaultValue: 1` (starts with 1 copy), minimum 0
- Colorless (`colorIdentity: ''`)
- Same pattern as Krenko Mob Boss and Cathar's Crusade

### Behavior
- Value tracks number of Academy Manufactor copies (increase/decrease, no death triggers)
- At value 0: "Make Tokens" disabled, card greyed out (0.4 opacity)
- "Make Tokens" shows confirmation dialog with:
  - Headline: "Creating X Food, Treasure, and Clue tokens"
  - Breakdown: Academy Manufactors count, Token Multiplier value
  - Confirm and Cancel buttons
- On confirm: creates Clue, Food, and Treasure tokens from database definitions
- Each type checks for existing stack without counters first — adds to it if found, creates new if not
- Artifacts have no P/T — no summoning sickness, no GameEvents.notifyCreatureEntered
- Artwork downloaded to local cache after token creation (fire-and-forget)

### Artwork
- Two variants baked into WidgetDefinition:
  - SLD (default): `https://cards.scryfall.io/large/front/5/f/5f0d37b6-c092-439b-ba8e-e297ad35f155.jpg?1758777214`
  - MH2: `https://cards.scryfall.io/large/front/b/6/b67c27f1-12d1-4c48-9e22-31c43a9ecbbc.jpg?1681082373`

---

## Files Changed

| File | Change |
|------|--------|
| `lib/database/widget_database.dart` | Added Academy Manufactor WidgetDefinition entry |
| `lib/widgets/tracker_widget_card.dart` | Added `case 'academy_manufactor'` + `_performAcademyManufactorAction()`, greyed-out state at value 0, `dart:math` import for `pow` |
| `lib/providers/token_provider.dart` | Added `createAcademyManufactorTokens()` with caches for Clue/Food/Treasure definitions, existing-stack consolidation, artwork download. Also fixed pre-existing Krenko artwork download bug. |

### Bugfix included
- **Krenko goblin artwork download**: `createKrenkoGoblins` was setting Scryfall URLs on new tokens without downloading them to local cache. Added fire-and-forget artwork download (same fix applied to Academy Manufactor). Both Krenko variants (Mob Boss, Tin Street Kingpin) share the same creation method so both are fixed.
