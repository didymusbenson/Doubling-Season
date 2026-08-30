# Token Creation Pipeline Research

**Date:** 2026-08-29
**Scope:** Current token creation, persistence, artwork, merge, ordering, and
event behavior in Tripling Season.

## Summary

The codebase already has a shared rules-result creation layer. Rules evaluation,
artwork resolution, clean-stack compatibility, copy semantics, immutable Rhys
planning, Brudiclad transformation planning, and unified-board rollback are
separate reusable components. The remaining caller-owned work is concentrated
in primary-result creation, specialized Scute/Krenko/copy flows, persistence
failure handling, and board-order calculation.

## Shared Components

- `lib/providers/rules_provider.dart:552` evaluates creation rules into ordered
  `TokenCreationResult` values. Display aggregation is separate from creation.
- `lib/services/token_creation_service.dart:29` creates companion results;
  `:133` creates peer result sets. Both resolve artwork, merge compatible clean
  stacks, insert new stacks, apply sickness, emit ETB, and cache artwork.
- `lib/services/token_result_artwork_resolver.dart:18` maps a result to its
  database definition, saved artwork preference, set, and artwork options.
- `lib/services/token_merge_compatibility.dart:7` defines clean stacks and
  exact identity/artwork compatibility.
- `lib/services/token_copy_semantics.dart:7` defines eligible token objects and
  intrinsic copied P/T behavior.
- `lib/services/rhys_copy_planner.dart:101` snapshots and resolves Rhys results
  before preview and execution.
- `lib/services/brudiclad_transform_planner.dart:72` plans transformation and
  clean-stack merging.
- `lib/services/board_undo_snapshot.dart:19` captures and restores tokens,
  trackers, and toggles without replaying events.
- `lib/utils/game_events.dart:3` provides the synchronous creature-ETB and
  board-wipe event bus consumed by `TrackerProvider`.

## Creation Entry Points

- Token search creates the primary stack locally, then calls the shared service
  for companions (`lib/screens/token_search_screen.dart:970`).
- The custom-token sheet follows the same primary/companion split and also owns
  staged custom-file and library persistence (`lib/widgets/new_token_sheet.dart:377`).
- Token-card rules additions locally decide whether the primary adds, merges, or
  creates, then delegate companions (`lib/widgets/token_card.dart:1377`).
- Scute Swarm delegates its primary to a specialized provider method and its
  companions to the shared service (`lib/widgets/token_card.dart:1273`).
- Hare Apparent and Academy Manufactor pass every peer result to the shared
  service (`lib/widgets/tracker_widget_card.dart:1474`, `:1876`).
- Krenko uses specialized primary creation and shared companions
  (`lib/widgets/tracker_widget_card.dart:1600`, `:1715`).
- Rhys executes an immutable, previewed plan through
  `TokenProvider.performRhysPopulate()` (`lib/providers/token_provider.dart:890`).
- Brudiclad creates Step 1 through the shared service and transforms through a
  planned provider mutation with snapshot rollback
  (`lib/widgets/tracker_widget_card.dart:1024`).
- Deck restore converts templates to amount-zero items and uses event-free
  explicit-order insertion (`lib/providers/deck_provider.dart:570`).

## Persistence and Events

- `TokenProvider.insertItem()` adds to Hive, then synchronously publishes
  creature ETB, then notifies listeners (`lib/providers/token_provider.dart:92`).
- `insertItemWithExplicitOrder()` adds and notifies without ETB (`:135`). It is
  used for restore and split-style operations.
- New rule-created stacks are inserted with sickness zero; sickness is assigned
  afterward because its setter saves and requires a Hive key.
- Merge paths update amount/sickness, await a save, then manually publish ETB.
- The shared result service and Rhys commit sequentially without a transaction.
  Earlier results remain if a later result fails.
- Brudiclad captures the complete unified board and restores it on execution
  failure. Restore deliberately publishes no events.
- `TokenProvider.items` copies and sorts the token box on every access
  (`lib/providers/token_provider.dart:86`).

## Ordering

- Search, custom creation, utilities, and deck append calculate order against
  tokens, trackers, and toggles at the UI/provider boundary.
- `insertItem()` has a token-only fallback when order equals `0.0`.
- Zero is both a valid position and the unassigned sentinel. Rhys explicitly
  avoids producing an exact zero (`lib/providers/token_provider.dart:1073`).
- Deck restore sorts all template types together and assigns contiguous orders.

## Artwork

- Definition-based rules results use `TokenResultArtworkResolver`.
- Unchanged copy paths preserve source artwork; changed identities resolve the
  result definition's artwork.
- Artwork caching is asynchronous and not part of the creation transaction.
- Download failure preserves selection metadata.
- Callback identity varies by path: shared/search use URL lookup, Krenko retains
  the created object, and Rhys verifies `item.isInBox`.

## Current Behavioral Boundaries

- Search/custom primaries always create a new stack.
- Token-card additions may add to the selected stack or merge elsewhere.
- Clean merge compatibility includes exact artwork URL and excludes all built-in
  and custom counters; tapped and sickness state do not prevent merging.
- Copy always creates a separate untapped, counter-free stack.
- Split, deck restore, undo, and Brudiclad transformation are event-free.
- Gameplay insertion and compatible-stack additions emit creature ETB.
