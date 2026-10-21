# Game history and undo

**Status:** requested feature and grouping behavior accepted 2026-10-21; no implementation started. Related decisions: D15–D17, D22/D26/D33; [tracker](03_life_and_game_controls.md), [persistence](06_data_persistence_and_migration.md), [QA](08_delivery_validation_and_risks.md).

## Accepted behavior

Keep game history to support undo, including player life/counter changes, token additions/removals and other gameplay changes. Repeated like actions update the current log line until a different action or sufficient time gap starts a new line. Preserve player attribution and distinguish events that have different gameplay significance.

| Example | Required log behavior |
|---|---|
| A creates one Soldier, then another without an intervening action/gap | Current line grows from “A: Soldier +1” to “A: Soldier +2” |
| A creates then removes a Soldier | Separate “A: Soldier +1” and “A: Soldier −1” lines, even though net quantity is zero |
| A repeats an addition after the grouping window | New line, not an extension of an older settled entry |
| A rapidly adjusts life in both directions to reach the intended value | Settle the net adjustment into one line after roughly **1–2 seconds** without taps |

Wording above is illustrative, not a fixed interface. Creation and removal must never cancel each other out in history: the user specifically wants distinct events visible for possible death-trigger bookkeeping. Recording removal is not proof that a creature died, and a log is not permission to automatically resolve triggers. Define removal operation/reason where available rather than infer all rules events from a negative count.

For life, opposite-direction taps may belong to the same settling adjustment. This is an explicit exception to treating every direction change as a new action. Token add versus remove remains distinct. Exact equivalence keys for other operations, timeout tuning, and treatment of a zero-net life adjustment need design; **a fixed two-second timeout for every action has not been approved**.

## Origin, player attribution and affected seats

Central history, wipes and resets use app/game-level context, not a specific player by default. Preserve player attribution where meaningful (for example a seat-context Soldier addition), but store/display affected seat(s) separately from origin and any attributed actor. A game-level wipe affecting A and B can be labeled “Game: wipe; affected A, B” without asserting that A or B performed it. Exact labels and wipe targeting UI remain open. Position in the center or three-player empty slot never supplies a human identity. Viewing history is read-only, not automatically a loggable gameplay action; whether navigation closes a pending group remains a detailed grouping-policy question. Committed game-level mutations participate in the same chronology and latest-action undo, not a separate stack.

Utility hiding is presentation-only: a confirmed corner-X dismissal retains stored values, unlike a separate clear action. Do not log it as counter/mana removal. Exact history/undo inclusion of utility visibility/order changes remains open under D37; accepted gameplay chronology and reset/archive semantics do not change.

Preset loading is distinct from current-game recovery and pre-reset archive loading. D38 accepts reusable tokens at zero plus utility preferences and optional seat life art, but does not settle midgame replacement/merge, life reset, or history/undo handling of preset loads. Resolve the load command’s write set and log behavior explicitly; never silently erase the timeline or replay old gameplay from a preset.

## Accepted bookkeeping policies

- New commander-damage entry subtracts life as **one undoable action**, including self-source entries. Provide corrections to either ledger or life independently; correcting one must not silently apply the other effect again.
- Life, poison and commander-damage thresholds give warnings, **not automatic elimination or disabled controls**. This does not attempt full rules enforcement or infer a winner.
- A player manually claims monarch; the shared holder transfers explicitly. Day/night is changed manually. Do not infer combat, spells cast or other physical-game events.

Detailed correction controls, warning presentation, remaining runtime/rule, archive-retention and restore-conflict details and UI remain open. These decisions do not approve new optional modes or alter the one player-facing keyboard policy.

## Timeline, undo and recovery decisions

- **Accepted:** one game-wide chronological timeline, with player attribution. It is the game’s history, not separate player histories.
- **Accepted:** undo walks back the latest action globally. No arbitrary selected-entry undo or independent per-player undo stack is promised. A settled grouped action is the intended log/undo unit; final group-boundary details must align with the underlying command order.
- **Accepted:** game state and current-session history are persistent and reload their last saved state. Undo information needed by the accepted contract must be saved coherently with that state; precise write/acknowledgement mechanics still need implementation design and validation.
- **Accepted clarification:** a different action by **any player** closes the active group. P1 Soldier → P2 life → P1 Soldier yields three chronological entries, never a retroactive P1 +2. The user answered “correct.” to that exact example. Do not maintain independent open per-player groups.
- **Accepted:** a pre-reset game archive can load the full last state and timeline from before reset, including historical seat game setup. Retention limits, archive UI and restore conflict handling remain open; statistics are not implied.

Chronological display, global latest-action undo and persistence are settled. Game-wide interruption is also settled. Pre-reset archive restore is accepted. Exact timeout tuning, detailed settlement/undo UI, archive retention and restore safeguards remain open. New replies should update this document and D16/D17/D33 together.

## Full-reset boundary and persistent seats

Two full-reset modes now restart the configured game: Reset with board retains zero-count/no-counter token entries and enabled utilities; Complete reset clears tokens/utilities. Both restore starting life and reset temporary/game statuses. Persistent seat names and color/art survive either mode, including currently hidden seats. See [reset details](03_life_and_game_controls.md).

A successful full reset begins a new game boundary and leaves a restorable archive of the prior full state and chronological timeline. Restore historical seat game setup from that archive, including tokens/utilities cleared from live seats when they were removed; do not reconstruct an old game from cleared current templates. Reusable setup survives only when explicitly kept for remaining seats; removed seats lose live game-specific setup, not persistent name/color/art. Do not infer cross-game undo from latest-action undo: archive loading is distinct. Transactional failure recovery remains required. The group must not absorb post-reset actions into a pre-reset entry; exact pending-draft handling remains design work. Historical attribution must remain stable despite later name/art edits.

**Proposal only:** save/preserve the current game before archive loading so it is not lost. This safeguard has not yet been accepted. Exact historical-versus-current customization conflict handling, retention limits and archive UI also remain open.

## Proposed implementation boundaries, not settled UX

Separate underlying commands, group identity and rendered log entries. A group should retain all constituent commands and before/after/write-set data needed by the chosen undo contract. A grouped “Soldier +2” display must not erase distinct underlying creation outcomes, companions, scoped utility updates or revisions.

Candidate compatibility key: origin context, optional attributed player, affected scope, command kind, target entity or commander/recipient pair, and relevant field/type. Do not coalesce different players, partner sources, same-named but distinct stacks, unrelated counters, add/remove operations or rules revisions merely because the display text matches. Final matching rules must accommodate legitimate new-token additions whose runtime entities differ.

A different action/time gap settles the current group across the whole game. Reset, replacement, failed/cancelled input, keyboard handoff, backgrounding and session changes need explicit settlement policies. A failed/cancelled command must not appear as a successful game mutation. Retry with one CommandId must not duplicate history or state.

Immediate visible life feedback with delayed grouping is a **recommendation**, not an accepted display/commit-timing choice. The user describes life settling about 1–2 seconds after tapping stops. Decide what is preview, what is applied, and what is durable; label pending state honestly. Never equate a settled log line with proven crash durability. Current-game state/history recovery is required; the exact pending-write and acknowledgement protocol must be designed and tested.

Undo must affect only the operation’s defined write set and preserve unrelated later work. Creation/removal undo needs quantities, identities, ordering, counters/status and causally linked rule/utility effects, not just a signed display delta. Coupled commander damage/life is one unit; independent corrections remain independently scoped. Monarch/day-night undo must check shared-state conflicts. Inverse restoration must not emit new ETB/death/gameplay events. Undo targets the global latest action and then walks backward, not an arbitrary earlier item. Whether an undone entry stays visible, gets annotated, or creates a correction entry is still a UI/history policy choice; never hide causality merely to make totals look right.

## Read-only audit: current Tripling Season undo

Source baseline: `d30050bd7a1067058fcdf7e707d3a223124a79fb`, inspected 2026-10-21. These are source findings, not a runtime test of this task.

- [BoardUndoSnapshot](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/services/board_undo_snapshot.dart) captures typed **in-memory** clones of all current item/tracker/toggle Hive records. Restore clears and repopulates all three boxes, deliberately without gameplay events. Useful cloning/restoration semantics; unsafe unchanged for a player-local history undo because it can overwrite another player’s later work. It is not a durable history journal or a single atomic multi-box transaction.
- [ContentScreen board-wipe flow](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/content_screen.dart#L1039-L1143) captures before wiping, attempts rollback on failure and offers immediate non-dismissible **Undo / Accept** after success. Delete-and-reset-rules also captures/restores rules. This is immediate operation undo, not a browsable game history or general selected-entry undo.
- [RulesProvider snapshot](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/providers/rules_provider.dart#L871-L909) stores preset counts and enabled states keyed to existing custom rules. Restore does not recreate deleted rule definitions.
- [Brudiclad action](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/tracker_widget_card.dart#L1171-L1224) also uses the board snapshot for rollback/immediate undo. This is another scoped workflow using a global snapshot, not evidence that every app operation is undoable.

Reuse proven ideas selectively: capture before mutation, restore typed values without re-triggering effects, retain failures and make completion deliberate. The new product still needs player/shared write sets, grouping, history UI, conflict policy and any chosen recovery format. No app code was changed by this audit.

## Acceptance outline

Test repeated additions, add/remove net-zero separation, different-action and timeout boundaries, opposite life taps and the chosen life-settling timing. Exercise same-name/different-ID stacks and partner/self damage sources, retries/failures, shared-state conflicts and reset boundaries. Exact timeout tuning and unchosen archive-retention/restore-safeguard details must produce explicitly blocked branches, not invented defaults; timeline order, latest-global-action undo and current-session persistence are required. See V45–V47 in the [validation plan](08_delivery_validation_and_risks.md). Preserve the accepted original 2/3/4-player layouts, single keyboard and cloud-first visual/interactive review before device installation.
