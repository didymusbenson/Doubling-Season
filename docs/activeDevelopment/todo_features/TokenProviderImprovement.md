# Token Provider Improvement

**Status:** Proposed
**Priority:** Medium
**Complexity:** Medium
**Related:** FeedbackIdeas.md (Chatterfang Mode), PremiumVersionIdeas.md (Token Modifiers)
**Last Updated:** February 2026

## Problem Statement

Token creation logic is duplicated across multiple files, leading to bugs and inconsistency:

**Current Duplication Locations (verified Feb 2026):**
1. `token_search_screen.dart` (lines ~834-948) - Full implementation with artwork preferences, background download, summoning sickness, ETB events
2. `new_token_sheet.dart` (lines ~225-285) - Custom token creation with artwork prefs but NO background download
3. `token_provider.dart:copyToken()` (lines ~287-373) - Uses `_itemsBox.add()` directly (bypasses insertItem), copies artwork from source
4. `token_provider.dart:createScuteSwarmTokens()` (lines ~491-601) - Checks for existing stack, artwork from source/DB
5. `token_provider.dart:createKrenkoGoblins()` (lines ~613-730) - Checks for existing goblin stack, DB lookup + download
6. `token_provider.dart:createAcademyManufactorTokens()` (lines ~743-878) - Creates 3 artifact types, uses `_itemsBox.add()` directly (intentional: no ETB for artifacts)
7. `load_deck_sheet.dart` (lines ~209-225) - Loads from templates via `insertItemWithExplicitOrder()`, no ETB (templates start at amount=0)
8. `tracker_widget_card.dart` - UI calling layer for Krenko (lines ~509-581), Krenko Tin Street (~583-645), Academy Manufactor (~713-780). Computes order, delegates to provider methods.

**Problems:**
- **Inconsistent behavior:** Different flows handle artwork, summoning sickness, ETB events differently
- **Bug risk:** Krenko goblins didn't show artwork until fixed (missing `.save()` callback after download)
- **Maintenance burden:** Changes to token creation logic require updates in 8+ places
- **No extensibility:** Future features (Chatterfang, Doubling Season modifiers) would require changing all locations

**Example Bug (Dec 2025):**
Krenko goblin creation set `artworkUrl` but didn't trigger UI rebuild after download. Normal token creation had the callback logic. This wouldn't have happened with centralized creation.

---

## Current State of Relevant Infrastructure (Feb 2026)

### Already Solved — Do NOT re-implement

**Provider dependency injection:** All providers available via `context.read<>()` pattern. No circular dependency issues. Provider methods that need cross-provider access receive values as parameters from the calling UI layer (e.g., `insertionOrder` computed by the caller across all three item types).

**GameEvents singleton:** `GameEvents.instance.notifyCreatureEntered(item, amount)` already wired up. Called by `insertItem()` automatically for creatures (line 104-106 of token_provider.dart). Specialized methods that use `_itemsBox.add()` directly skip this intentionally when appropriate (e.g., Academy Manufactor artifacts).

**Session-scoped definition caches:** TokenProvider already caches frequently-used TokenDefinitions loaded from the JSON database:
- `_scuteSwarmCache` — Scute Swarm definition
- `_basicGoblinCache` — 1/1 red Goblin definition
- `_clueCache` — Clue artifact definition
- `_foodCache` — Food artifact definition
- `_treasureCache` — Treasure artifact definition

These are loaded on-demand via `rootBundle.loadString()` and reused for the session.

**ArtworkPreferenceManager:** Works via `getPreferredArtwork(tokenIdentity)`. Used in `token_search_screen.dart` and `new_token_sheet.dart`.

**`TokenDefinition.toItem()` signature** (token_definition.dart:74-86):
```dart
Item toItem({required int amount, required bool createTapped}) {
  return Item(
    name: name, pt: pt, abilities: abilities, colors: colors, type: type,
    amount: amount,
    tapped: createTapped ? amount : 0,
    summoningSick: 0, // Caller must apply sickness AFTER insert
    artworkOptions: artwork.isNotEmpty ? List.from(artwork) : null,
  );
}
```
Does NOT set `artworkUrl`, `artworkSet`, or `order` — all are caller's responsibility.

### Consistency Table (Feb 2026)

| Location | Handles Order | Handles Artwork | Handles Sickness | Handles ETB | Uses insertItem |
|----------|:---:|:---:|:---:|:---:|:---:|
| token_search_screen | Yes (explicit) | Yes (pref + download) | Yes (after insert) | Yes (via insertItem) | Yes |
| new_token_sheet | Yes (explicit) | Yes (pref only, no download) | Yes (after insert) | Yes (via insertItem) | Yes |
| copyToken | Yes (fractional) | Yes (copied from source) | Yes (computed) | No (uses _itemsBox.add) | No |
| createScuteSwarmTokens | Yes (param) | Yes (source/DB) | Yes (new stack only) | Yes (insertItem or direct) | Mixed |
| createKrenkoGoblins | Yes (param) | Yes (DB + download) | Yes | Yes (insertItem) | Yes |
| createAcademyManufactorTokens | Yes (param) | Yes (DB + download) | No (artifacts) | No (intentional) | No |
| load_deck_sheet | Yes (sequential) | Yes (from template) | No (amount=0) | No (amount=0) | Yes (explicit order) |

---

## Proposed Solution

### Phase 1: Centralized Token Creation Method

Add a single, authoritative token creation method to `TokenProvider`:

```dart
/// Creates and inserts a new token with all standard handling.
///
/// Handles: order calculation, artwork assignment + background download,
/// summoning sickness, ETB event firing, provider notification.
///
/// Returns the created Item for further customization if needed.
Future<Item> createToken({
  required TokenDefinition definition,
  required int amount,
  required double insertionOrder,
  required bool summoningSicknessEnabled,
  bool createTapped = false,
}) async {
  // 1. Create item from definition
  final newItem = definition.toItem(
    amount: amount,
    createTapped: createTapped,
  );
  newItem.order = insertionOrder;

  // 2. Assign artwork (check preferences via ArtworkPreferenceManager, fallback to first)
  _assignArtwork(newItem, definition);

  // 3. Insert into Hive (fires ETB automatically for creatures)
  await insertItem(newItem);

  // 4. Apply summoning sickness if enabled (MUST be after insert — setter calls .save())
  if (summoningSicknessEnabled &&
      newItem.hasPowerToughness &&
      !newItem.hasHaste) {
    newItem.summoningSick = amount;
  }

  // 5. Download artwork in background (with rebuild callback)
  _downloadArtworkInBackground(newItem);

  return newItem;
}
```

**Design decisions:**
- `insertionOrder` is an explicit parameter (not computed internally) because order calculation requires cross-provider access that the caller already has via `context.read<>()`
- `summoningSicknessEnabled` is explicit to avoid needing SettingsProvider access inside TokenProvider
- No `preferredArtworkUrl` parameter — `_assignArtwork()` calls `ArtworkPreferenceManager` internally
- `insertItem()` already fires ETB via GameEvents, so no separate ETB call needed

**Helper methods to extract:**

```dart
/// Internal: Assign artwork URL and set from definition or preferences
void _assignArtwork(Item item, TokenDefinition definition) {
  final artworkPrefManager = ArtworkPreferenceManager();
  final tokenIdentity = definition.id; // 'name|pt|colors|type|abilities'
  final preferredArtwork = artworkPrefManager.getPreferredArtwork(tokenIdentity);

  if (preferredArtwork != null) {
    item.artworkUrl = preferredArtwork.artworkUrl;
    item.artworkSet = preferredArtwork.setCode;
  } else if (definition.artwork.isNotEmpty) {
    item.artworkUrl = definition.artwork.first;
  }
}

/// Internal: Download artwork with rebuild callback
void _downloadArtworkInBackground(Item item) {
  if (item.artworkUrl == null || item.artworkUrl!.startsWith('file://')) {
    return; // No artwork or custom local artwork — skip
  }

  final artworkUrl = item.artworkUrl!;
  ArtworkManager.downloadArtwork(artworkUrl).then((file) {
    // Re-lookup item in case it was deleted during download
    final currentItem = items.firstWhereOrNull((i) => i.artworkUrl == artworkUrl);
    if (currentItem == null) return;

    if (file == null) {
      currentItem.artworkUrl = null;
      currentItem.artworkSet = null;
      currentItem.save();
    } else {
      currentItem.save(); // Triggers Hive notification → UI rebuild
    }
  }).catchError((error) {
    debugPrint('Error during background artwork download: $error');
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
1. Implement `createToken()` + helpers in TokenProvider
2. Refactor `token_search_screen.dart` to use new method (highest-traffic path)
3. Refactor `new_token_sheet.dart` to use new method
4. Assess specialized methods (Krenko, Scute, Academy) — these have complex "merge into existing stack" logic that `createToken()` may not cover. Options:
   a. Have specialized methods call `createToken()` for the "new stack" path internally
   b. Keep specialized methods but extract shared helpers (`_assignArtwork`, `_downloadArtworkInBackground`) so logic is DRY without forcing a single entry point
5. Refactor `copyToken()` to use `insertItem()` instead of `_itemsBox.add()` (align ETB behavior)
6. Refactor `load_deck_sheet.dart` if applicable (may not benefit — templates have different needs)

**Open question for implementation:**
The specialized creation methods (Krenko, Scute Swarm, Academy Manufactor) all have "check for existing stack and add to it" logic before deciding to create a new token. A single `createToken()` method can't easily handle this. **Recommended approach:** Extract the shared helpers and let specialized methods use them, rather than forcing everything through one entry point.

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
}) async { ... }

class TokenCreationRequest {
  final TokenDefinition definition;
  final int amount;
  final bool createTapped;
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
  required List<int> amounts,
  bool createTapped = false,
  bool applySummoningSickness = true,
}) async { ... }
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

**Note (Feb 2026):** Academy Manufactor is currently implemented as a specialized TrackerWidget action (`actionType: 'academy_manufactor'`) with its own creation method in TokenProvider. If the modifier system is built, Academy Manufactor should be migrated to use it — but the current implementation works and ships.

**Modifier Examples:**
- **Chatterfang, Squirrel General:** "If one or more tokens would be created, create that many 1/1 black Squirrel tokens in addition to those tokens"
- **Doubling Season:** "If an effect would create one or more tokens, it creates twice that many instead"
- **Academy Manufactor:** "If you would create a Clue, Food, or Treasure token, instead create one of each"
- **Mondrak, Glory Dominus:** "If one or more tokens would be created, twice that many are created instead"

**Design Considerations:**

### Modifier Registration System
```dart
abstract class TokenModifier {
  List<TokenCreationRequest> apply(TokenCreationRequest original);
}

class ChatterfangModifier extends TokenModifier {
  @override
  List<TokenCreationRequest> apply(TokenCreationRequest original) {
    return [
      original,
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
    return [original.copyWith(amount: original.amount * 2)];
  }
}
```

### Toggle Widget Integration
```dart
// In ToggleWidget model - add modifier type field
@HiveField(14, defaultValue: null)
String? modifierType; // 'chatterfang', 'doubling_season', 'academy_manufactor'
```

**Multiplier vs Modifier Distinction:**
- **Multiplier** (current): Simple quantity multiplier applied at creation time (user setting)
- **Modifier**: Game rule that changes token creation (Chatterfang, Doubling Season, etc.)
- Both can be active simultaneously: "Create 1 Goblin with 2x multiplier and Chatterfang ON" → Creates 2 Goblins + 2 Squirrels

**Open Questions:**
1. Should modifiers apply to modifiers? (MTG ruling: YES — modifiers stack)
2. How to handle modifier ordering? (MTG ruling: Player chooses order)
3. Should we show a preview before creating modified tokens?
4. How to prevent infinite modifier loops?
5. Should modifiers be premium features or free?

---

## Implementation Checklist

### Phase 1: Centralized Creation
- [ ] Cache `items` getter with sorted list invalidation (add `_invalidateCache()` calls to insertItem, deleteItem, updateItem, etc.)
- [ ] Implement `_assignArtwork()` helper in TokenProvider
- [ ] Implement `_downloadArtworkInBackground()` helper in TokenProvider
- [ ] Implement `createToken()` using helpers + existing `insertItem()`
- [ ] Refactor `token_search_screen.dart` to use `createToken()`
- [ ] Refactor `new_token_sheet.dart` to use `createToken()`
- [ ] Refactor `copyToken()` to use `insertItem()` instead of `_itemsBox.add()`
- [ ] Update Krenko/Scute/Academy specialized methods to use `_assignArtwork()` and `_downloadArtworkInBackground()` helpers
- [ ] Remove duplicated artwork/sickness logic from old locations
- [ ] Test all token creation flows (search, custom, copy, Krenko, Scute, Academy, deck load)

### Phase 2: Batch Creation (Investigation)
- [ ] Research Hive batch insert performance
- [ ] Research optimal artwork download strategy (parallel vs sequential)
- [ ] Decide on batch API design (Option A/B/C)
- [ ] Prototype batch creation with 100+ tokens
- [ ] Measure performance vs individual creation
- [ ] Design error handling strategy
- [ ] Implement batch creation method
- [ ] Refactor deck loading to use batch creation
- [ ] Test with large batches (1000+ tokens)

### Phase 3: Token Modifiers (Future)
- [ ] Design TokenModifier abstract class
- [ ] Implement ChatterfangModifier
- [ ] Implement DoublingSeasonModifier
- [ ] Migrate AcademyManufactorModifier from current TrackerWidget action
- [ ] Add `modifierType` field to ToggleWidget (Hive migration)
- [ ] Update `createToken()` to apply modifiers
- [ ] Handle modifier stacking rules
- [ ] Add modifier preview dialog
- [ ] Test modifier combinations

---

## Dependencies

**Required Providers:**
- TokenProvider (owns creation logic)
- SettingsProvider (summoning sickness — passed as parameter, not injected)
- TrackerProvider (order calculation — caller computes via context.read)
- ToggleProvider (order calculation — caller computes via context.read)
- ArtworkPreferenceManager (preferred artwork — called internally by helper)

**Provider access pattern (solved):** Callers use `context.read<>()` to gather cross-provider values (like insertion order), then pass them as parameters to TokenProvider methods. This avoids circular dependencies and keeps TokenProvider independent.

---

## References

- **Current gold standard:** `lib/screens/token_search_screen.dart:834-948`
- **Bug example:** `lib/widgets/tracker_widget_card.dart` (Krenko artwork fix, Dec 2025)
- **Specialized methods:** `lib/providers/token_provider.dart` (createScuteSwarmTokens, createKrenkoGoblins, createAcademyManufactorTokens)
- **Definition model:** `lib/models/token_definition.dart:74-86` (toItem signature)
- **Related Docs:** `docs/activeDevelopment/FeedbackIdeas.md` (Chatterfang request)
- **MTG Rules:** Comprehensive Rules 701.6 (Token creation), 614 (Replacement effects)
