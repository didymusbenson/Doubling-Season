# Token Creation Pipeline Consolidation

**Status:** Implemented for 1.11 — pending user acceptance testing
**Priority:** Ranked backlog 2
**Complexity:** Medium–High
**Last updated:** 2026-08-29

## Objective

Finish consolidating token creation around the shared rules-result, artwork,
merge, persistence, and event infrastructure that now exists. The remaining
work is a consistency and failure-safety pass, not a ground-up replacement of
`TokenProvider`.

The implementation must preserve the intentionally different semantics of:

- creating a new game object versus adding to an existing stack;
- creating a token versus splitting, copying, transforming, or restoring one;
- event-producing gameplay actions versus event-free deck restore/undo;
- primary results versus replacement and companion results; and
- source-preserving copy artwork versus definition-resolved artwork.

## Progress Since the Original February 2026 Spec

### Shared infrastructure already implemented

- `TokenCreationService` creates companion results and all-peer result sets.
- `RulesProvider.evaluateRules()` produces ordered primary, replacement, and
  companion `TokenCreationResult` values with quantity caps.
- `TokenResultArtworkResolver` resolves saved preferences, database defaults,
  set codes, and artwork options for rules results.
- `TokenMergeCompatibility` provides the shared exact-identity, clean-stack,
  artwork-compatible merge rule.
- Token search, custom-token creation, token-card rule actions, Hare Apparent,
  both Krenko utilities, Academy Manufactor, and Brudiclad use the shared
  result-creation service for at least part of their flow.
- Rhys builds and previews an immutable creation plan before provider execution.
- Brudiclad uses immutable transformation planning plus a unified-board snapshot
  for rollback.
- `TokenCopySemantics` centralizes which board tokens are eligible and whether
  copied P/T is intrinsic.
- Creature ETB events now fire for compatible-stack merges as well as new-stack
  insertion.
- Artwork download failure preserves persisted selection metadata.

### Original work that is now obsolete

- Do not create a second modifier system. The rules engine already implements
  multipliers, replacements, companion creation, Academy Manufactor, and
  Chatterfang-style behavior.
- Do not add a single `createToken(TokenDefinition)` method as the universal
  abstraction. Most current callers operate on resolved
  `TokenCreationResult`s, and copy/restore/transform paths intentionally need
  different semantics.
- Do not make `TokenProvider` resolve user artwork preferences directly for all
  flows. `TokenResultArtworkResolver` is the established rules-result boundary;
  unchanged copy paths preserve source artwork instead.
- Do not route deck restore or board undo through gameplay insertion, because
  those operations intentionally emit no ETB events.

## Current Pipeline Map

| Flow | Primary handling | Additional results | Merge behavior | ETB behavior |
|---|---|---|---|---|
| Token search | caller creates a new stack | shared companion service | primary never merges | new-stack insert |
| Custom token sheet | caller creates a new stack | shared companion service | primary never merges | new-stack insert |
| Token-card add with rules | caller adds/merges/creates | shared companion service | exact clean artwork match | add/merge/insert |
| Scute Swarm | specialized provider method | shared companion service | exact source-art match | merge/insert |
| Krenko utilities | specialized provider method | shared companion service | exact resolved-art match | merge/insert |
| Hare Apparent | shared all-results service | same service | exact resolved-art match | merge/insert |
| Academy Manufactor | shared all-results service | same service | exact resolved-art match | merge/insert |
| Rhys | immutable plan + provider executor | included in plan | exact planned-art match | merge/insert |
| Brudiclad Step 1 | shared all-results service | same service | exact resolved-art match | merge/insert |
| Brudiclad transform | planned provider mutation | none | planned clean-stack merge | deliberately no ETB |
| Copy button | specialized provider method | none | always a separate stack | manual ETB |
| Split/counter split | explicit-order duplicate | none | never merges | deliberately no ETB |
| Deck restore | explicit-order template restore | none | never merges | deliberately no ETB |

## Verified Remaining Gaps

### 1. Duplicate result-creation loops

`TokenCreationService.createCompanionTokens()` and
`createAllFromResults()` contain nearly identical resolve, merge, insert,
sickness, ETB, and artwork-download logic. Their meaningful difference is only
which slice of the result list they process.

This is the safest first consolidation target: introduce one internal executor
and keep the two public intent-revealing entry points.

### 2. Caller-owned primary creation

Token search and the custom-token sheet still construct and insert primary
items independently. They differ in artwork metadata and download behavior:

- search carries URL, set, and all artwork options and starts a background
  download;
- custom creation carries only the selected URL; and
- both correctly apply summoning sickness after Hive insertion.

The shared layer needs an explicit primary-result request rather than assuming
all primaries should merge. Search and custom creation intentionally create new
stacks, while token-card additions may merge.

### 3. Specialized creation remains partly duplicated

Scute Swarm and Krenko correctly own their card-specific quantity/source rules,
but still duplicate portions of item construction, sickness, artwork, insertion,
and ETB behavior. They should delegate the final resolved-result commit where
that does not change their source-art and merge semantics.

The simple Copy action should remain specialized unless a shared executor can
express “always create one adjacent stack, preserve source artwork, discard all
counters, and emit ETB” without hidden flags or behavior changes.

### 4. Multi-result work is not atomic

The shared service commits results sequentially. If a later insert/save fails,
earlier inserts, merges, and synchronous ETB side effects remain. Search and
custom flows can likewise persist the primary before companion creation fails.
Rhys warns that partial creation may have occurred. Brudiclad is the only
multi-step flow currently wrapped in a board snapshot rollback.

Before implementation, choose and document one policy:

- **Explicit partial success:** return a typed result listing committed and
  failed operations, keep already-fired events, and show accurate UI feedback;
  or
- **All-or-rollback:** snapshot every affected token and utility before commit,
  restore on failure without replaying events, and account for Cathars' Crusade
  or other listener mutations in the snapshot.

Silent partial completion must not be treated as success.

### 5. Persistence timing differs between new stacks and merges

New-stack flows insert with sickness zero, emit ETB, then assign sickness through
an auto-saving setter whose save is not awaited. Merge flows assign sickness,
explicitly await `save()`, then emit ETB. This creates observable and durability
differences.

The consolidated commit contract must define when the item is fully persisted,
when listeners may observe it, and which saves are awaited. Summoning sickness
must still be applied only after insertion because its setter calls `save()`.

### 6. ETB behavior is coupled to insertion method

`insertItem()` emits creature ETB; `insertItemWithExplicitOrder()` does not.
Merge paths emit ETB manually. This is correct today but easy to misuse.

The shared API should make event intent explicit (`gameplayCreation`,
`eventFreeRestore`, or equivalent typed operations) instead of relying on the
caller knowing which low-level insert method fires events. Transform, split,
deck restore, and undo must remain event-free.

### 7. Board ordering is a dependency, not part of this refactor

Most callers calculate a unified token/tracker/toggle order. `insertItem()` has
a token-only fallback and treats `0.0` as “unassigned,” even though zero is a
valid board position. Rhys contains a special guard against calculating zero.

Do not duplicate another order algorithm inside the creation service. Accept an
explicit resolved order or order plan for now, and coordinate with
`orderedListManagement.md` for the eventual unified-order owner.

### 8. Artwork download callbacks are inconsistent

The shared service and search locate the first item with a matching artwork URL
to trigger a rebuild; Krenko closes over the created item; Rhys checks
`item.isInBox` and notifies the provider. Multiple items can share a URL, and a
token may be deleted or change artwork before a download finishes.

Consolidation should use the created item's Hive identity/object reference,
verify that it is still persisted and still selects the same URL, and never
clear artwork metadata because cache availability is transient.

### 9. Resource and UI failure cleanup varies

Several callers create a temporary `TokenDatabase` without `try/finally`, and
some creation buttons reset loading state only on success. The commit API should
propagate typed failures while UI callers guarantee database disposal, mounted
checks, progress reset, and non-duplicating retry behavior.

### 10. `TokenProvider.items` remains uncached

Every access copies and sorts the Hive box. Creation and merge flows can access
it repeatedly. This is related performance work, but cache invalidation must
account for direct `HiveObject.save()` calls and box-listenable updates—not only
provider methods. It should be implemented separately from behavioral
consolidation so stale-item risk is isolated.

## Proposed Remaining Design

### A. Typed commit request

Use one internal representation for an already-resolved creation operation. It
must carry:

- identity and quantity;
- resolved artwork URL/set/options;
- explicit order;
- tapped and summoning-sickness policy;
- merge policy (`never`, `compatibleCleanStack`);
- event policy (`creatureEtb`, `none`); and
- source/copy semantics where applicable.

It must not evaluate rules, choose UI ordering, or silently infer whether an
operation is a restore or gameplay action.

### B. Shared result executor

Refactor the two `TokenCreationService` loops into one executor that:

1. receives an immutable list of commit requests;
2. resolves the merge target against a stable pre-commit view;
3. performs awaited Hive writes in deterministic order;
4. applies the selected failure policy;
5. emits events exactly once for committed creature quantities;
6. returns a typed outcome with created items, merged quantities, caps, and
   failures; and
7. schedules identity-safe artwork caching after persistence.

Keep intent-specific wrappers for companion-only and all-result flows.

### C. Incremental caller migration

Migrate in this order:

1. Deduplicate the two existing shared-service loops without changing callers.
2. Move search primary creation into the typed executor with `merge: never`.
3. Move custom primary creation, preserving staged-file ownership and library
   persistence semantics.
4. Move token-card rule additions, preserving selected-stack behavior.
5. Reuse the executor for the final Krenko and Scute commit steps where parity is
   exact.
6. Evaluate Rhys reuse only after its adjacency plan, unchanged-source artwork,
   and preview/commit identity remain explicit.
7. Leave copy, split, deck restore, undo, and Brudiclad transformation on their
   specialized paths unless the typed API improves clarity without flags.

## Explicitly Out of Scope

- Redesigning the rules engine or modifier ordering.
- Changing token multiplier behavior.
- Changing merge identity rules.
- Centralizing unified-board ordering.
- Making deck restore fire gameplay events.
- Replacing the Hive schema or type IDs.
- Adding automated tests; this project uses manual functional validation.

## Manual Acceptance Checklist

- [ ] Token search creates tapped/untapped primaries with correct art metadata.
- [ ] Custom tokens preserve staged and saved custom artwork.
- [ ] Summoning sickness is correct after immediate use and after app restart.
- [ ] Normal add, rule replacement, and companion results match the preview.
- [ ] Clean compatible stacks merge; countered or different-art stacks do not.
- [ ] Cathars' Crusade increments exactly once for every created creature amount.
- [ ] Noncreature tokens and transformations do not emit creature ETB.
- [ ] Scute Swarm and both Krenko utilities preserve current quantity and artwork.
- [ ] Rhys preview and commit remain identical for all result groups.
- [ ] Brudiclad rollback and user Undo restore board and utility state exactly.
- [ ] Split, counter split, deck load, and undo remain event-free.
- [ ] Remote artwork failure preserves URL, set, and options for retry.
- [ ] Deleting or changing a token during artwork download causes no stale update.
- [ ] Simulated later-result failure follows the chosen partial/rollback policy.
- [ ] Loading indicators reset and temporary databases dispose after failure.
- [ ] Unified board order remains stable around tokens, trackers, and toggles.
- [ ] Large multi-result actions remain responsive and report quantity caps.

## Implementation Decisions Completed

The following decisions were completed before implementation:

1. partial-success versus all-or-rollback semantics;
2. the typed event policy for every operation category;
3. whether primary custom-token library persistence participates in rollback;
4. whether the executor owns artwork resolution or accepts resolved artwork;
5. which paths intentionally remain specialized; and
6. whether `items` caching ships separately after behavior consolidation.

## Locked Implementation Decisions

**Recorded:** 2026-08-29, before implementation

1. **Failure policy:** Preserve the current explicit partial-success semantics
   for ordinary multi-result creation in this change. The executor returns a
   typed outcome describing committed work and rethrows persistence failures;
   callers must not report full success after an exception. Brudiclad retains
   its existing unified-board rollback. General all-or-rollback creation is
   deferred because synchronous ETB listeners mutate utility state outside the
   originating token write and require a broader transaction design.
2. **Event policy:** Every commit request carries an explicit event policy.
   Gameplay token creation emits creature ETB exactly once per committed
   quantity. Restore, split, undo, and transformation paths remain event-free.
3. **Custom-token library persistence:** Saving a reusable custom definition and
   recent-entry metadata remains independent from board mutation and is not
   rolled back if later board creation fails.
4. **Artwork boundary:** Callers or `TokenResultArtworkResolver` provide fully
   resolved artwork to the executor. The executor does not query preferences.
   This preserves source artwork for copy flows and definition artwork for
   replacements/companions.
5. **Specialized paths:** Copy, split, deck restore, undo, Brudiclad
   transformation, and Rhys planning remain specialized. Scute and Krenko may
   share final commit mechanics only where their current merge/artwork/order
   behavior is represented explicitly.
6. **Items caching:** Deferred to a separate change after behavioral
   consolidation because direct `HiveObject.save()` calls require listenable-
   driven invalidation.
7. **Order ownership:** All migrated callers continue supplying resolved unified
   board orders. The `0.0` sentinel and unified ordering architecture are not
   changed here.

## Implemented Scope

**Implemented:** 2026-08-29

- Added typed commit requests, merge policy, event policy, commit outcomes, and
  partial-failure exceptions to `TokenCreationService`.
- Replaced the duplicated companion/all-result loops with one awaited executor.
- New-stack sickness is now persisted before the explicit creature-ETB event.
- Artwork caching now retains the exact created item, verifies `isInBox`, and
  verifies that its selected URL has not changed before triggering a rebuild.
- Migrated token-search primaries with `merge: never`.
- Migrated custom-token primaries with `merge: never`, including custom artwork
  metadata and definition-resolved artwork for replacement results.
- Migrated token-card rules primaries while preserving direct addition to an
  unchanged clean source stack.
- Fixed token-card replacement results so they cannot be added into the original
  token identity.
- Expanded clean-stack detection for token-card additions to include asymmetric
  P/T counters through `TokenMergeCompatibility.isClean()`.
- Added accurate partial-success messages and loading-state cleanup to search
  and custom creation.
- Added `try/finally` disposal for temporary token databases used by token-card,
  Hare Apparent, Krenko companion, and Academy Manufactor flows.
- Kept Scute and Krenko primary provider methods specialized; importing the
  service into its owning provider would invert the dependency direction, while
  their rule companions already use the executor.

## Remaining Acceptance Unknowns

- Fault-injected later-result persistence failure has not yet validated the
  typed partial-success message and exact committed-count reporting.
- Objective parity remains to be exercised for countered token-card sources,
  primary replacement rules, artwork-mismatched merge destinations, both Krenko
  utilities, Scute Swarm, Hare Apparent, Academy Manufactor, Rhys, Brudiclad,
  split, deck restore, and undo.
- Remote artwork completion after deleting a token or changing its artwork still
  needs an acceptance reproduction.
- Physical Android smoke testing remains required; the Android debug build
  succeeds, but simulator validation was performed on iOS.
- Animation feel, interaction feel, and subjective visual review are explicitly
  deferred to feature review and are not implementation-completion signals.

Future optimization and architecture work has moved to
`../todo_features/Optimizations.md` and is not part of 1.11 acceptance.

## Current References

- `lib/services/token_creation_service.dart`
- `lib/services/token_result_artwork_resolver.dart`
- `lib/services/token_merge_compatibility.dart`
- `lib/services/token_copy_semantics.dart`
- `lib/services/rhys_copy_planner.dart`
- `lib/services/brudiclad_transform_planner.dart`
- `lib/services/board_undo_snapshot.dart`
- `lib/providers/token_provider.dart`
- `lib/providers/rules_provider.dart`
- `lib/utils/game_events.dart`
- `lib/screens/token_search_screen.dart`
- `lib/widgets/new_token_sheet.dart`
- `lib/widgets/token_card.dart`
- `lib/widgets/tracker_widget_card.dart`
- `lib/providers/deck_provider.dart`
