# Artist Credit

**Status:** Proposed — full feature specification  
**Priority:** Expected to rank above the existing backlog; compare with the
second forthcoming feature before selecting implementation order.  
**Last updated:** 2026-08-29

## Objective

Show the creator credit for token artwork in the **Select Token Artwork** sheet.
The credit appears directly beneath the corresponding set code, for example:

> [Mana artist-nib icon] Steve Prescott

Official Scryfall/MTG artwork uses the credited artist name from source data.
User-uploaded artwork always displays the exact lower-case credit:

> [Mana artist-nib icon] custom

The value must be treated as an opaque display string. Future collaborating
artists may be credited by a social handle such as `@artistname` rather than a
legal name, and this must not require another schema migration.

## Why This Is Required

The app uses full Scryfall card images but commonly crops them for board cards,
token previews, deck rows, and utility backgrounds. Scryfall's official API
guidelines say projects must not crop away the printed copyright or artist name
without listing artist and source elsewhere in the same interface. Users must
be able to identify the artist and image source.

Source: [Scryfall REST API documentation — Use of Scryfall Data and Images](https://scryfall.com/docs/api).

`AboutScreen` already states that images are provided by Scryfall and are
copyright Wizards of the Coast. This feature supplies the missing per-image
artist attribution where selected artwork is inspected.

## Current State

### Source data already contains the artist

The primary token pipeline downloads MTGJSON `AllPrintings`. Its card/token
printing records already include a top-level `artist` value alongside the
Scryfall identifier. `process_tokens_mtgjson.py` currently reads the printing's
set and Scryfall ID but discards artist, producing:

```json
{
  "set": "BRC",
  "url": "https://cards.scryfall.io/..."
}
```

The bundled database currently contains:

- 948 token definitions
- 3,028 artwork variants
- 2,992 distinct Scryfall artwork URLs
- zero persisted artist values

Every bundled database URL has a nonempty artist in the current cached MTGJSON
source. The bulk-generated path therefore needs no live Scryfall requests.

### Current artwork model

`ArtworkVariant` (`lib/models/token_definition.dart`) is Hive type 4 and carries:

| Hive field | Value |
|---|---|
| 0 | `set` |
| 1 | `url` |

It is nested in `TokenDefinition`, `Item`, `TokenTemplate`, `TrackerWidget`,
`ToggleWidget`, and their deck templates. Deck JSON already delegates artwork
serialization to `ArtworkVariant.toJson()` / `fromJson()`.

Artist belongs on `ArtworkVariant`, not `TokenDefinition`: different printings
of the same token can have different artists.

### Selected artwork

An `Item` stores:

- `artworkUrl`
- `artworkSet`
- `artworkOptions`

The selected credit can be resolved by matching `artworkUrl` to the variant in
`artworkOptions`. The inline token artwork-selection flow already restores
missing options from the token database for legacy items when it can match
their token identity.

User uploads are distinguishable without metadata because their URLs begin with
`file://`. Those always resolve to `custom`.

## Data Model

Extend `ArtworkVariant` without changing its existing type ID or field numbers:

```dart
@HiveType(typeId: 4)
class ArtworkVariant {
  @HiveField(0)
  final String set;

  @HiveField(1)
  final String url;

  @HiveField(2, defaultValue: '')
  final String artist;

  ArtworkVariant({
    required this.set,
    required this.url,
    this.artist = '',
  });
}
```

JSON becomes:

```json
{
  "set": "BRC",
  "url": "https://cards.scryfall.io/...",
  "artist": "Victor Adame Minguez"
}
```

Requirements:

- Never change Hive fields 0 or 1.
- Field 2 must default safely for old Hive records.
- JSON parsing must accept old `{set,url}` objects.
- `artist` is the display credit and may contain a name, multiple names, a
  studio, or a social handle.
- Empty artist means unresolved legacy/source metadata, not custom art.
- Regenerate `token_definition.g.dart` after the model change.

No new `Item` or `TokenTemplate` field is required for MVP. Persisting the full
`ArtworkVariant` options retains the selected credit. If later collaboration
art can be selected without being present in `artworkOptions`, add a dedicated
active credit field then rather than preemptively duplicating data now.

## Generator Changes

Update `docs/housekeeping/process_tokens_mtgjson.py`:

1. Read `artist = card.get('artist') or ''` for each printing.
2. Build artwork as `{set, url, artist}`.
3. Change dedup storage from `url -> set` to `url -> {set, artist}`.
4. Preserve artist while merging printings.
5. Emit `artist` on every generated artwork object.
6. Preserve manually supplied artist values in `custom_tokens.json`.
7. Regenerate `assets/token_database.json` and its manifest/checksum through the
   existing token-regeneration workflow.

Do not query Scryfall once per image. The existing MTGJSON bulk source already
contains the needed artist field and avoids unnecessary API traffic.

## Credit Resolution

Add one shared resolver, for example
`lib/utils/artwork_credit_resolver.dart`:

```dart
class ArtworkCreditResolver {
  static String? resolve({
    required String? artworkUrl,
    required List<ArtworkVariant>? artworkOptions,
  }) {
    if (artworkUrl == null || artworkUrl.isEmpty) return null;
    if (artworkUrl.startsWith('file://')) return 'custom';

    final matching = artworkOptions
        ?.where((variant) => variant.url == artworkUrl)
        .firstOrNull;
    final artist = matching?.artist.trim() ?? '';
    return artist.isEmpty ? 'Artist unknown' : artist;
  }
}
```

Rules:

| Artwork state | Display credit |
|---|---|
| No artwork selected | no caption |
| User-uploaded `file://` art | `custom` |
| Variant with artist | exact stored value |
| Non-custom selected URL with missing artist | `Artist unknown` |

Never infer custom status from set code alone; `file://` is the canonical custom
upload signal. New custom-token creation paths should nevertheless construct
their temporary variants with `artist: 'custom'` for consistency.

## Artwork Selection UI

The authoritative MVP surface is the shared **Select Token Artwork** sheet in
`ArtworkSelectionSheet`. Inline token details do not have enough persistent
space for legible attribution, so credit does not appear on the expanded or
compact board card.

Current layout:

```text
[ artwork preview ]
2X2
```

New layout:

```text
[ artwork preview ]
2X2
[Mana artist-nib icon] Steve Prescott
```

Requirements:

- Credit sits directly beneath the set code for each artwork option.
- The currently-selected artwork summary also shows the credit beneath its set
  code when that summary is present.
- Use the exact resolved string without changing capitalization or adding “by”.
- Use a subdued body-small/label style but maintain accessible contrast.
- Long names and handles wrap to a second line rather than ellipsizing away the
  identity.
- Upload/download action tiles without a concrete artwork variant show no
  credit.
- Changing artwork updates the currently-selected summary credit in the same
  rebuild.
- Removing artwork removes the currently-selected summary credit.
- Missing cached files continue using the current cleanup behavior.

Create a small reusable widget such as `ArtworkCreditCaption` so the artist nib,
spacing, typography, fallback behavior, and future handle display stay
consistent.

Use Mana's dedicated artist-nib glyph (`ManaIcons.artistNib`, codepoint
`0xe924`) rather than an emoji or Material approximation. Artist Credit depends
on the locally bundled Mana font introduced by Mana Symbol Rendering and reuses
its pinned mapping and license registration.

## Artwork Surface Scope

Credit appears only in the shared artwork-selection sheet, directly beneath a
variant's set code. This includes token and utility flows wherever they use the
same sheet and variant model. The shared resolver and `ArtworkCreditCaption`
keep option tiles and the currently-selected summary consistent.

The following are explicitly out of scope:

- compact token, tracker, and toggle cards on the board;
- compact and expanded token-detail surfaces outside the artwork sheet;
- deck rows and deck-list previews;
- Brudiclad definition rows;
- search results and creation previews;
- any other card or background-art presentation.

Those surfaces remain visually unchanged. The credit is discoverable by
opening **Select Token Artwork**.

## Custom and Collaboration Artwork

### User uploads

- Always display the Mana artist nib followed by `custom`.
- Do not ask the user for a name or handle in MVP.
- Do not persist `custom` as personal information in preferences.
- Continue deriving it locally from `file://`.

### Future collaborating artists

Bundled collaborator artwork should be represented as an ordinary
`ArtworkVariant` with:

- the hosted artwork URL;
- a stable source/set label appropriate to the collaboration;
- `artist` set to the exact requested handle or credited name.

Examples:

```dart
ArtworkVariant(
  set: 'Tripling Season Artist Series',
  url: 'https://...',
  artist: '@artist_handle',
)
```

The app must display that value verbatim. Linking handles to social profiles,
platform icons, multiple collaborator roles, and artist profile pages are
future collaboration features, not part of this groundwork.

## Hardcoded Artwork Audit

The audit found 56 direct production artwork entries outside the generated
database: 30 utility variants and 26 maintenance/custom-token variants. The two
Rhys migration constants duplicate the credited Rhys variants and do not add
unique images.

### Utility definitions — `lib/database/widget_database.dart`

| Utility | Set | Artist from MTGJSON | Status |
|---|---|---|---|
| Life Total | KLD | Cliff Childs | derivable |
| Poison Counters | ONE | — | **manual resolution required** |
| Radiation Counters | PIP | Skinnyelbows | derivable |
| Energy Counters | PIP | Rafater | derivable |
| Energy Counters | NA | Liz Leo | derivable |
| Experience Counters | CM2 | — | **manual resolution required** |
| Storm Count | 2X2 | Donato Giancola | derivable |
| Commander Tax | CMM | Mike Bierek | derivable |
| The Monarch | CN2 | Mike Bierek | derivable |
| The Monarch | FIC | Nereida | derivable |
| The Monarch | OTC | Volkan Baǵa | derivable |
| The Monarch | LTC | Audrey Benjaminsen | derivable |
| Day/Night | VOW | Johan Grenier | derivable |
| Day/Night | RIX | Yeong-Hao Han | derivable |
| The Initiative | CLB | Ioannis Fiore | derivable |
| Krenko, Mob Boss | FDN | Lie Setiawan | derivable |
| Krenko, Mob Boss | RVR | Ai Nanahira | derivable |
| Krenko, Mob Boss | DDN | Karl Kopinski | derivable |
| Krenko, Tin Street Kingpin | J25 | Viko Menezes | derivable |
| Krenko, Tin Street Kingpin | SLD | Paolo Parente | derivable |
| Krenko, Tin Street Kingpin | WAR | Mark Behm | derivable |
| Cathar's Crusade | INR | Karl Kopinski | derivable |
| Cathar's Crusade | SLD | Stephen Andrade | derivable |
| Academy Manufactor | SLD | Ben Millar | derivable |
| Academy Manufactor | MH2 | Campbell White | derivable |
| Rhys the Redeemed | 2XM | Steve Prescott | derivable |
| Rhys the Redeemed | TLE | Viacom | derivable |
| Hare Apparent | FDN | Milivoj Ćeran | derivable |
| Brudiclad, Telchor Engineer | 2XM | Daarken | derivable |
| Brudiclad, Telchor Engineer | C18 | Daarken | derivable |

Manual gaps, with exact runtime references:

- Poison Counters — `widget_database.dart`, ONE image ID
  `40255bfa-0004-45f1-a31b-17d385f09a95`
- Experience Counters — `widget_database.dart`, CM2 image ID
  `1374bfa2-9714-486d-90aa-7a9b8d8ef3a8`

Both images exist in cached MTGJSON but their `artist` values are null. Do not
guess; resolve them from the printed credit or another authoritative record
before implementation acceptance.

### Manual token definitions — `docs/housekeeping/custom_tokens.json`

| Definition | Set | Artist from MTGJSON |
|---|---|---|
| Scute Swarm | DSC | Alex Konstad |
| Scute Swarm | SLD | Jason Loik & Matthew Cohen |
| Scute Swarm | ZNR | Roman Kuteynikov |
| Banshee of the Dread Choir | CMA | Anthony Palumbo |
| Battle Angels of Tyr | CLB | Fajareka Setiawan |
| Broodbirth Viper | C15 | Mathias Kollros |
| Caller of the Pack | CMA | Ryan Yee |
| Chittering Dispatcher | M3C | Jehan Choo |
| Conclave Evangelist | CLU | John Tedrick |
| Dalek Squadron | WHO | Hector Ortiz |
| Elturel Survivors | CLB | Zoltan Boros |
| Genasi Enforcers | CLB | Joshua Raphael |
| Gnoll War Band | CLB | Ben Wootten |
| Goldlust Triad | TDC | Arif Wijaya |
| Hammers of Moradin | CLB | Justine Cruz |
| Herald of the Host | CMM | Nils Hamm |
| Polygoyf | M3C | Helge C. Balzer |
| Scion of Calamity | LCC | Crystal Sully |
| Scurry of Squirrels | BLC | Izzy |
| Sumala Rumblers | CLU | Leon Tukker |
| Tabaxi Toucaneers | CLB | Filipe Pagliuso |
| The Master, Multiplied | WHO | Lie Setiawan |
| Tiamat's Fanatics | CLB | David Auden Nash |
| Warchief Giant | CM2 | Slawomir Maniak |
| Wizards of Thay | CLB | Josh Hass |
| Wyrm's Crossing Patrol | CLB | Edgar Sánchez Hidalgo |

Add the listed artist to each artwork object. This file feeds the generated
bundled database, so these are shipped metadata rather than documentation-only
examples.

### Rhys migration constants

`lib/providers/tracker_provider.dart` duplicates the TLE and 2XM URLs to migrate
an unreleased default. When it rebuilds `artworkOptions`, include:

- 2XM — Steve Prescott
- TLE — Viacom

### Documentation-only URLs

Rhys, Brudiclad, Academy Manufactor, and Hare Apparent release/spec documents
repeat some runtime URLs. They are not parsed into the app and do not require
schema changes, though examples should include artist when edited in the future.

## Implementation Sequence

1. Add backward-compatible `artist` field to `ArtworkVariant` and regenerate its
   Hive adapter.
2. Add the shared resolver and `ArtworkCreditCaption` widget.
3. Update the MTGJSON generator to retain per-variant artist.
4. Populate all entries in `custom_tokens.json` from the audit table.
5. Populate all hardcoded utility variants and Rhys migration variants.
6. Manually resolve Poison Counters and Experience Counters.
7. Regenerate and validate `token_database.json` plus manifest.
8. Add the caption beneath set codes in the shared artwork-selection sheet,
   including its currently-selected summary.
9. Verify old Hive data, old deck JSON, custom tokens, and custom uploads.

## Files Expected to Change

| File | Change |
|---|---|
| `lib/models/token_definition.dart` | add `ArtworkVariant.artist` and JSON support |
| `lib/models/token_definition.g.dart` | regenerated Hive adapter |
| `docs/housekeeping/process_tokens_mtgjson.py` | retain artist per printing/URL |
| `docs/housekeeping/custom_tokens.json` | add 26 manual artist values |
| `assets/token_database.json` | regenerated artist-bearing artwork variants |
| `assets/token_manifest.json` | regenerated checksum/version metadata |
| `lib/database/widget_database.dart` | add artist to 30 hardcoded variants |
| `lib/providers/tracker_provider.dart` | preserve artist in Rhys migration options |
| `lib/utils/artwork_credit_resolver.dart` | **new** centralized resolution |
| `lib/widgets/artwork_credit_caption.dart` | **new** shared caption UI |
| `lib/widgets/artwork_selection_sheet.dart` | captions beneath variant set codes and selected summary |
| `lib/widgets/new_token_sheet.dart` | label staged custom variants `custom` |
| `lib/providers/deck_provider.dart` | no structural change expected; verify JSON round trip |

## Open Decisions

1. **Unknown fallback wording?** Proposed `Artist unknown` for unresolved
   non-custom images so missing attribution is visible during testing.
2. **Poison Counters artist?** Manual authoritative lookup required.
3. **Experience Counters artist?** Manual authoritative lookup required.
4. **Future collaborator links?** Deferred. Store/display the requested handle
   now; add URL/profile behavior only with a collaboration-specific feature.

## Acceptance Test Checklist

### Data generation

- [ ] Regeneration emits `artist` on every artwork object with source data.
- [ ] All 2,992 generated Scryfall URLs have a nonempty artist.
- [ ] All 26 `custom_tokens.json` URLs retain the audited artist.
- [ ] All 30 utility variants have a resolved artist before release.
- [ ] Poison Counters and Experience Counters use manually verified credits.
- [ ] No per-artwork live Scryfall API request is introduced.
- [ ] Token database dedup identity remains unchanged.

### Migration and persistence

- [ ] Existing Hive `ArtworkVariant` records load with empty artist safely.
- [ ] Existing token/deck data boots without loss.
- [ ] New artist values survive token creation, copying, stack splitting,
      Brudiclad transformation, deck save/load, duplicate, export, and import.
- [ ] Old schema deck JSON imports successfully with unresolved credits handled.
- [ ] Custom token definitions stored in the Hive custom-token box round-trip.

### Artwork-selection sheet

- [ ] Every concrete database artwork option shows the Mana artist nib and
      artist name directly beneath its set code.
- [ ] The currently-selected summary shows the same credit beneath its set
      code.
- [ ] Switching variants immediately switches the selected-summary artist.
- [ ] Long artist names and joint credits wrap without clipping.
- [ ] Removing artwork removes the selected-summary caption.
- [ ] Upload/download action tiles show no artist caption.
- [ ] Missing artist displays the chosen visible fallback.
- [ ] Web and native artwork sheets render the same credit.

### Custom artwork

- [ ] User-uploaded artwork shows the Mana artist nib and exactly `custom`.
- [ ] Replacing one custom upload with another remains `custom`.
- [ ] Switching from custom to Scryfall art restores the official artist.
- [ ] Deleting a missing/stale custom file removes both preview and caption.

### Utilities

- [ ] Utility artwork variants show their artist beneath the set code in the
      shared artwork-selection sheet.
- [ ] All hardcoded utility artwork choices update the selected-summary credit
      when switched.
- [ ] Rhys migration retains 2XM/TLE credit metadata.
- [ ] Compact utility cards remain visually unchanged.

### Non-regression

- [ ] Artwork cache/download/crop behavior remains unchanged.
- [ ] Token cards, expanded inline details, deck rows, search/creation previews,
      and the Brudiclad picker remain visually unchanged.
- [ ] Artist is not added to token composite identity or merge compatibility.
- [ ] User-uploaded files collect no new personal metadata.
- [ ] iOS, Android, web, and desktop builds parse the expanded JSON schema.
