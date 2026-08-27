# Hare Apparent Utility

## Status: Reworked to Krenko-style flow, pending acceptance testing

## Card Reference

**Hare Apparent** — {1}{W}, Creature — Rabbit Noble, 2/2 (Foundations #15)

> When this creature enters, create a number of 1/1 white Rabbit creature tokens equal to the number of other creatures you control named Hare Apparent. A deck can have any number of cards named Hare Apparent.

## What the Utility Does

Tracks the number of Hare Apparents the player currently controls. **The count is fully manual** — the player sets it with the existing +/− stepper buttons (or the tap-to-edit big-number dialog) on the utility card. The action no longer auto-increments the count.

When a new Hare Apparent enters the battlefield, the player:

1. Steps the Hare Apparent count up by 1 (manual stepper) to reflect the Hare that just entered.
2. Presses **Make Rabbits**, which shows a confirmation popup, and on confirm creates 1/1 white Rabbit tokens equal to the number of *other* Hare Apparents (`count − 1`).

This mirrors the **Krenko, Mob Boss** flow exactly: the user owns the count via the stepper, the action button is a deliberate "Make Rabbits" press, and a confirmation dialog previews the amount (with rules-engine modifiers already applied) before anything is created.

Growth pattern (no doublers active), assuming the user steps the count up by 1 before each Make Rabbits press:

| Count (after manual step) | Other Hare Apparents | Rabbits created | Cumulative rabbits |
|---------------------------|----------------------|-----------------|--------------------|
| 1 (default)               | 0                    | 0 (info popup)  | 0                  |
| 2                         | 1                    | 1               | 1                  |
| 3                         | 2                    | 2               | 3                  |
| 4                         | 3                    | 3               | 6                  |
| N                         | N−1                  | N−1             | N(N−1)/2           |

**This is cumulative quadratic growth, not per-trigger multiplicative.** Only the newly-entered Hare's ETB trigger fires — the existing ones already resolved their triggers when they entered. External multipliers (Token Doublers, Doubling Season, Anointed Procession, Chatterfang, etc.) layer on via the rules engine and are reflected in the confirmation popup's previewed amount.

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
| `actionButtonText` | `Make Rabbits` |
| `actionType` | `hare_apparent` |
| Artwork | Single FDN variant: `https://cards.scryfall.io/large/front/9/f/9fc6f0e9-eb5f-4bc0-b3d7-756644b66d12.jpg?1730488646` |

## Action Flow (`_performHareApparentAction`)

1. Read the manually-controlled `currentValue` (number of Hare Apparents the user controls). **No auto-increment.**
2. Compute `rabbitsToCreate = currentValue − 1` (other Hare Apparents).
3. If `≤ 0`, show an informational dialog explaining that a new Hare needs at least one *other* Hare Apparent to make Rabbits, and to use the +/− buttons to set the count. Then return — nothing is created.
4. Call `rulesProvider.evaluateRules('Rabbit', '1/1', 'W', 'Creature — Rabbit', '', rabbitsToCreate)` so doublers and companion rules (Chatterfang, custom rules) apply. Take `results.first.quantity` as the post-rules Rabbit amount for the preview.
5. Show a confirmation popup (same style as Krenko's "Create Goblin Tokens"): shows the other-Hare count and the post-rules Rabbit total, with Cancel / "Create N Rabbits" actions.
6. On Cancel (or dismiss), return — nothing is created.
7. On confirm, compute `nextOrder` across all board items (tokens + trackers + toggles).
8. `TokenCreationService.createAllFromResults(...)` creates all peer results — merges into existing stacks, resolves artwork via preferences, downloads in background, fires ETB events through `insertItem` (identical artwork / summoning-sickness path to Krenko's companion creation).

**Confirmation dialog now present** — matches Krenko/Academy Manufactor. The count is manual, so the action is a deliberate, confirmed batch creation rather than a press-to-progress auto-action.

## Rabbit Token Reference

Composite ID in `assets/token_database.json`: `Rabbit|1/1|W|Creature — Rabbit|` (empty abilities). Three artwork variants bundled. The user's artwork preference for the Rabbit identity applies automatically through `TokenCreationService`.

## Files Touched

- `lib/database/widget_database.dart` — `actionButtonText` changed from `New Hare` to `Make Rabbits` for the `hare_apparent` definition.
- `lib/widgets/tracker_widget_card.dart` — `_performHareApparentAction` reworked: removed auto-increment, added the ≤0 info dialog and the Krenko-style confirmation popup, routed creation through the rules engine + `TokenCreationService` on confirm only.

## Migration Note

`actionButtonText` is copied onto the persisted `TrackerWidget` when the utility is first added to the board (via `WidgetDefinition.toTrackerWidget`). Users who already placed the Hare Apparent utility before this change will still see the old **New Hare** label until they remove and re-add the utility. The *behavior* is driven by `actionType` (`hare_apparent`, unchanged), so the new confirmation flow applies to all users immediately regardless of the displayed label. No Hive typeId/box changes; no schema migration required.

## Testing Checklist

Mark each item once verified in a live build. All unchecked — this is a fresh behavior.

- [ ] Adding the Hare Apparent utility from the selection screen shows the action button labeled **Make Rabbits** (fresh add, not a pre-existing tracker).
- [ ] The +/− stepper buttons change the Hare Apparent count and the count is NOT auto-incremented when pressing Make Rabbits.
- [ ] The tap-to-edit big-number dialog still sets the count manually and persists.
- [ ] With count = 1 (default), pressing Make Rabbits shows an informational popup (no Rabbits created, no count change).
- [ ] With count = 0, pressing Make Rabbits shows the same informational popup (no Rabbits created).
- [ ] With count = 2, pressing Make Rabbits opens a confirmation popup previewing **1 rabbit**; Cancel creates nothing.
- [ ] Confirming the popup at count = 2 creates exactly 1 Rabbit token (1/1 white Rabbit) and the count stays at 2.
- [ ] With count = 4, the confirmation popup previews **3 rabbits**; confirming creates 3 Rabbits and the count stays at 4.
- [ ] Pressing Make Rabbits multiple times (manually stepping the count up between presses) yields cumulative quadratic growth (e.g. count 2→1 rabbit, step to 3→2 rabbits, step to 4→3 rabbits; cumulative 1, 3, 6).
- [ ] Dismissing the confirmation popup by tapping outside / back gesture creates nothing.
- [ ] Created Rabbit tokens merge into an existing matching Rabbit stack (no counters) instead of creating duplicate stacks.
- [ ] Rules engine routing: with a Token Doubler / Doubling Season / Anointed Procession active, the confirmation popup preview AND the created amount reflect the doubled count.
- [ ] Rules engine routing: with Chatterfang (or a custom companion rule) active, companion tokens are also created alongside the Rabbits.
- [ ] Created Rabbit tokens display the correct artwork (respecting the user's saved Rabbit artwork preference if set, otherwise the default bundled variant); artwork downloads in the background and the card does not stay blank.
- [ ] Created Rabbit tokens get summoning sickness when the summoning sickness setting is enabled (and none when disabled).
- [ ] Created Rabbit tokens are ordered after existing board items (appear at the bottom / newest position).
- [ ] ETB-dependent utilities (e.g. Cathar's Crusade trigger count) respond to the newly created Rabbits.
- [ ] No "New Hare" auto-increment behavior remains anywhere (verify the old one-press-creates-and-increments flow is gone).
