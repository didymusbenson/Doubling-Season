# Feature Priority Queue

**Last updated:** 2026-08-30

The 1.11 implementation scope is closed aside from acceptance testing. New
implementation work proceeds through the immediate queue below.

## 1.11 Acceptance Queue

These features are implemented; they are not competing for new implementation
priority:

- **Inline Token Details** — human interaction and artwork review.
- **Mana symbol rendering** — visual, accessibility, theme, and platform review.
- **Artist Credit** — artist-placement, readability, upload, and migration review.
- **Token-creation consolidation** — remaining cross-entry-point acceptance.
- **Custom-art crash hardening** — high-volume physical-device acceptance.

## Immediate Implementation Queue

1. **Ordered-board architecture**
   Placement decisions are locked and implementation is in progress in
   `in_progress_features/orderedListManagement.md`.

2. **Undoable board wipes**
   Implemented; validation is tracked in
   `in_progress_features/UndoableBoardWipes.md`.

## 1.12 or Future

1. **Enters Tapped**
   Refine `todo_features/EntersTappedToggle.md` before implementation. The
   original/core request was a per-token “new additions enter tapped” behavior;
   the later global setting was an expansion and is not yet locked in.

2. **Better token-search filters and sorting**
   Refine the `FeedbackIdeas.md` proposal. Current likely scope is a persisted
   Popular / A–Z control; avoid duplicating the existing Recent tab without a
   clear benefit.

3. **Inline counter workflow v2**
   Continue `todo_features/inline_counter_workflow_v2.md` only after 1.11. It
   remains a convenience refinement, not part of Inline Token Details acceptance.

4. **Additional event-bus triggers**
   Implement `todo_features/busTriggers.md` incrementally as concrete utilities
   require death, tap/untap, counter, or creation-interceptor events.

5. **Token-pipeline optimizations**
   Deferred on 2026-08-29. Optional caching, rollback, and further specialized-
   path reuse live in `todo_features/Optimizations.md`; none is required for
   1.11 acceptance.

## Explicitly Descoped

- **Dungeon support** belongs to a different app and must not return to this
  project's roadmap.
