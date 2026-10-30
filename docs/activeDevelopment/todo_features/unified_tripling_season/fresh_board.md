# First migrated game: preserve Player 1's board

**Status: DEFERRED / SPECULATIVE / NOT IMPLEMENTED.** See [scope](README.md).

## Latest direction supersedes the fresh-board proposal

On 2026-10-30 the owner replaced the earlier clear-board requirement:
**the first migrated game maintains the existing token board state and enabled
utilities where Tripling Table has a counterpart.** The historical filename is
retained so existing links work; it is no longer a reset specification.

Do not clear token quantities, tap/sickness state, token counters or supported
live utility values merely to start the unified app. Do not use preset save/load
as a live-game migration: presets deliberately initialize fresh gameplay values.

## Two independent conversion paths

1. **Saved configurations:** convert every stored deck into a reusable TT preset,
   preserving its configuration, identities and artwork. Normal future preset
   loads retain their deliberate fresh-token/default-utility semantics.
2. **Active board:** translate the actual last saved token instances and enabled
   supported utilities into Player 1 of the destination session, preserving live
   values and relationships. Do not construct it by reloading a saved deck.

The destination remains an N-player game with Player 1 shown in phone view.
Initial opponent count/identities and life defaults not represented in the old
board still require explicit defaults; never manufacture existing match data.

## Mapping and safety boundaries

| Category | Required migration treatment |
|---|---|
| Active token instances | Preserve definition/custom identity, quantity, tapped/summoning-sick counts, counters, ordering and selected art/style/credits. Validate invariants without silently zeroing values. |
| Enabled utilities with a Table counterpart | Preserve configuration and supported live state with an explicit semantic mapping. Verify counter increments, actions, toggle art/state and ownership; matching a display name is not sufficient. |
| Utility entries without a counterpart | Preserve source/recovery data; visible unavailable-item policy is proposed, not a license to silently delete/substitute. |
| Existing life/status values represented by legacy utilities | Explicitly map to canonical Table life/counter/status fields if equivalent; avoid duplicate live trackers. Unsupported/ambiguous mapping remains a release blocker or explicit resolution choice. |
| Saved decks/custom tokens/artwork/preferences/supporters | Preserve through the separate persistent-content migration. |
| Old history/pending operations | Do not replay commands into the new board. Whether history can be translated is separate from preserving the final acknowledged state. Keep recovery material. |

## Proposed transaction and retry behavior

1. Snapshot a consistent legacy installation and its required local artwork.
2. Convert persistent content and independently stage Player 1's live board.
3. Validate quantities, references, enabled utility semantics, saved configurations
   and image hashes. Reopen the destination before declaring it usable.
4. Commit the full destination and versioned migration marker atomically, or use
   a journal with equivalent recoverability across storage boundaries.
5. On retry, resume or recognize that completed migration. Never duplicate tokens,
   replace newly played state with the old board, or clear a later game.

Keep the legacy snapshot under a deliberately selected retention policy. Failure
must leave source content recoverable. Normal restart, fold/unfold, resize and
presentation changes never rerun migration or call a game-reset command.

## Acceptance criteria

- Live tokens keep counts, statuses, counters, identity, art and order after an
  original-app update without uninstalling.
- Enabled supported utilities retain the agreed equivalent state; unsupported
  entries are accounted for, not silently lost.
- Saved decks separately survive and can be loaded on a selected seat without
  conflating a reusable template with the migrated live match.
- Interrupted conversion/commit/first launch is repeatable without duplicates,
  repeated resets or stale state overwriting subsequent gameplay.
- Missing artwork, invalid source, low storage and ambiguous utility mappings
  preserve recovery material and produce actionable outcomes.
- Switching phone/full-table view preserves Player 1's migrated board and all
  hidden players; no gameplay action is inferred from posture.

No live migration, cleanup, automatic source deletion or production cutover is
implemented or authorized by this document.
