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

## Action Trackers (Trackers with Action Buttons)

### Overview
Action Trackers extend the standard TrackerWidget with an optional action button. This allows trackers to not only track a value but also perform custom actions based on that value.

**Implementation:** Action trackers use the same base TrackerWidget class with additional fields for action button configuration, following DRY principles.

### Current Action Trackers

#### 1. Krenko, Mob Boss
- **Tracks:** Nontoken goblins you control
- **Action:** "Make Goblins" button creates goblin tokens equal to total goblins controlled (including token goblins) × multiplier
- **Default value:** 1 (Krenko himself)

#### 2. Krenko, Tin Street Kingpin
- **Tracks:** Krenko's power
- **Action:** "Make Goblins" button creates goblin tokens equal to Krenko's power × multiplier
- **Default value:** 1 (Krenko starts as 1/1)

### Data Model Extension

Action trackers use the existing `TrackerWidget` model with optional action fields:
```dart
@HiveField(12) bool hasAction; // True if this tracker has an action button
@HiveField(13) String? actionButtonText; // Text for action button (e.g., "Make Goblins")
@HiveField(14) String? actionType; // Type of action (e.g., "krenko_mob_boss")
```

### Implementation Pattern

1. **Definition** (`widget_database.dart`): Add utility with `hasAction: true` and `actionType` set
2. **Card Rendering** (`tracker_widget_card.dart`): Conditionally renders action button inline with +/- buttons
3. **Action Handler** (`tracker_widget_card.dart`): Switch statement routes to specific action based on `actionType`

### Token Creation Behavior

**Standard Goblin Token:**
- Name: "Goblin", P/T: "1/1", Colors: "R", Type: "Creature — Goblin", Abilities: ""

**Smart Token Merging:** If matching goblin token exists on board, adds to existing amount instead of creating duplicate card.

**Summoning Sickness:** Applied when global setting enabled.


# LATEST COMPLETED WORK

## Action Tracker Implementation (Krenko Utilities)

✅ **Implemented Action Tracker Pattern (DRY Solution)**

Instead of creating a separate utility type for Krenko, we extended the existing TrackerWidget infrastructure with optional action button support. This follows DRY principles and makes it easy to add more action trackers in the future.

### Changes Made:

**Data Model Extension** (`lib/models/tracker_widget.dart`):
- ✅ Added `@HiveField(12) bool hasAction`
- ✅ Added `@HiveField(13) String? actionButtonText`
- ✅ Added `@HiveField(14) String? actionType`
- ✅ Regenerated Hive adapters

**Card Rendering** (`lib/widgets/tracker_widget_card.dart`):
- ✅ Updated `_buildActionButtons()` to conditionally render third button when `hasAction == true`
- ✅ Added `_buildTextActionButton()` for text-based action buttons (inline with +/- buttons)
- ✅ Added `_performAction()` switch statement routing to specific actions
- ✅ Implemented `_performKrenkoMobBossAction()` - creates goblins based on total goblins controlled
- ✅ Implemented `_performKrenkoTinStreetAction()` - creates goblins based on Krenko's power
- ✅ Implemented `_createGoblins()` helper with smart token merging

**Widget Definitions** (`lib/database/widget_database.dart`):
- ✅ Added "Krenko, Mob Boss" tracker (tracks nontoken goblins, action creates based on total)
- ✅ Added "Krenko, Tin Street Kingpin" tracker (tracks power, action creates based on power)
- ✅ Both use `hasAction: true`, `actionButtonText: 'Make Goblins'`, different `actionType`

**Widget Definition Model** (`lib/models/widget_definition.dart`):
- ✅ Added action tracker fields to WidgetDefinition class
- ✅ Updated `toTrackerWidget()` to pass action fields through

### Benefits:
- No new Hive types needed
- No new providers needed
- No new card widgets needed
- Consistent styling with all other trackers
- Easy to add more action trackers (just add new case to switch statement)

### Testing:
- ✅ Build succeeds with no errors
- ✅ Both Krenko utilities available in utility selection
- ✅ Action buttons render inline with +/- buttons
- ✅ Goblin creation works with multiplier support
- ✅ Smart token merging prevents duplicate goblin cards

