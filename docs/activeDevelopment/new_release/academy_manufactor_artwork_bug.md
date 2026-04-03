# Academy Manufactor (and Krenko) Artwork Bug

## Status: Fixed and tested

## Symptoms

- Academy Manufactor creates Clue/Food/Treasure tokens with **wrong artwork** — different art than what the same tokens show when created through normal token search
- Cropping looks off because it's a completely different image, not a cropping issue per se
- **Only happens when no matching stack exists on the board.** If a correctly-created Treasure is already on the board, Manufactor adds to that stack (correct). If no Treasure exists, it creates a new one with wrong art.

## Root Cause (Two bugs)

### Bug 1: Wrong artwork selected
`createAcademyManufactorTokens()` and `createGoblinToken()` always used `definition.artwork.first` — the first artwork variant in the database array — instead of checking the user's artwork preference via `ArtworkPreferenceManager`.

### Bug 2: Wrong cropping after download
After downloading artwork from Scryfall, both methods overwrote `artworkUrl` with `file://${file.path}`. This caused `getCropPercentages()` to treat the image as custom artwork (zero crop) instead of applying the standard Scryfall crop values (8.8% left/right, 14.5% top, 36.8% bottom).

The normal token creation flow (token_search_screen.dart) keeps the original Scryfall URL after download and lets `getCachedArtworkFile()` resolve the local file via hash lookup — preserving correct crop behavior.

## Fix Applied

1. Both methods now check `ArtworkPreferenceManager.getPreferredArtwork(tokenIdentity)` before falling back to `artwork.first`
2. Both methods now keep the original Scryfall URL after download (matching the normal flow) instead of converting to `file://`

## Testing

- Tested by user on 2026-04-02 — confirmed fix resolves both artwork selection and cropping issues

## Affected Code

| Method | File | Fix |
|--------|------|-----|
| `createAcademyManufactorTokens()` | token_provider.dart | ArtworkPreferenceManager check + keep Scryfall URL |
| `createGoblinToken()` | token_provider.dart | ArtworkPreferenceManager check + keep Scryfall URL |
