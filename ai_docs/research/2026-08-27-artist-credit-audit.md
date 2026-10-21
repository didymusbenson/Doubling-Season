# Artist Credit Codebase Audit

**Date:** 2026-08-27  
**Purpose:** Map current artwork metadata, display paths, and hardcoded image
sources before specifying artist attribution.

## External Requirement

Scryfall's official API documentation says cropped/clipped images must retain
the printed artist/copyright information or provide artist and source elsewhere
in the same interface. It also says users must be able to identify the image's
artist and source. Source: [Scryfall REST API documentation](https://scryfall.com/docs/api).

The app already names Wizards and Scryfall in `AboutScreen`, but cropped artwork
surfaces do not currently show per-image artist attribution.

## Current Data Pipeline

- `docs/housekeeping/process_tokens_mtgjson.py` reads token records from the
  cached MTGJSON `AllPrintings` export.
- MTGJSON already supplies `artist` on the relevant printing records.
- The generator currently emits artwork variants as `{set, url}` and discards
  `artist`.
- `assets/token_database.json` contains 948 token definitions, 3,028 artwork
  entries, and no artist fields.
- `ArtworkVariant` (`lib/models/token_definition.dart`) is the shared persisted
  value object for a printing's set and URL. It is Hive type 4 with fields 0 and
  1 only.
- `Item`, `TokenTemplate`, tracker/toggle models, deck JSON, rules-result artwork
  resolution, and preferences already transport `ArtworkVariant` lists. Adding
  artist to the variant propagates through most of those paths automatically.

Artist is a property of an artwork/printing, not a token definition: two variants
of the same token may have different artists.

## Selected Artwork Resolution

An active token stores `artworkUrl`, `artworkSet`, and its full
`artworkOptions`. Artist credit can normally be resolved by matching the active
URL to the options list. `ExpandedTokenScreen` already backfills options from
the token database when legacy items lack them.

Custom uploads use `file://` URLs and can deterministically resolve to the exact
credit string `custom` without a new preference field.

## UI Surfaces

- `ExpandedTokenScreen._buildArtworkSelectionBox()` is the requested detailed
  token preview. It currently displays an `Artwork` label and a 60px thumbnail,
  with no subtitle.
- `ArtworkSelectionSheet` shows the current selection, variant tiles, and a
  full-image confirmation dialog. It currently shows set codes only.
- `ExpandedWidgetScreen` has a corresponding utility artwork preview and opens
  the same selection sheet.
- Board cards, deck rows, Brudiclad definitions, and deck-list cards use cropped
  artwork as backgrounds without captions.

## URL Inventory

- Generated bundled token database: 2,992 distinct Scryfall URLs. All have a
  nonempty artist in the current MTGJSON cache.
- `docs/housekeeping/custom_tokens.json`: 26 direct URLs across 24 definitions.
  All have artists in MTGJSON.
- `lib/database/widget_database.dart`: 30 direct utility variants. Twenty-eight
  have artists in MTGJSON; Poison Counters and Experience Counters have null
  artist values and require manual resolution.
- `lib/providers/tracker_provider.dart`: two Rhys migration constants, both
  duplicates of credited widget variants.
- No other shipped artwork CDN was found under `lib/`.

The union is 3,022 distinct Scryfall image IDs. Artist metadata is locally
derivable for 3,020; two require manual attribution.

## Persistence Boundary

The backward-compatible schema point is `ArtworkVariant`:

- preserve Hive fields 0 (`set`) and 1 (`url`);
- add field 2 for artist/credit with an empty default for old persisted data;
- make JSON parsing tolerate missing artist fields;
- regenerate the Hive adapter.

No new `Item` field is required if every selected non-custom URL retains a
matching artwork variant. A centralized resolver should handle URL matching,
`file://` custom credit, and unresolved legacy/direct URLs consistently.

## Future Collaborator Compatibility

The credit value should remain an opaque display string rather than assume a
legal name. That allows future bundled variants to carry values such as
`@instagram_handle` or a TikTok identity without another schema change.
