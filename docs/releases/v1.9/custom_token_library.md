# Custom Token Library

## Summary
Custom tokens created via NewTokenSheet now persist across sessions in a dedicated Hive box (`customTokens`). They appear in a new "Custom" tab in token search, show up in Recents/Favorites, and are searchable in the All tab.

## Files Changed
- `lib/models/token_definition.dart` — added `toJson()`
- `lib/database/hive_setup.dart` — opens `Box<String>('customTokens')` at boot
- `lib/database/token_database.dart` — custom token CRUD, merged into all lookups
- `lib/screens/token_search_screen.dart` — 4th "Custom" tab, swipe-to-delete
- `lib/widgets/new_token_sheet.dart` — saves custom tokens on creation, added image cropper to artwork upload
- `lib/main.dart` — added `customTokens` to data loss dialog
- `lib/screens/decks_list_screen.dart` — deck load ensures custom tokens exist in library

## Testing Checklist

### Basic Flow
- [ ] Create a custom token via NewTokenSheet → appears in Custom tab and Recent tab
- [ ] Kill and relaunch app → custom token persists in Custom tab
- [ ] Favorite a custom token → appears in Favorites tab
- [ ] Search for custom token by name → found in All tab and Custom tab
- [ ] Delete custom token from Custom tab (swipe left) → removed from all tabs

### Dedup
- [ ] Create custom token with same identity as a database token (e.g. "Goblin" 1/1 R Creature) → database version shown, no duplicate in All tab

### Artwork
- [ ] Upload artwork on custom token → cropper appears (4:3 locked aspect ratio)
- [ ] Cropped artwork displays correctly on board

### Deck Integration (IMPORTANT)
- [ ] Save a deck containing a custom token
- [ ] Delete the custom token from the Custom tab
- [ ] Load the deck → the custom token should be **automatically recreated** in the custom library from the deck's template data
- [ ] Verify the recreated token retains artwork (if the artwork file hasn't been cleared via Settings > Clear Imported Artwork)
- [ ] The recreated token should appear in the Custom tab

### Edge Cases
- [ ] Deleting a custom token does NOT delete its artwork file from disk (orphaned, cleaned up via Settings > Clear Imported Artwork)
- [ ] Hot restart preserves custom tokens (Hive box reopened in main())
- [ ] Web platform: customTokens box opens via IndexedDB path
- [ ] Tab selector text fits without wrapping (icons removed, `showSelectedIcon: false`)
