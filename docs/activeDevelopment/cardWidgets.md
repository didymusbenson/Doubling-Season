# Commander Widgets (Card Widgets for Commanders)

## Overview
**Commander Widgets** (also called "Card Widgets") are special cards that appear in the token list alongside regular tokens. They provide specialized tracking and controls for popular token-generating commanders.

Unlike the initial "Krenko Mode" concept (which used a fixed banner), widgets are **fully integrated into the token list** - they can be added, removed, reordered, and swiped away just like tokens.

---

## Krenko Widget (First Implementation)

### Overview
The Krenko widget is a special card for players using **Krenko, Mob Boss** in Commander. It provides quick goblin token generation based on Krenko's power and the number of goblins controlled.

**Magic Context:** Krenko, Mob Boss has the ability "Tap: Create X 1/1 red Goblin creature tokens, where X is the number of Goblins you control."

### Adding the Krenko Widget

**User Flow:**
1. Player opens FAB menu → Widgets
2. Widget selection sheet shows available widgets
3. Player taps "Krenko, Mob Boss"
4. Krenko widget card appears at **top of token list**
5. Widget can be dragged to reorder or swiped away to remove

### Krenko Widget Card

**Location:** IN the token list (not fixed above it)

**Layout:** Card design similar to TokenCard, but with custom Krenko controls

**Contains:**
- **Title:** "Krenko, Mob Boss" with Krenko icon
  - Distinguished with red color theme
  - Shows this is a widget card, not a token

- **"Krenko's Power"** - Stepper with inline input (range: 1-99)
  - Starts at 3 (Krenko's base power)
  - User can +/- with stepper or tap to enter manually
  - Persisted in widget state (Hive)

- **"Nontoken Goblins"** - Stepper with inline input (range: 0-99)
  - Represents non-token goblins on battlefield (Krenko himself, other creatures)
  - User can +/- with stepper or tap to enter manually
  - Persisted in widget state (Hive)

- **"Waaagh!" Button** - Primary action button
  - Opens confirmation dialog with two goblin creation options
  - Style: Red color theme

**Visual Design:**
- Card background: Same as TokenCard (cardColor)
- Red accent/border to distinguish from tokens
- Similar height to token cards (compact but functional)
- Can be reordered by dragging
- Can be dismissed by swiping left

### Waaagh! Confirmation Dialog

**Triggered by:** Tapping "Waaagh!" button in Krenko widget card

**Dialog Title:** "Create Goblin Tokens"

**Two Options (buttons):**

1. **"Krenko's Power" Button**
   - Label: "Create [X] Goblins" (where X = Krenko's Power × Global Multiplier)
   - Action: Create X 1/1 Red Goblin tokens
   - Example: If power = 5, multiplier = 2, creates 10 goblins

2. **"For Each Goblin You Control" Button**
   - Label: "Create [Y] Goblins" (where Y = (Total Token Goblins + Nontoken Goblins) × Global Multiplier)
   - Action: Count all goblin tokens, add nontoken count, multiply, create that many 1/1 Red Goblin tokens
   - Example: If you have 8 token goblins + 2 nontoken = 10, multiplier = 1, creates 10 goblins
   - Shows breakdown: "(8 token + 2 nontoken = 10 goblins)"

**Cancel:** Standard dialog close button (X) or tap outside

**Dialog Style:**
- Standard AlertDialog with red accent
- Show calculated amounts in button labels (dynamic)
- Buttons stack vertically for clarity

### Token Creation Logic

#### Standard Goblin Token Definition
**Name:** "Goblin"
**Power/Toughness:** "1/1"
**Colors:** "R" (Red)
**Type:** "Creature - Goblin"
**Abilities:** "" (empty)

#### Token Creation Behavior

**If matching token already exists:**
- Search for existing token with:
  - name = "Goblin"
  - pt = "1/1"
  - colors = "R"
  - type contains "Goblin"
  - abilities = "" (empty)
- If found: Add to that token's amount (don't create new card)
- If multiple matches: Add to first match (shouldn't happen with standard goblin)

**If no matching token exists:**
- Create new token card with standard goblin definition
- Set amount to calculated value
- Insert into token list

**Summoning Sickness:**
- Apply if global summoning sickness setting is enabled
- Set `summoningSick = amount` on creation

#### Calculation Details

**Option 1: Krenko's Power**
```dart
final krenkosPower = settingsProvider.krenkoPower; // e.g., 5
final multiplier = settingsProvider.tokenMultiplier; // e.g., 2
final goblinsToCreate = krenkosPower * multiplier; // = 10
```

**Option 2: For Each Goblin You Control**
```dart
// Step 1: Count all tokens with "Goblin" in type
int tokenGoblinCount = 0;
for (final item in tokenProvider.items) {
  if (item.type.toLowerCase().contains('goblin')) {
    tokenGoblinCount += item.amount; // Sum all goblin token amounts
  }
}

// Step 2: Add nontoken goblins
final nontokenGoblins = settingsProvider.nontokenGoblins; // e.g., 2
final totalGoblins = tokenGoblinCount + nontokenGoblins; // e.g., 10

// Step 3: Apply multiplier
final multiplier = settingsProvider.tokenMultiplier; // e.g., 1
final goblinsToCreate = totalGoblins * multiplier; // = 10
```

**Important:** Type matching is case-insensitive and substring-based:
- "Creature - Goblin" 
- "Creature - Goblin Warrior" 
- "Artifact Creature - Goblin" 
- "Creature - Elf" 

### Theme Override

#### Red Color Theme
When Krenko Mode is enabled, override blue theme colors with red:

**Components to recolor:**
- **FloatingActionButton** (multiplier, new token, menu)
  - Current: Blue
  - Krenko Mode: Red (use same red as Board Wipe icon)

- **TokenCard borders/accents** (optional - TBD)
  - May keep existing color identity system
  - Or add subtle red accent when Krenko Mode active

- **Krenko Banner**
  - Red accent/border
  - "Waaagh!" button: Red background

**Color Reference:**
- Board Wipe icon uses: `Colors.red` or similar
- Need to identify exact color value in FloatingActionMenu
- Ensure red works in both light and dark modes

**Implementation:**
- Check `settingsProvider.krenkoModeEnabled` in widget builds
- Conditional color selection: `krenkoModeEnabled ? Colors.red : Colors.blue`
- Apply to FABs, primary buttons, accents

### Implementation Notes

#### Settings Provider
Add to `lib/providers/settings_provider.dart`:
```dart
bool get krenkoModeEnabled => _prefs.getBool('krenkoModeEnabled') ?? false;
Future<void> setKrenkoModeEnabled(bool value) async {
  await _prefs.setBool('krenkoModeEnabled', value);
  notifyListeners();
}

int get krenkoPower => _prefs.getInt('krenkoPower') ?? 3;
Future<void> setKrenkoPower(int value) async {
  await _prefs.setInt('krenkoPower', value.clamp(1, 99));
  notifyListeners();
}

int get nontokenGoblins => _prefs.getInt('nontokenGoblins') ?? 0;
Future<void> setNontokenGoblins(int value) async {
  await _prefs.setInt('nontokenGoblins', value.clamp(0, 99));
  notifyListeners();
}
```

#### New Widgets Needed
1. **`KrenkoBanner`** (`lib/widgets/krenko_banner.dart`)
   - Horizontal layout with steppers and button
   - Conditionally rendered in ContentScreen when mode enabled
   - Fixed position at top of token list

2. **`KrenkoDialog`** (`lib/widgets/krenko_dialog.dart`)
   - AlertDialog with three option buttons
   - Calculates goblin counts dynamically
   - Shows calculated amounts in button labels

3. **`InlineStepperField`** (reusable widget)
   - Combines stepper buttons with tap-to-edit number
   - Similar to multiplier input pattern
   - Range validation

#### Token Provider
Add method to `lib/providers/token_provider.dart`:
```dart
Future<void> createOrAddGoblins(int amount, bool applyMultiplier) async {
  final finalAmount = applyMultiplier
      ? amount * settingsProvider.tokenMultiplier
      : amount;

  // Search for existing standard goblin token
  final existingGoblin = items.firstWhereOrNull((item) =>
    item.name == 'Goblin' &&
    item.pt == '1/1' &&
    item.colors == 'R' &&
    item.type.toLowerCase().contains('goblin') &&
    item.abilities.isEmpty
  );

  if (existingGoblin != null) {
    // Add to existing
    existingGoblin.amount += finalAmount;
    await existingGoblin.save();
  } else {
    // Create new
    final newGoblin = Item(
      name: 'Goblin',
      pt: '1/1',
      colors: 'R',
      type: 'Creature - Goblin',
      abilities: '',
      amount: finalAmount,
      // ... other fields
    );
    await insertItem(newGoblin);
  }
}
```

### Questions to Answer (TODO)

- [ ] Should Krenko Banner be collapsible/expandable?
- [ ] Should there be a "reset" button for power/nontoken counts?
- [ ] Do we want a history/counter of how many times Krenko has activated?
- [ ] Should the standard goblin token have artwork auto-assigned?
- [ ] Exact red color value to use (match Board Wipe icon)?
- [ ] Should TokenCard borders get red accent in Krenko Mode, or just FABs?
- [ ] Should we show a summary after creation? ("Created 10 goblins!")
- [ ] Edge case: What if multiplier is set to 1024 and user has 50 goblins? (50k tokens)

### Testing Checklist

- [ ] Toggle Krenko Mode on/off in settings
- [ ] Krenko Banner appears at top of token list when enabled
- [ ] Krenko Banner hidden when mode disabled
- [ ] Stepper +/- buttons work for both fields
- [ ] Tap-to-edit manual input works for both fields
- [ ] Range validation (1-99 for power, 0-99 for nontoken)
- [ ] "Waaagh!" button opens dialog
- [ ] Dialog shows correct calculated amounts (dynamic)
- [ ] "Krenko's Power" creates correct number of goblins
- [ ] "For Each Goblin" counts all token types containing "goblin"
- [ ] "For Each Goblin" includes nontoken count
- [ ] Both options apply global multiplier
- [ ] Existing goblin token gets amount added (not new card)
- [ ] New goblin token created if none exists
- [ ] Summoning sickness applied if enabled
- [ ] FABs change to red when Krenko Mode enabled
- [ ] Colors work in both light and dark mode
- [ ] Values persist across app restarts (SharedPreferences)

**Priority:** Medium-High - Popular commander deck archetype, high user value

---

## Commander Mode (Future Evolution)

### Concept
Replace the single-purpose "Krenko Mode" with a flexible "Commander Mode" system that provides specialized tools for multiple popular token-generating commanders. This allows adding commander-specific features without cluttering the UI for users who don't need them.

### Core UI Structure
**Top Banner** (similar to Krenko Mode banner, but adaptive):
- **Commander Selection Field**: Tap to open commander picker
  - Shows "Select Commander..." when none chosen
  - Shows commander name when selected
  - Opens modal with predefined commander list
- **Commander-Specific Controls**: Dynamic content based on selected commander
  - Krenko: Power stepper + Nontoken Goblins + "Waaagh!" button
  - Chatterfang: (Controls TBD)
  - Rhys: (Controls TBD)
  - Each commander gets custom UI tailored to their mechanics

### Settings Integration
**Location:** Settings screen
- **Toggle:** "Commander Mode" (on/off)
- **Commander Selection:** Dropdown or modal picker showing available commanders
- **Storage:**
  - `commanderModeEnabled` (bool)
  - `selectedCommander` (string, e.g., "krenko", "chatterfang", "rhys")
  - Commander-specific state (e.g., `krenkoPower`, `chatterfangSquirrels`, etc.)

### MVP Commanders

#### 1. Krenko, Mob Boss
**Ability:** "Tap: Create X 1/1 red Goblin creature tokens, where X is the number of Goblins you control."

**Controls:**
- **Krenko's Power** stepper (1-99, default 3)
- **Nontoken Goblins** stepper (0-99, default 0)
- **"Waaagh!" Button**: Creates 1/1 red Goblin tokens
  - Option A: Based on Krenko's power � multiplier
  - Option B: Based on total goblins controlled � multiplier
  - Adds to existing goblin token or creates new

**Color Theme:** Red (matches goblin tribal theme)

**Implementation:** Already documented above - migrate to commander system

---

#### 2. Chatterfang, Squirrel General
**Ability:** "If one or more tokens would be created under your control, those tokens plus that many 1/1 green Squirrel creature tokens are created instead."

**Controls:**
- **Token Being Created** selector (dropdown or text field)
  - User selects/inputs token name and amount
  - Example: "3 Treasure" or "5 Food"
- **"Create with Chatterfang" Button**
  - Creates the original tokens (e.g., 3 Treasure)
  - ALSO creates equal number of 1/1 green Squirrel tokens (3 Squirrels)
  - Applies global multiplier to both types
  - Adds to existing squirrel token or creates new

**Alternative Simpler Approach:**
- **Token Amount** stepper (how many tokens being created)
- **"Add Squirrels" Button**
  - Just creates squirrel tokens equal to amount � multiplier
  - User handles creating other tokens manually
  - Simpler implementation, covers 80% of use cases

**Squirrel Token Definition:**
- Name: "Squirrel"
- P/T: "1/1"
- Colors: "G" (Green)
- Type: "Creature - Squirrel"
- Abilities: ""

**Color Theme:** Green (matches squirrel tribal theme)

**Questions to Answer:**
- [ ] Do we need to track what tokens triggered Chatterfang? (probably not)
- [ ] Should there be a "quick add squirrels" that counts recent tokens? (nice to have)
- [ ] Do we need second ability tracking? ("Each opponent loses 1 life per dying creature token")

---

#### 3. Rhys the Redeemed
**Abilities:**
- **Ability 1:** "{2}{G/W}, Tap: Create a 1/1 green and white Elf Warrior creature token."
- **Ability 2:** "{4}{G/W}{G/W}, Tap: For each creature token you control, create a token that's a copy of that creature."

**Controls:**
- **Ability 1 Button**: "Create Elf Warrior"
  - Creates 1 Elf Warrior � global multiplier
  - Simple token creation

- **Ability 2 Button**: "Double All Tokens" (this is the complex one)
  - For EACH token type on board:
    - Count total amount (including tapped/untapped/summoning sick)
    - Create NEW token card with same properties (name, P/T, abilities, colors, type, counters, artwork)
    - Set amount to original amount � global multiplier
    - Result: Doubles your token count (or more with multiplier)
  - Example: If you have 5 Elves, 3 Goblins, creates 5 new Elves + 3 new Goblins
  - **With multiplier:** If multiplier is 2, creates 10 Elves + 6 Goblins (quadruples!)

**Elf Warrior Token Definition:**
- Name: "Elf Warrior"
- P/T: "1/1"
- Colors: "GW" (Green/White)
- Type: "Creature - Elf Warrior"
- Abilities: ""

**Color Theme:** Green/White (matches Selesnya tokens theme)

**Implementation Complexity:** HIGH
- Ability 2 requires deep-copying all token properties
- Must handle counters, artwork, abilities, everything
- Need to clarify: Do copied tokens enter tapped? (probably untapped)
- Multiplier interaction creates explosive growth (intentional, but need UI warning?)

**Questions to Answer:**
- [ ] Do copied tokens enter tapped or untapped? (Magic rule: untapped)
- [ ] Do copied tokens have summoning sickness? (Probably yes if global setting enabled)
- [ ] Should there be a confirmation dialog for "Double All Tokens"? (YES - it's powerful/destructive)
- [ ] Do we copy counters too? (Magic rule: yes, they're copies)
- [ ] Do we copy artwork URLs? (Yes, easier implementation)
- [ ] Performance: What if user has 20 different token types? (Should be fine, but test)

---

### System Design

**Commander Registry** (code organization):
```dart
enum Commander {
  krenko('krenko', 'Krenko, Mob Boss'),
  chatterfang('chatterfang', 'Chatterfang, Squirrel General'),
  rhys('rhys', 'Rhys the Redeemed');

  final String id;
  final String displayName;
  const Commander(this.id, this.displayName);
}
```

**Dynamic Banner Widget:**
```dart
Widget buildCommanderBanner(Commander commander) {
  switch (commander) {
    case Commander.krenko:
      return KrenkoBanner();
    case Commander.chatterfang:
      return ChatterfangBanner();
    case Commander.rhys:
      return RhysBanner();
  }
}
```

**Color Theme System:**
```dart
Color getCommanderThemeColor(Commander? commander) {
  if (commander == null) return Colors.blue; // Default
  switch (commander) {
    case Commander.krenko: return Colors.red;
    case Commander.chatterfang: return Colors.green;
    case Commander.rhys: return Colors.lightGreen; // Green/White blend
  }
}
```

### Migration Path

**Phase 1:** Implement Commander Mode framework
- Add commander selection UI
- Create base banner widget system
- Implement theme color switching

**Phase 2:** Migrate Krenko Mode
- Move Krenko banner to commander system
- Update settings to use new storage keys
- Maintain backward compatibility (auto-select Krenko if old setting enabled)

**Phase 3:** Add Chatterfang
- Implement squirrel token creation
- Add Chatterfang banner widget

**Phase 4:** Add Rhys
- Implement Elf Warrior creation
- Implement "Double All Tokens" (most complex)

### Future Expansion
Other popular token commanders to consider:
- **Brudiclad, Telchor Engineer**: Convert tokens to copies
- **Trostani, Selesnya's Voice**: Populate mechanic
- **Ghired, Conclave Exile**: Populate on attack
- **Adrix and Nev, Twincasters**: Double token creation
- **Mondrak, Glory Dominus**: Triple token creation
- **Jetmir, Nexus of Revels**: Rewards for token count
- **Hazezon, Shaper of Sand**: Desert token tracking

Each can be added without affecting existing commanders - modular system.

### Benefits
- **Scalable**: Easy to add new commanders without UI clutter
- **Targeted**: Users only see tools for their chosen commander
- **Flexible**: Each commander gets custom controls for their mechanics
- **Theme Integration**: Each commander can have unique color scheme
- **User Choice**: Players pick their commander, app adapts to their deck

### Testing Priorities
- [ ] Commander selection persists across app restarts
- [ ] Theme colors update when commander changes
- [ ] Disabling Commander Mode hides banner and restores default theme
- [ ] Each commander's token creation works correctly
- [ ] Multiplier applies correctly for each commander
- [ ] Rhys "Double All Tokens" handles complex board states
- [ ] Performance with 10+ different token types (Rhys doubling)

---

## Implementation Approach (UPDATED for Card Widget Design)

### Widget as Card in List

The Krenko widget is implemented as a **card that appears in the token list**, not as a fixed banner.

**Key Changes from Original Design:**
- ❌ NO Settings toggle for "Krenko Mode"
- ❌ NO fixed banner above token list
- ❌ NO theme color override
- ✅ Widget added via FAB menu → Widgets
- ✅ Widget appears as card in token list
- ✅ Widget can be reordered by dragging
- ✅ Widget can be removed by swiping

### Widget Data Model

**CardWidget Model:**
```dart
@HiveType(typeId: X) // Next available type ID
class CardWidget extends HiveObject {
  @HiveField(0) String widgetType; // 'krenko'
  @HiveField(1) Map<String, dynamic> state; // {'power': 3, 'nontokenGoblins': 0}
  @HiveField(2) DateTime createdAt;
  @HiveField(3) double order; // For list positioning
}
```

### New Components

1. **KrenkoWidgetCard** (`lib/widgets/krenko_widget_card.dart`)
   - Renders as card in token list
   - Shows Krenko title, power/goblin steppers, "Waaagh!" button
   - Red color theme for visual distinction
   - Persists state in widget.state Map

2. **KrenkoDialog** (`lib/widgets/krenko_dialog.dart`)
   - Two options: Krenko's Power or For Each Goblin
   - Calls TokenProvider.createOrAddGoblins()

3. **Widget Selection Sheet** (update existing in ContentScreen)
   - Shows "Krenko, Mob Boss" with checkmark if active
   - Tapping adds/removes widget from list

### Display Logic

**ContentScreen list builder:**
- Combine widgets and tokens
- Sort by order field
- Render KrenkoWidgetCard for widgets, TokenCard for tokens
- Both support drag-to-reorder and swipe-to-delete

---

# ARCHIVED: Previous Exploration - NOT WORKING

## 📦 Latest Build Artifacts (v1.3.0+8)

**iOS (.ipa):**
`build/ios/ipa/Doubling Season.ipa` (21.9MB)

**Android (.aab):**
`build/app/outputs/bundle/release/app-release.aab` (44.2MB)

**Built:** 2025-11-20
**Status:** Ready to deploy

---

# Next Feature: Widgets System & Menu Consolidation

**Status:** 🔍 **REFINEMENT PHASE** - Do NOT implement yet. Planning and design discussion required.

## Overview

Two major interconnected features to plan and refine before implementation:

### 1. Floating Action Menu Consolidation
### 2. Widgets System

---

## Part 1: Floating Action Menu Consolidation

### Problem
The floating action menu (FloatingActionMenu) is getting crowded. We need to add a "Widgets" button, and the current structure doesn't scale well.

### Current Menu Structure
1. New Token
2. +1/+1 Everything
3. Untap Everything
4. Clear Summoning Sickness
5. Save Deck
6. Load Deck
7. Board Wipe

### Proposed New Menu Structure
1. **New Token**
2. **Widgets** (NEW - opens widget selection dialog)
3. **Board Update** (NEW - opens submenu with bulk operations)
   - Untap All
   - Clear Summoning Sickness
   - +1/+1 Everything
   - -1/-1 Everything (NEW feature)
   - Board Wipe
4. **Save Deck**
5. **Load Deck**

### Rationale
- Groups related bulk operations into a logical submenu
- Reduces top-level menu items from 7 to 5
- Makes room for Widgets button without further crowding
- "Board Update" clearly indicates batch operations on all tokens

### -1/-1 Everything Feature (NEW)
**Context:** From `FeedbackIdeas.md` lines 11-18

Mirrors the existing +1/+1 Everything feature:
- Adds a -1/-1 counter to all tokens with power/toughness
- Useful for: Night of Souls' Betrayal, Black Sun's Zenith, etc.
- Same snapshot-based iteration pattern
- Same P/T pop animation
- Red color theme (debuff/weakening)

### Alternative Proposals

**Alternative 1: Further consolidation**
```
1. New Token
2. Widgets
3. Board Actions (submenu: Untap, Clear SS, +1/+1, -1/-1, Wipe)
4. Decks (submenu: Save, Load)
```
Reduces to 4 top-level items. Groups deck operations together.

**Alternative 2: Icon-only menu**
Use icons without text labels, add tooltips. Allows more items in less space. May hurt discoverability.

**Alternative 3: Contextual visibility**
Only show certain actions when relevant (e.g., hide Board Update when board is empty). Dynamic but potentially confusing.

**Questions to Answer:**
- [ ] Should "Board Update" have a confirmation dialog before opening submenu?
- [ ] Icon for "Board Update" menu item? (Currently thinking: refresh/update icon)
- [ ] Should submenu items have icons or text labels?
- [ ] Do we need a "Close" button in the Board Update submenu?
- [ ] Should we add analytics to track which bulk operations are most used?

---

## Part 2: Widgets System

### Concept

**Widgets** (also called "Card Widgets" or "Commander Widgets") are special cards that appear in the token list alongside regular tokens. They are NOT tokens themselves, but provide specialized controls and tracking for specific commanders or game mechanics.

### Core Widget Design (CONFIRMED)

**Widget Placement:**
- Widgets appear **IN the token list**, mixed with tokens
- When added, widgets insert at the **top of the list** (but can be reordered)
- Users can drag widgets to reorder them like any other card
- Swiping a widget away dismisses it (removes from list)
- Multiple widgets can be active simultaneously

**Widget Selection Menu:**
- Accessed via FAB menu → "Widgets" button
- Shows list of available widget types (Krenko, Chatterfang, Rhys, etc.)
- Active widgets shown with **checkmark or highlight**
- Tapping a widget adds it to the token list (if not already present)
- Tapping an active widget removes it from the list

**Use Case Example:**
1. Player has Krenko, Mob Boss on their battlefield
2. Player opens FAB menu → Widgets
3. Player taps "Krenko, Mob Boss" widget
4. Krenko widget card appears at top of token list
5. Player uses widget to track Krenko's power and create goblins
6. When done, player swipes widget away or unchecks it in menu

### Examples of Widgets
- **Krenko Widget**: Tracks Krenko's power and nontoken goblin count, creates goblin tokens on demand
- **Chatterfang Widget**: Auto-creates squirrels when other tokens are created
- **Rhys Widget**: Doubles all tokens or creates Elf Warriors
- **Doubling Season Widget**: Automatically doubles token multiplier when active
- **Cathars' Crusade Widget**: Reminder to add +1/+1 counters when tokens enter

### Widget Characteristics

**Similarities to Tokens:**
- Use TokenCard visual design (same styling as tokens)
- Appear in the same scrollable list as tokens
- Can be reordered via drag-and-drop
- Can be dismissed via swipe gesture
- Persist across sessions (Hive storage)
- Have order field for positioning

**Differences from Tokens:**
- Different action buttons (widget-specific controls, NOT tap/untap/add/remove)
- No amount, tapped/untapped counts, or summoning sickness
- No P/T or counters (unless widget-specific)
- Custom UI per widget type
- Distinguished visually (different icon, color scheme, or border)

### Key Design Questions

#### 1. Widget Data Model

**Proposed Base Model:**
```dart
@HiveType(typeId: X)
class CardWidget extends HiveObject {
  @HiveField(0) String widgetType; // 'krenko', 'chatterfang', 'doublingseason'
  @HiveField(1) Map<String, dynamic> state; // Widget-specific state (power, counters, etc.)
  @HiveField(2) DateTime createdAt;
  @HiveField(3) double order; // For reordering in token list
}
```

**Storage Strategy (CONFIRMED):**
- [ ] **Same Hive box as tokens?** OR separate `widgets` box?
  - **Recommendation:** Separate box to avoid type confusion, but both use `order` field for unified list display
- [x] Widgets do NOT have a "disabled" state - they are either in the list or not
- [x] Swiping widget deletes it from the list (can be re-added via menu)
- [ ] Widget state persists even when widget is removed (so re-adding restores previous values)?

**Questions:**
- [ ] How do we handle widget-specific state? (Generic Map? Subclasses? JSON serialization?)
- [ ] Should we merge tokens and widgets into one unified list view, or keep separate boxes?
- [ ] How do we distinguish widgets visually in the list?

#### 2. Unified List Display

**Challenge:** How do we display widgets and tokens in one unified list?

**Options:**
- **Option A:** Merge into single list, sorted by `order` field
  - Widgets and tokens both implement a common interface for rendering
  - List builder checks type and renders appropriate card
  - Pro: Simple, unified drag-and-drop
  - Con: More complex rendering logic

- **Option B:** Two separate lists, visually unified
  - Widgets box and tokens box separate
  - UI combines them for display
  - Pro: Clean data separation
  - Con: Complex drag-and-drop between types

**Recommendation:** Start with Option A (single merged list), use type checking in item builder

#### 3. Widget UI Rendering

**Challenge:** Each widget has different controls and layout

**Option A: Hardcoded widget cards**
```dart
Widget buildWidgetCard(CardWidget widget) {
  switch (widget.widgetType) {
    case 'krenko':
      return KrenkoWidgetCard(widget: widget);
    case 'chatterfang':
      return ChatterfangWidgetCard(widget: widget);
    // ...
  }
}
```

**Option B: Generic widget card with configuration**
```dart
class WidgetCard extends StatelessWidget {
  final CardWidget widget;
  final WidgetConfig config; // Defines layout, buttons, fields

  // Config loaded from registry
}
```

**Recommendation:** Start with Option A (hardcoded), extract common patterns later

#### 4. Token Creation with Special Rules

Some widgets create tokens with special rules. **Can we standardize these rule types?**

**Common Rule Types:**
1. **Multiplier Modifier**: "Double all token creation" (Doubling Season, Parallel Lives)
2. **Replacement Effect**: "When you create X, also create Y" (Chatterfang, Academy Manufactor)
3. **Power-based Creation**: "Create N tokens where N = [calculation]" (Krenko)
4. **Copy Effect**: "Create copies of existing tokens" (Rhys, Brudiclad)
5. **Conditional Creation**: "If condition, create token" (varies)

**Standardization Approach:**

**Option A: Rule Engine Pattern**
```dart
abstract class TokenCreationRule {
  int modifyAmount(int baseAmount);
  List<TokenTemplate> additionalTokens(TokenTemplate original);
  bool shouldApply(TokenCreationContext context);
}

class DoublingRule extends TokenCreationRule {
  int modifyAmount(int baseAmount) => baseAmount * 2;
}

class ChatterfangRule extends TokenCreationRule {
  List<TokenTemplate> additionalTokens(TokenTemplate original) {
    return [SquirrelTemplate(amount: original.amount)];
  }
}
```

**Option B: Widget Behavior Interface**
```dart
abstract class WidgetBehavior {
  Future<void> onTokenCreated(Item token, TokenProvider provider);
  Future<void> onTokenTapped(Item token, TokenProvider provider);
  Future<void> customAction(String actionId, Map<String, dynamic> params);
}
```

**Option C: Event-based System**
```dart
// Widgets register for events
enum TokenEvent { created, tapped, destroyed, modified }

class Widget {
  void onEvent(TokenEvent event, Item token) {
    // Widget-specific behavior
  }
}
```

**Recommendation:** Keep it simple for now - widgets create tokens directly via methods in TokenProvider. Event-based system can be added later if needed.

#### 5. Widget Selection Menu UI

**Requirements (CONFIRMED):**
- Shows list of all available widget types
- Indicates which widgets are currently active (checkmark or highlight)
- Tapping inactive widget adds it to token list
- Tapping active widget removes it from token list (or shows confirmation?)
- Visual design similar to other action sheets

**Implementation approach:**
- Widget registry maps widget types to display info (name, description, icon, color)
- Menu queries active widgets from Hive box
- Toggle logic: check if widget exists → add or remove

#### 6. Widget State Persistence

Widgets need to persist state (e.g., Krenko's power, nontoken goblin count).

**Option A: Generic Map in CardWidget model**
```dart
Map<String, dynamic> state = {
  'power': 3,
  'nontokenGoblins': 2,
};
```
Pro: Flexible, easy to implement. Con: No type safety, prone to errors.

**Option B: Subclass per widget type**
```dart
class KrenkoWidget extends CardWidget {
  @HiveField(10) int power;
  @HiveField(11) int nontokenGoblins;
}
```
Pro: Type-safe, clear structure. Con: Requires Hive adapter per widget type, more boilerplate.

**Option C: JSON serialization with typed classes**
```dart
class WidgetState {
  Map<String, dynamic> toJson();
  static WidgetState fromJson(Map<String, dynamic> json, String type);
}

class KrenkoState extends WidgetState {
  int power;
  int nontokenGoblins;
}
```
Pro: Flexible + type-safe, good balance. Con: More complex serialization, but manageable.

**Recommendation:** Start with Option A (Map) for MVP, migrate to Option C if needed for type safety.

### Implementation Priorities

**Phase 1: Foundation**
- [ ] Finalize Widget data model
- [ ] Create Widget Hive box and storage
- [ ] Implement widget selection dialog ("Add Widget" button)
- [ ] Create base WidgetCard UI component

**Phase 2: First Widget (Krenko)**
- [ ] Implement Krenko widget following refined design
- [ ] Test token creation with special rules
- [ ] Validate persistence and state management
- [ ] Learn from implementation challenges

**Phase 3: Standardization**
- [ ] Extract common patterns from Krenko implementation
- [ ] Create reusable widget components/behaviors
- [ ] Document widget creation guide

**Phase 4: Expansion**
- [ ] Add Chatterfang widget
- [ ] Add Doubling Season widget
- [ ] Add Rhys widget
- [ ] Iterate on standardization

### Questions That MUST Be Answered Before Implementation

#### Architecture:
- [ ] Where do widgets appear in the UI? (mixed with tokens, dedicated section, collapsible banner?)
- [ ] Separate Hive box or same box as tokens?
- [ ] How do we version widget types for future expansion?
- [ ] Can users have multiple widgets active simultaneously?

#### Data Model:
- [ ] Base Widget class structure?
- [ ] How to handle widget-specific state? (Map, subclasses, JSON?)
- [ ] Do widgets have order/position like tokens?
- [ ] Can widgets be disabled without deleting?

#### Behavior System:
- [ ] How do widgets hook into token creation? (events, callbacks, rules engine?)
- [ ] How do we prevent widget conflicts? (e.g., two doubling effects)
- [ ] Should widgets have priority/ordering for rule application?
- [ ] How do widgets access TokenProvider and SettingsProvider?

#### UI/UX:
- [ ] What actions are common across all widgets? (delete, disable, configure?)
- [ ] How do users discover available widgets?
- [ ] Should widgets have help/info tooltips explaining what they do?
- [ ] Do widgets need configuration screens or inline controls?

#### Token Creation Standardization:
- [ ] What rule types do we need to support? (multiplier, replacement, conditional, copy?)
- [ ] How do rules combine? (Doubling Season + Parallel Lives = x4?)
- [ ] Should widgets modify the global multiplier or apply separately?
- [ ] How do we show users what rules are active?

#### Performance:
- [ ] How many widgets can be active at once before performance issues?
- [ ] Do widget rules run on every token creation (performance impact)?
- [ ] Should we batch widget rule application for bulk operations?
- [ ] Memory footprint of widget state storage?

### Success Criteria

Before implementing, we should be able to answer:
1. **What is a widget?** (clear, concise definition)
2. **How do widgets work?** (behavior system, rule application)
3. **Where do widgets live?** (UI placement, data storage)
4. **What can widgets do?** (capabilities, limitations)
5. **How do users interact with widgets?** (creation, configuration, deletion)
6. **How do widgets stay performant?** (optimization strategy)

### Reference Materials

**Existing Documentation:**
- `commanderWidgets.md` - Krenko Mode detailed design (good foundation)
- `FeedbackIdeas.md` - User feedback on replacement effects and doublers
- `PremiumVersionIdeas.md` - Token modifier cards concept

**Related Code:**
- `lib/widgets/token_card.dart` - Visual design to mirror
- `lib/models/item.dart` - Data model pattern to follow
- `lib/providers/token_provider.dart` - Provider pattern for widget management

---

## Timeline

**Now → Refinement Complete:** Design discussion, answer key questions, document decisions
**After Refinement:** Implementation can begin with clear architectural foundation
**No deadline:** This is a major feature that must be done right

---

## Notes for Implementation

- Start with Krenko widget as proof-of-concept (already well-designed in commanderWidgets.md)
- Extract patterns and create framework AFTER seeing what works
- Don't over-engineer - build one widget well, then generalize
- Performance matters - test with 10+ widgets and 100+ tokens on screen
- User testing after first widget to validate approach before expanding

---

**⚠️ CRITICAL: Do NOT begin implementation until these design questions are answered and documented.**
