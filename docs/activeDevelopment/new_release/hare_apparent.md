# Hare Apparent Utility

## Status: Implemented, pending acceptance testing

## Card Reference

**Hare Apparent** — {1}{W}, Creature — Rabbit Noble, 2/2 (Foundations #15)

> When this creature enters, create a number of 1/1 white Rabbit creature tokens equal to the number of other creatures you control named Hare Apparent. A deck can have any number of cards named Hare Apparent.

## What the Utility Does

Tracks the number of Hare Apparents the player currently controls. When the player casts a new Hare Apparent, they press the **New Hare** button — the utility increments the tracker, then creates 1/1 white Rabbit tokens equal to the number of *other* Hare Apparents already on the battlefield.

Growth pattern (no doublers active):

| Press # | Tracker before | Tracker after | Rabbits created | Cumulative rabbits |
|---------|----------------|---------------|-----------------|--------------------|
| 0 (default) | —        | 1             | —               | 0                  |
| 1       | 1              | 2             | 1               | 1                  |
| 2       | 2              | 3             | 2               | 3                  |
| 3       | 3              | 4             | 3               | 6                  |
| N       | N              | N+1           | N               | N(N+1)/2           |

**This is cumulative quadratic growth, not per-trigger multiplicative.** Only the newly-entered Hare's ETB trigger fires — the existing ones already resolved their triggers when they entered. External multipliers (Token Doublers, Doubling Season, Anointed Procession, Chatterfang, etc.) layer on via the rules engine.

## Configuration

| Field | Value |
|-------|-------|
| `id` | `hare_apparent` |
| `type` | `WidgetType.special` |
| `name` | `Hare Apparent` |
| `description` | `Hare Apparents you control` |
| `colorIdentity` | `W` |
| `defaultValue` | `1` (player assumed to have one on board when adding the utility) |
| `hasAction` | `true` |
| `actionButtonText` | `New Hare` |
| `actionType` | `hare_apparent` |
| Artwork | Single FDN variant: `https://cards.scryfall.io/large/front/9/f/9fc6f0e9-eb5f-4bc0-b3d7-756644b66d12.jpg?1730488646` |

## Action Flow (`_performHareApparentAction`)

1. Increment `currentValue` by 1 (new Hare entered), persist via `TrackerProvider.updateTracker`.
2. Compute `rabbitsToCreate = currentValue - 1`. If ≤ 0, short-circuit (first Hare's ETB makes nothing).
3. Call `rulesProvider.evaluateRules('Rabbit', '1/1', 'W', 'Creature — Rabbit', '', rabbitsToCreate)` so doublers and companion rules (Chatterfang, custom rules) apply.
4. Compute `nextOrder` across tokens + trackers + toggles.
5. `TokenCreationService.createAllFromResults(...)` creates all peer results — merges into existing stacks, resolves artwork via preferences, downloads in background, fires ETB events through `insertItem`.

**No confirmation dialog** — the press-to-create progression is predictable (N rabbits on press N+1), unlike Krenko/Academy Manufactor which can spawn large batches unexpectedly. Can revisit if fine-tuning surfaces a need.

## Rabbit Token Reference

Composite ID in `assets/token_database.json`: `Rabbit|1/1|W|Creature — Rabbit|` (empty abilities). Three artwork variants bundled. The user's artwork preference for the Rabbit identity applies automatically through `TokenCreationService`.

## Files Touched

- `lib/database/widget_database.dart` — added `WidgetDefinition` for `hare_apparent`.
- `lib/widgets/tracker_widget_card.dart` — added `'hare_apparent'` case to `_performAction` switch and new `_performHareApparentAction` method.

## Known Behavior / Fine-Tune Candidates

- Manual tracker control: the ± buttons and the big-number tap-to-edit dialog still work as expected, so the user can correct counts when a Hare dies, is exiled, is bounced, etc.
- No dialog: if users find the auto-action jarring, consider adding a "Creating N rabbits (Y → Y+1 Hares)" confirm like Krenko/AM.
- Artwork: only one FDN variant; add more printings if the user wants options in the artwork selection sheet.
