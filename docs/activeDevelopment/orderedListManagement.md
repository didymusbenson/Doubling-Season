# Ordered List Management Architecture Analysis

**Status:** Deferred to next release
**Date:** December 2025
**Context:** After implementing Krenko action trackers, we encountered ordering issues when creating new tokens from utilities. This led to an architecture review.

---

## The Problem

### Current Architecture
The board (ContentScreen) displays a unified list of items from multiple sources:
- `Item` tokens (in `Box<Item>`, managed by TokenProvider)
- `TrackerWidget` utilities (in `Box<TrackerWidget>`, managed by TrackerProvider)
- `ToggleWidget` utilities (in `Box<ToggleWidget>`, managed by ToggleProvider)

Each type has its own `order` field. Items are merged at render time using a helper `_BoardItem` class.

### The Ordering Bug
When creating new items (e.g., goblin tokens from Krenko utility):
- Order calculation only looked at same-type items
- New goblins got placed between existing tokens and utilities (wrong)
- Expected: New tokens at bottom of token list (before utilities)

**Root cause:** No centralized order calculation across all board item types.

### The Bigger Problem
Adding new utility types requires updating ~12 locations:
1. `_BoardItem` type checker (add `isNewType` getter)
2. Provider declaration in `_buildTokenList`
3. Listenable merge in `_buildTokenList`
4. Board items population loop
5. Color identity handling in `_buildBoardItemCard`
6. Card rendering in `_buildCardContent`
7. Deletion handling in `_deleteItem`
8. Reorder handling in `_handleReorder`
9. Order compaction in `_compactOrders`
10. BoardOrderManager order calculation
11. Widget selection screen order calculation
12. Provider initialization in `main.dart`

**Risk:** With 4-7 utility types planned, this becomes 36-48 manual touchpoints. High chance of bugs.

---

## Option 1: BoardOrderManager (Quick Fix)

### Implementation
Create a centralized utility class:

```dart
class BoardOrderManager {
  static double getNextOrder(BuildContext context) {
    final tokens = context.read<TokenProvider>().items;
    final trackers = context.read<TrackerProvider>().trackers;
    final toggles = context.read<ToggleProvider>().toggles;

    final allOrders = [
      ...tokens.map((t) => t.order),
      ...trackers.map((t) => t.order),
      ...toggles.map((t) => t.order),
    ];

    return allOrders.isEmpty ? 0.0 : allOrders.reduce(max).floor() + 1.0;
  }
}
```

Update all insertion points to use: `item.order = BoardOrderManager.getNextOrder(context);`

### Pros ✅
- **Quick to implement** - Single utility class, update ~3 insertion points
- **No data migration needed** - Zero risk to existing user data
- **Fixes immediate ordering bug** - New items get correct order
- **Low risk** - Small, localized change
- **Can ship this week** - Doesn't block current release

### Cons ❌
- **Only fixes order calculation** - Doesn't address architectural fragmentation
- **Still 12 touchpoints per new type** - Adding listener utilities requires updates in 12 places
- **No compile-time safety** - Easy to forget a touchpoint, code still compiles
- **Scattered type-specific logic** - Still duplicated if/else chains everywhere
- **Doesn't scale** - Pain increases linearly with each new type
- **Manual enforcement** - Requires documentation/checklists to remember all touchpoints

### Effort
- **Implementation:** 2 hours
- **Testing:** 1 hour
- **Per new type added:** 2 hours (12 touchpoints to update)

---

## Option 2: Parent Wrapper (Architectural Fix)

### Implementation
Create a unified board item hierarchy:

```dart
@HiveType(typeId: 100)
abstract class BoardItem extends HiveObject {
  @HiveField(0) String itemId;
  @HiveField(1) double order;
  @HiveField(2) DateTime createdAt;
  @HiveField(3) String colorIdentity;
  @HiveField(4) String? artworkUrl;

  // Polymorphic methods all items must implement
  Widget buildCard(BuildContext context);
  String get displayName;
}

@HiveType(typeId: 101)
class TokenBoardItem extends BoardItem {
  @HiveField(10) String name;
  @HiveField(11) String pt;
  @HiveField(12) int amount;
  // ... token-specific fields

  @override
  Widget buildCard(BuildContext context) => TokenCard(item: this);
}

@HiveType(typeId: 102)
class TrackerBoardItem extends BoardItem {
  @HiveField(20) int currentValue;
  @HiveField(21) int defaultValue;
  // ... tracker-specific fields

  @override
  Widget buildCard(BuildContext context) => TrackerWidgetCard(tracker: this);
}

@HiveType(typeId: 103)
class ToggleBoardItem extends BoardItem {
  @HiveField(30) bool isActive;
  @HiveField(31) String onDescription;
  @HiveField(32) String offDescription;
  // ... toggle-specific fields

  @override
  Widget buildCard(BuildContext context) => ToggleWidgetCard(toggle: this);
}
```

Unified provider:

```dart
class BoardProvider extends ChangeNotifier {
  late Box<BoardItem> _box;

  ValueListenable<Box<BoardItem>> get listenable => _box.listenable();
  List<BoardItem> get items => _box.values.toList();

  Future<void> insertItem(BoardItem item) async {
    if (item.order == 0.0) {
      final items = _box.values.toList();
      final maxOrder = items.isEmpty ? -1.0 : items.map((i) => i.order).reduce(max);
      item.order = maxOrder.floor() + 1.0;
    }
    await _box.add(item);
    notifyListeners();
  }

  void updateOrder(BoardItem item, double newOrder) {
    item.order = newOrder;
    item.save();
  }

  void deleteItem(BoardItem item) => item.delete();
}
```

Simplified ContentScreen:

```dart
Widget _buildTokenList() {
  return ValueListenableBuilder<Box<BoardItem>>(
    valueListenable: context.read<BoardProvider>().listenable,
    builder: (context, box, _) {
      final items = box.values.toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      return ReorderableListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return items[index].buildCard(context); // Polymorphic!
        },
        onReorder: (oldIndex, newIndex) {
          _handleReorder(items, oldIndex, newIndex);
        },
      );
    },
  );
}

void _handleReorder(List<BoardItem> items, int oldIndex, int newIndex) {
  // Calculate new order
  final item = items[oldIndex];
  final newOrder = /* ... calculation ... */;

  // Update order - works for ALL types
  item.order = newOrder;
  item.save();
}
```

### Pros ✅
- **True polymorphism** - `item.buildCard()`, `item.delete()` work for all types
- **Single source of truth** - One `Box<BoardItem>` contains everything
- **Trivial to add new types** - Extend `BoardItem`, register adapter → done
- **Compile-time safety** - Forget to implement required method → won't compile
- **Clean architecture** - Mental model: "Board contains ordered items"
- **No type-checking proliferation** - No if/else chains checking types
- **Unified state management** - One observable for entire board
- **Scales elegantly** - Complexity doesn't increase with new types

### Cons ❌
- **Migration complexity** - Must migrate all existing user data
- **Migration risk** - Bugs could lose user data (requires extensive testing)
- **Hive inheritance limitations** - Each subtype needs separate typeId
- **Type casting when needed** - `if (item is TokenBoardItem) item.amount += 5`
- **Performance consideration** - Deserializes all items (vs lazy loading per type)
- **Blocks shipping** - Can't ship until migration tested thoroughly
- **More boilerplate** - Separate typeId/adapter for each subtype

### Effort
- **Implementation:** 1 day (create hierarchy, write adapters)
- **Migration logic:** 1 day (write migration, test thoroughly)
- **Edge case testing:** 0.5 day (handle failures, verify data integrity)
- **Per new type added:** 30 minutes (extend class, register adapter)

### Migration Strategy
```dart
Future<void> migrateToBoardItems() async {
  final boardBox = await Hive.openBox<BoardItem>('boardItems');

  // Migrate tokens
  final itemsBox = Hive.box<Item>('items');
  for (final item in itemsBox.values) {
    final boardItem = TokenBoardItem(
      itemId: item.createdAt.toString(),
      order: item.order,
      createdAt: item.createdAt,
      colorIdentity: item.colors,
      artworkUrl: item.artworkUrl,
      name: item.name,
      pt: item.pt,
      amount: item.amount,
      // ... copy all fields
    );
    await boardBox.add(boardItem);
  }

  // Migrate trackers
  final trackersBox = Hive.box<TrackerWidget>('trackerWidgets');
  for (final tracker in trackersBox.values) {
    final boardItem = TrackerBoardItem(
      itemId: tracker.widgetId,
      order: tracker.order,
      // ... copy all fields
    );
    await boardBox.add(boardItem);
  }

  // Migrate toggles
  // ... similar pattern

  // Close and delete old boxes
  await itemsBox.close();
  await Hive.deleteBoxFromDisk('items');
  // ... repeat for other boxes
}
```

---

## The Scale Question

### Current State
- 3 utility types (tokens, trackers, toggles)
- ~12 touchpoints per new type with current architecture

### Planned Future
- **Confirmed:** Listener utilities (utilities with event listeners + action buttons)
- **Likely:** 2-3 more specialized utility types
- **Total:** 6-7 utility types

### Maintenance Burden Comparison

**With BoardOrderManager approach:**
| Types | Manual Touchpoints | Hours per Type | Total Hours |
|-------|-------------------|----------------|-------------|
| 4     | 12                | 2              | 2           |
| 5     | 12                | 2              | 4           |
| 6     | 12                | 2              | 6           |
| 7     | 12                | 2              | 8           |
| **Total** | **48** | | **20 hours** |

**With Parent Wrapper approach:**
| Types | Implementation    | Hours per Type | Total Hours |
|-------|-------------------|----------------|-------------|
| Initial migration | 1 | - | 20 hours |
| 4     | Extend class      | 0.5            | 0.5         |
| 5     | Extend class      | 0.5            | 1.0         |
| 6     | Extend class      | 0.5            | 1.5         |
| 7     | Extend class      | 0.5            | 2.0         |
| **Total** | | | **22 hours** |

**Break-even point:** At 4 utility types, both approaches take similar time.

**At 7 types:**
- BoardOrderManager: 20 hours ongoing work, high bug risk
- Parent Wrapper: 22 hours total, low bug risk, clean architecture

---

## Decision Matrix

### Choose BoardOrderManager If:
- ✅ Only adding **exactly 1 more type** ever
- ✅ Need to ship **this week**
- ✅ Prioritizing **stability** over architecture
- ✅ User data migration is **unacceptable risk**

### Choose Parent Wrapper If:
- ✅ Planning **4+ utility types** total
- ✅ Can dedicate **2-3 days** to migration
- ✅ Prioritizing **long-term maintainability**
- ✅ Want **compile-time safety** for new types
- ✅ Prefer **one-time pain** over **ongoing complexity**

---

## Recommendation

**For this project:** **Parent Wrapper migration recommended for next release.**

**Reasoning:**
1. **Scale:** 4-7 utility types planned → well past tipping point (4 types)
2. **ROI:** After initial migration, saves 1.5 hours per new type × 4 types = 6 hours saved
3. **Quality:** Compile-time safety prevents entire class of bugs
4. **Architecture:** Matches mental model ("board of items" not "separate systems")
5. **Timing:** Migration before listener implementation = less data to migrate

**Current release:** Use quick fix (set `order` explicitly in Krenko goblin creation) to unblock shipping.

**Next release:** Do Parent Wrapper migration **before** implementing listener utilities.

---

## Implementation Timeline (Next Release)

### Phase 1: Design (Week 1)
- [ ] Design `BoardItem` class hierarchy
- [ ] Plan field mapping for each subtype
- [ ] Design migration strategy
- [ ] Write migration rollback plan

### Phase 2: Implementation (Week 2)
- [ ] Create `BoardItem` abstract class
- [ ] Create `TokenBoardItem`, `TrackerBoardItem`, `ToggleBoardItem` subclasses
- [ ] Generate Hive adapters
- [ ] Create `BoardProvider`
- [ ] Write migration logic with extensive error handling
- [ ] Implement migration rollback mechanism

### Phase 3: Testing (Week 3)
- [ ] Test migration with sample data (all types)
- [ ] Test migration with edge cases (empty boxes, corrupt data)
- [ ] Test rollback mechanism
- [ ] Test board operations (insert, delete, reorder)
- [ ] Test app startup after migration
- [ ] User acceptance testing

### Phase 4: Rollout (Week 4)
- [ ] Deploy migration in app update
- [ ] Monitor for migration failures
- [ ] Be ready to rollback if issues arise

---

## Current Workaround (This Release)

**Quick fix applied:** Krenko goblin creation now explicitly calculates order based on existing tokens only.

**Code location:** `lib/widgets/tracker_widget_card.dart:_createGoblins()`

```dart
// Calculate order: Place at bottom of token list (before utilities)
final allTokenOrders = tokenProvider.items.map((item) => item.order).toList();
final maxTokenOrder = allTokenOrders.isEmpty ? -1.0 : allTokenOrders.reduce((a, b) => a > b ? a : b);
final newOrder = maxTokenOrder.floor() + 1.0;
newGoblin.order = newOrder; // Set order before inserting
```

**This solves:** Ordering bug for goblin creation
**This doesn't solve:** Architectural fragmentation for new types

---

## References

- Current implementation: `lib/screens/content_screen.dart` (see `_BoardItem` helper class)
- Related discussion: `docs/activeDevelopment/NextFeature.md` (Process for Adding New Utility Types checklist)
- Krenko implementation: `lib/widgets/tracker_widget_card.dart` (action tracker pattern)

---

## Open Questions for Next Release

1. **Should we create intermediate base classes?** (e.g., `ActionBoardItem` for utilities with action buttons)
2. **How to handle deck saving/loading?** (Currently uses `TokenTemplate`, needs equivalent for all board item types)
3. **Should we migrate artwork preferences?** (Currently in separate box, could be unified)
4. **Performance testing needed:** How does deserializing all items impact large boards (100+ items)?
5. **Can we make migration seamless?** (Run in background, show progress bar, allow app use during migration)
