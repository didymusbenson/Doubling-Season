# Next Feature: Global +1/+1 Counter Tool

## Overview
A new action in the floating action menu that adds a +1/+1 counter to all tokens with power/toughness values in a single tap.

## User Interface

### Location
- Floating action menu (bottom right)
- Position: Below "New Token", above other actions
- Icon: `Icons.trending_up`
- Color: Green (enhancement/growth theme)
- Label: "+1/+1 Everything"

### Behavior
1. User taps action menu → sheet opens with actions list
2. User taps "+1/+1 Everything"
3. Sheet dismisses immediately
4. Background operation: iterate through all tokens, add +1/+1 counter to those with P/T
5. Token cards update reactively with P/T "pop" animation
6. Operation completes silently (no confirmation, no snackbar)

## Logic Requirements

### Eligibility Check (Which tokens get counters?)
A token receives a +1/+1 counter if **ANY** of these conditions are true:
- Token has a non-empty `pt` field (power/toughness)
- Examples that qualify: "1/1", "2/2", "0/1", "*/*", "1+*/1+*"

### Exclusion Cases (Which tokens are skipped?)
- Tokens with empty `pt` field
- Examples: Emblems, Treasure tokens, non-creature artifacts without P/T

### Counter Application
- If token already has +1/+1 counters: increment the count
- If token has no +1/+1 counters: add counter with count of 1
- Use existing `Item.addPowerToughnessCounters(1)` method (handles -1/-1 cancellation)
- Automatically saves token after modification
- Display updates automatically via `ValueListenableBuilder` on Hive box

## Use Cases

### Case 1: Emblem
- Token: "Emblem - Chandra" (no P/T)
- Action: Nothing happens (skipped)
- Reason: Empty `pt` field

### Case 2: Treasure Token
- Token: "Treasure" (Artifact - Treasure, no P/T)
- Action: Nothing happens (skipped)
- Reason: Empty `pt` field

### Case 3: Basic Creature Token
- Token: "Elf Warrior" (1/1 Creature - Elf Warrior)
- Action: Receives +1/+1 counter
- Display: Shows counter pill, P/T displays as "2/2"
- Reason: Has P/T value "1/1"

### Case 4: Minimal Token (P/T only)
- Token: Custom token with name "Bob", P/T "1/1", no type line
- Action: Receives +1/+1 counter
- Display: Shows counter pill, P/T displays as "2/2"
- Reason: Has P/T value "1/1"

### Case 5: Token Already Has +1/+1 Counters
- Token: "Elf Warrior" (1/1) with 2 existing +1/+1 counters (displays as 3/3)
- Action: +1/+1 counter count increases to 3
- Display: P/T displays as "4/4"
- Reason: Increments existing counter

### Case 6: Token With -1/-1 Counters
- Token: "Soldier" (1/1) with 1 -1/-1 counter (displays as 0/0)
- Action: +1/+1 counter added, cancels with -1/-1
- Display: P/T displays as "1/1" (counters cancel out)
- Reason: `addPowerToughnessCounters(1)` handles cancellation

## Technical Implementation

### Code Location
- **FloatingActionMenu**: Add new callback parameter `onAddCountersToAll`
- **ContentScreen**: Implement handler method `_handleAddCountersToAll()`
- **TokenProvider**: Add new method `addPlusOneToAll()` (similar to `untapAll()`, `clearSummoningSickness()`)

### Multi-Tap Prevention
Similar to token creation flow:
```dart
// In ContentScreen
bool _isAddingCounters = false;

void _handleAddCountersToAll() {
  if (_isAddingCounters) return; // Prevent multi-tap

  setState(() => _isAddingCounters = true);

  Navigator.pop(context); // Close action sheet immediately

  // Background operation
  tokenProvider.addPlusOneToAll().then((_) {
    setState(() => _isAddingCounters = false);
  });
}
```

### Concurrent Modification Handling
**CRITICAL QUESTION**: What happens if user performs these actions while counters are being added?

#### Scenario A: User opens ExpandedTokenScreen while operation running
- Current token being modified
- User changes P/T or other fields
- Potential conflict?

#### Scenario B: User deletes token while operation running
- Token is in iteration list
- Token gets deleted mid-operation
- Causes error when trying to save?

#### Scenario C: User creates new token while operation running
- New token added to box
- Not in original iteration list
- Should it get a counter or not?

### Proposed Solutions

**Option 1: Lock UI During Operation (Less Preferable)**
- Show overlay with spinner
- Disable all token interactions
- Simple but intrusive

**Option 2: Snapshot-Based Iteration (Recommended)**
```dart
Future<void> addPlusOneToAll() async {
  // Snapshot tokens at start
  final tokensToModify = items.where((item) => item.pt.isNotEmpty).toList();

  for (final item in tokensToModify) {
    // Check if token still exists before modifying
    if (item.isInBox) {
      item.addPowerToughnessCounters(1);
      await item.save();
    }
  }
}
```
- Non-blocking
- Ignores tokens created during operation
- Safely skips deleted tokens
- User can interact freely

**Option 3: Atomic Batch Operation**
- Disable button during operation
- Very fast (should complete in milliseconds for typical board states)
- No UI lock needed - operation completes before user can react
- Use `await` chain to ensure completion

## Performance Considerations

### Expected Board State
- Typical: 5-20 token stacks
- Heavy: 50+ token stacks
- Each modification: < 1ms (update counter + save)

### Estimated Duration
- Light board (10 tokens): ~10ms
- Heavy board (50 tokens): ~50ms
- Should be imperceptible to user

### Optimization
- Use `items` snapshot (already sorted)
- Filter for non-empty `pt` once
- Single pass through list
- Each save is async but sequential (Hive handles efficiently)

## Finalized Decisions

### UI Elements
- **Icon**: `Icons.trending_up` (power increase visual)
- **Color**: Green (enhancement/growth theme)
- **Label**: "+1/+1 Everything"

### User Experience
- **Confirmation**: None - execute immediately
- **User Feedback**: Silent operation - visual changes are self-evident
- **Edge Cases**: Silent no-op if no eligible tokens (no error message needed)

### Technical Approach
- **Concurrent Modification**: Snapshot-based iteration (Option A)
  - Take snapshot of tokens at operation start
  - Check `isInBox` before modifying each token
  - Gracefully handle deletions during operation
  - Non-blocking, user can interact freely

### Animation
- **P/T Pop Effect**: When counter is added, P/T text scales up briefly
  - Duration: 500ms
  - Scale: 1.0 → 1.5 → 1.0
  - Overflow: Allowed (can overlap other card elements temporarily)
  - No layout shift: Uses Transform (doesn't affect positioning)

### Scope
- **MVP**: Just +1/+1 counters
- **Future**: See FeedbackIdeas.md for "-1/-1 Everything" and other counter types

## Implementation Priority

1. **Core Functionality** (MVP)
   - Add action to menu
   - Implement `addPlusOneToAll()` in TokenProvider
   - Multi-tap prevention
   - Sheet auto-dismiss

2. **Polish** (Post-MVP)
   - Icon/color finalization
   - User feedback (snackbar/message)
   - Edge case handling (no eligible tokens)

3. **Future Enhancements** (Nice to Have)
   - Other counter types
   - Undo functionality
   - Filters/selection
   - Animation effects

## Next Steps

1. Answer clarifying questions
2. Finalize UI decisions (icon, color, label)
3. Choose concurrent modification strategy
4. Implement MVP
5. Test with various board states
6. Gather user feedback
7. Iterate on polish items
