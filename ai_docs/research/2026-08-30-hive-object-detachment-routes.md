# Hive Object Detachment Routes in 1.11

## Question

Besides Brudiclad's effect, which 1.11 flows can leave UI state or delayed work
holding a Hive model that is no longer in its box?

## Confirmed same-identity replacement routes

`BoardUndoSnapshot.restore()` clears the token, tracker, and toggle boxes, then
puts cloned models back under their captured Hive keys. The logical board IDs
therefore stay the same while every Dart model object is replaced and the old
objects become detached.

Current callers produce four concrete routes:

1. Brudiclad explicit **Undo**.
2. Brudiclad automatic rollback after a failure.
3. Board Wipe explicit **Undo**, including undoing **Set to 0**.
4. Board Wipe automatic rollback after a failure.

These routes are implemented by
`lib/services/board_undo_snapshot.dart`,
`lib/widgets/tracker_widget_card.dart`, and
`lib/screens/content_screen.dart`.

Before the card-key fix, any of them could preserve a card State keyed only by
the logical model identifier. A retained inline session could then call
`save()` on the pre-restore, detached object. Because the snapshot restores all
three boxes, the same lifecycle applied to tokens, trackers, and toggles.

## Other detachment paths

### Clear & Load Deck

`DeckProvider.loadDeckClearBoard()` clears all three board boxes and creates new
models from deck templates. Unlike snapshot restore, these are new records
rather than clones deliberately written under captured keys. The board is also
reached through the collapse gate before navigating to decks. This makes it a
less direct recurrence route, though it exercises the same general model
replacement boundary and is suitable for regression testing.

### Accepted Brudiclad merge

The normal transform mutates the surviving merge anchor in place and deletes
the other clean stacks. Deleted source cards leave the widget tree; the survivor
remains boxed. This is not by itself the same retained-State path.

### Individual delete, accepted board wipe, and reordering

Individual and bulk deletes remove their cards instead of recreating models
under the same logical identities. Reordering changes existing models in place.
These are not confirmed versions of the reported failure.

## Delayed-callback hardening

Card identity changes recreate editor State after a model replacement, but they
cannot cancel work that was already in flight. Inline commits and artwork-sheet
callbacks now capture the original Hive key and resolve the current boxed model
immediately before mutation. Snapshot replacement therefore redirects the
pending change to the restored model. If the key is absent because the board
item was genuinely deleted, the delayed operation cancels rather than
recreating it.

## Coverage of the current fix

`ContentScreen` now keys `TokenCard`, `TrackerWidgetCard`, and
`ToggleWidgetCard` by both persistent identity and Dart object identity. Normal
in-place updates preserve card State. Snapshot restore and clear/recreate flows
produce fresh card State and fresh inline controllers, covering all confirmed
same-identity replacement routes above.

## Relevant files

- `lib/services/board_undo_snapshot.dart`
- `lib/screens/content_screen.dart`
- `lib/widgets/tracker_widget_card.dart`
- `lib/widgets/token_card.dart`
- `lib/widgets/toggle_widget_card.dart`
- `lib/controllers/token_edit_session.dart`
- `lib/providers/deck_provider.dart`
- `lib/providers/token_provider.dart`
