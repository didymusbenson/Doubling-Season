# Mana Symbol Rendering

**Status:** Implemented — pending manual acceptance and visual refinement

**Priority:** Active acceptance testing; see `../NextFeature.md`

**Last updated:** 2026-08-27

## Objective

Render brace-delimited Magic symbols in read-only rules text using the Mana
icon font by Andrew Gioia. Examples:

| Stored text | Read-only display |
|---|---|
| `{T}: Add {G}.` | official-style tap glyph, then a green mana pip |
| `{2}, {T}, Sacrifice this token: Draw a card.` | generic 2 pip and tap glyph |
| `Add {C}.` | colorless mana pip |
| `{CUSTOM}` | unchanged as `{CUSTOM}` |

This is a display-only transformation. Raw rules text remains unchanged in the
token database, Hive models, deck data, editors, import/export, and rules
engine.

## Library Decision

Use the **Mana** pictographic font:

- Project: https://mana.andrewgioia.com/
- Source: https://github.com/andrewgioia/mana
- Pinned version: **1.18.0**
- Font license: SIL Open Font License 1.1
- CSS/Sass/Less license: MIT; these web assets are not needed by Flutter
- Underlying mana, tap, and card-symbol designs: copyright Wizards of the Coast

Bundle the original `mana.ttf` locally. Do not load the font from a CDN and do
not depend on an NPM or Flutter wrapper package. Pin the source version and file
checksum in the implementation notes so upstream codepoint changes cannot alter
the app silently.

### Existing local precedent

The local Disa's Diary Flutter project already demonstrates this integration:

- `../Disas-Diary/disas_diary_flutter/assets/fonts/mana.ttf`
- `../Disas-Diary/disas_diary_flutter/assets/fonts/OFL.txt`
- `../Disas-Diary/disas_diary_flutter/lib/widgets/mana_icons.dart`
- `../Disas-Diary/disas_diary_flutter/docs/ManaFontReference.md`

Reuse the asset-registration and `IconData` pattern, not the files blindly.
Disa's exposed mapping is incomplete, its reference still describes the old
`.ms-p` Phyrexian alias, and its bundled license is not explicitly registered
with Flutter's `LicenseRegistry`.

## Licensing and Policy Requirements

1. Copy the complete Mana `OFL.txt` beside the bundled font.
2. Register the notice with Flutter's `LicenseRegistry` so it appears in the
   existing **View Open Source Licenses** screen.
3. Preserve the copyright and Reserved Font Name `Mana` notice.
4. Bundle the font unmodified. If the font is ever subset or altered, treat it
   as a modified OFL font and do not use the reserved name without permission.
5. Keep the existing About-screen Wizards/Scryfall and unofficial Fan Content
   disclosures.
6. Use the symbols functionally in rules text and controls, not in the app icon,
   splash screen, store identity, or promotional branding.
7. Keep the app and all symbol-rendered functionality free and outside any
   paywall. Donations may not gate access.

The font license permits embedding and redistribution in software. It does not
separately license Wizards' symbol artwork; that use continues under the app's
unofficial, free Fan Content posture.

## Current Database Coverage

The current `assets/token_database.json` contains these recognized brace codes:

| Code | Occurrences | Mana glyph |
|---|---:|---|
| `{T}` | 37 | tap |
| `{1}` | 19 | generic 1 |
| `{2}` | 14 | generic 2 |
| `{B}` | 9 | black |
| `{G}` | 8 | green |
| `{C}` | 7 | colorless |
| `{R}` | 5 | red |
| `{W}` | 1 | white |
| `{U}` | 1 | blue |
| `{3}` | 1 | generic 3 |
| `{0}` | 1 | generic 0 |

MVP supports all eleven current codes. The parser architecture must also make
future additions straightforward without changing stored data.

## MVP Scope

### Supported symbols

- Tap: `{T}`
- Colored mana: `{W}`, `{U}`, `{B}`, `{R}`, `{G}`
- Colorless mana: `{C}`
- Generic mana: `{0}`, `{1}`, `{2}`, `{3}`

### Rendered surfaces

Render symbols anywhere existing rules or utility description text is displayed
read-only on the active board:

1. `TokenCard` abilities text.
2. `TrackerWidgetCard` description text.
3. `ToggleWidgetCard` description text.
4. `TokenCard` tapped count indicator and tap action button.
5. `TokenCard` summoning-sickness count indicator.
6. `ExpandedTokenScreen` summoning-sickness count row.
7. `TokenSearchScreen` search-result abilities and selected-token creation preview.
8. Shared `DefinitionPreviewCard` subtitles used by deckbuilding and token selectors.

Use one shared rich-text component rather than calling the parser differently
from each card.

### Raw-text surfaces

Continue showing brace syntax unchanged in:

- `ExpandedTokenScreen` editable abilities field;
- `NewTokenSheet` abilities input;
- any other editor or form field;
- database/search matching;
- rules-engine evaluation;
- deck serialization and import/export.

Other detail-view read-only summaries remain deferred. Search results, creation
previews, and shared definition-preview rows use the same renderer so users do
not see raw brace codes while choosing a token.

### Explicitly deferred symbols

- Untap `{Q}`
- Variables `{X}`, `{Y}`, `{Z}`
- Generic values `{4}` through `{20}`, `{100}`, and `{1000000}`
- Hybrid and two-brid symbols such as `{W/U}` and `{2/W}`
- Phyrexian costs
- Snow, energy, acorn, ticket, radiation, card-type, counter, and ability icons

Add these only when the stored token data or a concrete UI feature needs them.
Do not interpret arbitrary words inside braces as symbols.

## Version-Specific Mapping Rule

Mana uses Private Use Area codepoints. Create explicit `IconData` constants for
the pinned font rather than embedding numeric literals throughout widgets.

Important upstream compatibility trap:

- Older Mana documentation used `.ms-p` for Phyrexian.
- Mana 1.18 changed `P` to Pawprint and moved the Phyrexian symbol to `H`.

MVP does not render Phyrexian costs, but this distinction must be documented in
the mapping class so a later extension does not incorrectly render Pawprint.
Never derive a glyph by simply lowercasing an arbitrary brace code.

## Asset Integration

Add the pinned font and license:

```text
assets/fonts/mana.ttf
assets/fonts/Mana-OFL.txt
```

Register the font in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/token_database.json
    - assets/token_manifest.json
    - assets/fonts/Mana-OFL.txt
  fonts:
    - family: Mana
      fonts:
        - asset: assets/fonts/mana.ttf
```

Create `lib/widgets/mana/mana_icons.dart`:

```dart
class ManaIcons {
  ManaIcons._();

  static const fontFamily = 'Mana';
  static const tap = IconData(0xe61a, fontFamily: fontFamily);
  static const white = IconData(0xe600, fontFamily: fontFamily);
  static const blue = IconData(0xe601, fontFamily: fontFamily);
  static const black = IconData(0xe602, fontFamily: fontFamily);
  static const red = IconData(0xe603, fontFamily: fontFamily);
  static const green = IconData(0xe604, fontFamily: fontFamily);
  static const colorless = IconData(0xe904, fontFamily: fontFamily);
  static const generic0 = IconData(0xe605, fontFamily: fontFamily);
  static const generic1 = IconData(0xe606, fontFamily: fontFamily);
  static const generic2 = IconData(0xe607, fontFamily: fontFamily);
  static const generic3 = IconData(0xe608, fontFamily: fontFamily);
}
```

Validate every codepoint against the pinned 1.18.0 font before committing; the
snippet is the expected mapping, not a substitute for that validation.

## Rendering Architecture

### Shared parser

Create `lib/utils/mana_symbol_parser.dart`. It must:

1. Scan text with `RegExp(r'\{([^{}]+)\}')`.
2. Match complete, case-sensitive codes from a fixed allowlist.
3. Emit ordinary `TextSpan`s for surrounding text.
4. Emit a `WidgetSpan` containing `ManaSymbol` for recognized codes.
5. Preserve the entire original substring, including braces, for unrecognized
   or malformed codes.
6. Fast-path strings that contain no `{`.

The parser must not mutate or normalize its input. Adjacent symbols such as
`{1}{B}` render as adjacent widgets without inserting spaces.

### Shared display widget

Create `lib/widgets/mana/mana_text.dart` as the public UI entry point:

```dart
ManaText(
  text: item.abilities,
  style: Theme.of(context).textTheme.bodyMedium,
  maxLines: 3,
  overflow: TextOverflow.ellipsis,
)
```

`ManaText` owns parsing, `Text.rich`, semantics, wrapping, overflow, text scale,
and directionality. Board cards should not assemble spans themselves.

### Symbol widget

Create `lib/widgets/mana/mana_symbol.dart`. It receives a recognized symbol
definition and renders the pinned font glyph.

Mana is a monochrome icon font. The library's web styling supplies the familiar
colored pip backgrounds separately; Flutter must recreate that presentation:

- Colored mana: circular W/U/B/R/G background with contrasting glyph.
- Colorless and generic mana: neutral circular background with contrasting
  glyph, theme-aware where needed.
- Tap: standalone Mana tap glyph colored like surrounding text; no improvised
  `Icons.screen_rotation` substitute.

Use existing `ColorUtils` identity colors as initial app palette values, then
visually compare against familiar printed mana pips. White mana needs a dark
glyph/border rather than white-on-yellow assumptions. Black mana needs enough
contrast in both themes.

### Sizing and baseline

- Start at approximately `1.1 ×` the surrounding font size.
- Use `WidgetSpan` with baseline-aware alignment when possible.
- Validate against one-line and wrapped text at standard and large text scales.
- Keep consecutive pips visually grouped without collapsing or overlapping.
- Do not hardcode one vertical offset for every platform unless device testing
  proves it stable.

## Accessibility

Private-use font glyphs have no useful screen-reader pronunciation. `ManaText`
must provide a semantic expansion and exclude the visual glyph children from
semantics.

Semantic mappings for MVP:

| Code | Spoken text |
|---|---|
| `{T}` | `tap` |
| `{W}` | `one white mana` |
| `{U}` | `one blue mana` |
| `{B}` | `one black mana` |
| `{R}` | `one red mana` |
| `{G}` | `one green mana` |
| `{C}` | `one colorless mana` |
| `{0}` | `zero generic mana` |
| `{1}` | `one generic mana` |
| `{2}` | `two generic mana` |
| `{3}` | `three generic mana` |

Do not use the raw label `{T}` as the accessibility solution. Screen readers
may announce it as punctuation and a letter rather than its game meaning.
Unrecognized codes remain literal in the semantic string.

## License Registration

Because the font is a manually bundled asset rather than a Dart dependency, it
will not automatically appear in `showLicensePage()`. Register it during app
startup using `LicenseRegistry.addLicense`, loading `Mana-OFL.txt` from the asset
bundle, and associate it with a clear package label such as `Mana icon font`.

Manual validation must confirm the existing About-screen **View Open Source
Licenses** flow contains:

- Andrew Gioia's copyright notice;
- Reserved Font Name `Mana`;
- the complete SIL OFL 1.1 text.

## Failure and Fallback Behavior

- Unknown brace code: show original text unchanged.
- Malformed brace syntax: show original text unchanged.
- Missing font asset during development: treat as a build/configuration failure,
  not something silently replaced with a Material icon.
- Unsupported future code: remain literal until deliberately mapped.
- Web font-loading delay: surrounding rules text must remain laid out safely;
  verify the glyph appears after asset load without throwing or corrupting text.

## Performance

The current database contains 103 recognized occurrences, and most board cards
contain none. The primary safeguards are:

- skip RegExp work when the text contains no `{`;
- keep the mapping immutable and static;
- avoid network font loading;
- do not introduce global parsed-span caching before profiling demonstrates a
  need, because spans depend on style, theme, scale, and context.

## Files Expected to Change

| File | Change |
|---|---|
| `assets/fonts/mana.ttf` | **new** pinned Mana 1.18.0 font |
| `assets/fonts/Mana-OFL.txt` | **new** complete license notice |
| `pubspec.yaml` | register font and license asset |
| `lib/widgets/mana/mana_icons.dart` | **new** pinned codepoint constants |
| `lib/widgets/mana/mana_symbol.dart` | **new** glyph/pip presentation |
| `lib/widgets/mana/mana_text.dart` | **new** shared rich-text and semantics UI |
| `lib/utils/mana_symbol_parser.dart` | **new** fixed-allowlist parser |
| app startup/license registration location | register bundled OFL notice |
| `lib/widgets/token_card.dart` | use `ManaText`; replace tap and summoning-sickness indicators |
| `lib/screens/expanded_token_screen.dart` | replace summoning-sickness count-row indicator |
| `lib/widgets/tracker_widget_card.dart` | use `ManaText` for descriptions |
| `lib/widgets/toggle_widget_card.dart` | use `ManaText` for descriptions |
| `lib/screens/token_search_screen.dart` | render result and creation-preview abilities |
| `lib/widgets/definition_preview_card.dart` | render read-only subtitle wildcards |
| `lib/screens/about_screen.dart` | no disclaimer change expected; verify license link |

## Implementation Order

1. Copy the pinned, unmodified font and complete OFL notice from the authoritative
   Mana release; record version and checksum.
2. Register the asset and license.
3. Add validated `ManaIcons` constants for the eleven MVP codes.
4. Implement symbol definitions, visual pip treatment, and semantic expansions.
5. Implement parser and shared `ManaText`.
6. Replace read-only board text on token, tracker, and toggle cards.
7. Run the database wildcard audit again and compare it with the allowlist.
8. Complete cross-platform manual acceptance testing.

## Manual Acceptance Checklist

### Font and licensing

- [ ] Font is pinned to Mana 1.18.0 and bundled locally.
- [ ] Recorded checksum matches the bundled file.
- [ ] App launches and renders symbols without network access.
- [ ] Open Source Licenses shows the complete Mana OFL notice.
- [ ] Existing Wizards unofficial Fan Content notice remains visible.

### Parsing

- [ ] All current codes `{T}{W}{U}{B}{R}{G}{C}{0}{1}{2}{3}` render.
- [ ] Adjacent `{1}{B}` renders as two adjacent pips.
- [ ] Multiple symbols embedded in a sentence preserve punctuation and spacing.
- [ ] `{CUSTOM}`, `{Q}`, `{X}`, `{W/U}`, `{P}`, and `{H}` remain literal in MVP.
- [ ] Empty text, plain text, `{}`, missing braces, and nested braces do not fail.
- [ ] Editing and persisted data retain the original brace-delimited text.

### Visual behavior

- [ ] Tap uses the Mana tap glyph, not a Material rotation icon.
- [ ] W/U/B/R/G/C and generic pips are recognizable and legible.
- [ ] White and black pips meet practical contrast expectations in both themes.
- [ ] Symbols align with surrounding text without clipping.
- [ ] Adjacent pips do not overlap.
- [ ] Wrapping and three-line ellipsis behave like the previous text widget.
- [ ] System text scaling does not clip or detach symbols from their line.
- [ ] Artwork backgrounds do not make symbols unreadable.

### Accessibility

- [ ] VoiceOver and TalkBack announce `tap`, not `left brace T right brace`.
- [ ] Mana colors and generic values receive meaningful spoken labels.
- [ ] Visual glyphs are not announced twice.
- [ ] Unknown brace codes remain audible as literal text.

### Surfaces and platforms

- [ ] TokenCard abilities render Mana symbols.
- [ ] TokenCard tapped tally and tap action button use the Mana tap glyph.
- [ ] Untapped tally and action button retain the previous ready-device icon.
- [ ] Token and expanded-detail sickness tallies use the Mana summoning-sickness glyph.
- [ ] All replaced status glyphs inherit their existing foreground colors.
- [ ] Tracker utility descriptions render Mana symbols.
- [ ] Toggle utility descriptions render Mana symbols.
- [ ] Token-search results render Mana symbols.
- [ ] Selected-token creation previews render Mana symbols.
- [ ] Deckbuilding and token-selector definition previews render Mana symbols.
- [ ] Expanded token editing continues to show raw braces.
- [ ] iOS, Android, web, macOS, and Windows load the bundled font.
- [ ] Typical and deliberately dense boards scroll without visible regression.

## Resolved Decisions

1. Use Mana 1.18.0 rather than homemade or Material approximations.
2. Bundle the font locally rather than use a CDN.
3. Keep all stored text raw and apply symbols only while displaying it.
4. Start with the eleven codes present in the current database.
5. Preserve unknown codes exactly.
6. Use a shared board-text component across tokens and utilities.
7. Provide spoken game meanings rather than raw brace syntax.
8. Do not add a user preference toggle for MVP; raw text remains available in
   detail/editing screens.
9. Do not animate symbols.
10. Keep broader Mana iconography out of scope until a concrete feature needs it.

## Migration and Rollback

No data migration is required. Removing the renderer returns the UI to raw brace
text with no data loss. The only new persistent distribution artifact is the
bundled font and its license notice.

## Implementation Record — 2026-08-27

Implemented the MVP architecture and all eleven currently used brace codes.

- Bundled the unmodified Mana 1.18 font locally.
- Recorded SHA-256
  `a23809f7c0af7f9866734216bdd73bce2cfedd67333f5cde86a9ee066fa69819`.
- Registered the complete OFL notice with Flutter's `LicenseRegistry`.
- Added pinned icon mappings, fixed-allowlist parsing, semantic expansion,
  shared `ManaText`, and reusable pip rendering.
- Integrated read-only descriptions on token, tracker, and toggle board cards.
- Replaced the token card's tap approximation in both the count tally and action
  button with the Mana glyph. The previous ready-device icon remains for untap.
- Replaced the current summoning-sickness indicator on the token card and
  expanded token count row with Mana's dedicated ability glyph.
- Confirmed the iOS simulator debug build succeeds.
- Confirmed a stored `{T}` ability renders as the Mana tap glyph on an existing
  Squirrel token while the stored wildcard remains unchanged.
- Confirmed W/U/B/R/G and generic 0/1 pips render inline in the simulator.
- Confirmed unsupported `{20}`, `{H}`, `{Q}`, and `{P}` remain literal.
- Confirmed token count tallies inherit their black text/icon color while the
  tap action glyph inherits the existing teal control color.

Still requiring manual acceptance:

- colored and generic mana-pip appearance;
- dark-mode contrast;
- large text scaling and screen-reader announcements;
- license notice visibility through the About screen;
- Android, web, macOS, and Windows font loading.
