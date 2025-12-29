# Token Provider Improvement

**Status:** Proposed
**Priority:** Medium
**Complexity:** Medium
**Related:** FeedbackIdeas.md (Chatterfang Mode), PremiumVersionIdeas.md (Token Modifiers)

## Problem Statement

Token creation logic is currently duplicated across multiple files, leading to bugs and inconsistency:

**Current Duplication Locations:**
1. `token_search_screen.dart` (lines 860-948) - Full implementation with artwork callbacks
2. `tracker_widget_card.dart` (lines 605-727) - Krenko goblin creation (bug fixed Dec 2025)
3. `deck_provider.dart` - Deck loading creates tokens from templates
4. `token_provider.dart` - Copy token functionality
5. `new_token_sheet.dart` - Custom token creation

**Problems:**
- **Inconsistent behavior:** Different flows handle artwork, summoning sickness, ETB events differently
- **Bug risk:** Krenko goblins didn't show artwork until fixed (missing `.save()` callback after download)
- **Maintenance burden:** Changes to token creation logic require updates in 5+ places
- **No extensibility:** Future features (Chatterfang, Doubling Season modifiers) would require changing all locations

**Example Bug (Dec 2025):**
Krenko goblin creation set `artworkUrl` but didn't trigger UI rebuild after download. Normal token creation had the callback logic. This wouldn't have happened with centralized creation.

---

## Proposed Solution

### Phase 1: Centralized Token Creation Method

Add a single, authoritative token creation method to `TokenProvider`:

```dart
/// Creates and inserts a new token with all standard handling
///
/// Handles:
/// - Order calculation across all board items
/// - Artwork assignment (preferred or default)
/// - Artwork options persistence
/// - Background artwork download with callbacks
/// - Summoning sickness application
/// - ETB event firing (for Cathar's Crusade, etc.)
/// - Provider notification
///
/// Returns the created Item for further customization if needed
Future<Item> createToken({
  required TokenDefinition definition,
  required int amount,
  bool createTapped = false,
  bool applySummoningSickness = true,
  String? preferredArtworkUrl, // Optional: override default artwork selection
}) async {
  // 1. Calculate order
  final newOrder = _calculateNextOrder();

  // 2. Create item from definition
  final newItem = definition.toItem(
    amount: amount,
    createTapped: createTapped,
  );
  newItem.order = newOrder;

  // 3. Assign artwork (check preferences, fallback to first)
  _assignArtwork(newItem, definition, preferredArtworkUrl);

  // 4. Insert into Hive (makes it visible immediately)
  await insertItem(newItem);

  // 5. Apply summoning sickness if enabled
  if (applySummoningSickness) {
    _applySummoningSickness(newItem, amount);
  }

  // 6. Download artwork in background (with rebuild callback)
  _downloadArtworkInBackground(newItem);

  // 7. Fire ETB event for listeners (Cathar's Crusade, etc.)
  GameEvents.instance.notifyCreatureEntered(newItem, amount);

  return newItem;
}

/// Internal: Calculate next order across tokens, trackers, toggles
double _calculateNextOrder() {
  final allOrders = <double>[];
  allOrders.addAll(items.map((item) => item.order));
  // Access other providers via context or injection (TBD)
  allOrders.addAll(trackerProvider.trackers.map((t) => t.order));
  allOrders.addAll(toggleProvider.toggles.map((t) => t.order));

  final maxOrder = allOrders.isEmpty ? 0.0 : allOrders.reduce((a, b) => a > b ? a : b);
  return maxOrder.floor() + 1.0;
}

/// Internal: Assign artwork URL and set from definition or preferences
void _assignArtwork(Item item, TokenDefinition definition, String? preferredUrl) {
  // Check user preference via ArtworkPreferenceManager
  // Fallback to first artwork in definition
  // Handle file:// vs Scryfall URLs
  // Store artworkUrl, artworkSet, artworkOptions on item
}

/// Internal: Apply summoning sickness if conditions met
void _applySummoningSickness(Item item, int amount) {
  // Access SettingsProvider (via context or injection)
  // Check: enabled && hasPowerToughness && !hasHaste
  // Set item.summoningSick = amount
}

/// Internal: Download artwork with rebuild callback (matching TokenSearchScreen pattern)
void _downloadArtworkInBackground(Item item) {
  if (item.artworkUrl == null || item.artworkUrl!.startsWith('file://')) {
    return; // Skip custom artwork
  }

  final artworkUrl = item.artworkUrl!;
  ArtworkManager.downloadArtwork(artworkUrl).then((file) {
    if (file == null) {
      // Download failed - reset artworkUrl
      final currentItem = items.firstWhereOrNull((i) => i.artworkUrl == artworkUrl);
      if (currentItem != null) {
        currentItem.artworkUrl = null;
        currentItem.artworkSet = null;
        currentItem.save(); // Triggers rebuild
      }
    } else {
      // Download succeeded - trigger rebuild
      final currentItem = items.firstWhereOrNull((i) => i.artworkUrl == artworkUrl);
      if (currentItem != null) {
        currentItem.save(); // Triggers Hive save and notifies listeners
      }
    }
  }).catchError((error) {
    debugPrint('Error during background artwork download: $error');
    // Reset on error
    final currentItem = items.firstWhereOrNull((i) => i.artworkUrl == artworkUrl);
    if (currentItem != null) {
      currentItem.artworkUrl = null;
      currentItem.artworkSet = null;
      currentItem.save();
    }
  });
}
```

**Migration Plan:**
1. Implement `createToken()` in TokenProvider
2. Refactor TokenSearchScreen to use new method
3. Refactor Krenko actions to use new method
4. Refactor deck loading to use new method
5. Refactor copy token to use new method
6. Refactor custom token creation to use new method

**Benefits:**
- Single source of truth for token creation
- All bugs fixed once
- Consistent behavior everywhere
- Easier to extend for future features

---

## Phase 2: Batch Token Creation (Investigation Required)

**Use Cases:**
1. **Deck Loading:** Load 10+ tokens at once from deck template
2. **Future Token Modifiers:** Chatterfang creates "N Goblins + N Squirrels" in one action
3. **Mass Token Creation:** Player creates 100 goblins (performance optimization)

**API Design Options (To Investigate):**

**Option A: List of Definitions**
```dart
Future<List<Item>> createTokens({
  required List<TokenCreationRequest> requests,
  bool applySummoningSickness = true,
}) async {
  // requests = [
  //   TokenCreationRequest(definition: goblinDef, amount: 5),
  //   TokenCreationRequest(definition: squirrelDef, amount: 5),
  // ]
}

class TokenCreationRequest {
  final TokenDefinition definition;
  final int amount;
  final bool createTapped;
  // ... other overrides
}
```

**Option B: Batch Builder Pattern**
```dart
final batch = TokenBatchBuilder()
  .add(goblinDef, amount: 5)
  .add(squirrelDef, amount: 5)
  .withSummoningSickness(true)
  .build();

await tokenProvider.createTokenBatch(batch);
```

**Option C: Simple List with Shared Options**
```dart
Future<List<Item>> createTokensFromDefinitions({
  required List<TokenDefinition> definitions,
  required List<int> amounts, // Must match definitions length
  bool createTapped = false,
  bool applySummoningSickness = true,
}) async {
  // Simpler but less flexible
}
```

**Performance Considerations:**
- **Order calculation:** Calculate once, increment for each token (avoid recalculating)
- **Artwork download:** Batch download or parallel downloads? Investigate memory usage
- **Hive writes:** Can we batch inserts? Does Hive support transactions?
- **Provider notifications:** Notify once after batch vs per-item?

**Questions to Answer:**
1. Should batch creation be atomic (all-or-nothing)?
2. How to handle errors mid-batch? (Rollback vs partial success)
3. Should artwork download in batch be parallelized or sequential?
4. Do we need progress callbacks for large batches (100+ tokens)?
5. Should batch creation merge with existing stacks automatically?

---

## Phase 3: Token Modifier System (Future - Chatterfang, Doubling Season)

**Background:**
Cards like Chatterfang, Doubling Season, Parallel Lives, Academy Manufactor, Mondrak modify token creation. These should be handled in the centralized creation logic.

**Modifier Examples:**
- **Chatterfang, Squirrel General:** "If one or more tokens would be created, create that many 1/1 black Squirrel tokens in addition to those tokens"
- **Doubling Season:** "If an effect would create one or more tokens, it creates twice that many instead"
- **Academy Manufactor:** "If you would create a Clue, Food, or Treasure token, instead create one of each"
- **Mondrak, Glory Dominus:** "If one or more tokens would be created, twice that many are created instead"

**Design Considerations:**

### Modifier Registration System
```dart
abstract class TokenModifier {
  /// Modifies the token creation request before execution
  /// Returns list of tokens to create (may add additional tokens)
  List<TokenCreationRequest> apply(TokenCreationRequest original);
}

class ChatterfangModifier extends TokenModifier {
  @override
  List<TokenCreationRequest> apply(TokenCreationRequest original) {
    return [
      original, // Original tokens
      TokenCreationRequest(
        definition: squirrelDefinition,
        amount: original.amount,
        createTapped: original.createTapped,
      ),
    ];
  }
}

class DoublingSeasonModifier extends TokenModifier {
  @override
  List<TokenCreationRequest> apply(TokenCreationRequest original) {
    return [
      original.copyWith(amount: original.amount * 2),
    ];
  }
}

class AcademyManufactorModifier extends TokenModifier {
  @override
  List<TokenCreationRequest> apply(TokenCreationRequest original) {
    // Only applies to Clue, Food, Treasure
    if (!_isArtifactToken(original.definition)) {
      return [original];
    }

    return [
      TokenCreationRequest(definition: clueDef, amount: original.amount),
      TokenCreationRequest(definition: foodDef, amount: original.amount),
      TokenCreationRequest(definition: treasureDef, amount: original.amount),
    ];
  }
}
```

### Modified Creation Method
```dart
Future<List<Item>> createToken({
  required TokenDefinition definition,
  required int amount,
  // ... other params
}) async {
  // 1. Create initial request
  var request = TokenCreationRequest(
    definition: definition,
    amount: amount,
    createTapped: createTapped,
  );

  // 2. Apply active modifiers (from toggle widgets or global state)
  List<TokenCreationRequest> requests = [request];
  for (final modifier in _activeModifiers) {
    requests = requests.expand((req) => modifier.apply(req)).toList();
  }

  // 3. Create all tokens from modified requests
  final createdTokens = <Item>[];
  for (final req in requests) {
    final token = await _createTokenInternal(req);
    createdTokens.add(token);
  }

  return createdTokens;
}

List<TokenModifier> get _activeModifiers {
  // Check toggle widgets for active modifiers
  // Example: If Chatterfang toggle is ON, include ChatterfangModifier
  final modifiers = <TokenModifier>[];

  // Access ToggleProvider (via context or injection)
  for (final toggle in toggleProvider.toggles) {
    if (toggle.isActive) {
      final modifier = _modifierForToggle(toggle);
      if (modifier != null) {
        modifiers.add(modifier);
      }
    }
  }

  return modifiers;
}
```

### Toggle Widget Integration
```dart
// In ToggleWidget model - add modifier type field
@HiveField(14, defaultValue: null)
String? modifierType; // 'chatterfang', 'doubling_season', 'academy_manufactor'

// In WidgetDefinition
WidgetDefinition(
  id: 'chatterfang',
  type: WidgetType.toggle,
  name: 'Chatterfang Mode',
  description: 'Create matching Squirrel tokens',
  offDescription: 'Chatterfang inactive',
  colorIdentity: 'BG',
  modifierType: 'chatterfang', // NEW - links toggle to modifier
  artwork: [...],
)
```

**Multiplier vs Modifier Distinction:**
- **Multiplier** (current): Simple quantity multiplier applied at creation time (user setting)
- **Modifier**: Game rule that changes token creation (Chatterfang, Doubling Season, etc.)
- Both can be active simultaneously: "Create 1 Goblin with 2x multiplier and Chatterfang ON" → Creates 2 Goblins + 2 Squirrels

**Open Questions:**
1. Should modifiers apply to modifiers? (Chatterfang creates Squirrels → Does Doubling Season double the Squirrels?)
   - MTG ruling: YES (modifiers stack and can create infinite loops in some cases)
2. How to handle modifier ordering? (Doubling Season → Chatterfang vs Chatterfang → Doubling Season may differ)
   - MTG ruling: Player chooses order for modifiers they control
3. Should we show a preview before creating modified tokens? ("This will create 4 Goblins + 4 Squirrels. Continue?")
4. How to prevent infinite modifier loops? (Some MTG card combos can create unbounded tokens)
5. Should modifiers be premium features or free?

---

## Implementation Checklist

### Phase 1: Centralized Creation
- [ ] Design `createToken()` API in TokenProvider
- [ ] Implement order calculation helper
- [ ] Implement artwork assignment helper
- [ ] Implement summoning sickness helper
- [ ] Implement background download helper
- [ ] Add unit tests for createToken()
- [ ] Refactor TokenSearchScreen to use createToken()
- [ ] Refactor Krenko actions to use createToken()
- [ ] Refactor deck loading to use createToken()
- [ ] Refactor copy token to use createToken()
- [ ] Refactor custom token creation to use createToken()
- [ ] Remove duplicated code from all old locations
- [ ] Test all token creation flows

### Phase 2: Batch Creation (Investigation)
- [ ] Research Hive batch insert performance
- [ ] Research optimal artwork download strategy (parallel vs sequential)
- [ ] Decide on batch API design (Option A/B/C)
- [ ] Prototype batch creation with 100+ tokens
- [ ] Measure performance vs individual creation
- [ ] Design error handling strategy
- [ ] Implement batch creation method
- [ ] Refactor deck loading to use batch creation
- [ ] Add progress callbacks if needed
- [ ] Test with large batches (1000+ tokens)

### Phase 3: Token Modifiers (Future)
- [ ] Design TokenModifier abstract class
- [ ] Implement ChatterfangModifier
- [ ] Implement DoublingSeasonModifier
- [ ] Implement AcademyManufactorModifier
- [ ] Add `modifierType` field to ToggleWidget (Hive migration)
- [ ] Update WidgetDefinition to include modifierType
- [ ] Implement modifier registration system
- [ ] Update createToken() to apply modifiers
- [ ] Handle modifier stacking rules
- [ ] Add modifier preview dialog
- [ ] Test modifier combinations
- [ ] Add to PremiumVersionIdeas.md if premium feature

---

## Dependencies

**Required Providers:**
- TokenProvider (owns creation logic)
- SettingsProvider (summoning sickness, multiplier)
- TrackerProvider (order calculation)
- ToggleProvider (order calculation, future modifiers)
- ArtworkPreferenceManager (preferred artwork)

**Design Decision Needed:**
How should TokenProvider access other providers? Options:
1. Pass providers as constructor params (dependency injection)
2. Access via context (requires BuildContext in createToken)
3. Use global provider instance (via Provider.of without context)
4. Event bus / pub-sub pattern

**Recommendation:** Investigate dependency injection pattern used elsewhere in codebase.

---

## Testing Strategy

**Unit Tests:**
- createToken() with various TokenDefinitions
- Order calculation with empty board
- Order calculation with mixed items (tokens + trackers + toggles)
- Artwork assignment with preferences
- Artwork assignment without preferences
- Summoning sickness application conditions
- Error handling for failed artwork downloads

**Integration Tests:**
- Create token via TokenSearchScreen → Verify UI updates
- Create token via Krenko → Verify artwork loads
- Load deck with 10 tokens → Verify batch performance
- Apply Chatterfang modifier → Verify squirrels created
- Stack modifiers (Chatterfang + Doubling Season) → Verify correct count

**Performance Tests:**
- Create 1000 tokens individually → Measure time
- Create 1000 tokens in batch → Measure time
- Compare batch vs individual performance
- Memory usage during batch creation
- UI responsiveness during large batch

---

## References

- **Current Implementation:** `lib/screens/token_search_screen.dart:860-948` (gold standard)
- **Bug Example:** `lib/widgets/tracker_widget_card.dart:605-727` (Krenko, fixed Dec 2025)
- **Related Docs:** `docs/activeDevelopment/FeedbackIdeas.md` (Chatterfang request)
- **Related Docs:** `docs/activeDevelopment/PremiumVersionIdeas.md` (Token modifier features)
- **MTG Rules:** Comprehensive Rules 701.6 (Token creation)
- **MTG Rules:** Comprehensive Rules 614 (Replacement effects - modifiers)
