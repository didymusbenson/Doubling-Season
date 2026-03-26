# Enters Tapped Toggle

## Overview

Add the ability to control whether tokens enter the battlefield tapped. This should work at two levels:

1. **Global setting** — A toggle (likely in the settings menu) that makes all tokens enter tapped by default.
2. **Per-token override** — A toggle on the expanded token screen that overrides the global setting for that specific token stack (e.g., "Enters Tapped: Yes/No").

## Implementation Scope

### Global Setting
- New `entersTapped` boolean in `SettingsProvider` (SharedPreferences)
- UI toggle in the settings dialog (follows existing `SwitchListTile` pattern like summoning sickness)
- Applied during token creation — after `insertItem()`, set `tapped = finalAmount` if enabled

### Per-Token Override
- New `entersTapped` field on the `Item` model (Hive)
- UI toggle on `ExpandedTokenScreen`
- Overrides the global setting for that specific token stack when adding more tokens

### Creation Flow Changes
- Affects `insertItem`, `addTokens`, `copyToken`, `createScuteSwarmTokens`, `createKrenkoGoblins`, and any other token creation paths
- Logic: check per-token override first, fall back to global setting

---

## Clarifying Questions

### Data Model
1. **What type should the per-token field be?** A nullable bool (`bool? entersTapped`) with three states (null = follow global, true = always tapped, false = always untapped) vs a simple bool that just mirrors or overrides the global? The tri-state approach is more flexible but adds UI complexity.
2. **New HiveField index** — What is the next available HiveField index on `Item`? Need to confirm before adding the field, and it must have `defaultValue: null` for migration safety.

### Interaction with Existing Features
3. **How does this interact with summoning sickness?** If a token enters tapped AND has summoning sickness, are both applied? Or does entering tapped imply it "already attacked" and shouldn't have sickness?
4. **Does "enters tapped" apply to tokens added to an existing stack (via the + button)?** Or only to newly created token stacks? The `addTokens` flow increases `amount` on an existing item — should those added tokens be auto-tapped too?
5. **Does copying a token (copy button) respect the enters-tapped setting?** Currently copies inherit the parent's tapped state.
6. **Emblems** — Emblems don't have tapped/untapped state. Should the toggle be hidden for emblem items? (Probably yes, matching how summoning sickness is hidden for emblems.)

### UX / UI
7. **Where exactly does the global toggle go?** In the existing settings dialog (alongside summoning sickness, theme, etc.)? Or somewhere more prominent since it affects every token creation?
8. **Per-token UI placement** — Where on the expanded token screen should this toggle appear? Near the tapped/untapped controls? As a switch or a segmented control?
9. **Should the per-token toggle be visible even when the global setting is off?** i.e., can a user say "this specific token always enters tapped" regardless of the global default?
10. **Visual indicator on the token card?** Should there be any indication on the compact card view that a token has "enters tapped" set? Or is it purely a behind-the-scenes behavior?

### Edge Cases
11. **Deck save/load** — `TokenTemplate` is used for deck persistence. Should `entersTapped` be saved as part of the deck template so it persists across save/load?
12. **Split stack** — When splitting a stack, should the new stack inherit the `entersTapped` override from the original?
13. **Board wipe / clear** — No impact expected, but worth confirming the field resets properly on new token creation after a wipe.
