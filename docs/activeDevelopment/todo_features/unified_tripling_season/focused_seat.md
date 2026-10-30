# Phone presentation: Seat 1 of an N-player game

**Status: DEFERRED / SPECULATIVE / NOT IMPLEMENTED.** See [scope](README.md).

## Confirmed concept

Phone/compact view displays **Seat 1 of the existing N-player session**. If the
user starts or restarts a four-player game while on a phone, it remains a
four-player game; only Seat 1 is shown. Seat-local settings act on Seat 1.

- A conservatively sized life tracker sits above Seat 1's token view.
- Commander damage retains all applicable sources across the N-player table,
  including independent partner sources. Counters and status controls remain.
- Other seats and their state remain intact, not deleted or reset because hidden.
- The token-add FAB needs reconsideration; a cleaner + menu or a few distinct
  FABs should remain near the thumb, toward the bottom right.
- Preserve **Tripling Table's new styles and aesthetic**. This is not a return to
  the old phone visual language, nor a miniature rotated multiplayer table.

This supersedes the earlier exploratory assumption that a genuine one-player
engine was necessary. That engine could be a separate future proposal, but is
not required here. N means the supported session size; no six-player expansion,
network multiplayer or automatic transfer of control is implied.

## Presentation sketch

```text
Compact Seat 1 life surface
  own life + compact commander/status/counter summary
Token workspace
  full-width Table-style tokens and inline expansion
  optional utility presentation (explore below)
                             thumb-reachable action cluster
```

This is a hierarchy sketch, not approved pixel dimensions. The life surface
should serve the phone user's needs without taking tablet-sized vertical space.
Names remain inside their stepper surfaces. Commander sources must be distinguishable
by identity/art, not reduced to a single combined damage number.

The board summary omits zero numeric counters and reserves no empty counter strip;
the combined commander editor still exposes zero-valued counter stepper chips
beneath status chips. Match current Table semantics unless deliberately revised.

## Utility and action alternatives to explore

### A. Token-first view with a compact utility dock

Keep life above tokens. Show selected compact tools, such as mana, in a narrow
expandable dock near the action cluster. Tokens retain most of the screen.

- Benefit: familiar token-first scanning; frequently used mana can be close to thumb.
- Risk: keyboard/safe-area collision and a dock that obscures the last token.
- Prototype: empty dock, mana only, mana plus storm, long names and large text.

### B. A revealable utility shelf

Keep the same life/token hierarchy. A distinct utility action reveals a shelf
using the Table drawer visual language. Closing restores the token workspace.

- Benefit: more tools without permanently sacrificing token height.
- Risk: an extra action for frequently adjusted mana; must not become another
  dense settings modal or hide the life tracker unnecessarily.
- Prototype: immediate mana stepping, return-to-token continuity and keyboard use.

### C. User-selected compact tools below life

Life remains compact at the top; selected mana/utility chips form an expandable
row below it. No tools means no reserved row. Detailed controls open locally.

- Benefit: simultaneous visibility of important values, clear grouping.
- Risk: utilities can grow into a second header that crowds tokens; cap visual
  footprint through a deliberate expansion pattern rather than shrinking targets.
- Prototype: one tool, several tools, utility removal and retained configuration.

These alternatives are proposals, not three modes users must learn. Mana pool
could be the primary utility with optional steppers such as storm. Which tools
are default, optional, persistent or per-game is still a product decision.

For FABs, compare one clearly organized + expansion against two or three distinct
icon-led actions (for example tokens, utilities, game tools). Exact count and
icons are unresolved. Avoid a pile of unlabeled ambiguous buttons, hover/hold
help popups, and an action-menu system that steals the whole screen. Accessibility
names remain required even when there are no visual tooltips.

## Scope and continuity

| Action | Scope |
|---|---|
| Life, player counters/statuses, commander damage editor | Seat 1 as the target; preserve all source-player/partner relationships and coupled effects. |
| Token/utility add, edit, remove and preset load | Seat 1; explicitly preserve established replace/append and history semantics. |
| Player customization | Seat 1, not whichever hidden seat occupies a tablet coordinate. |
| Shared Monarch/Initiative ownership and Day/Night | Preserve whole-game uniqueness and shared state; claiming from Seat 1 still affects other owners where required. City's Blessing and numeric counters retain their appropriate player scope. |
| New Game, archives, global history/undo, Everyone wipe | Whole game or explicit chosen targets, never silently retargeted to Seat 1. |
| Fold/unfold, resize, orientation or presentation override | View only: no reset, new session, opponent loss, replay or data migration. |

A closed foldable may show Seat 1; opening it can reveal the same full table.
Available app-window space and hinge/posture matter more than hardware labels.
Exact breakpoints, transition animation, manual override, focus selection beyond
Seat 1, and what happens to open editors/keyboards during resize remain open.
Keep active drafts and pending command identity safe regardless of the chosen UX.

## Visual and interaction invariants

- Table artwork, full-art/fade behavior, mana/P-T symbols, artist credits and
  token inline editing remain consistent across compact and full-table views.
- Immediate input feedback, durable save/rollback, history-only undo and existing
  hold behavior remain correct. Layout changes must not introduce tap latency.
- Floating controls overlay rather than add a blank lane header. If first-token
  clearance is needed, explore filled artwork space/internal layout rather than
  pushing the card down with an empty margin. Totals/actions remain hittable.
- Empty utility/counter areas take no space. Long content scrolls without losing
  selection, token expansion or draft state.
- No routine toast/snackbar confirmations or tooltips; readable contrast and
  explicit accessible names/states must make actions understandable.
- Native text entry and paste/selection remain usable; keyboard direction and
  platform limitations require actual testing rather than assumed support.

## Future acceptance and unresolved choices

Test a four-player game entirely through Seat 1: adjust life, partner commander
sources, counters and mana; load a preset; restart deliberately; reveal full
table and verify all hidden identities/state are correct. Test compact/full
transitions during holds, pending saves, inline edits and history operations.

Prototype small phones, large text, landscape, tablets choosing compact view,
folded/unfolded devices and narrow multi-window layouts. Verify no silent game
reset or loss of source attribution. Compare utility alternatives with real play,
not only empty screenshots.

Open: exact life height, utility defaults/location, FAB count, other-seat focus,
compact global-game menu design, native keyboard posture behavior and transition
rules. These documents preserve intent without starting implementation.
