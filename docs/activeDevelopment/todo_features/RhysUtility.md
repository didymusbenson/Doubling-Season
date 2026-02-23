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

For every `Item` on the board that is a creature (has P/T, is not an emblem):
- Create a new `Item` that copies: name, pt, colors, type, abilities, artwork fields
- The new stack's `amount` = original stack's `amount` × multiplier
- Apply summoning sickness to the new copies if the setting is enabled
- New stacks should be inserted adjacent to their source (fractional order, same pattern as Scute Swarm)
- +1/+1 and -1/-1 counters are NOT copied (they represent modifications to the original, not the base token)
- Custom counters are NOT copied

### Token Database Match

Rhys's first ability creates an Elf Warrior token already in the database:
- **Name:** Elf Warrior
- **P/T:** 1/1
- **Colors:** GW
- **Type:** Creature — Elf Warrior
- **Artwork:** Available from 2XM and SHM sets

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
- For each, call a new `TokenProvider` method to create the copy
- May want a confirmation dialog since this could create many tokens at once

### 4. Provider Method (`lib/providers/token_provider.dart`)

Add `duplicateAllCreatureTokens()` or `performRhysPopulate()`:
- Snapshot the current token list (avoid iterating over a mutating list)
- For each creature token, create a new `Item` copying base fields
- Insert with fractional order placement
- Apply summoning sickness after insert (existing two-step pattern)
- Fire ETB events for Cathar's Crusade integration

## Clarifying Questions

### Behavior
1. **Does the multiplier apply?** When duplicating, should each copy stack's amount be `original.amount * multiplier` or just `original.amount`? The card says "create a token that's a copy" per creature token you control — the multiplier simulates Doubling Season/Parallel Lives, so it probably should apply.
2. ~~**Should the tracker value be used for anything?**~~ **Resolved:** No tracker value — Rhys is action-only.
3. ~~**Action-only layout**~~ **Resolved:** Option B — new `actionOnly` HiveField on TrackerWidget with `defaultValue: false`.
4. **Confirmation dialog?** With many creature tokens on board, a single tap could create dozens of new stacks. Should there be a confirmation showing how many tokens will be created?

### Copying Details
5. **Tapped state** — Should copies enter untapped (matching the card's behavior — new tokens enter untapped) regardless of whether the original is tapped?
6. **Existing copies** — If the user activates Rhys twice, the second activation should also copy the tokens created by the first activation (they are creature tokens too). Is this the expected behavior, or should there be any dedup?
7. **Non-token creatures** — The card says "creature token," so it only copies tokens. In our app, everything on the board is a token. Should all creatures be copied, or should there be any filtering?
8. **Utility widgets on board** — TrackerWidgets and ToggleWidgets on the board are not creature tokens. Confirm these are naturally excluded (they should be, since we'd iterate `TokenProvider.items` only).

### UI
9. ~~**Button count**~~ **Resolved:** No +/- buttons. Action button only — just "Copy Tokens".
10. **Action button disabled state** — Should "Copy Tokens" be disabled when there are no creature tokens on the board? (Academy Manufactor disables when its value is 0.)
