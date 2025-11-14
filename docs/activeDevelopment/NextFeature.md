# Next Feature: Artwork Display Style Toggle

## Overview

Implement a user-selectable setting that allows toggling between two different artwork display styles for tokens:

1. **FULL VIEW** (Method 2 from artFeature.md) - Currently on `artwork` branch
2. **FADEOUT** (Method 1 from artFeature.md) - Currently on `altArtwork` branch

Both implementations share core artwork infrastructure (download, caching, selection) but differ in how artwork is displayed on TokenCard.

## Prerequisites (MUST BE COMPLETED FIRST)

### 1. Branch State Verification
- **Current branch:** `artwork` (verified from git status)
- **Artwork infrastructure status:** IMPLEMENTED on both `artwork` and `altArtwork` branches
  - Artwork selection UI (ExpandedTokenScreen) ✅
  - Download/caching (ArtworkManager) ✅
  - Manual artwork selection (ArtworkSelectionSheet) ✅
  - Display on TokenCard ✅
- **Known issues:** None blocking this feature

### 2. Auto-Assignment Feature
- **Status:** NOT IMPLEMENTED on either branch
- **Action:** Skip auto-assignment for this feature - it will be added later
- **Rationale:** Style toggle can work independently of auto-assignment
- **Note:** Auto-assignment documented in artFeature.md is a FUTURE feature, not required for style toggle

### 3. AnimatedSwitcher Status
- **Status:** NOT verified on either branch
- **Action:** If AnimatedSwitcher not present, add it during implementation
- **Location:** TokenCard `_buildArtworkLayer` should wrap artwork with AnimatedSwitcher
- **Key behavior:** ValueKey should include both artworkUrl AND artworkDisplayStyle to trigger transition on style change

### 4. Starting Point
- **Base branch:** `artwork` (current branch)
- **Strategy:** Create new feature branch, then merge specific code from `altArtwork`
- **New branch name:** `artwork-style-toggle`

---

## Quick Start (TL;DR for Autonomous Agent)

**Goal:** Add user setting to toggle between two artwork display styles (Full View vs Fadeout)

**What to do:**
1. Follow **Step-by-Step Implementation Sequence** section below (11 phases)
2. Each phase has explicit code snippets and verification steps
3. Run automated tests to verify code correctness
4. Commit and push when complete
5. Manual testing (visual verification) will be done by user afterward

**Key files to modify:**
- `lib/providers/settings_provider.dart` - Add setting
- `lib/widgets/token_card.dart` - Add fadeout method, wire up switching
- `lib/widgets/cropped_artwork_widget.dart` - Add fillWidth parameter
- `lib/screens/content_screen.dart` - Add UI for style selection

**Starting branch:** `artwork` → Create new branch `artwork-style-toggle`

**Expected outcome:** User can switch between Full View and Fadeout artwork styles via Settings dialog, setting persists across restarts.

---

## Branch Comparison Summary

### `artwork` branch (FULL VIEW Method)
- **Latest commit:** `72ec0c9 - Token Artwork "FULL VIEW" version.`
- **Display style:** Full-width background artwork with semi-transparent color overlay
- **Implementation:** Full card method as documented in artFeature.md Method 2

### `altArtwork` branch (FADEOUT Method)
- **Latest commit:** `e57c6ae - fade method implemented`
- **Based on:** `artwork` branch + fadeout modifications
- **Display style:** Right-aligned artwork (50% width) with gradient fade
- **Implementation:** Fadeout method as documented in artFeature.md Method 1

---

## Detailed Implementation Comparison

### 1. Artwork Layer Structure (`_buildArtworkLayer`)

#### FULL VIEW (`artwork` branch)
```dart
Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints) {
  final crop = ArtworkManager.getCropPercentages();

  return Positioned.fill(  // � Full-width
    child: FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(item.artworkUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
            child: CroppedArtworkWidget(  // � No shader mask
              imageFile: snapshot.data!,
              cropLeft: crop['left']!,
              cropRight: crop['right']!,
              cropTop: crop['top']!,
              cropBottom: crop['bottom']!,
            ),
          );
        }
        return const SizedBox.shrink();
      },
    ),
  );
}
```

**Key characteristics:**
- `Positioned.fill` - Artwork fills entire card width (100%)
- No gradient/shader mask
- Uniform border radius on all corners
- Relies on overlay layer for opacity fade

#### FADEOUT (`altArtwork` branch)
```dart
Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints) {
  final crop = ArtworkManager.getCropPercentages();
  final cardWidth = constraints.maxWidth;
  final artworkWidth = cardWidth * 0.50;  // � 50% of card width

  return Positioned(  // � Right-side placement
    right: 0,
    top: 0,
    bottom: 0,
    width: artworkWidth,
    child: FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(item.artworkUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
            borderRadius: const BorderRadius.only(  // � Only right corners
              topRight: Radius.circular(UIConstants.smallBorderRadius),
              bottomRight: Radius.circular(UIConstants.smallBorderRadius),
            ),
            child: ShaderMask(  // � Gradient fade
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent, // Fade start (0% opacity)
                    Colors.white,       // Fade end (100% opacity)
                  ],
                  stops: [0.0, 0.50], // Fade over first 50% of artwork width
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: CroppedArtworkWidget(
                imageFile: snapshot.data!,
                cropLeft: crop['left']!,
                cropRight: crop['right']!,
                cropTop: crop['top']!,
                cropBottom: crop['bottom']!,
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    ),
  );
}
```

**Key characteristics:**
- `Positioned` with `right: 0` - Artwork on right side only
- Artwork width: **50% of card width**
- `ShaderMask` with `LinearGradient` - Creates fade from transparent to opaque
- Gradient stops: `[0.0, 0.50]` - Fades over first 50% of artwork width (25% of total card width)
- Border radius only on right corners
- No separate overlay layer needed

---

### 2. Stack Layer Order

#### FULL VIEW (`artwork` branch)
```dart
Stack(
  children: [
    // Artwork layer (background, if artwork selected)
    if (item.artworkUrl != null)
      _buildArtworkLayer(context, constraints),

    // Content layer (all existing UI elements)
    Container(...),
  ],
)
```

**Layer order:**
1. Artwork (full-width background)
2. Content (UI elements with background boxes)

**Note:** Has `_buildOverlayLayer` method defined but NOT used in Stack

#### FADEOUT (`altArtwork` branch)
```dart
Stack(
  children: [
    // Base card background layer
    Container(
      color: Theme.of(context).cardColor,
    ),

    // Artwork layer (background, if artwork selected)
    if (item.artworkUrl != null)
      _buildArtworkLayer(context, constraints),

    // Content layer (all existing UI elements)
    Container(...),
  ],
)
```

**Layer order:**
1. Base card background (solid color)
2. Artwork (right-side, 50% width)
3. Content (UI elements with background boxes)

**Note:** No `_buildOverlayLayer` method at all

---

### 3. Text Background Boxes (`_buildTextWithBackground`)

#### FULL VIEW (`artwork` branch)
```dart
Widget _buildTextWithBackground({
  required BuildContext context,
  required Widget child,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
}) {
  if (item.artworkUrl == null) {
    return child;
  }

  final backgroundColor = Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surface
      : Theme.of(context).colorScheme.surfaceContainerHighest;

  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor.withValues(alpha: 0.85),  // � Semi-transparent
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
}
```

**Background color:**
- Dark mode: `surface` with 0.85 alpha (semi-transparent)
- Light mode: `surfaceContainerHighest` with 0.85 alpha (semi-transparent)

#### FADEOUT (`altArtwork` branch)
```dart
Widget _buildTextWithBackground({
  required BuildContext context,
  required Widget child,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
}) {
  if (item.artworkUrl == null) {
    return child;
  }

  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,  // � Solid color
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
}
```

**Background color:**
- Uses `cardColor` (solid, no alpha transparency)
- No theme-specific logic needed

---

### 4. Action Button Backgrounds (`_buildActionButton`)

#### FULL VIEW (`artwork` branch)
```dart
final buttonBackgroundColor = item.artworkUrl != null
    ? (Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.85)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85))
    : effectiveColor.withValues(alpha: 0.15);
```

**Background color:**
- With artwork: `surface` (dark) or `surfaceContainerHighest` (light) with 0.85 alpha
- Without artwork: `effectiveColor` with 0.15 alpha (original transparent style)

#### FADEOUT (`altArtwork` branch)
```dart
final buttonBackgroundColor = item.artworkUrl != null
    ? Theme.of(context).cardColor
    : effectiveColor.withValues(alpha: 0.15);
```

**Background color:**
- With artwork: `cardColor` (solid)
- Without artwork: `effectiveColor` with 0.15 alpha (original transparent style)

---

### 5. Cropped Artwork Widget Scaling (`cropped_artwork_widget.dart`)

#### FULL VIEW (`artwork` branch)
```dart
// Use BoxFit.cover behavior: fill width, maintain aspect ratio, overflow/crop height
final scaleToFillWidth = size.width / croppedWidth;
final scaledHeight = croppedHeight * scaleToFillWidth;

// Center vertically and allow overflow
final dstTop = (size.height - scaledHeight) / 2;
final dstRect = Rect.fromLTWH(0, dstTop, size.width, scaledHeight);
```

**Scaling priority:**
- Fill **WIDTH** first
- Crop **HEIGHT** (vertically) if needed
- Center vertically

#### FADEOUT (`altArtwork` branch)
```dart
// Use BoxFit.cover behavior: fill height, maintain aspect ratio, overflow/crop width
final scaleToFillHeight = size.height / croppedHeight;
final scaledWidth = croppedWidth * scaleToFillHeight;

// Center horizontally and allow overflow
final dstLeft = (size.width - scaledWidth) / 2;
final dstRect = Rect.fromLTWH(dstLeft, 0, scaledWidth, size.height);
```

**Scaling priority:**
- Fill **HEIGHT** first
- Crop **WIDTH** (horizontally) if needed
- Center horizontally

---

### 6. Unused Code Differences

#### FULL VIEW (`artwork` branch)
- Has `_buildOverlayLayer()` method **defined but NOT used in Stack**
- Method creates a semi-transparent overlay layer with 0.5 alpha
- Appears to be leftover from development/testing

#### FADEOUT (`altArtwork` branch)
- No `_buildOverlayLayer()` method (removed entirely)
- Cleaner implementation without unused code

---

## Common Elements (Shared Between Both)

### Artwork Infrastructure
 Both use same artwork download/caching system (`ArtworkManager`)
 Both use same crop percentages (8.8% left/right, 14.5% top, 36.8% bottom)
 Both use `CroppedArtworkWidget` for rendering
 Both check `item.artworkUrl != null` before displaying artwork
 Both use `FutureBuilder` for async image loading
 Both show background boxes on text elements (when artwork present)
 Both use same padding for background boxes: `EdgeInsets.symmetric(horizontal: 6, vertical: 2)`
 Both use `BorderRadius.circular(4)` for text background boxes
 Both apply background boxes only when artwork exists

### UI Elements
 Same token card layout structure (name, type, abilities, counters, buttons)
 Same action button layout and spacing logic
 Same emblem handling (centered text, no tap/untap)
 Same counter pill display
 Same gesture handling (tap to expand, long-press for bulk actions)

### Data Models
 Both use `Item.artworkUrl` to store artwork URL
 Both use `Item.artworkSet` to store set code
 Both preserve artwork in deck save/load via `TokenTemplate`

---

## Discrepancies Requiring User Decisions

### 1. Background Color Choices

**Issue:** The two implementations use different background colors for text boxes and buttons.

**FULL VIEW approach:**
- Text backgrounds: `surface` / `surfaceContainerHighest` with 0.85 alpha
- Button backgrounds: `surface` / `surfaceContainerHighest` with 0.85 alpha
- Rationale: Semi-transparency allows some artwork to show through

**FADEOUT approach:**
- Text backgrounds: `cardColor` (solid)
- Button backgrounds: `cardColor` (solid)
- Rationale: Simpler, more readable, no transparency needed

**Decision needed:**
- **Option A:** Use FULL VIEW colors (semi-transparent surface colors) for both styles
- **Option B:** Use FADEOUT colors (solid cardColor) for both styles
- **Option C:** Keep different colors per style (FULL VIEW = semi-transparent, FADEOUT = solid)
- **Option D:** Make background color/opacity a separate user preference

**✅ USER DECISION:** Option A (semi-transparent backgrounds with 0.85 alpha for both styles)
- Text backgrounds: `surface` / `surfaceContainerHighest` with 0.85 alpha
- Button backgrounds: `surface` / `surfaceContainerHighest` with 0.85 alpha
- Consistent across both styles

---

### 2. Artwork Width Percentage (FADEOUT only)

**Current value:** 50% of card width

**Original spec (artFeature.md Method 1):** 30% of card width

**Issue:** The implemented fadeout uses 50% width instead of the documented 30%.

**✅ USER DECISION:** Keep at 50% (current implementation is the standard)
- Actual implementation takes precedence over original planning documents
- artFeature.md will be updated to reflect 50% as the specification

---

### 3. Gradient Fade Distance (FADEOUT only)

**Current value:** Fades over first 50% of artwork width (i.e., 25% of total card width)

**Original spec (artFeature.md Method 1):** Fades over first 25% of artwork width (i.e., 7.5% of total card width with 30% artwork)

**Issue:** Gradient fade zone is larger than originally specified.

**✅ USER DECISION:** Keep at 50% fade distance (current implementation is the standard)
- Actual implementation takes precedence over original planning documents
- artFeature.md will be updated to reflect 50% fade as the specification

---

### 4. Overlay Layer Usage (FULL VIEW only)

**Current state:** `_buildOverlayLayer()` method exists but is NOT used in Stack.

**Issue:** Code is defined but inactive. Suggests incomplete implementation or testing artifact.

**What the unused overlay does:**
- Creates semi-transparent background color overlay at 0.5 alpha
- Would sit on top of artwork, below content
- Purpose: Fade out artwork to improve text readability

**✅ USER DECISION:** Keep the overlay code but leave it unused
- Preserve `_buildOverlayLayer()` method for potential future use
- Document in code comments that it's available for masking background with opacity if needed
- Currently unused because text background boxes provide sufficient contrast
- Can be enabled later if we want to globally dim artwork across entire card

---

### 5. Base Card Background Layer

**FADEOUT has:** Explicit base card background layer in Stack
```dart
Container(color: Theme.of(context).cardColor)
```

**FULL VIEW has:** No explicit base layer (relies on parent widget background)

**Issue:** FADEOUT explicitly sets card background to ensure left 50% is solid color.

**Decision needed:**
- Add base background layer to FULL VIEW for consistency?
- Keep FULL VIEW without base layer (relies on parent)?

**Recommendation:** Add base background layer to both for consistency and predictability.

---

### 6. Font/Text Style Differences

**Current state:** Both implementations use identical text styles (from Theme)

**No differences found** 

---

### 7. Color/Opacity Variations

| Element | FULL VIEW | FADEOUT |
|---------|-----------|---------|
| Text background color | `surface` / `surfaceContainerHighest` | `cardColor` |
| Text background opacity | 0.85 alpha | 1.0 (solid) |
| Button background color | `surface` / `surfaceContainerHighest` | `cardColor` |
| Button background opacity | 0.85 alpha | 1.0 (solid) |
| Artwork overlay | None (method defined but unused) | None |

---

## Step-by-Step Implementation Sequence

**IMPORTANT:** Follow these steps in exact order. Each step must be completed before proceeding to the next.

### Phase 1: Create Feature Branch
```bash
# Ensure you're on artwork branch
git checkout artwork

# Create new feature branch
git checkout -b artwork-style-toggle

# Verify branch created
git branch --show-current
# Expected output: artwork-style-toggle
```

### Phase 2: Add Setting to SettingsProvider

**File:** `lib/providers/settings_provider.dart`

**Action:** Add new setting after `summoningSicknessEnabled` (around line 45)

**Code to add:**
```dart
// Artwork display style: 'fullView' or 'fadeout'
String get artworkDisplayStyle => _prefs.getString('artworkDisplayStyle') ?? 'fadeout';

Future<void> setArtworkDisplayStyle(String style) async {
  await _prefs.setString('artworkDisplayStyle', style);
  notifyListeners();
}
```

**Verification:** Run `flutter analyze` - should have no errors

### Phase 3: Copy Fadeout Implementation from altArtwork Branch

**Step 3a: Extract fadeout code**

Check out the altArtwork branch version of token_card.dart to a temporary file:
```bash
git show altArtwork:lib/widgets/token_card.dart > /tmp/token_card_fadeout.dart
```

**Step 3b: Identify fadeout implementation**

From `/tmp/token_card_fadeout.dart`, extract the `_buildArtworkLayer` method (lines 67-112 based on comparison section).

**Step 3c: Add fadeout as separate method**

In `lib/widgets/token_card.dart`, add NEW method `_buildFadeoutArtwork`:

```dart
Widget _buildFadeoutArtwork(BuildContext context, BoxConstraints constraints) {
  final crop = ArtworkManager.getCropPercentages();
  final cardWidth = constraints.maxWidth;
  final artworkWidth = cardWidth * 0.50;

  return Positioned(
    right: 0,
    top: 0,
    bottom: 0,
    width: artworkWidth,
    child: FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(item.artworkUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
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
          );
        }
        return const SizedBox.shrink();
      },
    ),
  );
}
```

**Step 3d: Rename existing method**

Rename current `_buildArtworkLayer` to `_buildFullViewArtwork`:

```dart
Widget _buildFullViewArtwork(BuildContext context, BoxConstraints constraints) {
  // ... existing implementation stays the same
  // Just rename the method
}
```

### Phase 4: Update CroppedArtworkWidget

**File:** `lib/widgets/cropped_artwork_widget.dart`

**Action:** Add `fillWidth` parameter to control scaling behavior

**Step 4a: Update constructor**
```dart
class CroppedArtworkWidget extends StatelessWidget {
  final File imageFile;
  final double cropLeft;
  final double cropRight;
  final double cropTop;
  final double cropBottom;
  final bool fillWidth;  // NEW PARAMETER

  const CroppedArtworkWidget({
    super.key,
    required this.imageFile,
    required this.cropLeft,
    required this.cropRight,
    required this.cropTop,
    required this.cropBottom,
    this.fillWidth = true,  // DEFAULT: full-width behavior
  });
}
```

**Step 4b: Update painter logic**

In `_CroppedArtworkPainter.paint()`, replace scaling logic with:

```dart
if (widget.fillWidth) {
  // FULL VIEW: Fill width, crop height
  final scaleToFillWidth = size.width / croppedWidth;
  final scaledHeight = croppedHeight * scaleToFillWidth;
  final dstTop = (size.height - scaledHeight) / 2;
  dstRect = Rect.fromLTWH(0, dstTop, size.width, scaledHeight);
} else {
  // FADEOUT: Fill height, crop width
  final scaleToFillHeight = size.height / croppedHeight;
  final scaledWidth = croppedWidth * scaleToFillHeight;
  final dstLeft = (size.width - scaledWidth) / 2;
  dstRect = Rect.fromLTWH(dstLeft, 0, scaledWidth, size.height);
}
```

**Verification:** Run `flutter analyze` - should have no errors

### Phase 5: Wire Up Style Switching in TokenCard

**File:** `lib/widgets/token_card.dart`

**Step 5a: Create new `_buildArtworkLayer` that switches based on setting**

Replace the call site of artwork layer with:

```dart
Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints) {
  final artworkStyle = context.read<SettingsProvider>().artworkDisplayStyle;

  if (artworkStyle == 'fadeout') {
    return _buildFadeoutArtwork(context, constraints);
  } else {
    return _buildFullViewArtwork(context, constraints);
  }
}
```

**Step 5b: Update Stack to include base background layer**

In TokenCard's `build()` method, ensure Stack starts with base background:

```dart
Stack(
  children: [
    // Base card background layer (ensures left side is solid in fadeout mode)
    Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
      ),
    ),

    // Artwork layer (if artwork selected)
    if (item.artworkUrl != null)
      _buildArtworkLayer(context, constraints),

    // Content layer (existing UI elements)
    // ... rest of existing Stack children
  ],
)
```

**Step 5c: Update AnimatedSwitcher key (if AnimatedSwitcher exists)**

If TokenCard uses AnimatedSwitcher for artwork transitions, update ValueKey to include style:

```dart
AnimatedSwitcher(
  duration: Duration(milliseconds: 500),
  child: _buildArtworkLayer(
    key: ValueKey('${item.artworkUrl ?? 'no-art'}-${context.read<SettingsProvider>().artworkDisplayStyle}'),
    context,
    constraints,
  ),
)
```

**If AnimatedSwitcher does NOT exist:** Wrap `_buildArtworkLayer` with AnimatedSwitcher as shown above.

**Verification:**
- Run `flutter analyze` - no errors
- Build app: `flutter build ios --debug` (or android) - should compile

### Phase 6: Unify Background Colors

**File:** `lib/widgets/token_card.dart`

**Action:** Ensure both styles use semi-transparent backgrounds (0.85 alpha)

**Step 6a: Update `_buildTextWithBackground`**

```dart
Widget _buildTextWithBackground({
  required BuildContext context,
  required Widget child,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
}) {
  if (item.artworkUrl == null) {
    return child;
  }

  final backgroundColor = Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surface
      : Theme.of(context).colorScheme.surfaceContainerHighest;

  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
}
```

**Step 6b: Update `_buildActionButton` background**

Find the button background color assignment and update:

```dart
final buttonBackgroundColor = item.artworkUrl != null
    ? (Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.85)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85))
    : effectiveColor.withValues(alpha: 0.15);
```

**Verification:** Run `flutter analyze` - no errors

### Phase 7: Add Settings UI

**File:** `lib/screens/content_screen.dart`

**Location:** Modify `_showSummoningSicknessToggle()` method (line ~388)

**Action:** Replace entire method with:

```dart
void _showSummoningSicknessToggle() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Settings'),
      content: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Existing summoning sickness toggle
              SwitchListTile(
                title: const Text('Track summoning sickness'),
                subtitle: const Text('Automatically track summoning sickness on newly created tokens'),
                value: settings.summoningSicknessEnabled,
                onChanged: (value) {
                  settings.setSummoningSicknessEnabled(value);
                },
                contentPadding: EdgeInsets.zero,
              ),

              const Divider(),

              // NEW: Artwork style selection
              ListTile(
                title: const Text('Artwork Display Style'),
                subtitle: Text(
                  settings.artworkDisplayStyle == 'fullView'
                    ? 'Full View - Artwork fills card width'
                    : 'Fadeout - Artwork on right with gradient',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'fullView',
                    label: Text('Full View'),
                    icon: Icon(Icons.crop_landscape),
                  ),
                  ButtonSegment(
                    value: 'fadeout',
                    label: Text('Fadeout'),
                    icon: Icon(Icons.gradient),
                  ),
                ],
                selected: {settings.artworkDisplayStyle},
                onSelectionChanged: (Set<String> newSelection) {
                  settings.setArtworkDisplayStyle(newSelection.first);
                },
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
```

**Verification:** Run `flutter analyze` - no errors

### Phase 8: Document Unused Code

**File:** `lib/widgets/token_card.dart`

**Action:** If `_buildOverlayLayer()` method exists, add documentation comment:

```dart
/// Build semi-transparent overlay layer
///
/// NOTE: This method is currently UNUSED but preserved for potential future use.
/// It provides a way to dim the entire artwork with a semi-transparent overlay
/// if text contrast becomes insufficient. Currently, text background boxes
/// provide adequate readability without needing this global dimming effect.
///
/// To enable: Add to Stack between artwork layer and content layer:
/// ```dart
/// if (item.artworkUrl != null && artworkStyle == 'fullView')
///   _buildOverlayLayer(context),
/// ```
Widget _buildOverlayLayer(BuildContext context) {
  // ... existing implementation
}
```

**If method doesn't exist:** Skip this step.

### Phase 9: Clean Build and Test

```bash
# Clean build cache
flutter clean

# Get dependencies
flutter pub get

# Run code analysis
flutter analyze

# Build for iOS
flutter build ios --debug

# Or build for Android
flutter build apk --debug

# Run app on device
flutter run
```

**Expected Results:**
- No compilation errors
- No analyzer warnings in modified files
- App launches successfully
- Settings dialog shows artwork style toggle
- Switching styles updates all visible tokens
- Setting persists after app restart

### Phase 10: Manual Testing Checklist

Test each scenario:

1. **Setting Persistence**
   - [ ] Change style to Full View, close app, reopen - setting should be Full View
   - [ ] Change style to Fadeout, close app, reopen - setting should be Fadeout

2. **Visual Verification**
   - [ ] Create token with artwork in Full View mode - artwork fills card width
   - [ ] Switch to Fadeout mode - artwork appears on right 50% with gradient
   - [ ] Switch back to Full View - artwork returns to full width
   - [ ] Tokens without artwork look identical in both modes

3. **Multiple Tokens**
   - [ ] Create 5 tokens with different artwork
   - [ ] Switch styles - all tokens update simultaneously
   - [ ] No visual glitches or rendering errors

4. **Light/Dark Mode**
   - [ ] Test both styles in light mode
   - [ ] Test both styles in dark mode
   - [ ] Text backgrounds readable in all combinations

5. **Edge Cases**
   - [ ] Open ExpandedTokenScreen, change style in background - no crashes
   - [ ] Change style while scrolling token list - smooth updates
   - [ ] Rapidly toggle between styles - no crashes or memory issues

### Phase 11: Commit and Push

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "Add artwork display style toggle

- Add artworkDisplayStyle setting to SettingsProvider (fadeout/fullView)
- Implement two artwork display methods in TokenCard:
  - Full View: artwork fills card width
  - Fadeout: artwork on right 50% with gradient fade
- Add fillWidth parameter to CroppedArtworkWidget for scaling control
- Update Settings UI with SegmentedButton for style selection
- Unify text/button backgrounds to semi-transparent (0.85 alpha)
- Add base background layer to Stack for consistent rendering
- Document unused overlay layer method

Default style: fadeout (right-side with gradient)"

# Push to remote
git push origin artwork-style-toggle
```

---

## Implementation Strategy for Toggle Feature (DEPRECATED - Use Step-by-Step Sequence Above)

### 1. Add Setting to SettingsProvider

**File:** `lib/providers/settings_provider.dart`

Add new setting:
```dart
// Artwork display style: 'fullView' or 'fadeout'
String get artworkDisplayStyle => _prefs.getString('artworkDisplayStyle') ?? 'fadeout';

Future<void> setArtworkDisplayStyle(String style) async {
  await _prefs.setString('artworkDisplayStyle', style);
  notifyListeners();
}
```

**Default value:** `'fadeout'` ✅

**Valid values:**
- `'fullView'` - Full-width artwork with background boxes
- `'fadeout'` - Right-side artwork with gradient fade (DEFAULT)

---

### 2. Update TokenCard to Use Setting

**File:** `lib/widgets/token_card.dart`

Modify `_buildArtworkLayer` to switch based on setting:

```dart
Widget _buildArtworkLayer(BuildContext context, BoxConstraints constraints) {
  final artworkStyle = context.read<SettingsProvider>().artworkDisplayStyle;
  final crop = ArtworkManager.getCropPercentages();

  if (artworkStyle == 'fadeout') {
    return _buildFadeoutArtwork(context, constraints, crop);
  } else {
    return _buildFullViewArtwork(context, constraints, crop);
  }
}

Widget _buildFullViewArtwork(
  BuildContext context,
  BoxConstraints constraints,
  Map<String, double> crop,
) {
  return Positioned.fill(
    child: FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(item.artworkUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
            child: CroppedArtworkWidget(
              imageFile: snapshot.data!,
              cropLeft: crop['left']!,
              cropRight: crop['right']!,
              cropTop: crop['top']!,
              cropBottom: crop['bottom']!,
              fillWidth: true,  // � New parameter
            ),
          );
        }
        return const SizedBox.shrink();
      },
    ),
  );
}

Widget _buildFadeoutArtwork(
  BuildContext context,
  BoxConstraints constraints,
  Map<String, double> crop,
) {
  final cardWidth = constraints.maxWidth;
  final artworkWidth = cardWidth * 0.50;

  return Positioned(
    right: 0,
    top: 0,
    bottom: 0,
    width: artworkWidth,
    child: FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(item.artworkUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
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
                fillWidth: false,  // � New parameter
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    ),
  );
}
```

---

### 3. Update CroppedArtworkWidget

**File:** `lib/widgets/cropped_artwork_widget.dart`

Add `fillWidth` parameter to control scaling behavior:

```dart
class CroppedArtworkWidget extends StatelessWidget {
  final File imageFile;
  final double cropLeft;
  final double cropRight;
  final double cropTop;
  final double cropBottom;
  final bool fillWidth;  // � New parameter

  const CroppedArtworkWidget({
    super.key,
    required this.imageFile,
    required this.cropLeft,
    required this.cropRight,
    required this.cropTop,
    required this.cropBottom,
    this.fillWidth = true,  // � Default to full-width behavior
  });

  // ... rest of widget
}
```

Update `_CroppedArtworkPainter`:

```dart
if (widget.fillWidth) {
  // FULL VIEW: Fill width, crop height
  final scaleToFillWidth = size.width / croppedWidth;
  final scaledHeight = croppedHeight * scaleToFillWidth;
  final dstTop = (size.height - scaledHeight) / 2;
  final dstRect = Rect.fromLTWH(0, dstTop, size.width, scaledHeight);
} else {
  // FADEOUT: Fill height, crop width
  final scaleToFillHeight = size.height / croppedHeight;
  final scaledWidth = croppedWidth * scaleToFillHeight;
  final dstLeft = (size.width - scaledWidth) / 2;
  final dstRect = Rect.fromLTWH(dstLeft, 0, scaledWidth, size.height);
}
```

---

### 4. Unified Background Color Strategy

**✅ USER DECISION:** Use semi-transparent backgrounds (0.85 alpha) for both styles

Update `_buildTextWithBackground`:
```dart
Widget _buildTextWithBackground({
  required BuildContext context,
  required Widget child,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
}) {
  if (item.artworkUrl == null) {
    return child;
  }

  final backgroundColor = Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surface
      : Theme.of(context).colorScheme.surfaceContainerHighest;

  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor.withValues(alpha: 0.85),  // Semi-transparent (0.85 alpha)
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
}
```

Update `_buildActionButton`:
```dart
final buttonBackgroundColor = item.artworkUrl != null
    ? (Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.85)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85))
    : effectiveColor.withValues(alpha: 0.15);
```

---

### 5. Add Base Background Layer

Add to both styles for consistency:

```dart
Stack(
  children: [
    // Base card background layer (BOTH styles)
    Container(
      color: Theme.of(context).cardColor,
    ),

    // Artwork layer (style-dependent)
    if (item.artworkUrl != null)
      _buildArtworkLayer(context, constraints),

    // Content layer
    Container(...),
  ],
)
```

---

### 6. Preserve Unused Overlay Code (FULL VIEW only)

**Keep** `_buildOverlayLayer()` method in FULL VIEW implementation.

Add documentation comment:
```dart
/// Build semi-transparent overlay layer
///
/// NOTE: This method is currently UNUSED but preserved for potential future use.
/// It provides a way to dim the entire artwork with a semi-transparent overlay
/// if text contrast becomes insufficient. Currently, text background boxes
/// provide adequate readability without needing this global dimming effect.
///
/// To enable: Add to Stack between artwork layer and content layer.
Widget _buildOverlayLayer(BuildContext context) {
  final backgroundColor = Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surface
      : Theme.of(context).colorScheme.surfaceContainerHighest;

  return Positioned.fill(
    child: Container(
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.5), // 0.5 alpha overlay
        borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
      ),
    ),
  );
}
```

---

### 7. Add Settings UI

**File:** `lib/screens/content_screen.dart` or create dedicated settings screen

Add artwork style selector:

```dart
// In settings dialog/sheet
ListTile(
  title: const Text('Artwork Display Style'),
  subtitle: Text(
    artworkStyle == 'fullView' ? 'Full View' : 'Fadeout',
  ),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Artwork Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Full View'),
              subtitle: const Text('Full-width background artwork'),
              value: 'fullView',
              groupValue: artworkStyle,
              onChanged: (value) {
                if (value != null) {
                  settings.setArtworkDisplayStyle(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Fadeout'),
              subtitle: const Text('Right-side artwork with fade'),
              value: 'fadeout',
              groupValue: artworkStyle,
              onChanged: (value) {
                if (value != null) {
                  settings.setArtworkDisplayStyle(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  },
)
```

**Alternative:** Use SegmentedButton or ToggleButtons for simpler UI.

---

## Automated Testing Checklist (Code-Level Verification)

**These tests can be performed by an autonomous agent:**

- [ ] **Code Analysis:** Run `flutter analyze` - zero errors in modified files
- [ ] **Build Verification:** `flutter build ios --debug` completes without errors
- [ ] **Setting Getter:** `SettingsProvider.artworkDisplayStyle` returns 'fadeout' by default
- [ ] **Setting Setter:** `setArtworkDisplayStyle('fullView')` changes value (verify with getter)
- [ ] **Method Exists:** `TokenCard._buildFadeoutArtwork` method defined
- [ ] **Method Exists:** `TokenCard._buildFullViewArtwork` method defined
- [ ] **Method Exists:** `TokenCard._buildArtworkLayer` switches based on setting
- [ ] **Parameter Added:** `CroppedArtworkWidget.fillWidth` parameter exists with default `true`
- [ ] **Settings UI:** `SegmentedButton<String>` exists in ContentScreen settings dialog
- [ ] **Stack Order:** Base Container appears first in Stack children (before artwork layer)
- [ ] **Import Check:** `SettingsProvider` imported in token_card.dart
- [ ] **Documentation:** `_buildOverlayLayer` has doc comment explaining it's unused (if method exists)

## Manual Testing Checklist (Requires Human Verification)

**These tests require human eyes - noted for user to verify:**

- [ ] **Visual:** Full View displays artwork at 100% width
- [ ] **Visual:** Fadeout displays artwork at 50% width on right side
- [ ] **Visual:** Fadeout gradient fade looks smooth (no hard edges)
- [ ] **Visual:** Text backgrounds readable over artwork
- [ ] **Visual:** Button backgrounds readable over artwork
- [ ] **Visual:** No glitches when switching styles
- [ ] **Visual:** Both styles work in light mode
- [ ] **Visual:** Both styles work in dark mode
- [ ] **Functional:** Setting persists after app restart
- [ ] **Functional:** Switching styles updates all visible tokens immediately
- [ ] **Performance:** No lag when rendering 10+ tokens with artwork

---

## ✅ User Decisions (RESOLVED)

### 1. Background Colors
**Decision:** Semi-transparent `surface`/`surfaceContainerHighest` with 0.85 alpha for both styles

### 2. Artwork Width (FADEOUT)
**Decision:** Keep at **50%** (current implementation is the standard, not the 30% from planning docs)

### 3. Fade Distance (FADEOUT)
**Decision:** Keep at **50%** of artwork width (current implementation is the standard)

### 4. Overlay Layer (FULL VIEW)
**Decision:** Keep `_buildOverlayLayer()` code but leave it unused (preserved for potential future use)

### 5. Default Style
**Decision:** **Fadeout** (default value in settings)

## ✅ All Questions Resolved

All implementation details have been specified in the Step-by-Step Implementation Sequence section above. No open questions remain.

---

## File Modification Summary

**Files requiring changes:**
1. `lib/providers/settings_provider.dart` - Add `artworkDisplayStyle` setting
2. `lib/widgets/token_card.dart` - Split `_buildArtworkLayer` into two methods, update backgrounds
3. `lib/widgets/cropped_artwork_widget.dart` - Add `fillWidth` parameter
4. `lib/screens/content_screen.dart` (or settings screen) - Add style selector UI
5. `lib/utils/constants.dart` - Add artwork style constants (optional)

**Files NOT requiring changes:**
- `lib/utils/artwork_manager.dart` - Shared infrastructure 
- `lib/screens/expanded_token_screen.dart` - Artwork selection works for both 
- `lib/widgets/artwork_selection_sheet.dart` - Shared UI 
- All data models (`Item`, `TokenTemplate`, `TokenDefinition`) 

---

## Estimated Implementation Effort (For Autonomous Agent)

**Complexity:** Low-Medium - Most infrastructure exists, mainly refactoring and wiring.

**Automated Steps (Agent can complete):**
1. Create feature branch (Phase 1) - 1 minute
2. Add setting to SettingsProvider (Phase 2) - 5 minutes
3. Copy fadeout implementation from altArtwork (Phase 3) - 10 minutes
4. Update CroppedArtworkWidget (Phase 4) - 10 minutes
5. Wire up style switching (Phase 5) - 15 minutes
6. Unify background colors (Phase 6) - 10 minutes
7. Add Settings UI (Phase 7) - 15 minutes
8. Document unused code (Phase 8) - 5 minutes
9. Clean build and analyze (Phase 9) - 5 minutes
10. Run automated tests (Phase 9) - 5 minutes
11. Commit and push (Phase 11) - 2 minutes

**Total Agent Time:** ~80 minutes (1.3 hours)

**Manual Verification (User must complete):**
- Phase 10: Manual testing checklist - 30-60 minutes
- Visual verification of both styles
- Performance testing with multiple tokens

**Total End-to-End Time:** 2-3 hours (including manual testing)

---

## Success Criteria

 User can toggle between Full View and Fadeout styles
 Setting persists across app restarts
 Both styles use identical text/button backgrounds (consistency)
 Both styles use same artwork infrastructure (download, cache, selection)
 No unused code remains
 Visual appearance matches specifications for each style
 Performance is acceptable
 Works in light and dark mode
 Code is maintainable and well-documented
