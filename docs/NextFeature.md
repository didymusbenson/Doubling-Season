# Next Feature: Search Feature Overhaul

## Overview
Complete redesign of the token search system with improved relevance, filtering, and data quality. This feature includes both backend (data processing) and frontend (UI/UX) improvements.

---

## Prerequisites (Must Complete Before Implementation)

### 1. Popularity Analysis & Bracket Definition ✅ COMPLETED
**Goal:** Analyze the distribution of `<reverse-related>` counts across all tokens and define popularity brackets.

**Analysis Results:**
- **Total tokens:** 911
- **Popularity range:** 0 to 316
- **Mean popularity:** 5.18
- **Median popularity:** 1 (highly skewed distribution)
- **Top token:** Treasure (popularity: 316)

**Distribution characteristics:**
- Top 10% of tokens: popularity ≥ 10 (~91 tokens)
- Highly skewed: 64% of tokens have popularity ≤ 1
- Top 20 tokens account for majority of actual card references

**Final Bracket Definitions:**
```
Bracket 1: popularity >= 10   (~90 tokens)   - Ultra popular tokens
Bracket 2: popularity 3-9      (~140 tokens)  - Popular tokens
Bracket 3: popularity 2        (~120 tokens)  - Common tokens
Bracket 4: popularity 0-1      (~560 tokens)  - Rare/niche tokens
```

**Top 20 Most Popular Tokens:**
1. Treasure (316)
2. Morph 2/2 (183)
3. Clue (137)
4. Energy Reserve (133)
5. Poison Counter (128)
6. Food (126)
7. On an Adventure (110)
8. Zombie 2/2 (102)
9. Saproling 1/1 (85)
10. Soldier 1/1 (72)
11. Spirit 1/1 (72)
12. Goblin 1/1 (57)
13. Foretell (56)
14. Manifest 2/2 (54)
15. A Mysterious Creature 2/2 (52)
16. The Monarch (50)
17. The Ring (49)
18. Thopter 1/1 (49)
19. CRANK! (46)
20. Human Soldier 1/1 (41)

---

## Backend Changes

### 1. Python Parser Updates (`AI STUFF/process_tokens.py`)

#### A. Add Popularity Field
- Count `<reverse-related>` tags per token
- Add `"popularity"` field to JSON output
- Example output:
  ```json
  {
    "name": "Adorned Pouncer (Token)",
    "abilities": "Double strike",
    "pt": "4/4",
    "colors": "B",
    "type": "Token Creature  Zombie Cat",
    "popularity": 1
  }
  ```

#### B. Deduplication Logic Update
**Current dedup key:**
```python
f"{name}|{pt}|{colors}|{type}|{abilities}"
```

**Updated deduplication behavior:**
- When duplicates are found, **sum their popularity scores**
- BUT only count unique `<reverse-related>` card names (avoid double-counting)
- Keep only one entry per unique token

**Algorithm:**
```python
# For each unique token (by dedup key):
# 1. Collect all <reverse-related> card names across all instances
# 2. Deduplicate the card names (use Set)
# 3. popularity = len(deduplicated_card_names)
```

**Example:**
```
Token A appears in 2 sets:
  Set 1: <reverse-related>Goblin Guide</reverse-related>
         <reverse-related>Legion Loyalist</reverse-related>
  Set 2: <reverse-related>Goblin Guide</reverse-related>
         <reverse-related>Krenko, Mob Boss</reverse-related>

Unique reverse-related cards: {Goblin Guide, Legion Loyalist, Krenko, Mob Boss}
Final popularity: 3 (not 4)
```

**Note:** This script may take longer to execute due to set operations, but it's a one-time manual job per set release.

### 2. TokenDefinition Model Updates (`lib/models/token_definition.dart`)

Add `popularity` field:
```dart
class TokenDefinition {
  final String name;
  final String abilities;
  final String pt;
  final String colors;
  final String type;
  final int popularity; // NEW FIELD

  TokenDefinition({
    required this.name,
    required this.abilities,
    required this.pt,
    required this.colors,
    required this.type,
    required this.popularity,
  });

  factory TokenDefinition.fromJson(Map<String, dynamic> json) {
    return TokenDefinition(
      name: json['name'] as String,
      abilities: json['abilities'] as String,
      pt: json['pt'] as String,
      colors: json['colors'] as String,
      type: json['type'] as String,
      popularity: json['popularity'] as int? ?? 0, // Default to 0 for backwards compat
    );
  }
}
```

### 3. TokenDatabase Sorting (`lib/database/token_database.dart`)

Update `filteredTokens` getter to sort by popularity brackets, then alphabetically:
```dart
List<TokenDefinition> get filteredTokens {
  final filtered = _allTokens.where((token) {
    // Apply filters...
  }).toList();

  // Sort: popularity DESC (highest first), then name ASC (alphabetical)
  // This automatically creates bracket-based sorting:
  //   Bracket 1 (≥10) appears first
  //   Bracket 2 (3-9) appears second
  //   Bracket 3 (2) appears third
  //   Bracket 4 (0-1) appears last
  filtered.sort((a, b) {
    // Higher popularity first
    final popularityCompare = b.popularity.compareTo(a.popularity);
    if (popularityCompare != 0) return popularityCompare;

    // Same popularity: alphabetical
    return a.name.compareTo(b.name);
  });

  return filtered;
}
```

**Note:** Popularity sorting ONLY applies to "All" tab, not "Recent" or "Favorites" tabs.

**Bracket Implementation:**
No need to explicitly check brackets in code. Simple `popularity DESC` sorting automatically groups tokens by bracket since:
- All tokens with popularity ≥10 sort before popularity 9
- All tokens with popularity 3-9 sort before popularity 2
- All tokens with popularity 2 sort before popularity 0-1

---

## Frontend Changes

### 1. Color Filtering System

#### A. UI Component: Color Filter Toggle Buttons
**Design:**
- 6 toggle buttons in a row: **W, U, B, R, G, C** (C = Colorless)
- Visual style: Similar to `ColorSelectionButton` in `expanded_token_screen.dart`
- Each button shows:
  - Letter label (W/U/B/R/G/C)
  - Color-coded background when selected
  - Multi-select enabled (can select any combination)

**Color Mapping:**
- W (White) = Yellow/cream background
- U (Blue) = Blue background
- B (Black) = Purple background
- R (Red) = Red background
- G (Green) = Green background
- C (Colorless) = Grey background

**Component Implementation:**
- Create new color filter button component specifically for search screen
- Do NOT abstract/reuse `ColorSelectionButton` from expanded token screen
- Reason: Adding colorless (C) button adds complexity that doesn't belong in the token editor

#### B. Filtering Logic: Exact Color Match
**Behavior:**
- No selection = show all colors (including colorless)
- Select **W only** = show only mono-white tokens
- Select **W + U** = show only white-blue (Azorius) tokens
- Select **W + U + B** = show only white-blue-black (Esper) tokens
- Select **C only** = show only colorless tokens
- **Exact match required** - token colors must match selected colors exactly

**State Management:**
Store selected colors in `TokenDatabase` as instance variable (similar to `selectedCategory`):
```dart
class TokenDatabase extends ChangeNotifier {
  Set<String> _selectedColors = {};

  Set<String> get selectedColors => _selectedColors;
  set selectedColors(Set<String> value) {
    _selectedColors = value;
    notifyListeners();
  }
}
```

**Filtering Implementation:**
```dart
bool matchesColorFilter(TokenDefinition token, Set<String> selectedColors) {
  if (selectedColors.isEmpty) return true; // No filter = show all

  // Handle colorless filter (C selected)
  if (selectedColors.contains('C')) {
    return token.colors.isEmpty;
  }

  // Exact color match for WUBRG
  final tokenColors = token.colors.split('').toSet();
  return tokenColors.length == selectedColors.length &&
         tokenColors.containsAll(selectedColors);
}
```

#### C. UI Placement
- Display color filter buttons horizontally below the search bar
- Above the category filter chips (Creature/Artifact/Emblem)
- Always visible in "All" tab (hidden in Recent/Favorites tabs if they don't need it)

### 2. Category Filter Simplification

**Current categories:** Creature, Artifact, Enchantment, Emblem, Dungeon, Counter, Other

**New categories:** Creature, Artifact, Emblem only

**Excluded Types (Not Shown in Search):**
The following token types are excluded from all search results as they are not traditional gameplay tokens:
- **Counter** (6 tokens): Energy Reserve, Poison Counter, Radiation, Experience Counter, Ticket Bucket-Bot, Acorn Stash
- **State** (12 tokens): The Monarch, The Ring, On an Adventure, etc.
- **Bounty** (12 tokens): Outlaw bounty mechanic tokens
- **Dungeon** (4 tokens): Dungeon cards

These types should be filtered out in the token loading/parsing logic, reducing the searchable token pool from 911 to ~877 tokens.

**Implementation Note:** Filter these types in the Python script's `clean_token_data()` function before writing to JSON. This prevents them from being included in the token database at all, rather than filtering at runtime in Dart.

**Behavior:**
- Multi-select enabled (can select multiple categories simultaneously)
- Works alongside color filters (both can be active)
- Maintain current horizontal scrolling chip UI
- Selection state persists during search session

**Category Matching Logic:**
Use existing `token_models.Category` enum and matching logic. Update the category identification to handle these types:
- **Creature category:** Matches "Creature", "Artifact Creature", "Enchantment Creature", "Legendary Creature"
- **Artifact category:** Matches "Artifact", "Artifact Creature", "Legendary Artifact", "Snow Artifact"
- **Emblem category:** Matches "Emblem" only

**Multi-Select UI Implementation:**
Use existing Material Design `FilterChip` widget with `selected` property (same as current implementation). No custom styling needed - Material Design handles selected state automatically.

### 3. Recent Feature Bug Fix

**Current Issue:**
- `TokenDatabase` maintains in-memory `recentTokens` list that never persists
- `SettingsProvider` has proper persistence logic but `TokenDatabase` doesn't use it
- Result: Recent tokens lost on app restart or new TokenDatabase instance

**Root Cause:**
```dart
// TokenDatabase (WRONG - in-memory only)
List<TokenDefinition> recentTokens = []; // Line 74

// SettingsProvider (CORRECT - persisted)
List<String> get recentTokens => _prefs.getStringList(...); // Line 53
```

**Fix Strategy:**
1. TokenDatabase should delegate to SettingsProvider for persistence
2. **Pass SettingsProvider to methods that need it** (least invasive approach):
   - No constructor changes needed
   - Methods that need persistence take SettingsProvider as parameter
   - Keeps TokenDatabase decoupled from Provider system
3. Update methods:
   ```dart
   // OLD (broken)
   void addToRecent(TokenDefinition token) {
     recentTokens.remove(token);
     recentTokens.insert(0, token);
     // ...
   }

   // NEW (fixed) - pass SettingsProvider as parameter
   void addToRecent(TokenDefinition token, SettingsProvider settingsProvider) {
     settingsProvider.addRecent(token.id); // Persist to SharedPreferences
     notifyListeners(); // Trigger UI update
   }

   // Reconstruct recent tokens from IDs
   List<TokenDefinition> getRecentTokens(SettingsProvider settingsProvider) {
     final recentIds = settingsProvider.recentTokens;
     return recentIds
       .map((id) => _allTokens.firstWhere((t) => t.id == id, orElse: () => null))
       .whereType<TokenDefinition>()
       .toList();
   }
   ```

4. Same fix applies to favorites functionality:
   ```dart
   // toggleFavorite becomes:
   void toggleFavorite(TokenDefinition token, SettingsProvider settingsProvider) {
     if (settingsProvider.favoriteTokens.contains(token.id)) {
       settingsProvider.removeFavorite(token.id);
     } else {
       settingsProvider.addFavorite(token.id);
     }
     notifyListeners();
   }

   // isFavorite becomes:
   bool isFavorite(TokenDefinition token, SettingsProvider settingsProvider) {
     return settingsProvider.favoriteTokens.contains(token.id);
   }

   // getFavoriteTokens becomes:
   List<TokenDefinition> getFavoriteTokens(SettingsProvider settingsProvider) {
     final favoriteIds = settingsProvider.favoriteTokens;
     return _allTokens.where((t) => favoriteIds.contains(t.id)).toList();
   }
   ```

5. Update call sites in `token_search_screen.dart`:
   ```dart
   // OLD
   _tokenDatabase.addToRecent(token);

   // NEW - get SettingsProvider from context
   final settingsProvider = context.read<SettingsProvider>();
   _tokenDatabase.addToRecent(token, settingsProvider);
   ```

**Testing checklist:**
- [ ] Add token to recent
- [ ] Restart app - recent token still appears
- [ ] Add 21 tokens to recent - oldest drops off (max 20)
- [ ] Toggle favorite - persists across restart

### 4. Filter Interaction & Order of Operations

**Question answered:** Search text + filters interaction

**Order of operations:**
1. **Color filter** - Exact match on selected colors (if any selected)
2. **Category filter** - Match selected categories (if any selected)
3. **Popularity sort** - Sort by popularity DESC, then name ASC (All tab only)
4. **Text search** - Filter sorted results by search query
5. **Display** - Show final filtered & sorted results

**Example flow:**
```
User selects: Red (color) + Creature (category) + types "goblin"

Step 1: Filter by color = only mono-red tokens
Step 2: Filter by category = only creatures from step 1
Step 3: Sort by popularity = most popular mono-red creatures first
Step 4: Text search = only tokens containing "goblin" from step 3
Result: Shows "Goblin Token (1/1)" before "Goblin Token (2/1)" if more popular
```

---

## User Experience Goals

### Primary Objectives
1. **Improved Relevance:** Most commonly-used tokens appear first in search results
2. **Faster Discovery:** Color + category filters quickly narrow down options
3. **Handle Variants:** Color filtering solves the "12 Elemental variations" problem
4. **Persistent Recents:** Recent tokens persist across app restarts
5. **No UI Clutter:** Popularity sorting is invisible to users (just works)

### Non-Goals (Explicit Exclusions)
- Do NOT show "popularity score" in UI
- Do NOT show "bracket" indicators to users
- Do NOT explain why tokens are ordered a certain way
- Keep UI clean and simple - ranking happens behind the scenes

---

## Testing Plan

### Backend Testing
1. **Python Script:**
   - [ ] Run on full Cockatrice XML (all sets)
   - [ ] Verify popularity counts match manual inspection of sample tokens
   - [ ] Confirm deduplication sums unique reverse-related cards
   - [ ] Check output JSON contains `popularity` field for all tokens

2. **Data Validation:**
   - [ ] Verify top 10 most popular tokens match expectations (e.g., Treasure, Soldier, Clue)
   - [ ] Check distribution report makes sense (no outliers like popularity=9999)
   - [ ] Confirm bracket boundaries produce roughly equal-sized groups

### Frontend Testing
1. **Color Filtering:**
   - [ ] Select W only � shows only mono-white tokens
   - [ ] Select W+U � shows only Azorius (WU) tokens
   - [ ] Select C only � shows only colorless tokens
   - [ ] No selection � shows all tokens including colorless
   - [ ] Works with search text (e.g., "angel" + W filter)

2. **Category Filtering:**
   - [ ] Multi-select Creature + Artifact � shows both
   - [ ] Emblem filter shows only emblems
   - [ ] Works with color filters (e.g., Red + Creature)

3. **Popularity Sorting:**
   - [ ] "All" tab: Popular tokens appear first within color/category filters
   - [ ] Same popularity: alphabetical order
   - [ ] "Recent" tab: NOT sorted by popularity (chronological)
   - [ ] "Favorites" tab: NOT sorted by popularity (user order)

4. **Recent Feature:**
   - [ ] Add token to recent � appears in Recent tab
   - [ ] Restart app � recent token persists
   - [ ] Add 21st token � oldest drops off
   - [ ] Recent tokens respect search filter

5. **Integration:**
   - [ ] Search "goblin" + Red filter + Creature filter � gets correct popular goblin
   - [ ] Popular token appears before less popular variant
   - [ ] All filters can be cleared independently

---

## Implementation Notes

### File Changes Required
- `HOUSEKEEPING/process_tokens_with_popularity.py` - Add type exclusion logic, keep as primary script
- `HOUSEKEEPING/process_tokens.py` - DELETE (replaced by popularity version)
- `lib/models/token_definition.dart` - Add popularity field
- `lib/database/token_database.dart` - Add color filtering, sorting, fix recent/favorites
- `lib/screens/token_search_screen.dart` - Add color filter UI, update category chips
- `lib/models/token_definition.dart` - May need to update Category enum matching logic
- `assets/token_database.json` - Regenerate with popularity data and excluded types

### Performance Considerations
- Popularity sorting happens in-memory on already-filtered list (O(n log n) - acceptable)
- Color exact-match is O(1) per token (Set comparison)
- No database queries or network calls
- All filtering/sorting is client-side

### Backwards Compatibility
- Old token_database.json without `popularity` field: defaults to 0
- Existing favorites/recent data in SharedPreferences: preserved and migrated

---

## Future Enhancements (Out of Scope)
These are NOT part of this feature but may be considered later:
- Dynamic bracket recalculation on new set releases
- User preference for sort order (popularity vs alphabetical)
- "Most Popular" badge/indicator in UI
- Search result count display
- Advanced filters (P/T range, ability keywords)
