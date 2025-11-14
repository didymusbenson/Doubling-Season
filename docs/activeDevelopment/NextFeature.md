## Bug: Artwork Does Not Auto-Assign for New Tokens

**Location:** `lib/models/token_definition.dart:67-78` (in `toItem()` method)

**Expected Behavior:** When creating a new token from the token database, the first artwork option (index 0) should automatically be assigned to the token.

**Actual Behavior:** Newly created tokens initialize with `artworkUrl: null` and `artworkSet: null`, showing the empty artwork state.

**Root Cause:**
The `TokenDefinition.toItem()` method creates new `Item` objects but doesn't pass artwork data:

```dart
Item toItem({required int amount, required bool createTapped}) {
  return Item(
    name: name,
    pt: pt,
    abilities: abilities,
    colors: colors,
    type: type,
    amount: amount,
    tapped: createTapped ? amount : 0,
    summoningSick: amount,
    // MISSING: artworkUrl and artworkSet not set
  );
}
```

**Data Flow:**
1. User selects token in `TokenSearchScreen`
2. `token.toItem()` called at `token_search_screen.dart:740`
3. Item created without artwork fields
4. `tokenProvider.insertItem(item)` saves to database
5. Token appears with empty artwork state

**Fix:**
Modify `toItem()` to auto-assign first artwork variant if available:

```dart
Item toItem({required int amount, required bool createTapped}) {
  // Auto-assign first artwork if available
  final firstArtwork = artwork.isNotEmpty ? artwork[0] : null;

  return Item(
    name: name,
    pt: pt,
    abilities: abilities,
    colors: colors,
    type: type,
    amount: amount,
    tapped: createTapped ? amount : 0,
    summoningSick: amount,
    artworkUrl: firstArtwork?.url,      // ADD THIS
    artworkSet: firstArtwork?.set,      // ADD THIS
  );
}
```

**Additional Consideration:**
The fix should also trigger artwork download/caching when the item is created, similar to how `ExpandedTokenScreen._handleArtworkSelected()` uses `ArtworkManager.downloadArtwork()`. Otherwise the artwork URL will be set but the image won't be cached locally until the user opens the token details.

**Alternative Approach:**
Instead of modifying `toItem()`, handle this in `TokenSearchScreen._showQuantityDialog()` after creating the item but before inserting it:

```dart
final item = token.toItem(
  amount: finalAmount,
  createTapped: _createTapped,
);

// Auto-assign first artwork if available
if (token.artwork.isNotEmpty) {
  final firstArtwork = token.artwork[0];
  item.artworkUrl = firstArtwork.url;
  item.artworkSet = firstArtwork.set;
  // Optionally trigger download: await ArtworkManager.downloadArtwork(firstArtwork.url);
}

await tokenProvider.insertItem(item);
```

**Impact:** Medium priority - tokens function correctly but missing expected visual enhancement on creation.

## Bug: Artwork Selection Shows Wrong Color Variants

**Location:** `lib/screens/expanded_token_screen.dart:71-102` (in `_loadTokenDefinition()`)

**Issue:** When selecting artwork for a token, the app shows artwork from ALL tokens with matching name/P/T/abilities/type, regardless of color identity.

**Example:**
- Creating a 4/4 white/blue (UW) Elemental
- Artwork selection shows art from the 4/4 green (G) Elemental (UMA, MMA, LRW sets)
- Should only show WOE set artwork for UW variant

**Root Cause:**
Token matching logic at lines 77-82 compares:
- Name ✅
- P/T ✅
- Abilities ✅
- Type ✅
- Colors ❌ **MISSING**

**Fix:**
Add color identity to the comparison:
```dart
final matchingToken = database.allTokens.firstWhere(
  (token) =>
      token.name == widget.item.name &&
      token.pt == widget.item.pt &&
      token.abilities == widget.item.abilities &&
      token.type == widget.item.type &&
      token.colors == widget.item.colors,  // ADD THIS LINE
  orElse: () => TokenDefinition(...)
);
```

**Impact:** Low priority - doesn't break functionality, just shows confusing artwork options for tokens with same stats but different colors.

## Feature: Store Artwork Options on Item (Hybrid Solution)

**Problem:** When a user edits a token (e.g., changing abilities text on a 1/1 green Elf Warrior), the artwork options disappear. The current architecture does a reverse lookup against the token database by matching name/P/T/abilities/type. When abilities change, the match fails, and the token loses access to artwork variants even though it keeps its currently selected artwork.

**Current Architecture:**
- `Item` stores only `artworkUrl` (currently selected) and `artworkSet`
- `ExpandedTokenScreen._loadTokenDefinition()` does O(n) database search to find artwork options
- Search compares: name, P/T, abilities, type (and colors once Bug #2 is fixed)
- If no match → empty artwork array → user can't select alternate artwork

**Proposed Solution: Hybrid Approach**

Store the full artwork options array on `Item` at creation time, with database lookup as fallback for legacy/custom tokens.

**Implementation:**

1. **Add field to Item model** (`lib/models/item.dart`):
```dart
@HiveField(15)
List<ArtworkVariant>? artworkOptions;
```

2. **Add field to TokenTemplate** (`lib/models/token_template.dart`):
```dart
@HiveField(6)
List<ArtworkVariant>? artworkOptions;
```

3. **Populate on creation** (`lib/models/token_definition.dart`):
```dart
Item toItem({required int amount, required bool createTapped}) {
  final firstArtwork = artwork.isNotEmpty ? artwork[0] : null;

  return Item(
    name: name,
    pt: pt,
    abilities: abilities,
    colors: colors,
    type: type,
    amount: amount,
    tapped: createTapped ? amount : 0,
    summoningSick: amount,
    artworkUrl: firstArtwork?.url,
    artworkSet: firstArtwork?.set,
    artworkOptions: List.from(artwork),  // ADD THIS
  );
}
```

4. **Lazy migration in ExpandedTokenScreen** (`lib/screens/expanded_token_screen.dart`):
```dart
Future<void> _loadTokenDefinition() async {
  // If already has artwork options, use them (edited tokens!)
  if (widget.item.artworkOptions != null && widget.item.artworkOptions!.isNotEmpty) {
    setState(() {
      _tokenDefinition = TokenDefinition(
        name: widget.item.name,
        abilities: widget.item.abilities,
        pt: widget.item.pt,
        colors: widget.item.colors,
        type: widget.item.type,
        popularity: 0,
        artwork: widget.item.artworkOptions!,
      );
    });
    return;
  }

  // Otherwise, do database lookup (legacy tokens or custom tokens)
  final database = TokenDatabase();
  await database.loadTokens();

  final matchingToken = database.allTokens.firstWhere(
    (token) =>
        token.name == widget.item.name &&
        token.pt == widget.item.pt &&
        token.abilities == widget.item.abilities &&
        token.type == widget.item.type &&
        token.colors == widget.item.colors,  // Include colors!
    orElse: () => TokenDefinition(
      name: widget.item.name,
      abilities: widget.item.abilities,
      pt: widget.item.pt,
      colors: widget.item.colors,
      type: widget.item.type,
      popularity: 0,
      artwork: [],
    ),
  );

  // Save artwork options for next time (migrate legacy token)
  if (matchingToken.artwork.isNotEmpty) {
    widget.item.artworkOptions = List.from(matchingToken.artwork);
    await widget.item.save();
  }

  setState(() {
    _tokenDefinition = matchingToken;
  });
}
```

5. **Update TokenTemplate.fromItem()** (`lib/models/token_template.dart`):
```dart
factory TokenTemplate.fromItem(Item item) {
  return TokenTemplate(
    name: item.name,
    pt: item.pt,
    abilities: item.abilities,
    colors: item.colors,
    artworkUrl: item.artworkUrl,
    artworkSet: item.artworkSet,
    artworkOptions: item.artworkOptions != null
        ? List.from(item.artworkOptions!)
        : null,  // ADD THIS
  );
}
```

6. **Update TokenTemplate.toItem()** (`lib/models/token_template.dart`):
```dart
Item toItem({required int amount, required bool createTapped}) {
  return Item(
    name: name,
    pt: pt,
    abilities: abilities,
    colors: colors,
    amount: amount,
    tapped: createTapped ? amount : 0,
    summoningSick: 0,
    order: 0.0,
    artworkUrl: artworkUrl,
    artworkSet: artworkSet,
    artworkOptions: artworkOptions != null
        ? List.from(artworkOptions!)
        : null,  // ADD THIS
  );
}
```

**Migration Strategy:**

**No upfront migration needed!** The lazy migration approach:
- Existing tokens have `artworkOptions: null`
- First time user opens token details, it does database lookup (current behavior)
- If lookup succeeds, saves artwork options for future
- If user edits token, artwork options persist because they're now stored on the item
- Zero user-facing delays or breaking changes

**Benefits:**
- ✅ Edited tokens keep artwork options (solves the problem!)
- ✅ Performance improvement (O(1) access vs O(n) database search)
- ✅ Works offline without token database
- ✅ Zero-downtime migration (lazy loading)
- ✅ Backward compatible (nullable field + fallback)
- ✅ Allows custom tokens to have manually assigned artwork

**Storage Impact:**
- ~1KB per token (10-15 artwork variants × ~100 chars per URL)
- 50 tokens = ~50KB additional storage
- Negligible on modern devices

**Hive Schema Version:**
- Item: v2 (adds field 15)
- TokenTemplate: v2 (adds field 6)
- Migration: Lazy (on-demand in ExpandedTokenScreen)
- Backward compatible: null values handled gracefully

**Testing Checklist:**
1. Install current version, create decks with tokens and artwork
2. Install new version with Field 15
3. Verify existing tokens still display
4. Verify artwork still shows
5. Verify decks still load
6. Open token details → verify artworkOptions populated
7. Edit token abilities → verify artwork options persist
8. Create new token → verify artworkOptions populated at creation

**Impact:** High priority - significantly improves UX for edited tokens and future-proofs artwork system.

## Bug: Modified P/T and Counter Pills Need Higher Opacity

**Location:** `lib/widgets/token_card.dart` (modified P/T background and counter pill backgrounds)

**Issue:** Before artwork was implemented, modified P/T backgrounds and counter pills used lower opacity values. Now that tokens can have artwork, these elements need higher opacity (0.85 alpha) to remain readable when artwork is displayed behind them.

**Affected Elements:**
1. **Modified P/T Display** - The colored background shown when a token has +1/+1 or -1/-1 counters
2. **Counter Pills** - Custom counter badges displayed on TokenCard in list view

**Current Behavior:**
- Modified P/T and counter pills may have insufficient contrast when token artwork is visible
- Text can be difficult to read against certain artwork backgrounds

**Expected Behavior:**
- Modified P/T background should use 0.85 opacity (matching other text backgrounds over artwork)
- Counter pills should use 0.85 opacity (matching other UI elements over artwork)

**Fix:**
Update opacity values in `token_card.dart` to match the 0.85 alpha used for other text backgrounds (like the semi-transparent `cardColor` backgrounds used throughout the card).

**Impact:** Medium priority - affects readability when artwork is present, but tokens are still functional.

## Bug: Token Copies Do Not Copy Type Field

**Location:** Token copy functionality (likely in `lib/providers/token_provider.dart` or `lib/widgets/token_card.dart`)

**Issue:** When copying a token card, the newly created token does not contain type information. Split operations correctly preserve the type field.

**Expected Behavior:** Copied tokens should preserve all properties including the `type` field (Creature, Artifact, Enchantment, Emblem, etc.)

**Actual Behavior:**
- Copying a token creates a new Item without the `type` field
- Splitting a token stack correctly preserves the `type` field

**Platform:** Confirmed on both Android and iOS

**Impact:** Medium priority - tokens function correctly but lose type metadata when copied

## Bug: iPhone Splash Screen Text Overflow on Large Devices

**Location:** `lib/screens/splash_screen.dart`

**Issue:** The splash screen text "zombies&" wraps to a second line on iPhone 16 and iPhone 16 Pro Max simulators.

**Expected Behavior:** All five color labels (angels&, merfolk&, zombies&, goblins&, elves&) should remain on a single line within their respective color bars.

**Actual Behavior:**
- On iPhone 16 and 16 Pro Max simulators: "zombies&" overflows to second line
- On iPhone X: No overflow observed (works correctly)

**Root Cause:** Font sizing or margin/padding handling doesn't properly account for the available width on larger iPhone displays.

**Fix Options:**
1. Reduce overall font size slightly
2. Improve automatic sizing to better handle margins/padding constraints
3. Adjust horizontal padding to give more space for text

**Note:** This issue appears only in simulators for newer/larger iPhones. Physical device testing on iPhone X shows no overflow.

**Impact:** Low priority - cosmetic issue on specific device sizes, doesn't affect functionality

