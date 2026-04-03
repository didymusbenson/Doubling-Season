# New Release Acceptance Testing Checklist

**Version:** 1.8.x → next release
**Date:** March 23, 2026

---

## 1. Resilient Boot & Crash Recovery

_Ref: custom_token_artwork_boot_hang.md_

- [ ] Fresh install boots to main screen without errors
- [ ] Upgrade from previous version preserves all existing data (tokens, decks, utilities)
- [ ] App recovers gracefully if a Hive box is corrupted (falls back to backup or empty)
- [ ] Post-boot dialog appears ONLY when a box had to be wiped (not on backup restore)
- [ ] Kill app mid-operation, relaunch — no hang on splash screen

## 2. Decks — Core CRUD & Navigation

_Ref: decks_overhaul.md, decks_phase2.md_

- [ ] Single "Decks" button in FAB menu opens Decks List Screen
- [ ] Create new deck: name required, WUBRG color auto-detected from board, empty board allowed
- [ ] Deck cards show name, token summary, and color gradient border
- [ ] Tap deck → 6 options: Clear & Load, Add to Board, Edit, Share, Duplicate, Delete
- [ ] Clear & Load: clears board, loads deck tokens at amount 0
- [ ] Add to Board: adds deck tokens without clearing
- [ ] Edit deck: drag-to-reorder, add/remove tokens, rename
- [ ] Duplicate deck creates a copy with unique name
- [ ] Delete deck with confirmation

## 3. Decks — Artwork & Display

_Ref: decks_phase2.md_

- [ ] Deck list cards show fadeout artwork (right 50%, gradient fade)
- [ ] Auto artwork: uses first token template that has artwork
- [ ] Custom deck artwork: tap deck box thumbnail → upload custom art
- [ ] Long-press deck box thumbnail → clears custom art, reverts to auto
- [ ] Empty deck or no artwork → no image shown (no broken placeholder)

## 4. Decks — Export & Import

_Ref: decks_overhaul.md, decks_phase2.md_

- [ ] Share/export produces pretty-printed JSON with app version, date, schema version
- [ ] artworkOptions included in export for all template types
- [ ] Import from JSON file (accepts `.json` and `.tsdeck`)
- [ ] Imported deck loads correctly with artwork preserved

## 5. Import Deck from Decklist (Clipboard)

_Ref: import_from_decklist.md_

- [ ] "Import from Copied Decklist" reads clipboard directly (one-tap, no text field)
- [ ] Parses standard formats: `1 Card (SET) 123`, `1 Card`, `1x Card`, `*1 Card`, name-only
- [ ] Skips blank lines and section headers
- [ ] Handles split/DFC card names with `/` and `//`
- [ ] Confirmation screen shows detected tokens with artwork, color borders, and source card attribution
- [ ] If no tokens found: dialog with "Try Again" and "Cancel"
- [ ] Auto-names deck from `[deck title=...]` if present, otherwise "Imported Deck"
- [ ] All imported tokens start at qty 1

## 6. Custom Token Library

_Ref: custom_token_library.md_

- [ ] Creating a custom token saves it to persistent library
- [ ] Custom tokens appear in dedicated "Custom" tab in token search
- [ ] Custom tokens also appear in "Recent" tab after creation
- [ ] Custom tokens searchable in "All" tab
- [ ] Custom tokens persist after kill and relaunch
- [ ] Swipe-to-delete removes custom token from all tabs
- [ ] Artwork upload during custom token creation (4:3 crop)
- [ ] Loading a deck re-creates deleted custom tokens in the library

## 7. Utility Cards — General

_Ref: swipe_dismiss_fix.md, artwork docs_

- [ ] Tracker widgets display correctly with artwork (fadeout and full-view styles)
- [ ] Toggle widgets display correctly with artwork
- [ ] Swipe-to-dismiss shows red background correctly on ALL card types (tokens, tracker, toggle)
- [ ] Utilities save/load with decks, preserving order
- [ ] Utility state resets on deck load (values go to defaults)

## 8. Academy Manufactor Utility

_Ref: academy_manufactor.md_

- [ ] Create Academy Manufactor utility from utility menu
- [ ] Value tracks copy count; at 0 copies, button disabled, card greyed out
- [ ] "Make Tokens" shows confirmation with math breakdown (3^(N-1) formula)
- [ ] Creates Clue, Food, and Treasure tokens (or consolidates into existing stacks)
- [ ] Created tokens have no P/T, no summoning sickness
- [ ] Artwork downloads for created tokens

## 9. Cathar's Crusade Utility

_Ref: commits 238586b, 006364a, 9a9ec13_

- [ ] Cathar's Crusade utility detects all creatures on board (including Krenko-created goblins)
- [ ] Quick +1 button for fast single-trigger resolution
- [ ] Correctly adds +1/+1 counters to eligible creatures

## 10. Counters — +1/+0 and +0/+1

_Ref: livedemofeedback.md, commit a5596e4_

- [ ] +1/+0 counter available in counter selection
- [ ] +0/+1 counter available in counter selection
- [ ] +1/+0 modifies displayed power only
- [ ] +0/+1 modifies displayed toughness only
- [ ] These counters do NOT auto-cancel with +1/+1, -1/-1, or each other

## 11. Token Database (MTGJSON Migration)

_Ref: commit 432311b, 9ace932_

- [ ] Token search returns results from updated 913-token database
- [ ] `reverse_related` field populated (powers decklist import)
- [ ] About screen credits MTGJSON (not Cockatrice)

## 12. App Bar & Board Controls

_Ref: commits ea55ee7, 6f33a67, b6a5c1f_

- [ ] Next Turn button works (untaps all, clears summoning sickness)
- [ ] Status bar / clear summoning sickness buttons in app bar
- [ ] Quick +1/+1 counter button on token cards

## 13. Artwork Display System

_Ref: ArtworkImplementationResearch.md_

- [ ] Fadeout style: artwork on right 50% with gradient fade (all card types)
- [ ] Full-view style: artwork fills card width (all card types)
- [ ] Artwork style toggle works and persists
- [ ] No animation flicker on card appearance
- [ ] Custom artwork capped at 768px resolution

## 14. Storage Management

_Ref: commit 296acee_

- [ ] Settings > Clear Downloaded Artwork — clears Scryfall cached art
- [ ] Settings > Clear Imported Artwork — clears user-uploaded custom art
- [ ] Re-download missing art before clearing (no broken images after clear)
- [ ] Downloaded vs custom artwork tracked separately

## 15. Android Compatibility

_Ref: androidCompatibility.md_

- [ ] Keyboard opens correctly in token search quantity input
- [ ] Custom token creation modal works on Android 11-15
- [ ] Counter editing dialogs don't cause navigation issues
- [ ] Modal bottom sheets dismissible on older Android versions

## 16. Web Platform

_Ref: commit 15c86ba_

- [ ] Web build boots without crash
- [ ] Artwork renders correctly on web
- [ ] Custom artwork upload locked off on web

## 17. General Regression

- [ ] Create token from search → appears on board with correct P/T, colors, abilities
- [ ] Tap/untap tokens
- [ ] Summoning sickness applies correctly (only to creatures without haste)
- [ ] Stack splitting works (dismiss-before-split pattern)
- [ ] +1/+1 and -1/-1 counters auto-cancel
- [ ] +1/+1 Everything adds counters to all creatures
- [ ] Board wipe clears all items
- [ ] Multiplier applies at token creation time
- [ ] Scute Swarm doubling button works
- [ ] Copy token preserves sickness state
- [ ] Emblems: no tap/untap UI, no color border, centered layout
