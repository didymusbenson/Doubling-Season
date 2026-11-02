# Draw Your Own Token Art

**Status:** Future reference / proposal only. Not scheduled or implemented.
**Recorded:** 2026-11-02
**Product scope:** Tripling Table (`apps/tablet`), including its phone mode and player-facing tablet layout. This does not add work to the original Tripling Season release queue.

## User direction

The user requested a prospective feature for drawing their own token artwork,
then narrowed it to “a bare bones, editor with very few color choices very
straightforward.” They requested filing this proposal in the repository docs
for future reference, explicitly saying implementation is not needed today.

The simplicity requirement is confirmed. The concrete palette and controls
below are the proposed starting point, not separately approved design decisions.

## Goal and flow

A small doodle pad lets a player draw a recognizable token and return to play
in a few taps. It is not a full art editor.

From a token's existing artwork options, choose **Draw**, make a doodle, then
choose **Save** to apply it to the selected token. Do not add permanent drawing
controls to the gameplay surface or create a separate token-detail workflow.

## Proposed minimal editor

- White canvas shaped like the token's visible artwork area.
- Tiny fixed palette. Suggested six colors: black, white, red, blue, green,
  and yellow; final palette remains open.
- One pen with a fixed stroke width, an eraser, and **Undo**.
- **Save** and **Cancel**.
- All controls visible in one compact toolbar, with no nested menus.
- Full-screen workspace on a phone; player-facing canvas on a tablet, retaining
  the initiating seat and the existing table-modal interaction rules.
- Finger drawing and basic stylus input where supported and verified. No
  pressure sensitivity or palm-rejection promise.

## Save and safety behavior

- Saved drawings can be reopened for further drawing and survive app restarts.
- Cancel leaves the previously saved artwork untouched.
- Saving changes artwork only: preserve quantities, counters, token details,
  state, and other players' tokens. Do not rewrite the upstream token catalog.
- Respect existing artwork lifetime, seat, deck, and history behavior; this
  proposal does not introduce global artwork propagation or new seat defaults.
- Do not misattribute a new drawing to the artist of the replaced artwork.
  Preserve credits for any original artwork that remains available.
- Save failures retain the drawing and show an inline, plain-language retry
  path instead of raw exceptions. Avoid routine snackbars and extra controls.

## Future acceptance checks

These checks describe eventual behavior, not tests performed or implementation
approval:

1. Draw, erase, undo, and save using only the visible toolbar.
2. Reopen the saved drawing after restarting the app.
3. Cancel an edit without changing previous art or game state.
4. A failed save retains work for retry and does not replace valid saved art.
5. Phone and tablet input remain usable; tablet canvas and controls face the
   initiating player without affecting another seat.
6. Applying art does not change token metadata, counters, quantities, or
   existing artwork attribution incorrectly.

## Explicitly out of scope

Layers, brush choices, size sliders, custom color pickers, text tools, shapes,
filters, galleries, cloud sharing, and a dedicated export or art-library system.
Do not expand the editor into these features when this proposal is revisited.

## Before implementation

Confirm the fixed palette and final minimal controls, and choose a small local
storage approach that supports reopening without introducing a library UI.
Check existing artwork rendering, persistence, and seat/history semantics at
that time. No dependency, schema, or release changes are selected here.
