# Future Optimizations

**Status:** Deferred — not part of 1.11 acceptance
**Last updated:** 2026-08-29

This document collects performance and architectural follow-ups that are not
required for current feature correctness. Items belong here only when the
shipping implementation is complete and the remaining work is optional
optimization or simplification.

## Token-Creation Pipeline

### Cache `TokenProvider.items`

`TokenProvider.items` currently copies and sorts the Hive token box on every
access. Creation and merge flows can read it repeatedly.

A safe cache cannot invalidate only through provider methods because `Item`
models call `HiveObject.save()` directly. Any implementation must use Hive box
notifications or another authoritative listenable-driven invalidation source.
Keep this separate from token-creation behavior changes so stale-state risk is
isolated.

Related record: `../new_release/TokenProviderImprovement.md`.

### General creation rollback

Ordinary multi-result creation currently uses explicit partial-success
semantics. A future all-or-rollback implementation would need to include every
token mutation plus synchronous event-listener side effects such as Cathars'
Crusade tracker changes. Restoring only token stacks would be incomplete.

Reuse the unified `BoardUndoSnapshot` pattern only after defining transaction
boundaries, event suppression, rules-state coverage, and failure reporting.

### Further specialized-path reuse

Scute Swarm, Krenko, the simple Copy action, split operations, deck restore,
Rhys, and Brudiclad retain specialized orchestration because their merge,
artwork, ordering, event, preview, or restore semantics differ.

Revisit only if shared mechanics can be reused without importing
`TokenCreationService` back into `TokenProvider`, adding flag-heavy APIs, or
obscuring event-free restore/transform behavior.

### Unified board-order ownership

Token creation still receives caller-resolved unified board orders, while
`TokenProvider.insertItem()` retains a token-only fallback and treats `0.0` as
an unassigned sentinel.

The full architecture is already tracked in `orderedListManagement.md`. Do not
solve it piecemeal inside the creation executor.

## Existing Optimization Backlog References

- `NextVersionChecklist.md` — UI constants, sorted-item caching, and order
  utility extraction.
- `orderedListManagement.md` — unified token/tracker/toggle order ownership.
- `../customartcrashbug.md` — visibility-based artwork loading only if the shared
  cached renderer remains insufficient on device.
