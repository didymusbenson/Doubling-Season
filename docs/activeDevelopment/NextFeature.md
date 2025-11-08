# Next Feature

## Feature 1: Display Token Types

### Overview
Add token type display to both list view (TokenCard) and detail view (ExpandedTokenScreen). Types should appear under the name and above abilities, matching the layout of physical Magic cards.

### Current Problem
Token types (e.g., "Creature — Elf Warrior", "Artifact", "Emblem") are completely missing from the UI:
- **TokenDefinition** (database model) has `type` field with values like "Creature — Elf Warrior Token"
- **Item** (active token model) does NOT have a `type` field
- **TokenTemplate** (deck save/load model) does NOT have a `type` field
- When converting TokenDefinition → Item via `toItem()`, the type information is lost
- NewTokenSheet (custom token creation) has no type input field
- Neither TokenCard nor ExpandedTokenScreen display type information

### Required Changes

**Summary:** 6 files need updates to support type display
1. `lib/models/item.dart` - Add HiveField 12 for type
2. `lib/models/token_template.dart` - Add HiveField 5 for type
3. `lib/models/token_definition.dart` - Pass type in toItem()
4. `lib/widgets/new_token_sheet.dart` - Add type input field
5. `lib/widgets/token_card.dart` - Display type in list view
6. `lib/screens/expanded_token_screen.dart` - Display and edit type

#### 1. Add Type Field to Item Model
**File:** `lib/models/item.dart`

Add new Hive field for type:
```dart
@HiveField(12)  // Next available field ID
String type;
```

**CRITICAL:**
- Must use next available HiveField ID (currently 12)
- NEVER change existing field IDs (risk of data corruption)
- Add to constructor with default value: `this.type = ''`
- Consider migration strategy for existing tokens without type

#### 2. Add Type Field to TokenTemplate Model
**File:** `lib/models/token_template.dart`

Add new Hive field for type:
```dart
@HiveField(5)  // Next available field ID (after order at 4)
String type;
```

Update constructor:
```dart
TokenTemplate({
  required this.name,
  required this.pt,
  required this.abilities,
  required this.colors,
  this.type = '',  // ← Add with default
  this.order = 0.0,
});
```

Update `fromItem()` factory:
```dart
factory TokenTemplate.fromItem(Item item) {
  return TokenTemplate(
    name: item.name,
    pt: item.pt,
    abilities: item.abilities,
    colors: item.colors,
    type: item.type,  // ← Add this line
    order: item.order,
  );
}
```

Update `toItem()` method:
```dart
Item toItem({int amount = 1, bool createTapped = false}) {
  return Item(
    name: name,
    pt: pt,
    abilities: abilities,
    colors: colors,
    type: type,  // ← Add this line
    amount: amount,
    tapped: createTapped ? amount : 0,
    summoningSick: 0,
    order: order,
  );
}
```

**Why this matters:** TokenTemplate is used for deck saving/loading. Without type, saved decks would lose type information.

#### 3. Preserve Type During Conversion
**File:** `lib/models/token_definition.dart`

Update `toItem()` method to include type:
```dart
Item toItem({required int amount, required bool createTapped}) {
  return Item(
    name: name,
    pt: pt,
    abilities: abilities,
    colors: colors,
    type: type,  // ← Add this line
    amount: amount,
    tapped: createTapped ? amount : 0,
    summoningSick: amount,
  );
}
```

#### 4. Display Type in Token Card (List View)
**File:** `lib/widgets/token_card.dart`

Add type display between name and abilities:
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    // Name row (existing)
    Row(...),

    // TYPE - New section
    if (item.type.isNotEmpty) ...[
      const SizedBox(height: 4),
      Text(
        item.cleanType,  // Use cleanType to remove "Token" suffix
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
        ),
      ),
    ],

    // Counter pills (existing)
    if (item.counters.isNotEmpty...) ...[],

    // Abilities (existing)
    if (item.abilities.isNotEmpty) ...[],
  ],
)
```

**Design notes:**
- Use italic font to match Magic card styling
- Use `bodySmall` for secondary/supporting text
- Reduce opacity (0.7) to de-emphasize vs name
- Use `cleanType` helper to strip "Token" suffix

#### 5. Add Type Field to Custom Token Creation
**File:** `lib/widgets/new_token_sheet.dart`

Add type input field between P/T and Colors:

**Add controller:**
```dart
final _typeController = TextEditingController();

@override
void dispose() {
  _nameController.dispose();
  _ptController.dispose();
  _typeController.dispose();  // ← Add this
  _abilitiesController.dispose();
  super.dispose();
}
```

**Add TextField in build():**
```dart
TextField(
  controller: _ptController,
  decoration: const InputDecoration(
    labelText: 'Power/Toughness',
    hintText: 'e.g., 1/1',
    border: OutlineInputBorder(),
  ),
),
const SizedBox(height: 16),

// TYPE FIELD - New
TextField(
  controller: _typeController,
  decoration: const InputDecoration(
    labelText: 'Type',
    hintText: 'e.g., Creature — Elf Warrior',
    border: OutlineInputBorder(),
  ),
  textCapitalization: TextCapitalization.words,
),
const SizedBox(height: 16),

// Colors section (existing)
const Text('Colors', ...),
```

**Update _createToken() to include type:**
```dart
void _createToken() {
  final item = Item(
    name: _nameController.text.trim(),
    pt: _ptController.text.trim(),
    type: _typeController.text.trim(),  // ← Add this
    abilities: _abilitiesController.text.trim(),
    colors: _getColorString(),
    amount: finalAmount,
    tapped: _createTapped ? finalAmount : 0,
    summoningSick: settings.summoningSicknessEnabled ? finalAmount : 0,
  );
  // ...
}
```

**Design notes:**
- Positioned between P/T and Colors (matches card layout)
- Use TextCapitalization.words for proper capitalization
- Placeholder example: "Creature — Elf Warrior"
- Optional field (can be left empty)

#### 6. Display Type in Expanded View (Detail Screen)
**File:** `lib/screens/expanded_token_screen.dart`

Add type display after name/stats row:
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    // Name and Stats row (existing)
    Row(...),

    const SizedBox(height: 16),

    // TYPE - New section
    if (widget.item.type.isNotEmpty)
      _buildEditableField(
        label: 'Type',
        field: EditableField.type,  // Add to enum
        value: widget.item.type,
        onSave: (value) => widget.item.type = value,
      ),

    const SizedBox(height: 16),

    // Abilities (existing)
    _buildEditableField(...),
  ],
)
```

**Add to EditableField enum:**
```dart
enum EditableField {
  name,
  powerToughness,
  type,      // ← Add this
  abilities,
}
```

### Implementation Order
1. Add `type` field to Item model (HiveField 12)
2. Add `type` field to TokenTemplate model (HiveField 5)
3. Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate Hive adapters
4. Update `TokenDefinition.toItem()` to pass type
5. Update `TokenTemplate.fromItem()` to pass type
6. Update `TokenTemplate.toItem()` to pass type
7. Add `cleanType` getter to Item model (similar to TokenDefinition)
8. Update NewTokenSheet to include type input field
9. Update TokenCard to display type
10. Update ExpandedTokenScreen to display and edit type
11. Test with existing tokens (should show empty type initially)
12. Test with new tokens created from search (should show proper type)
13. Test with custom tokens created manually (should accept and display type)
14. Test deck save/load (should preserve type information)

### Data Migration Strategy

**Problem:** Existing tokens in Hive don't have type field.

**Solution:**
- When adding HiveField 12, provide default value `''` (empty string)
- Existing tokens will automatically get empty type on first load
- No manual migration needed (Hive handles this gracefully)
- Users can manually edit type in ExpandedTokenScreen if desired

### Testing Checklist
- [ ] Create new token from search → type appears in TokenCard
- [ ] Create new token from search → type appears in ExpandedTokenScreen
- [ ] Create custom token with type field → type appears in TokenCard
- [ ] Create custom token without type (leave empty) → no type shown
- [ ] Edit type in ExpandedTokenScreen → saves and persists
- [ ] Type displays with italic styling and reduced opacity
- [ ] Type doesn't appear if empty string (no visual gap)
- [ ] cleanType properly removes "Token" suffix
- [ ] Existing tokens still load without errors (migration successful)
- [ ] Save deck with tokens → type preserved in saved deck
- [ ] Load deck → tokens have correct type information

### Success Criteria
After implementation:
- ✅ Item model has `type` field (HiveField 12)
- ✅ TokenTemplate model has `type` field (HiveField 5)
- ✅ TokenDefinition → Item conversion preserves type
- ✅ TokenTemplate ↔ Item conversions preserve type
- ✅ NewTokenSheet includes type input field
- ✅ TokenCard displays type between name and abilities
- ✅ ExpandedTokenScreen displays and allows editing type
- ✅ Type styling matches Magic card conventions (italic, de-emphasized)
- ✅ Existing tokens load without errors
- ✅ New tokens created from search include type information
- ✅ Custom tokens created manually can include type information
- ✅ Saved decks preserve type information when loaded

---

## Feature 2: Handling for Large P/T Values

### Overview
Implement proper display handling for power/toughness values that exceed 7 characters to prevent overlap with action buttons in the token card list view.

### Problem Statement

The P/T display shares a horizontal row with action buttons (add/remove/tap/untap/copy). When P/T strings become too long, they overlap with buttons, making both the P/T value and the buttons difficult to read and interact with.

**Current Layout:**
```
[Buttons: - + ↑ → copy]              [3/3]       ← Normal (works fine)
[Buttons: - + ↑ → copy]    [*/*+1 (+5/+5)]       ← Overlap (broken)
[Buttons: - + ↑ → copy]          [1003/1003]     ← Overlap (broken)
```

### Problem Cases

#### Case 1: Non-Standard P/T with Counters
**Example:** `*/*+1` with 5 +1/+1 counters
- **Current display:** `*/*+1 (+5/+5)` (14 characters)
- **Problem:** The notation for showing both base and modified P/T is too verbose
- **Frequency:** Uncommon but valid (tokens like "Fractal" or "Construct")

#### Case 2: Extreme Counter Values
**Example:** `3/3` with 1000 +1/+1 counters
- **Current display:** `1003/1003` (9 characters)
- **Problem:** Players adding hundreds or thousands of counters (e.g., infinite combo scenarios)
- **Frequency:** Rare but legitimate gameplay (combo decks, casual/Commander formats)

#### Case 3: Edge Cases
**Examples:**
- `*/1+*` with counters → `*/1+* (+10/+10)` (17 characters)
- `X/X` with 9999 counters → `9999/9999` (9 characters)
- `100/100` with 900 counters → `1000/1000` (9 characters)

### Proposed Solutions

#### Option 1: Dynamic Text Scaling
**Approach:** Reduce font size when P/T exceeds threshold length.

**Implementation:**
- Measure P/T string length
- Scale font from `headlineMedium` down to `bodyMedium` or smaller
- Maintain minimum readable size (don't go below ~14sp)

**Pros:**
- Always fits in available space
- No layout changes needed
- Simple to implement

**Cons:**
- Inconsistent text sizes across cards look unprofessional
- Very small text at extreme values (1000+ digits) becomes unreadable
- Doesn't follow Material Design typography guidelines

**Verdict:** ⚠️ Quick fix but poor UX at scale

---

#### Option 2: Two-Line Display for Long Values
**Approach:** Stack P/T on a second line when it exceeds threshold.

**Implementation:**
- Detect P/T length > 7 characters
- Move P/T to its own line below buttons
- Keep buttons bottom-aligned to maintain layout consistency

**Example:**
```
[Buttons: - + ↑ → copy]
                    [1003/1003]    ← Bottom-aligned

[Buttons: - + ↑ → copy]
                [*/*+1 (+5/+5)]    ← Bottom-aligned
```

**Pros:**
- Maintains consistent font size
- Clear visual separation
- Simple conditional logic

**Cons:**
- Cards with long P/T become taller (inconsistent card heights in list)
- More vertical space consumed

**Verdict:** ✅ Clean, readable, follows original design intent

---

#### Option 3: Abbreviated Number Notation
**Approach:** Use K/M/B notation for large numbers (1K, 1M, 1B).

**Implementation:**
- Format numbers ≥1000 as "1K", ≥1,000,000 as "1M", etc.
- Example: `1003/1003` → `1K/1K`
- Example: `9999/9999` → `10K/10K` (rounded)

**Pros:**
- Extremely compact representation
- Common in gaming UIs (MTG Arena uses this)
- Maintains single-line layout

**Cons:**
- Loss of precision (shows ~1K instead of exact 1003)
- Requires tap-to-expand for exact values
- Doesn't help with non-numeric P/T like `*/*+1 (+5/+5)`

**Verdict:** ⚠️ Good for extreme numbers, doesn't solve all cases

---

#### Option 4: Truncate with Ellipsis + Tap to Expand
**Approach:** Truncate P/T at 7 characters with "..." and make it tappable.

**Implementation:**
- Show first 7 chars + "..." (e.g., `1003/10...`)
- Tap P/T to show full value in a dialog/tooltip
- Visual indicator (subtle icon or different text color) that it's tappable

**Pros:**
- Consistent layout, no size changes
- Full precision available on demand
- Works for all cases (numbers and non-standard)

**Cons:**
- Hidden information (user doesn't see full value at a glance)
- Requires extra interaction
- Not discoverable without visual cue

**Verdict:** ⚠️ Power-user friendly but hides critical gameplay info

---

#### Option 5: Compact Counter Notation
**Approach:** Simplify how counters are displayed for non-standard P/T.

**Current:** `*/*+1 (+5/+5)` (14 chars)
**Proposed:** `*/*+1 +5` (8 chars) - show only the counter delta, not full notation

**Alternative compact formats:**
- `*/*+1⁺⁵` - use superscript (7 chars)
- `*/*+1 [+5]` - brackets (11 chars)
- `*/*+1 ↑5` - arrow indicator (9 chars)

**Pros:**
- Solves Case 1 (non-standard P/T with counters)
- Maintains readability
- Single line layout

**Cons:**
- Doesn't solve Case 2 (extreme numbers)
- Less explicit about what the modifier represents
- May confuse new users

**Verdict:** ✅ Good complement to other solutions for Case 1

---

#### Option 6: Move P/T Above Button Row
**Approach:** Reflow layout to put P/T on its own line above buttons.

**Implementation:**
```
                        [1003/1003]    ← Always on top
[Buttons: - + ↑ → copy]               ← Always on bottom
```

**Pros:**
- Always sufficient space for P/T
- Consistent layout (P/T always in same position)
- No conditional logic needed

**Cons:**
- Breaks current design pattern (P/T traditionally on right)
- All cards become taller
- Changes visual hierarchy

**Verdict:** ⚠️ Solves the problem but major layout change

---

#### Option 7: Adaptive Button Layout
**Approach:** Wrap buttons to a second row when P/T is large.

**Implementation:**
```
Normal:
[Buttons: - + ↑ → copy]              [3/3]

Large P/T:
[Buttons: - + ↑]         [*/*+1 (+5/+5)]
[Buttons: → copy]
```

**Pros:**
- P/T stays on right (consistent with design)
- Buttons remain accessible
- Flexible layout

**Cons:**
- Complex layout logic
- Button positions change (UX inconsistency)
- Cards become taller anyway

**Verdict:** ⚠️ Over-engineered, confusing button reflow

---

#### Option 8: Tap-to-Reveal Full P/T Badge
**Approach:** Show abbreviated P/T with tap gesture to reveal full value in overlay.

**Implementation:**
- Display `1003...` in badge/pill
- Tap P/T area to show floating overlay with full value: `1003/1003`
- Overlay auto-dismisses after 2 seconds or on tap elsewhere

**Pros:**
- Elegant, minimal UI impact
- Full precision available
- Works for all edge cases

**Cons:**
- Critical info hidden behind interaction
- Not accessible without tap
- May frustrate users who want to see exact values

**Verdict:** ⚠️ Good for extreme edge cases but hides important data

---

#### Option 9: Hybrid Approach - Abbreviated with Tooltip
**Approach:** Show abbreviated values but with instant visual feedback.

**Implementation:**
- Display `1K/1K` for large numbers
- Long-press P/T shows tooltip with exact value: `1003/1003`
- Tooltip appears immediately on long-press (no navigation)

**Pros:**
- Clean single-line display
- Exact values available without dialog
- Familiar pattern (long-press for more info)

**Cons:**
- Still hides precision by default
- Long-press not universally discoverable
- Doesn't help with `*/*+1 (+5/+5)` case

**Verdict:** ✅ Best balance for Case 2 (extreme numbers)

---

#### Option 10: Maximum P/T Cap with Warning
**Approach:** Enforce maximum displayable P/T and warn users.

**Implementation:**
- Cap display at reasonable limit (e.g., 9999/9999)
- Show `9999+/9999+` for values exceeding cap
- Add visual indicator (icon, color) that value is capped
- Tap to see exact value in details view

**Pros:**
- Prevents extreme display issues
- Simple implementation
- Educates users about practical limits

**Cons:**
- Arbitrary limitation on valid gameplay
- May frustrate combo players
- Doesn't solve non-standard P/T case

**Verdict:** ❌ Too restrictive, doesn't respect valid gameplay

---

### Recommended Combination

**Tiered approach based on P/T type and length:**

#### Tier 1: Standard P/T (numeric, no counters)
- Length ≤7 chars → Display normally: `3/3`
- Length 8-9 chars → Display normally: `1003/1003`
- Length ≥10 chars → Abbreviate with K/M notation: `10K/10K`
  - Long-press shows tooltip with exact value

#### Tier 2: Modified P/T (numeric with counters)
- Calculable (e.g., `3/3` → `8/8`) → Use highlighted background (current)
- Length ≤7 chars → Display normally: `8/8`
- Length ≥8 chars → Abbreviate: `10K/10K`
  - Long-press shows breakdown: "Base: 3/3, Counters: +9997/+9997"

#### Tier 3: Non-Standard P/T (contains `*`, `X`, etc.)
- No counters → Display normally: `*/*+1`
- With counters → Use compact notation: `*/*+1 +5` (instead of `*/*+1 (+5/+5)`)
  - If still >7 chars → Two-line display (fallback)

### Implementation Checklist

- [ ] Add P/T length detection utility function
- [ ] Implement K/M/B number formatting helper
- [ ] Create compact counter notation for non-standard P/T
- [ ] Add long-press tooltip handler for P/T element
- [ ] Update `formattedPowerToughness` getter to include length checks
- [ ] Add unit tests for edge cases (extreme numbers, non-standard formats)
- [ ] Visual testing with real tokens in various scenarios

### Test Cases

**Standard P/T:**
- `3/3` → `3/3` (no change)
- `99/99` → `99/99` (no change)
- `1003/1003` → `1K/1K` (long-press shows `1003/1003`)
- `10000/10000` → `10K/10K` (long-press shows `10000/10000`)
- `1000000/1000000` → `1M/1M` (long-press shows `1000000/1000000`)

**Modified P/T:**
- `3/3` + 5 counters → `8/8` (highlighted, current behavior)
- `3/3` + 1000 counters → `1K/1K` (highlighted, abbreviated)
- `100/100` + 900 counters → `1K/1K` (highlighted, abbreviated)

**Non-Standard P/T:**
- `*/*` → `*/*` (no change)
- `*/*+1` → `*/*+1` (no change)
- `*/*+1` + 5 counters → `*/*+1 +5` (compact notation)
- `X/X` + 10 counters → `X/X +10` (compact notation)
- `*/1+*` + 100 counters → Two-line display (fallback if compact still >7 chars)

### Success Criteria

After implementation:
- ✅ No P/T overlaps with buttons in any scenario
- ✅ All P/T values ≤7 characters display unchanged
- ✅ Extreme values (1000+) use K/M notation
- ✅ Non-standard P/T with counters use compact notation
- ✅ Long-press tooltip shows exact values for abbreviated numbers
- ✅ Visual consistency maintained across token cards
- ✅ Layout doesn't break with any valid P/T combination

---

## Completed Features

- Token List Reordering
- WCAG Accessibility Fixes
