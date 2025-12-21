# Artwork Implementation Research

**Date:** December 20, 2025
**Purpose:** Analyze existing artwork implementations to design the ArtworkDisplayMixin

---

## Summary of Findings

Analyzed three card implementations:
- ✅ **TokenCard** (Gold standard - `lib/widgets/token_card.dart`)
- **TrackerWidgetCard** (`lib/widgets/tracker_widget_card.dart`)
- **ToggleWidgetCard** (`lib/widgets/toggle_widget_card.dart`)

### Key Clarification: ToggleWidget State-Specific Artwork

⚠️ **ToggleWidget does NOT actually use state-specific artwork (on/off) on the frontend.** The feature is scaffolded in the model but not implemented:
- Model has `onArtworkUrl` and `offArtworkUrl` fields (always null)
- Has `currentArtworkUrl` computed property
- Card calls `currentArtworkUrl` but it always returns general `artworkUrl`
- No UI exists to set state-specific artwork
- **Mixin implementation can treat ToggleWidget like other cards - no special handling needed**

---

## 1. Implementation Pattern Discrepancy

### TokenCard (lines 565-727)
Uses **SEPARATE helper methods**:
```dart
Widget _buildArtworkLayer(...) {
  if (artworkStyle == 'fadeout') {
    return _buildFadeoutArtwork(context, constraints);
  } else {
    return _buildFullViewArtwork(context, constraints);
  }
}

Widget _buildFullViewArtwork(...) { /* 65 lines */ }
Widget _buildFadeoutArtwork(...) { /* 70 lines */ }
```

### TrackerWidgetCard (lines 588-729)
Uses **INLINE if/else**:
```dart
Widget _buildArtworkLayer(...) {
  if (artworkDisplayStyle == 'fadeout') {
    // Fadeout implementation inline (70 lines)
  } else {
    // Full view implementation inline (65 lines)
  }
}
```

### ToggleWidgetCard (lines 196-340)
Uses **INLINE if/else** (same as TrackerWidget):
```dart
Widget _buildArtworkLayer(...) {
  final artworkUrl = _getCurrentArtworkUrl(); // Special for toggles
  if (artworkUrl == null) return const SizedBox.shrink();

  if (artworkDisplayStyle == 'fadeout') {
    // Fadeout implementation inline
  } else {
    // Full view implementation inline
  }
}
```

**Conclusion:** TokenCard is the outlier. TrackerWidget and ToggleWidget use the inline pattern described in NextFeature.md.

---

## 2. State Variables (CONSISTENT)

All three cards use identical state variables:

```dart
class _CardState extends State<Card> {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;
  bool _artworkCleanupAttempted = false;

  @override
  void didUpdateWidget(Card oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset cleanup flag if artwork URL changed
    if (oldWidget.item.artworkUrl != widget.item.artworkUrl) {
      _artworkCleanupAttempted = false;
    }
  }
}
```

**Pattern is 100% consistent** across all three implementations.

---

## 3. Cleanup Logic (CRITICAL BUG FOUND!)

### TokenCard (CORRECT - Gold Standard)
**Lines 624-630, 711-717:**
```dart
if (mounted) {
  widget.item.artworkUrl = null;
  widget.item.artworkSet = null;       // ← Clears set
  widget.item.artworkOptions = null;   // ← Clears options
  widget.item.save();
}
```

### TrackerWidgetCard (BUG - Missing Fields)
**Lines 658-661, 716-719:**
```dart
if (mounted) {
  widget.tracker.artworkUrl = null;
  widget.tracker.save();  // ← MISSING artworkSet and artworkOptions!
}
```

### ToggleWidgetCard (BUG - Missing Fields)
**Lines 269-272, 327-330:**
```dart
if (mounted) {
  widget.toggle.artworkUrl = null;
  widget.toggle.save();  // ← MISSING artworkSet and artworkOptions!
}
```

### Model Field Verification

**Item model** (`lib/models/item.dart`):
- `@HiveField(13) String? artworkUrl;`
- `@HiveField(14) String? artworkSet;`
- `@HiveField(15) List<ArtworkVariant>? artworkOptions;`

**TrackerWidget model** (`lib/models/tracker_widget.dart`):
- `@HiveField(9) String? artworkUrl;`
- `@HiveField(15) String? artworkSet;`
- `@HiveField(16) List<ArtworkVariant>? artworkOptions;`

**ToggleWidget model** (`lib/models/toggle_widget.dart`):
- `@HiveField(5) String? artworkUrl;`
- `@HiveField(6) String? onArtworkUrl;`
- `@HiveField(7) String? offArtworkUrl;`
- `@HiveField(11) String? artworkSet;`
- `@HiveField(12) List<ArtworkVariant>? artworkOptions;`

**All three models have artworkSet and artworkOptions fields, but only TokenCard clears them!**

---

## 4. ToggleWidget Special Behavior (NOT ACTUALLY IMPLEMENTED)

⚠️ **IMPORTANT:** ToggleWidget has scaffolded support for state-specific artwork (on/off), but this feature is **NOT IMPLEMENTED on the frontend**.

**Model property** (`toggle_widget.dart:79-83`):
```dart
String? get currentArtworkUrl {
  if (isActive && onArtworkUrl != null) return onArtworkUrl;
  if (!isActive && offArtworkUrl != null) return offArtworkUrl;
  return artworkUrl;  // Fallback to general artwork
}
```

**Card helper method** (`toggle_widget_card.dart:155-158`):
```dart
String? _getCurrentArtworkUrl() {
  return widget.toggle.currentArtworkUrl;
}
```

**Why it doesn't work:**
1. ✅ Model has `onArtworkUrl` and `offArtworkUrl` fields
2. ✅ Model has `currentArtworkUrl` computed property
3. ✅ Card calls `currentArtworkUrl` via helper method
4. ❌ **No UI exists to set `onArtworkUrl` or `offArtworkUrl`**
5. ❌ **ExpandedWidgetScreen only has getters/setters for general `artworkUrl`** (lines 87-98)
6. ❌ **Fields are never assigned - always null**
7. ❌ **Always falls back to general `artworkUrl`**

**Current behavior:** ToggleWidget always uses the same artwork regardless of on/off state.

**For mixin implementation:** The `artworkUrl` getter interface works fine even though it calls `currentArtworkUrl`, because that property just returns the general `artworkUrl` anyway. **No special handling needed for current implementation.**

**Future work:** If state-specific artwork is implemented later:
- Add UI in ExpandedWidgetScreen to set `onArtworkUrl` and `offArtworkUrl`
- Add separate getters/setters for these fields (like lines 87-98)
- Mixin will automatically support it (no changes needed)
- Cleanup logic will need to clear all three artwork fields

---

## 5. Animation Logic (CONSISTENT)

All three implementations use identical animation threshold logic:

```dart
final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
final shouldAnimate = elapsed > 100 && !_artworkAnimated;

if (shouldAnimate) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      setState(() {
        _artworkAnimated = true;
      });
    }
  });
}

return AnimatedOpacity(
  opacity: 1.0,
  duration: shouldAnimate ? const Duration(milliseconds: 500) : Duration.zero,
  curve: Curves.easeIn,
  // ... child
);
```

**Magic numbers identified:**
- `100` milliseconds - Animation threshold
- `500` milliseconds - Animation duration
- `2000` milliseconds - Cleanup delay

---

## 6. Selector Usage

**TokenCard:**
```dart
Selector<SettingsProvider, (bool, String)>(
  selector: (context, settings) =>
    (settings.summoningSicknessEnabled, settings.artworkDisplayStyle),
  // Watches TWO settings
)
```

**TrackerWidgetCard & ToggleWidgetCard:**
```dart
Selector<SettingsProvider, String>(
  selector: (context, settings) => settings.artworkDisplayStyle,
  // Watches ONE setting
)
```

**Utilities don't need summoning sickness** - pattern is correct.

---

## 7. Exact Duplication Statistics

**Code duplicated across all 3 cards:**
- Animation threshold logic: ~15 lines × 3 = 45 lines
- Cleanup logic: ~15 lines × 3 = 45 lines
- FutureBuilder structure: ~25 lines × 3 × 2 modes = 150 lines
- AnimatedOpacity wrapper: ~15 lines × 3 × 2 modes = 90 lines
- ShaderMask for fadeout: ~12 lines × 3 = 36 lines
- CroppedArtworkWidget call: ~10 lines × 3 × 2 modes = 60 lines

**Total duplicated lines: ~426 lines**

Actual implementations:
- TokenCard artwork methods: 163 lines (565-727)
- TrackerWidget artwork method: 142 lines (588-729)
- ToggleWidget artwork method: 145 lines (196-340)

**Total actual lines: 450 lines**

**Potential savings with mixin: ~300 lines** (keeping some per-card customization)

---

## 8. Mixin Interface Requirements

Based on gold standard (TokenCard), the mixin needs:

### Required State Variables (provide via getters/setters)
```dart
DateTime get createdAt;
bool get artworkAnimated;
set artworkAnimated(bool value);
bool get artworkCleanupAttempted;
set artworkCleanupAttempted(bool value);
```

### Required Methods (implement in card class)
```dart
String? get artworkUrl;  // For most cards, return widget.item.artworkUrl
void clearArtwork();     // Clear artworkUrl, artworkSet, artworkOptions, then save
```

### Special Cases
**ToggleWidget (appears special, but isn't):**
```dart
@override
String? get artworkUrl => widget.toggle.currentArtworkUrl;  // Uses computed property
```

This LOOKS like special handling, but `currentArtworkUrl` always returns the general `artworkUrl` because state-specific fields are never set. The mixin doesn't need any special logic for this case.

### Cleanup Implementation (CORRECT PATTERN)

**TokenCard (gold standard):**
```dart
@override
void clearArtwork() {
  widget.item.artworkUrl = null;
  widget.item.artworkSet = null;
  widget.item.artworkOptions = null;
  widget.item.save();
}
```

**TrackerWidget (NEEDS FIX):**
```dart
@override
void clearArtwork() {
  widget.tracker.artworkUrl = null;
  widget.tracker.artworkSet = null;      // ← ADD THIS
  widget.tracker.artworkOptions = null;  // ← ADD THIS
  widget.tracker.save();
}
```

**ToggleWidget (NEEDS FIX):**
```dart
@override
void clearArtwork() {
  widget.toggle.artworkUrl = null;
  widget.toggle.artworkSet = null;      // ← ADD THIS
  widget.toggle.artworkOptions = null;  // ← ADD THIS
  widget.toggle.save();
}
```

---

## 9. Recommended Mixin Implementation

### Option A: Inline Pattern (Matches Tracker/Toggle)
Mixin implements single `buildArtworkLayer()` with inline if/else blocks (140+ lines).

**Pros:**
- Matches 2/3 existing implementations
- Single method to maintain

**Cons:**
- Very long method (~140 lines)
- Harder to read

### Option B: Separate Methods Pattern (Matches TokenCard)
Mixin delegates to `_buildFullViewArtwork()` and `_buildFadeoutArtwork()` helper methods.

**Pros:**
- Matches gold standard (TokenCard)
- Better code organization
- Easier to understand and modify

**Cons:**
- More methods
- Slightly more code

**Recommendation:** **Option B - Follow TokenCard gold standard**

TokenCard is the most mature implementation and uses the cleaner pattern. When refactoring, we should migrate TrackerWidget and ToggleWidget to the separate methods pattern, not the other way around.

---

## 10. Migration Strategy

### Phase 1: Fix Cleanup Bugs (URGENT)
Before creating mixin, fix the missing cleanup fields:

1. Update `tracker_widget_card.dart` lines 659-660, 717-718:
   ```dart
   widget.tracker.artworkUrl = null;
   widget.tracker.artworkSet = null;      // ADD
   widget.tracker.artworkOptions = null;  // ADD
   widget.tracker.save();
   ```

2. Update `toggle_widget_card.dart` lines 270-271, 328-329:
   ```dart
   widget.toggle.artworkUrl = null;
   widget.toggle.artworkSet = null;      // ADD
   widget.toggle.artworkOptions = null;  // ADD
   widget.toggle.save();
   ```

**Risk:** Low
**Estimated time:** 5 minutes
**Testing:** Verify artwork cleanup still works

### Phase 2: Create Mixin (REFACTOR)
1. Create `lib/widgets/mixins/artwork_display_mixin.dart`
2. Extract shared logic from TokenCard (gold standard)
3. Use separate helper methods pattern
4. Add comprehensive documentation

**Risk:** Medium
**Estimated time:** 2-3 hours
**Testing:** All three card types in both display modes

### Phase 3: Apply Mixin (MIGRATE)
1. Update TokenCard to use mixin (should be straightforward)
2. Update TrackerWidgetCard to use mixin
3. Update ToggleWidgetCard to use mixin (handle `currentArtworkUrl`)
4. Remove old `_buildArtworkLayer()` methods
5. Remove old `_buildFullViewArtwork()` / `_buildFadeoutArtwork()` methods

**Risk:** Medium
**Estimated time:** 1-2 hours
**Testing:** Regression test all artwork features

---

## 11. Critical Findings Summary

### Bugs Found
1. ❌ **TrackerWidget cleanup incomplete** - Missing artworkSet and artworkOptions
2. ❌ **ToggleWidget cleanup incomplete** - Missing artworkSet and artworkOptions

### Pattern Inconsistencies
3. ⚠️ **TokenCard uses separate methods**, TrackerWidget/ToggleWidget use inline
4. ⚠️ **Magic numbers** (100ms, 500ms, 2000ms) hardcoded in all three

### Design Notes
5. ℹ️ **ToggleWidget uses `currentArtworkUrl`** but it's not actually implemented - always returns general `artworkUrl`

### Opportunities
6. ✅ **~300 lines can be eliminated** with proper mixin
7. ✅ **State variables are 100% consistent** - mixin interface is simple
8. ✅ **Animation logic is identical** - perfect for sharing

---

## Next Steps

1. **Fix cleanup bugs** (5 min, low risk) - DO THIS FIRST
2. **Create artwork display mixin** (2-3 hours, medium risk)
3. **Migrate all three cards** (1-2 hours, medium risk)
4. **Update NextFeature.md** to reference mixin pattern
5. **Add to code quality audit as COMPLETED**

**Total estimated effort:** 3-5 hours
**Lines saved:** ~300 lines
**Bugs fixed:** 2 (cleanup incomplete)
**Maintainability improvement:** HIGH
