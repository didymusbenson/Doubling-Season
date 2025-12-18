# UTILITY WIDGET TODO LIST

✅ ALL CURRENT UTILITIES COMPLETE - Ready for Cathar's Crusade

- ✅ ~~Refine the appearance of toggles and trackers~~ (COMPLETED)
- ✅ ~~Improve handling of artwork to match behaviors of tokens~~ (COMPLETED)
- ✅ ~~Set default artwork URLs for trackers/toggles~~ (COMPLETED - all 13 utilities have Scryfall artwork)

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
- [ ] Implement `init()` method with try-catch and debug logging
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
- [ ] **CRITICAL: Use TokenCard as reference implementation**
- [ ] Use `Selector<SettingsProvider, String>` for artwork display style
- [ ] Implement artwork layers following EXACT pattern from TokenCard:
  - Base card background layer
  - Gradient background layer (conditional)
  - Artwork layer using `_buildArtworkLayer(context, constraints, artworkDisplayStyle)`
  - Content layer with semi-transparent backgrounds (0.85 alpha)
- [ ] Implement `_buildArtworkLayer()` that delegates to `_buildFullViewArtwork()` and `_buildFadeoutArtwork()`
- [ ] In fadeout mode: Use `Positioned(width: cardWidth * 0.50)` for 50% width constraint
- [ ] Wrap `CroppedArtworkWidget` with `ShaderMask` for gradient fade
- [ ] Pass `fillWidth: false` to `CroppedArtworkWidget` for fadeout mode
- [ ] Implement tap handler to open `ExpandedWidgetScreen`
- [ ] Save changes to Hive on user interactions

### 7. Widget Definition (`lib/models/widget_definition.dart`)
- [ ] Add new type to `WidgetType` enum (if needed)
- [ ] Import your utility model
- [ ] Add `toYourUtility()` factory method to create instances

### 8. Widget Database (`lib/database/widget_database.dart`)
- [ ] Add predefined utility definition to `loadWidgets()` list
- [ ] Include Scryfall artwork URLs (at least one ArtworkVariant)

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
- [ ] **Artwork displays correctly in BOTH fullView and fadeout modes**
- [ ] **Artwork fills container properly without stretching**
- [ ] Utility can be reordered with other board items
- [ ] Utility responds to user interactions correctly
- [ ] Utility state persists across app restarts
- [ ] Utility can be deleted via swipe
- [ ] Expanded view works (tap to open)
- [ ] Artwork selection works

**CRITICAL:** If your utility doesn't appear or work correctly, review each step above. Missing ANY step will break functionality.

---

## Artwork Implementation Pattern (MEMORIZE THIS)

When creating new card types (tokens, utilities, or any future board items), artwork must be implemented following this exact pattern to ensure consistent behavior across fullView and fadeout modes.

### Required Setup

**1. Card State Variables:**
```dart
final DateTime _createdAt = DateTime.now();
bool _artworkAnimated = false;
bool _artworkCleanupAttempted = false;
```

**2. Widget Structure (use LayoutBuilder + Stack):**
```dart
return Selector<SettingsProvider, String>(
  selector: (context, settings) => settings.artworkDisplayStyle,
  builder: (context, artworkDisplayStyle, child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Layer 1: Base card background
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
              ),
            ),
            
            // Layer 2: Gradient background (shows when no artwork or while loading)
            if (artworkUrl == null || artworkUrl.isEmpty)
              _buildGradientLayer(context)
            else
              _buildConditionalGradient(context),
            
            // Layer 3: Artwork layer
            if (artworkUrl != null)
              _buildArtworkLayer(context, constraints, artworkDisplayStyle),
            
            // Layer 4: Content with semi-transparent backgrounds
            Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(UIConstants.cardPadding),
              child: // ... your content
            ),
          ],
        );
      },
    );
  },
);
```

**3. Artwork Layer Builder:**
```dart
Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints, String artworkStyle) {
  if (artworkStyle == 'fadeout') {
    return _buildFadeoutArtwork(context, constraints);
  } else {
    return _buildFullViewArtwork(context, constraints);
  }
}
```

**4. Full View Implementation:**
```dart
Widget _buildFullViewArtwork(BuildContext context, BoxConstraints constraints) {
  final crop = ArtworkManager.getCropPercentages(artworkUrl);
  
  return Positioned.fill(
    child: FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(artworkUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          // Animation logic
          final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
          final shouldAnimate = elapsed > 100 && !_artworkAnimated;
          
          if (shouldAnimate) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _artworkAnimated = true);
            });
          }
          
          return AnimatedOpacity(
            opacity: 1.0,
            duration: shouldAnimate ? const Duration(milliseconds: 500) : Duration.zero,
            curve: Curves.easeIn,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
              child: CroppedArtworkWidget(
                imageFile: snapshot.data!,
                cropLeft: crop['left']!,
                cropRight: crop['right']!,
                cropTop: crop['top']!,
                cropBottom: crop['bottom']!,
                fillWidth: true,  // ← FULL VIEW: fill width
              ),
            ),
          );
        }
        
        // Cleanup logic for missing files
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data == null &&
            !_artworkCleanupAttempted) {
          final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
          if (elapsed > 2000) {
            _artworkCleanupAttempted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                artworkUrl = null;
                save();
              }
            });
          }
        }
        
        return const SizedBox.shrink();
      },
    ),
  );
}
```

**5. Fadeout Implementation (CRITICAL - must constrain width to 50%):**
```dart
Widget _buildFadeoutArtwork(BuildContext context, BoxConstraints constraints) {
  final crop = ArtworkManager.getCropPercentages(artworkUrl);
  final cardWidth = constraints.maxWidth;
  final artworkWidth = cardWidth * 0.50;  // ← CRITICAL: 50% width
  
  return Positioned(
    right: 0,
    top: 0,
    bottom: 0,
    width: artworkWidth,  // ← CRITICAL: constrains container to 50% width
    child: FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(artworkUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          // Same animation logic as full view
          final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
          final shouldAnimate = elapsed > 100 && !_artworkAnimated;
          
          if (shouldAnimate) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _artworkAnimated = true);
            });
          }
          
          return AnimatedOpacity(
            opacity: 1.0,
            duration: shouldAnimate ? const Duration(milliseconds: 500) : Duration.zero,
            curve: Curves.easeIn,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(UIConstants.smallBorderRadius),
                bottomRight: Radius.circular(UIConstants.smallBorderRadius),
              ),
              child: ShaderMask(  // ← CRITICAL: gradient fade
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.0, 0.50],  // ← Fade covers left 50% of artwork container
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: CroppedArtworkWidget(
                  imageFile: snapshot.data!,
                  cropLeft: crop['left']!,
                  cropRight: crop['right']!,
                  cropTop: crop['top']!,
                  cropBottom: crop['bottom']!,
                  fillWidth: false,  // ← CRITICAL: scale to fill HEIGHT, not width
                ),
              ),
            ),
          );
        }
        
        // Same cleanup logic as full view
        return const SizedBox.shrink();
      },
    ),
  );
}
```

### CroppedArtworkWidget Scaling Logic

The `CroppedArtworkWidget` (`lib/widgets/cropped_artwork_widget.dart`) handles aspect ratio scaling:

**Full View Mode (`fillWidth: true`):**
- Scales image to fill container WIDTH
- May overflow vertically (gets clipped)
- Centers vertically

**Fadeout Mode (`fillWidth: false`):**
- Scales image to fill container HEIGHT
- If resulting width < container width → rescales to fill width (maintains aspect ratio)
- If resulting width >= container width → uses height-based scale, overflows left (gradient masks it)
- This ensures the 50% container is always filled without stretching

### Text Overlays

All text and buttons must have semi-transparent backgrounds for readability over artwork:

```dart
Widget _buildTextWithBackground({
  required BuildContext context,
  required Widget child,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor.withValues(alpha: 0.85),  // ← 85% opacity
      borderRadius: BorderRadius.circular(6),
    ),
    child: child,
  );
}
```

### Common Mistakes to Avoid

1. **Missing width constraint in fadeout mode** → Artwork fills entire card width
2. **Using `fillWidth: true` in fadeout mode** → Artwork doesn't fill container height
3. **Forgetting ShaderMask in fadeout mode** → No gradient fade
4. **Wrong gradient stops** → Fade appears in wrong area
5. **Missing LayoutBuilder** → Can't get card width for 50% calculation
6. **Stretching instead of scaling** → `CroppedArtworkWidget` now handles this, but old implementations had this bug

### Testing Checklist

When implementing artwork for a new card type, verify:
- [ ] Full view: Artwork fills entire card width
- [ ] Full view: Artwork maintains aspect ratio (no stretching)
- [ ] Fadeout: Artwork container is exactly 50% of card width
- [ ] Fadeout: Artwork fills the 50% container without stretching
- [ ] Fadeout: Gradient fade is visible on left edge of artwork
- [ ] Fadeout: Right edge of artwork is fully opaque
- [ ] Both modes: Text and buttons have semi-transparent backgrounds
- [ ] Both modes: Artwork animates on first load (if downloaded)
- [ ] Both modes: Missing artwork files clean up after 2 seconds

**Reference Implementation:** `lib/widgets/token_card.dart` (lines 565-727)

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

---

# NEXT UP: Cathar's Crusade

Now that all artwork and Krenko utilities are complete, the next special utility to implement is **Cathar's Crusade**.
