# Inline Token Details

**Status:** Implementation complete — awaiting human interaction and artwork review

**Last updated:** 2026-08-29

## Premise

Replace the token card's current tap-to-open-detail-route behavior with an
in-place expansion. A user taps into a token, the same board card grows into an
editable detail card, and its existing visual landmarks remain in place.

Example:

1. Tap a token card to expand it in the board.
2. Tap the displayed token name.
3. The name becomes a focused text field with a cursor and keyboard.
4. Press the keyboard's check mark/Done or focus elsewhere.
5. The name saves and returns to rendered text without leaving the board.

This specification now drives the active implementation. Human review remains
required for the interaction feel and final expanded-artwork treatment before
the former full-screen detail experience is retired.

## Product Goals

- Keep the user spatially anchored to the board and the selected token.
- Make common edits feel direct: tap the displayed value, change it, continue.
- Preserve the token card's name, status, counters, type, abilities, P/T,
  artwork, and color identity in recognizable positions during expansion.
- Avoid presenting every possible control simultaneously.
- Continue using bottom sheets for secondary or multi-step operations.
- Preserve every existing mutation rule, validation, and persistence behavior.

## Non-Goals

- Changing the `Item` schema or how token data is stored.
- Replacing artwork selection, counter search, or split workflows with new
  custom interfaces.
- Making every pixel of the expanded card editable.
- Rewriting stored abilities when Mana symbols are rendered.
- Retaining two permanent token-detail experiences after inline parity is
  complete. Git history is the historical fallback, not shipped duplicate UI.

## Current Behavior Being Reconsidered

The entire compact `TokenCard` currently pushes `ExpandedTokenScreen`. The
board row also supports child action taps, swipe deletion, and long-press
reordering. `ExpandedTokenScreen` already supplies the proposed tap-to-edit
behavior for name, P/T, type, abilities, total, tapped, sickness, and counters.

The feature is therefore primarily a composition and interaction change, not a
new editing model.

Research record:
`ai_docs/research/2026-08-28-inline-token-details-current-state.md`.

## Proposed Board State

`ContentScreen` owns the identity of the currently expanded board item using
its stable persisted key. Expansion is board UI state and is not persisted.

Locked invariant for the exploratory MVP:

- Exactly zero or one board card is expanded; multiple simultaneous expansions
  are never allowed.
- While one token is expanded, tapping any other token is treated as an
  off-card dismissal tap: commit the active edit and collapse the current token,
  but do not expand the newly tapped token. Expanding that token requires a
  deliberate second tap.
- If the active edit cannot be committed safely, keep the current token
  expanded and do not transfer the interaction to another token.
- Closing/reopening the app starts with all cards collapsed.
- Tokens, trackers, and toggles share the same commit-or-veto collapse contract.
- A token provider rebuild retains expansion while the keyed token still exists.
- Deleting or replacing the expanded token clears expansion safely.

Local per-card expansion state is discouraged because provider/Hive rebuilds,
reordering, and board composition are owned above `TokenCard`.

## Expansion and Collapse

### Expand

- A tap on any non-action portion of the compact token expands it. This is the
  locked entry model and preserves the current learned behavior that tapping a
  token opens its details.
- Compact action buttons consume their own taps and perform their actions
  without expanding the token.
- The expansion tap never focuses a field, opens a sheet, or summons the
  keyboard. Expansion is the first stage; the user then taps a specific field
  or region to edit it.
- Expansion occurs within the same `ReorderableListView` row.
- Use a short size transition that preserves the artwork/background layer and
  does not animate from a duplicate card.
- Expansion uses a lightly overshooting height transition for a bouncy feel;
  do not scale the whole card, because scaling makes stable artwork appear to
  jitter. Collapse is quicker and smooth.
- After expansion, keep the card visible by scrolling only enough to reveal the
  active field or lower controls. Do not automatically jump it to the top.

## Full-Width Board Tokens

As part of this interaction change, token cards become full-width board items
in both compact and expanded states. Remove the exterior horizontal whitespace
between token cards and the board/list viewport. The token artwork, identity
border, and interaction surface extend to the available content width.

This is added room, not a global scale increase:

- preserve the current name, type, ability, P/T, status, counter, and action
  control sizes;
- use the additional horizontal space for breathing room, longer text, and
  future explicit controls rather than enlarging every element;
- preserve minimum touch targets and existing internal padding;
- stack compact token rows edge to edge without exterior horizontal or vertical
  whitespace; a full-height 7 px left identity rail replaces the former
  perimeter border and provides the ambient color cue;
- respect the device safe area and any actual list viewport inset; “full-width”
  means edge-to-edge within the usable board content area, not underneath the
  physical screen bezel; and
- apply the layout consistently to special tokens, including Scute Swarm, and
  to tokens without artwork.

The accepted board-wide treatment also applies to tracker and toggle utilities:
all board items are full-width, square, edge-to-edge rows with no exterior
vertical gap and a 7 px left color-identity rail. Utilities expand in place;
their names and applicable description/state fields edit inline, while color
identity and artwork controls live in the expanded card. Existing value,
toggle, and commander actions retain their compact behavior.

Tracker values use the same two-stage inline interaction: tapping the compact
number expands the utility, and tapping the expanded number replaces it with a
bounded numeric field. Done, focus loss, another utility action, or collapse
commits the value; invalid or failed saves retain the editor. Board tracker
values must never open a separate setting dialog.

The wider aspect ratio compounds the expanded-artwork risk described below.
Compact and expanded crops must be tested separately; gaining horizontal space
must not introduce a new focal-point jump, card-frame artifact, or stretch.
The compact artwork surface remains the sole painted artwork layer throughout
expansion and collapse. Keep its decoded image, crop, and width-derived scale
stable while the card changes size. It may translate smoothly to remain
vertically centered in the live viewport, but must not rescale, recrop, reload,
or swap sources. Do not add a delayed expanded-art overlay or crossfade:
testing showed that even a decoded secondary source creates a perceptible
focal-point jump. Any space still beyond the centered image is intentionally
filled by the color-identity gradient.

Full-width rows must retain the complete swipe-delete hit area, stable
reordering geometry, identity-rail visibility, and clipping. Every board item
and its artwork uses square exterior corners. Token expansion must not briefly
restore old margins or rounded corners during its size animation.

### Collapse

Do not add or reserve space for a dedicated collapse button. Existing spatial
collapse gestures are sufficient, while another floating control makes the
dense board visually busier without materially improving discoverability.

Collapse triggers:

- tapping outside the expanded token;
- tapping a noneditable, non-action portion of the expanded token;
- tapping another token, which collapses the first without expanding the
  second; and
- board-level Back after any visible keyboard has been dismissed.

Interactive fields, status/counter/artwork regions, and action buttons consume
their own taps and must not collapse the card. A tap that ends an active edit
commits through the focus-loss save path before collapse. Keyboard dismissal by
itself does not require collapse.

Do not collapse merely because a bottom sheet was opened and dismissed.

### Keyboard behavior

- Tapping a field requests focus after the expansion frame completes.
- The platform keyboard supplies the Done/check affordance; do not add a second
  check button inside the token card.
- Keyboard Done/check and focus loss commit through the same save path.
- Invalid input remains governed by the current field's validation/clamping.
- Scrolling the board may dismiss the keyboard but must commit or safely retain
  the edit; it must not silently discard text.
- The focused field must be scrolled above the keyboard when necessary.

## Spatial Layout

The expanded card retains the compact card's visual hierarchy:

```text
┌─────────────────────────────────────────────┐
│ Name                          sick ready tap │
│ counter pills  +                            │
│ Type                                        │
│ Abilities                                   │
│ W U B R G  art                        P / T  │
│ existing token actions                      │
└─────────────────────────────────────────────┘
```

The existing background artwork remains a card layer. Text retains
`BackgroundText` treatment for legibility. Expansion reveals room around the
same elements instead of rearranging them into the full-screen detail layout.

The vertical order is locked: name/status, the existing counter region with its
add-counter affordance, type, abilities, a compact characteristics row holding
the inline color selector and artwork control at left with P/T anchored right,
then the existing action row. Expansion must not move counters below abilities
or create a separate counter-control section. Editable fields remain bounded to
their content regions and must not force the compact hierarchy into new rows.

Expanded artwork fills the card using the available derived crop without
mutating the persisted artwork preference merely to produce a taller crop. The
color-identity gradient is always painted beneath expanded artwork, so any
space not covered by the crop reveals an intentional identity field instead of
the neutral card background. Human review still determines whether the crop
and gradient balance is visually satisfying across representative artwork.

## Field Behavior

### Name

- Tap the rendered name to replace it in place with a single-line text field.
- Preserve the current font weight and approximate footprint.
- Save on Done/check or focus loss.
- Empty-name handling must match current detail behavior.

### Power/toughness

- Tap the displayed P/T block to edit the raw stored P/T string.
- Keep it anchored at the lower/right card position.
- Displayed counter modifications remain derived; editing changes the base P/T,
  not its counter-adjusted presentation.

### Type

- Tap the rendered type line to edit the raw type string.
- Preserve italic/read-only styling when not editing.

### Abilities

- Read-only mode uses `ManaText` and renders supported wildcards.
- Edit mode shows the untouched raw brace syntax in a multiline text field.
- A token with no abilities still shows a subdued, italicized placeholder text
  box labeled **Abilities** in the normal abilities region. It visually reads
  as empty/inactive until touched, but it is not actually disabled: tapping it
  starts an empty multiline ability edit.
- Accessibility semantics must announce the placeholder as an editable empty
  abilities field, not as a disabled control.
- Saving abilities must not reconstruct the `Item` or alter artwork metadata.
- Preserve the existing hard maximum height used for truncated ability text;
  long abilities do not make the expanded token grow beyond that region.
- In expanded read-only mode, the bounded abilities region becomes vertically
  scrollable so the user can inspect all rendered text and Mana symbols.
- Tapping within the region still enters raw multiline editing. The editor uses
  the same bounded height and scrolls internally around the cursor/selection.
- Vertical drags that begin inside the abilities region scroll its text rather
  than the board. Board scrolling remains available from the rest of the token
  and surrounding list; nested scrolling must not accidentally collapse the
  token or discard an edit.

### Total, tapped, untapped, and summoning sickness

- The existing upper-right status summary is the single visible source for
  total/tapped/ready/summoning-sick state. Do not repeat those values in an
  expanded control row.
- Tapping that summary opens a focused status/count bottom sheet containing the
  exact controls needed to edit total, tapped/untapped distribution, and
  summoning sickness, including clearing summoning sickness.
- The sheet reuses the existing numeric editing rules and clamping for total,
  tapped, and summoning-sick values.
- Untapped remains derived as `total - tapped` and is not independently edited.
- Tap and sickness use the established Mana glyphs; ready/untapped retains the
  existing ready-device icon.
- Increasing total continues applying summoning sickness according to settings,
  P/T, and haste.

### Colors

Color identity uses a compact inline segmented W/U/B/R/G control in the lower
characteristics row. Each segment exposes selected/unselected state, toggles
directly, has an individual accessibility label, and persists immediately. An
empty selection represents colorless. This replaces the color-selection bottom
sheet in the inline workflow and immediately refreshes the identity rail and
gradient.

### Artwork

Tap the visible artwork or a clear artwork affordance to open the existing
`ArtworkSelectionSheet`. Inline expansion does not duplicate downloading,
preference, removal, or artist-credit logic. Artist credit belongs beneath the
set code inside **Select Token Artwork**, not on the expanded card.

### Expanded artwork aspect-ratio risk

The current artwork treatment is tuned for normally sized token cards. Most
artwork definitions point at complete Scryfall card-printing images, which are
then cropped into the token card's much wider background ratio. Making that
same background substantially taller can expose parts of the source card that
were never intended to be visible, produce an unattractive crop, or make the
artwork appear to shift as the token expands.

This is a visual constraint the implementation intentionally tolerates; not
every printing will fill the expanded background. Stable spatial continuity is
more important than replacing the source with a more flexible crop.

### Resolved implementation comparison

The implementation compared:

- **A — current source:** stored Scryfall `large` URL plus the existing manual
  card-frame crop percentages;
- **B — first candidate:** derive the equivalent Scryfall `art_crop` URL for
  expanded display and do not apply the full-card crop percentages again.

The current generated URLs use `/large/front/.../<scryfall-id>.jpg`; the
candidate can derive `/art_crop/front/.../<scryfall-id>.jpg` without changing
the selected artwork identity. The full URL is already used as the artwork-cache
key, so the two source variants cache separately.

Do not rewrite `Item.artworkUrl`, artwork preferences, definitions, or artwork
options during this comparison. `art_crop` is an expanded-display derivative;
the selected full-card source remains canonical for complete previews and
metadata/artist attribution. If derivation is unsupported, download fails, or
the source is custom/non-Scryfall artwork, fall back gracefully to the canonical
URL and its established crop behavior.

Representative-device testing rejected the expanded `art_crop` handoff because
it visibly shifted the focal point after the size transition. Expanded board
cards therefore retain renderer A as one persistent surface. The derived
`art_crop` path is not part of the active board-card composition.

The underlying mitigation choices remain:

1. **Cap the artwork viewport height.** Preserve the existing crop through a
   defined maximum height. Beyond that point, keep/zoom the art treatment while
   the expanded controls continue below or over a stable background treatment.
   This avoids a data migration but may visibly enlarge, soften, or repeat the
   artwork and needs a deliberate transition at the cap.
2. **Use Scryfall `art_crop` assets.** Add or derive the art-crop URL for artwork
   definitions and use that image for flexible expanded backgrounds. This gives
   the renderer illustration-focused source material without card frame/text,
   but changes the artwork data pipeline, cache behavior, persistence/fallback
   rules, and potentially CDN request volume. Existing full-card previews and
   artist attribution must continue using the appropriate metadata/source.

Third-party collaborator artwork should eventually be allowed to provide a
purpose-built background crop or sufficiently flexible source image. That will
reduce the Scryfall card-frame constraint, but custom/collaborator artwork still
needs an explicit aspect-ratio contract and fallback crop behavior. That
contract is intentionally deferred to the implementation spike: evaluate real
custom and collaborator samples alongside the expanded renderer, then document
the accepted source dimensions/aspect ratio and any optional focal-point or crop
metadata. Until then, preserve the existing custom-art behavior and do not reject
previously accepted uploads merely because they lack new metadata.

Before implementation, test both approaches against unusually short and tall
expanded cards, long ability text, tokens with many counters, and several
Scryfall printings whose subjects sit near an edge. Expansion and collapse must
not visibly jump between unrelated focal points. The solution must also preserve
the existing custom-art path and must not discard artwork definitions while
editing other token fields.

## Counters

Counter pills remain in their compact-card position. In expanded mode, tapping
the existing counter region opens a counter-management bottom sheet. Do not add
a separate Counters button below it. The counter region remains directly below
the name row and above type and abilities, even as the card grows.

The expanded card displays at most two complete wrapped rows of counter pills.
If additional counters do not fit, replace the remaining inline content with a
clearly tappable ellipsis overflow affordance. Tapping either a visible counter
pill, the ellipsis, or otherwise within the counter region opens the same
counter-management sheet containing the complete counter list. Do not introduce
a horizontal counter slider in v1; it competes with board gestures and hides
the existence of off-screen counters less clearly than the explicit overflow.

Proposed sheet responsibilities:

- display built-in and custom counters;
- increment/decrement existing counters;
- tap a value for direct numeric entry;
- remove a custom counter when it reaches the established removal condition;
- launch or embed the existing counter search for adding a counter.

The first implementation reuses the existing `CounterSearchScreen`. From the
counter-management sheet, **Add Counter** dismisses the sheet and opens the
existing full-screen search. Returning from search restores the board with the
same token expanded when it still exists. This deliberately favors proven
behavior over broadening the first inline-details implementation.

The consolidated follow-up is intentionally out of scope here. See
`inline_counter_workflow_v2.md`.

## Token Actions

The current compact card exposes remove, add, ready, tap, +1/+1, clone, and
split directly. Preserve that action row in the exploratory MVP:

- Lowest behavioral change.
- Common game actions remain one tap away.
- Expanded editing adds height without hiding established controls.

Validate inline editing before combining it with a redesign of every token
action. Do not add generic **More** or **More details** controls: no missing
operation currently justifies either.

## Gesture Arbitration

Expanded mode must define ownership of gestures that currently overlap:

- Child field/action taps always win over card expansion/collapse.
- Swipe-to-delete remains available while a token card is expanded, but is
  disabled while an inline text field is active.
- Long-press reorder is disabled for the expanded row while editing.
- Horizontal gestures inside a text field must select text, not dismiss the row.
- Tapping blank expanded-card space must not steal focus before the field save
  callback runs.

Expanded tokens may be swiped directly because physical testing showed that
removal is a common action while reviewing the open card. Active editors remain
protected so horizontal text-selection gestures cannot dismiss the row.

## Reuse and Architecture

### Extract shared editing behavior

The current `ExpandedTokenScreen` already implements the field semantics. Do
not create a second independent set of save/clamp rules inside `TokenCard`.

Likely reusable pieces:

- a token-edit session/controller that owns active field, text controllers,
  focus nodes, numeric edit state, and save methods;
- reusable editable text and numeric-value widgets;
- existing artwork and split sheets;
- reusable counter rows or a counter-management sheet;
- shared provider methods for mutations.

During implementation, extract and reuse the proven behavior from the existing
full-screen detail route rather than rewriting its rules independently. Once
the operation inventory and acceptance checks pass, remove the old token-detail
route, navigation entry, and obsolete screen-specific composition. Do not ship
parallel detail experiences or preserve dead UI as an in-app fallback; Git
history retains the prior implementation.

### Expansion animation

There is no existing expansion component. The card already has intrinsic
height, layered artwork, and an `AnimatedContainer` in the board row. Add the
smallest animation mechanism that handles child-size changes without duplicating
the artwork or token state.

### Persistence

- Edit the existing `Item`; do not create a replacement item.
- Route every edit through the existing model/provider semantics.
- Do not alter `order`, artwork URL/set/options, counters, tap distribution, or
  sickness unless that field/action is explicitly edited.
- Field save completion must remain safe if Hive rebuilds the list immediately.

## Accessibility

- Expanded/collapsed state is announced and exposed as a button state.
- Every editable value has a semantic label and edit affordance.
- Read-only Mana symbols keep their spoken expansions; editors expose raw text
  without duplicate semantics.
- Status, Artwork, and Counters controls meet touch-target requirements.
- Focus order follows the visible card order rather than implementation order.
- Large text and keyboard navigation must not trap the user inside the row.

## Full-Screen Detail Retirement

Inline token details replace `ExpandedTokenScreen`; they are not an additional
mode. The old screen may remain temporarily while shared editing behavior is
extracted and parity is verified, but completion requires removing its route,
tap navigation, and dead screen-specific code. Do not add **More details**, an
accessibility fallback route, or a setting that restores the old screen.

### Completed operation inventory

The current `ExpandedTokenScreen` has been audited. No operation requires a
generic **More** control:

| Current detail operation | Inline-details destination |
|---|---|
| Edit name | Tap name |
| Edit base P/T | Tap P/T |
| Edit type | Tap type |
| Edit abilities | Tap abilities/empty Abilities placeholder |
| Select or remove artwork | Tap artwork → existing artwork sheet |
| Edit color identity | Inline segmented W/U/B/R/G selector |
| Set total, tapped distribution, or sickness | Tap upper-right status summary → status/count sheet |
| View untapped count | Derived in status summary/sheet |
| Edit built-in or custom counters | Tap counter region → counter-management sheet |
| Add a counter | Counter sheet → existing full-screen counter search in v1 |
| View modified P/T | Existing rendered P/T remains derived from base P/T and counters |
| Split stack | Existing split action button/sheet |
| Clone, double, add/remove, ready/tap, +1/+1 | Existing action row |
| Delete token | Swipe the compact or expanded card while no inline field is active |

Deletion intentionally has no added button while expanded. The existing swipe
gesture remains available until an inline field becomes active, keeping the
expanded action row from growing while protecting unsaved text edits.

## Files Expected to Change

| File | Expected responsibility |
|---|---|
| `lib/screens/content_screen.dart` | expanded token identity; wrapper gesture rules |
| `lib/widgets/token_card.dart` | compact/expanded composition and entry points |
| `lib/screens/expanded_token_screen.dart` | source proven behavior during extraction, then remove |
| `lib/models/item.dart` | no schema change expected |
| `lib/providers/token_provider.dart` | reuse existing mutation methods; add only missing explicit operations |
| new shared token-edit controller/widgets | active field, focus, validation, save behavior |
| new token actions/counter sheet, if approved | secondary operations |
| `lib/widgets/split_stack_sheet.dart` | reuse unchanged where possible |
| `lib/widgets/artwork_selection_sheet.dart` | reuse unchanged |

## Phased Experiment

### Phase 0: interaction prototype

- Expand/collapse one card in place.
- Preserve card artwork and visual anchors.
- Keep reorder disabled while expanded; allow token swipe-delete unless an
  inline field is active.
- No mutation behavior beyond what is necessary to test board ergonomics.

### Phase 1: core inline editing

- Name, P/T, type, abilities.
- Status/count sheet for total, tapped/untapped, and summoning sickness.
- Save on confirm and focus loss.
- Remove the old full-screen detail route after parity validation.

### Phase 2: secondary controls

- Artwork and color entry points.
- Counter-management sheet.
- Preserve the existing token action row.

### Phase 3: product decision

- Compare speed, accidental edits, board stability, and discoverability against
  the current full-screen detail route.
- Refine the inline model as needed; do not ship both detail experiences.

## Acceptance Checklist

### Expansion

- [ ] One token expands in place without changing persisted board order.
- [ ] Expansion visibly eases, softly overshoots, and settles; it never snaps
      directly to the expanded height or produces a distracting spring effect.
- [ ] Compact and expanded tokens occupy the full usable board width without
      scaling up their internal typography or controls.
- [ ] Tracker and toggle utilities use the same full-width, square, zero-gap
      surface and left identity rail without changing utility-specific actions.
- [ ] Full-width layout remains correct for artwork-free and special tokens and
      does not alter tracker/toggle sizing.
- [ ] Only one token can be expanded at a time.
- [ ] Tapping another token safely saves/collapses the first but requires a
      second tap to expand the new token.
- [ ] The bottom-center floating collapse control reliably collapses dense and
      ordinary token layouts without displacing other controls.
- [ ] Its overlapping hit target belongs only to the expanded token and never
      activates the following token.
- [ ] Provider rebuilds do not lose expansion or active text.
- [ ] Collapse restores the current compact card exactly.
- [ ] Artwork remains visually continuous while expansion/collapse reveals or
      hides it; centering may translate smoothly, but it does not flash,
      rescale, reload, or swap crop/source.
- [ ] Expansion does not expose card-frame artifacts or cause unacceptable
      artwork focal-point/crop jumps.
- [ ] Expansion never mutates the canonical artwork URL, selected printing,
      crop metadata, or cached artwork identity.

### Editing

- [ ] Name, base P/T, type, and raw abilities save on Done/check and focus loss.
- [ ] Done/check is supplied by the keyboard; no redundant card check appears.
- [ ] Mana symbols render only after abilities return to read-only mode.
- [ ] Tokens without abilities show the subdued italicized **Abilities**
      placeholder, and tapping it opens an empty editable field.
- [ ] Long rendered and raw ability text stays within the existing height cap
      and scrolls internally without moving or collapsing the token.
- [ ] Long abilities remain usable and do not erase artwork definitions.
- [ ] Total/tapped/sickness validation matches the existing detail screen.
- [ ] Untapped remains correctly derived.
- [ ] Cancel/invalid input behavior is explicit and consistent.

### Gestures and keyboard

- [ ] Child controls never accidentally collapse the card.
- [ ] Swipe deletion cannot trigger while editing.
- [ ] Reorder cannot begin while editing.
- [ ] Keyboard appearance keeps the active field visible.
- [ ] Scrolling/focus loss does not discard an edit.
- [ ] Back dismisses keyboard before collapsing or leaving the board.

### Secondary workflows

- [ ] Artwork sheet preserves URL, set, options, and future artist credit.
- [ ] Color identity opens a reusable selector sheet and correctly handles
      colorless, mono-color, and multicolor identities.
- [ ] The Mana color-identity indicator remains beside the token name.
- [ ] Counter pills remain below the name and above type/abilities in both
      compact and expanded compositions.
- [ ] No more than two complete counter rows render inline; overflow produces a
      tappable ellipsis that opens the complete counter sheet.
- [ ] Saving color identity immediately refreshes the border/indicator without
      altering artwork definitions or unrelated token fields.
- [ ] Counter management preserves every built-in and custom counter behavior.
- [ ] V1 Add Counter dismisses counter management, opens the existing full-screen
      search, and returns to the still-expanded token safely.
- [ ] Tapping the upper-right status summary opens total/tap/sickness controls.
- [ ] Split dismisses safely before mutation and returns to a valid board state.
- [ ] Clone, double, add/remove, ready/tap, and delete remain reachable.
- [ ] Every existing detail operation has a specifically named inline or sheet
      destination; no generic More control is required.
- [ ] The old token-detail route, navigation entry, and obsolete screen-specific
      code are removed after parity validation.

### Non-regression

- [ ] Tracker and toggle utility actions, navigation, persistence, swipe, and
      reorder behavior remain unchanged.
- [ ] Reordering compact cards behaves unchanged.
- [ ] Full-width token swipe-delete and reorder hit regions remain reliable.
- [ ] Deck save/load and undo snapshots remain unaffected.
- [ ] Light/dark themes, large text, VoiceOver/TalkBack, and small screens remain usable.

## Product Decisions Complete

Inline token details ship as the default and only token-detail interaction once
implemented. Do not add a development feature flag, staged user rollout,
permanent Settings toggle, or compatibility mode for the former full-screen
detail route. Implementation branches and normal pre-release testing provide
the development boundary; the shipped product commits fully to the new model.

## Human Review Gate

Complete everything that can be validated mechanically before review. Human
acceptance then covers:

- a low-fidelity interaction mockup demonstrates expansion on a realistic board;
- expanded swipe/reorder rules are chosen;
- the `art_crop` comparison is completed and an expanded-artwork default and
  fallback are chosen;
- every current detail operation has a named destination;
- the prototype is judged meaningfully faster or clearer than the current detail route.

## Implementation Handoff

Completed before human review:

- board-owned single-token expansion with guarded collapse, Back, outside-tap,
  swipe, and reorder behavior;
- full-width, square, zero-gap rows and left identity rails for tokens,
  trackers, and toggles;
- edge-to-edge compact token stacking without exterior vertical whitespace,
  while retaining collapse-control clearance beneath an expanded token;
- inline name, P/T, type, and bounded raw-abilities editing;
- focused status, color-identity, counter-management, and artwork workflows;
- measured two-row counter overflow that respects accessibility text scaling;
- canonical-versus-`art_crop` expanded rendering with canonical loading/failure
  fallback and race-safe image replacement;
- save-failure rollback that keeps the editor expanded;
- expanded/collapsed semantics, spoken color names, and keyboard visibility
  follow-up; and
- removal of `ExpandedTokenScreen` and its route dependency.

Mechanical verification:

- focused analysis of every touched Dart file: clean;
- full-project analysis: no new findings (the existing project lint backlog
  remains); and
- Android debug APK, iOS Simulator app, and web bundle build successfully; the
  iOS build also installs and launches with the existing simulator board data.

Human review remains responsible for renderer preference, focal-point quality,
physical-device keyboard feel, dense-board spacing, and overall interaction
speed/discoverability. Do not move this document to `new_release/` until that
acceptance pass succeeds.
