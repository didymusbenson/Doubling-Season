# Migration-safe, one-time fresh board

**Status: DEFERRED / SPECULATIVE / NOT IMPLEMENTED.** See [scope](README.md).

## Confirmed intent

After safely importing persistent TS content, start the user with a fresh clear
board/game. Do not attempt to preserve the old active match as the new active
match. This is a migration boundary, not permission to erase data now or on
ordinary future app updates.

A clean board must not mean an empty collection. Existing decks become reusable
TT configurations; custom tokens, artwork, supporter ownership and preferences
survive through the [migration contract](migration.md).

## Data boundary

| Category | Proposed first migrated launch |
|---|---|
| Saved decks/presets and reusable utility configurations | Preserve and validate. Do not zero or rewrite the templates as if they were live instances. |
| Custom-token definitions, local images, credits and art preferences | Preserve, copy/remap and validate. |
| Supported settings, favorites, ownership/cosmetics | Preserve or explicitly map. |
| Old active token instances, quantities, tap/sickness state and token counters | Do not activate on the new board; retain in recovery snapshot. |
| Old active life, commander damage, player counters, Monarch/Blessing/Initiative, Day/Night | Initialize from the chosen fresh-game policy; no old active claims/damage carried across. |
| Mana, storm and other temporary utility values | Reset as live game state, while preserving reusable configuration separately. |
| Old history, undo receipts and pending commands | Never replay into the fresh game. Keep recovery history separate from normal new-game undo. |
| Player identities/appearance | Preserve durable choices where they exist and can be mapped. Do not invent opponents or transfer one identity to every seat. |

Exact initial life, initial player count within the existing 2–4-player scope,
and utility defaults remain open.
Whether the initial board is completely empty or offers to load a migrated preset
also remains open. The owner requested a fresh clear board, so no automatic
recreation of the prior live tokens should be assumed.

## Proposed transaction and retry behavior

The fresh-game transition is coupled to persistent migration success:

1. Snapshot the legacy installation and migrate persistent content to staging.
2. Verify and reopen all required destination content before preparing a reset.
3. Create a new session identity and fresh board using explicit defaults. Do not
   mutate the legacy match in place or emit normal gameplay/rule triggers.
4. Commit destination content, fresh session and a versioned completion marker
   atomically, or use a recovery journal that gives equivalent all-or-nothing
   behavior. The marker identifies the source snapshot and migration version.
5. Only then show the new board as the active game.

On interruption before commit, resume staging or revert to the intact source.
On interruption after commit but before UI acknowledgement, recognize the durable
completion and load the committed game. Never clear it again just because the
onboarding screen did not finish. A future schema migration must not reuse this
one-time reset indiscriminately.

Normal launch, folding, unfolding, rotation, resizing, choosing phone view,
loading a preset and changing focused presentation do **not** invoke this reset.
A user-requested later New Game is a separate, deliberate gameplay operation.
Do not call the existing `resetGame()` blindly from viewport detection.

## Recovery and UX

Keep a private legacy snapshot with references to its art until an explicit
retention policy is approved. Recovery must not merge old counters or history
into a new match already in progress. A deliberate restore workflow would need
its own scope and conflict rules.

Explain the transition briefly in-context: saved configurations/content retained,
active game starts fresh. Avoid routine snackbars or a wall of migration prose.
Unresolved conversion problems must remain actionable; never report successful
migration while silently dropping a user's deck or images.

## Acceptance criteria

- All migrated decks and images remain available after the clear board is shown.
- New session has no old token instances, temporary values, claims or undo replay.
- Crash at every transaction boundary cannot leave a cleared source and incomplete
  destination, nor trigger a second reset after the user starts playing.
- Repeated launches and view/posture changes preserve newly entered game state.
- Disk-full, failed image copy, unknown schema and invalid destination leave
  recoverable original content untouched.
- A valid retained recovery snapshot is distinguished from a normal game archive;
  neither is claimed present unless actually written and checked.

No deletion/cleanup implementation, retention duration or automatic source purge
is approved by this document.
