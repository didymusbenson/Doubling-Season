---
## 📦 Latest Build Artifacts (v1.3.0+8)

**iOS (.ipa):**
`build/ios/ipa/Doubling Season.ipa` (21.9MB)

**Android (.aab):**
`build/app/outputs/bundle/release/app-release.aab` (44.2MB)

**Built:** 2025-11-20
**Status:** Ready to deploy

---

# Bug Fix: Remove Placeholder Pattern from Custom Token Creation ⚠️ URGENT

## Priority

**URGENT** - This creates a confusing broken state for custom tokens with the "(loading...)" suffix and amount=0.

## Problem Statement

`lib/widgets/new_token_sheet.dart` still uses the old placeholder pattern that was removed from TokenSearchScreen in the Issue #2 performance fix. Custom tokens appear as:
- `"Token Name (loading...)"` with `amount: 0`
- Then get updated to remove "(loading...)" and set correct amount

This is **unnecessary** because custom tokens don't have artwork downloads (no async delay), so the placeholder serves no purpose. It's just leftover code that creates a confusing broken state.

## Current Implementation (Lines 235-272)

```dart
// Create placeholder with amount=0
final placeholderItem = Item(
  name: '${_nameController.text} (loading...)',
  pt: _ptController.text,
  type: _typeController.text.trim(),
  colors: _getColorString(),
  abilities: _abilitiesController.text,
  amount: 0, // Placeholder
  tapped: 0,
  summoningSick: 0,
);

// Insert placeholder immediately
await tokenProvider.insertItem(placeholderItem);

// Close dialog immediately (before async gap)
if (mounted) {
  Navigator.pop(context);
}

// Update placeholder with final data in background
try {
  placeholderItem.name = _nameController.text; // Remove "(loading...)"
  placeholderItem.amount = finalAmount;
  placeholderItem.tapped = _createTapped ? finalAmount : 0;
  placeholderItem.summoningSick =
      settings.summoningSicknessEnabled ? finalAmount : 0;
  await placeholderItem.save();
} catch (error) {
  // ... error handling
}
```

## Required Fix

Remove the placeholder pattern and create the token with final data immediately, matching the TokenSearchScreen implementation.

**Replace lines 235-272 with:**

```dart
// Create final token immediately (no placeholder)
final newItem = Item(
  name: _nameController.text,
  pt: _ptController.text,
  type: _typeController.text.trim(),
  colors: _getColorString(),
  abilities: _abilitiesController.text,
  amount: finalAmount,
  tapped: _createTapped ? finalAmount : 0,
  summoningSick: 0, // Will be set below if needed
);

// Insert token immediately
await tokenProvider.insertItem(newItem);

// Apply summoning sickness if enabled AND token is a creature without Haste
// (must be after insert because setter calls save())
if (settings.summoningSicknessEnabled &&
    newItem.hasPowerToughness &&
    !newItem.hasHaste) {
  newItem.summoningSick = finalAmount;
}

// Close dialog - token is on board and usable
if (mounted) {
  Navigator.pop(context);
}
```

## Notes

- This also applies the summoning sickness logic fix (checking for P/T and Haste) from the other bug fix
- No placeholder, no "(loading...)" suffix, no amount=0 state
- Token is immediately complete and usable
- Consistent with TokenSearchScreen implementation

---

# Bug Fix: Summoning Sickness Logic

## Problem Statement

Summoning sickness is currently applied to all tokens when the "Summoning Sickness" setting is enabled, regardless of the token's characteristics. However, according to Magic: The Gathering rules:

1. **Only creatures can have summoning sickness** - tokens without power/toughness (like Treasure, Food, Clue, etc.) should not receive summoning sickness
2. **Creatures with Haste don't have summoning sickness** - tokens with "Haste" in their abilities text should be exempt from summoning sickness

## Current Behavior

When a token is created with "Summoning Sickness" enabled in settings:
- ALL tokens receive summoning sickness, including non-creatures (Treasure, Food, etc.)
- Tokens with "Haste" still receive summoning sickness

## Expected Behavior

When a token is created with "Summoning Sickness" enabled in settings:
- Only tokens with power/toughness (P/T) should receive summoning sickness
- Tokens with "Haste" (case-insensitive) in their abilities text should NOT receive summoning sickness
- Non-creature tokens (no P/T) should NOT receive summoning sickness

## Implementation Requirements

### Rule 1: Check for Power/Toughness

A token should only be eligible for summoning sickness if it has power/toughness stats.

**Detection logic:**
```dart
bool get hasPowerToughness {
  return pt.isNotEmpty && pt.trim() != '';
}
```

### Rule 2: Check for Haste

A token with "Haste" in its abilities text should never receive summoning sickness.

**Detection logic:**
```dart
bool get hasHaste {
  return abilities.toLowerCase().contains('haste');
}
```

### Combined Logic

Summoning sickness should only be applied if:
1. The summoning sickness setting is enabled (existing check)
2. AND the token has power/toughness
3. AND the token does NOT have Haste

**Implementation pattern:**
```dart
// When creating a token (e.g., in TokenSearchScreen, NewTokenSheet, etc.)
if (settingsProvider.summoningSicknessEnabled &&
    newItem.hasPowerToughness &&
    !newItem.hasHaste) {
  newItem.summoningSick = finalAmount;
}
```

## Files to Modify

### 1. `lib/models/item.dart`

Add two computed properties to the `Item` class:

```dart
/// Returns true if this token has power/toughness stats
bool get hasPowerToughness {
  return pt.isNotEmpty && pt.trim() != '';
}

/// Returns true if this token has Haste (negates summoning sickness)
bool get hasHaste {
  return abilities.toLowerCase().contains('haste');
}
```

Place these properties near the existing `isEmblem` computed property for consistency.

### 2. `lib/screens/token_search_screen.dart`

Update the summoning sickness logic when creating tokens (around line 834-837):

**Current code:**
```dart
// Apply summoning sickness if enabled (must be after insert because setter calls save())
if (settingsProvider.summoningSicknessEnabled) {
  newItem.summoningSick = finalAmount;
}
```

**Updated code:**
```dart
// Apply summoning sickness if enabled AND token is a creature without Haste
// (must be after insert because setter calls save())
if (settingsProvider.summoningSicknessEnabled &&
    newItem.hasPowerToughness &&
    !newItem.hasHaste) {
  newItem.summoningSick = finalAmount;
}
```

### 3. `lib/widgets/new_token_sheet.dart`

Update the summoning sickness logic when creating custom tokens (around the token creation section):

**Find the similar pattern:**
```dart
if (settingsProvider.summoningSicknessEnabled) {
  newItem.summoningSick = finalAmount;
}
```

**Update to:**
```dart
if (settingsProvider.summoningSicknessEnabled &&
    newItem.hasPowerToughness &&
    !newItem.hasHaste) {
  newItem.summoningSick = finalAmount;
}
```

### 4. `lib/providers/token_provider.dart`

Check the `copyToken()` method and any other token creation paths to ensure the same logic is applied consistently.

Look for any instances where `summoningSick` is set and verify they follow the new pattern.

## Testing Checklist

### Test Case 1: Non-Creature Tokens (No P/T)
- [ ] Create a Treasure token with summoning sickness enabled
- [ ] Verify the token does NOT have summoning sickness
- [ ] Create a Food token with summoning sickness enabled
- [ ] Verify the token does NOT have summoning sickness
- [ ] Create a Clue token with summoning sickness enabled
- [ ] Verify the token does NOT have summoning sickness

### Test Case 2: Creature Tokens Without Haste
- [ ] Create a 1/1 Soldier token with summoning sickness enabled
- [ ] Verify the token DOES have summoning sickness
- [ ] Create a 2/2 Zombie token with summoning sickness enabled
- [ ] Verify the token DOES have summoning sickness

### Test Case 3: Creature Tokens With Haste
- [ ] Create a creature token with "Haste" in abilities text (e.g., 1/1 Goblin with Haste)
- [ ] Verify the token does NOT have summoning sickness
- [ ] Create a creature token with "haste" in lowercase
- [ ] Verify the token does NOT have summoning sickness
- [ ] Create a creature token with "Haste, Trample" (Haste among other abilities)
- [ ] Verify the token does NOT have summoning sickness

### Test Case 4: Summoning Sickness Disabled
- [ ] Disable summoning sickness in settings
- [ ] Create any creature token (with or without Haste)
- [ ] Verify the token does NOT have summoning sickness

### Test Case 5: Copy Token Behavior
- [ ] Create a creature token without Haste (should have summoning sickness)
- [ ] Copy the token
- [ ] Verify the copy also has summoning sickness
- [ ] Create a creature token with Haste (should NOT have summoning sickness)
- [ ] Copy the token
- [ ] Verify the copy does NOT have summoning sickness

### Test Case 6: Custom Token Creation
- [ ] Create a custom non-creature token (no P/T) via "Create Custom Token"
- [ ] Verify it does NOT have summoning sickness
- [ ] Create a custom creature token via "Create Custom Token"
- [ ] Verify it DOES have summoning sickness
- [ ] Create a custom creature with Haste via "Create Custom Token"
- [ ] Verify it does NOT have summoning sickness

## Edge Cases to Consider

1. **Empty P/T field:** Tokens with `pt = ""` or `pt = "   "` should be treated as non-creatures
2. **Case sensitivity:** "Haste", "haste", "HASTE" should all be recognized
3. **Haste in the middle of text:** "Flying, Haste, Trample" should be detected
4. **Copy behavior:** Copied tokens should inherit the summoning sickness state of the original

## Priority

**Nice-to-have** - This is a quality-of-life improvement that makes the app more faithful to Magic rules, but it's not blocking any critical functionality.

## Notes

- This change only affects token creation, not existing tokens in the database
- Existing tokens with incorrect summoning sickness will not be retroactively fixed
- The change is purely logical and doesn't require any UI modifications
- No migration or data model changes are needed

---

# UI Improvement: Condense P/T Layout for Tokens Without Abilities

## Problem Statement

Currently, tokens without abilities text waste vertical space. The P/T is displayed below the type line with empty space in between, when it could be inline with the type line to save space.

The card layout currently behaves as:
- **Type line** (top)
- **Abilities text** with **P/T bottom-right** (if abilities present)
- **P/T** on its own row (if NO abilities - wasteful)

## Current Layout

**With abilities (current - good):**
```
Type line (Creature — Zombie)
Abilities text wraps...  [2/2]
```

**Without abilities (current - wasteful):**
```
Type line (Creature — Zombie)

                          [2/2]
```

## Proposed Layout

**With abilities (unchanged):**
```
Type line (Creature — Zombie)
Abilities text wraps...  [2/2]
```

**Without abilities (condensed - saves space):**
```
Type line (Creature — Zombie)  [2/2]
```

The layout should look basically how it already does, just that when there are no abilities, the P/T should be inline with the type line instead of below it.

## Design Requirements

### Current Implementation

Currently uses two layout methods in `token_card.dart` (lines 270-278):

1. `_buildInlineAbilitiesAndPT()` - Row layout with abilities on left, P/T on right
2. `_buildStackedAbilitiesAndPT()` - Column layout for long P/T (>= 8 chars)

### Required Change

Modify the layout logic to handle the "no abilities" case:

**When there ARE abilities:**
- Use existing Row layout (inline) or Column layout (stacked) based on P/T length
- Type line above, abilities + P/T below (current behavior)

**When there are NO abilities:**
- Position P/T inline with the type line (bottom-right aligned)
- Type and P/T should share the same vertical space

### Layout Structure

The Type + Abilities + P/T section should be a **Stack** or **Row** that allows:
1. **Type line** (always top-left or full-width)
2. **Abilities** (stacked below type, constrained width to leave room for P/T)
3. **P/T** (bottom-right, aligned with abilities if present, or with type line if no abilities)

## Files to Modify

### `lib/widgets/token_card.dart`

**Current section (lines 269-279):**
```dart
// Abilities and P/T - conditional layout based on P/T size
if (widget.item.abilities.isNotEmpty || (!widget.item.isEmblem && widget.item.pt.isNotEmpty)) ...[
  const SizedBox(height: UIConstants.mediumSpacing),
  Padding(
    padding: EdgeInsets.only(right: kIsWeb ? 40 : 0, bottom: UIConstants.mediumSpacing),
    // Use Column layout if formatted P/T is too long (>= 8 chars like "1000/1000")
    child: (!widget.item.isEmblem && widget.item.pt.isNotEmpty && widget.item.formattedPowerToughness.length >= 8)
        ? _buildStackedAbilitiesAndPT(context, widget.item)
        : _buildInlineAbilitiesAndPT(context, widget.item),
  ),
],
```

**Modify to handle type + abilities + P/T together:**

The Type line (currently lines 224-241) should be included in the same vertical layout block as abilities and P/T, allowing the P/T to align with whichever is the bottom row (abilities or type).

**Suggested approach:**

Create a combined section that includes Type, Abilities, and P/T in a way that:
- Type is always shown (if present)
- Abilities are shown below type (if present)
- P/T is bottom-right aligned with:
  - Abilities row (if abilities present)
  - Type row (if no abilities)

This may require wrapping Type + Abilities in a Column, then using that Column in a Row with P/T, or using a Stack for more precise positioning.

## Testing Checklist

### Visual Tests

- [ ] **Creature with abilities:** Type on top, abilities + P/T below (unchanged from current)
- [ ] **Creature without abilities:** Type and P/T inline on same row (condensed)
- [ ] **Non-creature token (no P/T):** Type line only, no empty space
- [ ] **Long P/T (>= 8 chars):** Stacked layout still works correctly
- [ ] **Modified P/T:** Colored background on P/T still displays correctly
- [ ] **Emblem:** Emblem layout remains centered and unchanged

### Functional Tests

- [ ] Text backgrounds (semi-transparent overlays) render correctly in all cases
- [ ] Artwork display modes (Full View / Fadeout) still work with new layout
- [ ] Type and abilities text wrapping works correctly
- [ ] Layout works in both light and dark mode

## Priority

**Nice-to-have** - This is a visual improvement that makes cards more compact, especially for tokens without abilities. Not critical functionality.

## Notes

- This change is purely visual/layout - no data model changes required
- Existing text wrapping and P/T styling logic should be preserved
- The `formattedPowerToughness` computed property already handles counter modifications
- May need to refactor the Type line (currently separate) into the same layout block as abilities + P/T
