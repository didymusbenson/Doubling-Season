# Import from Decklist

Create tokens from a pasted deck list by matching card names against the token database's `reverse_related` field.

## User Flow

1. User taps import button on Decks List screen → selects "Import from Copied Decklist"
2. App reads clipboard, parses the decklist, matches card names against `reverseRelated` in token database
3. If tokens found: full-screen "Tokens Detected" confirmation screen with artwork, color borders, and source card attribution
4. User confirms → new deck created with token templates, navigates to DeckDetailScreen for editing
5. If no tokens found: dialog with "Try Again" (re-reads clipboard) or "Cancel"

## Deck List Parser (`lib/utils/decklist_parser.dart`)

Handles all common export formats:

| Format | Qty pattern | Example |
|--------|------------|---------|
| Standard | `<n> <name> (<set>) <num>` | `1 Delina, Wild Mage (AFR) 317` |
| Bare | `<n> <name>` | `1 Delina, Wild Mage` |
| X-suffix | `<n>x <name> (<set>) <num> [<type>]` | `1x Biogenic Ooze (tmc) 49 [Creature]` |
| Star-prefix | `*<n> <name>` | `*1 Biogenic Ooze` |
| Name only | `<name>` | `Biogenic Ooze` |

Skips blank lines, section headers (`[Creatures]`, `[/deck]`, etc.). Handles split/DFC cards with `/` and `//`. Extracts deck title from `[deck title=...]`.

## Reverse Lookup Index (`lib/database/token_database.dart`)

`Map<String, List<TokenDefinition>>` built on token load from all `reverseRelated` entries, keyed by lowercase card name. O(1) lookups via `findTokensByCardName()`.

## Entry Point (`lib/screens/decks_list_screen.dart`)

Import button in AppBar shows choice sheet:
- "Import from Copied Decklist" → `importFromClipboardDecklist()`
- "Import Tripling Season Deck File" → file picker for `.json`/`.tsdeck`

## Confirmation Screen (`lib/screens/decklist_import_screen.dart`)

- Artwork pre-cached in `initState`, `setState` after downloads complete so FutureBuilders refresh
- Token cards use Stack pattern with ClipRRect to prevent corner bleed through gradient borders
- Color identity borders via `GradientBoxBorder` + `ColorUtils.gradientForColors()`
- Source card attribution in subtitle ("From: Beast Within, Garruk Wildspeaker")

## Deck Creation

- Auto-detects color identity from templates (WUBRG-ordered)
- Default name from `[deck title=...]` or "Imported Deck"
- TokenTemplates with artwork from first variant, full artworkOptions preserved
- Navigates to DeckDetailScreen via pushReplacement

## Decisions

- **One-tap clipboard flow** — no text field, reads clipboard directly
- **Token quantities:** All tokens start at qty 1, user edits in deck detail after
- **Artwork:** Auto-select first available variant, pre-cache on confirmation screen
