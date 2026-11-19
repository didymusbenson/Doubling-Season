# Utility picker and expanded gameplay controls

- Tap the named row to use a utility. Its separate switch controls whether it is shown on this seat's board. Opening an unused utility initializes it hidden; using it does not turn the switch on. Existing hidden values and identifiers are retained.
- Details opened from the picker go Back to the same picker. A board-origin panel offers All utilities; Close dismisses the workspace without removing or hiding the utility. Board swipes remain a separate undoable removal.
- Built-in names and descriptions are read-only. Expanded trackers, toggles, mana, token actions and Ring controls use the seat's live game state. A numeric correction follows an untouched counter, but subsequent board changes do not discard a correction the player has typed.
- Existing custom trackers and toggles keep equal-width editable name and description fields. Creating new utility types remains intentionally unavailable: see [corrective iteration F08](corrective_iteration.md). No custom utility creation or migration was enabled.
- The Ring now uses the canonical built-in art in the picker artwork options, active board display and expanded controls. The prior built-in URL is recognized for display; saved custom art and explicit clearing are preserved without rewriting stored data.

Device installation, migration safety and release are separate from this UI checkpoint.
