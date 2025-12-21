# Next Feature Development

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
- [ ] Use `Selector<SettingsProvider, String>` to watch `artworkDisplayStyle` (utilities only need this setting, NOT `summoningSicknessEnabled`)
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

**3. Artwork Layer Builder (Inline Implementation):**

**IMPORTANT:** The implementation uses a single method with inline if/else blocks, NOT separate helper methods. This pattern matches the actual implementations in TrackerWidgetCard and ToggleWidgetCard.

```dart
Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints, String artworkDisplayStyle) {
  final crop = ArtworkManager.getCropPercentages(artworkUrl);
  final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;

  // Cleanup logic for missing files (runs in both modes)
  if (elapsed > 2000 && !_artworkCleanupAttempted) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _artworkCleanupAttempted = true;
        });
      }
    });
  }

  // Animation trigger (runs in both modes)
  if (elapsed > 100 && !_artworkAnimated) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _artworkAnimated = true;
        });
      }
    });
  }

  // FADEOUT MODE
  if (artworkDisplayStyle == 'fadeout') {
    final cardWidth = constraints.maxWidth;
    final artworkWidth = cardWidth * 0.50;  // ← CRITICAL: 50% width constraint

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: artworkWidth,  // ← CRITICAL: constrains container to 50% width
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return AnimatedOpacity(
              opacity: _artworkAnimated ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeIn,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(UIConstants.smallBorderRadius),
                  bottomRight: Radius.circular(UIConstants.smallBorderRadius),
                ),
                child: ShaderMask(  // ← CRITICAL: gradient fade on left edge
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.50],  // Fade covers left 50% of artwork container
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

          // Cleanup for missing artwork
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null &&
              !_artworkCleanupAttempted &&
              elapsed > 2000) {
            _artworkCleanupAttempted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Clear artwork URL from model and save
                artworkUrl = null;
                save();
              }
            });
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // FULL VIEW MODE
  else {
    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return AnimatedOpacity(
              opacity: _artworkAnimated ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeIn,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(UIConstants.borderRadius - 3.0),
                child: CroppedArtworkWidget(
                  imageFile: snapshot.data!,
                  cropLeft: crop['left']!,
                  cropRight: crop['right']!,
                  cropTop: crop['top']!,
                  cropBottom: crop['bottom']!,
                  fillWidth: true,  // ← FULL VIEW: fill width, crop height
                ),
              ),
            );
          }

          // Cleanup for missing artwork
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null &&
              !_artworkCleanupAttempted &&
              elapsed > 2000) {
            _artworkCleanupAttempted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Clear artwork URL from model and save
                artworkUrl = null;
                save();
              }
            });
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
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

## Code Refactoring Required: Artwork Layer Duplication

**Status:** MUST FIX before adding more card types

**Research completed:** See `docs/activeDevelopment/ArtworkImplementationResearch.md` for detailed analysis.

**Problem:** The artwork layer implementation is duplicated across 3 card types (~450 total lines of nearly identical code):
- `lib/widgets/token_card.dart` (lines 565-727) - 163 lines
- `lib/widgets/tracker_widget_card.dart` (lines 588-729) - 142 lines
- `lib/widgets/toggle_widget_card.dart` (lines 196-340) - 145 lines

**Duplicated logic:**
- Animation threshold check (`elapsed > 100`)
- Cleanup logic (`elapsed > 2000`)
- FutureBuilder structure with AnimatedOpacity
- ShaderMask for fadeout gradient
- CroppedArtworkWidget integration
- Two mode implementations (full view vs fadeout)

**Critical Bugs Found:**
1. ❌ **TrackerWidget cleanup incomplete** - Only clears `artworkUrl`, should also clear `artworkSet` and `artworkOptions`
2. ❌ **ToggleWidget cleanup incomplete** - Same issue as TrackerWidget

**Why this matters:**
- Bug fixes must be applied to 3 places (maintenance nightmare)
- **Cleanup bugs exist in 2/3 implementations** (TrackerWidget, ToggleWidget)
- Adding new card types (like Cathar's Crusade) would create 4th duplication
- Inconsistencies can creep in between implementations
- ~300 lines could be eliminated

**Estimated effort:** 3-5 hours (includes bug fixes)
**Risk:** Medium (must test all card types thoroughly after refactor)

### Proposed Solution: Artwork Display Mixin

**Design:** Follow TokenCard pattern (gold standard) with separate helper methods for better code organization.

**Create:** `lib/widgets/mixins/artwork_display_mixin.dart`

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/artwork_manager.dart';
import '../../utils/constants.dart';
import '../cropped_artwork_widget.dart';

/// Mixin providing shared artwork display logic for all card types.
///
/// This follows the TokenCard pattern (gold standard) with separate methods
/// for full view and fadeout modes.
///
/// Card types that display artwork (TokenCard, TrackerWidgetCard, ToggleWidgetCard)
/// should use this mixin to avoid duplicating the artwork layer implementation.
///
/// Required state variables in the widget class:
/// ```dart
/// final DateTime _createdAt = DateTime.now();
/// bool _artworkAnimated = false;
/// bool _artworkCleanupAttempted = false;
/// ```
///
/// Required getters/setters to implement:
/// ```dart
/// DateTime get createdAt => _createdAt;
/// bool get artworkAnimated => _artworkAnimated;
/// set artworkAnimated(bool value) => _artworkAnimated = value;
/// bool get artworkCleanupAttempted => _artworkCleanupAttempted;
/// set artworkCleanupAttempted(bool value) => _artworkCleanupAttempted = value;
/// String? get artworkUrl;  // For TokenCard: widget.item.artworkUrl
///                          // For TrackerWidget: widget.tracker.artworkUrl
///                          // For ToggleWidget: widget.toggle.currentArtworkUrl
///                          //   NOTE: currentArtworkUrl is scaffolded for state-specific
///                          //   artwork but not implemented - always returns artworkUrl
/// void clearArtwork();     // Clear artworkUrl, artworkSet, artworkOptions, save()
/// ```
mixin ArtworkDisplayMixin<T extends StatefulWidget> on State<T> {
  // Subclasses must provide these
  DateTime get createdAt;
  bool get artworkAnimated;
  set artworkAnimated(bool value);
  bool get artworkCleanupAttempted;
  set artworkCleanupAttempted(bool value);
  String? get artworkUrl;
  void clearArtwork();

  /// Main artwork layer builder - delegates to specific mode methods.
  ///
  /// This is the entry point called from the card's build() method.
  Widget buildArtworkLayer({
    required BuildContext context,
    required BoxConstraints constraints,
    required String artworkDisplayStyle,
  }) {
    if (artworkDisplayStyle == 'fadeout') {
      return buildFadeoutArtwork(context, constraints);
    } else {
      return buildFullViewArtwork(context, constraints);
    }
  }

  /// Build full-width artwork background layer (fills entire card).
  Widget buildFullViewArtwork(BuildContext context, BoxConstraints constraints) {
    final crop = ArtworkManager.getCropPercentages(artworkUrl);

    return Positioned.fill(
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            // Determine if artwork should animate
            // If it appears > 100ms after card creation = downloaded (animate)
            // If it appears < 100ms after card creation = cached (no animation)
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            final shouldAnimate = elapsed > 100 && !artworkAnimated;

            if (shouldAnimate) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    artworkAnimated = true;
                  });
                }
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
                  fillWidth: true,
                ),
              ),
            );
          }

          // If artwork file is missing, clear the invalid reference
          // BUT: Only do this if widget has been stable for >2 seconds to avoid cleanup during drag/scroll
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null &&
              !artworkCleanupAttempted) {
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            if (elapsed > 2000) {
              artworkCleanupAttempted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  clearArtwork();
                }
              });
            }
          }

          // Show empty background while loading or if file missing
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Build fadeout artwork layer (right-side 50% with gradient fade).
  Widget buildFadeoutArtwork(BuildContext context, BoxConstraints constraints) {
    final crop = ArtworkManager.getCropPercentages(artworkUrl);
    final cardWidth = constraints.maxWidth;
    final artworkWidth = cardWidth * 0.50;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: artworkWidth,
      child: FutureBuilder<File?>(
        future: ArtworkManager.getCachedArtworkFile(artworkUrl!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            // Same animation logic as full view
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            final shouldAnimate = elapsed > 100 && !artworkAnimated;

            if (shouldAnimate) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    artworkAnimated = true;
                  });
                }
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
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.50],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: CroppedArtworkWidget(
                    imageFile: snapshot.data!,
                    cropLeft: crop['left']!,
                    cropRight: crop['right']!,
                    cropTop: crop['top']!,
                    cropBottom: crop['bottom']!,
                    fillWidth: false,
                  ),
                ),
              ),
            );
          }

          // If artwork file is missing, clear the invalid reference
          // BUT: Only do this if widget has been stable for >2 seconds to avoid cleanup during drag/scroll
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data == null &&
              !artworkCleanupAttempted) {
            final elapsed = DateTime.now().difference(createdAt).inMilliseconds;
            if (elapsed > 2000) {
              artworkCleanupAttempted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  clearArtwork();
                }
              });
            }
          }

          // Show empty background while loading or if file missing
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
```

### Usage Pattern

**Before (in each card class):**
```dart
class _TokenCardState extends State<TokenCard> {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;

  Widget _buildArtworkLayer(...) {
    // 150+ lines of duplicated code
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ...
        if (artworkUrl != null)
          _buildArtworkLayer(context, constraints, artworkDisplayStyle),
        // ...
      ],
    );
  }
}
```

**After (in each card class):**

**TokenCard:**
```dart
class _TokenCardState extends State<TokenCard> with ArtworkDisplayMixin {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;

  @override
  void didUpdateWidget(TokenCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset cleanup flag if artwork URL changed
    if (oldWidget.item.artworkUrl != widget.item.artworkUrl) {
      _artworkCleanupAttempted = false;
    }
  }

  // Implement required getters
  @override
  DateTime get createdAt => _createdAt;

  @override
  String? get artworkUrl => widget.item.artworkUrl;

  @override
  void clearArtwork() {
    widget.item.artworkUrl = null;
    widget.item.artworkSet = null;      // ← CRITICAL: Clear all artwork fields
    widget.item.artworkOptions = null;  // ← CRITICAL: Clear all artwork fields
    widget.item.save();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ...
        if (artworkUrl != null)
          buildArtworkLayer(  // ← Use mixin method
            context: context,
            constraints: constraints,
            artworkDisplayStyle: artworkDisplayStyle,
          ),
        // ...
      ],
    );
  }
}
```

**TrackerWidgetCard (with bug fix):**
```dart
class _TrackerWidgetCardState extends State<TrackerWidgetCard> with ArtworkDisplayMixin {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;

  @override
  void didUpdateWidget(TrackerWidgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracker.artworkUrl != widget.tracker.artworkUrl) {
      _artworkCleanupAttempted = false;
    }
  }

  @override
  DateTime get createdAt => _createdAt;

  @override
  String? get artworkUrl => widget.tracker.artworkUrl;

  @override
  void clearArtwork() {
    widget.tracker.artworkUrl = null;
    widget.tracker.artworkSet = null;      // ← FIX: Was missing!
    widget.tracker.artworkOptions = null;  // ← FIX: Was missing!
    widget.tracker.save();
  }
}
```

**ToggleWidgetCard (with bug fix):**
```dart
class _ToggleWidgetCardState extends State<ToggleWidgetCard> with ArtworkDisplayMixin {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;

  @override
  void didUpdateWidget(ToggleWidgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.toggle.artworkUrl != widget.toggle.artworkUrl) {
      _artworkCleanupAttempted = false;
    }
  }

  @override
  DateTime get createdAt => _createdAt;

  @override
  String? get artworkUrl => widget.toggle.currentArtworkUrl;
  // NOTE: currentArtworkUrl is scaffolded for state-specific artwork (on/off)
  // but not implemented on frontend. Always returns general artworkUrl.
  // See ArtworkImplementationResearch.md section 4 for details.

  @override
  void clearArtwork() {
    widget.toggle.artworkUrl = null;
    widget.toggle.artworkSet = null;      // ← FIX: Was missing!
    widget.toggle.artworkOptions = null;  // ← FIX: Was missing!
    widget.toggle.save();
    // FUTURE: When state-specific artwork is implemented, also clear:
    // widget.toggle.onArtworkUrl = null;
    // widget.toggle.offArtworkUrl = null;
  }
}
```

### Implementation Checklist

**Phase 0: Add Artwork Magic Numbers to UIConstants (15 minutes)**
- [ ] Add to `lib/utils/constants.dart` → `UIConstants`:
  - `artworkAnimationThreshold = 100` (milliseconds - cached vs downloaded distinction)
  - `artworkCleanupDelay = 2000` (milliseconds - prevents cleanup during drag/scroll)
  - `artworkFadeInDuration = Duration(milliseconds: 500)` (animation duration)
  - `artworkFadeoutWidthPercent = 0.50` (50% width for fadeout mode)
  - `artworkFadeoutGradientStops = [0.0, 0.50]` (gradient fade on left edge)
  - `textBackgroundOpacity = 0.85` (semi-transparent backgrounds for readability)
- [ ] These values are empirically determined and deliberate - do not change

**Phase 1: Fix Cleanup Bugs (5 minutes, DO THIS FIRST)**
- [ ] Fix `tracker_widget_card.dart` lines 659-660 - Add artworkSet and artworkOptions to cleanup
- [ ] Fix `tracker_widget_card.dart` lines 717-718 - Add artworkSet and artworkOptions to cleanup
- [ ] Fix `toggle_widget_card.dart` lines 270-271 - Add artworkSet and artworkOptions to cleanup
- [ ] Fix `toggle_widget_card.dart` lines 328-329 - Add artworkSet and artworkOptions to cleanup
- [ ] Test artwork cleanup on all three card types (user tests on physical devices/simulators)

**Phase 2: Extract TextWithBackground Helper (30 minutes)**
- [ ] Create `lib/widgets/common/background_text.dart`
- [ ] Extract shared `_buildTextWithBackground()` logic from all three cards
- [ ] Use `UIConstants.textBackgroundOpacity` instead of hardcoded 0.85
- [ ] Update TokenCard to use shared widget
- [ ] Update TrackerWidgetCard to use shared widget
- [ ] Update ToggleWidgetCard to use shared widget
- [ ] Verify text readability over artwork in both display modes

**Phase 3: Create Artwork Display Mixin (2-3 hours)**
- [ ] Create `lib/widgets/mixins/` directory
- [ ] Create `lib/widgets/mixins/artwork_display_mixin.dart`
- [ ] Implement mixin with `buildArtworkLayer()`, `buildFullViewArtwork()`, and `buildFadeoutArtwork()` methods
- [ ] Use UIConstants for all magic numbers (animation thresholds, durations, percentages)
- [ ] Copy gold standard logic from TokenCard
- [ ] Add comprehensive documentation
- [ ] Note: All future card types will need artwork support - mixin is the standard

**Phase 4: PILOT - Apply Mixin to TokenCard (1 hour)**
- [ ] Update `TokenCard` to use mixin:
  - [ ] Add `with ArtworkDisplayMixin` to state class
  - [ ] Implement required interface (createdAt, artworkUrl, artworkAnimated, etc.)
  - [ ] Implement `clearArtwork()` method
  - [ ] Replace `_buildArtworkLayer()` call with mixin's `buildArtworkLayer()`
  - [ ] Remove old `_buildArtworkLayer()`, `_buildFullViewArtwork()`, `_buildFadeoutArtwork()` methods
- [ ] **STOP AND TEST PILOT:**
  - [ ] Test TokenCard in full view mode (user tests on physical devices/simulators)
  - [ ] Test TokenCard in fadeout mode
  - [ ] Verify artwork animations (fade-in after 100ms for downloaded artwork)
  - [ ] Verify cleanup logic (missing artwork cleared after 2 seconds)
  - [ ] Verify text backgrounds maintain readability
  - [ ] Test with Scryfall artwork
  - [ ] Test with custom uploaded artwork
  - [ ] Verify no visual regressions compared to old implementation
- [ ] **REVIEW PILOT RESULTS** - If issues found, fix mixin before proceeding

**Phase 5: Apply Mixin to Utility Cards (1 hour)**
- [ ] Update `TrackerWidgetCard` to use mixin (same steps as TokenCard)
- [ ] Update `ToggleWidgetCard` to use mixin (same steps as TokenCard, uses `currentArtworkUrl`)
- [ ] **FINAL TESTING:**
  - [ ] Test all three card types in both display modes
  - [ ] Verify artwork animations work correctly across all card types
  - [ ] Verify cleanup logic works across all card types
  - [ ] Verify text backgrounds maintain readability over artwork
  - [ ] Verify no visual regressions
- [ ] Update NextFeature.md artwork pattern section to reference mixin usage
- [ ] Document lessons learned from pilot (if any)

### Testing Checklist

After implementing mixin:
- [ ] TokenCard: Full view mode displays correctly
- [ ] TokenCard: Fadeout mode displays correctly
- [ ] TrackerWidget: Full view mode displays correctly
- [ ] TrackerWidget: Fadeout mode displays correctly
- [ ] ToggleWidget: Full view mode displays correctly
- [ ] ToggleWidget: Fadeout mode displays correctly
- [ ] Artwork animations trigger at 100ms
- [ ] Missing artwork cleans up after 2000ms
- [ ] No performance degradation
- [ ] Switching display modes works instantly

**Lines saved:** ~300 lines of duplicated code eliminated

---

## Next Up: Cathar's Crusade

The next special utility to implement is **Cathar's Crusade**.

**Status:** Planning phase - design and implementation details to be determined.
