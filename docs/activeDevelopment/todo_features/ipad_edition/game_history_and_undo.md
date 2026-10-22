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

Preset loading is distinct from current-game recovery and pre-reset archive loading. D38 accepts midgame Replace and Append: replace swaps the loading seat’s preset-managed tokens/utilities for zero-state setup; append adds without clearing existing items. Both apply saved token art and optional deck life art under the existing contract. Each load is one undoable action, preserving the existing timeline, life value, commander damage, player counters and unrelated state. Undo restores the load’s complete before-state, including any art/preference changes, without touching other seats or replaying token-entry gameplay from templates.

D39 keeps token-art choices durable with the current game and its restorable archive, not as next-game seat defaults. Archive loading restores historical choices; a fresh game does not inherit them unless reusable board artwork is explicitly kept or a preset is loaded. Persistent seat name/life appearance remains distinct. Artwork-change history/undo presentation still requires design.

## Accepted bookkeeping policies

- New commander-damage entry subtracts life as **one undoable action**, including self-source entries. Provide corrections to either ledger or life independently; correcting one must not silently apply the other effect again.
- Life, poison and commander-damage thresholds give warnings, **not automatic elimination or disabled controls**. This does not attempt full rules enforcement or infer a winner.
- A player manually claims monarch; the shared holder transfers explicitly. Day/night is changed manually. Do not infer combat, spells cast or other physical-game events.

Detailed correction controls, warning presentation, remaining runtime/rule mappings and archive presentation/transaction details and UI remain open. These decisions do not approve new optional modes or alter the one player-facing keyboard policy.

## Timeline, undo and recovery decisions

- **Accepted:** one game-wide chronological timeline, with player attribution. It is the game’s history, not separate player histories.
- **Accepted:** undo walks back the latest action globally. No arbitrary selected-entry undo or independent per-player undo stack is promised. A settled grouped action is the intended log/undo unit; final group-boundary details must align with the underlying command order.
- **Accepted:** game state and current-session history are persistent and reload their last saved state. Undo information needed by the accepted contract must be saved coherently with that state; precise write/acknowledgement mechanics still need implementation design and validation.
- **Accepted clarification:** a different action by **any player** closes the active group. P1 Soldier → P2 life → P1 Soldier yields three chronological entries, never a retroactive P1 +2. The user answered “correct.” to that exact example. Do not maintain independent open per-player groups.
- **Accepted:** a pre-reset game archive can load the full last state and timeline from before reset, including historical seat game setup. Retain the last ten archived game states, separate from the active working game. Each keeps its full timeline and undo information. Save the current game before restoring another; saved decks and permanent seat customization are not overwritten. Archive UI/transaction mechanics remain design work; statistics are not implied.

Chronological display, global latest-action undo and persistence are settled. Game-wide interruption is also settled. Pre-reset archive restore is accepted. Ten-snapshot retention and restore safeguards are accepted; exact timeout tuning, detailed settlement/undo UI and transaction design remain open. New replies should update this document and D16/D17/D33 together.

## Full-reset boundary and persistent seats

Two full-reset modes now restart the configured game: Reset with board retains zero-count/no-counter token entries and enabled utilities; Complete reset clears tokens/utilities. Both restore starting life and reset temporary/game statuses. Persistent seat names and color/art survive either mode, including currently hidden seats. See [reset details](03_life_and_game_controls.md).

A successful full reset begins a new game boundary and leaves a restorable archive of the prior full state and chronological timeline. Restore historical seat game setup from that archive, including tokens/utilities cleared from live seats when they were removed; do not reconstruct an old game from cleared current templates. Reusable setup survives only when explicitly kept for remaining seats; removed seats lose live game-specific setup, not persistent name/color/art. Do not infer cross-game undo from latest-action undo: archive loading is distinct. Transactional failure recovery remains required. The group must not absorb post-reset actions into a pre-reset entry; pending inline/form/search state follows the existing-design audit; async save/recovery mechanics remain technical work. Historical attribution must remain stable despite later name/art edits.

**Accepted D33:** save the current game before loading an archive. Restore historical game state and timeline without overwriting saved deck presets or permanent seat customization. Keep the last **10 archived game-state snapshots**, evicting the oldest as new snapshots are saved. The active game is a separate working state; ordinary taps are not ten separate archive slots, and ten snapshots does not mean ten history entries or undo actions. Each retained snapshot preserves its complete timeline and required undo information.

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

Test repeated additions, add/remove net-zero separation, different-action and timeout boundaries, opposite life taps and the chosen life-settling timing. Exercise same-name/different-ID stacks and partner/self damage sources, retries/failures, shared-state conflicts and reset boundaries. Exact timeout tuning and unimplemented transaction/UI details must be identified honestly; accepted ten-snapshot retention and save-current-before-restore must be tested, not marked undecided; timeline order, latest-global-action undo and current-session persistence are required. See V45–V47 in the [validation plan](08_delivery_validation_and_risks.md). Preserve the accepted original 2/3/4-player layouts, single keyboard and cloud-first visual/interactive review before device installation.

## Old-design inference checkpoint

The [granular baseline map](outstanding_behavior_baselines.md) supplies concrete starting points for remaining behavior questions, including what current design cannot settle. These are explicitly inferred defaults, not additional accepted requirements; D41 and all earlier explicit decisions take precedence.

## Modifier scope checkpoint — D25

A source modifier change is one attributable action with potentially multi-seat applicability consequences. Latest-global-action undo restores the source and applicability atomically without deleting independent sources. Previously committed token/counter results are not retroactively recalculated by a toggle; each evaluated operation retains its causal source snapshot. See [modifier ownership and applicability](modifier_ownership_and_applicability.md).

## Archive transaction and retention contract — D33

Capture the selected archive snapshot before saving the outgoing current game or performing eviction, so choosing the oldest of ten still restores the intended snapshot. Save-current, restore and oldest-snapshot eviction form one recoverable transition: a failure must leave the previous active game intact/recoverable, with no partially restored state/history or premature archive loss. Exact transaction ordering, snapshot identity/deduplication and storage mechanism are implementation decisions, not additional user approvals. At a successful boundary retain at most the latest ten archived snapshots plus the separate active working game. Ordinary edits do not consume archive slots.

Restore historical game-specific setup, source identities, token-art choices and full timeline/undo data, while preserving the saved deck library and permanent seat name/life-appearance customization. Historical attribution may use snapshot labels without rewriting persistent seat records. Keep references needed by active state, retained archives and saved presets before reclaiming media; eviction is not authorization to remove still-referenced artwork. This document specifies future application behavior, not deletion of any current user archive.
