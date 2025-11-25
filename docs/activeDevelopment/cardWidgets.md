# Next Feature: Widget Cards

## Overview
Widget cards are utility cards that provide game-tracking tools (like commander abilities, life counters, etc.) that live alongside token cards in the main game board.

## Core Requirements

### Visual Consistency
Widget cards MUST match token card styling exactly:
- **Size**: Same height/width constraints as `TokenCard`
- **Border**: Same border radius (`UIConstants.smallBorderRadius`)
- **Containment**: Same card background color and padding (`UIConstants.cardPadding`)
- **Layout**: Stack-based structure (background → content)
- **Shadows/Elevation**: Match token card elevation
- **Base Component**: All custom widgets inherit from `BaseWidgetCard` class that enforces visual consistency

### Widget Content Fields
Widget cards have two text fields that map to token card equivalents:
- **NAME**: Widget title (maps to token's `name` field)
    - Displayed in title position with same typography
    - Background: `cardColor.withValues(alpha: 0.85)` for readability
    - Read-only (set by widget type, cannot be edited by user)
- **DESCRIPTION**: Widget explanation/rules text (maps to token's `abilities` field)
    - **Compact Card**: 3-line max with ellipsis overflow
    - **Expanded View**: Full multi-line text without truncation
    - Background: `cardColor.withValues(alpha: 0.85)` for readability
    - Read-only (set by widget type, cannot be edited by user)
    - Provides clear instructions on how the widget works and how to use it

### Widget Color Identity and Artwork
- **Hard-coded Color**: Each widget type has a fixed color identity (cannot be changed by user)
- **Border Gradient**: Uses `ColorUtils.gradientForColors()` like token cards
- **Examples**:
    - Life Counter: Colorless (gray)
    - Commander Damage: Red (R)
    - Energy Counter: Blue (U)
    - Poison Counter: Black/Green (BG)
- **Custom Artwork**: Users can select custom artwork via `ExpandedWidgetScreen`
    - Uses exact same artwork selection logic as `ExpandedTokenScreen`
    - Scryfall API integration via `ArtworkManager`
    - Same cropping, caching, and display behavior as tokens
    - Artwork displayed with Full View or Fadeout style (based on global setting)
    - Artwork persisted in Hive with widget data

### Action Button Styling
Widget cards have action buttons styled identically to token cards:
- **Button Style**: Use `_buildActionButton()` pattern from `TokenCard`
    - Border width: `UIConstants.actionButtonBorderWidth`
    - Border radius: `UIConstants.actionButtonBorderRadius`
    - Padding: `UIConstants.actionButtonPadding`
    - Icon size: `UIConstants.iconSize`
    - Background color: `cardColor.withValues(alpha: 0.85)`
- **Button Layout**: Centered row with responsive spacing (same logic as token cards)
- **Long-press**: Support long-press for bulk operations where applicable
- **Custom Buttons**: Each widget type defines its own button set (different icons/functions)

### Expanded View
- **Universal Component**: All widgets use the same `ExpandedWidgetScreen` component (not widget-specific)
- **Tap Behavior**: Tapping any widget opens the same `ExpandedWidgetScreen`
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
- **Rationale**: Universal expanded view provides clear instructions without cluttering the compact card

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

### 2. Base Widget Card Component
```dart
/// Base class for all widget cards - enforces visual consistency
abstract class BaseWidgetCard extends StatefulWidget {
  final Widget widget;

  const BaseWidgetCard({required this.widget, super.key});

  /// Each widget type defines its own button set
  List<WidgetActionButton> buildActionButtons(BuildContext context);

  /// Widget type's hard-coded color identity (e.g., "R", "UG", "", etc.)
  String get colorIdentity;

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
    // - Action buttons using _buildActionButton() pattern
    // - NO GestureDetector for navigation (widgets don't have detail view)
    // - Hard-coded color border gradient
  }

  Widget _buildActionButton(...) {
    // Identical implementation to TokenCard._buildActionButton()
  }

  // NOTE: BaseWidgetCard DOES have GestureDetector for navigation
  // Tapping widget opens ExpandedWidgetScreen (similar to TokenCard → ExpandedTokenScreen)
}

/// Example: Life Counter Widget
class LifeCounterWidget extends BaseWidgetCard {
  @override
  String get colorIdentity => ""; // Colorless (gray border)

  @override
  List<WidgetActionButton> buildActionButtons(BuildContext context) {
    return [
      WidgetActionButton(
        icon: Icons.remove,
        onTap: () => _decrementLife(1),
        onLongPress: () => _decrementLife(5),
      ),
      WidgetActionButton(
        icon: Icons.add,
        onTap: () => _incrementLife(1),
        onLongPress: () => _incrementLife(5),
      ),
      WidgetActionButton(
        icon: Icons.refresh,
        onTap: () => _resetLife(40),
        onLongPress: () => _resetLife(20),
      ),
    ];
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

### 5. FloatingActionMenu
Add "New Widget" option:
- Opens `WidgetSelectionScreen` (similar to `TokenSearchScreen`)
- Widget catalog with categories (life counters, commander tools, etc.)
- Creates and inserts widget into board

## Widget Types (Future)
Examples of widgets to implement:

**Basic Counters (No Event Listening):**
- **Life Counter**: Track life total with +/- buttons
- **Commander Damage**: Track damage from each opponent's commander
- **Energy Counter**: Track energy resource
- **Experience Counter**: Track experience counters
- **Poison Counter**: Track poison counters
- **Monarch/Initiative**: Toggle status indicators
- **Storm Count**: Track storm count
- **Mana Pool**: Track floating mana

**Trigger-Based Widgets (Use CreatureEnteredEvent):**
- **Cathars' Crusade**: Button applies +X/+X to all (where X = pending triggers)
- **Doubling Season**: Multiplier toggle (auto-doubles token creation via event interception)
- **Parallel Lives**: Multiplier toggle (same as Doubling Season)
- **Anointed Procession**: Multiplier toggle (same as Doubling Season)
- **Chatterfang**: Auto-creates matching Squirrel tokens when creature enters
- **Impact Tremors**: Tracks damage dealt (1 per creature entered)

**Future Event Types for Advanced Widgets:**
- **Blood Artist** (CreatureDiedEvent): Tracks life gain/loss triggers
- **Purphoros** (CreatureEnteredEvent with devotion): +2 damage per creature
- **Krenko** (button-based): Creates X goblins where X = goblins you control

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

## Open Questions
1. **Hive Type IDs**: Widget needs a new type ID (4)
2. **Deck Persistence**: Do widgets save to deck templates? (TBD - probably yes for full game state restoration)
3. **Gradient Background**: Do artless widgets get color gradient backgrounds like artless tokens? (Probably yes for consistency)
4. **Widget State**: What state do widgets persist? (e.g., Life Counter current value, Commander Damage values, Cathars' Crusade pending triggers, etc.)
5. **Event System Location**: Should event callbacks live in TokenProvider or migrate to BoardProvider? (Probably BoardProvider for consistency)

## Success Criteria
- [ ] Widget card visually indistinguishable from token card (except content)
- [ ] Action buttons styled identically to token buttons
- [ ] Widgets can be reordered freely among tokens
- [ ] Tapping widget opens `ExpandedWidgetScreen`
- [ ] Expanded view shows full description without truncation
- [ ] Artwork selection works identically to tokens (Scryfall API)
- [ ] Custom artwork displays on widget card with Full View/Fadeout styles
- [ ] Widget NAME and DESCRIPTION are read-only (cannot be edited)
- [ ] Widget state persists across app restarts
- [ ] Widget position persists in deck templates (if applicable)
- [ ] Artless widgets display color gradient backgrounds
- [ ] Event system implemented with `CreatureEnteredEvent` class
- [ ] Widgets can register/unregister for token creation events
- [ ] Creating tokens fires callbacks with correct amount
- [ ] Widgets properly dispose and unregister callbacks (no memory leaks)
- [ ] Event system extensible (can add new event types and fields without breaking existing widgets)
