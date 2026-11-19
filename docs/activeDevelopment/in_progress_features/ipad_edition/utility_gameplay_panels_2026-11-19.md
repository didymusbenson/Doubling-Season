# Utility picker and expanded gameplay controls

- Tap the named row to use a utility. Its separate switch controls whether it is shown on this seat's board. Opening an unused utility initializes it hidden; using it does not turn the switch on. Existing hidden values and identifiers are retained.
- The inline **All utilities / utility name** breadcrumb returns to the same seat’s picker from either entry point; Close dismisses the workspace without removing or hiding the utility. Board swipes remain a separate undoable removal.
- Built-in names and descriptions are read-only. Expanded trackers, toggles, mana, token actions and Ring controls use the seat's live game state. Existing tap/hold value steppers are unchanged. **Set value** opens an optional in-panel digit pad for exact totals (0–999999). Apply commits once; Cancel discards. No numeric editor invokes a keyboard. Ring uses an always-visible total temptations stepper; correction never triggers Tempt or changes the bearer.
- Existing custom trackers and toggles keep equal-width editable name and description fields. Creating new utility types remains intentionally unavailable: see [corrective iteration F08](corrective_iteration.md). No custom utility creation or migration was enabled.
- The Ring now uses the canonical built-in art in the picker artwork options, active board display and expanded controls. The prior built-in URL is recognized for display; saved custom art and explicit clearing are preserved without rewriting stored data.

Board utility headers no longer show a decorative chevron. Utility, token, and commander-ledger background art fills its frame with a centered crop; existing readability overlays and deliberate contained print previews remain.

Device installation, migration safety and release are separate from this UI checkpoint.
