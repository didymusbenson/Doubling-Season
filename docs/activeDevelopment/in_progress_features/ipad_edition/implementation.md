# First implementation

This is the historical first-pass record at `dcac16b`. The independent review
and 2026-10-22 correction supersede any broad parity implication below; see
[the corrective tracker](corrective_iteration.md). In particular, planning
commits `012d9f3` and `c986e53` require full original token functionality,
reuse-first lane adaptation and compact icon-led chrome. They have been
reconciled into the moved dossier without reverting implementation additions.

**Implemented:** 2026-10-21 (America/Phoenix). **Status:** first implementation built and exercised; physical-device/release acceptance remains open.

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
No permanent automated test suite was added in the first pass. The user later
explicitly authorized tablet regression tests for the corrective iteration;
that scoped exception is recorded in `AGENTS.md` and the tablet README.

## Validation during integration

Complete builds passed for web release, Android release APK and iOS simulator
on Flutter 3.41.2/Dart 3.11.0. Tablet and root repository analysis passed with
no issues. Cupertino icon assets are bundled explicitly, resolving the initial
missing-font warning. The new tablet CI workflow repeats analysis and platform
builds for pull requests without deploying either product.

Actual browser interaction at 1133 × 744 (iPad mini landscape logical size):

- Four complete player spaces, independent token/utility lanes and fixed life
  regions render. Three rapid opposing life taps changed only Player 1 from 40
  to 39, grouped as one net -1 action; latest-action undo returned life to 40.
- Onscreen keyboard keys searched for Goblin. Creation added one Goblin only to
  Player 1 with appropriate sickness and loaded artwork. The top player's entire
  editor, results and keyboard render facing the opposite direction.
- Tapping a background player control through the modal margin dismissed the
  editor without opening that control. Repeated after the final commit-on-exit
  refinement: changing an existing token's name and tapping over Player 4's
  background Add control committed the exact name, closed the editor and did not
  open Player 4's editor. All quantities and other players remained unchanged.
- Keep-board reset 4→2 kept the Goblin at zero, cleared sickness, and preserved
  life/utility layout. Reset 2→3 accepted top-right as the empty game-tools slot.
  Restoring the four-player archive returned the count-one Goblin and the prior
  timeline, and both survived a full browser reload.
- Adding an own-commander source, recording one damage, and correcting the ledger
  to zero demonstrated coupled life loss (40→39) and independent correction
  (life remained 39).
- One Player 1 Primal Vigor plus one local Doubling Season changed its next
  Goblin increment into four tokens. History displayed the actual +4 result.
  Player 2's creation preview/output was two Treasures, confirming that only the
  global source applied there. Other boards remained unchanged.
- Saved a one-token/two-utility setup from a five-token live stack, replaced that
  player's setup, observed zero quantity with life still 39 and the other
  player's two Treasures intact, then undid the replacement as one history action.
- Added ten white mana, locked white, and added one blue. Empty preserved the
  locked ten white and cleared blue; conversion to blue then moved all ten white
  into blue while retaining the white lock. This exercises the rule that locks
  protect against Empty only, not conversion.
- Hardware key events entered the full text `Krenko` and `goblins`; onscreen keys
  also work. Web field accessibility labels expose their current values. A low
  commander-entry field scrolls fully above the keyboard when activated.
  The browser automation's bulk `typeText` path delivered only its first
  character; individual physical key events and onscreen entry succeeded. This
  does not establish software IME/composition support.

The app also launched successfully on an iPad mini A17 Pro simulator (iOS 26.2).
Its complete four-player portrait and landscape boards rendered. Temporary
Maestro flows selected a Treasure, created it, dismissed the workspace through
the outside margin, and verified Player 1's resulting token control. The
[portrait screenshot](validation/ipad-mini-portrait.png) shows the real native
result with artwork. Flows were kept outside the repository and discarded.
This is simulator evidence, not physical seated usability or multitouch validation.

Integration review corrected queued utility increments, bound toggles, split
status policy, custom-rule order, retryable image/store failures, profile-art
undo conflicts, and effective token-history summaries. Input review corrected
focus-independent hardware handling, field visibility, web/native accessibility
semantics, duplicate action races, close-time input races and reset-slot
initialization. Failed-draft keys include immutable game generation.

## Product/release boundaries

- The app is fully local and independent of the phone app. Native uploaded media
  is retained immutably to protect historical artwork; reclamation is deferred.
- Custom keyboard provides Latin/symbol/numeric keys, grapheme-safe deletion and
  selection, clipboard and hardware input. Full multilingual software composition
  is not implemented; native and assistive-technology validation remains open.
- Failed editor drafts survive dismissal/reopening within the running app. The
  acknowledged game is durable; uncommitted drafts do not survive process death.
- Store product IDs, final product name, production Android signing and store
  provisioning remain external release setup. Optional supporter purchase code
  and restore paths exist but live purchases are not configured or validated.
- The initial Android release artifact uses development signing; it is an
  installable validation build, not an approved store release.

Physical seated/multitouch, VoiceOver, native picker, interruption/container
corruption, multi-window writers, battery/thermal and store purchase gates
remain unverified. No release acceptance or store readiness is claimed.
The detailed acceptance matrix and domain edge-case inventory retain their
unrun status wherever the specific case was not exercised above. This dossier
stays in `in_progress_features` until that acceptance work is complete.
