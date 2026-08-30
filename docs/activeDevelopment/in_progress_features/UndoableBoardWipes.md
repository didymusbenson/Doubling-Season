# Undoable Board Wipes

**Status:** Implemented; simulator smoke passed, pending user acceptance

**Target:** Immediate post-1.11 work

**Last updated:** 2026-08-30

## Objective

Give every destructive board-wipe action one immediate, explicit recovery
opportunity using the established Brudiclad **Undo / Accept** completion pattern.

Covered actions:

- **Set to 0**
- **Delete All**
- **Delete All & Reset Rules**

## Locked Existing Semantics

- **Set to 0** sets token quantities, tapped counts, and summoning-sickness
  counts to zero. It does not zero or delete utilities and does not publish the
  board-wiped event.
- **Delete All** deletes token stacks. Utilities remain, while the existing
  board-wiped event resets listeners such as Cathar's Crusade.
- **Delete All & Reset Rules** performs Delete All and disables every preset
  and custom rule. It does not delete rule definitions.

Undo adds recovery; it does not redefine what each wipe means.

## Completion Flow

After a successful action, show a non-dismissible dialog:

> **Board Wiped**
>
> **Undo** / **Accept**

- **Undo** is the left text action.
- **Accept** is the right primary action.
- No complete before/after board preview is required.
- Accept discards the in-memory recovery opportunity.
- Starting a later wipe captures a new independent snapshot.

## Snapshot Scope

All three actions capture the complete unified board before mutation:

- tokens, including identity, quantity, counters, tapped/sick counts, artwork,
  dates, and order;
- tracker utilities, including Cathar's Crusade values; and
- toggle utilities and their complete state.

**Delete All & Reset Rules** additionally captures:

- all nine persisted preset counts; and
- each custom rule's enabled state by its stable Hive key.

Rule definitions, order, triggers, outcomes, and counts are not cloned because
the reset action does not mutate or delete them.

## Event and Failure Semantics

- Undo restoration writes directly to Hive and emits no ETB or board-wipe
  events.
- The normal wipe still emits its existing events exactly once.
- If any wipe step fails, restore the captured board and rules state and report
  that the failed wipe was undone.
- If user-requested restoration itself fails, retain the underlying provider
  error and show that the board could not be completely restored.
- The snapshot is in-memory and intentionally does not survive process death;
  Accept/Undo is an immediate completion decision.

## Implementation

- Reuse `BoardUndoSnapshot` for the unified board.
- Add a lightweight `RulesStateSnapshot` owned by `RulesProvider` so private
  SharedPreferences/Hive persistence remains encapsulated.
- Keep orchestration in `ContentScreen`, where the three wipe choices and the
  completion dialog already belong.
- Clear stale dismiss-animation state after deletion and after Undo.

## Acceptance Checklist

### Set to 0

- [x] Simulator: Set to 0 showed the non-dismissible completion dialog; Undo
      restored Zombie and Squirrel quantities exactly.
- [ ] Start with tokens containing quantities, tapped/sick counts, every built-
      in counter type, and custom counters.
- [ ] Choose **Set to 0** and confirm all token quantities/status counts become
      zero while token identity, counters, artwork, and order remain.
- [ ] Confirm trackers and toggles do not change.
- [ ] Choose Undo and confirm the exact pre-wipe board returns.
- [ ] Repeat and choose Accept; confirm the zeroed state persists after relaunch.

### Delete All

- [x] Simulator: Delete All showed the completion dialog; Undo restored both
      deleted stacks and their quantities.
- [ ] Start with interleaved tokens, trackers, and toggles.
- [ ] Include Cathar's Crusade with a nonzero value.
- [ ] Choose **Delete All** and confirm tokens disappear, utilities remain, and
      Cathar's Crusade resets through the existing event.
- [ ] Choose Undo and confirm tokens, exact interleaving, and the previous
      Cathar's Crusade value return.
- [ ] Repeat and choose Accept; confirm the deleted state persists.

### Delete All & Reset Rules

- [x] Simulator: with Chatterfang active, Undo restored the deleted board and
      restored the rule, verified by the `1 Zombie + 1 Squirrel` preview.
- [x] Simulator: Accept persisted the empty board and disabled-rule state across
      full process termination and relaunch.
- [ ] Enable nonzero counts for every preset and a mixture of enabled/disabled
      custom rules.
- [ ] Choose **Delete All & Reset Rules** and confirm tokens are deleted,
      Cathar's Crusade resets, every preset becomes zero, and every custom rule
      becomes disabled without deleting its definition.
- [ ] Choose Undo and confirm the exact board, every preset count, and each
      custom enabled/disabled state returns.
- [ ] Repeat and choose Accept; confirm board and rules state persist.

### Completion and regression

- [x] Simulator: all three actions showed **Board Wiped**, with Undo left and
      primary Accept right.
- [ ] Confirm all three actions show **Board Wiped**, with Undo on the left and
      primary Accept on the right.
- [x] Simulator: system Back could not dismiss the completion dialog;
      `barrierDismissible: false` also blocks scrim dismissal.
- [ ] Confirm Undo emits no creature-ETB or board-wipe events.
- [ ] Perform two wipes in succession and confirm each Undo restores only its
      immediately preceding state.
- [ ] Fault-inject each persistence phase and confirm automatic rollback does
      not claim success.
- [ ] Confirm deck clear-and-load retains its existing behavior and does not
      gain an interactive wipe completion dialog.
- [ ] Smoke-test iOS and Android.
