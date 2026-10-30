# Phone feature: decision and implementation summary

**Status: option C approved; feature-branch implementation starting.**
This is the end-to-end implementation record for the approved phone direction. The custom Pages preview infrastructure is a separately authorized task,
not permission to start the phone interface.

## Explicit owner feedback

- Fixed Player 1 of an N-player session; no player hot-swap.
- Fixed compact life at top, one scrolling utilities-then-tokens body, fixed
  thumb-accessible controls, newer Table aesthetic.
- No compact tablet mode or full-table layout on phones in this scope.
- Fold/unfold closes menus/modals, preserves gameplay, reveals full table open.
- Preserve migrated live token board and enabled utilities with Table counterparts;
  saved decks must separately import/convert safely. Earlier clear-board idea is
  superseded, not a fallback to apply without permission.
- Separate tablet identity during development; deliberate original-identity
  release cutover later. Phone work stays on a feature branch; stable tablet main
  remains deliverable. Signed feature builds are allowed after implementation.
- Cloud-first editing and commit/push checkpoints; Mac only when necessary for
  native validation/building or explicitly requested.
- Show alternatives before implementation. Once approved, implement end to end,
  perform design/UX reviews and record independent decisions versus user feedback.

## Assistant recommendations / judgment calls (not mockup approval)

- The initial recommendation was B; the owner selected C instead. Implement
  direct Token, Utilities jump and More; do not reinterpret the generated image.
- Return to the actual utility section rather than duplicate pinned mana controls.
- Preserve unfinished drafts when dismissing UI on a fold; do not silently commit
  text or replay accepted commands. Exact durable-draft policy needs validation.
- Preserve/report unsupported migration entries, not silently delete or substitute.
- Separate live board conversion from preset conversion because their semantics
  intentionally differ. Audit source: [saved configurations](preset_audit.md).

## Required record once implementation starts

For each material decision, record: user requirement or assistant judgment,
chosen behavior, reason/alternatives, changed files, regression/visual evidence,
remaining risk and whether owner confirmation changed the choice.

Record source branch/commits, test and design-review outcomes, preview deployment
SHA, signed-build source equivalence, and actual installation/physical testing
separately. Never describe unrun validation as passed. Keep WIP pushed and avoid
merging the phone implementation into main before deliberate integration approval.

## Design approval (2026-10-30)

The owner approved option C **as behavior**: direct Add Token, Utilities jump,
and More. The generated images must not be used or retained as design context.
No generated image is committed here; its shapes, token layout, typography and
artwork are not implementation requirements. Use the actual Table UI and written
owner requirements as the design authority.

Phone implementation is authorized on its feature branch, including design/UX
passes and a summary of independent decisions. Stable tablet main stays separate.
