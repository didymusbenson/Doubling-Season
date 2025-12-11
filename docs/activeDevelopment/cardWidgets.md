# Next Feature: Utility Cards

## Overview
Utility cards are game-tracking tools (like life counters, poison counters, monarch status, etc.) that live alongside token cards in the main game board.

## Utility Types

There are two fundamental utility types:

### 1. Tracker Utility
A numeric counter with stepper buttons. Trackers emphasize the VALUE as the primary display element.

**Layout Structure:**
Trackers use a single-row layout that mirrors token name vs tapped/untapped structure:
- **Left Side (Expanded)**: Column containing Name, Description (optional), and Buttons
- **Right Side (shrink-wrap)**: VALUE display (centered, prominent)

**Components:**
- **Name**: Read-only title (e.g., "Life Total", "Poison Counters", "Experience")
  - Max 75% width (naturally constrained by Expanded layout)
  - Truncates with ellipsis if too long
  - Same styling as token names
- **Description**: Optional explanation text (e.g., "Tap +/- to adjust life total")
  - Lives in same 75% column as Name (cannot overlap with Value)
  - **Editable**: Users can add/edit descriptions for any tracker (via ExpandedUtilityScreen)
  - By default, predefined utilities (Life Total, Poison Counters) have no description
  - Players know what these are, no need for explanatory text
  - Custom trackers can have descriptions if user wants
- **Value**: Large numeric display (tap to manually edit)
  - Right-aligned, takes remaining space (typically ~25%)
  - **BIG NUMBER emphasis**: Uses displayMedium font with bold weight
  - Semi-transparent background (same as token tapped/untapped)
  - NO border (unlike buttons)
  - Vertically centered to take full card height
  - Padding: 12px horizontal, 8px vertical
- **Buttons**: Decrement (-), Increment (+)
  - Left-aligned in the 75% column below Name/Description
  - Spaced using token button spacing calculation (LayoutBuilder with clamp)
  - Tap: Change by utility's tapIncrement (default: 1)
  - Long-press: Change by utility's longPressIncrement (default: 5)

**Examples:**
- Life Total (starting value: 40 or 20)
- Poison Counters (starts at 0, lose at 10)
- Radiation Counters (starts at 0)
- Experience Counters (starts at 0, can only increase)
- Energy Counters (starts at 0)
- Commander Damage per opponent (starts at 0, lose at 21)
- Storm Count (starts at 0)

**State Persistence:**
- Current value
- Name (fixed by utility type)
- Description (fixed by utility type)
- Artwork URL (optional)
- Color identity (fixed by utility type)

### 2. Toggle Utility
A binary state indicator that switches between two views.

**Behavior:**
- Tap anywhere on card to toggle between ON/OFF states
- Visual change indicates current state (e.g., different icon, text, or background treatment)

**Examples:**
- Monarch (ON: "You are the Monarch", OFF: "Not the Monarch")
- City's Blessing (ON: "You have the City's Blessing", OFF: "No City's Blessing")
- Day/Night (ON: "It is Day", OFF: "It is Night")
- Initiative (ON: "You have the Initiative", OFF: "No Initiative")
- The Ring (ON: "You are the Ring-bearer", OFF: "Not the Ring-bearer")

**State Persistence:**
- Current state (boolean: true/false)
- Name (fixed by utility type)
- ON description (fixed by utility type)
- OFF description (fixed by utility type)
- Artwork URL (optional)
- Color identity (fixed by utility type)

## Core Requirements

### Visual Consistency
Utility cards MUST match token card styling exactly:

**Structure (from ContentScreen):**
- **Container Wrapper**: GradientBoxBorder with 3px border width
- **Inner Border Radius**: Adjusted to fit inside border (`UIConstants.borderRadius - borderWidth`)
- **ClipRRect**: Clips content to inner border radius
- **Dismissible**: Swipe-to-delete with red background and delete icon
- **Stack Layout**: Background layer → Artwork layer → Content layer

**Card Appearance:**
- **Size**:
- Same width constraints as `TokenCard`
- Height: Naturally shorter for utilities without action buttons (toggles)
- Optional: 2-per-row layout for compact utilities (if drag-and-drop compatible)
- **Border**: Same border radius and 3px gradient border
- **Background**: `Theme.of(context).cardColor`
- **Padding**: `UIConstants.cardPadding`
- **Shadows**: Only in light mode (no shadows in dark mode)
  - Primary shadow: `Colors.black.withValues(alpha: UIConstants.shadowOpacity)`, blur 8px
  - Light shadow: `Colors.black.withValues(alpha: UIConstants.lightShadowOpacity)`, blur 3px

**Gradient Backgrounds:**
- Show gradient when no artwork present
- Use `ColorUtils.gradientForColors(colorIdentity)`
- Same gradient as border color
- Full card coverage with border radius

**Text Overlays:**
- Semi-transparent backgrounds: `cardColor.withValues(alpha: 0.85)`
- Applied to name, description, buttons when over artwork/gradient
- Border radius: 4-6px depending on element

**Reordering:**
- Drag proxy animation: Scale 1.0 → 1.03 during drag
- Elevation 8 with shadow opacity 0.3 when dragging
- Uses `order` field (double) for fractional positioning

### Utility Content Fields
Utility cards have text fields that map to token card equivalents:
- **NAME**: Utility title (maps to token's `name` field)
    - Displayed in title position with same typography
    - Background: `cardColor.withValues(alpha: 0.85)` for readability
    - Read-only (set by utility type, cannot be edited by user)
- **DESCRIPTION**: Utility explanation/rules text (maps to token's `abilities` field)
    - **Tracker utilities**: Optional text field (editable by user in ExpandedUtilityScreen)
      - By default empty for predefined trackers (Life Total, Poison Counters)
      - Users can add custom descriptions if desired
      - **Compact Card**: 3-line max with ellipsis overflow
      - **Expanded View**: Editable TextField with 3-line height
    - **Toggle utilities**: Current state text (e.g., "You are the Monarch" or "Not the Monarch")
      - Read-only (set by utility type via onDescription/offDescription)
      - **Compact Card**: 3-line max with ellipsis overflow
      - **Expanded View**: Full multi-line text without truncation, read-only
    - Background: `cardColor.withValues(alpha: 0.85)` for readability

### Utility Color Identity and Artwork

**Color Identity:**
- **Editable**: Users can manually set color identity for any utility (same as tokens)
- **Color Selection**: Via ExpandedUtilityScreen using ColorSelectionButton (W/U/B/R/G)
- **Border Gradient**: Uses `ColorUtils.gradientForColors()` like token cards
- **Background Gradient**: Utilities without artwork show gradient background based on color identity
- **Default Colors** (predefined utilities):
    - Life Total: Colorless (empty string)
    - Poison Counters: Black/Green (BG)
    - The Monarch: Red (R)
    - Day/Night: White/Green (WG)

**Artwork Behavior (from TokenCard):**
- **Selection**: Via `ExpandedUtilityScreen` using `ArtworkManager` (same as tokens)
- **Caching**: Uses `ArtworkManager.getCachedArtworkFile()` and `ArtworkManager.downloadArtwork()`
- **Cropping**: Same crop percentages as tokens (8.8% left/right, 14.5% top, 36.8% bottom)
- **Display Styles**:
  - Full View: Artwork fills card width, scales to fill width, crops height, center vertically
  - Fadeout: Artwork on right 50%, gradient fade from transparent to opaque (stops: [0.0, 0.50])
- **Global Setting**: Respects `SettingsProvider.artworkDisplayStyle` (reactive via Selector)
- **Animation**:
  - If artwork loads >100ms after card creation: Fade in over 500ms with `AnimatedOpacity`
  - If artwork loads <100ms (cached): No animation, instant display
- **Cleanup**: Auto-removes invalid `artworkUrl` when file is missing (after ConnectionState.done)
- **Gradient Placeholder**: Shows color gradient while artwork is loading, then hides when loaded
- **Persistence**: `artworkUrl` saved in Hive with utility data

### Action Button Styling
Utility cards have action buttons styled identically to token cards:

**Button Style (from TokenCard._buildActionButton):**
- Border width: `UIConstants.actionButtonBorderWidth`
- Border radius: `UIConstants.actionButtonBorderRadius`
- Padding: `UIConstants.actionButtonPadding` (all sides)
- Icon size: `UIConstants.iconSize`
- Background color: `cardColor.withValues(alpha: 0.85)` (solid over artwork/gradient)
- Border color: `Theme.of(context).colorScheme.primary`
- Disabled state: Border color with opacity `UIConstants.disabledOpacity`

**Button Layout (from TokenCard._buildActionButtons, lines 320-338):**
- Centered row with responsive spacing
- **Calculation**:
  ```dart
  const buttonInternalWidth = UIConstants.actionButtonInternalWidth; // Icon + padding
  final totalButtonWidth = buttonCount * buttonInternalWidth;
  final availableSpacingWidth = constraints.maxWidth - totalButtonWidth;
  final spacing = (availableSpacingWidth / (buttonCount - 1)).clamp(
    UIConstants.minButtonSpacing,
    UIConstants.maxButtonSpacing,
  );
  ```
- Last button gets 0 trailing spacing

**Utility-Specific Buttons:**
- **Tracker utilities**: 2 buttons in left-aligned row (with token spacing calculation)
  - Decrement button (-): Icons.remove, tap = -1, long-press = -5 (configurable)
  - Increment button (+): Icons.add, tap = +1, long-press = +5 (configurable)
  - Value display: Separate element on right side (NOT in button row), tappable to edit
- **Toggle utilities**: No action buttons (entire card is tappable to toggle state)

### What Utilities DON'T Have (vs Tokens)

**Fields:**
- No editable name/description (read-only, set by utility type)
- No power/toughness
- No abilities text
- No type line
- No color selection (hard-coded by utility type)
- No +1/+1 or -1/-1 counters
- No custom counter management
- No tapped/untapped state
- No summoning sickness
- No "amount" field (utilities are singular items)

**Actions:**
- No add/remove amount buttons
- No tap/untap buttons
- No copy button
- No split stack button
- No "clear summoning sickness" button
- No counter pills displayed

**Behavior:**
- No opacity change based on amount (utilities don't have amount=0 state)
- No special handling for emblems or Scute Swarm

### Tap Behavior

**Tracker Utilities:**
- **Tap card background**: Opens `ExpandedUtilityScreen` (for artwork selection/delete)
- **Tap decrement button**: Decrease value by tap increment
- **Long-press decrement button**: Decrease value by long-press increment
- **Tap value display**: Opens numeric keyboard for manual editing
- **Tap increment button**: Increase value by tap increment
- **Long-press increment button**: Increase value by long-press increment

**Toggle Utilities:**
- **Tap anywhere on card**: Toggle state (ON ↔ OFF) with cross-fade animation
  - Cross-fade between artwork states if both `onArtworkUrl` and `offArtworkUrl` set
  - Cross-fade text opacity when description changes
  - Note: Cross-fade for background images may be challenging (document if not feasible)
- **Long-press on card**: Opens `ExpandedUtilityScreen` (for artwork selection/delete)
- Rationale: Toggle should be instant (tap), expanded view is secondary (long-press)

### Expanded View
- **Universal Component**: All utilities use the same `ExpandedUtilityScreen` component (not utility-specific)
- **Navigation**:
  - Tracker utilities: Tap card background
  - Toggle utilities: Long-press card
- **Name Display**: Utility name shown as read-only text (not editable)
- **Description**:
    - **Tracker utilities**: Editable TextField with 3-line height
      - Label: "Description (Optional)"
      - Hint text: "Add optional description..."
      - Auto-saves on change
      - Users can add/edit/remove descriptions as desired
    - **Toggle utilities**: Read-only display showing both ON and OFF state descriptions
      - Multi-line text without truncation
      - Scrollable if needed
- **Color Selection**: Editable for all utilities via ColorSelectionButton (W/U/B/R/G)
    - Same UI as ExpandedTokenScreen
    - Auto-saves on change
    - Updates gradient background when utility has no artwork
- **Artwork Selection**: Uses exact same artwork selection logic as tokens
    - Scryfall API integration via `ArtworkManager`
    - Same artwork picker UI from `ExpandedTokenScreen`
    - Same cropping/caching behavior
    - Artwork displayed on utility card using same styling as tokens (Full View or Fadeout)
- **No Counter Management**: Utilities don't have +1/+1 counters or custom counters
- **No Utility-Specific Controls**: Base `ExpandedUtilityScreen` has no special function controls
    - If future utilities need custom controls, extend the base class (e.g., `ExpandedLifeCounterScreen extends ExpandedUtilityScreen`)
    - Similar inheritance pattern to `BaseUtilityCard`
- **Delete Button**: Utilities can be deleted from the board
- **Rationale**: Universal expanded view provides artwork selection, description editing (trackers), and delete without cluttering the compact card

### Utility Event System
Utilities can listen to token-related events for automatic trigger tracking:

**Event Architecture:**
```dart
// Event object pattern for future-proof extensibility
class CreatureEnteredEvent {
  final int amount;           // Required: number of creatures that entered
  final Item? token;          // Optional: the token that was created/modified
  final String? source;       // Optional: 'addTokens', 'insertItem', 'copyToken', etc.
  // Future fields can be added here without breaking existing utilities

  CreatureEnteredEvent({
    required this.amount,
    this.token,
    this.source,
  });
}

// TokenProvider (or future BoardProvider) maintains callback registry
class TokenProvider {
  final List<void Function(CreatureEnteredEvent)> _onCreatureEnteredCallbacks = [];

  void registerCreatureEnteredCallback(void Function(CreatureEnteredEvent) callback) {
    _onCreatureEnteredCallbacks.add(callback);
  }

  void unregisterCreatureEnteredCallback(void Function(CreatureEnteredEvent) callback) {
    _onCreatureEnteredCallbacks.remove(callback);
  }

  void _notifyCreatureEntered(CreatureEnteredEvent event) {
    for (var callback in _onCreatureEnteredCallbacks.toList()) {
      try {
        callback(event);
      } catch (e) {
        debugPrint('Utility callback failed: $e');
        _onCreatureEnteredCallbacks.remove(callback); // Auto-cleanup dead callbacks
      }
    }
  }
}
```

**Utility Implementation:**
```dart
class CatharsCrusadeUtility {
  int pendingTriggers = 0;

  void init(BoardProvider provider) {
    provider.registerCreatureEnteredCallback(_onCreatureEntered);
  }

  void _onCreatureEntered(CreatureEnteredEvent event) {
    // Today: Only use amount
    pendingTriggers += event.amount;
    notifyListeners();

    // Future: Can filter by token properties
    // if (event.token?.colors.contains('G') ?? true) {
    //   pendingTriggers += event.amount;
    // }
  }

  @override
  void dispose() {
    provider.unregisterCreatureEnteredCallback(_onCreatureEntered);
    super.dispose();
  }
}
```

**Event Triggers:**
- `addTokens()`: Fires when tokens added to existing stack
- `insertItem()`: Fires when new token stack created
- `copyToken()`: Fires when token stack copied
- Does NOT fire for: tap/untap, deck loading, counter changes, board wipe

**Future Event Types:**
- `CreatureDiedEvent`: For death triggers (e.g., Blood Artist)
- `CreatureAttackedEvent`: For attack triggers
- `SpellCastEvent`: For spell-based triggers
- `ArtifactEnteredEvent`, `EnchantmentEnteredEvent`, etc.

**Benefits:**
- ✅ Non-intrusive: Doesn't block token creation flow
- ✅ User control: Utilities accumulate triggers, user resolves when ready
- ✅ Future-proof: Adding optional fields to events doesn't break existing utilities
- ✅ Type-safe: Compiler catches callback signature mismatches
- ✅ Self-cleaning: Dead callbacks auto-removed on error

### List Integration
Utility cards are part of the same reorderable list as token cards:
- **Data Model**: Utilities and tokens share a common interface or union type
- **Ordering**: Utilities can be dragged/reordered among tokens
- **Persistence**: Utility position and state saved in same Hive box as tokens
- **Creation**: Utilities added via FloatingActionMenu (same entry point as tokens)

## Implementation Plan

### 1. Data Model
Create a unified model for board items (tokens + utilities):
```dart
// Option A: Union type
abstract class BoardItem extends HiveObject {
  String get displayType; // "token" or "utility"
  double order; // For drag-and-drop
}

class Item extends BoardItem { /* existing token model */ }
class Utility extends BoardItem { /* new utility model */ }

// Option B: Single model with type field
class BoardItem extends HiveObject {
  String itemType; // "token" or "utility"
  // ... token-specific fields (nullable for utilities)
  // ... utility-specific fields (nullable for tokens)
}
```

### 2. Utility Card Components

#### Base Utility Card
```dart
/// Base class for all utility cards - enforces visual consistency
abstract class BaseUtilityCard extends StatefulWidget {
  final dynamic utility;

  const BaseUtilityCard({required this.utility, super.key});

  @override
  State<BaseUtilityCard> createState() => _BaseUtilityCardState();
}

class _BaseUtilityCardState extends State<BaseUtilityCard> {
  @override
  Widget build(BuildContext context) {
    // Enforces TokenCard structure:
    // - Stack with background + gradient/artwork layer + content
    // - Same padding, borders, shadows
    // - Name + Description layout (maps to token's name + abilities)
    // - Action buttons using _buildActionButton() pattern (trackers only)
    // - Hard-coded color border gradient
    // - GestureDetector opens ExpandedUtilityScreen (for artwork/delete)
  }

  Widget _buildActionButton(...) {
    // Identical implementation to TokenCard._buildActionButton()
  }
}
```

#### Tracker Utility Card
```dart
class TrackerUtilityCard extends BaseUtilityCard {
  final TrackerUtility tracker;

  const TrackerWidgetCard({required this.tracker, super.key});

  @override
  Widget build(BuildContext context) {
    // Layout: Single row mirroring token name vs tapped/untapped
    // Left: Expanded column (Name, Description, Buttons)
    // Right: Value display (shrink-wrap, centered)
    return GestureDetector(
      onTap: () => _openExpandedView(),
      child: Stack([
        _buildGradientBackground(tracker.colorIdentity),
        _buildArtworkLayer(tracker.artworkUrl),
        Row([
          // Left side: Name, Description, Buttons (75% naturally via Expanded)
          Expanded(
            child: Column([
              _buildTextWithBackground(
                child: Text(tracker.name, overflow: TextOverflow.ellipsis),
              ),
              if (tracker.description.isNotEmpty)
                _buildTextWithBackground(
                  child: Text(tracker.description, maxLines: 3),
                ),
              _buildActionButtons([  // Left-aligned, token spacing
                _buildActionButton(
                  icon: Icons.remove,
                  onTap: () => _decrement(tracker.tapIncrement),
                  onLongPress: () => _decrement(tracker.longPressIncrement),
                ),
                _buildActionButton(
                  icon: Icons.add,
                  onTap: () => _increment(tracker.tapIncrement),
                  onLongPress: () => _increment(tracker.longPressIncrement),
                ),
              ]),
            ]),
          ),
          // Right side: Value display (25% naturally via shrink-wrap)
          _buildTextWithBackground(
            child: Text(
              '${tracker.currentValue}',
              style: titleLarge,
              textAlign: TextAlign.center,
            ),
          ), // Tappable to edit via GestureDetector wrapper
        ]),
      ]),
    );
  }
}
```

#### Toggle Utility Card
```dart
class ToggleUtilityCard extends BaseUtilityCard {
  final ToggleUtility toggle;

  const ToggleWidgetCard({required this.toggle, super.key});

  @override
  Widget build(BuildContext context) {
    // Uses BaseWidgetCard structure
    // NO action buttons - entire card is tappable
    return GestureDetector(
      onTap: () => _toggleState(),
      onLongPress: () => _openExpandedView(), // Long-press for expanded view
      child: Stack([
        _buildGradientBackground(toggle.colorIdentity),
        _buildArtworkLayer(toggle.isActive ? toggle.onArtworkUrl : toggle.offArtworkUrl),
        Column([
          _buildNameSection(toggle.name),
          _buildDescriptionSection(
            toggle.isActive ? toggle.onDescription : toggle.offDescription
          ),
          // Optional: Visual indicator of state (icon or badge)
          _buildStateIndicator(toggle.isActive),
        ]),
      ]),
    );
  }
}

/// Single expanded view component for ALL utility cards
class ExpandedUtilityScreen extends StatelessWidget {
  final dynamic utility;

  // Universal utility detail screen - works for all utility types:
  // - NAME displayed as read-only text (not TextField)
  // - Full DESCRIPTION displayed without truncation (scrollable)
  // - Artwork selection UI (identical to ExpandedTokenScreen)
  // - No ColorSelectionButton (color identity is hard-coded per utility type)
  // - No counter management (no +1/+1, no custom counters)
  // - Delete button present
  // - No stack splitting
  // - No utility-specific controls in base implementation
  //
  // NOTE: If future utilities need custom controls in expanded view,
  // create specialized screens (e.g., ExpandedLifeCounterScreen extends ExpandedUtilityScreen)
  // and override buildCustomControls() method. For now, base class has no special functions.
}
```

### 3. ContentScreen Updates
- **List View**: Change from `List<Item>` to `List<BoardItem>`
- **Builder**: Conditional rendering based on item type:
  ```dart
  itemBuilder: (context, index) {
    final item = items[index];
    return item is Item
      ? TokenCard(item: item)
      : UtilityCard(utility: item as Utility);
  }
  ```
- **Reordering**: Existing drag-and-drop logic works with unified `order` field

### 4. Provider Updates
- **TokenProvider** � **BoardProvider**: Rename and expand
- Methods: `insertBoardItem()`, `updateBoardItem()`, `deleteBoardItem()`
- Box: Change from `Box<Item>` to `Box<BoardItem>` (requires migration)

### 5. Widget Selection Screen
Opens when user taps "Widgets" in FloatingActionMenu:

**Layout (follows TokenSearchScreen pattern):**
- Full-screen Scaffold with AppBar (title: "Select Widget", close button)
- Search bar at top (debounced search like TokenSearchScreen)
- Type filter chips below search: [All] [Tracker] [Toggle]
- Scrollable list of matching widgets below filters
- Each row shows: Widget name, type tag, brief description
- Tapping a predefined widget creates instance immediately

**Custom Widget Creation:**
- "Create Custom Tracker" button at top of list (sticky)
- "Create Custom Toggle" button at top of list (sticky)
- Opens `NewTrackerSheet` or `NewToggleSheet` (full-screen Scaffold like NewTokenSheet)
  - **Tracker form**: Name (TextField), Description (TextField), Default Value (stepper), Color Identity (ColorSelectionButton)
  - **Toggle form**: Name (TextField), ON Description (TextField), OFF Description (TextField), Color Identity (ColorSelectionButton)
  - "Create" button in AppBar actions (same pattern as NewTokenSheet)
- Creates and inserts custom widget instance

**Widget Storage:**
- Instances stored in separate Hive boxes: `Box<TrackerWidget>`, `Box<ToggleWidget>`
- Custom widgets: `isCustom = true`
- Predefined widgets: `isCustom = false`
- ContentScreen merges `items`, `trackers`, `toggles` by `order` field

## Widget Catalog

### Tracker Widgets (To Implement)

**Life & Damage:**
- **Life Total**: Track life total (default: 40, color: colorless)
- **Commander Damage**: Track damage from specific commander (default: 0, color: R)

**Counters:**
- **Poison Counters**: Track poison (default: 0, color: BG)
- **Radiation Counters**: Track radiation (default: 0, color: colorless)
- **Energy Counters**: Track energy (default: 0, color: U)
- **Experience Counters**: Track experience (default: 0, color: colorless)

**Game State:**
- **Storm Count**: Track storm count (default: 0, color: UR)
- **Mana Pool**: Track floating mana (default: 0, color: colorless)

**Custom Tracker:**
- User-defined tracker with custom name, description, default value, min/max, increments, color

### Toggle Utilities (To Implement)

**Status Indicators:**
- **Monarch**: "You are the Monarch" / "Not the Monarch" (color: R)
- **City's Blessing**: "You have the City's Blessing" / "No City's Blessing" (color: W)
- **Initiative**: "You have the Initiative" / "No Initiative" (color: colorless)
- **The Ring**: "You are the Ring-bearer" / "Not the Ring-bearer" (color: colorless)
- **Day/Night**: "It is Day" / "It is Night" (color: WG)

**Custom Toggle:**
- User-defined toggle with custom name, ON/OFF descriptions, color

### Special Utilities (Future - Advanced Features)
These utilities are marked as `UtilityType.special` and have complex, commander-specific functionality beyond basic trackers/toggles. They may listen to game events or provide unique button actions.

**Trigger Trackers (based on Tracker utility):**
- **Cathars' Crusade**: Tracks ETB triggers, button applies +X/+X to all tokens
- **Impact Tremors**: Tracks damage dealt (1 per creature entered)
- **Purphoros**: Tracks damage (2 per creature entered)

**Replacement Effect Toggles (based on Toggle utility):**
- **Doubling Season**: When ON, auto-doubles token creation
- **Parallel Lives**: When ON, auto-doubles token creation
- **Anointed Procession**: When ON, auto-doubles token creation

**Button-Action Utilities (special type, custom card implementations):**
- **Krenko, Mob Boss**: Button creates X goblins where X = goblins you control
  - Color: R
  - Button: "Tap Krenko" → counts goblin tokens → creates that many 1/1 goblins
- **Rhys the Redeemed**: Button doubles all token stacks
  - Color: GW
  - Button: "Activate Rhys" → for each token type, creates matching stack with same amount
  - Example: 3 Goblins + 5 Elves → creates 3 more Goblins + 5 more Elves
- **Brudiclad, Telchor Engineer**: Button converts all tokens to selected type
  - Color: UR
  - Button: "Activate Brudiclad" → opens token picker → all tokens become copies of chosen type
  - Preserves tapped/untapped state
- **Chatterfang**: Auto-creates matching Squirrel tokens when creature tokens enter
  - Color: BG
  - Listens to CreatureEnteredEvent → creates matching 1/1 green Squirrel tokens
- **Blood Artist**: Tracks life gain/loss triggers on creature death
  - Color: B
  - Listens to CreatureDiedEvent → increments trigger counter

## Implementation Decisions (Finalized)

### Utility Selection Screen
Following existing TokenSearchScreen pattern for consistency:
- **Screen Type**: Full-screen Scaffold (not bottom sheet)
- **AppBar**: Title "Select Utility" with close button
- **Search Bar**: Debounced search at top (300ms delay like TokenSearchScreen)
- **Filter Chips**: Type filters below search - [All] [Tracker] [Toggle]
- **Utility List**: Scrollable list of matching predefined utilities
- **Custom Creation Buttons**: "Create Custom Tracker" and "Create Custom Toggle" at top of list (sticky)
- **Selection Behavior**: Tap predefined utility → creates instance immediately and closes screen

### Custom Utility Creation Forms
Following existing NewTokenSheet pattern for consistency:
- **NewTrackerSheet** (full-screen Scaffold):
  - Name (TextField)
  - Description (TextField)
  - Default Value (stepper widget, starts at 0)
  - Color Identity (ColorSelectionButton - same as tokens)
  - "Create" button in AppBar actions
- **NewToggleSheet** (full-screen Scaffold):
  - Name (TextField)
  - ON Description (TextField)
  - OFF Description (TextField)
  - Color Identity (ColorSelectionButton - same as tokens)
  - "Create" button in AppBar actions

### FAB Menu Integration
- **Location**: Line ~123 in FloatingActionMenu (between "New Token" and "Untap All")
- **Action Level**: Same level as "New Token" (not nested submenu)
- **Implementation**: Uncomment existing lines 124-135 in floating_action_menu.dart
- **Icon**: `Icons.apps`
- **Color**: `Colors.deepPurple`

### Initial Predefined Utility Catalog (Phase 1)
Start with 4 essential utilities to validate implementation:
1. **Life Total** (Tracker, default: 40, colorless)
2. **Poison Counters** (Tracker, default: 0, BG)
3. **Monarch** (Toggle, R)
4. **Day/Night** (Toggle, WG)

Additional utilities can be added incrementally after Phase 1 validation.

### Board Wipe Behavior
- **"Delete All"**: Use `item is Item` type check to filter - deletes only tokens, preserves utilities
- **"Set to 0"**: Only operates on `Item` objects (utilities have no `amount` field)
- **Future "Reset Utilities"**: Not implemented in Phase 1, can add if users request it

## Migration Strategy
### Phase 1: Foundation (Current)
- Create `BoardItem` abstract class
- Implement `UtilityCard` component
- Add utility creation flow

### Phase 2: Data Migration
- Migrate Hive box from `Box<Item>` to `Box<BoardItem>`
- Handle existing user data (all items become tokens)
- Update provider layer

### Phase 3: First Utility
- Implement simplest utility (e.g., Life Counter)
- Test integration with token list
- Validate reordering and persistence

## Design Decisions (Resolved)
1. ✅ **Color Identity**: Each utility type has hard-coded color identity (cannot be changed by user)
2. ✅ **Expanded View**: Utilities DO have `ExpandedUtilityScreen` for description + artwork selection
3. ✅ **Content Fields**: Utilities have NAME and DESCRIPTION (map to token's name/abilities, read-only)
4. ✅ **Base Class**: All utilities inherit from `BaseUtilityCard` for visual consistency
5. ✅ **Artwork Support**: Utilities can have custom artwork selected via Scryfall (same logic as tokens)

## Data Model

### Utility Base Class
```dart
@HiveType(typeId: 4)
abstract class Utility extends BoardItem {
  @HiveField(0) String utilityId; // Unique ID for this utility instance
  @HiveField(1) String utilityType; // "tracker" or "toggle"
  @HiveField(2) String name; // Display name (read-only, set by utility definition)
  @HiveField(3) String description; // Explanation text (read-only)
  @HiveField(4) String colorIdentity; // Color(s) for border gradient (read-only)
  @HiveField(5) String? artworkUrl; // Optional custom artwork
  @HiveField(6) double order; // Sort order (inherited from BoardItem)
  @HiveField(7) DateTime createdAt;
}
```

### Tracker Utility
```dart
@HiveType(typeId: 6)  // CORRECTED: 4 and 5 are already used by ArtworkVariant and TokenArtworkPreference
class TrackerUtility extends HiveObject {
  @HiveField(0) String utilityId; // Unique ID (UUID)
  @HiveField(1) String name; // Display name (user can edit for custom trackers)
  @HiveField(2) String description; // Explanation text (user can edit for custom trackers)
  @HiveField(3) String colorIdentity; // Color(s) for border gradient
  @HiveField(4) String? artworkUrl; // Optional custom artwork
  @HiveField(5) double order; // Sort order for reordering
  @HiveField(6) DateTime createdAt;
  @HiveField(7) int currentValue; // Current numeric value
  @HiveField(8) int defaultValue; // Starting value (user-settable, for reset functionality)
  @HiveField(9) int tapIncrement; // Amount to change on tap (default: 1)
  @HiveField(10) int longPressIncrement; // Amount to change on long-press (default: 5)
  @HiveField(11) bool isCustom; // True if user-created, false if predefined

  // Value constraints:
  // - Minimum: Always 0 (clamped on decrement)
  // - Maximum: Arbitrarily high (TBD based on device testing for display width)
  // - Overflow handling: Truncate to "XXXXX..." if value too wide
  // - CARDINAL RULE: NO TEXT OVERFLOWS
}
```

### Toggle Utility
```dart
@HiveType(typeId: 7)  // CORRECTED: 6 is TrackerUtility
class ToggleUtility extends HiveObject {
  @HiveField(0) String utilityId; // Unique ID (UUID)
  @HiveField(1) String name; // Display name (user can edit for custom toggles)
  @HiveField(2) String colorIdentity; // Color(s) for border gradient
  @HiveField(3) String? artworkUrl; // Optional custom artwork (used for both states if no per-state artwork)
  @HiveField(4) double order; // Sort order for reordering
  @HiveField(5) DateTime createdAt;
  @HiveField(6) bool isActive; // Current state (true = ON, false = OFF)
  @HiveField(7) String onDescription; // Text to show when active
  @HiveField(8) String offDescription; // Text to show when inactive
  @HiveField(9) String? onArtworkUrl; // Optional: Different artwork for ON state
  @HiveField(10) String? offArtworkUrl; // Optional: Different artwork for OFF state
  @HiveField(11) bool isCustom; // True if user-created, false if predefined

  // Visual behavior:
  // - Reserve space for longest description (onDescription vs offDescription) to prevent height changes
  // - Cross-fade animation when toggling states (artwork and text)
  // - Note: Cross-fade for background images may be challenging based on past implementation attempts
}
```

### Utility Definition (Not Persisted)
```dart
class UtilityDefinition {
  final String id; // Unique identifier (e.g., "life_total", "monarch")
  final UtilityType type; // tracker, toggle, or special
  final String name;
  final String description; // Or onDescription for toggles
  final String? offDescription; // For toggles only
  final String colorIdentity;
  final int? defaultValue; // For trackers
  final int? minValue; // For trackers
  final int? maxValue; // For trackers
  final int tapIncrement; // For trackers (default: 1)
  final int longPressIncrement; // For trackers (default: 5)

  // Factory method to create utility instance from definition
  TrackerUtility toTrackerUtility() { ... }
  ToggleUtility toToggleUtility() { ... }
}

enum UtilityType { tracker, toggle, special }
```

## Technical Implementation Details (From Codebase Research)

### Hive Architecture
**No Abstract Base Class:**
- Hive doesn't support abstract class adapters
- Each concrete class needs its own TypeAdapter
- TrackerWidget and ToggleWidget are independent HiveObjects
- No shared Widget base class with Hive persistence

**Type ID Corrections:**
```dart
// Current assignments:
// 0 = Item
// 1 = TokenCounter
// 2 = Deck
// 3 = TokenTemplate
// 4 = ArtworkVariant (ALREADY USED)
// 5 = TokenArtworkPreference (ALREADY USED)
// 6 = TrackerUtility (NEW)
// 7 = ToggleUtility (NEW)
```

**Box Strategy:**
- Keep existing `Box<Item>('items')` as-is (no migration)
- Add new `Box<TrackerUtility>('trackerUtilities')`
- Add new `Box<ToggleUtility>('toggleUtilities')`
- ContentScreen merges lists by `order` field

### Provider Pattern
Following existing patterns:
- `TokenProvider` wraps `Box<Item>`
- `DeckProvider` wraps `LazyBox<Deck>`
- Create `TrackerProvider` wraps `Box<TrackerUtility>`
- Create `ToggleProvider` wraps `Box<ToggleUtility>`
- Each provider has: `insert()`, `update()`, `delete()`, `ValueListenable<Box<T>>`

### ContentScreen Integration
```dart
// Merge three boxes into single sorted list
final items = tokenProvider.items;
final trackers = trackerProvider.trackers;
final toggles = toggleProvider.toggles;

final boardItems = [...items, ...trackers, ...toggles]
  ..sort((a, b) => a.order.compareTo(b.order));

// Conditional rendering in itemBuilder
itemBuilder: (context, index) {
  final item = boardItems[index];
  if (item is Item) return TokenCard(item: item);
  if (item is TrackerUtility) return TrackerUtilityCard(tracker: item);
  if (item is ToggleUtility) return ToggleUtilityCard(toggle: item);
}
```

### Tap Handling (from TokenCard pattern)
Child GestureDetectors automatically consume taps before parent:
```dart
GestureDetector(  // Parent: Opens expanded view
  onTap: () => _openExpandedView(),
  child: Column([
    ...
    Row([  // Child GestureDetectors consume taps
      GestureDetector(onTap: _decrement, child: DecrementButton()),
      GestureDetector(onTap: _editValue, child: ValueDisplay()),
      GestureDetector(onTap: _increment, child: IncrementButton()),
    ]),
  ]),
)
```

### Value Editing Pattern (from ExpandedTokenScreen)
Inline TextField toggle:
```dart
// Tap value → show TextField inline
// constraints: BoxConstraints(minWidth: 40, maxWidth: 80)
// keyboardType: TextInputType.number
// autofocus: true
// onSubmitted + onTapOutside both save
```

### Deck Persistence Pattern
Following TokenTemplate approach with bug fix:
- Template stores configuration, resets game state to defaults
- **BUG FIX**: `template.toItem(amount: 0, createTapped: false)` should initialize to 0, not 1
  - Location: `lib/widgets/load_deck_sheet.dart:165`
  - Current code: `final item = template.toItem(amount: 1, createTapped: false);`
  - Correct code: `final item = template.toItem(amount: 0, createTapped: false);`
  - Rationale: User manually adds tokens during gameplay, deck should only define token types
- Utilities: Template stores utility config, resets to `defaultValue` and `isActive: false`

## Design Decisions (Resolved)
1. ✅ **Hive Type IDs**: TrackerUtility (6), ToggleUtility (7)
2. ✅ **Utility Types**: Tracker (numeric counter) and Toggle (binary state)
3. ✅ **Default Values**: Life Total = 40, all other trackers = 0 unless specified
4. ✅ **Experience Counter**: Normal tracker controls (decrement allowed, even though rare in practice)
5. ✅ **Utility Selection UI**: Full-screen with search bar + type filters (All, Tracker, Toggle), scrollable list
6. ✅ **Custom Utilities**: Users can create custom trackers and toggles
7. ✅ **Gradient Background**: Artless utilities get color gradient backgrounds (consistency with tokens)
8. ✅ **Toggle Animation**: Cross-fade when toggling states (artwork and text)
9. ✅ **Toggle Height**: Reserve space for longest description to prevent height changes
10. ✅ **Tracker Bounds**: Minimum 0, no maximum (truncate with "XXXXX..." if overflow, NO TEXT OVERFLOWS)
11. ✅ **Deck Persistence**: Utilities save to templates, always reset to defaults on load
12. ✅ **Deck Bug Fix**: Tokens should initialize to amount=0 (not 1) when loading deck
13. ✅ **Board Wipe Behavior**:
    - "Delete All": Deletes tokens only, keeps utilities
    - "Set to 0": Sets token amounts to 0, doesn't affect utilities
14. ✅ **Event System**: Defer to Advanced Utilities phase (not needed for basic tracker/toggle)
15. ✅ **Custom Utility Forms**: Follow NewTokenSheet pattern - full-screen Scaffold with TextFields and ColorSelectionButton
16. ✅ **FAB Menu Integration**: Uncomment existing lines 124-135 in floating_action_menu.dart (same level as New Token)
17. ✅ **Initial Utility Catalog**: Start with 4 utilities (Life Total, Poison, Monarch, Day/Night) to validate implementation

## Success Criteria

### Foundation
- [ ] Utility card visually indistinguishable from token card (except content)
- [ ] Action buttons styled identically to token buttons
- [ ] Utilities can be reordered freely among tokens
- [ ] Utility NAME and DESCRIPTION are read-only (cannot be edited)
- [ ] Utility state persists across app restarts
- [ ] Artless utilities display color gradient backgrounds matching their color identity
- [ ] Custom artwork displays on utility card with Full View/Fadeout styles (same as tokens)

### Tracker Utility
- [ ] Displays name, description, and current value
- [ ] Decrement button (-): Tap = -1, Long-press = -5
- [ ] Increment button (+): Tap = +1, Long-press = +5
- [ ] Tap value to manually edit (numeric keyboard)
- [ ] Respects min/max limits (if set)
- [ ] Life Total tracker works (starting at 40 or 20)
- [ ] Poison Counter tracker works (starting at 0)

### Toggle Utility
- [ ] Displays name and current state description
- [ ] Tap anywhere on card to toggle state
- [ ] Description updates to show current state (ON/OFF text)
- [ ] Visual feedback indicates state change
- [ ] Monarch toggle works ("You are the Monarch" / "Not the Monarch")
- [ ] Day/Night toggle works ("It is Day" / "It is Night")

### Expanded View
- [ ] Tapping utility opens `ExpandedUtilityScreen`
- [ ] Expanded view shows full description without truncation
- [ ] Artwork selection works identically to tokens (Scryfall API)
- [ ] Delete button present and functional
- [ ] No field editing (name/description are read-only)

### Integration
- [ ] FloatingActionMenu "Utilities" button opens utility selection
- [ ] Utility selection screen shows categorized list (Trackers, Toggles)
- [ ] Creating utility inserts it into board with correct order
- [ ] Utilities save to deck templates
- [ ] Loading deck restores utility configuration, resets to defaults (defaultValue, isActive: false)
- [ ] Loading deck initializes tokens to amount=0 (BUG FIX: currently initializes to 1)

### Board Wipe Behavior
- [ ] "Delete All": Deletes tokens only, keeps utilities
- [ ] "Set to 0": Sets token amounts to 0, doesn't affect utilities
- [ ] Optional: "Reset/Remove Utilities" action for clearing utilities separately

### Optional Requirements
- [ ] 2-per-row layout for compact utilities (if compatible with drag-and-drop)
- [ ] Cross-fade animation for toggle state changes (artwork and text)
  - Note: May be challenging based on past background image fade issues
  - Document if cross-fade isn't feasible
