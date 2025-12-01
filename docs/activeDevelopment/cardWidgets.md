# Next Feature: Widget Cards

## Overview
Widget cards are utility cards that provide game-tracking tools (like life counters, poison counters, monarch status, etc.) that live alongside token cards in the main game board.

## Widget Types

There are two fundamental widget types:

### 1. Tracker Widget
A numeric counter with stepper buttons.

**Components:**
- **Name**: Read-only title (e.g., "Life Total", "Poison Counters", "Experience")
- **Value**: Numeric display (tap to manually edit)
- **Buttons**: Decrement (-), Increment (+)
  - Tap: Change by 1 (or widget-specific amount)
  - Long-press: Change by 5 (or widget-specific amount)

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
- Name (fixed by widget type)
- Description (fixed by widget type)
- Artwork URL (optional)
- Color identity (fixed by widget type)

### 2. Toggle Widget
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
- Name (fixed by widget type)
- ON description (fixed by widget type)
- OFF description (fixed by widget type)
- Artwork URL (optional)
- Color identity (fixed by widget type)

## Core Requirements

### Visual Consistency
Widget cards MUST match token card styling exactly:

**Structure (from ContentScreen):**
- **Container Wrapper**: GradientBoxBorder with 3px border width
- **Inner Border Radius**: Adjusted to fit inside border (`UIConstants.borderRadius - borderWidth`)
- **ClipRRect**: Clips content to inner border radius
- **Dismissible**: Swipe-to-delete with red background and delete icon
- **Stack Layout**: Background layer → Artwork layer → Content layer

**Card Appearance:**
- **Size**:
- Same width constraints as `TokenCard`
- Height: Naturally shorter for widgets without action buttons (toggles)
- Optional: 2-per-row layout for compact widgets (if drag-and-drop compatible)
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

### Widget Content Fields
Widget cards have text fields that map to token card equivalents:
- **NAME**: Widget title (maps to token's `name` field)
    - Displayed in title position with same typography
    - Background: `cardColor.withValues(alpha: 0.85)` for readability
    - Read-only (set by widget type, cannot be edited by user)
- **DESCRIPTION**: Widget explanation/rules text (maps to token's `abilities` field)
    - **Tracker widgets**: Instructions like "Tap +/- to adjust life total" (single line)
    - **Toggle widgets**: Current state text (e.g., "You are the Monarch" or "Not the Monarch")
    - **Compact Card**: 3-line max with ellipsis overflow
    - **Expanded View**: Full multi-line text without truncation
    - Background: `cardColor.withValues(alpha: 0.85)` for readability
    - Read-only (set by widget type, cannot be edited by user)
    - Provides clear instructions on how the widget works and how to use it

### Widget Color Identity and Artwork

**Color Identity:**
- **Hard-coded Color**: Each widget type has a fixed color identity (cannot be changed by user)
- **Border Gradient**: Uses `ColorUtils.gradientForColors()` like token cards
- **Examples**:
    - Life Counter: Colorless (gray)
    - Commander Damage: Red (R)
    - Energy Counter: Blue (U)
    - Poison Counter: Black/Green (BG)

**Artwork Behavior (from TokenCard):**
- **Selection**: Via `ExpandedWidgetScreen` using `ArtworkManager` (same as tokens)
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
- **Persistence**: `artworkUrl` saved in Hive with widget data

### Action Button Styling
Widget cards have action buttons styled identically to token cards:

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

**Widget-Specific Buttons:**
- **Tracker widgets**: 3 buttons in centered row
  - Decrement button (-): Icons.remove, tap = -1, long-press = -5 (configurable)
  - Value display (center): Tappable text with background, opens numeric keyboard
  - Increment button (+): Icons.add, tap = +1, long-press = +5 (configurable)
- **Toggle widgets**: No action buttons (entire card is tappable to toggle state)

### What Widgets DON'T Have (vs Tokens)

**Fields:**
- No editable name/description (read-only, set by widget type)
- No power/toughness
- No abilities text
- No type line
- No color selection (hard-coded by widget type)
- No +1/+1 or -1/-1 counters
- No custom counter management
- No tapped/untapped state
- No summoning sickness
- No "amount" field (widgets are singular items)

**Actions:**
- No add/remove amount buttons
- No tap/untap buttons
- No copy button
- No split stack button
- No "clear summoning sickness" button
- No counter pills displayed

**Behavior:**
- No opacity change based on amount (widgets don't have amount=0 state)
- No special handling for emblems or Scute Swarm

### Tap Behavior

**Tracker Widgets:**
- **Tap card background**: Opens `ExpandedWidgetScreen` (for artwork selection/delete)
- **Tap decrement button**: Decrease value by tap increment
- **Long-press decrement button**: Decrease value by long-press increment
- **Tap value display**: Opens numeric keyboard for manual editing
- **Tap increment button**: Increase value by tap increment
- **Long-press increment button**: Increase value by long-press increment

**Toggle Widgets:**
- **Tap anywhere on card**: Toggle state (ON ↔ OFF) with cross-fade animation
  - Cross-fade between artwork states if both `onArtworkUrl` and `offArtworkUrl` set
  - Cross-fade text opacity when description changes
  - Note: Cross-fade for background images may be challenging (document if not feasible)
- **Long-press on card**: Opens `ExpandedWidgetScreen` (for artwork selection/delete)
- Rationale: Toggle should be instant (tap), expanded view is secondary (long-press)

### Expanded View
- **Universal Component**: All widgets use the same `ExpandedWidgetScreen` component (not widget-specific)
- **Navigation**:
  - Tracker widgets: Tap card background
  - Toggle widgets: Long-press card
- **Description Display**: Shows full widget description explaining how it works and how to use it
    - Multi-line text without truncation
    - Scrollable if needed
    - Same text styling as token abilities in expanded view
- **Artwork Selection**: Uses exact same artwork selection logic as tokens
    - Scryfall API integration via `ArtworkManager`
    - Same artwork picker UI from `ExpandedTokenScreen`
    - Same cropping/caching behavior
    - Artwork displayed on widget card using same styling as tokens (Full View or Fadeout)
- **No Field Editing**: Unlike tokens, widget NAME and DESCRIPTION are read-only (cannot be edited)
- **No Counter Management**: Widgets don't have +1/+1 counters or custom counters
- **No Widget-Specific Controls**: Base `ExpandedWidgetScreen` has no special function controls
    - If future widgets need custom controls, extend the base class (e.g., `ExpandedLifeCounterScreen extends ExpandedWidgetScreen`)
    - Similar inheritance pattern to `BaseWidgetCard`
- **Delete Button**: Widgets can be deleted from the board
- **Rationale**: Universal expanded view provides artwork selection and delete without cluttering the compact card

### Widget Event System
Widgets can listen to token-related events for automatic trigger tracking:

**Event Architecture:**
```dart
// Event object pattern for future-proof extensibility
class CreatureEnteredEvent {
  final int amount;           // Required: number of creatures that entered
  final Item? token;          // Optional: the token that was created/modified
  final String? source;       // Optional: 'addTokens', 'insertItem', 'copyToken', etc.
  // Future fields can be added here without breaking existing widgets

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
        debugPrint('Widget callback failed: $e');
        _onCreatureEnteredCallbacks.remove(callback); // Auto-cleanup dead callbacks
      }
    }
  }
}
```

**Widget Implementation:**
```dart
class CatharsCrusadeWidget {
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
- ✅ User control: Widgets accumulate triggers, user resolves when ready
- ✅ Future-proof: Adding optional fields to events doesn't break existing widgets
- ✅ Type-safe: Compiler catches callback signature mismatches
- ✅ Self-cleaning: Dead callbacks auto-removed on error

### List Integration
Widget cards are part of the same reorderable list as token cards:
- **Data Model**: Widgets and tokens share a common interface or union type
- **Ordering**: Widgets can be dragged/reordered among tokens
- **Persistence**: Widget position and state saved in same Hive box as tokens
- **Creation**: Widgets added via FloatingActionMenu (same entry point as tokens)

## Implementation Plan

### 1. Data Model
Create a unified model for board items (tokens + widgets):
```dart
// Option A: Union type
abstract class BoardItem extends HiveObject {
  String get displayType; // "token" or "widget"
  double order; // For drag-and-drop
}

class Item extends BoardItem { /* existing token model */ }
class Widget extends BoardItem { /* new widget model */ }

// Option B: Single model with type field
class BoardItem extends HiveObject {
  String itemType; // "token" or "widget"
  // ... token-specific fields (nullable for widgets)
  // ... widget-specific fields (nullable for tokens)
}
```

### 2. Widget Card Components

#### Base Widget Card
```dart
/// Base class for all widget cards - enforces visual consistency
abstract class BaseWidgetCard extends StatefulWidget {
  final Widget widget;

  const BaseWidgetCard({required this.widget, super.key});

  @override
  State<BaseWidgetCard> createState() => _BaseWidgetCardState();
}

class _BaseWidgetCardState extends State<BaseWidgetCard> {
  @override
  Widget build(BuildContext context) {
    // Enforces TokenCard structure:
    // - Stack with background + gradient/artwork layer + content
    // - Same padding, borders, shadows
    // - Name + Description layout (maps to token's name + abilities)
    // - Action buttons using _buildActionButton() pattern (trackers only)
    // - Hard-coded color border gradient
    // - GestureDetector opens ExpandedWidgetScreen (for artwork/delete)
  }

  Widget _buildActionButton(...) {
    // Identical implementation to TokenCard._buildActionButton()
  }
}
```

#### Tracker Widget Card
```dart
class TrackerWidgetCard extends BaseWidgetCard {
  final TrackerWidget tracker;

  const TrackerWidgetCard({required this.tracker, super.key});

  @override
  Widget build(BuildContext context) {
    // Uses BaseWidgetCard structure
    // Action buttons: [-] [Value] [+]
    return GestureDetector(
      onTap: () => _openExpandedView(),
      child: Stack([
        _buildGradientBackground(tracker.colorIdentity),
        _buildArtworkLayer(tracker.artworkUrl),
        Column([
          _buildNameSection(tracker.name),
          _buildDescriptionSection(tracker.description),
          _buildActionButtons([
            _buildActionButton(
              icon: Icons.remove,
              onTap: () => _decrement(tracker.tapIncrement),
              onLongPress: () => _decrement(tracker.longPressIncrement),
            ),
            _buildValueDisplay(tracker.currentValue), // Tappable to edit
            _buildActionButton(
              icon: Icons.add,
              onTap: () => _increment(tracker.tapIncrement),
              onLongPress: () => _increment(tracker.longPressIncrement),
            ),
          ]),
        ]),
      ]),
    );
  }
}
```

#### Toggle Widget Card
```dart
class ToggleWidgetCard extends BaseWidgetCard {
  final ToggleWidget toggle;

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

/// Single expanded view component for ALL widget cards
class ExpandedWidgetScreen extends StatelessWidget {
  final Widget widget;

  // Universal widget detail screen - works for all widget types:
  // - NAME displayed as read-only text (not TextField)
  // - Full DESCRIPTION displayed without truncation (scrollable)
  // - Artwork selection UI (identical to ExpandedTokenScreen)
  // - No ColorSelectionButton (color identity is hard-coded per widget type)
  // - No counter management (no +1/+1, no custom counters)
  // - Delete button present
  // - No stack splitting
  // - No widget-specific controls in base implementation
  //
  // NOTE: If future widgets need custom controls in expanded view,
  // create specialized screens (e.g., ExpandedLifeCounterScreen extends ExpandedWidgetScreen)
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
      : WidgetCard(widget: item as Widget);
  }
  ```
- **Reordering**: Existing drag-and-drop logic works with unified `order` field

### 4. Provider Updates
- **TokenProvider** � **BoardProvider**: Rename and expand
- Methods: `insertBoardItem()`, `updateBoardItem()`, `deleteBoardItem()`
- Box: Change from `Box<Item>` to `Box<BoardItem>` (requires migration)

### 5. Widget Selection Screen
Opens when user taps "Widgets" in FloatingActionMenu:

**Layout:**
- Scrollable list (NOT search-based like TokenSearchScreen)
- Type filter buttons at top: [All] [Tracker] [Toggle] [Special]
- Each row shows: Widget name, type tag, brief description

**Predefined Widgets:**
- Life Total, Poison Counters, Energy, Experience, etc.
- Monarch, Initiative, Day/Night, City's Blessing, etc.
- Tapping a predefined widget creates instance immediately

**Custom Widget Creation:**
- "Create Custom Tracker" button at top
- "Create Custom Toggle" button at top
- Opens `NewTrackerSheet` or `NewToggleSheet` with form:
  - **Tracker form**: Name, Description, Default Value, Min/Max (optional), Tap/Long-press increments, Color Identity selector
  - **Toggle form**: Name, ON Description, OFF Description, Color Identity selector
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

### Toggle Widgets (To Implement)

**Status Indicators:**
- **Monarch**: "You are the Monarch" / "Not the Monarch" (color: R)
- **City's Blessing**: "You have the City's Blessing" / "No City's Blessing" (color: W)
- **Initiative**: "You have the Initiative" / "No Initiative" (color: colorless)
- **The Ring**: "You are the Ring-bearer" / "Not the Ring-bearer" (color: colorless)
- **Day/Night**: "It is Day" / "It is Night" (color: WG)

**Custom Toggle:**
- User-defined toggle with custom name, ON/OFF descriptions, color

### Special Widgets (Future - Advanced Features)
These widgets are marked as `WidgetType.special` and have complex, commander-specific functionality beyond basic trackers/toggles. They may listen to game events or provide unique button actions.

**Trigger Trackers (based on Tracker widget):**
- **Cathars' Crusade**: Tracks ETB triggers, button applies +X/+X to all tokens
- **Impact Tremors**: Tracks damage dealt (1 per creature entered)
- **Purphoros**: Tracks damage (2 per creature entered)

**Replacement Effect Toggles (based on Toggle widget):**
- **Doubling Season**: When ON, auto-doubles token creation
- **Parallel Lives**: When ON, auto-doubles token creation
- **Anointed Procession**: When ON, auto-doubles token creation

**Button-Action Widgets (special type, custom card implementations):**
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

## Migration Strategy
### Phase 1: Foundation (Current)
- Create `BoardItem` abstract class
- Implement `WidgetCard` component
- Add widget creation flow

### Phase 2: Data Migration
- Migrate Hive box from `Box<Item>` to `Box<BoardItem>`
- Handle existing user data (all items become tokens)
- Update provider layer

### Phase 3: First Widget
- Implement simplest widget (e.g., Life Counter)
- Test integration with token list
- Validate reordering and persistence

## Design Decisions (Resolved)
1. ✅ **Color Identity**: Each widget type has hard-coded color identity (cannot be changed by user)
2. ✅ **Expanded View**: Widgets DO have `ExpandedWidgetScreen` for description + artwork selection
3. ✅ **Content Fields**: Widgets have NAME and DESCRIPTION (map to token's name/abilities, read-only)
4. ✅ **Base Class**: All widgets inherit from `BaseWidgetCard` for visual consistency
5. ✅ **Artwork Support**: Widgets can have custom artwork selected via Scryfall (same logic as tokens)

## Data Model

### Widget Base Class
```dart
@HiveType(typeId: 4)
abstract class Widget extends BoardItem {
  @HiveField(0) String widgetId; // Unique ID for this widget instance
  @HiveField(1) String widgetType; // "tracker" or "toggle"
  @HiveField(2) String name; // Display name (read-only, set by widget definition)
  @HiveField(3) String description; // Explanation text (read-only)
  @HiveField(4) String colorIdentity; // Color(s) for border gradient (read-only)
  @HiveField(5) String? artworkUrl; // Optional custom artwork
  @HiveField(6) double order; // Sort order (inherited from BoardItem)
  @HiveField(7) DateTime createdAt;
}
```

### Tracker Widget
```dart
@HiveType(typeId: 6)  // CORRECTED: 4 and 5 are already used by ArtworkVariant and TokenArtworkPreference
class TrackerWidget extends HiveObject {
  @HiveField(0) String widgetId; // Unique ID (UUID)
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

### Toggle Widget
```dart
@HiveType(typeId: 7)  // CORRECTED: 6 is TrackerWidget
class ToggleWidget extends HiveObject {
  @HiveField(0) String widgetId; // Unique ID (UUID)
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

### Widget Definition (Not Persisted)
```dart
class WidgetDefinition {
  final String id; // Unique identifier (e.g., "life_total", "monarch")
  final WidgetType type; // tracker, toggle, or special
  final String name;
  final String description; // Or onDescription for toggles
  final String? offDescription; // For toggles only
  final String colorIdentity;
  final int? defaultValue; // For trackers
  final int? minValue; // For trackers
  final int? maxValue; // For trackers
  final int tapIncrement; // For trackers (default: 1)
  final int longPressIncrement; // For trackers (default: 5)

  // Factory method to create widget instance from definition
  TrackerWidget toTrackerWidget() { ... }
  ToggleWidget toToggleWidget() { ... }
}

enum WidgetType { tracker, toggle, special }
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
// 6 = TrackerWidget (NEW)
// 7 = ToggleWidget (NEW)
```

**Box Strategy:**
- Keep existing `Box<Item>('items')` as-is (no migration)
- Add new `Box<TrackerWidget>('trackerWidgets')`
- Add new `Box<ToggleWidget>('toggleWidgets')`
- ContentScreen merges lists by `order` field

### Provider Pattern
Following existing patterns:
- `TokenProvider` wraps `Box<Item>`
- `DeckProvider` wraps `LazyBox<Deck>`
- Create `TrackerProvider` wraps `Box<TrackerWidget>`
- Create `ToggleProvider` wraps `Box<ToggleWidget>`
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
  if (item is TrackerWidget) return TrackerWidgetCard(tracker: item);
  if (item is ToggleWidget) return ToggleWidgetCard(toggle: item);
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
- Widgets: Template stores widget config, resets to `defaultValue` and `isActive: false`

## Design Decisions (Resolved)
1. ✅ **Hive Type IDs**: TrackerWidget (6), ToggleWidget (7)
2. ✅ **Widget Types**: Tracker (numeric counter) and Toggle (binary state)
3. ✅ **Default Values**: Life Total = 40, all other trackers = 0 unless specified
4. ✅ **Experience Counter**: Normal tracker controls (decrement allowed, even though rare in practice)
5. ✅ **Widget Selection UI**: Scrollable list with type filters (tracker, toggle, special)
6. ✅ **Custom Widgets**: Users can create custom trackers and toggles
7. ✅ **Gradient Background**: Artless widgets get color gradient backgrounds (consistency with tokens)
8. ✅ **Toggle Animation**: Cross-fade when toggling states (artwork and text)
9. ✅ **Toggle Height**: Reserve space for longest description to prevent height changes
10. ✅ **Tracker Bounds**: Minimum 0, no maximum (truncate with "XXXXX..." if overflow, NO TEXT OVERFLOWS)
11. ✅ **Deck Persistence**: Widgets save to templates, always reset to defaults on load
12. ✅ **Deck Bug Fix**: Tokens should initialize to amount=0 (not 1) when loading deck
13. ✅ **Board Wipe Behavior**:
    - "Delete All": Deletes tokens only, keeps widgets
    - "Set to 0": Sets token amounts to 0, doesn't affect widgets
14. **Event System**: Defer to Advanced Widgets phase (not needed for basic tracker/toggle)

## Success Criteria

### Foundation
- [ ] Widget card visually indistinguishable from token card (except content)
- [ ] Action buttons styled identically to token buttons
- [ ] Widgets can be reordered freely among tokens
- [ ] Widget NAME and DESCRIPTION are read-only (cannot be edited)
- [ ] Widget state persists across app restarts
- [ ] Artless widgets display color gradient backgrounds matching their color identity
- [ ] Custom artwork displays on widget card with Full View/Fadeout styles (same as tokens)

### Tracker Widget
- [ ] Displays name, description, and current value
- [ ] Decrement button (-): Tap = -1, Long-press = -5
- [ ] Increment button (+): Tap = +1, Long-press = +5
- [ ] Tap value to manually edit (numeric keyboard)
- [ ] Respects min/max limits (if set)
- [ ] Life Total tracker works (starting at 40 or 20)
- [ ] Poison Counter tracker works (starting at 0)

### Toggle Widget
- [ ] Displays name and current state description
- [ ] Tap anywhere on card to toggle state
- [ ] Description updates to show current state (ON/OFF text)
- [ ] Visual feedback indicates state change
- [ ] Monarch toggle works ("You are the Monarch" / "Not the Monarch")
- [ ] Day/Night toggle works ("It is Day" / "It is Night")

### Expanded View
- [ ] Tapping widget opens `ExpandedWidgetScreen`
- [ ] Expanded view shows full description without truncation
- [ ] Artwork selection works identically to tokens (Scryfall API)
- [ ] Delete button present and functional
- [ ] No field editing (name/description are read-only)

### Integration
- [ ] FloatingActionMenu "Widgets" button opens widget selection
- [ ] Widget selection screen shows categorized list (Trackers, Toggles)
- [ ] Creating widget inserts it into board with correct order
- [ ] Widgets save to deck templates
- [ ] Loading deck restores widget configuration, resets to defaults (defaultValue, isActive: false)
- [ ] Loading deck initializes tokens to amount=0 (BUG FIX: currently initializes to 1)

### Board Wipe Behavior
- [ ] "Delete All": Deletes tokens only, keeps widgets
- [ ] "Set to 0": Sets token amounts to 0, doesn't affect widgets
- [ ] Optional: "Reset/Remove Widgets" action for clearing widgets separately

### Optional Requirements
- [ ] 2-per-row layout for compact widgets (if compatible with drag-and-drop)
- [ ] Cross-fade animation for toggle state changes (artwork and text)
  - Note: May be challenging based on past background image fade issues
  - Document if cross-fade isn't feasible
