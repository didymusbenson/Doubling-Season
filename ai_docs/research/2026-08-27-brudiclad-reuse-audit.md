# Brudiclad Reuse Audit

**Date:** 2026-08-27  
**Scope:** Final read-only audit of existing code that can reduce new Brudiclad implementation work.

## Outcome

The feature plan is structurally sound. The codebase already contains several pieces that should be extracted or generalized before Brudiclad is implemented. The only material correction is that the current UI listens directly to Hive boxes, so suppressing provider notifications does not make a multi-record commit render as one indivisible change.

## Reuse Worth Locking Into the Feature

### 1. Generalize Rhys's immutable resolved plan

[`RhysCopyPlanner`](https://github.com/didymusbenson/Doubling-Season/blob/9b1a1a1ccd69354f71de27b6ef20fe76047cca33/lib/services/rhys_copy_planner.dart#L7-L100) already models the key architecture Brudiclad needs: snapshot inputs, resolve rules and artwork once, preview that immutable result, then execute the same object without reevaluation. Brudiclad should reuse or generalize the resolved-token value object and follow this exact lifecycle.

This is stronger than merely copying the pattern: Rhys's private artwork resolution at lines 230-271 duplicates resolution logic in `TokenCreationService`. Extracting a shared resolved-result/artwork service would serve Rhys, Brudiclad, and ordinary token creation.

### 2. Extract one clean-stack merge compatibility helper

[`TokenProvider._findRhysMergeTarget`](https://github.com/didymusbenson/Doubling-Season/blob/9b1a1a1ccd69354f71de27b6ef20fe76047cca33/lib/providers/token_provider.dart#L863-L889) already defines the safest shipped compatibility rule: exact token characteristics, no built-in or custom counters, and exact artwork URL. This should become a shared predicate/finder used by Rhys, `TokenCreationService`, and Brudiclad.

This also gives the prerequisite ETB merge bug one canonical merge path instead of fixing multiple slightly different implementations.

### 3. Reuse rules display aggregation only for the compact summary

[`TokenCreationResult.aggregateForDisplay()` and `breakdownString()`](https://github.com/didymusbenson/Doubling-Season/blob/9b1a1a1ccd69354f71de27b6ef20fe76047cca33/lib/providers/rules_provider.dart#L40-L94) already produce the compact result summary the preview needs. Their own contract correctly says they are display-only. Brudiclad's virtual board and commit must retain raw per-event results, while its impact text can reuse these helpers directly.

### 4. Extract the deck definition row as `DefinitionPreviewCard`

The planned extraction is supported by the existing implementation: [`DeckDetailScreen._buildBorderedCard`](https://github.com/didymusbenson/Doubling-Season/blob/9b1a1a1ccd69354f71de27b6ef20fe76047cca33/lib/screens/deck_detail_screen.dart#L492-L517) and [`_buildItemWithArtwork`](https://github.com/didymusbenson/Doubling-Season/blob/9b1a1a1ccd69354f71de27b6ef20fe76047cca33/lib/screens/deck_detail_screen.dart#L601-L702) already combine cached cropped artwork, `BackgroundText`, color border, subtitle, and P/T. Refactor the deck screen onto the shared widget first, then use it in Brudiclad so existing visuals act as the regression reference.

Selection chrome can be an optional outer state on that card. Existing selected-state idioms use a primary-color border/tint, but there is no general selectable-card component worth importing wholesale.

### 5. Centralize artwork precaching

Artwork rendering primitives are already shared, but download/precache orchestration remains private and duplicated between `DeckDetailScreen` and [`TokenProvider._downloadArtworkInBackground`](https://github.com/didymusbenson/Doubling-Season/blob/9b1a1a1ccd69354f71de27b6ef20fe76047cca33/lib/providers/token_provider.dart#L905-L924). `ArtworkManager.getCachedArtworkFile()` does not initiate a download, so the Brudiclad rows cannot rely on it alone.

A small shared cache warmer/coordinator is justified. It should preserve the Scryfall URL after caching so existing crop percentages continue to work. Web behavior should be changed only deliberately because the current deck row is native-cache oriented.

### 6. Reuse the unified-board fractional ordering helper where needed

Rhys already snapshots the next unified-board order and safely calculates an interior fractional order, including the special zero value that `insertItem` treats as unassigned. See [`_rhysOrderFor`](https://github.com/didymusbenson/Doubling-Season/blob/9b1a1a1ccd69354f71de27b6ef20fe76047cca33/lib/providers/token_provider.dart#L892-L903). Step 1 Myr placement or any future plan insertion should extract this math instead of reproducing it.

### 7. Use a single model-level mutation method for transformation

[`Item.updateArtwork()`](https://github.com/didymusbenson/Doubling-Season/blob/9b1a1a1ccd69354f71de27b6ef20fe76047cca33/lib/models/item.dart#L281-L289) demonstrates the correct pattern: assign related private fields and save once. Brudiclad's proposed `becomeCopyOf()` should do the same for all copied characteristics. Public `Item` setters auto-save, so chaining them would expose many intermediate persisted states.

## Genuinely New Infrastructure

No existing helper can safely provide action-level board undo or transactional rollback.

- `Item.createDuplicate()` resets amount, tapped state, sickness, and order. Its deep-copy approach for custom counters and artwork options is useful reference material, but it is not a snapshot.
- `TokenTemplate` and deck import/export intentionally omit live board state and counters.
- Hive boot backups are corruption recovery, not an in-session undo mechanism.

The scoped typed `BoardUndoSnapshot` and silent restore path therefore remain appropriate new work. Board wipe is a good later consumer, but Brudiclad should define the reusable contract without expanding the MVP into retrofitting board wipe now.

## Atomicity Caveat

The spec currently calls for one final `notifyListeners()`. That is useful provider hygiene, but it is not equivalent to one UI update: [`ContentScreen`](https://github.com/didymusbenson/Doubling-Season/blob/9b1a1a1ccd69354f71de27b6ef20fe76047cca33/lib/screens/content_screen.dart#L144-L175) directly merges listeners from the token, tracker, and toggle Hive boxes. Each save/delete may therefore rebuild the board even when provider notification is suppressed.

For MVP, define atomicity as:

- no mutation before Resolve/Skip;
- the immutable plan is the sole commit input;
- failures trigger restoration from the pre-action snapshot;
- the user is left in either the complete pre-action or complete post-action state.

Do not promise a single rendered frame unless a separate box-level transaction or UI-listener suppression mechanism is designed. That mechanism does not exist today and is not necessary for rules correctness or Undo.

## Recommended Implementation Order

1. Extract token identity/copy semantics, resolved artwork handling, and clean merge compatibility.
2. Extract `DefinitionPreviewCard` and shared artwork precaching, with deck detail as the regression consumer.
3. Fix `TokenCreationService` merge ETB behavior using the shared merge path.
4. Add the immutable Brudiclad plan and virtual board.
5. Add the typed undo snapshot and model-level batch transformation.
6. Build the selector/Resolve UI and post-action `Tokens Modified` confirmation.

## Bottom Line

The best reuse is architectural rather than a hidden ready-made Brudiclad component: Rhys supplies the immutable plan, merge compatibility, ordering, and artwork-resolution precedents; the rules engine supplies summary aggregation; deckbuilding supplies the preview card. Undo remains legitimately new.
