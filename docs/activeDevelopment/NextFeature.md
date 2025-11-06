# Next Feature: Token List Reordering

## Overview
Enable users to manually reorder tokens in the main game board by long-pressing and dragging tokens to their desired position. The order persists across app sessions.

**Effort Estimate:** Medium (2-4 hours)

---

## Implementation Strategy

### 1. Data Model Changes

#### A. Add Order Field to Item Model
**File:** `lib/models/item.dart`

Add new Hive field for persistent ordering:
```dart
@HiveType(typeId: 0)
class Item extends HiveObject {
  // ... existing fields ...

  @HiveField(11) double order; // NEW FIELD - fractional ordering for efficient insertion

  Item({
    // ... existing parameters ...
    this.order = 0.0, // Default to 0.0 for new items
  });
}
```

**Critical Notes:**
- Next available HiveField index is `11` (createdAt is `10`)
- Using `double` to support fractional ordering (1, 1.5, 2, 2.25, 3...)
- Must run `flutter pub run build_runner build` after model change
- NEVER change existing HiveField numbers (data corruption risk)

#### B. Data Migration Strategy
Existing tokens in Hive database don't have `order` field.

**Implementation: Default Initialization with Silent Migration**
- Items without `order` field default to `0.0`
- First time user opens app after update, assign orders automatically in `TokenProvider` constructor
- **Migration is silent** - no toast notification (happens instantly in background)
  ```dart
  // In TokenProvider constructor after box initialization
  TokenProvider() {
    // ... box initialization ...
    _ensureOrdersAssigned();
  }

  void _ensureOrdersAssigned() {
    final items = itemsBox.values.toList();
    bool needsReorder = items.any((item) => item.order == 0);

    if (needsReorder) {
      // Assign sequential orders based on current position
      for (int i = 0; i < items.length; i++) {
        items[i].order = i.toDouble();
        items[i].save();
      }
    }
  }
  ```

**Why Silent Migration:**
- Migration is instant (typically <100ms for normal gameplay token counts)
- Users won't notice any difference - tokens simply appear in their current order
- No UI interruption needed

---

### 2. UI Changes

#### A. Replace ListView with ReorderableListView
**File:** `lib/screens/content_screen.dart`

**Current implementation:**
```dart
ValueListenableBuilder<Box<Item>>(
  valueListenable: tokenProvider.itemsListenable,
  builder: (context, box, _) {
    final items = box.values.toList();
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => TokenCard(item: items[index]),
    );
  },
)
```

**New implementation:**
```dart
ValueListenableBuilder<Box<Item>>(
  valueListenable: tokenProvider.itemsListenable,
  builder: (context, box, _) {
    final items = box.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order)); // Sort by order field

    return ReorderableListView.builder(
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        _handleReorder(items, oldIndex, newIndex);
      },
      proxyDecorator: _buildDragProxy, // Custom drag appearance
      itemBuilder: (context, index) {
        final item = items[index];
        return TokenCard(
          key: ValueKey(item.key), // Required for ReorderableListView
          item: item,
        );
      },
    );
  },
)
```

**Key Requirements:**
- Each child needs a unique `Key` (use `ValueKey(item.key)` - Hive provides unique key)
- `onReorder` callback handles the reordering logic
- Items must be sorted by `order` field before displaying
- `proxyDecorator` customizes appearance of dragged token

#### B. Drag Visual Feedback (proxyDecorator)

**UX Requirements:**
When user long-presses a token to begin dragging:
1. **Dragged token scales up** by ~5% (grows slightly larger)
2. **Dragged token "pops out"** with increased elevation/shadow
3. **Smooth reorder animation** as other tokens shift around the dragged item
4. On release, dragged token returns to normal size

**Note:** Dimming of non-dragged tokens (opacity reduction) is **scoped out for future refinement** to simplify initial implementation.

**Implementation:**
```dart
// Import needed: import 'dart:ui' show lerpDouble;

Widget _buildDragProxy(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      // Scale from 1.0 to 1.05 during drag (5% growth - adjustable during implementation)
      final scale = lerpDouble(1.0, 1.05, animation.value) ?? 1.0;

      return Transform.scale(
        scale: scale,
        child: Material(
          elevation: 8.0, // Higher elevation for "floating" effect
          shadowColor: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      );
    },
    child: child,
  );
}
```

**Why Scale + Elevation is Sufficient:**
- Clear visual distinction between dragged and static tokens
- Native Flutter animation feels polished
- Simpler implementation without state tracking complexity
- Can add dimming effect later as polish enhancement

#### C. Reorder Logic Implementation (Fractional Ordering)

**Why Fractional Ordering:**
- Enables O(1) insertion after existing tokens (copy, split stack)
- No need to renumber all subsequent items when inserting
- User requirement: copies/splits must appear immediately after original

**Implementation Strategy:**
- Use `double` for order field instead of `int`
- New items get whole numbers: 1, 2, 3, 4...
- Inserted items get fractional values: item between 1 and 2 gets 1.5
- Compact orders periodically to prevent precision issues

**Data Model Update:**
```dart
@HiveField(11) double order; // Changed from int to double
```

**Reorder Logic:**
```dart
void _handleReorder(List<Item> items, int oldIndex, int newIndex) {
  if (newIndex > oldIndex) {
    newIndex -= 1;
  }

  final item = items[oldIndex];

  // Calculate new fractional order
  double newOrder;
  if (newIndex == 0) {
    // Moving to top
    newOrder = items.first.order - 1.0;
  } else if (newIndex == items.length - 1) {
    // Moving to bottom
    newOrder = items.last.order + 1.0;
  } else {
    // Moving between two items
    final prevOrder = items[newIndex].order;
    final nextOrder = items[newIndex + 1].order;
    newOrder = (prevOrder + nextOrder) / 2.0;
  }

  item.order = newOrder;
  item.save();

  // Check if we need compacting (when gap becomes too small)
  _checkAndCompactOrders(items);
}

void _checkAndCompactOrders(List<Item> items) {
  // If any two adjacent items have order difference < 0.001, compact all orders
  items.sort((a, b) => a.order.compareTo(b.order));

  for (int i = 0; i < items.length - 1; i++) {
    if ((items[i + 1].order - items[i].order) < 0.001) {
      _compactOrders(items);
      return;
    }
  }
}

void _compactOrders(List<Item> items) {
  items.sort((a, b) => a.order.compareTo(b.order));
  for (int i = 0; i < items.length; i++) {
    items[i].order = i.toDouble();
    items[i].save();
  }
}
```

---

### 3. Provider Updates (TokenProvider)

#### A. Update TokenProvider Methods
**File:** `lib/providers/token_provider.dart`

**insertItem() - Assign order to new tokens:**
```dart
Future<void> insertItem(Item item) async {
  final items = itemsBox.values.toList();
  if (items.isEmpty) {
    item.order = 0.0;
  } else {
    // Find max order and add 1.0 (whole number for new items)
    final maxOrder = items.map((i) => i.order).reduce(max);
    item.order = maxOrder.floor() + 1.0;
  }
  await itemsBox.add(item);
  notifyListeners();
}
```

**addTokens() - Maintain order when adding to existing stack:**
```dart
void addTokens(Item item, int amount) {
  item.amount += amount;
  item.save(); // Order unchanged
  notifyListeners();
}
```

**copyToken() - New copy appears immediately after original (fractional order):**
```dart
Future<void> copyToken(Item original) async {
  // Find the next item after the original
  final items = itemsBox.values.toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  final originalIndex = items.indexWhere((i) => i.key == original.key);

  double newOrder;
  if (originalIndex == items.length - 1) {
    // Original is last item - add 1.0
    newOrder = original.order + 1.0;
  } else {
    // Insert between original and next item (fractional)
    final nextOrder = items[originalIndex + 1].order;
    newOrder = (original.order + nextOrder) / 2.0;
  }

  final newItem = Item(
    name: original.name,
    pt: original.pt,
    abilities: original.abilities,
    colors: original.colors,
    amount: original.amount,
    tapped: original.tapped,
    summoningSick: original.summoningSick,
    plusOneCounters: original.plusOneCounters,
    minusOneCounters: original.minusOneCounters,
    counters: original.counters.map((c) => TokenCounter(
      name: c.name,
      amount: c.amount,
    )).toList(),
    createdAt: DateTime.now(),
    order: newOrder,
  );

  await itemsBox.add(newItem);
  notifyListeners();
}
```

**Split stack logic (called from SplitStackSheet):**
```dart
Future<void> splitStack({
  required Item original,
  required int newStackAmount,
  required int newStackTapped,
  required int newStackSummoningSick,
  required bool copyCounters,
}) async {
  // Calculate fractional order (same as copyToken)
  final items = itemsBox.values.toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  final originalIndex = items.indexWhere((i) => i.key == original.key);

  double newOrder;
  if (originalIndex == items.length - 1) {
    newOrder = original.order + 1.0;
  } else {
    final nextOrder = items[originalIndex + 1].order;
    newOrder = (original.order + nextOrder) / 2.0;
  }

  // Create new split stack
  final newItem = Item(
    name: original.name,
    pt: original.pt,
    abilities: original.abilities,
    colors: original.colors,
    amount: newStackAmount,
    tapped: newStackTapped,
    summoningSick: newStackSummoningSick,
    plusOneCounters: copyCounters ? original.plusOneCounters : 0,
    minusOneCounters: copyCounters ? original.minusOneCounters : 0,
    counters: copyCounters ? original.counters.map((c) => TokenCounter(
      name: c.name,
      amount: c.amount,
    )).toList() : [],
    createdAt: DateTime.now(),
    order: newOrder,
  );

  await itemsBox.add(newItem);

  // Update original stack
  original.amount -= newStackAmount;
  original.tapped -= newStackTapped;
  original.summoningSick -= newStackSummoningSick;
  original.save();

  notifyListeners();
}
```

---

### 4. Deck Saving/Loading with Order Preservation

#### A. Update TokenTemplate Model
**File:** `lib/models/token_template.dart`

Add order field to preserve token position in saved decks:
```dart
@HiveType(typeId: 3)
class TokenTemplate extends HiveObject {
  @HiveField(0) String name;
  @HiveField(1) String pt;
  @HiveField(2) String abilities;
  @HiveField(3) String colors;
  @HiveField(4) double order; // NEW FIELD - preserves position

  TokenTemplate({
    required this.name,
    required this.pt,
    required this.abilities,
    required this.colors,
    this.order = 0.0,
  });

  factory TokenTemplate.fromItem(Item item) {
    return TokenTemplate(
      name: item.name,
      pt: item.pt,
      abilities: item.abilities,
      colors: item.colors,
      order: item.order,
    );
  }

  Item toItem({required int amount, required bool createTapped}) {
    return Item(
      name: name,
      pt: pt,
      abilities: abilities,
      colors: colors,
      amount: amount,
      tapped: createTapped ? amount : 0,
      summoningSick: 0,
      plusOneCounters: 0,
      minusOneCounters: 0,
      counters: [],
      createdAt: DateTime.now(),
      order: order, // Preserve order when loading
    );
  }
}
```

**Critical Notes:**
- Must run `flutter pub run build_runner build` after adding field
- Next available HiveField index for TokenTemplate is `4`
- Order is preserved from Item when saving

#### B. Deck Saving with Order Compacting
**File:** `lib/providers/deck_provider.dart` (or wherever deck saving logic lives)

When saving a deck, compact fractional orders to sequential integers:
```dart
Future<void> saveDeck(String deckName, List<Item> items) async {
  // Sort by current order
  final sortedItems = items.toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  // Convert to templates with compacted sequential orders
  final templates = sortedItems.asMap().entries.map((entry) {
    final index = entry.key;
    final item = entry.value;

    return TokenTemplate(
      name: item.name,
      pt: item.pt,
      abilities: item.abilities,
      colors: item.colors,
      order: index.toDouble(), // Compact: 0.0, 1.0, 2.0, 3.0...
    );
  }).toList();

  final deck = Deck(
    name: deckName,
    templates: templates,
  );

  await decksBox.add(deck);
  notifyListeners();
}
```

**Why Compact:**
- Keeps saved deck data clean (no fractional values like 1.5, 2.75)
- Prevents floating point precision issues from accumulating
- User requirement: "saved deck should simplify to single digits"

#### C. Deck Loading with Order Restoration and Confirmation Dialog

**Behavior:**
- **If board is empty:** Load deck directly without confirmation
- **If board has tokens:** Show confirmation dialog with 3 options

**Confirmation Dialog:**
```
"Loading {deckName}. Would you like to:"
- Clear tokens and load
- Add deck tokens to board
- Cancel
```

**Implementation:**
```dart
Future<void> loadDeck(Deck deck) async {
  final currentTokens = tokenProvider.itemsBox.values.toList();

  if (currentTokens.isNotEmpty) {
    // Show confirmation dialog
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Loading ${deck.name}'),
        content: Text('Would you like to:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'clear'),
            child: Text('Clear tokens and load'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'add'),
            child: Text('Add deck tokens to board'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text('Cancel'),
          ),
        ],
      ),
    );

    if (result == 'cancel' || result == null) return;

    if (result == 'clear') {
      await tokenProvider.boardWipeDelete();
      await _loadDeckTokens(deck, startOrder: 0.0);
    } else if (result == 'add') {
      // Find max order and append deck tokens after it
      final maxOrder = currentTokens.isEmpty
          ? 0.0
          : currentTokens.map((i) => i.order).reduce(max);
      await _loadDeckTokens(deck, startOrder: maxOrder.floor() + 1.0);
    }
  } else {
    // Board is empty - load directly
    await _loadDeckTokens(deck, startOrder: 0.0);
  }
}

Future<void> _loadDeckTokens(Deck deck, {required double startOrder}) async {
  // Sort templates by order
  final sortedTemplates = deck.templates.toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  // Create items preserving relative order
  for (int i = 0; i < sortedTemplates.length; i++) {
    final template = sortedTemplates[i];
    final item = template.toItem(
      amount: 1, // Default amount
      createTapped: false,
    );
    // Override order to position correctly (clear: 0,1,2... or add: maxOrder+1, maxOrder+2...)
    item.order = startOrder + i.toDouble();
    await tokenProvider.insertItemWithExplicitOrder(item);
  }
}
```

**Helper Method (add to TokenProvider):**
```dart
Future<void> insertItemWithExplicitOrder(Item item) async {
  // Item.order is already set - don't override it
  await itemsBox.add(item);
  notifyListeners();
}
```

**UX Notes:**
- "Clear tokens and load": Deck tokens start at order 0.0, 1.0, 2.0...
- "Add deck tokens to board": Deck tokens append at end with orders maxOrder+1, maxOrder+2...
- Both options preserve the deck's internal token order

---

### 5. Testing Plan

#### Manual Testing Checklist

**Visual Feedback:**
- [ ] Long-press token - token scales up ~5% (adjust if needed during implementation)
- [ ] Long-press token - token gains elevation/shadow (appears to float)
- [ ] Release token - token returns to normal size smoothly
- [ ] While dragging - smooth animation and visual feedback is clear

**Reordering:**
- [ ] Drag token up in list - order updates correctly
- [ ] Drag token down in list - order updates correctly
- [ ] Drag token to top position - becomes first
- [ ] Drag token to bottom position - becomes last
- [ ] While dragging - other tokens smoothly shift/reorder around dragged token
- [ ] Add new token - appears at bottom of list (highest order + 1)
- [ ] Restart app - order persists
- [ ] Copy token - appears immediately after original (fractional order)
- [ ] Copy token multiple times - all copies appear after original in sequence
- [ ] Split stack - new stack appears immediately after original
- [ ] Delete token - remaining tokens keep relative order
- [ ] Board wipe - clears all tokens correctly
- [ ] Save deck with reordered tokens - order preserved in deck
- [ ] Load deck on empty board - loads directly without confirmation
- [ ] Load deck with tokens on board - shows confirmation dialog
- [ ] Load deck → "Clear tokens and load" - board cleared, deck loads at order 0, 1, 2...
- [ ] Load deck → "Add deck tokens to board" - deck tokens append to end of list
- [ ] Load deck → "Cancel" - no changes, dialog closes
- [ ] Load deck with fractional orders - still loads correctly (backward compat)

#### Edge Cases
- [ ] Single token in list (dragging disabled automatically by Flutter)
- [ ] Two tokens - can swap positions
- [ ] Empty list → add first token → order = 0.0
- [ ] Rapid reordering (spam dragging) - no data corruption
- [ ] Reorder during active ValueListenableBuilder update - no crashes
- [ ] Copy same token 20+ times - fractional orders remain stable (no precision issues)
- [ ] Trigger compacting - orders reset to 0, 1, 2, 3... and list order unchanged
- [ ] Save deck after many copies - compacted orders are clean integers
- [ ] Load old deck (no order field) - tokens appear, can be reordered
- [ ] Mix of old tokens (order = 0) and new tokens - migration assigns sequential orders

---

## User Experience Goals

### Primary Objectives
1. **Intuitive Gesture:** Long-press and drag feels natural (standard mobile pattern)
2. **Visual Feedback:** Drag handle or elevation change shows token is movable
3. **Persistent Order:** Users can organize tokens by importance/role (e.g., attackers at top)
4. **No Accidental Triggers:** Long-press prevents accidental reordering during tap actions

### Non-Goals (Explicit Exclusions)
- Do NOT add "reorder mode" toggle - always draggable (long-press activates drag)
- Do NOT show visible "drag handle" icons on TokenCard - keeps UI clean
- Do NOT add "sort by name/P/T/color" options (conflicts with manual ordering)
- Do NOT add wobble/tilt physics during drag (moved to Future Enhancements)
- Do NOT add dimming effect for non-dragged tokens (moved to Future Enhancements)
- Do NOT add reordering to Deck loading/management screen (ContentScreen only)
- Do NOT show toast notification during order migration (silent migration)

---

## Implementation Notes

### File Changes Required
- `lib/models/item.dart` - Add `order` field (HiveField 11, type: double)
- `lib/models/token_template.dart` - Add `order` field (HiveField 4, type: double)
- `lib/models/item.g.dart` - Regenerate with build_runner
- `lib/models/token_template.g.dart` - Regenerate with build_runner
- `lib/screens/content_screen.dart` - Replace ListView with ReorderableListView, add reorder logic, add proxyDecorator for drag appearance
- `lib/providers/token_provider.dart` - Update insertItem, copyToken, add splitStack, add migration logic in constructor, add insertItemWithExplicitOrder, add compacting logic
- `lib/providers/deck_provider.dart` (or wherever deck loading is handled) - Update saveDeck to compact orders, update loadDeck with confirmation dialog and order restoration
- `lib/widgets/token_card.dart` - Add key parameter for ReorderableListView
- `lib/widgets/split_stack_sheet.dart` - Update to use new splitStack method with order support
- `lib/widgets/load_deck_sheet.dart` (or wherever deck loading UI is) - Update to call new loadDeck method with confirmation dialog

### Performance Considerations
- **Fractional ordering:** O(1) insertion for copy/split operations (no renumbering needed)
- **Manual reordering:** O(1) per drag operation (single order value update)
- **Compacting:** O(n) when gaps become too small, but rare (only after many insertions)
- **Deck saving:** O(n) to compact orders, acceptable for deck size (typically < 50 tokens)
- Hive `.save()` calls are fast (in-memory + async disk write)
- ReorderableListView handles animation smoothly
- Typical gameplay (5-20 tokens): all operations feel instant

### Backwards Compatibility
- **Item model:** Items without `order` field default to `0.0`
- **First load after update:** Auto-assign sequential orders based on current Hive iteration order
- **TokenTemplate model:** Templates without `order` field default to `0.0`
- **Existing saved decks:** Load correctly, tokens will have order 0.0 (all at top, then user can reorder)
- **No data loss or corruption risk:** Hive handles missing fields gracefully with defaults

### Future Enhancements (Out of Scope)
- **Dimming non-dragged tokens during drag:** Reduce opacity of non-dragged tokens to ~60% while dragging
  - Requires tracking drag state (onReorderStart/onReorderEnd callbacks)
  - May need custom StatefulWidget or TokenCard opacity parameter
  - ReorderableListView doesn't expose drag state directly
  - Scale + elevation provide sufficient visual feedback for initial release
- **Wobble/tilt physics during drag:** Add subtle rotation/skew to dragged token based on drag velocity
  - Should tilt/wobble with the motion of the user's finger (±2-5 degrees rotation)
  - Requires custom physics simulation based on drag velocity and acceleration
  - Should feel natural and subtle, not exaggerated
  - Adds visual polish but requires significant implementation effort
- "Reset order to creation time" action
- Group tokens by type/color (with manual reordering within groups)
- Drag-to-reorder in Deck loading/management screen
- Visual indicator showing drag handles (currently relies on long-press discovery)
- "Pin" tokens to always stay at top/bottom regardless of other reordering

---

## Design Decisions

The following design questions were answered and are now part of the implementation:

### 1. Copied and Split Tokens Position
**Decision:** Copies AND split stacks appear immediately after the original token.

**Rationale:**
- If a Treasure token is at the top and user copies it, the copy should be 2nd from top
- Same behavior for stack splitting
- Maintains logical grouping of related tokens
- User can manually reorder if desired

**Implementation:** Fractional ordering enables O(1) insertion without renumbering all items.

### 2. Ordering Strategy
**Decision:** Use fractional ordering (double) instead of sequential integers.

**Rationale:**
- Enables efficient insertion after existing tokens (no renumbering)
- Supports requirement #1 (copies/splits appear immediately after original)
- Automatic compacting when gaps become too small (< 0.001)
- Clean storage: new tokens get whole numbers, inserted tokens get fractions

### 3. Deck Order Preservation
**Decision:** Decks preserve token order on save/load, with compacting on save.

**Rationale:**
- Users may organize tokens strategically (attackers at top, utility at bottom)
- Compacting on save keeps deck data clean (0, 1, 2, 3... not 1.5, 2.75, etc.)
- Loading restores exact order
- No fractional precision issues accumulate in saved decks

### 4. Deck Loading Confirmation Dialog
**Decision:** Show confirmation dialog when loading a deck if board has existing tokens. Offer 3 options: "Clear tokens and load", "Add deck tokens to board", or "Cancel".

**Rationale:**
- Prevents accidental data loss (user may have current game state they want to preserve)
- "Clear tokens and load" = traditional deck loading (fresh board state)
- "Add deck tokens to board" = flexible workflow (combine multiple decks or add tokens to existing game)
- If board is empty, skip confirmation (no data to lose, faster UX)
- User has full control over merge vs. replace behavior

### 5. Visual Feedback Simplification
**Decision:** Use scale + elevation for drag feedback. Scope out dimming effect (opacity reduction of non-dragged tokens).

**Rationale:**
- Scale + elevation provide clear visual distinction between dragged and static tokens
- ReorderableListView doesn't expose drag state easily (would require custom StatefulWidget or workaround)
- Simplifies initial implementation - dimming can be added later as polish
- Native Flutter animation feels professional without additional complexity
