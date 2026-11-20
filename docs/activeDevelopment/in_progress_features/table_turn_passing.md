# Tripling Table: multiplayer turn passing

Status: draft only. Do not start implementation until the current fixes are in
and implementation is authorized. Evidence baseline:
`4b6946a1ae1d28a4e08c6fd78deae9eec01f92df`. Recheck the integrated head before
coding. This proposal changes no app behavior.

## Requested behavior

- In multiplayer, the active player's seat has a thin, white 1 px outline. Only
  that player's seat has a visible **Pass** button, next to **Rules**.
- Pass advances to the next player in turn order, supports turn timing, logs
  **[player] passed turn**, and untaps the incoming player's tokens and clears
  their summoning-sickness flags. It does not change other players' tokens.
- In the one-player phone view, hide the whole feature: no outline, Pass, timer,
  pass event, or automatic untap/sickness clear. Existing manual actions stay.

## Existing surfaces and reuse

- `domain/table_state.dart` has a serializable `GameSession` with stable player
  IDs, physical slots, mirrored rows, revisions and history. No active-player
  state or turn-order field exists at baseline. `seatRowsFor` is presentation
  (including a genuine empty corner in three-seat layouts); it is not rules order.
- `features/board_service.dart` already has seat-scoped `startTurn`: zeroes
  `TokenState.tapped` and `summoningSick` in one undoable command. The separate
  bulk actions clear each field individually. `ui/table_screen.dart` and
  `ui/phone_player_view.dart` expose the manual action. Reuse the mutation
  inside Pass, not a second command. Both counts are per stack; don't touch
  amount, counters, utility values, or the user's sickness-tracking preference.
- `state/table_controller.dart` serializes commands, applies them to detached
  state, checks affected-player scope, deduplicates command IDs, and publishes
  after a successful save. Its history projection ignores internal epochs;
  Undo applies stored command changes. The history drawer in
  `ui/workspace/game_pages.dart` consumes those entries. Reuse it as the log.
- No gameplay turn timer found at baseline. `main.dart` already flushes on
  non-resumed lifecycle states; build lifecycle timing on that boundary, not a
  widget-local stopwatch that resets with drawers or rotation.

## Recommended MVP (decisions to confirm before build)

| Topic | Recommendation |
| --- | --- |
| Starting player | Choose an occupied player at setup, defaulting to the first player in the configured game. For existing saves without turn data, use that default on the first deliberate tracking action; no automatic untap, sickness clear or log on loading. Define whether a one-tap setter or setup-only selection is sufficient. |
| Turn order | Save an explicit circular list of occupied player IDs when tracking starts; propose configured seat order as the default, independent of rendered row, screen rotation, mirrored controls, drawer location, or temporarily hidden seats. Label the next player where useful. For a 3-seat game skip the empty position by construction. Confirm whether physical clockwise order is preferred before coding; the two orders need not match. |
| Timers | Optional elapsed time (off by default), current turn only, starting at zero when tracking begins or Pass succeeds. No countdown, buzzer, automatic Pass, per-player time bank, or timing leaderboard. Keep timing out of widgets that come and go. |
| Rule exceptions | This is manual turn tracking and batch cleanup, not a rules engine. Keep existing manual Start turn and token edits for exceptions; Undo is the immediate recovery path. Do not infer extra/skipped turns, untap restrictions, control changes, triggers, or card-specific sickness rules. If needed later, add deliberate override/extra/skip controls as separate designs. |
| Phone vs multiplayer | Gate by both presentation and eligible session scope. A phone surface may show a single selected seat of a multiplayer save: never surface Pass or fire any cleanup there, and preserve saved active player/order. A seat existing offscreen in multiplayer still participates. |

## State, timer and command contract

- Store order, current player, and a turn identifier in the game session, not
  reusable seat profiles. Validate unique occupied IDs and an active member;
  invalid recovered data must not trigger cleanup or silently choose an incoming
  player. Offer explicit reinitialization of tracking rather than repair by Pass.
  Do not let delayed captured commands revive after reset, archive restore or
  undo. Use a non-rewinding interaction epoch (or equivalent) alongside the
  session ID/generation and expected outgoing turn.
- One accepted Pass: validate multiplayer eligibility, active outgoing player
  and expected turn inside the queued command; calculate the incoming player
  from live state; finalize outgoing clock and reset incoming clock; zero only
  incoming token counts; persist the new active player and the single history
  event together. Capture the outgoing display name as of the event, so renames
  do not rewrite it. Ensure the message is exactly **[player] passed turn**,
  including for an empty incoming board; optionally add structured timing
  metadata without changing that text. Don't call `startTurn` or append a second
  log independently. Scope outgoing actor and incoming target explicitly.
- Disable Pass as soon as submitted; bind repeated events to the captured turn,
  not to whatever turn becomes current after the save. Guard again inside the
  writer, including queued taps, restored routes and a later same-player wrap.
  A failed write leaves outline, clock authority, token counts and history on
  the outgoing turn. Show an error, let the player retry, and don't display an
  optimistic next player. No unintentional extra Pass while drawer/orientation
  transitions are occurring.
- Count foreground time only, using monotonic time while resumed; stop on
  background/inactive, phone-only presentation, or exit; persist accumulated
  elapsed time at lifecycle checkpoints using the same serialized writer. No
  writes on each tick. Resume from the last saved elapsed time and don't infer
  background time from wall clock; a crash may lose the uncheckpointed segment.
  Start the next clock only after Pass commits; on failed Pass keep the outgoing
  clock. Don't make lifecycle checkpoints undo entries or allow stale timer
  writes to cross a turn or overwrite a restored session.
- Undo makes Pass one reversible action: restore previous active player,
  incoming tapped/sick counts and outgoing elapsed time as at Pass, mark the
  history entry undone and restart the restored clock if eligible/resumed.
  Account for elapsed checkpoints when defining the undoable projection; live
  tick updates cannot be gameplay changes. Both reset modes create fresh turn
  tracking and timers; archive snapshots preserve saved order, active player and
  elapsed. Restore resumes from the saved value only, not historical wall time.
  Seat/setup changes must rebuild or explicitly reconcile order; never advance
  or mutate tokens as a side effect of opening or rotating a board.

## UI constraints

Draw a seat-local inset stroke (1 logical pixel) matching the existing rounded
corners, clipped within the seat; no padding, layout shift, extra card, hit-test
interception, or covering the spacing between seats. Add a semantic active-turn
label; don't rely on white alone, or announce timer ticks continuously. Keep
Pass text visible and the normal touch target in both orientations. Place it by
the seat's Rules entry point, not as a new global drawer button. At the narrowest
supported widths prefer a local wrap/overflow layout that keeps Rules and Pass
together and other controls reachable. A drawer must not let a hit leak to
underlying Pass. Closing the drawer, seat switching, and rotation do not cause a
pass or restart the timer.

## Implementation sequence and acceptance

1. After current fixes and approval, confirm starting-player picker, order,
   timer default and phone-surface behavior. Add backward-compatible session
   fields and a clock with a fake-time seam. Old, corrupt and partially migrated
   metadata must not cause automatic token changes.
2. Implement the serialized Pass and undo/restore/reset behavior before UI.
   Test 2–6 players (including 3-seat empty corner, 5-seat row layout and wrap),
   starting-player selection, correct actor label, no duplicate on rapid/delayed
   taps, stale commands across undo/reset/restore, zero-token board, mixed tapped
   and sick counts, unrelated board state untouched, and failed save/retry.
   Verify close/reopen and serialized relaunch retain authority without replay.
3. Add seat visuals and controls. Widget-test one outline and one Pass exactly;
   all others retain Rules, no Pass in phone view (including when the saved
   session is multiplayer), no phone auto-actions, readable semantics, mirrored
   seats, minimum supported width, higher text scale, drawer transitions and
   portrait/landscape. Inspect rendered narrow/wide layouts; native tablet
   acceptance remains separate.
4. Fake-time tests: Pass resets timer; background/resume, phone posture,
   archive/restore, undo, and cold relaunch do not add away time; changing the
   system clock doesn't affect elapsed foreground time. Test a late lifecycle
   save racing Pass. Run focused controller/history, seat layout and phone tests,
   then Table analyze and suite against the integrated branch.

Optional later: explicit turn-order editing, unusual turn sequences, configurable
countdown or shared clock, recorded per-player timing. No rules engine, native
install, deployment, scheduling, integration, or source edit in this draft.
