# Feature: Data Export/Import

**Status:** Planning
**Priority:** Low (nice-to-have, not urgent)
**Related:** Bug fix release added automatic silent backups — this is the user-facing complement

## Summary

Let users manually export their board state and decks to a JSON file, and import it back. Enables deck sharing between devices/users and provides a user-controlled backup option beyond the automatic silent backup system.

## Scope

**What gets exported:**
- Token definitions (name, P/T, colors, abilities, type)
- Deck structure and templates
- Counter configurations
- Scryfall artwork URLs (these still work on import — they're just web links)

**What does NOT get exported:**
- Custom artwork image files (`file://` paths are device-local, meaningless elsewhere)
- On import, tokens that had custom artwork come back with no artwork selected
- User can re-pick artwork manually after import

## Recommended Approach

**Option C: Metadata-only with a note**
- Export as a plain JSON file (small, easy to share)
- On import, if a token had custom artwork, show a subtle indicator so the user knows to re-select it
- No zip files, no bundled images, no heavy infrastructure

## Why not bundle images?

- Zip creation/extraction adds complexity and dependencies
- Larger files make sharing harder
- Goes against the app's lightweight philosophy
- The primary value is recovering deck *configurations* — artwork is secondary and re-selectable

## Open Questions

1. Where does the user trigger export/import? (Settings screen? Deck management?)
2. Share sheet integration or just save to files?
3. Should import merge with existing data or replace it?
4. File naming convention for exports?
