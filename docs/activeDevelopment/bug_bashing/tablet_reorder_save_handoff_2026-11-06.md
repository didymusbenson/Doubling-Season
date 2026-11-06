# Tablet reorder drop/save handoff

## Report and reproduced mechanism

Build 13, source `08956a8`, still flashed at the end of a token reorder after
its orientation was corrected. The user clarified that the token appeared to
snap back to its old position before jumping to its destination.

The real-drag regression in `reorder_save_handoff_test.dart` holds the repository
save after drop. Before this change, upright and rotated seats both failed on
frame 16 (16 ms steps after release): the moved token appeared 121 logical
pixels on the old side of its neighbor. The controller still correctly held
the old canonical order pending acknowledgement, but the list had no separate
displayed order once Flutter removed its drag proxy. Thus the proxy handed off
to the old list until persistence published the new one. This is a reproduced
Flutter frame transition, not an inference from an artwork placeholder.

The earlier `f42112b` artwork-cache change remains in place. Root Tripling
Season was compared: it uses `ContentScreen` and Hive-backed
`BoardOrderPersistence`, while Table uses a serialized whole-table writer.
The phone root's persistence and widgets are unchanged by this correction.
This comparison does not claim that the root app is immune to delayed writes.

## Correction

- `BoardReorderFeedback` synchronously projects only the requested stable IDs
  before entering the save queue. Tokens/utilities still use current canonical
  objects, and the controller remains the sole writer.
- Receipt IDs retire acknowledged drops without briefly restoring old order.
  Earlier success/failure cannot remove a newer pending sequence. A failed
  final save restores the durable order and follows existing error handling.
- Token saves resolve full ID order inside the queue, rather than stale display
  indexes. Changed membership is rejected without resurrecting deleted tokens.
- Visible utilities use the same projection while preserving hidden/legacy
  slots and payloads. No storage schema, history or undo contract changed.
- The table owns feedback across retained tablet/phone views. Session and
  player generation changes invalidate stale display receipts.

## Evidence and limits

- New delayed-save real-drag tests pass for upright, rotated and phone token
  lists, checking every frame after proxy handoff.
- New token/utility tests pass while switching tablet → phone → tablet with
  the first save held and a second reorder submitted in the phone view.
- State tests cover rapid queued drops, earlier write failure, final failure,
  undo, persisted order, unchanged other seats/object data, exact hidden/legacy
  utility preservation, queued removal, stale player generation and no-op drops.
- Existing orientation, grab-anchor, bounds and artwork regressions remain green.
- Full Flutter analysis passed. The final aggregate suite passed 1,275 tests
  with seven existing skips. The focused handoff file passed all five tests.
- Existing web Release build passed; no web deployment was performed.
- Independent code review found no substantive issues. The subsequent retained
  tablet/phone pending-save regression tests also passed.
- iOS simulator compile passed with Flutter 3.41.2 / Dart 3.11.0. This is compile
  validation, not a simulator launch, signing check or physical-device result.
- Read-only CoreDevice inspection on Kista Mac reported the iPad unavailable.
  No new build was installed, no active game was modified, and no Firebase or
  store upload occurred. Physical iPad drop/reorder and bottom-edge acceptance
  remain pending.
