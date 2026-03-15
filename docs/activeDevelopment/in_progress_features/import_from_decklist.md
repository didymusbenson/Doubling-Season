# Import from Decklist

Create tokens from a pasted deck list by matching card names against the token database's `reverse_related` field.

## User Flow

1. User taps "Import from Decklist" on the Decks List screen (alongside existing "Save Board" and "New Deck" buttons)
2. User enters a deck list via multiline text field OR taps "Paste from Clipboard" button for one-tap import
3. App parses the list, extracts card names, matches against `reverseRelated` in token database
4. App shows a "Tokens Detected" confirmation screen listing matched tokens (with which cards created them)
5. User confirms — a new deck is created containing those token templates
6. App navigates to the new deck's detail screen (DeckDetailScreen) for further editing

## Entry Point

The Decks List screen (`decks_list_screen.dart`) already has an import button in the AppBar (line 82-85, mobile only) that handles `.json`/`.tsdeck` file import. The bottom bar has "Save Board" and "New Deck" buttons.

**Approach:** Add "Import from Decklist" as a third bottom bar button, or add it to the existing AppBar import button as a second import option (sheet with "Import Deck File" vs "Import from Decklist"). The AppBar approach keeps the bottom bar clean and groups import actions together.

## Deck List Parser

Must handle all common export formats:

| Format | Qty pattern | Example |
|--------|------------|---------|
| Standard | `<n> <name> (<set>) <num>` | `1 Delina, Wild Mage (AFR) 317` |
| Bare | `<n> <name>` | `1 Delina, Wild Mage` |
| X-suffix | `<n>x <name> (<set>) <num> [<type>]` | `1x Biogenic Ooze (tmc) 49 [Creature]` |
| Star-prefix | `*<n> <name>` | `*1 Biogenic Ooze` |
| Name only | `<name>` | `Biogenic Ooze` |

### Parsing Rules

1. Skip blank lines, section headers (`[Creatures]`, `[/deck]`, `[deck title=...]`), and comment lines
2. Strip quantity prefix: match `^\*?(\d+)x?\s+` or treat whole line as name with implicit qty 1
3. Extract card name: everything after qty prefix up to first `(` or `[` or end of line
4. Trim whitespace from card name
5. For split/DFC cards (`/` or `//` separator), match on BOTH the full name and the front face name independently
6. Extract deck title from `[deck title=...]` if present — use as default deck name

### Matching Against Token Database

- For each extracted card name, search all `TokenDefinition.reverseRelated` lists for that card name
- Match should be case-insensitive
- A single card may produce multiple different token types (e.g., Academy Manufactor creates Clue, Food, and Treasure)
- Multiple cards may produce the same token — deduplicate tokens in the result, but track which cards reference each token
- Token database is already loaded async via `TokenDatabase.loadTokens()` — reuse the existing instance, don't reload

### Building a Reverse Lookup Index

For performance, build a one-time `Map<String, List<TokenDefinition>>` keyed by lowercase card name from all `reverseRelated` entries. This avoids O(n*m) scanning on every card in the decklist.

## Confirmation Screen

Show a list of matched tokens, each displaying:
- Token name and P/T (if applicable)
- Color identity (use existing `ColorUtils.gradientForColors()` for visual indicator)
- Which card(s) from the decklist create this token (subtitle text)
- First available artwork thumbnail (from `TokenDefinition.artwork[0]`)

Unmatched cards (no tokens found) are silently ignored — most cards in a deck won't create tokens.

If zero tokens are detected, show a message like "No tokens found for this decklist" with option to go back.

## Deck Creation

On confirm:
- Create a new `Deck` object following existing `DeckProvider.saveDeck()` pattern (auto-assigns timestamps, order)
- Default name: deck title from `[deck title=...]` if found, otherwise "Imported Deck"
- Auto-detect `colorIdentity` from the token templates (same pattern as existing save flow — collect all colors from templates, WUBRG-order them)
- Populate `templates` with `TokenTemplate` for each confirmed token:
  - `name`, `pt`, `abilities`, `colors`, `type` from `TokenDefinition`
  - `artworkUrl` from first `artwork` entry's URL
  - `artworkSet` from first `artwork` entry's set code
  - `artworkOptions` from full `artwork` list (preserves all variants for later selection)
  - `order` assigned sequentially (1.0, 2.0, 3.0...)
- Navigate to `DeckDetailScreen` for the new deck (user can rename, reorder, add/remove tokens, edit artwork)

## Decisions

- **Entry point:** Decks List screen — group with existing import button in AppBar
- **Token quantities:** All tokens start at qty 1, no adjustment on confirmation screen (user edits in deck detail after)
- **Artwork:** Auto-select first available artwork variant from the token database for each matched token
- **Reuse existing patterns:** DeckProvider.saveDeck(), DeckDetailScreen for post-creation editing, TokenTemplate model, ColorUtils for color display
