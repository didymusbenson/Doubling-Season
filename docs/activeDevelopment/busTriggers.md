# Event Bus Triggers - Future Implementation

**Status:** Planned but not yet implemented

This document preserves the design for additional Game Events that will enable future utilities. These triggers follow the same event bus pattern established for Cathar's Crusade.

## Overview

The Event Bus (`lib/utils/game_events.dart`) currently implements:
- ✅ Creature ETB events (for Cathar's Crusade)
- ✅ Board wipe events (for Cathar's Crusade reset)

This document specifies additional triggers to implement when needed:
- ⏳ Death triggers (for Blood Artist, Zulaport Cutthroat utilities)
- ⏳ Tap/untap triggers (for Inspired mechanic tracking)
- ⏳ Counter triggers (for Proliferate, Hardened Scales tracking)
- ⏳ Token doubling interceptors (for Doubling Season, Parallel Lives effects)

---

## Death Triggers

**Use case:** Track creature deaths for utilities like Blood Artist counter, Zulaport Cutthroat tracker, or Grave Pact effects.

### Event Bus Extension

Add to `lib/utils/game_events.dart`:

```dart
class GameEvents {
  // ... existing ETB and board wipe events ...

  // ===== Creature Death Triggers =====

  final _creatureDiedListeners = <void Function(Item item, int count)>[];

  /// Register a listener for creature death events.
  ///
  /// Callback receives:
  /// - [item]: The token that died (for filtering by type/color)
  /// - [count]: Number of tokens that died (item.amount)
  void onCreatureDied(void Function(Item item, int count) callback) {
    _creatureDiedListeners.add(callback);
  }

  /// Notify all listeners that creature(s) died.
  ///
  /// Called by TokenProvider when tokens with P/T are deleted.
  void notifyCreatureDied(Item item, int count) {
    for (var listener in _creatureDiedListeners) {
      listener(item, count);
    }
  }
}
```

### Integration Points

**1. TokenProvider.deleteItem()**

```dart
// In lib/providers/token_provider.dart
Future<void> deleteItem(Item item) async {
  try {
    // Fire death event BEFORE deleting (for utilities that track deaths)
    if (item.hasPowerToughness) {
      GameEvents.instance.notifyCreatureDied(item, item.amount);
    }

    await item.delete();
    _errorMessage = null;
    notifyListeners();
    debugPrint('TokenProvider: Deleted item "${item.name}"');
  } on HiveError catch (e) {
    // ... error handling
  }
}
```

**2. TokenProvider.boardWipeDelete()**

```dart
// In lib/providers/token_provider.dart
Future<void> boardWipeDelete() async {
  final items = box.values.toList();

  // Fire death events BEFORE deleting (for utilities that track deaths)
  for (var item in items) {
    if (item.hasPowerToughness) {
      GameEvents.instance.notifyCreatureDied(item, item.amount);
    }
  }

  // Fire board wipe event (for utilities that reset on wipe)
  GameEvents.instance.notifyBoardWiped();

  // Delete all items
  await box.clear();
}
```

**3. TrackerProvider - Example Death Counter Utility**

```dart
// In TrackerProvider.init()
void init() {
  // ... existing listeners ...

  // Register listener for creature deaths (e.g., Blood Artist counter)
  GameEvents.instance.onCreatureDied((item, count) {
    _onCreatureDied(item, count);
  });
}

void _onCreatureDied(Item item, int count) {
  // Find all death-tracking utilities on board
  final deathCounters = box.values.where((tracker) =>
    tracker.actionType == 'blood_artist' ||
    tracker.actionType == 'zulaport_cutthroat'
  );

  // Increment each death counter
  for (var counter in deathCounters) {
    counter.currentValue += count;
    counter.save();
  }

  // Notify UI to rebuild
  notifyListeners();
}
```

### Example Utilities

**Blood Artist:**
- **Tracks:** Total creature deaths this game
- **Action:** Optional "Deal Damage" button shows total life loss/gain
- **Type:** Action tracker with `actionType: 'blood_artist'`

**Zulaport Cutthroat:**
- **Tracks:** Creature deaths (same as Blood Artist, different flavor)
- **Action:** Optional "Calculate Life Loss" for opponents
- **Type:** Action tracker with `actionType: 'zulaport_cutthroat'`

### Testing Requirements

- [ ] Death event fires when single token deleted
- [ ] Death event fires with correct count for stacks
- [ ] Death event does NOT fire when token without P/T deleted
- [ ] Death event fires during board wipe for all creatures
- [ ] Death counter utility increments correctly
- [ ] Board wipe fires both death events AND board wipe event (order: deaths first, then wipe)

---

## Tap/Untap Triggers

**Use case:** Track tap/untap events for Inspired mechanic utilities or tap-triggered abilities.

### Event Bus Extension

Add to `lib/utils/game_events.dart`:

```dart
class GameEvents {
  // ... existing events ...

  // ===== Tap/Untap Triggers =====

  final _creatureTappedListeners = <void Function(Item item, int count)>[];
  final _creatureUntappedListeners = <void Function(Item item, int count)>[];

  /// Register a listener for creature tap events.
  void onCreatureTapped(void Function(Item item, int count) callback) {
    _creatureTappedListeners.add(callback);
  }

  /// Notify all listeners that creature(s) tapped.
  void notifyCreatureTapped(Item item, int count) {
    for (var listener in _creatureTappedListeners) {
      listener(item, count);
    }
  }

  /// Register a listener for creature untap events.
  void onCreatureUntapped(void Function(Item item, int count) callback) {
    _creatureUntappedListeners.add(callback);
  }

  /// Notify all listeners that creature(s) untapped.
  void notifyCreatureUntapped(Item item, int count) {
    for (var listener in _creatureUntappedListeners) {
      listener(item, count);
    }
  }
}
```

### Integration Points

**1. TokenProvider.tapTokens()**

```dart
// In lib/providers/token_provider.dart
Future<void> tapTokens(Item item, int amount) async {
  try {
    final oldTapped = item.tapped;
    item.tapped += amount;
    await item.save();

    // Fire tap event for creatures
    if (item.hasPowerToughness) {
      GameEvents.instance.notifyCreatureTapped(item, amount);
    }

    _errorMessage = null;
    notifyListeners();
    debugPrint('TokenProvider: Tapped $amount of "${item.name}" (${oldTapped} → ${item.tapped})');
  } on HiveError catch (e) {
    // ... error handling
  }
}
```

**2. TokenProvider.untapTokens()**

```dart
// In lib/providers/token_provider.dart
Future<void> untapTokens(Item item, int amount) async {
  try {
    final oldTapped = item.tapped;
    final toUntap = amount.clamp(0, item.tapped);
    item.tapped -= toUntap;
    await item.save();

    // Fire untap event for creatures
    if (item.hasPowerToughness && toUntap > 0) {
      GameEvents.instance.notifyCreatureUntapped(item, toUntap);
    }

    _errorMessage = null;
    notifyListeners();
    debugPrint('TokenProvider: Untapped $toUntap of "${item.name}" (${oldTapped} → ${item.tapped})');
  } on HiveError catch (e) {
    // ... error handling
  }
}
```

**3. Content Screen - "Untap Everything" Button**

```dart
// In lib/screens/content_screen.dart - untapAll()
Future<void> untapAll() async {
  final tokenProvider = context.read<TokenProvider>();
  final items = tokenProvider.box.values.toList();

  for (var item in items) {
    if (item.tapped > 0) {
      await tokenProvider.untapTokens(item, item.tapped);
    }
  }
}
```

### Example Utilities

**Inspired Counter:**
- **Tracks:** Total "Inspired" triggers this turn (creatures that untapped)
- **Reset:** Manual reset button or "Reset on Untap Everything"
- **Type:** Tracker widget with untap listener

**Pain Seer Tracker:**
- **Tracks:** Number of Inspired triggers (draw cards equal to counter)
- **Action:** "Draw Cards" button (reminder to draw)
- **Type:** Action tracker with `actionType: 'pain_seer'`

### Testing Requirements

- [ ] Tap event fires when tapping tokens
- [ ] Untap event fires when untapping tokens
- [ ] Tap count matches amount tapped
- [ ] Untap count matches amount untapped (clamped to tapped count)
- [ ] "Untap Everything" fires untap events for all tapped creatures
- [ ] Events do NOT fire for tokens without P/T

---

## Counter Triggers

**Use case:** Track +1/+1 counter placement for Proliferate tracking, Hardened Scales effects, or Winding Constrictor utilities.

### Event Bus Extension

Add to `lib/utils/game_events.dart`:

```dart
class GameEvents {
  // ... existing events ...

  // ===== Counter Triggers =====

  final _counterAddedListeners = <void Function(Item item, String counterType, int count)>[];

  /// Register a listener for counter addition events.
  ///
  /// Callback receives:
  /// - [item]: The token that received counters
  /// - [counterType]: Type of counter ("plus_one", "minus_one", "custom_name")
  /// - [count]: Number of counters added
  void onCounterAdded(void Function(Item item, String counterType, int count) callback) {
    _counterAddedListeners.add(callback);
  }

  /// Notify all listeners that counter(s) were added.
  void notifyCounterAdded(Item item, String counterType, int count) {
    for (var listener in _counterAddedListeners) {
      listener(item, counterType, count);
    }
  }
}
```

### Integration Points

**1. Item Setters (lib/models/item.dart)**

```dart
// In Item class
set plusOneCounters(int value) {
  final delta = value - _plusOneCounters;
  if (delta > 0) {
    // Counters added
    GameEvents.instance.notifyCounterAdded(this, 'plus_one', delta);
  }
  _plusOneCounters = value;
  save();
}

set minusOneCounters(int value) {
  final delta = value - _minusOneCounters;
  if (delta > 0) {
    // Counters added
    GameEvents.instance.notifyCounterAdded(this, 'minus_one', delta);
  }
  _minusOneCounters = value;
  save();
}
```

**2. Custom Counter Addition**

```dart
// When adding custom counter (in ExpandedTokenScreen or CounterManagementPillView)
final counter = item.counters.firstWhere(
  (c) => c.name == counterName,
  orElse: () {
    final newCounter = TokenCounter(name: counterName, amount: 0);
    item.counters.add(newCounter);
    return newCounter;
  },
);

final oldAmount = counter.amount;
counter.amount += amountToAdd;
item.save();

// Fire counter event
GameEvents.instance.notifyCounterAdded(item, counterName, amountToAdd);
```

### Example Utilities

**Proliferate Counter:**
- **Tracks:** Total +1/+1 counters placed this turn (for Proliferate triggers)
- **Action:** "Proliferate" button adds one counter of each type to all permanents
- **Type:** Action tracker with `actionType: 'proliferate_tracker'`

**Hardened Scales Tracker:**
- **Tracks:** Number of times +1/+1 counters were placed (to remember Hardened Scales bonus)
- **Display:** Shows "X placement events (remember +1 bonus)"
- **Type:** Passive tracker (no action button)

### Testing Requirements

- [ ] Counter event fires when +1/+1 counter added
- [ ] Counter event fires when -1/-1 counter added
- [ ] Counter event fires when custom counter added
- [ ] Counter event does NOT fire when counter removed (delta negative)
- [ ] "Add Counters" action (Cathar's Crusade) fires counter events for all creatures
- [ ] Event includes correct counter type and count

---

## Token Doubling Interceptors

**Use case:** Intercept token creation events to apply Doubling Season, Parallel Lives, Anointed Procession, or other token-doubling effects.

### Event Bus Extension

**Note:** This requires a different pattern than simple listeners. Doublers need to MODIFY the creation event before it completes.

**Option A: Pre-creation hook** (modify amount before insertion):

```dart
class GameEvents {
  // ... existing events ...

  // ===== Token Doubling Hooks =====

  final _tokenCreationHooks = <int Function(Item item, int originalAmount)>[];

  /// Register a hook that modifies token creation amount.
  ///
  /// Hook receives original item and amount, returns modified amount.
  /// Multiple hooks stack multiplicatively (2x then 2x = 4x total).
  void registerTokenCreationHook(int Function(Item item, int originalAmount) hook) {
    _tokenCreationHooks.add(hook);
  }

  /// Apply all token creation hooks to modify final amount.
  int applyTokenCreationHooks(Item item, int originalAmount) {
    int finalAmount = originalAmount;

    for (var hook in _tokenCreationHooks) {
      finalAmount = hook(item, finalAmount);
    }

    return finalAmount;
  }
}
```

### Integration Point

**TokenProvider.insertItem()**

```dart
// In lib/providers/token_provider.dart
Future<void> insertItem(Item item) async {
  try {
    // Apply doubling hooks (e.g., Doubling Season)
    final originalAmount = item.amount;
    final finalAmount = GameEvents.instance.applyTokenCreationHooks(item, originalAmount);
    item.amount = finalAmount;

    await box.add(item);

    // Fire ETB event AFTER doubling applied
    if (item.hasPowerToughness) {
      GameEvents.instance.notifyCreatureEntered(item, item.amount);
    }

    _errorMessage = null;
    notifyListeners();
    debugPrint('TokenProvider: Inserted item "${item.name}" (original: $originalAmount, final: $finalAmount)');
  } on HiveError catch (e) {
    // ... error handling
  }
}
```

### Example Utilities

**Doubling Season:**
- **Effect:** Doubles all token creation (×2)
- **Type:** Toggle widget (on/off state)
- **Hook:** Returns `originalAmount * 2` when active
- **Visual:** Shows "×2" badge on ContentScreen when active

**Parallel Lives:**
- **Effect:** Doubles creature token creation only (×2)
- **Type:** Toggle widget
- **Hook:** Returns `originalAmount * 2` if `item.hasPowerToughness`, else `originalAmount`

**Anointed Procession:**
- **Effect:** Doubles all token creation (×2, same as Doubling Season)
- **Type:** Toggle widget
- **Hook:** Same as Doubling Season

**Primal Vigor:**
- **Effect:** Doubles all token creation (×2)
- **Type:** Toggle widget
- **Hook:** Same as Doubling Season

### Hook Registration

```dart
// In ToggleProvider.init() or similar
void init() {
  // ... existing init code ...

  // Register token doubling hook for active doublers
  GameEvents.instance.registerTokenCreationHook((item, originalAmount) {
    // Find all active doubling utilities
    final doublers = box.values.where((toggle) =>
      toggle.isActive &&
      (toggle.actionType == 'doubling_season' ||
       toggle.actionType == 'parallel_lives' ||
       toggle.actionType == 'anointed_procession')
    );

    int finalAmount = originalAmount;

    for (var doubler in doublers) {
      // Apply doubling (stacks multiplicatively)
      if (doubler.actionType == 'parallel_lives') {
        // Only double creatures
        if (item.hasPowerToughness) {
          finalAmount *= 2;
        }
      } else {
        // Double all tokens
        finalAmount *= 2;
      }
    }

    return finalAmount;
  });
}
```

### Testing Requirements

- [ ] Doubling Season toggle doubles token creation when ON
- [ ] Doubling Season does NOT affect tokens when OFF
- [ ] Multiple doublers stack multiplicatively (2x + 2x = 4x)
- [ ] Parallel Lives only doubles creatures (not artifacts/enchantments)
- [ ] ETB events fire AFTER doubling applied (count reflects final amount)
- [ ] Summoning sickness applied to final doubled amount
- [ ] Cathar's Crusade increments based on final doubled amount

---

## Implementation Priority

When implementing these triggers, suggested order:

1. **Death Triggers** - Enables Blood Artist, Zulaport Cutthroat utilities (simple counter tracking)
2. **Token Doubling** - High user demand for Doubling Season, Parallel Lives effects
3. **Tap/Untap Triggers** - Enables Inspired mechanic tracking (niche but interesting)
4. **Counter Triggers** - Enables Proliferate, Hardened Scales tracking (complex, lower demand)

---

## Cross-References

- Main Event Bus implementation: `docs/activeDevelopment/NextFeature.md` (Cathar's Crusade section)
- Event Bus source: `lib/utils/game_events.dart`
- Provider integration examples: `lib/providers/token_provider.dart`, `lib/providers/tracker_provider.dart`
