# Next Version Checklist - Code Quality Audit

**Original Audit Date:** December 20, 2025
**Last Verified:** February 2026
**Version Audited:** 1.8.0+16
**Overall Grade:** A- (improved from B+ — most high-priority items completed)

## Executive Summary

The original Dec 2025 audit identified code duplication, magic numbers, and minor performance issues. Since then, significant progress has been made:

**Completed:**
- Artwork display mixin extracted (~300 lines saved)
- BackgroundText widget extracted
- Artwork cleanup bugs fixed (TrackerWidget + ToggleWidget)
- Key constants added to UIConstants
- All cleanup items resolved (commented code, hardcoded URLs, outdated comments)

**Still Pending:**
- TokenProvider.items getter caching (medium priority)
- Order calculation utility extraction (low priority)
- Remaining magic numbers not yet centralized (~20 values)

---

## 1. MAGIC NUMBERS

### Completed — Added to UIConstants (constants.dart:78-95)

These constants now exist and should be used across the codebase:

```dart
// Opacity (lines 78-84)
static const double disabledOpacity = 0.3;
static const double actionButtonBackgroundOpacity = 0.15;
static const double shadowOpacity = 0.35;
static const double lightShadowOpacity = 0.15;
static const double dragShadowOpacity = 0.3;
static const double darkModeGlowOpacity = 0.40;

// Artwork display (lines 91-95)
static const int artworkAnimationThreshold = 100;
static const int artworkCleanupDelay = 2000;
static const Duration artworkFadeInDuration = Duration(milliseconds: 500);
static const double artworkFadeoutWidthPercent = 0.50;
static const double textBackgroundOpacity = 0.85;

// Animation (lines 87-88)
static const Duration animationDuration = Duration(milliseconds: 300);
static const Duration sheetDismissDelay = Duration(milliseconds: 100);
```

### Still Missing — Should be added to UIConstants

```dart
// Opacity values still hardcoded
static const double typeTextOpacity = 0.7;        // token_card.dart (type line text)
static const double zeroAmountOpacity = 0.5;       // token_card.dart (empty stack dimming)

// Animation values still hardcoded
static const double ptScaleAnimationEnd = 1.5;     // token_card.dart (P/T bounce)

// Layout thresholds still hardcoded
static const int ptLayoutThreshold = 8;             // token_card.dart (P/T text wrapping)

// Padding presets still hardcoded in multiple files
// Various (16, 12, 8, 24, 4) values — lower priority
```

### Files with Remaining Magic Numbers

**Note:** Line numbers from the Dec 2025 audit are stale. The numbers below reflect patterns, not exact locations. Grep for specific values when implementing.

**token_card.dart:**
- `Duration(milliseconds: 500)` — P/T scale animation (should use artworkFadeInDuration or new ptAnimationDuration constant)
- `Tween(begin: 1.0, end: 1.5)` — P/T bounce scale
- `0.5` opacity for zero-amount tokens
- `0.7` opacity for type text
- `8` character threshold for P/T layout
- `0.85` opacity for P/T backgrounds (should use textBackgroundOpacity)

**tracker_widget_card.dart:**
- `48` icon size for toggle
- `0.85` button background opacity (should use textBackgroundOpacity)
- `+2` magic padding adjustment

**multiplier_view.dart** (stable — these line numbers still accurate):
- Line 25: FAB padding `(16, 12)`
- Line 87: Focus delay `100ms`
- Line 139: Container padding `(16, 12)`
- Line 159: Disabled opacity `0.3` (should use UIConstants.disabledOpacity)
- Line 165: TextField width `100`

**floating_action_menu.dart** (stable):
- Line 88: Bottom padding `24`
- Line 234: Padding `(16, 4)`
- Line 241: Inactive opacity `0.15` (should use UIConstants.actionButtonBackgroundOpacity)

**Estimated remaining effort:** 1-2 hours
**Risk:** Low

---

## 2. MISSING DEFAULT VALUES

**Status: EXCELLENT — Zero issues found**

All Hive models properly implement `defaultValue` parameters:
- Item (16 fields)
- TokenTemplate (9 fields)
- TrackerWidget (17 fields)
- ToggleWidget (14 fields)
- Deck, TokenCounter (simple models)

**Migration safety:** 100% — No risk of data loss on upgrades.

---

## 3. PERFORMANCE RISKS

### Medium Priority — TokenProvider.items getter

**Status: MOVED — Now tracked in TokenProviderImprovement.md Phase 1**

Bundled with the TokenProvider refactor since it touches the same methods (insertItem, deleteItem, etc.).

### Positive Findings (still true)
- CroppedArtworkWidget properly caches ui.Image objects
- Search screens use debouncing (300ms)
- Proper async operations with mounted checks

---

## 4. CODE DUPLICATION

### COMPLETED — Artwork Layer Pattern

**Extracted to:** `lib/widgets/mixins/artwork_display_mixin.dart` (211 lines)

All three card types now use the shared mixin:
- `token_card.dart` — `with ArtworkDisplayMixin`
- `tracker_widget_card.dart` — `with ArtworkDisplayMixin`
- `toggle_widget_card.dart` — `with ArtworkDisplayMixin`

**Lines saved:** ~300 (down from ~510 duplicated across 3 files)

### COMPLETED — BackgroundText Widget

**Extracted to:** `lib/widgets/common/background_text.dart` (34 lines)

Used by all three card types. Uses `UIConstants.textBackgroundOpacity`.

### COMPLETED — Artwork Cleanup Bug Fix

TrackerWidgetCard and ToggleWidgetCard now properly clear all three fields (`artworkUrl`, `artworkSet`, `artworkOptions`) during cleanup, matching TokenCard's pattern.

### Still Pending — Order Calculation Utility

Order pattern `maxOrder.floor() + 1.0` still repeated in:
- `token_provider.dart:insertItem()` (line ~98)
- `tracker_provider.dart` (similar pattern)
- `toggle_provider.dart` (similar pattern)
- Various UI callers that compute order across all three item types

**Suggested:** Extract to `lib/utils/order_utils.dart`:
```dart
class OrderUtils {
  static double nextWholeOrder(Iterable<double> orders) {
    if (orders.isEmpty) return 0.0;
    return orders.reduce(max).floor() + 1.0;
  }

  static double fractionalOrder(double prev, double next) {
    return (prev + next) / 2.0;
  }
}
```

**Estimated effort:** 1.5 hours
**Risk:** Low
**Note:** This overlaps with TokenProviderImprovement Phase 1 — could be done together.

---

## 5. DESIGN INCONSISTENCIES

### Animation Duration Mismatch

- `UIConstants.animationDuration = 300ms`
- `UIConstants.artworkFadeInDuration = 500ms`
- P/T scale animation uses `500ms` directly

**Assessment (Feb 2026):** This appears intentional — different animation types use different durations. The 300ms constant is for quick UI transitions (sheet dismiss, etc.), while 500ms is for visible artwork/P/T animations. Consider renaming for clarity:
- `animationDuration` → `quickTransitionDuration` (300ms)
- `artworkFadeInDuration` stays (500ms)
- Add `ptAnimationDuration` (500ms) if P/T bounce should use a constant

**Estimated effort:** 30 minutes
**Risk:** Low

---

## 6. CLEANUP ITEMS

### ALL COMPLETED

- ~~content_screen.dart: Commented-out shadow calculation~~ — Removed
- ~~tracker_widget_card.dart: Hardcoded Scryfall URL~~ — Removed
- ~~token_card.dart: Outdated gradient comment~~ — Removed

---

## REMAINING IMPLEMENTATION PRIORITY

### Sprint 1 (Quick Wins) — ~2 hours
1. Add remaining magic number constants to UIConstants (~20 values)
2. Replace hardcoded values with constants across files
3. Cache sorted items list in TokenProvider

### Sprint 2 (Overlaps with TokenProviderImprovement) — ~2 hours
4. Extract order calculation utilities
5. Rename animation duration constants for clarity

---

## TESTING CHECKLIST

After implementing remaining fixes:

- [ ] All card types render correctly (Token, Tracker, Toggle)
- [ ] Artwork display works in both Full View and Fadeout modes
- [ ] Artwork animations trigger properly
- [ ] Performance: Large token lists (50+ items) scroll smoothly
- [ ] Deck save/load preserves order correctly
- [ ] No visual regressions in padding, opacity, or colors

---

## POSITIVE FINDINGS (still true)

- Excellent Hive migration safety — all models have proper defaultValue
- Good constant usage — UIConstants class well-structured and growing
- Proper memory management — images cached and disposed correctly
- Safe async operations — mounted checks prevent crashes
- Smart performance — search debouncing, proper ValueListenables
- Good error handling — comprehensive error messages in providers
- Artwork display mixin — clean DRY pattern across all card types
