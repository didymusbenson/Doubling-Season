# Next Feature Development

## Process for Adding New Utility Types (CRITICAL CHECKLIST)

This checklist documents ALL steps required when adding a new utility type (like Krenko). Missing any step will cause the utility to not work properly.

### 1. Data Model (`lib/models/your_utility.dart`)
- [ ] Create Hive model class extending `HiveObject`
- [ ] Add `@HiveType(typeId: X)` annotation (use next available ID from constants.dart)
- [ ] Add `@HiveField(N)` annotations for all fields
- [ ] Include `part 'your_utility.g.dart';` directive
- [ ] Implement required fields: `utilityId`, `name`, `colorIdentity`, `artworkUrl`, `order`, `createdAt`
- [ ] Add utility-specific fields (e.g., `krenkoPower`, `nontokenGoblins`)

### 2. Constants (`lib/utils/constants.dart`)
- [ ] Add new typeId to `HiveTypeIds` class (NEVER change existing IDs)
- [ ] Add new box name to `DatabaseConstants` class

### 3. Hive Setup (`lib/database/hive_setup.dart`)
- [ ] Import your utility model
- [ ] Register adapter: `Hive.registerAdapter(YourUtilityAdapter());`
- [ ] Open box in `Future.wait()`: `Hive.openBox<YourUtility>('yourUtilityBox')`

### 4. Provider (`lib/providers/your_provider.dart`)
- [ ] Create provider class extending `ChangeNotifier`
- [ ] Implement `init()` method with try-catch and debug logging
- [ ] Add `listenable` getter exposing `ValueListenable<Box<YourUtility>>`
- [ ] Implement CRUD methods: `insertUtility()`, `updateUtility()`, `deleteUtility()`
- [ ] Implement `updateOrder()` for drag-and-drop support
- [ ] Implement `_ensureOrdersAssigned()` for migration

### 5. Main App Init (`lib/main.dart`)
- [ ] Import your provider
- [ ] Add provider field to `_MyAppState`: `late YourProvider yourProvider;`
- [ ] Add `_initYourProvider()` method
- [ ] Add provider init to `Future.wait()` in `_initializeProviders()`
- [ ] Assign result to provider field
- [ ] Add provider to `MultiProvider` providers list

### 6. Widget Card (`lib/widgets/your_utility_card.dart`)
- [ ] Create card widget extending `StatefulWidget`
- [ ] **CRITICAL: Use TokenCard as reference implementation**
- [ ] Use `Selector<SettingsProvider, String>` to watch `artworkDisplayStyle` (utilities only need this setting, NOT `summoningSicknessEnabled`)
- [ ] Implement artwork layers following EXACT pattern from TokenCard:
  - Base card background layer
  - Gradient background layer (conditional)
  - Artwork layer using `_buildArtworkLayer(context, constraints, artworkDisplayStyle)`
  - Content layer with semi-transparent backgrounds (0.85 alpha)
- [ ] Implement `_buildArtworkLayer()` that delegates to `_buildFullViewArtwork()` and `_buildFadeoutArtwork()`
- [ ] In fadeout mode: Use `Positioned(width: cardWidth * 0.50)` for 50% width constraint
- [ ] Wrap `CroppedArtworkWidget` with `ShaderMask` for gradient fade
- [ ] Pass `fillWidth: false` to `CroppedArtworkWidget` for fadeout mode
- [ ] Implement tap handler to open `ExpandedWidgetScreen`
- [ ] Save changes to Hive on user interactions

### 7. Widget Definition (`lib/models/widget_definition.dart`)
- [ ] Add new type to `WidgetType` enum (if needed)
- [ ] Import your utility model
- [ ] Add `toYourUtility()` factory method to create instances

### 8. Widget Database (`lib/database/widget_database.dart`)
- [ ] Add predefined utility definition to `loadWidgets()` list
- [ ] Include Scryfall artwork URLs (at least one ArtworkVariant)

### 9. ContentScreen Integration (`lib/screens/content_screen.dart`)
- [ ] Import utility model and provider
- [ ] Import utility card widget
- [ ] Add to `_BoardItem` comment: include your utility type
- [ ] Add `bool get isYourUtility => item is YourUtility;` helper
- [ ] Get provider in `_buildTokenList()`: `final yourProvider = Provider.of<YourProvider>(...)`
- [ ] Add provider listenable to `Listenable.merge([])`
- [ ] Add utilities to boardItems list in builder
- [ ] Handle utility in `_buildBoardItemCard()` color identity logic
- [ ] Handle utility in `_buildCardContent()` to return your card widget
- [ ] Handle utility in `_deleteItem()` to delete from provider
- [ ] Handle utility in `_handleReorder()` to update order
- [ ] Handle utility in `_compactOrders()` to save new orders

### 10. Widget Selection (`lib/screens/widget_selection_screen.dart`)
- [ ] Import your provider
- [ ] Get provider in `_createWidget()`: `final yourProvider = context.read<YourProvider>();`
- [ ] Add utilities to order calculation: `allOrders.addAll(yourProvider.utilities.map((u) => u.order));`
- [ ] Handle your WidgetType in if/else chain
- [ ] Call `toYourUtility()` factory and `insertUtility()` provider method

### 11. Code Generation
- [ ] Run `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Verify `your_utility.g.dart` file is generated
- [ ] Fix any compilation errors

### 12. Testing Checklist
- [ ] Utility appears in utility selection screen
- [ ] Utility can be created and added to board
- [ ] Utility displays with correct styling and colors
- [ ] **Artwork displays correctly in BOTH fullView and fadeout modes**
- [ ] **Artwork fills container properly without stretching**
- [ ] Utility can be reordered with other board items
- [ ] Utility responds to user interactions correctly
- [ ] Utility state persists across app restarts
- [ ] Utility can be deleted via swipe
- [ ] Expanded view works (tap to open)
- [ ] Artwork selection works

**CRITICAL:** If your utility doesn't appear or work correctly, review each step above. Missing ANY step will break functionality.

## Artwork Implementation

All card types use the `ArtworkDisplayMixin` for consistent artwork display. See `lib/widgets/mixins/artwork_display_mixin.dart` and reference implementations in `TokenCard`, `TrackerWidgetCard`, and `ToggleWidgetCard`.

---

## Action Trackers (Trackers with Action Buttons)

### Overview
Action Trackers extend the standard TrackerWidget with an optional action button. This allows trackers to not only track a value but also perform custom actions based on that value.

**Implementation:** Action trackers use the same base TrackerWidget class with additional fields for action button configuration, following DRY principles.

### Current Action Trackers

#### 1. Krenko, Mob Boss
- **Tracks:** Nontoken goblins you control
- **Action:** "Make Goblins" button creates goblin tokens equal to total goblins controlled (including token goblins) × multiplier
- **Default value:** 1 (Krenko himself)

#### 2. Krenko, Tin Street Kingpin
- **Tracks:** Krenko's power
- **Action:** "Make Goblins" button creates goblin tokens equal to Krenko's power × multiplier
- **Default value:** 1 (Krenko starts as 1/1)

### Data Model Extension

Action trackers use the existing `TrackerWidget` model with optional action fields:
```dart
@HiveField(12) bool hasAction; // True if this tracker has an action button
@HiveField(13) String? actionButtonText; // Text for action button (e.g., "Make Goblins")
@HiveField(14) String? actionType; // Type of action (e.g., "krenko_mob_boss")
```

### Implementation Pattern

1. **Definition** (`widget_database.dart`): Add utility with `hasAction: true` and `actionType` set
2. **Card Rendering** (`tracker_widget_card.dart`): Conditionally renders action button inline with +/- buttons
3. **Action Handler** (`tracker_widget_card.dart`): Switch statement routes to specific action based on `actionType`

### Token Creation Behavior

**Standard Goblin Token:**
- Name: "Goblin", P/T: "1/1", Colors: "R", Type: "Creature — Goblin", Abilities: ""

**Smart Token Merging:** If matching goblin token exists on board, adds to existing amount instead of creating duplicate card.

**Summoning Sickness:** Applied when global setting enabled.

---

## Next Up: Cathar's Crusade

**Status:** Requirements defined - ready for implementation.

### Overview

**Cathar's Crusade** is an action tracker utility that automatically counts creature token ETBs (enters-the-battlefield triggers) and allows the player to resolve all pending triggers at once by adding +1/+1 counters to all creatures.

**Card reference:** "Whenever a creature you control enters, put a +1/+1 counter on each creature you control."

**Key insight:** The app cannot model "simultaneous" ETBs perfectly, so instead we give the player control over batching triggers. Player creates tokens → Cathar's counter auto-increments → player presses action button when ready to resolve → all creatures get counters → counter resets to 0.

### Utility Type

**Action Tracker** - Uses existing `TrackerWidget` model with action button enabled:
- `hasAction: true`
- `actionButtonText: "Add Counters"`
- `actionType: "cathars_crusade"`
- `defaultValue: 0`

### Behavior Specifications

#### 1. Tracking Creature ETBs

**Auto-increment when:**
- Token with P/T is created via `TokenProvider.insertItem()` → increment by `amount`
- Token with P/T is copied via `TokenProvider.copyToken()` → increment by `amount` of new token
- Check: `item.hasPowerToughness` (same check used for summoning sickness logic)

**Manual adjustment:**
- Player can use +/- stepper buttons to adjust counter value
- Allows tracking physical creatures played from hand
- Allows corrections before resolving triggers

**Does NOT increment when:**
- Token is split via `SplitStackSheet` (split = death + creation, not true ETB)
- Token is deleted (death trigger, not ETB)
- Token without P/T is created (not a creature)

**Does NOT decrement when:**
- Token is deleted (ETB trigger already happened, can't undo it)

#### 2. Action Button Behavior

**Button text:** "Add Counters"

**Button displays:** Current pending trigger count (e.g., "Add Counters (3)")

**Confirmation dialog:**
```
"Pressing confirm will add {x} +1/+1 counters to all creatures."

[Confirm] [Cancel]
```

**On confirm:**
1. Iterate through all tokens on board
2. For each token with `hasPowerToughness`:
   - Add `x` +1/+1 counters (where `x` = current tracker value)
   - Use existing `item.plusOneCounters += x` logic
   - Save each item to Hive
3. Reset Cathar's tracker value to 0
4. Save tracker to Hive
5. Close dialog

**Counter stacking:**
- If token already has +2/+2 counters, and Cathar's resolves 3 triggers, token gets +3/+3 more (total +5/+5)
- Uses existing auto-canceling logic with -1/-1 counters

#### 3. Default Starting Value

**Default value: 0**

**Rationale:** Prevents accidental triggers when utility is first added to board. Player hasn't played any creatures yet.

### Event Bus Architecture

**CRITICAL INFRASTRUCTURE:** Cathar's Crusade requires cross-provider communication - `TrackerWidget` needs to listen to `TokenProvider` events. This requires implementing an event bus pattern.

#### Event Bus Design

**Create:** `lib/utils/game_events.dart`

```dart
/// Singleton event bus for game-wide trigger events.
///
/// Allows utilities to listen to token lifecycle events without creating
/// circular dependencies between providers.
///
/// Mirrors Magic's rules engine: actions generate events → permanents with
/// triggered abilities listen for matching events.
class GameEvents {
  static final GameEvents instance = GameEvents._();
  GameEvents._();

  // ===== Creature Entered Battlefield =====

  final _creatureEnteredListeners = <void Function(Item item, int count)>[];

  /// Register a listener for creature ETB events.
  ///
  /// Callback receives:
  /// - [item]: The token that entered (for future filtering by type/color)
  /// - [count]: Number of tokens that entered (item.amount)
  void onCreatureEntered(void Function(Item item, int count) callback) {
    _creatureEnteredListeners.add(callback);
  }

  /// Notify all listeners that creature(s) entered the battlefield.
  ///
  /// Called by TokenProvider when tokens with P/T are created/copied.
  void notifyCreatureEntered(Item item, int count) {
    for (var listener in _creatureEnteredListeners) {
      listener(item, count);
    }
  }

  // ===== Board Wipe Event =====

  final _boardWipedListeners = <void Function()>[];

  /// Register a listener for board wipe events.
  void onBoardWiped(void Function() callback) {
    _boardWipedListeners.add(callback);
  }

  /// Notify all listeners that board was wiped.
  ///
  /// Called by TokenProvider when user triggers board wipe action.
  void notifyBoardWiped() {
    for (var listener in _boardWipedListeners) {
      listener();
    }
  }
}
```

#### Event Bus Integration Points

**1. TokenProvider - Fire Events**

```dart
// In TokenProvider.insertItem()
Future<void> insertItem(Item item) async {
  await box.add(item);

  // Fire ETB event for creatures
  if (item.hasPowerToughness) {
    GameEvents.instance.notifyCreatureEntered(item, item.amount);
  }
}

// In TokenProvider.copyToken()
Future<void> copyToken(Item original) async {
  final newItem = Item(
    // ... copy fields
  );
  await box.add(newItem);

  // Fire ETB event for creatures
  if (newItem.hasPowerToughness) {
    GameEvents.instance.notifyCreatureEntered(newItem, newItem.amount);
  }
}

// In TokenProvider.deleteItem()
Future<void> deleteItem(Item item) async {
  // No events fired (death triggers not implemented yet)
  await item.delete();
}
```

**2. TrackerProvider - Listen to Events**

```dart
// In TrackerProvider.init()
void init() {
  // ... existing init code

  // Register listener for creature ETBs (Cathar's Crusade)
  GameEvents.instance.onCreatureEntered((item, count) {
    _onCreatureEntered(item, count);
  });

  // Register listener for board wipes (Cathar's Crusade reset)
  GameEvents.instance.onBoardWiped(() {
    _onBoardWiped();
  });
}

void _onCreatureEntered(Item item, int count) {
  // Find all Cathar's Crusade utilities on board
  final catharsUtilities = box.values.where((tracker) =>
    tracker.actionType == 'cathars_crusade'
  );

  // Increment each Cathar's counter
  for (var cathar in catharsUtilities) {
    cathar.currentValue += count;
    cathar.save();
  }

  // Notify UI to rebuild
  notifyListeners();
}

void _onBoardWiped() {
  // Find all Cathar's Crusade utilities on board
  final catharsUtilities = box.values.where((tracker) =>
    tracker.actionType == 'cathars_crusade'
  );

  // Reset each Cathar's counter to 0
  for (var cathar in catharsUtilities) {
    cathar.currentValue = 0;
    cathar.save();
  }

  // Notify UI to rebuild
  notifyListeners();
}
```

#### Performance Impact

**Estimated overhead:** < 0.1ms per event (imperceptible to users)

**Reasoning:**
- Event firing = iterating a list of 1-3 callbacks
- Each callback increments a counter and saves to Hive (1-5ms)
- Total overhead 2-3 orders of magnitude faster than UI rendering (16-33ms per frame)

**Scalability:** Event bus can support 10+ listening utilities without noticeable performance impact.

### Widget Database Definition

```dart
// In lib/database/widget_database.dart
WidgetDefinition(
  name: "Cathar's Crusade",
  type: WidgetType.tracker,
  colorIdentity: 'W',  // White enchantment
  artworkVariants: [
    ArtworkVariant(
      artworkUrl: 'https://cards.scryfall.io/art_crop/front/8/a/8a2c9f16-d61f-4e7d-975e-9b7b697f8f6d.jpg?1592710893',
      setCode: 'cm2',
      isFallback: true,
    ),
  ],
  defaultValue: 0,  // Starts at 0 (no creatures entered yet)
  hasAction: true,
  actionButtonText: 'Add Counters',
  actionType: 'cathars_crusade',
),
```

### Implementation in TrackerWidgetCard

**Action handler in `tracker_widget_card.dart`:**

```dart
void _handleAction(BuildContext context, TrackerWidget tracker) {
  final settingsProvider = context.read<SettingsProvider>();
  final tokenProvider = context.read<TokenProvider>();

  switch (tracker.actionType) {
    case 'krenko_mob_boss':
      // ... existing Krenko logic
      break;

    case 'krenko_tin_street_kingpin':
      // ... existing Krenko Kingpin logic
      break;

    case 'cathars_crusade':
      _handleCatharsCrusade(context, tracker, tokenProvider);
      break;

    default:
      break;
  }
}

void _handleCatharsCrusade(
  BuildContext context,
  TrackerWidget tracker,
  TokenProvider tokenProvider,
) {
  final triggerCount = tracker.trackedValue;

  if (triggerCount <= 0) {
    // No triggers to resolve
    return;
  }

  // Show confirmation dialog
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Cathar's Crusade"),
      content: Text(
        'Pressing confirm will add $triggerCount +1/+1 counter${triggerCount == 1 ? '' : 's'} '
        'to all creatures.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _resolveCatharsTriggers(tracker, tokenProvider, triggerCount);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

void _resolveCatharsTriggers(
  TrackerWidget tracker,
  TokenProvider tokenProvider,
  int triggerCount,
) {
  // Get all tokens on board
  final allTokens = tokenProvider.box.values.toList();

  // Add counters to all creatures (tokens with P/T)
  for (var token in allTokens) {
    if (token.hasPowerToughness) {
      token.plusOneCounters += triggerCount;
      token.save();
    }
  }

  // Reset Cathar's counter to 0
  tracker.trackedValue = 0;
  tracker.save();
}
```

### Testing Requirements

#### Event Bus Testing
- [ ] Creature ETB event fires when token with P/T is created
- [ ] Creature ETB event fires when token with P/T is copied
- [ ] Creature ETB event does NOT fire when token without P/T is created
- [ ] Creature ETB event does NOT fire when stack is split
- [ ] Board wipe event fires when user triggers board wipe
- [ ] Multiple utilities can listen to same event
- [ ] No performance degradation with multiple listeners

#### Cathar's Crusade Testing
- [ ] Utility appears in widget selection screen
- [ ] Utility can be added to board
- [ ] Default value is 0
- [ ] Counter auto-increments when creature token created
- [ ] Counter increments by correct amount (matches token amount)
- [ ] Counter does NOT increment for non-creature tokens
- [ ] Counter does NOT increment when stack is split
- [ ] Counter does NOT decrement when token is deleted
- [ ] Manual +/- buttons work correctly
- [ ] Action button shows current count: "Add Counters (3)"
- [ ] Confirmation dialog displays correct message
- [ ] Confirm adds counters to all creatures on board
- [ ] Counters stack with existing counters correctly
- [ ] Cathar's counter resets to 0 after resolving
- [ ] Board wipe resets Cathar's counter to 0
- [ ] Multiple Cathar's utilities can coexist (both track independently)
- [ ] Artwork displays correctly in both view modes
- [ ] State persists across app restarts
- [ ] Utility can be deleted
- [ ] Utility can be reordered

#### Edge Cases
- [ ] Empty board → Cathar's resolves with no creatures → no crash
- [ ] Create 2 squirrels simultaneously → both get same counter boost
- [ ] Physical creature added manually → stepper works
- [ ] Cathar's at 0 → action button does nothing (or shows "No triggers")
- [ ] Very large counter values (100+) → no overflow or performance issues

### Future Extensions

The Event Bus architecture can be extended for future utilities. Add these event types when needed:

**Death triggers** (not implemented yet):
- "Whenever a creature dies, do X"
- Example utilities: Blood Artist counter, Zulaport Cutthroat tracker
- Events: `onCreatureDied()`, `notifyCreatureDied()`

**Tap triggers** (not implemented yet):
- "Whenever a creature taps, do X"
- Example utilities: Inspired mechanic tracker
- Events: `onCreatureTapped()`, `notifyCreatureTapped()`

**Counter triggers** (not implemented yet):
- "Whenever a +1/+1 counter is placed, do X"
- Example utilities: Proliferate tracker, Hardened Scales multiplier
- Events: `onCounterAdded()`, `notifyCounterAdded()`

**Token doubling** (not implemented yet):
- Intercept creation events to apply Doubling Season, Parallel Lives, etc.
- Modify token count before insertion
- Requires event filtering/interception pattern

---

## Behavioral Specifications - Resolved

All design decisions have been finalized. Implementation can proceed autonomously.

### 1. Event Bus Lifecycle Management
**Decision:** Listeners register once in `TrackerProvider.init()` and remain registered for the lifetime of the provider. Filter by `actionType` at runtime.

**Rationale:**
- Negligible performance overhead (~1-5 microseconds per event when no utilities present)
- Simpler implementation with no lifecycle management complexity
- Less error-prone than dynamic registration/unregistration
- Event bus stays "always listening" like Magic's rules engine

**Implementation:** The `_onCreatureEntered()` callback filters `box.values.where((tracker) => tracker.actionType == 'cathars_crusade')`. If no Cathar's utilities exist, the loop doesn't execute.

---

### 2. Board Wipe Behavior
**Decision:** When user triggers board wipe, reset all Cathar's Crusade counters to 0 (fresh board state).

**Rationale:** Board wipe clears all creatures, so pending Cathar's triggers should reset.

**Implementation:**
```dart
// In TokenProvider.boardWipeDelete()
Future<void> boardWipeDelete() async {
  // Fire board wipe event to reset Cathar's counters
  GameEvents.instance.notifyBoardWiped();

  // Delete all items
  await box.clear();
}

// In TrackerProvider.init() - Register board wipe listener
GameEvents.instance.onBoardWiped(() {
  final catharsUtilities = box.values.where((tracker) =>
    tracker.actionType == 'cathars_crusade'
  );

  // Reset all Cathar's counters to 0
  for (var cathar in catharsUtilities) {
    cathar.currentValue = 0;
    cathar.save();
  }

  notifyListeners();
});
```

**Note:** Death events are planned for future utilities (Blood Artist, etc.) but not implemented in this iteration since Cathar's doesn't use them.

---

### 3. Deck Save/Load Behavior
**Decision:** Follow existing template pattern:
- **On Save:** `TrackerWidgetTemplate.fromWidget()` saves `defaultValue: 0` (not current value)
- **On Load:** `TrackerWidgetTemplate.toWidget()` sets `currentValue: defaultValue` (always starts at 0)

**Rationale:** Deck templates represent starting board state, not mid-game state. Matches existing behavior for TrackerWidget (see `tracker_widget_template.dart:100`) and ToggleWidget (resets to `isActive: false`).

**Implementation:** No special handling needed - existing template system already does this.

---

### 4. Multiple Cathar's Utilities Interaction
**Decision:** Independent tracking and resolution.

**Behavior:**
- Each Cathar's utility increments its own counter on creature ETB
- Each "Add Counters" button resolves based only on that utility's counter value
- Example: 2 Cathar's both at 3 triggers → User can press button on first utility to add +3/+3 to all creatures, leaving second utility at 3 triggers

**Rationale:** Gives player full control over trigger batching. Users unlikely to have multiple Cathar's, but allowing it provides flexibility.

---

### 5. NewTokenSheet Creation Path
**Decision:** Yes, fire ETB events.

**Rationale:** Custom token creation calls `TokenProvider.insertItem()` which should fire events like any other token creation.

---

### 6. Scute Swarm Doubling Button
**Decision:** Yes, fire ETB events for the amount added.

**Implementation:** The Scute Swarm button calls `TokenProvider.addTokens(item, amount, summoningSick)` which increases the stack size. Fire events from `addTokens()`:

```dart
// In TokenProvider.addTokens() (lib/providers/token_provider.dart:152)
Future<void> addTokens(Item item, int amount, bool summoningSicknessEnabled) async {
  try {
    final oldAmount = item.amount;
    item.amount += amount;

    // Apply summoning sickness if enabled AND token is a creature without Haste
    if (summoningSicknessEnabled && item.hasPowerToughness && !item.hasHaste) {
      item.summoningSick += amount;
    }

    await item.save();

    // Fire ETB event for added creatures
    if (item.hasPowerToughness) {
      GameEvents.instance.notifyCreatureEntered(item, amount);
    }

    _errorMessage = null;
    notifyListeners();
    debugPrint('TokenProvider: Added $amount tokens to "${item.name}" (${oldAmount} → ${item.amount})');
  } on HiveError catch (e) {
    // ... error handling
  }
}
```

---

### 7. Stack Splitting
**Decision:** Do NOT fire any events (neither death nor ETB).

**Rationale:** Splitting represents distributing existing tokens across two stacks, not creating new tokens or destroying old ones.

**Implementation:** `SplitStackSheet` does NOT call any GameEvents methods.
