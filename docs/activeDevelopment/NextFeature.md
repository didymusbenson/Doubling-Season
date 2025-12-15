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

We just added artwork for all of the toggles and trackers defined so far. 

We solved a number of issues with them not rendering displaying and updating the same way tokens do. 

We are currently troubleshooting issues with half-card view and graidents. The last messages before we hit spending cap were as follows:

```
> They do not fade appropriately on half card view.

⏺ Let me check the exact fadeout gradient implementation in TokenCard to see if there's a difference:

⏺ Read(lib/widgets/token_card.dart)
⎿  Read 25 lines

⏺ The gradient code looks identical to TokenCard. Let me check if there's a structural difference in how the layers are stacked. Let me compare the
full Stack structure:

⏺ Search(pattern: "Stack\(", path: "lib/widgets/token_card.dart", output_mode: "content")
⎿  Found 36 lines (ctrl+o to expand)

⏺ Search(pattern: "Stack\(", path: "lib/widgets/tracker_widget_card.dart", output_mode: "content")
⎿  Found 31 lines (ctrl+o to expand)

⏺ The gradient implementation looks identical to TokenCard. Can you describe what's specifically wrong with the fade? Is it:

1. Not fading at all (artwork just appears solid)?
2. Fading too abruptly (not smooth enough)?
3. Fading in the wrong area (should cover more or less of the artwork)?
4. Fading in the wrong direction (should fade opposite way)?

The current gradient setup is:
- Fades from transparent (left edge of artwork) to opaque (middle of artwork)
- This covers the left 50% of the artwork widget, which is the center 25% of the card
- The right 50% of the artwork (right 25% of card) remains fully opaque

If tokens are fading differently, I need to know what specifically looks wrong so I can identify the difference.

> There is zero fade whatsoever.


⏺ Now to answer your question:

YES, tokens force the artwork container to be exactly 50% of the card width in fadeout/half view mode.

Looking at TokenCard's fadeout implementation:

Widget _buildFadeoutArtwork(BuildContext context, BoxConstraints constraints) {
final cardWidth = constraints.maxWidth;
final artworkWidth = cardWidth * 0.50;  // 50% of card width

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: artworkWidth,  // ← CONSTRAINS container to 50% width
      child: ...
        CroppedArtworkWidget(
          ...
          fillWidth: false,  // ← Image scales to fill HEIGHT (not width)
        ),
      ),
    );
}

The Positioned widget with width: artworkWidth forces the container to be exactly 50% of card width, positioned on the right side. Then fillWidth:
false tells CroppedArtworkWidget to scale the image to fill the container's HEIGHT, which causes it to potentially overflow leftward (where the
gradient fade masks it).

My utility implementation does the same thing - so the 50% width constraint is identical between tokens and utilities.

> You are mistaken. [Image #1]
```

When I sent the message "You are mistaken" I included the image "noitdoesnt.png" which you can find here in the /activeDevelopment directory.

Once we sort out the artwork rendering, we should be ready to move onto the next special utility: Cathar's Crusade.
