# Layout and interaction

**Status:** proposed geometry and behavior derived from the user's sketch. D04–D12 require review.

## Reading the sketch

The image has four quadrants around a central 2 × 2 life tracker. The top two life panels face the opposite side of the table; the bottom two face the viewer. Lower-left demonstrates tokens toward the outer edge, and utilities below that player's life panel toward the center seam. The thin central strip suggests a location for universal controls. Only that lower-left quadrant illustrates full content.

Two interpretations need a deliberate choice:

| Layout | What it means | Tradeoff |
|---|---|---|
| A: screenshot-first, proposed starting point | Token lane fills the outer part of each quadrant; life occupies the central end of the inner column; utilities fill the remainder of that inner column | Preserves the strongest visual cues; utilities lose vertical space to life |
| B: life above both lanes in player-local coordinates | Each quadrant has a life/header band and two lanes beneath | Simpler local layout; reduces token height and makes the life hub less visually compact |

Prototype A and retain B as the first comparison, rather than deciding from artwork alone. “Beneath” must be interpreted from each player's seated perspective. The central hub should be visually unified but must not become an overlapping hit-test surface that covers the lists.

```text
Physical screen, landscape; text rotation omitted here
┌──────────────────────────────┬──────────────────────────────┐
│ P2 tokens │ P2 utilities/menu│P3 utilities/menu │ P3 tokens │
│           ├──────────────────┼──────────────────┤           │
│           │     P2 life      │     P3 life      │           │
│           │          [ GAME CONTROLS ]         │           │
├───────────┼──────────────────┼──────────────────┼───────────┤
│           │     P1 life      │     P4 life      │           │
│           ├──────────────────┼──────────────────┤           │
│ P1 tokens │ P1 utilities/menu│P4 utilities/menu │ P4 tokens │
└──────────────────────────────┴──────────────────────────────┘
```

This is a topology diagram, not an exact wireframe. The center control affordance needs real reserved area; it must not obscure life ± controls. An accessible larger game-control panel may open from a small hub button.

## Seat geometry and orientation

Proposed starting arrangement:

| Seat | Physical quadrant | Text faces | Outer token side | Inner life / utility side |
|---|---|---|---|---|
| P1 | Lower-left | Bottom of device, 0° | Screen left | Screen right |
| P2 | Upper-left | Top of device, 180° | Screen left | Screen right |
| P3 | Upper-right | Top of device, 180° | Screen right | Screen left |
| P4 | Lower-right | Bottom of device, 0° | Screen right | Screen left |

These labels are illustrative seat names, never database keys. The screenshot implies a two-on-each-long-edge arrangement. A four-edge arrangement with 90°/270° side seats is a separate D05 option, with different available widths and reaching behavior.

**Do not rotate the same entire quadrant template four times and assume the lanes stay correct.** A 180° rotation swaps physical left/right. Compose the desired inner/outer placement, then apply seat orientation with explicit local constraints. Define scroll direction, drag handles, menu anchoring and text input in player-local coordinates. Rotating the device is a viewport change; it is not a request to swap player identities.

Flutter's `RotatedBox` participates in layout for quarter turns. That makes it a candidate for seat-local subtrees; it does not automatically solve overlay placement, keyboard orientation, semantics, or drag proxies. [Official API](https://api.flutter.dev/flutter/widgets/RotatedBox-class.html). See [research](10_research_sources.md) for version/prototype caveats.

## Space budgets and adaptation

Use logical pixels and actual available constraints, not screenshot pixels or a device-name test. Let usable window width/height be `W/H`, central separation `s`, quadrant dimensions approximately `(W-s)/2` and `(H-s)/2`. Safe areas and any permanent hub reservation must be deducted explicitly.

For layout A, a feasibility estimate is:

```text
quadrantMinWidth  = tokenMinWidth + utilityMinWidth + laneGap + 2*padding
quadrantMinHeight = max(tokenMinHeight, lifeMinHeight + utilityMinHeight + laneGap)
                    + 2*padding
tableMinWidth     = 2*quadrantMinWidth + centerSeparation
tableMinHeight    = 2*quadrantMinHeight + centerSeparation
```

Illustrative starting inputs: token width 280, utility width 200, lane gap 12, padding 12, life height 140, utility height 200, token height 288, center separation 8. This yields roughly **1040 × 760** before additional safe areas or hub deductions. These are prototype inputs, not a supported minimum or an Apple device specification. At an illustrative 1024 × 768 viewport the width already fails this estimate; at 1366 × 1024 there is much more room. Increased text size can fail either size.

Do not shrink every card and touch target to fit. Current phone cards have a dense action row; narrow lanes need a purpose-built compact view with primary controls and overflow/expansion for secondary actions. Reuse the behaviors, not their exact row arrangement.

Proposed adaptation ladder:

1. **Roomy table:** full four-seat overview, both lanes visible, central life hub.
2. **Constrained table:** compact card controls, bounded life detail, optional seat-local lane-width adjustment. Do not hide a whole lane without an obvious selector and count.
3. **Focused seat fallback:** persistent compact life overview plus one selected player's full workspace; preserve all players' state and label the focused seat. This relaxes simultaneous four-workspace visibility and requires D06 approval.

If fallback is rejected, state the supported minimum and offer a clear “enlarge window / rotate device” state. Never discard game state on resize. Flutter recommends adapting to local/window constraints rather than device type. [Adaptive layout guidance](https://docs.flutter.dev/ui/adaptive-responsive/general).

## Independent lists

- Each of the eight lanes owns scroll position, restoration key, reorder state and stable item keys.
- Tokens reorder only among that player's tokens; all supported utility types share that player's utility ordering.
- Life is fixed in its surface and never consumes a list position.
- Default drag cannot cross lane or player boundaries. A future “give control” action must be explicit, not an accidental drop target.
- Use an intentional reorder handle or explicit reorder mode to distinguish scrolling, tap controls, inline editing and drag.
- During an order write, disable only the affected ordering domain. Another player can continue life or token actions.
- Define insertion in lane terms: proposed new entries append; split/copy outputs appear next to their source; merged additions retain the target position. See D13.
- If an expanded entry changes height, retain its stable key and sensible viewport position. Another player's edit must not jump this lane.
- A drag proxy and its hit area must remain within the intended surface, including for rotated seats. A regular child clip alone is not proof that an overlay-based proxy is bounded. Flutter exposes a reorder drag-boundary callback; confirm availability on the selected toolchain. [API](https://api.flutter.dev/flutter/material/ReorderableListView/dragBoundaryProvider.html).

## Expansion and editing

Proposed: at most one expanded token/utility **per player**, so four seats can inspect different objects concurrently. Whether one token and one utility can both expand for a single player is D10; one across both lanes is the simpler starting point. Preserve failed-save vetoes and pending editor content.

Expansion stays in the lane where the item belongs. Do not reintroduce a full-screen phone detail route to avoid the layout work. If a lane cannot contain a complex editor, use a seat-local panel with a clear originating object. Closing P1's panel cannot collapse P2's card.

Changing layout, opening game controls, deleting the current object, and starting a new game all need an editor-resolution policy: commit and await, ask to discard, or veto. Silent discard is never an acceptable default.

## Player menu and local panels

Every seat has a persistent, reachable menu affordance bearing its player identity. Proposed groups: Add token; Utilities; Rules; Board actions; Decks; Player settings. “Everything” becomes “P1's tokens” or an equivalent named scope.

Token/utility search, quantity input, artwork selection, counters and deck selection should render in a bounded panel associated with that player. Record `playerId` when opening; carry it through every return value and callback. A screen-space pointer position may choose the originating surface but may never become the durable identity.

A root modal bottom sheet prevents interaction with the rest of the app. `anchorPoint` relates to display-feature sub-screens, not arbitrary tabletop quadrants. Reusing current sheets unchanged would undermine independent play. [Bottom-sheet API](https://api.flutter.dev/flutter/material/showModalBottomSheet.html). Candidate implementation: bounded per-seat navigator/overlay or an explicit panel host, validated for barriers and focus. A nested navigator alone is not proof of clipping. [Navigator documentation](https://api.flutter.dev/flutter/widgets/Navigator-class.html).

## Simultaneous touch and keyboard

- Different seats' quick controls should accept independent touches without a global “active player” variable.
- Capture a repeating life/mana gesture's player and direction at gesture start. Crossing a seam must not retarget it.
- Cancel repeat on pointer cancel/up, backgrounding, focus loss, panel destruction or session-generation change.
- Two gestures on the same life total must combine deterministically through commands; no read-modify-write lost updates.
- Default proposal: multiple local non-text panels may coexist; **one text editor owns keyboard focus at a time**. A second request should give a visible “finish editing P2” action or an intentional focus handoff, not steal a draft.
- Treat the system keyboard as a shared device resource. Top-facing seat text input and floating/split keyboard behavior require a physical iPad experiment. Do not promise four independently rotated system keyboards.
- Account for keyboard insets without lifting all eight lanes into unusable heights. Preserve life access where practical; use a temporary named input panel if necessary.
- Root game actions acquire an explicit table-operation barrier; resolve editors, stop repeat gestures and suspend new mutations before taking their snapshot.

Flutter distinguishes raw pointers and gesture recognition; nested buttons, drags and repeated controls need deliberate gesture arbitration. [Gesture documentation](https://docs.flutter.dev/ui/interactivity/gestures). Actual multi-seat reliability remains unproven until P0.

## Accessibility and tabletop use

Proposed shared target floor: 48 × 48 logical pixels for primary touch targets, with visible separation, readable text, and no color-only seat identification. Seat name + icon/label should supplement color. Retain contrast over bright artwork with solid backing or an optional plain background. [Flutter accessibility guidance](https://docs.flutter.dev/ui/accessibility).

Give semantics labels such as “Alex, life 37, decrease life by one” and “Sam, Treasure, increase quantity.” Define reading order by player, then life/menu/tokens/utilities, rather than relying on rotated visual position. Offer a single-orientation accessibility/focused view if VoiceOver traversal around four rotations is confusing; D12 settles that behavior.

Verify light/dark themes, large text, reduced motion, grayscale, external keyboard navigation, and life legibility from seated distance. Keep global destructive actions away from routine ± taps. Decide haptics/sound at device scope because the same tablet serves every player.

## Empty, busy and failure states

An empty lane shows its own Add action and player's name. A busy creation command marks only its originating seat and blocks duplicate submission of that operation. An artwork failure preserves selection and shows a placeholder. A failed save retains the editor or mutation draft and offers retry in the same player's area. A stale panel after a reset explains that the game changed and must not apply its old result.

No table-wide snackbar is assumed. Use local inline status for routine results and explicit local/global completion controls for destructive operations, adapting the current undo pattern to the correct scope.
