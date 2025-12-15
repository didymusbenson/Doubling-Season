# UTILITY WIDGET TODO LIST

- Refine the appearance of toggles and trackers
- ✅ ~~Improve handling of artwork to match behaviors of tokens, including custom upload behavior~~ (COMPLETED - see below)
    - ✅ ~~Investigate whether they are using shared logic or have created redundant code. Can we DRY this?~~ (Using shared ArtworkVariant model)
- Set default artwork URLs for trackers/toggles that have predefined artwork (infrastructure ready, just need Scryfall URLs)

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

---

## Widget Artwork System Implementation (DRY with Tokens)

✅ **Implemented Artwork Support for Utilities - Matching Token Pattern Exactly**

Widgets (TrackerWidget and ToggleWidget) now have the exact same artwork system as tokens, using shared infrastructure with no code duplication.

### Changes Made:

**Data Model Updates:**
- ✅ **TrackerWidget** (`lib/models/tracker_widget.dart`):
  - Added `@HiveField(15) String? artworkSet` - Set code for artwork (e.g., "M13")
  - Added `@HiveField(16) List<ArtworkVariant>? artworkOptions` - Available artwork variants
  - Imported shared `ArtworkVariant` model from `token_definition.dart`

- ✅ **ToggleWidget** (`lib/models/toggle_widget.dart`):
  - Added `@HiveField(12) String? artworkSet` - Set code for artwork
  - Added `@HiveField(13) List<ArtworkVariant>? artworkOptions` - Available artwork variants
  - Imported shared `ArtworkVariant` model from `token_definition.dart`

**WidgetDefinition Updates** (`lib/models/widget_definition.dart`):
- ✅ Added `List<ArtworkVariant> artwork` field (defaults to empty list)
- ✅ Updated `toTrackerWidget()` to pass `artworkOptions: artwork.isNotEmpty ? List.from(artwork) : null`
- ✅ Updated `toToggleWidget()` to pass `artworkOptions: artwork.isNotEmpty ? List.from(artwork) : null`

**Widget Selection Screen** (`lib/screens/widget_selection_screen.dart:257-273`):
- ✅ Added automatic first-artwork application (matching token pattern exactly):
  ```dart
  if (definition.artwork.isNotEmpty) {
    final firstArtwork = definition.artwork[0];
    widget.artworkUrl = firstArtwork.url;
    widget.artworkSet = firstArtwork.set;
  }
  ```

**Database Setup** (`lib/database/widget_database.dart`):
- ✅ Added TODO placeholders for artwork URLs:
  - Krenko, Mob Boss (needs Scryfall URLs)
  - Krenko, Tin Street Kingpin (needs Scryfall URLs)
  - The Monarch (needs Scryfall URLs)

**Code Generation:**
- ✅ Regenerated Hive adapters for new fields (`build_runner build`)

### How It Works (Same as Tokens):

1. **Define artwork options** in `widget_database.dart`:
   ```dart
   artwork: [
     ArtworkVariant(set: 'M13', url: 'https://cards.scryfall.io/art_crop/...'),
     ArtworkVariant(set: 'DD2', url: 'https://cards.scryfall.io/art_crop/...'),
   ]
   ```

2. **First artwork auto-applies** when user creates widget from predefined list

3. **User can change artwork** later via widget details screen (uses same artwork selection UI as tokens)

4. **Artwork persists** in Hive alongside widget data

5. **Error handling** matches token pattern (safe fallbacks, no crashes on missing URLs)

### DRY Benefits:
- ✅ **Shared model:** Both systems use `ArtworkVariant` (no duplicate classes)
- ✅ **Shared manager:** Both use `ArtworkManager` for download/caching (no duplicate download logic)
- ✅ **Shared UI:** Both use same artwork selection screens (no duplicate UI code)
- ✅ **Shared cropping:** Both use `CroppedArtworkWidget` (no duplicate cropping logic)
- ✅ **Consistent behavior:** First-artwork auto-application works identically

### Testing:
- ✅ Code compiles with no errors (14 info-level warnings, 0 errors)
- ✅ Hive adapters generated successfully
- ✅ Models can accept and persist artwork data
- ✅ Widget selection screen applies first artwork automatically
- ✅ Ready for Scryfall URLs to be added to predefined widgets

### Next Step:
Add actual Scryfall artwork URLs to the TODO placeholders in `lib/database/widget_database.dart`. The infrastructure is 100% ready and will work immediately once URLs are provided.

