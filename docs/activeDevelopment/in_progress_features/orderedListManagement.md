# Ordered Board Architecture

**Status:** Definition complete — implementation approved

**Last updated:** 2026-08-30

## Purpose

Centralize the ordering contract for the unified board without changing user
data or silently choosing new placement behavior. This record describes the
current implementation and the decisions that must be made before architecture
is selected.

## Current Board Model

The rendered board is already a unified, freely reorderable sequence of three
persisted item types:

- `Item` in the `items` Hive box;
- `TrackerWidget` in `trackerWidgets`; and
- `ToggleWidget` in `toggleWidgets`.

Each model owns a `double order` field. `ContentScreen` wraps all three in a
private `_BoardItem`, sorts them together, and dispatches rendering, deletion,
and order persistence by runtime type. Deck templates repeat the same three-way
merge to preserve a deck's unified sequence.

There is no current requirement to add another persisted board-item type. The
old claim that four to seven new types were imminent is no longer a valid basis
for a schema migration.

## Current Ordering Behaviors

Ordering is not one operation. Existing flows intentionally use several
placement policies:

| Operation | Current placement |
|---|---|
| New token from search/custom creation | after the maximum unified-board order |
| New utility | after the maximum unified-board order |
| Add deck to board | append the deck's internal unified sequence |
| Clear and load deck | rebuild from order `0.0` in template sequence |
| Manual reorder | fractional value between unified neighbors |
| Split/copy | adjacent to the source, currently with token-only gaps in some paths |
| Rhys copies | between each source and its snapshotted next unified neighbor |
| Token-card replacement/new stack | fractional position near the source |
| Utility-created tokens | generally append to unified-board maximum |
| Brudiclad Step 1 | append; later transformation preserves existing orders |

These differences are observable behavior, not merely duplicated arithmetic.
A central service must express named policies rather than replacing every call
with one generic `nextOrder()`.

## Confirmed Technical Problems

### Repeated unified maximum calculations

Token search, custom-token creation, utility selection, new tracker/toggle
sheets, deck append, and several utility actions each rebuild the same three-
provider order list and calculate `floor(max) + 1`.

### Provider fallbacks are not unified

`TokenProvider.insertItem`, `TrackerProvider.insertTracker`, and
`ToggleProvider.insertToggle` each calculate fallback order from only their own
box. Callers usually avoid this by supplying a unified order, but a missed call
site can place an item incorrectly.

### `0.0` has two meanings

Order `0.0` is both a valid first position and a sentinel meaning "assign an
order." This complicates empty-board insertion, explicit deck loading, Rhys
placement, and startup migrations.

### Startup migrations are type-local

Each provider independently treats an order of zero as evidence that its box
needs migration. That cannot reconstruct a historic cross-type sequence and
can rewrite legitimate first positions.

### Neighbor insertion is fragmented

Manual reorder, copy, split, token-card rule creation, and Rhys each calculate
fractional positions. Some inspect the unified board; older paths inspect only
tokens. Dense fractions are compacted only from `ContentScreen` after reorder.

### Board dispatch remains type-specific

`ContentScreen` and deck screens contain runtime-type branches for rendering,
deletion, reorder persistence, and template conversion. This is maintenance
friction, but it is separate from order calculation and does not by itself
justify moving all persisted data into a new Hive hierarchy.

## Constraints

- Never change existing Hive type IDs or box names.
- Do not introduce a destructive data migration merely to remove runtime-type
  branches.
- Preserve exact interleaving of tokens, trackers, and toggles.
- Preserve source-adjacent semantics where the feature requires them.
- Deck save/load, duplicate, export, and import must preserve unified order.
- Undo/restore and transformations must not emit creation or board-wipe events.
- Ordering APIs must work outside widget code; requiring `BuildContext` would
  keep domain behavior coupled to UI.
- A future board-item type should have an explicit integration contract and
  compile-time-visible touchpoint list.

## Selected Architecture

Direction A is selected: a typed order coordinator over the existing persisted
models and Hive boxes. No schema migration or unified persisted parent is
needed. A small shared runtime representation may be introduced where it
removes repeated dispatch, but it will not alter persistence.

### Direction A — Typed order coordinator over existing boxes

Keep all current models and Hive boxes. Introduce a board-order service that
accepts typed order snapshots and exposes named operations such as:

- append to unified board;
- insert between two unified neighbors;
- insert immediately after a source;
- allocate a contiguous range for multi-result creation/deck append; and
- normalize a complete unified sequence.

This has no data migration and directly addresses duplicated calculations. It
does not eliminate type-specific rendering or persistence dispatch.

### Direction B — Shared non-persisted board entry abstraction

Create a sealed runtime wrapper/interface for stable identity, order reads, and
order writes while retaining the existing persisted models and boxes. Use it
in `ContentScreen`, deck orchestration, planners, and the order coordinator.

This can provide more compile-time coverage without a Hive migration, but model
adapters or wrapper construction remain necessary for each type.

### Direction C — Unified persisted parent hierarchy

Move all board items into a new persisted hierarchy/provider. This is the old
document's recommendation, but it carries the highest migration, rollback,
deck-schema, and data-loss risk. It should be selected only if concrete future
requirements cannot be met by A or B.

The previous recommendation to choose this direction based on several planned
utility model types is withdrawn.

## Confirmed Placement Contract

| Operation | Required placement |
|---|---|
| New token from search or custom creation | Absolute bottom |
| New utility | Absolute bottom |
| Utility-created tokens | Absolute bottom |
| Copy or Split | Immediately after the source |
| Token-card rule replacement/new stack | Immediately after the source |
| Scute and Rhys results | Immediately after their source |
| Multiple new result stacks from one action | Remain together in result order |
| A result that merges into an existing stack | Existing stack remains in place |
| Add deck to existing board | Append as one contiguous block |
| Manual token/utility interleaving | Permanently supported |

“Remain together” applies only to newly inserted stacks. An existing compatible
merge target is never moved merely to make the visual result group contiguous.
Utility-created tokens intentionally append rather than appearing next to the
utility that triggered them.

## Implementation Work

1. Lock placement semantics as named policies.
2. Inventory every creation, copy, split, utility, deck, reorder, and restore
   caller against those policies.
3. Select the least risky architecture that enforces them.
4. Remove the `0.0` sentinel or isolate it behind an explicit insertion API.
5. Centralize range allocation and normalization.
6. Validate upgrade behavior with existing interleaved boards and decks.

## Acceptance Requirements

- Existing interleaved boards open in the same order after upgrade.
- Existing decks preserve exact token/tracker/toggle order through every deck
  operation and JSON round trip.
- New items follow the selected placement policy consistently from every entry
  point.
- Adjacent copy/split/rules operations never jump across a utility unexpectedly.
- Multi-result creation produces deterministic ordering whether results merge
  or create new stacks.
- Repeated fractional insertions cannot create unstable or equal order values.
- Empty-board first insertion has an explicit order and no sentinel ambiguity.
- Manual reorder persists correctly across relaunch.
- Undo, failure rollback, and transforms restore exact order silently.
- No Hive type IDs, box names, or existing records are lost.

## Relevant Code

- `lib/screens/content_screen.dart`
- `lib/providers/token_provider.dart`
- `lib/providers/tracker_provider.dart`
- `lib/providers/toggle_provider.dart`
- `lib/providers/deck_provider.dart`
- `lib/services/token_creation_service.dart`
- `lib/services/rhys_copy_planner.dart`
- `lib/services/board_undo_snapshot.dart`
