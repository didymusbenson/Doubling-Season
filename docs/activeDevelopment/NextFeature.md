# UTILITY WIDGET TODO LIST

- Refine the appearance of toggles and trackers
- Improve handling of artwork to match behaviors of tokens, including custom upload behavior
    - Investigate whether they are using shared logic or have created redundant code. Can we DRY this?
- Set default artwork for trackers/toggles that have them

---

## Krenko, Mob Boss Utility (Special Utility Type)

### Overview
A special utility widget for Krenko, Mob Boss Commander decks. Provides quick goblin token generation based on Krenko's power and battlefield goblin count. Unlike standard trackers/toggles, this is a **button-action utility** with custom card layout and behavior.

**Magic Context:** Krenko, Mob Boss has the ability _"Tap: Create X 1/1 red Goblin creature tokens, where X is the number of Goblins you control."_

### Utility Card Layout

**Type:** Special utility (UtilityType.special)
**Color Identity:** R (Red)
**Name:** "Krenko, Mob Boss"
**Reorderable:** Yes (can be dragged among tokens/utilities in ContentScreen)

**Card Structure (similar to TrackerUtilityCard but custom):**
```
┌─────────────────────────────────────┐
│ Krenko, Mob Boss            [Red]   │ ← Name + color border
├─────────────────────────────────────┤
│ Krenko's Power:    [3]    [-] [+]   │ ← Editable value with steppers
│ Nontoken Goblins:  [1]    [-] [+]   │ ← Editable value with steppers
│                                      │
│         [    WAAAGH!    ]            │ ← Primary action button (red)
└─────────────────────────────────────┘
```

**Components:**
1. **Krenko's Power** - Editable numeric value (default: 3)
   - Stepper buttons: -1 / +1
   - Tap value to edit manually (numeric keyboard)
   - Range: 1-99
   - Persisted in Hive with utility instance

2. **Nontoken Goblins** - Editable numeric value (default: 1)
   - Counts non-token goblins on battlefield (Krenko himself + others)
   - Stepper buttons: -1 / +1
   - Tap value to edit manually (numeric keyboard)
   - Range: 0-99
   - Persisted in Hive with utility instance

3. **WAAAGH! Button** - Primary action button
   - Style: Red background (matches Krenko color identity)
   - Full width, prominent
   - Opens confirmation dialog (see below)

### Tap Behavior

**Tap card background:** Opens ExpandedUtilityScreen (for artwork selection/delete)
**Tap stepper buttons:** Increment/decrement values by 1
**Tap numeric values:** Open manual input dialog (numeric keyboard)
**Tap WAAAGH! button:** Open goblin creation confirmation dialog

### WAAAGH! Confirmation Dialog

**Title:** "Create Goblin Tokens"

**Body text:** Display both calculated amounts:
- "Krenko's Power: [X] goblins (Power × Multiplier)"
- "All Goblins: [Y] goblins (Total Goblins × Multiplier)"

**Three buttons:**

1. **"Create [X] Goblins"** (based on Krenko's Power)
   - Calculation: `krenkoPower × globalMultiplier`
   - Example: Power = 5, Multiplier = 2 → Creates 10 goblins
   - Label dynamically updates with calculated amount

2. **"Create [Y] Goblins"** (based on all goblins controlled)
   - Calculation: `(totalTokenGoblins + nontokenGoblins) × globalMultiplier`
   - Counts all tokens with "goblin" in type (case-insensitive substring match)
   - Example: 8 token goblins + 2 nontoken = 10, Multiplier = 1 → Creates 10 goblins
   - Label dynamically updates with calculated amount

3. **"Cancel"** - Dismiss dialog without action

**Dialog Style:**
- Standard AlertDialog
- Red accent color (matches Krenko theme)
- Buttons stack vertically for clarity
- Show real-time calculations in button labels

### Token Creation Logic

**Standard Goblin Token:**
- Name: "Goblin"
- Power/Toughness: "1/1"
- Colors: "R" (Red)
- Type: "Creature — Goblin"
- Abilities: "" (empty)

**Smart Token Merging:**
If matching goblin token already exists on board:
- Search criteria: name="Goblin", pt="1/1", colors="R", type contains "Goblin", abilities=""
- If found: Add to existing token's amount (don't create duplicate card)
- If multiple matches: Add to first match (shouldn't happen with standard goblins)

If no match exists:
- Create new token card with standard goblin definition
- Set amount to calculated value
- Insert into token list with standard ordering

**Summoning Sickness:**
- Apply if global summoning sickness setting is enabled
- Set `summoningSick = amount` on creation
- Applied to newly created goblins only (not existing tokens being merged into)

**Goblin Counting Logic (Option 2):**
```dart
// Count all tokens with "goblin" in type (case-insensitive)
int tokenGoblinCount = 0;
for (final item in tokenProvider.items) {
  final type = item.type?.toLowerCase() ?? '';
  if (type.contains('goblin')) {
    tokenGoblinCount += item.amount;
  }
}

// Add nontoken goblins from Krenko utility
final nontokenGoblins = krenkoUtility.nontokenGoblins;
final totalGoblins = tokenGoblinCount + nontokenGoblins;

// Apply global multiplier
final multiplier = settingsProvider.tokenMultiplier;
final goblinsToCreate = totalGoblins * multiplier;
```

**Type Matching Examples:**
- "Creature — Goblin" ✅
- "Creature — Goblin Warrior" ✅
- "Artifact Creature — Goblin" ✅
- "Creature — Elf" ❌

### Data Model

```dart
@HiveType(typeId: 8) // Next available typeId
class KrenkoUtility extends HiveObject {
  @HiveField(0) String utilityId;
  @HiveField(1) String name; // "Krenko, Mob Boss"
  @HiveField(2) String colorIdentity; // "R"
  @HiveField(3) String? artworkUrl;
  @HiveField(4) double order;
  @HiveField(5) DateTime createdAt;
  @HiveField(6) int krenkoPower; // Default: 3
  @HiveField(7) int nontokenGoblins; // Default: 1
  @HiveField(8) bool isCustom; // false for predefined Krenko
}
```

### Implementation Notes

**Custom Card Widget:**
- Create `KrenkoUtilityCard extends StatefulWidget` (not BaseUtilityCard)
- Custom layout with two rows of steppers + action button
- Follows TokenCard styling (borders, shadows, padding)
- Red color theme throughout

**Provider:**
- Option A: Add to existing TrackerProvider/ToggleProvider with type union
- Option B: Create dedicated `KrenkoProvider` (cleaner separation)
- Recommendation: Option A for simplicity, as it's a single special utility

**Widget Database:**
```dart
WidgetDefinition(
  id: 'krenko_mob_boss',
  type: WidgetType.special,
  name: 'Krenko, Mob Boss',
  description: 'Tap to create goblin tokens based on Krenko\'s power or goblins controlled.',
  colorIdentity: 'R',
  defaultValue: 3, // Krenko's base power
  // Special fields for Krenko-specific data
)
```

**Expanded View:**
- Use ExpandedUtilityScreen (standard utility expanded view)
- Shows name (read-only), no description field
- Artwork selection works (same as other utilities)
- Delete button functional
- No special controls needed (all editing on compact card)

### Future Considerations

**Other Krenko Cards:**
This design focuses on **Krenko, Mob Boss**. For **Krenko, Street Kingpin** or other Krenko variants:
- Could extend KrenkoUtility with `krenkoType` enum
- Different button actions based on card
- For now: Implement Mob Boss only, design allows future expansion

**Similar Commander Utilities:**
This pattern could apply to other commander-specific tools:
- Rhys the Redeemed (doubles all tokens)
- Brudiclad (converts all tokens to chosen type)
- Pattern: Special utility with custom card layout + action button(s)

### Success Criteria

- [ ] Krenko utility can be added from utility selection screen
- [ ] Card displays with two editable values and WAAAGH! button
- [ ] Stepper buttons increment/decrement values correctly
- [ ] Tap values to edit manually with numeric keyboard
- [ ] WAAAGH! button opens dialog with calculated amounts
- [ ] Option 1 (Krenko's Power) creates correct number of goblins
- [ ] Option 2 (All Goblins) counts token goblins correctly + applies multiplier
- [ ] Smart merging: New goblins add to existing goblin tokens
- [ ] Summoning sickness applied when setting enabled
- [ ] Utility can be reordered with tokens/other utilities
- [ ] Expanded view works (artwork selection, delete)
- [ ] State persists across app restarts
- [ ] Red color theme consistent throughout
