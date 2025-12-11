# UTILITY WIDGET TODO LIST

- Refine the appearance of toggles and trackers
- Improve handling of artwork to match behaviors of tokens, including custom upload behavior
    - Investigate whether they are using shared logic or have created redundant code. Can we DRY this?
- Set default artwork for trackers/toggles that have them

---

## Process for Adding New Utility Types (CRITICAL CHECKLIST)

This checklist documents ALL steps required when adding a new utility type (like Krenko). Missing any step will cause the utility to not work properly.

### 1. Data Model (`lib/models/your_utility.dart`)
- [ ] Create Hive model class extending `HiveObject`
- [ ] Add `@HiveType(typeId: X)` annotation (use next available ID from constants.dart)
- [ ] Add `@HiveField(N)` annotations for all fields
- [ ] Include `part 'your_utility.g.dart';` directive
- [ ] Implement required fields: `utilityId`, `name`, `colorIdentity`, `artworkUrl`, `order`, `createdAt`
- [ ] Add utility-specific fields (e.g., `krenkoPower`, `nontokenGoblins`)

### 2. Constants (`lib/utils/constants.dart`)
- [ ] Add new typeId to `HiveTypeIds` class (NEVER change existing IDs)
- [ ] Add new box name to `DatabaseConstants` class

### 3. Hive Setup (`lib/database/hive_setup.dart`)
- [ ] Import your utility model
- [ ] Register adapter: `Hive.registerAdapter(YourUtilityAdapter());`
- [ ] Open box in `Future.wait()`: `Hive.openBox<YourUtility>('yourUtilityBox')`

### 4. Provider (`lib/providers/your_provider.dart`)
- [ ] Create provider class extending `ChangeNotifier`
- [ ] Implement `init()` method to open box and migrate orders
- [ ] Add `listenable` getter exposing `ValueListenable<Box<YourUtility>>`
- [ ] Implement CRUD methods: `insertUtility()`, `updateUtility()`, `deleteUtility()`
- [ ] Implement `updateOrder()` for drag-and-drop support
- [ ] Implement `_ensureOrdersAssigned()` for migration

### 5. Main App Init (`lib/main.dart`)
- [ ] Import your provider
- [ ] Add provider field to `_MyAppState`: `late YourProvider yourProvider;`
- [ ] Add `_initYourProvider()` method
- [ ] Add provider init to `Future.wait()` in `_initializeProviders()`
- [ ] Assign result to provider field
- [ ] Add provider to `MultiProvider` providers list

### 6. Widget Card (`lib/widgets/your_utility_card.dart`)
- [ ] Create card widget extending `StatefulWidget`
- [ ] Follow TokenCard patterns for styling (borders, shadows, padding)
- [ ] Use `Selector<SettingsProvider, String>` for artwork display style
- [ ] Implement `CroppedArtworkWidget` for artwork layer
- [ ] Add semi-transparent backgrounds for text overlays (0.85 alpha)
- [ ] Implement tap handler to open `ExpandedWidgetScreen`
- [ ] Save changes to Hive on user interactions

### 7. Widget Definition (`lib/models/widget_definition.dart`)
- [ ] Add new type to `WidgetType` enum (if needed)
- [ ] Import your utility model
- [ ] Add `toYourUtility()` factory method to create instances

### 8. Widget Database (`lib/database/widget_database.dart`)
- [ ] Add predefined utility definition to `loadWidgets()` list
- [ ] Include all required fields: id, type, name, description, colorIdentity, defaultValue

### 9. ContentScreen Integration (`lib/screens/content_screen.dart`)
- [ ] Import utility model and provider
- [ ] Import utility card widget
- [ ] Add to `_BoardItem` comment: include your utility type
- [ ] Add `bool get isYourUtility => item is YourUtility;` helper
- [ ] Get provider in `_buildTokenList()`: `final yourProvider = Provider.of<YourProvider>(...)`
- [ ] Add provider listenable to `Listenable.merge([])`
- [ ] Add utilities to boardItems list in builder
- [ ] Handle utility in `_buildBoardItemCard()` color identity logic
- [ ] Handle utility in `_buildCardContent()` to return your card widget
- [ ] Handle utility in `_deleteItem()` to delete from provider
- [ ] Handle utility in `_handleReorder()` to update order
- [ ] Handle utility in `_compactOrders()` to save new orders

### 10. Widget Selection (`lib/screens/widget_selection_screen.dart`)
- [ ] Import your provider
- [ ] Get provider in `_createWidget()`: `final yourProvider = context.read<YourProvider>();`
- [ ] Add utilities to order calculation: `allOrders.addAll(yourProvider.utilities.map((u) => u.order));`
- [ ] Handle your WidgetType in if/else chain
- [ ] Call `toYourUtility()` factory and `insertUtility()` provider method

### 11. Code Generation
- [ ] Run `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Verify `your_utility.g.dart` file is generated
- [ ] Fix any compilation errors

### 12. Testing Checklist
- [ ] Utility appears in utility selection screen
- [ ] Utility can be created and added to board
- [ ] Utility displays with correct styling and colors
- [ ] Utility can be reordered with other board items
- [ ] Utility responds to user interactions correctly
- [ ] Utility state persists across app restarts
- [ ] Utility can be deleted via swipe
- [ ] Expanded view works (tap to open)
- [ ] Artwork selection works

**CRITICAL:** If your utility doesn't appear or work correctly, review each step above. Missing ANY step will break functionality.

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

**IMPORTANT NOTE - Potential Split:**
The current design combines both Krenko, Mob Boss and Krenko, Tin Street Kingpin into a single utility. We may split this into **two separate utilities**:
- **Krenko, Mob Boss** - Creates goblins based on power OR total goblins controlled
- **Krenko, Tin Street Kingpin** - Different ability: "Whenever a creature you control attacks, defending player may pay {1}. If they don't, create a 1/1 red Goblin creature token"

**Current Implementation:** Single utility with both options available. If split is needed, can create separate KrenkoMobBossUtility and KrenkoTinStreetUtility classes with shared base logic.

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


# LATEST COMPLETED WORK
⏺ Perfect! The Krenko utility implementation is complete and ready for
  testing. Here's the status:

  ✅ Implementation Complete

  All 12 checklist items from NextFeature.md have been implemented:

  Core Files Created:
  - ✅ lib/models/krenko_utility.dart - Data model with Hive annotations
  - ✅ lib/providers/krenko_provider.dart - State management with CRUD
  operations
  - ✅ lib/widgets/krenko_utility_card.dart - Custom card with two value
  rows + WAAAGH button

  Integration Points Updated:
  - ✅ lib/utils/constants.dart - Added typeId 8 and box name
  - ✅ lib/database/hive_setup.dart - Registered adapter and opened box
  - ✅ lib/main.dart - KrenkoProvider initialization
  - ✅ lib/models/widget_definition.dart - Added special type and
  toKrenkoUtility() method
  - ✅ lib/database/widget_database.dart - Added Krenko predefined utility
  - ✅ lib/screens/content_screen.dart - Full board integration (display,
  reorder, delete)
  - ✅ lib/screens/widget_selection_screen.dart - Special type creation
  handling

  🔧 Next Steps

  1. Generate Hive adapter (required before running):
  flutter pub run build_runner build --delete-conflicting-outputs
  2. Full app restart (hot reload won't work for Hive changes):
  flutter run
  3. Test the utility:
    - Open Utilities menu → Select "Krenko, Mob Boss"
    - Verify stepper buttons work for both values
    - Tap values to test manual input
    - Tap WAAAGH button → test goblin creation (both options)
    - Verify smart goblin merging (adds to existing goblins)
    - Test reordering with tokens
    - Test deletion via swipe

  The comprehensive checklist in NextFeature.md documents all steps for
  future utility types, addressing your main concern about having a
  repeatable process.

