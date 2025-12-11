✅ Removed the "Board Update" submenu - all actions now in main menu for fewer taps.

# ✅ RESOLVED: Copy Counter issue (v1.8.0)

**Resolution:** Counter copying has been **disabled** in v1.8.0. The Copy button now creates fresh token stacks without any counters (+1/+1, -1/-1, or custom). Users should use "Split Stack" feature to preserve counters when dividing stacks.

## Original Bug Description

When a user pressed "Copy" to copy a token stack, custom counters appeared to be "linked" between the original and copy. Modifying a custom counter on one token would update all copies.

**Root Cause:** Shallow copy bug in `token_provider.dart:274-277`
- The code added the **same** `TokenCounter` object references to both token stacks
- When modifying `counter.amount` on one token, it modified the shared object appearing in both lists
- +1/+1 counters didn't have this bug because they're primitive `int` fields (copied by value, not reference)

**Steps to reproduce the bug:**
- Create any token
- Add a custom counter (e.g., "Age" or "FooBar")
- Press "Copy" button
- Increase custom counter on first token
- Both token cards show the updated counter value

## Fix Applied

The fix creates proper deep copies of `TokenCounter` objects:
```dart
for (final counter in original.counters) {
  newItem.counters.add(TokenCounter(
    name: counter.name,
    amount: counter.amount,
  ));
}
```

However, this fix is **commented out** in the code with documentation for future reference.

## Design Decision

Counter copying was disabled (not just fixed) because:
1. **Better UX**: Copy button creates fresh stacks for independent tracking
2. **Clear separation of concerns**: "Split Stack" feature already exists for preserving counters
3. **Typical use case**: Players usually want separate stacks to manage independently

**Code location:** `lib/providers/token_provider.dart:274-289`

## Other Fields Investigated

- ✅ `artworkOptions`: Already correctly deep-copied with `List.from()`
- ✅ All primitive fields (strings, ints, etc.): Copied by value
- ✅ **Only `counters` list had the shallow copy bug** 
