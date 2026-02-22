# Artwork Display Implementation Pattern

**Reference implementation:** `lib/widgets/token_card.dart` (lines 565-727)

## Two Display Modes

- **Full View** (`fullView`): `CroppedArtworkWidget(fillWidth: true)` — scales to fill card width, crops height, centers vertically
- **Fadeout** (`fadeout`, default): `CroppedArtworkWidget(fillWidth: false)` — scales to fill height, crops width, aligns right. Uses `ShaderMask` with `LinearGradient` (stops: [0.0, 0.50]) for left-edge fade

## Stack Layer Order

Always: Base background → Artwork → Content

Use `Positioned.fill()` as the artwork wrapper inside a `Stack`.

## Key Values

- Crop percentages: 8.8% left/right, 14.5% top, 36.8% bottom
- Fadeout: artwork constrained to right 50% of card width
- Text/button backgrounds: semi-transparent `cardColor` (0.85 alpha) for readability over artwork
- Reactive selector: `Selector<SettingsProvider, (bool, String)>` watches both `summoningSicknessEnabled` and `artworkDisplayStyle`

## Adding Artwork to a New Card Type

1. Check `TokenCard` first — use same layer order and alpha values
2. Use `CroppedArtworkWidget` with appropriate `fillWidth`
3. Wrap artwork in `Positioned.fill()` inside a `Stack`
4. Place content layer above artwork in the Stack
5. Use semi-transparent backgrounds on text/buttons for readability
