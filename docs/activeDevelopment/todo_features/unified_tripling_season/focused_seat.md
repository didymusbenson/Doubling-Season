# Phone presentation: fixed Player 1 of an N-player game

**Status: option C approved; implementation isolated on the phone feature branch.**
The feature stays on a dedicated branch and keeps the Tripling Table identity.
See [product scope](README.md) and [decision/progress record](implementation_summary.md).

## Explicit owner decisions (2026-10-30)

- Phone view is always **Player 1 / Seat 1** of the existing N-player game.
  No hot-swapping players. A four-player session remains four-player.
- A compact life surface is fixed at the top, above the token workspace.
  Full commander source/partner relationships and counters remain available.
- Below life, **one scrolling body** contains utilities first, then tokens.
  Do not retain independently scrolling tablet lanes or intermix the two groups.
- Buttons/FABs stay fixed to screen locations, preferably near the bottom-right
  thumb area: direct Add Token, Utilities jump and More (approved C).
- Preserve the newer Tripling Table visual design, not the original phone skin.
- Tablets do not gain compact view in this scope. Phones do not offer full tablet
  layout. Folded phones use Player 1; unfolding reveals the full table.
- Folding/unfolding dismisses menus and modals to closed/default UI states while
  preserving Player 1's board and the underlying complete session.
- Existing token board state and supported enabled utilities survive migration;
  saved decks convert separately. See [board continuity](fresh_board.md).

A true one-player engine and player-count changes on posture are not required.
No additional player-count expansion or network synchronization is implied.

## Layout and UX recommendation

```text
FIXED TOP: Player 1 life, compact commander/status/counter summary
ONE SCROLLING BODY:
  configured utilities (compact direct controls; expansion for management)
  tokens (full-width art, existing inline editing and expansion)
FIXED BOTTOM-RIGHT: selected action architecture
```

The life surface is fixed in position, not an inflexible pixel height. Keep life
the strongest number and the name inside its tap surface. A compact source-art
mini-grid can open the full commander editor; never collapse distinct opponents
or partners into a single damage total. Active counters/statuses take only their
required space; zeros remain editable in the combined editor but absent from the
board summary. Life, commander and status hit targets must remain distinct.

One scroll means no nested utility viewport. Empty sections take zero space and
need no permanent heading. Utilities remain directly usable: simple trackers can
be compact rows, mana a real grid. Do not hide configured utilities or zero mana
colors simply to fit a screenshot. Check individual minus/plus target sizes,
not just the surrounding chip. If three columns squeeze each half too much,
reflow to two columns rather than shrinking touch areas.

The main risk is utilities consuming the initial viewport and becoming distant
when the user scrolls deep into tokens. Prefer a fixed route back to the actual
utilities section over a duplicate pinned mana panel. This preserves one set of
controls and the requested stack. Exact jump/return behavior needs a prototype.

## Action alternatives shown for approval

| Option | Fixed controls | Benefits | Tradeoff |
|---|---|---|---|
| A — One Actions button | One button opens labeled Token, Utilities, Board and Game actions | Smallest resting footprint | Token creation and utility access need an extra tap |
| B — Token + Board | Direct Add Token; secondary Board menu with Utilities, Summary, Start Turn and separate Game/History | Clear priority with restrained permanent controls; recommended baseline | Utility return requires the Board menu |
| C — Direct utility access | Add Token, Utilities jump and More | Fastest return to mana on long boards | Largest overlay footprint; icon clarity and token overlap require care |

The owner selected **C: Add Token + Utilities jump + More**. This supersedes
our initial recommendation of B. Generated concept imagery is expressly excluded
from design context; use the real Table components and these written decisions.
The alternatives above are historical rationale, not additional user modes.

## Scope and interaction

- Life, token/utility edits, player settings and preset loads target Player 1.
- Commander damage retains all source identities and established coupled effects.
- Monarch/Initiative ownership and Day/Night preserve shared-game semantics;
  player counters and City's Blessing retain player scope.
- New Game, global history/undo, archives and Everyone wipes remain whole-game or
  explicitly targeted operations. Never silently retarget them to Player 1.
- Keep undo in History and routine feedback in the affected surface, not toasts.
- Overlay controls reserve no blank full-width lane header. Keep last-item actions
  reachable using appropriate scroll clearance and actual overlay footprints.
- Scrolling over a stepper must not increment accidentally. Preserve existing
  deliberate reorder, collapse-first, hold and inline-edit behavior unless a
  reviewed change is required.

## Assistant design judgments for implementation review

The owner allowed reasonable decisions after design approval; record deviations
and their evidence in the implementation summary instead of inventing approvals.

Recommended policies:
- Close transient menus/modals on posture changes, cancel active holds/pointers
  and dismiss keyboard input. Accepted commands still complete exactly once.
- Retain unfinished drafts by session/player/item without silently committing or
  discarding text. Do not automatically reopen the editor after unfolding.
  Revisit drafts in context; reconcile changed/deleted targets explicitly.
- Temporarily suppress nonessential floating actions while typing rather than
  crowding the keyboard with a large action stack. Keep field/error/save controls
  visible. This is a proposed UX choice, not current implemented behavior.
- Preserve scroll anchors separately per presentation; a raw phone offset is not
  a meaningful tablet-lane offset. Inline expansion is distinct from a modal and
  needs an explicit transition decision in implementation review.

Durable draft survival across app termination is not yet promised. Device/posture
classification and safe window-size thresholds need real-device validation;
width alone must not accidentally enable compact mode on an iPad window.

## Acceptance before feature integration

Test no utilities, mana only, several utilities, long boards, expanded final
tokens, large text, both phone orientations and keyboard validation failures.
Exercise folds during holds, pending saves, edits, menus and history operations.
Verify all hidden seats and partner commander relationships, not only Player 1.

Capture design/UX reviews at realistic populated sizes. Keep 2–4-player tablet
visual/behavioral regressions intact. No automatic route is enabled in the stable
main tablet app merely to expose the experimental preview.
