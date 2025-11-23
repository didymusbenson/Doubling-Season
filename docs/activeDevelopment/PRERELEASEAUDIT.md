# Pre-Release Bug Audit
**Date:** 2025-11-21
**Version:** 1.3.0+8
**Status:** Two bugs identified and reproduced

---

## = Bug #1: Scute Swarm Doubling Button Ignores Token Multiplier

**Severity:** Medium
**Status:** Confirmed via code analysis and testing
**Affects:** Scute Swarm special token only

### Description
The special Scute Swarm doubling button (bug icon =) doubles the stack size but does not respect the user's token multiplier setting. When the multiplier is set to any value other than 1, the button should create `stack_size × multiplier` tokens, but instead it only creates `stack_size` tokens (effectively ignoring the multiplier).

### Location
**File:** `lib/widgets/token_card.dart`
**Lines:** 450-461

### Code Analysis

**Current Implementation (Broken):**
```dart
// Lines 450-461
if (item.name.toLowerCase().contains('scute swarm'))
  _buildActionButton(
    context,
    icon: Icons.bug_report,
    onTap: () {
      final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
      tokenProvider.addTokens(item, item.amount, summoningSick);  // L Missing multiplier
    },
    onLongPress: null,
    color: primaryColor,
    spacing: 0,
  ),
```

**Expected Implementation:**
Compare to the regular Add button (lines 362-377) which correctly applies the multiplier:
```dart
// Regular Add button (CORRECT)
_buildActionButton(
  context,
  icon: Icons.add,
  onTap: () {
    final multiplier = context.read<SettingsProvider>().tokenMultiplier;
    final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
    tokenProvider.addTokens(item, multiplier, summoningSick);  //  Applies multiplier
  },
  // ...
),
```

### Reproduction Steps
1. Set token multiplier to 3 (or any value other than 1)
2. Create a "Scute Swarm" token
3. Add 1 token to get stack size of 2
4. Press the bug icon button (special Scute Swarm doubling)
5. **Expected:** Stack should increase by 2 × 3 = 6, resulting in stack of 8
6. **Actual:** Stack only increases by 2, resulting in stack of 4

### Debug Logs
```
I/flutter: TokenProvider: Added 2 tokens to "Scute Swarm" (2 ’ 4)
I/flutter: TokenProvider: Added 4 tokens to "Scute Swarm" (4 ’ 8)
I/flutter: TokenProvider: Added 8 tokens to "Scute Swarm" (8 ’ 16)
```
Logs confirm the button is adding `item.amount` instead of `item.amount × multiplier`.

### Fix Required
Read the multiplier from `SettingsProvider` and multiply it by `item.amount` before passing to `addTokens()`:

```dart
if (item.name.toLowerCase().contains('scute swarm'))
  _buildActionButton(
    context,
    icon: Icons.bug_report,
    onTap: () {
      final multiplier = context.read<SettingsProvider>().tokenMultiplier;  // ADD THIS
      final summoningSick = context.read<SettingsProvider>().summoningSicknessEnabled;
      tokenProvider.addTokens(item, item.amount * multiplier, summoningSick);  // CHANGE THIS
    },
    onLongPress: null,
    color: primaryColor,
    spacing: 0,
  ),
```

---

## = Bug #2: Manual Counter Input Bypasses Auto-Cancellation Logic

**Severity:** High
**Status:** Confirmed via code analysis and testing
**Affects:** All tokens with +1/+1 and -1/-1 counters

### Description
When users manually type in counter values (by tapping the counter number in the expanded token view), the +1/+1 and -1/-1 counters do NOT auto-cancel each other. This differs from using the increment/decrement buttons, which properly trigger the cancellation logic. According to Magic: The Gathering rules, +1/+1 and -1/-1 counters should always cancel each other as a state-based action, regardless of how they are applied.

### Location
**File:** `lib/screens/expanded_token_screen.dart`
**Lines:** 639-650 (for +1/+1 counters), 744-755 (for -1/-1 counters)

### Code Analysis

**Root Cause:**
The `Item` model has proper auto-cancellation logic implemented in `lib/models/item.dart:179-203`:

```dart
void addPowerToughnessCounters(int amount) {
  if (amount > 0) {
    // Adding +1/+1 counters cancels -1/-1 first
    if (_minusOneCounters > 0) {
      final reduction = amount < _minusOneCounters ? amount : _minusOneCounters;
      _minusOneCounters -= reduction;
      final remaining = amount - reduction;
      _plusOneCounters += remaining;
    } else {
      _plusOneCounters += amount;
    }
  } else if (amount < 0) {
    // Adding -1/-1 counters cancels +1/+1 first
    final absAmount = amount.abs();
    if (_plusOneCounters > 0) {
      final reduction = absAmount < _plusOneCounters ? absAmount : _plusOneCounters;
      _plusOneCounters -= reduction;
      final remaining = absAmount - reduction;
      _minusOneCounters += remaining;
    } else {
      _minusOneCounters += absAmount;
    }
  }
  save();
}
```

However, the manual input bypasses this logic by directly assigning to the properties:

**Current Implementation (Broken):**
```dart
// Lines 639-650: Manual +1/+1 counter input
onSubmitted: (_) => _saveNumericEdit((value) {
  setState(() {
    currentItem.plusOneCounters = value.clamp(0, kMaxCounterValue);  // L Direct assignment
    tokenProvider.updateItem(currentItem);
  });
}),

// Lines 744-755: Manual -1/-1 counter input
onSubmitted: (_) => _saveNumericEdit((value) {
  setState(() {
    currentItem.minusOneCounters = value.clamp(0, kMaxCounterValue);  // L Direct assignment
    tokenProvider.updateItem(currentItem);
  });
}),
```

**Comparison to Increment Buttons (Correct):**
```dart
// Lines 678-693: +1/+1 increment button (CORRECT)
IconButton(
  onPressed: isEditingPlusOne || currentItem.plusOneCounters >= kMaxCounterValue
      ? null
      : () {
          if (_editingNumericField != null) {
            _saveNumericEdit();
          }
          setState(() {
            currentItem.addPowerToughnessCounters(1);  //  Triggers cancellation logic
            tokenProvider.updateItem(currentItem);
          });
        },
  // ...
),
```

### Reproduction Steps
1. Create any creature token with P/T (e.g., "Soldier")
2. Tap the token to open expanded view
3. Tap the "+1/+1 Counters" number to edit manually
4. Type "5" and press Enter/Save
5. Tap the "-1/-1 Counters" number to edit manually
6. Type "3" and press Enter/Save
7. **Expected:** Display should show 2 +1/+1 counters and 0 -1/-1 counters (auto-cancelled)
8. **Actual:** Display shows 5 +1/+1 counters and 3 -1/-1 counters (no cancellation)

**Alternative Test:**
1. Use increment buttons to add 5 +1/+1 counters and 3 -1/-1 counters
2. Observe correct cancellation: shows 2 +1/+1, 0 -1/-1
3. Manually edit +1/+1 to "8"
4. Observe incorrect behavior: shows 8 +1/+1, 3 -1/-1 (should be 5 +1/+1, 0 -1/-1)

### Debug Logs
```
I/flutter: TokenProvider: Successfully updated token "Scute Swarm" (amount: 32, tapped: 0)
[Multiple repeated update messages during manual counter editing]
```
The logs show that updates are being persisted via direct property assignment without triggering cancellation logic.

### Fix Required

Add a method to the `Item` class to reconcile counters after direct assignment:

**Option 1: Add reconciliation method to Item model (RECOMMENDED)**
```dart
// In lib/models/item.dart
void reconcileCounters() {
  if (_plusOneCounters > 0 && _minusOneCounters > 0) {
    final cancelAmount = _plusOneCounters < _minusOneCounters
        ? _plusOneCounters
        : _minusOneCounters;
    _plusOneCounters -= cancelAmount;
    _minusOneCounters -= cancelAmount;
    save();
  }
}
```

Then call it after manual input:
```dart
// In expanded_token_screen.dart
onSubmitted: (_) => _saveNumericEdit((value) {
  setState(() {
    currentItem.plusOneCounters = value.clamp(0, kMaxCounterValue);
    currentItem.reconcileCounters();  // ADD THIS
    tokenProvider.updateItem(currentItem);
  });
}),
```

**Option 2: Calculate delta and use existing method**
```dart
// Store previous value before editing
int _previousPlusOneCounters = 0;

// On edit start, capture current value
onTap: () {
  setState(() {
    _editingNumericField = 'counter_plusOne';
    _previousPlusOneCounters = currentItem.plusOneCounters;
    _numericController.text = currentItem.plusOneCounters.toString();
  });
},

// On save, calculate delta and use addPowerToughnessCounters
onSubmitted: (_) => _saveNumericEdit((value) {
  setState(() {
    final newValue = value.clamp(0, kMaxCounterValue);
    final delta = newValue - _previousPlusOneCounters;

    // Reset counters first
    currentItem.plusOneCounters = _previousPlusOneCounters;

    // Apply delta through proper method
    currentItem.addPowerToughnessCounters(delta);
    tokenProvider.updateItem(currentItem);
  });
}),
```

**Recommendation:** Option 1 is simpler and cleaner. Option 2 is more complex but uses the existing cancellation logic without modification.

---

## Summary

Both bugs have been confirmed through code analysis, manual testing, and debug log capture.

- **Bug #1** is a straightforward missing multiplier read that affects the Scute Swarm special functionality
- **Bug #2** is a more serious rules violation that affects all tokens and bypasses core game mechanics

Both should be fixed before the next release to ensure consistent behavior and adherence to Magic: The Gathering rules.

---

## Test Environment
- **Platform:** Android Emulator (sdk gphone64 arm64, API 36)
- **Flutter Version:** Latest stable
- **Build:** Debug mode
- **Date Tested:** 2025-11-21
