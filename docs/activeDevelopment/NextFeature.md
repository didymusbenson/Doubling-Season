# Feature Priority Queue

**Last updated:** 2026-08-27

Inline Token Details is the active next-priority feature. Implement and verify
everything possible before its human interaction and artwork review gate.

## Active Priority

1. **Inline Token Details**
   Active specification: `in_progress_features/inline_token_details.md`. Expand
   tokens into editable board cards, preserve established game actions, and use
   focused sheets for secondary operations. Human review will choose the final
   expanded-artwork treatment and validate the interaction feel.

## Next Feature Being Scoped

- **Artist Credit**
  Full specification: `todo_features/ArtistCredit.md`. Carry artist metadata
  per artwork variant, place credit beneath set codes in the shared **Select
  Token Artwork** sheet, display user-uploaded artwork as `custom`, and leave
  room for future collaborator names or social handles.

## Ranked Backlog

1. **Undoable board wipes**
   Reuse the `BoardUndoSnapshot` infrastructure introduced for Brudiclad for
   all three board-wipe actions: **Set to 0**, **Delete All**, and **Delete All
   & Reset Rules**. After a successful wipe, show the established completion
   flow with **Undo / Accept**. Undo must restore the exact pre-wipe token,
   tracker, and toggle state without replaying game events. Extend the snapshot
   to include rules enablement before supporting **Delete All & Reset Rules**;
   restoring only the board for that action would be incomplete.

2. **TokenProvider consolidation**
   Refresh `todo_features/TokenProviderImprovement.md` against the shared merge,
   artwork-resolution, immutable-plan, and creation-result infrastructure added
   with Rhys and Brudiclad. The objective is one consistent creation pipeline,
   not refactoring for its own sake.

3. **Enters Tapped**
   Refine `todo_features/EntersTappedToggle.md` before implementation. The
   original/core request was a per-token “new additions enter tapped” behavior;
   the later global setting was an expansion and is not yet locked in.

4. **Mana symbol rendering**
   Implemented and awaiting acceptance in
   `in_progress_features/ManaSymbolRendering.md`. Validate the pinned, locally
   bundled Mana font across colored/generic pips, accessibility, themes, and
   platforms before moving it into the next release.

5. **Better token-search filters and sorting**
   Refine the `FeedbackIdeas.md` proposal. Current likely scope is a persisted
   Popular / A–Z control; avoid duplicating the existing Recent tab without a
   clear benefit.

6. **Ordered-board architecture**
   Revisit `todo_features/orderedListManagement.md` to centralize unified board
   ordering and reduce the number of touchpoints required for future board item
   types and insertion flows.

7. **Additional event-bus triggers**
   Implement `todo_features/busTriggers.md` incrementally as concrete utilities
   require death, tap/untap, counter, or creation-interceptor events.

8. **Custom-art crash hardening**
   Continue `customartcrashbug.md`: reproduce high-volume custom-art loading,
   then add decode throttling/cache sharing or visibility-based loading as the
   evidence supports.

## Explicitly Descoped

- **Dungeon support** belongs to a different app and must not return to this
  project's roadmap.

## Planning Notes

- Complete Inline Token Details through its documented human review gate before
  advancing Artist Credit.
