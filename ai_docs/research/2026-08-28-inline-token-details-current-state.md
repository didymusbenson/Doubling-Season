# Inline Token Details: Current-State Code Map

**Date:** 2026-08-28

## Board composition

- `lib/screens/content_screen.dart:144-205` combines tokens, trackers, and
  toggles into one order-sorted `ReorderableListView`.
- `content_screen.dart:229-303` gives each row a stable key, animated container,
  gradient border, and end-to-start `Dismissible` deletion wrapper.
- `content_screen.dart:513-593` persists fractional board order and compacts
  small gaps.
- No board state currently records an expanded item.

## Compact token card

- `lib/widgets/token_card.dart:157-175` makes the whole card tappable and pushes
  `ExpandedTokenScreen` as a new route.
- `token_card.dart:175-215` uses `LayoutBuilder`, layered background/artwork, and
  an intrinsically sized `Column`; there is no fixed token-card height.
- Existing element order is name/status (`:216-315`), counter pills (`:318-356`),
  type/abilities/P-T (`:358-377`), and actions (`:380-384`).
- `token_card.dart:398-440` calculates one compact action row responsively.
- Remove/add/ready/tap/counter/clone/split actions are implemented at `:443-597`.

## Existing detail editing

- `lib/screens/expanded_token_screen.dart:274-304` is a separate `Scaffold`
  route with an app bar and scroll view.
- `expanded_token_screen.dart:30-68` maintains one active editable field,
  controllers, focus nodes, and focus-loss saving.
- Name, P/T, type, and abilities already use tap-to-edit behavior through
  `_buildEditableField` (`:305-373`, `:1238-1342`). Submission or focus loss
  writes through `TokenProvider.updateItem`.
- Total, tapped, and sickness use tap-to-edit numeric rows (`:454-590`,
  `:1344-1467`). Untapped is derived and display-only.
- Colors use direct selection buttons (`:377-450`).
- Counters react to the Hive box and expose increment, decrement, and numeric
  editing (`:600-1222`). Adding a counter pushes `CounterSearchScreen`.
- Artwork uses an 85%-height `ArtworkSelectionSheet` (`:161-258`, `:1470-1557`).
- Split uses `SplitStackSheet` (`:1560-1572`).

## Persistence

- `lib/models/item.dart:8-123` auto-saves several setters, including colors,
  amount, tapped, sickness, type, and counters.
- Name, P/T, and abilities are plain fields and rely on provider saving.
- `lib/providers/token_provider.dart:142-165` saves an item and notifies
  listeners; the board then rebuilds while preserving the stable row key.

## Existing interaction layers

The same board subtree currently participates in:

1. Whole-card single-tap route navigation (`token_card.dart:157-175`).
2. Child action-button taps (`token_card.dart:443-597`).
3. End-to-start swipe deletion (`content_screen.dart:275-303`).
4. Flutter's mobile long-press reorder behavior around the row
   (`content_screen.dart:191-205`).

There is no existing `AnimatedSize`, `AnimatedCrossFade`, `AnimatedSwitcher`,
or inline-expansion component under `lib/`. Current card height is already
intrinsic, so an expanded body can participate in list layout without changing
the persisted board model.

## Reusable sheets and controls

- `lib/widgets/split_stack_sheet.dart` is the established secondary-action
  bottom-sheet pattern and dismisses before Hive mutation.
- Artwork selection is already a bottom sheet.
- The main tools menu is a modal bottom sheet in
  `lib/widgets/floating_action_menu.dart`.
- Counter selection is currently a full-screen route, while existing counter
  values are edited directly on the detail screen.
