# Grid View Feature - Multi-Column Card Layout

**STATUS: Future Improvement Idea**

This document describes a potential future feature for supporting half-width cards in a multi-column grid layout. **This feature is NOT currently implemented and is NOT currently planned for implementation.** This is purely an architectural analysis for future reference.

## Feature Overview

The concept would allow board items (tokens and widgets) to be displayed in either:
- **Full-width** - Takes entire screen width (current behavior)
- **Half-width** - Two cards can fit side-by-side on a single row

Requirements:
- Half-width cards can be paired on the same row or split into different rows
- Full-width cards never share rows
- Cards can be rearranged with drag-and-drop, including:
  - Moving half-width cards to different rows
  - Swapping left/right positions within a row
  - Converting between full-width and half-width
  - Reordering between mixed-width cards

## Current System Architecture

### 1D Ordering System
Our current implementation uses a **linear ordering system** (see `lib/screens/content_screen.dart:447-528`):

```dart
class Item extends HiveObject {
  @HiveField(11)
  double order; // Fractional ordering value
  // ...
}
```

**Key characteristics:**
- Each item has a single `double order` field
- Items are sorted by this value in ascending order
- When reordering, new position is calculated via fractional averaging:
  - Moving to top: `newOrder = firstItem.order - 1.0`
  - Moving to bottom: `newOrder = lastItem.order + 1.0`
  - Moving between items: `newOrder = (prevOrder + nextOrder) / 2.0`
- Auto-compacts to sequential integers when gaps become too small (`< 0.001`)
- Renders using `ReorderableListView.builder` (single-column layout)

**What it CANNOT represent:**
- Row grouping (which items share a row)
- Horizontal positioning (left vs right)
- Variable card widths
- Multi-column layouts

### Current Data Models
```dart
// Item (tokens)
class Item extends HiveObject {
  @HiveField(11) double order;
  // No width or position fields
}

// TrackerWidget (experimental widgets)
class TrackerWidget extends HiveObject {
  @HiveField(6) double order;
  // No width or position fields
}

// ToggleWidget (experimental widgets)
class ToggleWidget extends HiveObject {
  @HiveField(6) double order;
  // No width or position fields
}
```

### Current UI Rendering
```dart
// Single-column ReorderableListView
ReorderableListView.builder(
  itemCount: boardItems.length,
  onReorder: (oldIndex, newIndex) => _handleReorder(...),
  itemBuilder: (context, index) {
    return _buildBoardItemCard(boardItems[index], index);
  },
)
```

## Required Changes for Grid View

### 1. Data Model Changes (Medium Complexity)

Add new Hive fields to `Item`, `TrackerWidget`, and `ToggleWidget`:

```dart
@HiveField(16) // Use next available field ID for each model
String width = 'full'; // 'full' or 'half'

@HiveField(17)
String? rowPosition; // null for full-width, 'left' or 'right' for half-width
```

**Considerations:**
- Requires Hive type adapter regeneration (`flutter pub run build_runner build`)
- Existing data will use default values (backward compatible)
- Deck templates need updating to include width/position
- Migration path: all existing items default to `width: 'full'`

**Estimated effort:** 50-100 lines of code, low-medium complexity

### 2. Ordering System Redesign (High Complexity)

Two architectural options:

#### Option A: Keep Fractional `order`, Add Pairing Logic
```dart
@HiveField(11) double order;           // Existing
@HiveField(17) String? rowPosition;    // NEW
```

**Logic:**
- Items with similar `order` values (within threshold) and `width: 'half'` can pair
- Scan adjacent items to determine row grouping
- Requires complex pairing detection algorithm

**Pros:**
- Minimal change to existing ordering logic
- Fractional averaging still works

**Cons:**
- Implicit row grouping is fragile
- Complex edge cases (what if three half-width items have close order values?)
- Hard to reason about which items will pair

#### Option B: Explicit `row` + `column` Fields (Recommended)
```dart
@HiveField(16) int row = 0;      // Which row (0, 1, 2, ...)
@HiveField(17) int column = 0;   // 0 = left/full-width, 1 = right
@HiveField(18) String width = 'full'; // 'full' or 'half'
```

**Logic:**
- Each item knows exactly which row and column it occupies
- Full-width items: `row: N, column: 0`
- Half-width left: `row: N, column: 0`
- Half-width right: `row: N, column: 1`
- No ambiguity about grouping

**Pros:**
- Explicit, easy to reason about
- Clear representation of layout
- Easier to implement drag-and-drop logic

**Cons:**
- Complete rewrite of ordering system
- Need compacting logic when rows are deleted
- More fields to manage

**Estimated effort:** 300-500 lines of code, high complexity

### 3. UI Rendering System (High Complexity)

`ReorderableListView` cannot support multi-column layouts. Three options:

#### Option A: Custom Layout with Manual Drag Handling
```dart
Widget _buildBoard(List<_BoardItem> items) {
  // Group items by row
  final rows = _groupItemsIntoRows(items);

  return Column(
    children: rows.map((row) {
      if (row.length == 1 && row[0].width == 'full') {
        // Full-width card
        return _buildFullWidthCard(row[0]);
      } else {
        // Row with 1-2 half-width cards
        return Row(
          children: row.map((item) =>
            Expanded(child: _buildHalfWidthCard(item))
          ).toList(),
        );
      }
    }).toList(),
  );
}
```

Implement drag-and-drop using:
- `LongPressDraggable` for each card
- `DragTarget` for each drop zone (between rows, left/right positions)
- Manual state management for drag feedback
- Custom animations and visual feedback

**Pros:**
- Full control over layout and behavior
- Can optimize for this specific use case

**Cons:**
- Must implement all drag-and-drop logic from scratch
- Complex edge case handling
- Significant testing required

#### Option B: Use Existing Package
- `reorderable_grid_view` - designed for uniform grids (not suitable)
- `flutter_reorderable_grid_view` - supports variable sizes but has limitations
- Most packages assume uniform item sizes or fixed grid patterns

**Pros:**
- Less code to write
- Some edge cases handled by package

**Cons:**
- Packages may not support full-width items mixed with half-width
- Less control over behavior
- Dependency on third-party maintenance

#### Option C: Hybrid Column of Rows (Recommended)
```dart
Column(
  children: _buildRows(items).map((row) {
    return _buildReorderableRow(row);
  }).toList(),
)
```

Each row is a separate widget that handles its own internal reordering (left/right swap). Between-row reordering uses custom drag targets.

**Pros:**
- Balance of control and simplicity
- Can reuse some existing patterns
- Clear separation of concerns (row-level vs card-level)

**Cons:**
- Still significant implementation effort
- Need careful state coordination

**Estimated effort:** 400-600 lines of code, high complexity

### 4. Reorder Logic (Very High Complexity)

Must handle numerous edge cases:

#### Case 1: Drag Full-Width Between Full-Width Items
```
Before:  [A full]
         [B full]

After:   [B full]
         [A full]
```
**Action:** Swap row numbers

#### Case 2: Drag Half-Width to Row with Compatible Half-Width
```
Before:  [A half-left] [empty]
         [B half-right] [empty]

After:   [A half-left] [B half-right]
```
**Action:** Update row numbers to match, set column positions

#### Case 3: Drag Half-Width onto Full-Width Row
```
Before:  [A full]
         [B half-left] [empty]

After:   [A half-left] [B half-left]  // OR shift A down?
```
**Action:** Either split the full-width item to half-width, OR shift it to next row

#### Case 4: Swap Half-Width Cards in Same Row
```
Before:  [A half-left] [B half-right]

After:   [B half-left] [A half-right]
```
**Action:** Swap column values

#### Case 5: Remove Last Item from Row
```
Before:  [A half-left] [B half-right]
         [C full]

After:   [A half-left] [empty]  // User removed B
         [C full]
```
**Action:** Leave A alone, or auto-expand to full-width?

#### Case 6: Drag Half-Width to Empty Position
```
Before:  [A half-left] [B half-right]
         [C full]

After:   [A half-left] [B half-right]
         [C half-left] [empty]  // User dragged C here
```
**Action:** Convert full-width to half-width, update row/column

**Validation Rules:**
- No row can have more than 2 items
- Full-width items must have `column: 0`
- If row has full-width item, it cannot have a second item
- Row numbers must be sequential after compacting
- Left position must exist before right position can be used

**Estimated effort:** 200-400 lines of code, very high complexity

### 5. Visual Feedback During Drag (Medium Complexity)

Current system uses `proxyDecorator` for simple scale/elevation effect. New system needs:

**Drag Preview:**
- Show outline of where card will land
- Highlight valid drop zones (left/right positions, between rows)
- Show "invalid drop" state for disallowed positions

**Drop Zone Indicators:**
- Placeholder widgets showing "drop here" targets
- Different indicators for:
  - Between-row drops (insert new row)
  - Left position drops (pair with existing right-side item)
  - Right position drops (pair with existing left-side item)
  - Cannot-drop zones (shaded out)

**Animation:**
- Cards shifting to make room for dropped item
- Smooth expansion/collapse when changing width
- Row height adjustments

**Estimated effort:** 200-300 lines of code, medium complexity

## Complexity Summary

| Component | Current LOC | Estimated New LOC | Complexity |
|-----------|-------------|-------------------|------------|
| Data models | ~300 | +50-100 (new fields) | Low-Medium |
| Ordering logic | ~100 | ~300-500 | High |
| UI rendering | ~150 | ~400-600 | High |
| Drag handling | ~50 | ~200-400 | Very High |
| Visual feedback | ~50 | ~200-300 | Medium |
| **Total** | ~650 | **~1150-1900** | **High** |

**Overall estimate:** 2-4 days of focused development + 1-2 days of testing and polish

## Recommendations

### If Implementing This Feature:

1. **Use explicit `row` + `column` fields** (Option B)
   - Easier to reason about than fractional pairing
   - Clearer representation of layout
   - Worth the rewrite cost

2. **Build hybrid Column/Row layout** (Option C)
   - Good balance of control and simplicity
   - Can leverage existing patterns
   - Avoids package dependencies

3. **Start with proof-of-concept**
   - Build simplified version with 2-3 static cards
   - Test drag logic before refactoring everything
   - Validate UX before committing to full implementation

4. **Phase the rollout:**
   - **Phase 1:** Add width toggle (full vs compact), auto-pair consecutive compact items
   - **Phase 2:** Add manual left/right positioning
   - **Phase 3:** Add full drag-and-drop between all positions

### Simpler Alternative (50% Less Complexity):

Instead of explicit left/right positioning:
- Allow users to toggle cards between "full" and "compact" width
- Auto-pair consecutive compact-width items into rows (by order value)
- Don't allow explicit left/right positioning initially
- Much simpler rendering: just check if next item is also compact

```dart
Widget _buildList(List<Item> items) {
  int i = 0;
  List<Widget> rows = [];

  while (i < items.length) {
    if (items[i].width == 'full') {
      rows.add(_buildFullWidthCard(items[i]));
      i++;
    } else if (i + 1 < items.length && items[i + 1].width == 'compact') {
      // Pair them
      rows.add(Row([
        Expanded(child: _buildCompactCard(items[i])),
        Expanded(child: _buildCompactCard(items[i + 1])),
      ]));
      i += 2;
    } else {
      // Single compact card (takes left half)
      rows.add(Row([
        Expanded(child: _buildCompactCard(items[i])),
        Expanded(child: SizedBox.shrink()),
      ]));
      i++;
    }
  }

  return Column(children: rows);
}
```

This would:
- Keep the existing `order` field system
- Only add `width` field (no position field)
- Use existing `ReorderableListView` (items still reorder linearly)
- Auto-pair adjacent compact items when rendering
- Cut complexity by approximately 50%

## Related Files

- `lib/screens/content_screen.dart:447-528` - Current ordering logic
- `lib/models/item.dart` - Token data model
- `lib/models/tracker_widget.dart` - Tracker widget data model
- `lib/models/toggle_widget.dart` - Toggle widget data model
- `lib/widgets/token_card.dart` - Token card rendering
- `lib/widgets/tracker_widget_card.dart` - Tracker card rendering
- `lib/widgets/toggle_widget_card.dart` - Toggle card rendering

## Open Questions

1. **Width toggle UI:** Where should users toggle between full/compact width? Long-press menu? Settings per-card? Global preference?

2. **Auto-expand behavior:** If a half-width card is the only item in its row, should it auto-expand to full-width or stay half-width with empty space?

3. **Deck persistence:** Should deck templates remember width/position, or only order?

4. **Default width for new items:** Should new tokens default to full or half-width? Should it be configurable?

5. **Drag restrictions:** Should we allow dragging half-width items onto full-width rows (forcing split), or only allow drops into compatible positions?

6. **Mobile vs tablet:** Should compact mode only be available on tablets/large screens, or also on phones?

## Conclusion

The current 1D fractional ordering system is **fundamentally incompatible** with multi-column grid layouts. Implementing this feature would require:
- Complete redesign of the ordering system
- Replacement of `ReorderableListView` with custom layout
- Complex drag-and-drop logic for 2D positioning
- Extensive edge case handling
- Significant testing

**This is NOT a quick refactor** - it's a substantial feature that would take multiple days of focused development. The simpler alternative (auto-pairing compact items) would be a more reasonable starting point if this functionality is desired in the future.
