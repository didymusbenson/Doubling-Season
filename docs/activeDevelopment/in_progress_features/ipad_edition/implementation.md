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

## Validation during integration

Initial complete builds passed for web release, Android release APK and iOS
simulator on Flutter 3.41.2/Dart 3.11.0. Root repository analysis also passed with
no issues. Final source refinements after those builds require another build.

Actual browser interaction at 1133 × 744 (iPad mini landscape logical size):

- Four complete player spaces, independent token/utility lanes and fixed life
  regions render. Three rapid opposing life taps changed only Player 1 from 40
  to 39, grouped as one net -1 action; latest-action undo returned life to 40.
- Onscreen keyboard keys searched for Goblin. Creation added one Goblin only to
  Player 1 with appropriate sickness and loaded artwork. The top player's entire
  editor, results and keyboard render facing the opposite direction.
- Tapping a background player control through the modal margin dismissed the
  editor without opening that control. This will be repeated after the final
  commit-on-exit editor refinement.
- Keep-board reset 4→2 kept the Goblin at zero, cleared sickness, and preserved
  life/utility layout. Reset 2→3 accepted top-right as the empty game-tools slot.
  Restoring the four-player archive returned the count-one Goblin and the prior
  timeline, and both survived a full browser reload.
- Adding an own-commander source, recording one damage, and correcting the ledger
  to zero demonstrated coupled life loss (40→39) and independent correction
  (life remained 39).

The app also launched successfully on an iPad mini A17 Pro simulator (iOS 26.2).
Its complete four-player portrait board rendered without clipping. This is
simulator evidence, not physical seated usability or multitouch validation.

Integration review corrected queued utility increments, bound toggles, split
status policy, custom-rule order, retryable image/store failures, profile-art
undo conflicts, and effective token-history summaries. Browser input uncovered
a hardware-text/focus problem and reset-slot initialization issue; repairs are
being integrated and must be re-exercised before calling those cases passed.

Physical seated/multitouch, VoiceOver, native picker, interruption/container
corruption, multi-window writers, battery/thermal and store purchase gates
remain unverified. No release acceptance or store readiness is claimed.
