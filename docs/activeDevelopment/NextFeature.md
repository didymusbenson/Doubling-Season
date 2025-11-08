# Next Feature

## Feature 1: Display Token Types

### Overview
Add token type display to both list view (TokenCard) and detail view (ExpandedTokenScreen). Types should appear under the name and above abilities, matching the layout of physical Magic cards.

### Current Problem
Token types (e.g., "Creature — Elf Warrior", "Artifact", "Emblem") are completely missing from the UI:
- **Source data** contains incorrect type strings like "Token Creature — Goblin" (should be "Creature — Goblin")
- **TokenDefinition** (database model) has `type` field but needs data to be cleaned first
- **Item** (active token model) does NOT have a `type` field
- **TokenTemplate** (deck save/load model) does NOT have a `type` field
- When converting TokenDefinition → Item via `toItem()`, the type information is lost
- NewTokenSheet (custom token creation) has no type input field
- Neither TokenCard nor ExpandedTokenScreen display type information

### Required Changes

**Summary:** 7 files need updates to support type display
1. `docs/housekeeping/process_tokens_with_popularity.py` - Strip "Token" prefix from types
2. `lib/models/item.dart` - Add HiveField 12 for type
3. `lib/models/token_template.dart` - Add HiveField 5 for type
4. `lib/models/token_definition.dart` - Pass type in toItem()
5. `lib/widgets/new_token_sheet.dart` - Add type input field
6. `lib/widgets/token_card.dart` - Display type in list view
7. `lib/screens/expanded_token_screen.dart` - Display and edit type

#### 0. Update Token Database Processing Script (FIRST)
**File:** `docs/housekeeping/process_tokens_with_popularity.py`

**Problem:** The source XML data from GitHub contains type strings like "Token Creature — Goblin", "Token Artifact", etc. The word "Token" is not actually a Magic card type and should be stripped during processing.

**Current behavior (lines 109-115):** Script adds "Token " prefix
**Required behavior:** Strip "Token " prefix from types

Update the `clean_token_data()` function:
```python
# Clean type - remove "Token" prefix since it's not a real Magic type
type_text = token['type']
# Remove "Token " prefix (case-insensitive, handles "Token Creature", "Token Artifact", etc.)
type_text = re.sub(r'^Token\s+', '', type_text, flags=re.IGNORECASE)
type_text = type_text.strip()
```

**Examples of transformation:**
- `"Token Creature — Goblin"` → `"Creature — Goblin"`
- `"Token Artifact"` → `"Artifact"`
- `"Token Enchantment"` → `"Enchantment"`
- `"Emblem"` → `"Emblem"` (no "Token" prefix to remove)

**IMPORTANT:** Run this script BEFORE implementing the UI changes to regenerate `assets/token_database.json` with properly cleaned type strings.

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
1. **Update Python script** - Modify `process_tokens_with_popularity.py` to strip "Token" prefix from types
2. **Regenerate token database** - Run the script to update `assets/token_database.json`
3. Add `type` field to Item model (HiveField 12)
4. Add `type` field to TokenTemplate model (HiveField 5)
5. Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate Hive adapters
6. Update `TokenDefinition.toItem()` to pass type
7. Update `TokenTemplate.fromItem()` to pass type
8. Update `TokenTemplate.toItem()` to pass type
9. Add `cleanType` getter to Item model (if needed - may not be necessary since script already cleans)
10. Update NewTokenSheet to include type input field
11. Update TokenCard to display type
12. Update ExpandedTokenScreen to display and edit type
13. Test with existing tokens (should show empty type initially)
14. Test with new tokens created from search (should show proper type like "Creature — Goblin", not "Token Creature — Goblin")
15. Test with custom tokens created manually (should accept and display type)
16. Test deck save/load (should preserve type information)

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

## Other Features Under Consideration

### Power/Toughness Display Handling
**Status:** Design phase - see `PtHandlingFeature.md`

Long P/T values (e.g., `*/*+1 (+5/+5)`, `1003/1003`) currently overlap with action buttons. Multiple solutions are being evaluated including:
- K/M notation for large numbers
- Compact counter notation for non-standard P/T
- Two-line display fallback
- Long-press tooltips for exact values

See the dedicated feature document for full analysis of 10 proposed solutions.

---

## Completed Features

- Token List Reordering
- WCAG Accessibility Fixes
