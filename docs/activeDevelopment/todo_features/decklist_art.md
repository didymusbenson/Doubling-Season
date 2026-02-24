# Deck List Artwork

## Overview

Add a hero artwork image to decks, displayed on deck cards in `DecksListScreen` and as a header in `DeckDetailScreen`. Follows the same artwork display patterns used on `TokenCard` (fadeout style on right side, full view option).

## Artwork Source Priority

1. **Automatic (default):** Use the artwork from the first token template in the deck (by order). If the first template has no artwork, fall back through templates until one is found, or show no artwork.
2. **User-selected token:** User picks any token in the deck to be the hero image.
3. **Custom upload:** User uploads their own image from device storage.

When a deck has no templates or none have artwork, deck cards render without artwork (current behavior, no placeholder needed).

## Data Model Changes

Add to `Deck` model (`lib/models/deck.dart`):

| HiveField | Name | Type | Default | Purpose |
|-----------|------|------|---------|---------|
| 8 | `artworkMode` | `String?` | `null` | `null`/`'auto'` = first token, `'selected'` = specific token, `'custom'` = user upload |
| 9 | `artworkUrl` | `String?` | `null` | URL/path of the selected or custom artwork. `null` when mode is auto. |

When `artworkMode` is `null` or `'auto'`, resolve artwork at display time from the first template with a non-null `artworkUrl`. When `'selected'` or `'custom'`, use the stored `artworkUrl` directly.

Run `build_runner` after adding fields.

## UI: DecksListScreen Deck Cards

- Display resolved artwork on deck cards using the fadeout style (artwork on right ~50%, gradient fade to card background on left).
- Reuse the artwork display pattern from `TokenCard` — same layer order: base background → artwork → content.
- Artwork should not interfere with the deck name, subtitle, or gradient color border.

## UI: DeckDetailScreen Header

- Show the resolved artwork as a banner/hero at the top of the detail screen, above the name field.
- Keep it compact — roughly the height of a deck card, not a full-screen splash.

## UI: Artwork Selection

Add an artwork picker accessible from `DeckDetailScreen` (e.g., tap the header artwork area, or a menu option):

- **Auto (default):** First token's artwork. Label: "Auto — uses first token art."
- **Select from deck:** Show a grid of all templates in the deck that have artwork. Tap to select.
- **Upload custom:** Open device image picker. Save the image locally via `ArtworkManager` (same resize/cache pipeline as token artwork).

## Implementation Notes

- Follow `TokenCard` artwork patterns — check `lib/widgets/token_card.dart` for fadeout/fullView rendering.
- Use `ArtworkManager` (`lib/utils/artwork_manager.dart`) for downloading/caching/resizing any custom uploads.
- Auto-detection should be a computed getter on `Deck` (or a helper in `DeckProvider`) so it stays reactive when templates are reordered or removed.
- If the user-selected token is removed from the deck, fall back to auto mode gracefully.
- Export/import: include `artworkMode` and `artworkUrl` in the JSON schema. Custom uploads should be referenced by local path — imported decks with custom art will lose the image (acceptable for v1, note in import).

## Debugging Notes (from decks_overhaul integration)

These issues were found and fixed during the decks_overhaul work. Document here so they're not reintroduced:

### GlobalKey collision in ReorderableListView

**Symptom:** Massive spam of "Multiple widgets used the same GlobalKey" on every interaction.

**Root cause 1 — `DecksListScreen`:** Two separate `ReorderableListView.builder` instances (`_buildDeckList` and `_buildEditModeList`) swapped on edit mode toggle. Both used the same `_buildDeckCard` with `ValueKey('deck_${deck.key}')`. During the transition frame, both lists coexisted in the widget tree and `ReorderableListView`'s internal `GlobalObjectKey` wrappers collided.
- **Fix:** Eliminated the duplicate list builder. Single `ReorderableListView` handles both modes since `_buildDeckCard` already switches on `_editMode` internally.

**Root cause 2 — `ContentScreen`:** Token board items keyed as `'token_${item.createdAt}'`. `DateTime.now()` can produce identical timestamps during batch operations (deck loading, multiplier-applied creation), causing duplicate keys on every subsequent rebuild.
- **Fix:** Changed to `'token_${item.key}'` using Hive's auto-incremented integer box key (always unique).

**Lesson:** Never use `DateTime` as a uniqueness key in `ReorderableListView`. Use Hive `.key` or UUIDs.

## Out of Scope

- Artwork on the old load deck sheet (deleted).
- Mosaic/collage auto-generation.
- Artwork in exported JSON as embedded base64.
