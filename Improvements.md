# Drag-to-Reorder Implementation

## Feature: Manual Drag-to-Reorder for Token List

Add persistent manual reordering capability to the token list in ContentView, allowing users to long-press on token cards and drag them to new positions.

---

## 1. Data Model Changes (Item.swift)

### Add sortOrder property:
```swift
var sortOrder: Double = 0  // Use Double for fractional positioning
```

### Update Item initializer:
- Do NOT modify the initializer parameter list
- Keep default value assignment: `self.sortOrder = 0`
- Migration handled at app level (see below)

### Update copyToken() in TokenView.swift (line 295-316):
- After creating `newItem`, set: `newItem.sortOrder = item.sortOrder + 0.5`
- This places copies directly beneath the original

### Update createDuplicate() in Item.swift (line 154-173):
- After creating `duplicate`, preserve original's sortOrder: `duplicate.sortOrder = sortOrder`
- SplitStackView will handle final positioning (see below)

---

## 2. Query Update (ContentView.swift)

### Change line 13:
```swift
// FROM:
@Query(sort: \Item.createdAt, order: .forward) private var items: [Item]

// TO:
@Query(sort: [SortDescriptor(\Item.sortOrder), SortDescriptor(\Item.createdAt)]) private var items: [Item]
```
- Primary sort by sortOrder
- Secondary sort by createdAt (tiebreaker for items with identical sortOrder, especially during migration)

---

## 3. Migration Logic (ContentView.swift)

### Add to onAppear block (currently line 188-194):
```swift
.onAppear {
    disableViewTimer()

    // One-time migration: assign sortOrder based on createdAt
    let unmigrated = items.filter { $0.sortOrder == 0 }
    if !unmigrated.isEmpty {
        let sorted = unmigrated.sorted { $0.createdAt < $1.createdAt }
        for (index, item) in sorted.enumerated() {
            item.sortOrder = Double(index)
        }
    }
}
```

---

## 4. New Token Placement

### Update addItem() function (line 287-301):
```swift
private func addItem(...) {
    let finalAmount = amount * multiplier
    let newItem = Item(...)

    // Place at bottom of list
    let maxSort = items.map { $0.sortOrder }.max() ?? -1.0
    newItem.sortOrder = maxSort + 1.0

    withAnimation {
        modelContext.insert(newItem)
    }
}
```

### Update loadDeck() function (line 257-282):
- Keep existing deletion logic
- After creating each `newItem`, assign sequential sortOrder:
```swift
deck.templates.enumerated().forEach { (index, deckItem) in
    let newItem = Item(...)
    newItem.sortOrder = Double(index)
    modelContext.insert(newItem)
}
```

---

## 5. Split Stack Positioning (SplitStackView.swift)

### Update the split completion logic:
- When creating the new split stack, set: `newStack.sortOrder = originalItem.sortOrder + 0.5`
- This places splits directly beneath the original token
- If user splits the same token multiple times, all splits will have identical sortOrder values (original + 0.5)
- Secondary sort by createdAt ensures most recent split appears last among siblings

---

## 6. Drag Gesture Implementation (TokenView.swift)

### Goal: Long-press (1 second) on non-interactive card areas to activate drag.

### Modify the VStack body (starting at line 31):

#### Step 6a: Add state for drag activation
```swift
@State private var isDragEnabled = false
```

#### Step 6b: Replace `.onTapGesture` (line 180-182) with combined gesture:
```swift
// Remove existing:
// .onTapGesture { isShowingExpandedView = true }

// Add instead:
.simultaneousGesture(
    LongPressGesture(minimumDuration: 1.0)
        .onEnded { _ in
            isDragEnabled = true
        }
)
.simultaneousGesture(
    TapGesture()
        .onEnded { _ in
            if !isDragEnabled {
                isShowingExpandedView = true
            }
            isDragEnabled = false
        }
)
```

#### Step 6c: Add drag provider (apply AFTER gesture modifiers, BEFORE sheet):
```swift
.onDrag {
    guard isDragEnabled else { return NSItemProvider() }
    // Provide item data for drag
    let itemData = item.objectID.uriRepresentation().absoluteString
    return NSItemProvider(object: itemData as NSString)
}
```

---

## 7. Drop Handling (ContentView.swift)

### Modify ForEach block (lines 77-92):

#### Add drop destination to TokenView:
```swift
ForEach(items) { item in
    TokenView(item: item)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
        .deleteDisabled(true)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    modelContext.delete(item)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onDrop(of: [.text], delegate: DropViewDelegate(
            destinationItem: item,
            items: items,
            modelContext: modelContext
        ))
}
```

---

## 8. Create DropViewDelegate (new struct in ContentView.swift)

Add this helper struct at the bottom of ContentView.swift (before #Preview):

```swift
struct DropViewDelegate: DropDelegate {
    let destinationItem: Item
    let items: [Item]
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        // Extract dragged item ID from drop info
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }

        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { (data, error) in
            guard let data = data as? Data,
                  let urlString = String(data: data, encoding: .utf8),
                  let url = URL(string: urlString),
                  let draggedItem = try? modelContext.existingObject(with: NSManagedObjectID(url: url)) as? Item
            else { return }

            DispatchQueue.main.async {
                reorderItems(draggedItem: draggedItem)
            }
        }

        return true
    }

    private func reorderItems(draggedItem: Item) {
        guard draggedItem != destinationItem else { return }

        // Calculate new sortOrder as average of neighbors
        if let destIndex = items.firstIndex(where: { $0.id == destinationItem.id }) {
            let prevSort = destIndex > 0 ? items[destIndex - 1].sortOrder : destinationItem.sortOrder - 1.0
            let nextSort = destinationItem.sortOrder

            draggedItem.sortOrder = (prevSort + nextSort) / 2.0
        }
    }
}
```

---

## 9. Visual Feedback

SwiftUI's `.onDrag()` provides automatic visual feedback:
- Dragged token lifts with shadow and slight scale
- Follows touch during drag
- Other items remain in place
- Drop indicator appears between items

No additional styling needed - standard iOS behavior.

---

## 10. Button Interaction Blocking

Current implementation already handles this correctly:
- All buttons use `.buttonStyle(BorderlessButtonStyle())` which captures gestures locally
- Long-press gestures on buttons trigger their specific alerts (lines 73-75, 92-94, 107-109, 121-123)
- Only long-press on card background (non-button areas) will activate drag
- The `.contentShape(Rectangle())` (line 179) ensures entire card area is tappable for ExpandedTokenView

**No changes needed** - gesture priority is already correct.

---

## Implementation Summary

1. ✅ Add `sortOrder: Double = 0` to Item model
2. ✅ Update @Query to sort by sortOrder (with createdAt tiebreaker)
3. ✅ Migration: auto-assign sortOrder based on createdAt order on first launch
4. ✅ New tokens: append to bottom (max sortOrder + 1)
5. ✅ Deck loading: sequential sortOrder starting from 0
6. ✅ Copy tokens: original sortOrder + 0.5 (directly beneath)
7. ✅ Split stacks: original sortOrder + 0.5 (directly beneath)
8. ✅ Drag activation: 1-second long-press on non-button card areas only
9. ✅ Visual feedback: Standard iOS lift/shadow effect
10. ✅ Reordering: Fractional sortOrder (average of neighbors)

---

## Testing Checklist:
- [ ] Existing tokens maintain visual order after update (migration works)
- [ ] New tokens appear at bottom
- [ ] Copied tokens appear directly beneath original
- [ ] Split stacks appear directly beneath original
- [ ] Long-press on card (not buttons) for 1 second activates drag
- [ ] Drag shows lift effect with shadow
- [ ] Dropping between tokens reorders correctly
- [ ] Order persists after app restart
- [ ] Buttons remain functional (don't activate drag)

