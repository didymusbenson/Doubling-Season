# Brudiclad Inline Edit Uses Detached Hive Object

## Symptom

After resolving Brudiclad's effect, attempting to edit a token inline can fail
with a Hive error saying that the token is not in a box.

## Root cause

`BoardUndoSnapshot.restore()` clears and repopulates the board boxes. Restored
models keep their persistent Hive keys, but they are new Dart objects. Board
cards were keyed only by those persistent identifiers, so Flutter could retain
an existing card State and its `TokenEditSession`. That session continued to
reference the pre-restore `Item`, which Hive had detached during `clear()`.
Calling `save()` on it produced the reported error.

The same stale-State risk applied to tracker and toggle cards because the board
snapshot restores all three boxes together.

## Fix

Board card State keys now combine the persistent model identifier with Dart
object identity. Normal Hive updates retain the same card State, while a
snapshot restore creates a fresh State and fresh inline controllers for the new
boxed model. Token, tracker, and toggle cards all follow the same rule.

Delayed write paths also capture the original Hive key and resolve the live
boxed model immediately before mutation. This covers token inline commits,
tracker/toggle inline commits, and token/utility artwork selection callbacks.
If the key no longer exists, the operation cancels without recreating a model
the user intentionally deleted.

## Validation

- Run `flutter analyze`.
- Resolve Brudiclad, choose **Undo**, expand a restored token, edit a text field,
  and confirm the edit saves without a Hive error.
- Repeat a normal Brudiclad transform and edit the surviving merged stack.
- Confirm tracker and toggle inline edits still work after undoing an immediate
  destructive board action.
- Start an artwork download, restore the board before it completes, and confirm
  completion updates the restored model or cancels if that model was deleted.
