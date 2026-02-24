# Feature: Decks Overhaul

**Status:** Requirements complete — ready for implementation
**Priority:** TBD

## Summary

Decks become a first-class view instead of save/load buttons on the main screen. A single "Decks" button in the floating action menu replaces both "Save Deck" and "Load Deck", opening a dedicated Decks screen for full deck management with sharing/export as the capstone feature.

Everything in this doc is MVP. No phasing — all features ship together: decks screen, save/load, detail editing, export/import, share, duplicate.

---

## Screen Flow

### FAB Menu Entry Point
- "Save Deck" and "Load Deck" replaced by a single new "Decks" button
- Single entry point into the Decks experience (FAB menu only)
- Opens the Decks List Screen

### Decks List Screen
- **App bar:** "Save" (left), title "Decks" (center), icon row (right): Edit, Import
- **Deck cards show:**
  - Deck name (title)
  - Subtitle: token type summary (e.g., "Treasure, Merfolk, Clue, and X others")
  - Color gradient border derived from the deck's own `colorIdentity` field (same gradient system as token cards, via `ColorUtils.gradientForColors()`)
- **"Save" button** (app bar left): Saves current board as new deck → bottom sheet modal for naming the deck and setting its colors (see "Save Flow" section)
- **"Edit" button** (app bar right): Enters edit mode for the deck LIST — bulk delete decks, drag to reorder decks
- **Tapping a deck** (not in edit mode): Opens a bottom sheet with 6 options:
  - Clear board and load deck
  - Add deck to current board
  - Edit deck (opens Deck Detail Screen)
  - Share (native share sheet with exportable JSON)
  - Duplicate (creates a copy with auto-renamed name, e.g., "My Deck (2)")
  - Delete deck (confirmation modal, permanent and immediate, no undo)
- **Empty state:** Centered grey icon + descriptive text. Optionally prompt to save first deck.

### Deck Detail Screen
- **App bar:** "Back" (left), deck name as title, Share icon (right) — `Icons.share` via `share_plus`, same pattern as French Vanilla detail screens
- **Navigation:** `Navigator.of(context).push(MaterialPageRoute(..., fullscreenDialog: true))`
- **Deck header** at top of list (before token/utility rows):
  - Deck name (editable)
  - Deck color identity displayed with `ColorSelectionButton` toggles (same WUBRG buttons as ExpandedTokenScreen / NewTokenSheet) — user can update the deck's colors from here
- **Token definition list:**
  - Each row looks like a TokenCard from the main board EXCEPT: no tapped/untapped counts, no counters, no action buttons
  - Shows: name, abilities, power/toughness, artwork, color gradient border — raw token template info only
- **Utility definitions** also shown in the list (trackers and toggles saved in the deck), with same display treatment (template info only, no live state)
- **Tap token/utility to edit:** Opens an expanded view for the template (like ExpandedTokenScreen but template-only fields: name, type, abilities, P/T, artwork, colors). Altering a preset token's properties makes it effectively a custom token, but retains all artwork options and other relevant info.
- **Swipe-to-delete:** Always available on individual items. Produces an "are you sure?" confirmation so accidental swipes can be cancelled.
- **Edit button:** Enters multi-select mode with checkboxes for bulk deletion. Bulk deletion also requires confirmation.
- **"Add a token" button** at bottom of list: Opens token search that adds the token to the DECK (not to the main board). Works with custom tokens too. (See "Search Screen Refactor" section for implementation.)
- **"Add a utility" button** (or combined with above): Opens utility selection that adds to the deck. (See "Search Screen Refactor" section.)
- **Deck-scoped artwork preference:** Artwork stored directly on the `TokenTemplate` (`artworkUrl`/`artworkSet`/`artworkOptions` fields). Independent from the global `artworkPreferences` box. Loading a deck does NOT overwrite existing board tokens' artwork or change global preferences.

---

## Deck Color Identity

Decks have their own `colorIdentity` field (String, same format as token colors — e.g., "WUB", "RG", "WUBRG"). This drives the gradient border on deck cards, identical to how token cards derive their gradient from `item.colors`.

**At save time (creating a new deck):**
1. Auto-detect colors from the board: union of all contained tokens' color identities
2. Present the save bottom sheet with: name field + `ColorSelectionButton` toggles (WUBRG) with detected colors pre-selected
3. User can tap toggles to add/remove colors before confirming
4. Uses the same `ColorSelectionButton` widget from `lib/widgets/color_selection_button.dart` (already used in ExpandedTokenScreen and NewTokenSheet)

**In deck detail (editing an existing deck):**
- Deck header at top of the token list shows the deck's color identity via `ColorSelectionButton` toggles
- User can update colors at any time (auto-saves like all other Hive fields)

**On the Decks list screen:**
- Each deck card's border gradient is computed from `deck.colorIdentity` using `ColorUtils.gradientForColors()` — same system as TokenCard

---

## Save Flow

- **Entry:** "Save" button in Decks List Screen app bar (left)
- **UI:** Bottom sheet modal with deck name field + `ColorSelectionButton` WUBRG toggles (colors auto-detected from board, user can change before confirming)
- **Dedup key:** Tokens deduped on `name|pt|colors|type|abilities|artworkUrl` — base info PLUS artwork preference. Three identical goblins with the same art = 1 template. Two goblins with different artwork selections = 2 separate templates.
- **Amounts NOT saved:** Decks are templates, not snapshots. Tokens load with amount 0 — user adds quantities manually after loading.
- **Duplicate name handling:** When the user types a name (save sheet, deck detail), duplicate names are silently allowed — don't second-guess the user. Auto-rename (e.g., "My Deck (2)") only applies to system-generated names: the Duplicate action and Import.
- **Empty board:** Allowed. Users might want a named placeholder to fill in later via deck detail editing.
- **No deck count limit:** Users can save as many decks as they want.
- **Empty names:** Blocked. No max length, no character restrictions.

---

## Load Flow

- **Entry:** Bottom sheet on deck tap → "Clear board and load deck" or "Add deck to current board"
- **Behavior:** Same as old Load Deck flow (clear & load or additive)
- **Tapped/summoningSick state:** NOT preserved. Loading a deck = starting a new game.
- **Tracker/toggle live state:** NOT preserved. `currentValue` resets to `defaultValue`, `isActive` resets to `false`.
- **Multiplier:** NOT part of decks. Not applied during load.
- **Return after load:** Auto-pop back to board via `Navigator.pop(context)`

---

## Deck Editing

- **Auto-save:** Follows Hive auto-save pattern used everywhere. No explicit save button.
- **Reorder:** Drag-to-reorder using `ReorderableListView.builder` + fractional order pattern from `content_screen.dart`. Consider extracting the reorder/compaction logic as a mixin since it'll be used in three places (board, deck list, deck detail).
- **Swipe-to-delete:** Always available on individual items, with "are you sure?" confirmation.
- **Edit mode:** Multi-select checkboxes for bulk deletion, with confirmation.
- **Tap to edit:** Opens expanded template view (like ExpandedTokenScreen but template-only fields: name, type, abilities, P/T, artwork, colors).
- **Add tokens:** "Add a token" button → refactored `TokenSearchScreen` pops with a `TokenDefinition` → deck detail builds a `TokenTemplate` and adds to deck. No quantity picker, no multiplier, no summoning sickness. (See "Search Screen Refactor" section.)
- **Add utilities:** "Add a utility" button → refactored `WidgetSelectionScreen` pops with selection → deck detail builds template and adds to deck. (See "Search Screen Refactor" section.)
- **Deck-scoped artwork:** Artwork stored on `TokenTemplate` fields (`artworkUrl`/`artworkSet`/`artworkOptions`). Independent from global `artworkPreferences` box. Already works correctly — `template.toItem()` copies template artwork directly, never consults global preferences.

---

## Export / Sharing

- **Platform:** iOS + Android only. Export/import features explicitly skipped/hidden on web and desktop.
- **Mechanism:** Platform share sheet via `share_plus` (new dependency — already used in French Vanilla). Enables AirDrop, Messages, email, etc. "Save to Files" is built into the iOS share sheet so no separate file-save flow needed.
- **File format:** `.json` (pretty-printed — users should be able to read it, and deck files are small). Future-proof the import file picker to accept both `['json', 'tsdeck']` so the switch to `.tsdeck` later is seamless. See `FeedbackIdeas.md` for the `.tsdeck` + file handler registration plan.
- **Filename:** `DeckName.json` with special characters sanitized.
- **Metadata included in export:** App version (via `package_info_plus`, already a dependency), export date, and schema version (integer, start at 1 — lets future imports handle old formats gracefully).
- **Available from:** Deck tap bottom sheet (Share option) AND from within the deck detail screen (so users can edit then share without backing out).

---

## Import

**This version:** Import from the app's own exportable JSON format. User taps the Import icon in the Decks screen app bar → system file picker → parses JSON → creates a new deck in the library.

- **Entry:** Import icon in Decks screen app bar (right side, alongside Edit and Share icons)
- **Format:** JSON only (this version). File picker accepts `['json', 'tsdeck']` for future-proofing.
- **Validation:** If the file is malformed or has a newer schema version than the app recognizes, show error and abort. No partial imports.
- **Duplicate name handling:** Auto-rename (same pattern as save and duplicate).
- **Destination:** Adds to deck library only. User loads to board manually.
- **File handler registration:** Deferred to `.tsdeck` phase (see `FeedbackIdeas.md`).

**Future version (NOT in scope, but MUST be documented):** Import a deck from a list of card names. Cards have "reverse-lookups" in the token database — given a card name, we can determine which tokens it creates. This would allow importing a decklist from Moxfield/Archidekt/etc. and auto-populating the necessary tokens.

**CRITICAL: The import screen implementation MUST include comment documentation noting this future capability.** Example:
```dart
// FUTURE: Support importing from a list of card names.
// Cards can be reverse-looked-up in token_database.json to find
// which tokens they create. This enables importing decklists from
// external sources (Moxfield, Archidekt, etc.) and auto-populating
// the required token templates. See decks_overhaul.md for details.
```

---

## Data Model Changes

**New Deck fields (HiveField 4+):**

| HiveField | Name | Type | Default |
|-----------|------|------|---------|
| 4 | `colorIdentity` | String? | null |
| 5 | `order` | double? | 0.0 |
| 6 | `createdAt` | DateTime? | null |
| 7 | `lastModifiedAt` | DateTime? | null |

- All new fields use `@HiveField(N, defaultValue: ...)` for migration safety
- Timestamps: stored for future use, no UI exposure (no sorting UI, no display)
- `createdAt` set at creation time; `lastModifiedAt` updated on every edit
- All business logic in DeckProvider, not UI layer

**Constraints:**
- No deck count limit
- Duplicate names silently allowed
- Empty names blocked
- No max name length, no character restrictions

---

## Migration Safety

**CRITICAL: Existing user decks MUST be preserved.**

Users on v1.8 (before this change) who have saved decks need those decks migrated to the new format with zero data loss.

**Current Deck model (v1.8):**
- HiveField 0: `name` (String)
- HiveField 1: `templates` (List<TokenTemplate>)
- HiveField 2: `trackerWidgets` (List<TrackerWidgetTemplate>?, defaultValue: null)
- HiveField 3: `toggleWidgets` (List<ToggleWidgetTemplate>?, defaultValue: null)

**Migration strategy:**
- All new fields use `@HiveField(N, defaultValue: ...)` — Hive handles missing fields gracefully
- Existing decks load with null/default for new fields
- On first access of an existing deck in the new UI:
  - `colorIdentity` is null → auto-detect from contained templates' colors (same logic as save-time auto-detection)
  - `order` is 0.0 → assign sequential orders based on existing box order
  - `createdAt` is null → leave null (no meaningful value to backfill; timestamps only apply to newly created decks)
  - `lastModifiedAt` is null → leave null (begins populating on next edit)
- **No destructive migration.** Old Hive box name (`'decks'`) and model (`Deck`) stay the same. We're adding fields, not replacing the model.
- **Test plan:** Create decks on v1.8, upgrade to new version, verify all decks appear with correct names, templates, and auto-detected colors.

---

## Search Screen Refactor

Refactor `TokenSearchScreen` and `WidgetSelectionScreen` into pure selectors that pop with a definition:

- Search screen pops with a `TokenDefinition` (or widget definition) via `Navigator.pop(context, selection)`, or null on cancel
- **Board caller** (`ContentScreen`) `await`s the result → shows quantity picker → applies multiplier → creates `Item` → inserts. This is just moving existing code from the search screen's closure to the call site.
- **Deck detail caller** `await`s the same result → builds a `TokenTemplate` (or tracker/toggle template) → adds to deck. No quantity picker, no multiplier, no summoning sickness.
- **Key sequencing change:** Quantity picker currently lives inside `TokenSearchScreen`. After refactor, board caller triggers it. User sees identical flow. Test carefully.
- Same refactor applies to `WidgetSelectionScreen` for utility selection.

---

## Debug Logging

Follow the existing `debugPrint('ComponentName: message')` pattern used throughout the codebase (see `hive_setup.dart`, `TrackerProvider`, `DatabaseMaintenance` for examples). Include error + stack trace on all catch blocks.

**Migration (DeckProvider or hive_setup):**
- Log when migrated decks are detected (null `colorIdentity` / default `order`)
- Log each deck's auto-detected color identity during migration
- Log count of decks migrated and any that failed

**Save flow:**
- Log deck creation with name and template count
- Log dedup results (how many board items collapsed into how many templates)
- Log color auto-detection result

**Load flow:**
- Log which deck is being loaded and which mode (clear & load vs. add to board)
- Log template count being loaded

**Export / Import:**
- Log export: deck name, template count, schema version written
- Log import: file picked, schema version found, validation pass/fail
- Log import failure reason (malformed JSON, unknown schema version, etc.)
- Log auto-rename if import triggered duplicate name resolution

**Sharing:**
- Log share invocation with deck name

**Deck editing:**
- Log bulk delete (count of items removed)
- Log reorder compaction when triggered

---

## Code Removal

- **Delete:** `lib/widgets/load_deck_sheet.dart` — new Decks screen replaces it entirely
- **Remove from FAB menu:** "Save Deck" (line 192) and "Load Deck" (line 204) entries in `lib/widgets/floating_action_menu.dart`
- **Approach:** Rip-and-replace. No feature flag. Clean break once the new Decks screen is functional.

---

## Implementation Reference

- **Deck model:** `lib/models/deck.dart` — name, List<TokenTemplate>, optional List<TrackerWidgetTemplate>, optional List<ToggleWidgetTemplate>. HiveFields 0-3, next available is 4.
- **Templates:** `lib/models/token_template.dart` (typeId 3), `tracker_widget_template.dart` (typeId 8), `toggle_widget_template.dart` (typeId 9)
- **TokenTemplate fields:** name, pt, abilities, colors, order, type, artworkUrl, artworkSet, artworkOptions — note: NO amount field
- **DeckProvider:** `lib/providers/deck_provider.dart` — `saveDeck()`, `deleteDeck()`, sync `decks` getter
- **Save flow:** `lib/screens/content_screen.dart` `_showSaveDeckDialog()` — currently deduplicates tokens by `name|pt|colors|abilities`. **Changing to** `name|pt|colors|type|abilities|artworkUrl` (adds `type` and `artworkUrl` to preserve per-token artwork choices). Preserves utilities individually, normalizes order.
- **Load flow:** `lib/widgets/load_deck_sheet.dart` — `Navigator.push` full-screen dialog, three-option load (Cancel / Clear & Load / Add to Board)
- **Floating action menu:** `lib/widgets/floating_action_menu.dart` — currently has separate "Save Deck" (line 192) and "Load Deck" (line 204) entries
- **Tokens load with amount: 0** — user adds quantities manually after loading
- **Tracker/toggle state resets on load** — currentValue → defaultValue, isActive → false
- **Artwork preferences:** Global `artworkPreferences` Hive box via `ArtworkPreferenceManager`. TokenTemplate already stores artworkUrl/artworkSet/artworkOptions per template.
- **Mockup reference:** See mockup image provided during requirements gathering (3-screen flow: FAB menu → Decks List → Deck Detail).
