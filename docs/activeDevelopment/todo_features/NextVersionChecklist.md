# Next Version Checklist - Code Quality Audit

**Audit Date:** December 20, 2025
**Version Audited:** 1.8.0+16
**Overall Grade:** B+ (Good code quality with room for optimization)

## Executive Summary

The codebase is well-maintained with excellent migration safety (all Hive models properly configured) and good architectural patterns. Primary areas for improvement:
1. **Code duplication** - Artwork layer pattern duplicated across 3 card types (~400 lines)
2. **Magic numbers** - 56 hardcoded values that should be constants
3. **Minor performance optimization** - TokenProvider.items getter rebuilds sorted list frequently

**No critical issues found.** All findings are optimization opportunities.

---

## 1. MAGIC NUMBERS (56 instances)

### High Priority Constants to Add

Add these to `lib/utils/constants.dart` → `UIConstants` class:

```dart
// Opacity values (currently hardcoded 10+ times)
static const double textBackgroundOpacity = 0.85;
static const double typeTextOpacity = 0.7;
static const double zeroAmountOpacity = 0.5;
static const double disabledIconOpacity = 0.3;
static const double inactiveButtonOpacity = 0.15;

// Artwork animation thresholds
static const double artworkAnimationThreshold = 100; // milliseconds
static const double artworkCleanupDelay = 2000; // milliseconds
static const double artworkFadeoutWidthPercent = 0.50;

// Animation parameters
static const double ptScaleAnimationEnd = 1.5;
static const Duration artworkFadeInDuration = Duration(milliseconds: 500);
static const Duration searchDebounceDuration = Duration(milliseconds: 300);
static const Duration focusRequestDelay = Duration(milliseconds: 100);
static const Duration artworkPreloadDelay = Duration(milliseconds: 150);

// Layout thresholds
static const int ptLayoutThreshold = 8; // characters for P/T text
static const double orderCompactionThreshold = 0.001;
static const double orderIncrementValue = 1.0;

// Gradient configuration
static const List<double> fadeoutGradientStops = [0.0, 0.50];

// Standard padding presets
static const EdgeInsets dialogPadding = EdgeInsets.all(16);
static const EdgeInsets sheetPadding = EdgeInsets.all(24);
static const EdgeInsets fabExtendedPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
static const EdgeInsets ptPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
static const EdgeInsets smallPadding = EdgeInsets.all(4);
```

### Files with Magic Numbers

**token_card.dart** (20 instances)
- Line 45: Animation duration 500ms
- Line 51: Scale animation 1.0 → 1.5
- Line 137: Opacity 0.5 for zero-amount
- Line 276: P/T layout threshold (8 chars)
- Line 586: Artwork animation threshold (100ms)
- Line 622/709: Artwork cleanup delay (2000ms)
- Line 646: Fadeout width (50%)
- Line 686: Gradient stops [0.0, 0.50]
- Line 744: Text background opacity (0.85) - appears 10x
- Line 772/832: Type text opacity (0.7)
- Lines 890/896: P/T background opacity (0.85)
- Line 895: P/T padding (8, 4)

**tracker_widget_card.dart** (12 instances)
- Line 148: Toggle icon size 48
- Lines 278/312: Button opacity 0.85
- Line 320: Magic +2 padding adjustment
- Line 495: Hardcoded Scryfall URL (move to config)
- Line 594: Fadeout width 50% (duplicated)

**toggle_widget_card.dart** (8 instances)
- Lines 231/303: Animation duration 500ms
- Lines 145/216: Padding (12, 8)
- Line 350: Background opacity 0.85

**floating_action_menu.dart** (4 instances)
- Line 88: Bottom padding 24
- Line 234: Padding (16, 4)
- Line 241: Inactive opacity 0.15

**multiplier_view.dart** (5 instances)
- Line 25: FAB padding (16, 12)
- Line 87: Focus delay 100ms
- Line 139: Container padding (16, 12)
- Line 159: Disabled opacity 0.3
- Line 165: TextField width 100

**Other files** (7 instances)
- artwork_selection_sheet.dart: Various delays and padding
- counter_pill.dart: Orange counter opacity 0.85
- content_screen.dart: Border width 3.0, animation 100ms

### Recommended Action

1. Create new constants in UIConstants
2. Find/replace hardcoded values across codebase
3. Run tests to ensure no regressions

**Estimated effort:** 2-3 hours
**Risk:** Low (purely cosmetic refactor)

---

## 2. MISSING DEFAULT VALUES

**Status: ✅ EXCELLENT - Zero issues found**

All Hive models properly implement `defaultValue` parameters:
- ✅ `Item` (16 fields)
- ✅ `TokenTemplate` (9 fields)
- ✅ `TrackerWidget` (17 fields)
- ✅ `ToggleWidget` (14 fields)
- ✅ `Deck`, `TokenCounter` (simple models)

**Migration safety:** 100% - No risk of data loss on upgrades.

---

## 3. PERFORMANCE RISKS

### Medium Priority

**TokenProvider.items getter (lib/providers/token_provider.dart:66-69)**
```dart
// Current implementation rebuilds sorted list on every access
List<Item> get items {
  return _itemsBox.values.toList()
    ..sort((a, b) => a.order.compareTo(b.order));
}
```

**Issue:** Called frequently by UI (every ValueListenableBuilder rebuild)
**Impact:** Medium - Creates new list + sort operation on every access
**Fix:** Cache sorted list, invalidate on changes

**Suggested implementation:**
```dart
List<Item>? _cachedSortedItems;

List<Item> get items {
  if (_cachedSortedItems == null) {
    _cachedSortedItems = _itemsBox.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }
  return _cachedSortedItems!;
}

// Invalidate cache in insertItem, updateItem, deleteItem, etc.
void _invalidateCache() {
  _cachedSortedItems = null;
}
```

**Estimated effort:** 30 minutes
**Risk:** Low
**Expected improvement:** Reduced frame time when rendering large token lists

### Low Priority

**ContentScreen._buildBoardItems (content_screen.dart:141-153)**
- Creates wrapper objects in `build()` method
- **Impact:** Low - objects are lightweight
- **Action:** Monitor; optimize only if performance issues arise

**Positive findings:**
- ✅ CroppedArtworkWidget properly caches ui.Image objects
- ✅ Search screens use debouncing (300ms)
- ✅ Proper async operations with mounted checks

---

## 4. CODE DUPLICATION

### High Priority - Artwork Layer Pattern

**Duplicated across 3 files (~400 total lines):**
- `lib/widgets/token_card.dart` (lines 565-727)
- `lib/widgets/tracker_widget_card.dart` (lines 588-729)
- `lib/widgets/toggle_widget_card.dart` (lines 196-340)

**Duplicated logic:**
- Animation threshold check (`elapsed > 100`)
- Cleanup logic (`elapsed > 2000`)
- FutureBuilder structure with AnimatedOpacity
- ShaderMask for fadeout gradient
- CroppedArtworkWidget integration

**Fix:** Extract to shared mixin

**Suggested implementation:**
```dart
// Create: lib/widgets/mixins/artwork_display_mixin.dart

mixin ArtworkDisplayMixin<T extends StatefulWidget> on State<T> {
  // Subclass must provide these
  DateTime get createdAt;
  bool get artworkAnimated;
  set artworkAnimated(bool value);
  bool get artworkCleanupAttempted;
  set artworkCleanupAttempted(bool value);
  String? get artworkUrl;
  void clearArtwork();

  Widget buildArtworkLayer({
    required String? artworkUrl,
    required BuildContext context,
    required bool isFadeoutMode,
    required double cardWidth,
  }) {
    // Move shared implementation here
    final elapsed = DateTime.now().difference(createdAt).inMilliseconds;

    if (elapsed > UIConstants.artworkCleanupDelay && !artworkCleanupAttempted) {
      // Cleanup logic
    }

    if (elapsed < UIConstants.artworkAnimationThreshold) {
      artworkAnimated = false;
    }

    // ... rest of shared implementation
  }
}
```

**Usage in card classes:**
```dart
class _TokenCardState extends State<TokenCard> with ArtworkDisplayMixin {
  // Implement required properties
  @override
  DateTime get createdAt => widget.item.createdAt;

  @override
  String? get artworkUrl => widget.item.artworkUrl;

  // ... etc

  // Use mixin method
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ... other layers
        buildArtworkLayer(
          artworkUrl: widget.item.artworkUrl,
          context: context,
          isFadeoutMode: artworkDisplayStyle == 'fadeout',
          cardWidth: constraints.maxWidth,
        ),
        // ... content layer
      ],
    );
  }
}
```

**Estimated effort:** 3-4 hours
**Risk:** Medium (test all card types thoroughly)
**Benefit:** ~300 lines removed, single source of truth for artwork logic

### Medium Priority - Helper Methods

**Text Background Widget (duplicated 3x):**
- token_card.dart:730
- tracker_widget_card.dart:731
- toggle_widget_card.dart:342

**Fix:** Extract to shared widget

```dart
// Create: lib/widgets/common/background_text.dart

class BackgroundText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color backgroundColor;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;

  const BackgroundText({
    required this.text,
    required this.style,
    required this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
      child: Text(text, style: style),
    );
  }
}
```

**Estimated effort:** 1 hour
**Risk:** Low

---

## 5. DESIGN INCONSISTENCIES

### Medium Priority

**Animation Duration Mismatch:**
- UIConstants.animationDuration = 300ms
- Actual usage in files: 500ms (most common)

**Action:** Either:
1. Update constant to 500ms to match actual usage, OR
2. Update all usages to use existing 300ms constant

**Order Calculation Pattern (repeated 5x with variations):**
- `maxOrder.floor() + 1.0` (most common)
- `order + 1.0` (simpler)
- Fractional: `(prev + next) / 2.0`

**Fix:** Extract to utility class

```dart
// Create: lib/utils/order_utils.dart

class OrderUtils {
  static double nextWholeOrder(Iterable<double> orders) {
    if (orders.isEmpty) return 0.0;
    return orders.reduce(max).floor() + UIConstants.orderIncrementValue;
  }

  static double fractionalOrder(double prev, double next) {
    return (prev + next) / 2.0;
  }

  static bool needsCompaction(double difference) {
    return difference < UIConstants.orderCompactionThreshold;
  }
}
```

**Estimated effort:** 1.5 hours
**Risk:** Low

---

## 6. CLEANUP ITEMS

### Low Priority

**Commented-out code:**
- content_screen.dart:183 - Shadow calculation commented out
- **Action:** Either remove or document why it's disabled

**Hardcoded URLs:**
- tracker_widget_card.dart:495 - Scryfall URL for goblin token
- **Action:** Move to constants or configuration file

**Outdated comments:**
- token_card.dart:523 - Comment about trying different gradients
- **Action:** Remove if decision is final

**Estimated effort:** 30 minutes
**Risk:** None

---

## IMPLEMENTATION PRIORITY

### Sprint 1 (High Impact, Low Risk) - 4-5 hours
1. ✅ Add magic number constants to UIConstants
2. ✅ Cache sorted items list in TokenProvider
3. ✅ Extract text background widget
4. ✅ Clean up commented code and hardcoded URLs

### Sprint 2 (High Impact, Medium Risk) - 4-5 hours
5. ✅ Extract artwork layer mixin
6. ✅ Standardize animation durations
7. ✅ Extract order calculation utilities

### Sprint 3 (Nice to Have) - 2 hours
8. ✅ Review and consolidate padding constants
9. ✅ Audit for additional duplication patterns

---

## TESTING CHECKLIST

After implementing fixes:

- [ ] All card types render correctly (Token, Tracker, Toggle)
- [ ] Artwork display works in both Full View and Fadeout modes
- [ ] Artwork animations trigger properly (fade-in at 100ms)
- [ ] Artwork cleanup happens after 2000ms
- [ ] Performance: Large token lists (50+ items) scroll smoothly
- [ ] Deck save/load preserves order correctly
- [ ] No visual regressions in padding, opacity, or colors
- [ ] Dark mode still looks correct

---

## POSITIVE FINDINGS

✅ **Excellent Hive migration safety** - All models have proper defaultValue
✅ **Good constant usage** - UIConstants class well-structured
✅ **Proper memory management** - Images cached and disposed correctly
✅ **Safe async operations** - Mounted checks prevent crashes
✅ **Smart performance** - Search debouncing, proper ValueListenables
✅ **Good error handling** - Comprehensive error messages in providers

**The codebase demonstrates strong engineering fundamentals. These optimizations will make good code even better.**
