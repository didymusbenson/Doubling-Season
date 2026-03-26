# Dungeon Support

**Status:** Todo
**Priority:** User-requested feature (multiple requests noted in FeedbackIdeas.md)

## Overview

Add dungeon cards as a new board item type. Dungeons are game state cards from Adventures in the Forgotten Realms (and Baldur's Gate) that players "venture into" by progressing through a series of rooms. Each room triggers an effect. Dungeons have branching paths, so the detail view needs to show the room graph and let the player advance through it.

There are **4 dungeons** in Magic:
1. **Dungeon of the Mad Mage** (AFR) — 7 rooms, linear
2. **Lost Mine of Phandelver** (AFR) — 7 rooms, branching (3 paths after room 1)
3. **Tomb of Annihilation** (AFR) — 7 rooms, branching
4. **Undercity** (CLB) — 7 rooms, branching (Initiative mechanic)

## Design Decisions

### Decision 1: New Hive model vs. reuse Item model

**Recommendation: New Hive model (`Dungeon`, typeId 8)**

Dungeons are fundamentally different from tokens:
- No power/toughness, no tapped/untapped state, no summoning sickness, no stack quantity
- Need to track current room position in a branching graph
- Need room definitions (name, effect text) embedded in the model
- Only 4 possible dungeons exist (finite, well-defined set)

Reusing `Item` would require nullable fields and branching logic throughout the token pipeline. A dedicated model is cleaner and follows the precedent set by TrackerWidget/ToggleWidget.

### Decision 2: Room graph data — hardcoded vs. dynamic

**Recommendation: Hardcode room definitions in Dart**

There are only 4 dungeons and they will never change (they're printed cards). Hardcoding room layouts as a Dart data structure avoids:
- Complex graph serialization in Hive
- Keeping room definitions in the JSON pipeline
- Versioning issues if room text changes

The Hive model only needs to persist: which dungeon, and which room the player is currently in (by index/id).

### Decision 3: Board card appearance

**Recommendation: Follow the utility card pattern (like ToggleWidgetCard)**

The board card should show:
- Dungeon name
- Current room name + effect text
- A "Venture" / "Next Room" indicator
- Artwork if available (same `ArtworkDisplayMixin` pattern)
- Colorless border (dungeons have no color identity)
- Tap to open expanded dungeon view

### Decision 4: Dungeon detail view — room navigation

**Recommendation: Visual room list with current position highlighted**

The expanded dungeon view (`ExpandedDungeonScreen`) should show:
- All rooms laid out vertically (like a flowchart/checklist)
- Branching paths shown as indented options where applicable
- Current room highlighted with a distinct style
- Tappable "advance" buttons on the next available room(s)
- Completed rooms shown as checked/dimmed
- "Completed" state when the final room is reached
- Reset button to start the dungeon over (or delete and re-venture)

### Decision 5: How users add dungeons to the board

**Options to decide:**
- **A) Add to the existing "Add Utility" flow** — new category in WidgetSelectionScreen
- **B) Dedicated "Venture into Dungeon" button** — new FAB menu option in ContentScreen
- **C) Add to token search with Dungeon category filter** — the `Category.dungeon` enum already exists

Option A or B are most natural. Dungeons aren't really tokens or utilities, but the utility flow is the closest analogue (small finite set, no quantity picker needed).

### Decision 6: Deck save/load integration

**Recommendation: Include in deck system**

If a player has a dungeon in progress, saving a deck should snapshot it (including current room). Loading should restore it. This follows the TrackerWidget/ToggleWidget template pattern — requires a `DungeonTemplate` model.

However, this could be deferred to a follow-up since dungeons are relatively rare in gameplay.

## Implementation Scope

### Layer 1: Data Model
- [ ] Create `lib/models/dungeon.dart` — Hive model (typeId 8)
  - Fields: `widgetId`, `name`, `currentRoomIndex`, `order`, `createdAt`, `artworkUrl`, `artworkSet`, `artworkOptions`, `colorIdentity`
  - `completed` computed property (currentRoomIndex == final room)
- [ ] Create `lib/models/dungeon_rooms.dart` — hardcoded room graph definitions
  - Data structure for rooms: `DungeonDefinition` with `List<DungeonRoom>` where each room has `name`, `effectText`, `nextRoomIndices` (for branching)
  - 4 dungeon definitions with all rooms and branching paths
- [ ] Add `HiveTypeIds.dungeon = 8` to `lib/utils/constants.dart`
- [ ] Run `build_runner build --delete-conflicting-outputs`

### Layer 2: Persistence
- [ ] Register `DungeonAdapter()` in `lib/database/hive_setup.dart`
- [ ] Open `'dungeons'` box in both web and native paths
- [ ] Add `'dungeons'` to backup box names list

### Layer 3: Provider
- [ ] Create `lib/providers/dungeon_provider.dart`
  - Standard pattern: `ChangeNotifier`, `Box<Dungeon>`, `listenable`, `init()`, `insert()`, `update()`, `delete()`, `deleteAll()`

### Layer 4: Main App Wiring
- [ ] Register `DungeonProvider` in `lib/main.dart`
  - Import, state field, init in `Future.wait`, `ChangeNotifierProvider.value`, dispose

### Layer 5: Board Card
- [ ] Create `lib/widgets/dungeon_card.dart`
  - Follow `ToggleWidgetCard` pattern
  - Show: dungeon name, current room name, current room effect, progress indicator
  - `ArtworkDisplayMixin` for artwork support
  - `GestureDetector` → `Navigator.push` to `ExpandedDungeonScreen`

### Layer 6: Board Integration
- [ ] Update `lib/screens/content_screen.dart`
  - Add `isDungeon` to `_BoardItem`
  - Merge dungeons into unified board list from `DungeonProvider`
  - Add `DungeonProvider` to `Listenable.merge`
  - Add dungeon branches in: `_buildBoardItemCard`, `_buildCardContent`, `_deleteItem`, `_handleReorder`, `_compactOrders`

### Layer 7: Expanded Dungeon View (the unique piece)
- [ ] Create `lib/screens/expanded_dungeon_screen.dart`
  - AppBar: "Dungeon Details" + delete action
  - Room graph visualization — vertical list of rooms with branching
  - Current room highlighting
  - Tap to advance to next room (shows available next rooms if branching)
  - Completed rooms dimmed/checked
  - "Reset Dungeon" option
  - Artwork section (same pattern as ExpandedWidgetScreen)

### Layer 8: Creation Flow
- [ ] Add dungeon creation entry point (FAB menu option or utility selection addition)
  - Only 4 options, so a simple selection dialog/sheet may suffice
  - No quantity picker needed (dungeons are singleton board items)

### Layer 9: Data Pipeline (minimal)
- [ ] Either remove `'Dungeon'` from `EXCLUDED_TYPES` in `process_tokens_mtgjson.py` and regenerate, OR add the 4 dungeons to `custom_tokens.json`
  - This is only needed if we want Scryfall artwork IDs from the pipeline
  - Room definitions are hardcoded in Dart regardless
- [ ] Add `Category.dungeon` to `allowedCategories` in `token_search_screen.dart` if using the search flow

### Deferred / Follow-up
- [ ] Deck save/load integration (`DungeonTemplate` model, typeId 9)
- [ ] Deck provider changes for dungeon snapshot/restore
- [ ] Initiative tracking (auto-venture mechanic from Baldur's Gate)

## Room Data Reference

Need to research and transcribe the exact room layouts for all 4 dungeons. Each dungeon has ~7 rooms with branching paths. Example structure:

```
Lost Mine of Phandelver:
  Room 0: Cave Entrance — "Each player scries 1"
    → Room 1 OR Room 2 OR Room 3
  Room 1: Goblin Lair — "Create a 1/1 red Goblin creature token"
    → Room 4
  Room 2: Mine Tunnels — "Create a Treasure token"
    → Room 4
  Room 3: Dark Pool — "Each opponent loses 1 life"
    → Room 5
  Room 4: Fungi Cavern — "Target creature gets -4/-0 until your next turn"
    → Room 6
  Room 5: Lost Well — "Scry 2"
    → Room 6
  Room 6: Temple of Dumathoin — "Draw a card"
    → COMPLETED
```

## Files Affected (Summary)

**New files (6):**
- `lib/models/dungeon.dart`
- `lib/models/dungeon_rooms.dart`
- `lib/providers/dungeon_provider.dart`
- `lib/widgets/dungeon_card.dart`
- `lib/screens/expanded_dungeon_screen.dart`
- `lib/models/dungeon.g.dart` (generated)

**Modified files (4-5):**
- `lib/utils/constants.dart` — HiveTypeIds
- `lib/database/hive_setup.dart` — adapter registration, box opening, backup
- `lib/main.dart` — provider registration
- `lib/screens/content_screen.dart` — board integration (~8 branch points)
- `docs/housekeeping/process_tokens_mtgjson.py` or `custom_tokens.json` — data pipeline (if artwork needed)

## Open Questions

1. **Creation entry point** — FAB menu option, utility selection screen addition, or token search with dungeon filter? (Decision 5 above)
2. **Room visualization style** — Simple vertical list with indentation for branches, or something more graphical (connecting lines, flowchart)?
3. **Multiple dungeon instances** — Can a player have the same dungeon on the board twice (for multiplayer tracking), or enforce one-per-dungeon-name?
4. **Completed dungeon behavior** — Keep on board as completed? Auto-remove? Show "completed" badge and allow reset?
