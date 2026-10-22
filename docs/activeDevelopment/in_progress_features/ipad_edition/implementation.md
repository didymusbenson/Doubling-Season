# First implementation

**Started:** 2026-10-21 (America/Phoenix). **Status:** implementation and integration in progress; not release accepted.

The user authorized a complete first implementation of the updated tablet app,
not a disposable demonstration. The implementation branch starts from the latest
specification checkpoint, `0eea598` on `docs/tablet-product-keyboard-decisions`.
The entire dossier has moved from `todo_features` to `in_progress_features`.
Accepted product decisions remain authoritative; historical proposed designs
are not silently promoted to accepted product requirements.

## Product and code boundary

- Independent Flutter app: `apps/tablet`; working development label **Tripling Table**.
- Development identifiers: iOS `LooseTie.Tripling-Table` (iPad device family), Android
  `com.loosetie.triplingtable`; web target included. No store name, product IDs,
  production Android signing or release submission has been selected/performed.
- Existing phone app source, entry point, identifiers, Hive adapters and boxes
  remain untouched. The root package is a path dependency for catalog/domain reuse.
- New JSON schema, dedicated Hive namespace, a serialized command writer and
  checksummed complete current/previous generations. State/history publication
  follows awaited storage acknowledgement.
- Stable persistent seat customization is separate from active game membership,
  visual slots, token artwork and source-specific commander damage.
- Life, mana, board/rule changes, companion creation and global latest-action undo
  use the same session writer. Repeated compatible actions group for 1.5 seconds;
  any different action breaks grouping. Token additions/removals remain distinct.
- Reset and archive transitions retain a maximum of ten full archived games,
  preserve outgoing current state before restore, and retain library/customization.
- Catalog cache and immutable uploaded media are separate from frequently rewritten
  session state. Media references preserve artwork across seats/presets/archives.

## Implementation ownership

Parallel tracks cover the session engine, scoped catalog/rules/board/preset
behavior, and shared editor/custom input. The integrating track owns the native
projects, main board, independent lanes, fixed life regions and validation.
No permanent automated test suite is added, following repository policy.

## Validation at this checkpoint

Platform projects and dependencies are created; source integration is underway.
No build, simulator, browser, recovery or physical-device acceptance is claimed
at this checkpoint. The first complete builds and actual UI exercises will be
recorded here with their failures and repairs. Physical seated/multitouch,
VoiceOver, native picker, battery/thermal and store purchase gates require
separate evidence and will not be inferred from a compiler result.
