# Phone feature: decision and implementation summary

**Status: design/mockup approval pending; no phone UI implemented.**
This becomes the end-to-end implementation record after the owner approves a
mockup. The custom Pages preview infrastructure is a separately authorized task,
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

- B (direct Token + Board) is the baseline recommendation; C adds direct utility
  return, A minimizes permanent controls. Await owner selection.
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

## Mockup delivery checkpoint (2026-10-30)

Three generated comparison images were shown in chat, each with the same fixed
life header, scrolling utilities/tokens hierarchy and an open action menu:
A (one Actions button), B (Token + Board), C (direct Utilities access).
The recommendation is B; owner approval is pending. Images are concept studies,
not pixel-accurate app screenshots or proposed replacements for token rules/art.

Durable Space artifacts for later design review:
- A-one-actions.png — `libfile_dee7ba4aef18819196e28b875df2ef10`
- B-token-and-board.png — `libfile_58ae1c067b6c8191bffb8736460c4334`
- C-direct-utilities.png — `libfile_58d9b5a744d08191a6c7cd5ea8fcd2b3`

No phone implementation branch is started by this checkpoint. The owner will
approve a mockup first; infrastructure branches are separate from that approval.
