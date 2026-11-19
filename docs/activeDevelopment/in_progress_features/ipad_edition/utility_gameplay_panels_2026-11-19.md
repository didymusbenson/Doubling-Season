# Utility picker and expanded gameplay controls

- Tap the named row to use a utility. Its separate switch controls whether it is shown on this seat's board. Opening an unused utility initializes it hidden; using it does not turn the switch on. Existing hidden values and identifiers are retained.
- The upper-left **‹ Utilities** back control returns to the same seat’s picker from either entry point. The independent upper-right Close dismisses the workspace without removing or hiding the utility. Utility panels fit their contents within the available safe area: the name stays centered above descriptive text and grouped gameplay controls, with the artwork thumbnail, artist credit, and edit action at the lower left. Board swipes remain a separate undoable removal.
- Built-in names and descriptions are read-only. Expanded trackers, toggles, mana, token actions and Ring controls use the seat's live game state. Existing tap/hold value steppers are unchanged. **Set value** opens a separate, compact player-facing number editor for exact totals (0–999999). Apply commits once; Cancel, Close, Back, and tapping outside discard the draft without closing the utility. No numeric editor invokes a keyboard. Ring uses an always-visible total temptations stepper; correction never triggers Tempt or changes the bearer.
- Existing custom trackers and toggles keep equal-width editable name and description fields. Creating new utility types remains intentionally unavailable: see [corrective iteration F08](corrective_iteration.md). No custom utility creation or migration was enabled.
- The Ring now uses the canonical built-in art in the picker artwork options, active board display and expanded controls. The prior built-in URL is recognized for display; saved custom art and explicit clearing are preserved without rewriting stored data.

Board utility headers no longer show a decorative chevron. Utility, token, and commander-ledger background art fills its frame with a centered crop; existing readability overlays and deliberate contained print previews remain.

Device installation, migration safety and release are separate from this UI checkpoint.
