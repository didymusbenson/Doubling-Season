# Feature: Decks Phase 2 — Template Editing & Deck Artwork

**Status:** Complete
**Depends on:** Decks overhaul (shipped in `4aa16dc`, polish in `d2c4eb4`)

## Summary

This feature covers the remaining work from the decks overhaul spec plus the new deck artwork feature. These are tightly coupled — tap-to-edit templates, artwork display on deck cards, artwork selection in deck detail, and export/import completeness all feed into each other.

---

## What's Already Done (Decks Overhaul — shipped)

For context, the following are **complete and committed**. Do not reimplement:

- **DecksListScreen** — Full deck list with CRUD, drag-to-reorder, bulk delete, import/export, share, duplicate
- **DeckDetailScreen** — Deck editor with editable name, color identity toggles, token/utility list, drag-to-reorder, swipe-to-delete, bulk delete, add token/utility buttons
- **DeckSaveSheet** — Save current board as deck with color auto-detection + user override
- **DeckProvider** — All business logic: save, delete, reorder, duplicate, export JSON, import JSON, load (clear & add), migration
- **Search screen refactor** — `TokenSearchScreen` and `WidgetSelectionScreen` support `selectorMode: true` to pop with a definition instead of creating on board
- **Custom creation in selector mode** — `NewTokenSheet`, `NewTrackerSheet`, `NewToggleSheet` all support `selectorMode` to return definitions instead of creating on board (fixed in `d2c4eb4`)
- **FAB menu** — Single "Decks" button replaces old Save/Load pair
- **Data model** — Deck HiveFields 0-7 (name, templates, trackerWidgets, toggleWidgets, colorIdentity, order, createdAt, lastModifiedAt)
- **Migration** — `migrateExistingDecks()` at boot handles pre-overhaul decks
- **Drag proxy clipping** — Both deck screens use custom `proxyDecorator` matching content_screen pattern (fixed in `d2c4eb4`)
- **UI polish** — "Editing {name}" title, back arrow (not X), trash icon for bulk delete mode, `Icons.download` for import

### Debugging Notes (preserve — do not reintroduce these bugs)

**GlobalKey collision in ReorderableListView:**
- Root cause 1 — `DecksListScreen`: Two separate `ReorderableListView.builder` instances swapped on edit mode toggle, causing GlobalKey collisions during the transition frame. Fix: Single list that switches on `_editMode` internally.
- Root cause 2 — `ContentScreen`: Token board items keyed as `'token_${item.createdAt}'`. `DateTime.now()` produces duplicates during batch operations. Fix: Changed to `'token_${item.key}'` (Hive box key, always unique).
- **Lesson:** Never use `DateTime` as a uniqueness key in `ReorderableListView`. Use Hive `.key` or UUIDs.

**Custom creation in selectorMode:**
- `NewTokenSheet`, `NewTrackerSheet`, `NewToggleSheet` originally always created items directly on the board via providers, ignoring `selectorMode`. Fix: Added `selectorMode` parameter to all three sheets. In selector mode, they build a definition and `Navigator.pop` it back instead of inserting via provider. `WidgetSelectionScreen` and `TokenSearchScreen` forward the result.

**Drag proxy dark corners:**
- Default `ReorderableListView` drag proxy wraps in a rectangular `Material` with `canvasColor`, bleeding through rounded corners. Fix: Custom `proxyDecorator` with `MaterialType.transparency` + `Clip.antiAlias` at the correct `borderRadius`.

---

## Remaining Work

### 1. Deck Artwork on Cards and Detail Header

**Source:** decklist_art.md (simplified)

Add artwork display to deck cards in `DecksListScreen` and as a header in `DeckDetailScreen`.

#### Artwork Resolution (simple two-tier)

1. **Custom upload (if set):** User has uploaded a custom image for this deck. Use it.
2. **Auto (default):** Use the `artworkUrl` from the first token template in the deck (by order). Fall back through templates until one with artwork is found, or show no artwork.

No "select from deck" picker — just auto from first token, or custom upload overrides it.

#### Data Model Changes

Add to `Deck` model (`lib/models/deck.dart`):

| HiveField | Name | Type | Default | Purpose |
|-----------|------|------|---------|---------|
| 8 | `customArtworkUrl` | `String?` | `null` | Local file path of user-uploaded custom artwork. `null` = use auto (first token art). |

When `customArtworkUrl` is non-null, use it. Otherwise resolve at display time from the first template with a non-null `artworkUrl`.

Run `build_runner` after adding fields.

#### UI: DecksListScreen Deck Cards

- Display resolved artwork on deck cards using the fadeout style (artwork on right ~50%, gradient fade to card background on left)
- Reuse the artwork display pattern from `TokenCard` — same layer order: base background → artwork → content
- Artwork should not interfere with the deck name, subtitle, or gradient color border
- When a deck has no templates or none have artwork, render without artwork (current behavior, no placeholder needed)

#### UI: DeckDetailScreen Header

Deck name and artwork share the top row. Color identity gets full width below.

Layout:
```
┌──────────────────────────────────────────┐
│  [Deck Name TextField     ]  ┌────────┐ │
│                              │ Deck   │ │
│                              │  Box   │ │
│                              └────────┘ │
│  Color Identity                         │
│  (W) (U) (B) (R) (G)                   │
│─────────────────────────────────────────│
```

- **Name field:** ~2/3 width, left side
- **Deck Box thumbnail:** ~60x60 rounded square, right side of name row. Displays resolved artwork (custom if set, otherwise first token art). Labeled "Deck Box" below the thumbnail.
- **Empty state:** Dashed border with camera/add icon when no artwork is available
- **Tap thumbnail:** Opens device image picker to upload custom deck box art
- **Long-press thumbnail:** Clears custom art, reverts to auto (first token art). Only enabled when custom art is set.
- **Color buttons:** Full width row below, unchanged

#### Custom Upload Flow

- Use `file_picker` (already a dependency) to pick an image from device
- Save via `ArtworkManager` (same resize/cache pipeline as token artwork — cap at 672x936)
- Store the local file path in `deck.customArtworkUrl`
- To clear: set `customArtworkUrl = null`, deck reverts to auto

#### Artwork Resilience

- Auto-detection is a computed getter — stays reactive when templates are reordered or removed
- If the first token has no artwork, fall through remaining templates
- No templates or none have artwork = no artwork displayed (graceful, no placeholder)

### 2. artworkOptions in Export/Import

**Source:** decks_overhaul spec line 109, 253-254

Token, tracker, and toggle templates all have `artworkOptions` fields, but the current `exportDeckToJson` / `importDeckFromJson` methods do NOT include them. This means artwork variant lists are lost on export/import.

**Fix:**
- Include `artworkOptions` in the JSON export for all template types
- Parse and restore `artworkOptions` on import
- Include `artworkMode` and `artworkUrl` (new deck-level fields) in export/import as well
- Custom uploads referenced by local path — imported decks with custom art will lose the image (acceptable for v1, note in import)

---

## Implementation Notes

- Follow `TokenCard` artwork patterns — check `lib/widgets/token_card.dart` for fadeout/fullView rendering
- Follow `docs/activeDevelopment/patterns/artwork_display.md` for artwork layer ordering
- Use `ArtworkManager` (`lib/utils/artwork_manager.dart`) for downloading/caching/resizing custom uploads
- All new HiveFields MUST use `defaultValue` for migration safety
- Run `build_runner build --delete-conflicting-outputs` after model changes

## Out of Scope

- Artwork on the old load deck sheet (deleted)
- Mosaic/collage auto-generation from multiple token arts
- Artwork in exported JSON as embedded base64
- `.tsdeck` file format and handler registration (deferred, see `FeedbackIdeas.md`)
- Import from card names/decklists (future, documented in `DecksListScreen` source comment)
