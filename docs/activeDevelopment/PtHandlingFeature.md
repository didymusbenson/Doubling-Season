# Power/Toughness Display Handling & Token Controls Redesign

## Overview
Redesign the token card layout to give P/T values a dedicated row above centered token controls, solving overlap issues while improving overall usability and enabling new quick-action buttons.

## Implementation Status

**Status:** ✅ **READY FOR AUTONOMOUS IMPLEMENTATION**

All design decisions resolved. No ambiguities remaining.

**Key Decisions:**
- ✅ Clear SS Icon: `Icons.adjust` (matches existing SS display)
- ✅ Split Icon: `Icons.call_split`
- ✅ Button Order: Remove, Add, Untap, Tap, Clear SS, Copy, Split, Scute Swarm
- ✅ Split Behavior: Same as ExpandedTokenScreen, close sheet and stay on main list
- ✅ Button Spacing: Keep current (8px), adjust during testing if needed
- ✅ P/T Styling: Keep current styling, no font changes
- ✅ Long-press: No special behavior for new buttons
- ✅ Visual Feedback: Immediate disappearance (reactive rendering)

## Problem Statement

The P/T display shares a horizontal row with action buttons (add/remove/tap/untap/copy). When P/T strings become too long, they overlap with buttons, making both the P/T value and the buttons difficult to read and interact with.

**Current Layout:**
```
[Buttons: - + ↑ → copy]              [3/3]       ← Normal (works fine)
[Buttons: - + ↑ → copy]    [*/*+1 (+5/+5)]       ← Overlap (broken)
[Buttons: - + ↑ → copy]          [1003/1003]     ← Overlap (broken)
```

## Problem Cases

### Case 1: Non-Standard P/T with Counters
**Example:** `*/*+1` with 5 +1/+1 counters
- **Current display:** `*/*+1 (+5/+5)` (14 characters)
- **Problem:** The notation for showing both base and modified P/T is too verbose
- **Frequency:** Uncommon but valid (tokens like "Fractal" or "Construct")

### Case 2: Extreme Counter Values
**Example:** `3/3` with 1000 +1/+1 counters
- **Current display:** `1003/1003` (9 characters)
- **Problem:** Players adding hundreds or thousands of counters (e.g., infinite combo scenarios)
- **Frequency:** Rare but legitimate gameplay (combo decks, casual/Commander formats)

### Case 3: Edge Cases
**Examples:**
- `*/1+*` with counters → `*/1+* (+10/+10)` (17 characters)
- `X/X` with 9999 counters → `9999/9999` (9 characters)
- `100/100` with 900 counters → `1000/1000` (9 characters)

## Proposed Solutions

### Option 1: Dynamic Text Scaling
**Approach:** Reduce font size when P/T exceeds threshold length.

**Implementation:**
- Measure P/T string length
- Scale font from `headlineMedium` down to `bodyMedium` or smaller
- Maintain minimum readable size (don't go below ~14sp)

**Pros:**
- Always fits in available space
- No layout changes needed
- Simple to implement

**Cons:**
- Inconsistent text sizes across cards look unprofessional
- Very small text at extreme values (1000+ digits) becomes unreadable
- Doesn't follow Material Design typography guidelines

**Verdict:** ⚠️ Quick fix but poor UX at scale

---

### Option 2: Two-Line Display for Long Values
**Approach:** Stack P/T on a second line when it exceeds threshold.

**Implementation:**
- Detect P/T length > 7 characters
- Move P/T to its own line below buttons
- Keep buttons bottom-aligned to maintain layout consistency

**Example:**
```
[Buttons: - + ↑ → copy]
                    [1003/1003]    ← Bottom-aligned

[Buttons: - + ↑ → copy]
                [*/*+1 (+5/+5)]    ← Bottom-aligned
```

**Pros:**
- Maintains consistent font size
- Clear visual separation
- Simple conditional logic

**Cons:**
- Cards with long P/T become taller (inconsistent card heights in list)
- More vertical space consumed

**Verdict:** ✅ Clean, readable, follows original design intent

---

### Option 3: Abbreviated Number Notation
**Approach:** Use K/M/B notation for large numbers (1K, 1M, 1B).

**Implementation:**
- Format numbers ≥1000 as "1K", ≥1,000,000 as "1M", etc.
- Example: `1003/1003` → `1K/1K`
- Example: `9999/9999` → `10K/10K` (rounded)

**Pros:**
- Extremely compact representation
- Common in gaming UIs (MTG Arena uses this)
- Maintains single-line layout

**Cons:**
- Loss of precision (shows ~1K instead of exact 1003)
- Requires tap-to-expand for exact values
- Doesn't help with non-numeric P/T like `*/*+1 (+5/+5)`

**Verdict:** ⚠️ Good for extreme numbers, doesn't solve all cases

---

### Option 4: Truncate with Ellipsis + Tap to Expand
**Approach:** Truncate P/T at 7 characters with "..." and make it tappable.

**Implementation:**
- Show first 7 chars + "..." (e.g., `1003/10...`)
- Tap P/T to show full value in a dialog/tooltip
- Visual indicator (subtle icon or different text color) that it's tappable

**Pros:**
- Consistent layout, no size changes
- Full precision available on demand
- Works for all cases (numbers and non-standard)

**Cons:**
- Hidden information (user doesn't see full value at a glance)
- Requires extra interaction
- Not discoverable without visual cue

**Verdict:** ⚠️ Power-user friendly but hides critical gameplay info

---

### Option 5: Compact Counter Notation
**Approach:** Simplify how counters are displayed for non-standard P/T.

**Current:** `*/*+1 (+5/+5)` (14 chars)
**Proposed:** `*/*+1 +5` (8 chars) - show only the counter delta, not full notation

**Alternative compact formats:**
- `*/*+1⁺⁵` - use superscript (7 chars)
- `*/*+1 [+5]` - brackets (11 chars)
- `*/*+1 ↑5` - arrow indicator (9 chars)

**Pros:**
- Solves Case 1 (non-standard P/T with counters)
- Maintains readability
- Single line layout

**Cons:**
- Doesn't solve Case 2 (extreme numbers)
- Less explicit about what the modifier represents
- May confuse new users

**Verdict:** ✅ Good complement to other solutions for Case 1

---

### Option 6: Move P/T Above Button Row
**Approach:** Reflow layout to put P/T on its own line above buttons.

**Implementation:**
```
                        [1003/1003]    ← Always on top
[Buttons: - + ↑ → copy]               ← Always on bottom
```

**Pros:**
- Always sufficient space for P/T
- Consistent layout (P/T always in same position)
- No conditional logic needed

**Cons:**
- Breaks current design pattern (P/T traditionally on right)
- All cards become taller
- Changes visual hierarchy

**Verdict:** ⚠️ Solves the problem but major layout change

---

### Option 7: Adaptive Button Layout
**Approach:** Wrap buttons to a second row when P/T is large.

**Implementation:**
```
Normal:
[Buttons: - + ↑ → copy]              [3/3]

Large P/T:
[Buttons: - + ↑]         [*/*+1 (+5/+5)]
[Buttons: → copy]
```

**Pros:**
- P/T stays on right (consistent with design)
- Buttons remain accessible
- Flexible layout

**Cons:**
- Complex layout logic
- Button positions change (UX inconsistency)
- Cards become taller anyway

**Verdict:** ⚠️ Over-engineered, confusing button reflow

---

### Option 8: Tap-to-Reveal Full P/T Badge
**Approach:** Show abbreviated P/T with tap gesture to reveal full value in overlay.

**Implementation:**
- Display `1003...` in badge/pill
- Tap P/T area to show floating overlay with full value: `1003/1003`
- Overlay auto-dismisses after 2 seconds or on tap elsewhere

**Pros:**
- Elegant, minimal UI impact
- Full precision available
- Works for all edge cases

**Cons:**
- Critical info hidden behind interaction
- Not accessible without tap
- May frustrate users who want to see exact values

**Verdict:** ⚠️ Good for extreme edge cases but hides important data

---

### Option 9: Hybrid Approach - Abbreviated with Tooltip
**Approach:** Show abbreviated values but with instant visual feedback.

**Implementation:**
- Display `1K/1K` for large numbers
- Long-press P/T shows tooltip with exact value: `1003/1003`
- Tooltip appears immediately on long-press (no navigation)

**Pros:**
- Clean single-line display
- Exact values available without dialog
- Familiar pattern (long-press for more info)

**Cons:**
- Still hides precision by default
- Long-press not universally discoverable
- Doesn't help with `*/*+1 (+5/+5)` case

**Verdict:** ✅ Best balance for Case 2 (extreme numbers)

---

### Option 10: Maximum P/T Cap with Warning
**Approach:** Enforce maximum displayable P/T and warn users.

**Implementation:**
- Cap display at reasonable limit (e.g., 9999/9999)
- Show `9999+/9999+` for values exceeding cap
- Add visual indicator (icon, color) that value is capped
- Tap to see exact value in details view

**Pros:**
- Prevents extreme display issues
- Simple implementation
- Educates users about practical limits

**Cons:**
- Arbitrary limitation on valid gameplay
- May frustrate combo players
- Doesn't solve non-standard P/T case

**Verdict:** ❌ Too restrictive, doesn't respect valid gameplay

---

## Recommended Combination (PENDING USER DECISION)

**Tiered approach based on P/T type and length:**

### Tier 1: Standard P/T (numeric, no counters)
- Length ≤7 chars → Display normally: `3/3`
- Length 8-9 chars → Display normally: `1003/1003`
- Length ≥10 chars → Abbreviate with K/M notation: `10K/10K`
  - Long-press shows tooltip with exact value

### Tier 2: Modified P/T (numeric with counters)
- Calculable (e.g., `3/3` → `8/8`) → Use highlighted background (current)
- Length ≤7 chars → Display normally: `8/8`
- Length ≥8 chars → Abbreviate: `10K/10K`
  - Long-press shows breakdown: "Base: 3/3, Counters: +9997/+9997"

### Tier 3: Non-Standard P/T (contains `*`, `X`, etc.)
- No counters → Display normally: `*/*+1`
- With counters → Use compact notation: `*/*+1 +5` (instead of `*/*+1 (+5/+5)`)
  - If still >7 chars → Two-line display (fallback)

## Implementation Checklist (TO BE UPDATED AFTER DESIGN DECISION)

- [ ] Add P/T length detection utility function
- [ ] Implement K/M/B number formatting helper
- [ ] Create compact counter notation for non-standard P/T
- [ ] Add long-press tooltip handler for P/T element
- [ ] Update `formattedPowerToughness` getter to include length checks
- [ ] Add unit tests for edge cases (extreme numbers, non-standard formats)
- [ ] Visual testing with real tokens in various scenarios

## Test Cases (TO BE UPDATED AFTER DESIGN DECISION)

**Standard P/T:**
- `3/3` → `3/3` (no change)
- `99/99` → `99/99` (no change)
- `1003/1003` → `1K/1K` (long-press shows `1003/1003`)
- `10000/10000` → `10K/10K` (long-press shows `10000/10000`)
- `1000000/1000000` → `1M/1M` (long-press shows `1000000/1000000`)

**Modified P/T:**
- `3/3` + 5 counters → `8/8` (highlighted, current behavior)
- `3/3` + 1000 counters → `1K/1K` (highlighted, abbreviated)
- `100/100` + 900 counters → `1K/1K` (highlighted, abbreviated)

**Non-Standard P/T:**
- `*/*` → `*/*` (no change)
- `*/*+1` → `*/*+1` (no change)
- `*/*+1` + 5 counters → `*/*+1 +5` (compact notation)
- `X/X` + 10 counters → `X/X +10` (compact notation)
- `*/1+*` + 100 counters → Two-line display (fallback if compact still >7 chars)

## Success Criteria (TO BE FINALIZED AFTER DESIGN DECISION)

After implementation:
- ✅ No P/T overlaps with buttons in any scenario
- ✅ All P/T values ≤7 characters display unchanged
- ✅ Extreme values (1000+) use K/M notation
- ✅ Non-standard P/T with counters use compact notation
- ✅ Long-press tooltip shows exact values for abbreviated numbers
- ✅ Visual consistency maintained across token cards
- ✅ Layout doesn't break with any valid P/T combination

---

## Selected Solution: Option C - Dedicated P/T Row with Centered Controls

### Decision Rationale

After evaluating 10 different approaches, **Option C (P/T Above Button Row)** was selected with enhancements:

**Why this approach wins:**
1. ✅ **Always visible**: Both P/T and buttons fully accessible, no hidden information
2. ✅ **Zero interaction tax**: No extra taps needed for any operation
3. ✅ **Scales infinitely**: Handles even extreme values like `*/1+* (+9999/+9999)`
4. ✅ **Consistent layout**: All cards have same structure, no conditional edge-case handling
5. ✅ **Extensible**: Room to add new buttons without redesigning layout
6. ✅ **Respects information hierarchy**: P/T is critical gameplay data, deserves dedicated space

**Trade-offs accepted:**
- Cards become slightly taller (but consistently, not just edge cases)
- Slight increase in vertical scroll distance
- **Verdict**: Minor cost for major usability gain

---

## New Layout Design

### Visual Structure

```
╔══════════════════════════════════════════════════════════════╗
║ Token Name                        🌙1  📍5  ⟳3               ║ ← Name + counts
║ Creature — Goblin                                            ║ ← Type (future feature)
║ [+1/+1: 5] [Vigilance: 2]                                    ║ ← Counter pills
║ Haste, First strike                                          ║ ← Abilities
║                                                         3/3  ║ ← P/T (NEW ROW)
║         [➖] [➕] [⬆️] [⤵️] [💤] [✂️] [📋] [🐛*]               ║ ← Centered buttons
╚══════════════════════════════════════════════════════════════╝

* 🐛 = Scute Swarm doubling button (conditional, only for Scute Swarm)
```

### Layout Hierarchy (Top to Bottom)

1. **Name Row**: Token name (left) + Status counts (right: summoning sick, untapped, tapped)
2. **Type Row**: Token type in italics *(from NextFeature.md Feature 1)*
3. **Counter Pills Row**: Display of all counters (if any)
4. **Abilities Row**: Token abilities text
5. **P/T Row**: Power/Toughness display, right-aligned, full row width available
6. **Button Row**: Centered action buttons

---

## Required Changes

### File: `lib/widgets/token_card.dart`

#### New Button Requirements

**Existing Buttons (keep):**
1. ➖ **Remove** - Decrease token count by 1 (or all on long-press)
2. ➕ **Add** - Increase token count by multiplier (10× on long-press)
3. ⬆️ **Untap** - Untap 1 token (or all tapped on long-press)
4. ⤵️ **Tap** - Tap 1 token (or all untapped on long-press)
5. 📋 **Copy** - Duplicate the entire token stack

**New Buttons (add):**
6. **Clear Summoning Sickness** - Remove summoning sickness from this token stack only
   - Icon: `Icons.adjust` (same icon used elsewhere for summoning sickness)
   - Tap: Clear summoning sickness for entire stack (set `item.summoningSick = 0`)
   - Long-press: No special behavior
   - Only visible if `summoningSicknessEnabled` AND `item.summoningSick > 0`

7. **Split Stack** - Open split stack dialog
   - Icon: `Icons.call_split`
   - Tap: Opens `SplitStackSheet` via `showModalBottomSheet` (same behavior as ExpandedTokenScreen)
   - Callback: Close sheet and stay on main list (user sees new split token inserted)
   - Long-press: No special behavior
   - Only visible if `item.amount > 1`

**Conditional Button (keep):**
8. 🐛 **Scute Swarm Double** - Double the token count
   - Only visible if `item.name.toLowerCase().contains('scute swarm')`

#### Layout Changes

**Current Layout:**
```dart
Row(
  children: [
    Expanded(child: _buildActionButtons()),  // Left-aligned
    if (item.pt.isNotEmpty) Text(item.pt),   // Right-aligned
  ],
)
```

**New Layout:**
```dart
Column(
  children: [
    // P/T Row (new)
    if (!item.isEmblem && item.pt.isNotEmpty)
      Container(
        width: double.infinity,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(bottom: 8),
        child: item.isPowerToughnessModified
          ? Container(/* highlighted P/T */)
          : Text(item.formattedPowerToughness, /* styling */),
      ),

    // Button Row (modified)
    Row(
      mainAxisAlignment: MainAxisAlignment.center,  // ← CENTERED
      children: [
        _buildActionButton(Icons.remove, ...),           // Remove
        _buildActionButton(Icons.add, ...),              // Add
        if (!item.isEmblem) ...[
          _buildActionButton(Icons.screenshot, ...),      // Untap
          _buildActionButton(Icons.screen_rotation, ...), // Tap
          // NEW: Clear summoning sickness button
          if (summoningSicknessEnabled && item.summoningSick > 0)
            _buildActionButton(Icons.adjust, ...),        // Clear SS
        ],
        _buildActionButton(Icons.content_copy, ...),     // Copy
        // NEW: Split stack button
        if (!item.isEmblem && item.amount > 1)
          _buildActionButton(Icons.call_split, ...),     // Split
        if (item.name.toLowerCase().contains('scute swarm'))
          _buildActionButton(Icons.bug_report, ...),     // Scute Swarm
      ],
    ),
  ],
)
```

#### Styling & Spacing

**Button Spacing:**
- Keep current horizontal padding between buttons (`8px` currently)
- NOTE: Adjust during testing if button overflow occurs with 7-8 buttons visible
- Button icons remain `size: 20`
- Button container remains `padding: 8`

**P/T Styling:**
- Keep current font styling (same as existing implementation)
- P/T row gets `bottom: 8` padding to separate from buttons
- Modified P/T maintains highlighted background (existing behavior)

**Button Order (left to right):**
1. Remove
2. Add
3. Untap (if not emblem)
4. Tap (if not emblem)
5. Clear SS (if not emblem AND summoningSicknessEnabled AND summoningSick > 0)
6. Copy
7. Split (if not emblem AND amount > 1)
8. Scute Swarm (if name contains "scute swarm")

---

## Implementation Checklist

### Phase 1: Layout Restructure
- [ ] Extract P/T display from button row into dedicated `Column`
- [ ] Move P/T above buttons with right alignment
- [ ] Change button row `mainAxisAlignment` from `start` to `center`
- [ ] Adjust spacing (button padding, P/T bottom margin)
- [ ] Test with various P/T lengths to confirm no overflow

### Phase 2: New Button - Clear Summoning Sickness
- [ ] Add conditional button after Tap button, before Copy button
- [ ] Use icon: `Icons.adjust` (matches existing SS display icon)
- [ ] Implement tap action: `item.summoningSick = 0; tokenProvider.updateItem(item)`
- [ ] Show only if `!item.isEmblem && summoningSicknessEnabled && item.summoningSick > 0`
- [ ] No long-press behavior needed
- [ ] Test with summoning sickness enabled/disabled
- [ ] Test with tokens that have/don't have summoning sickness
- [ ] Verify button disappears immediately after tap (reactive rendering)

### Phase 3: New Button - Split Stack
- [ ] Add conditional button after Copy button, before Scute Swarm button
- [ ] Use icon: `Icons.call_split`
- [ ] Show only if `!item.isEmblem && item.amount > 1`
- [ ] Implement tap action using `showModalBottomSheet` (same as ExpandedTokenScreen):
  ```dart
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SplitStackSheet(
      item: item,
      onSplitCompleted: () {
        Navigator.of(context).pop(); // Close sheet, stay on main list
      },
    ),
  );
  ```
- [ ] No long-press behavior needed
- [ ] Test split functionality from card (should match ExpandedTokenScreen behavior)
- [ ] Verify new split token appears in main list after split
- [ ] Verify button disappears when `amount` becomes 1 after split

### Phase 4: Button Ordering & Layout
- [ ] Ensure final button order: Remove, Add, Untap, Tap, Clear SS, Copy, Split, Scute Swarm
- [ ] Verify buttons remain horizontally centered with `MainAxisAlignment.center`
- [ ] Test button layout with various combinations:
  - [ ] Emblem: Remove, Add, Copy (3 buttons)
  - [ ] Standard token (no SS, amount=1): Remove, Add, Untap, Tap, Copy (5 buttons)
  - [ ] Standard token (with SS, amount>1): Remove, Add, Untap, Tap, Clear SS, Copy, Split (7 buttons)
  - [ ] Scute Swarm (with SS, amount>1): All 8 buttons
- [ ] Check that button group doesn't overflow on small screens (iPhone SE, etc.)
- [ ] If overflow occurs, reduce padding as noted in specs

### Phase 5: Visual Polish
- [ ] P/T styling remains same as current implementation (no font size changes)
- [ ] Modified P/T highlighted background styling (keep existing behavior)
- [ ] Button container styling consistency
- [ ] Adequate vertical spacing between rows (P/T gets `bottom: 8` padding)
- [ ] Dark mode / light mode testing

---

## Test Cases

### P/T Display
- [ ] Standard P/T `3/3` → Right-aligned, above buttons
- [ ] Modified P/T `8/8` (from counters) → Highlighted, right-aligned
- [ ] Long P/T `1003/1003` → Fits comfortably, no overlap
- [ ] Non-standard `*/*+1 (+5/+5)` → Fits comfortably, no truncation
- [ ] Extreme `*/1+* (+9999/+9999)` → Fits without overflow
- [ ] Empty P/T → Row not shown (Emblems, etc.)

### Button Layout
- [ ] Button order: Remove, Add, Untap, Tap, Clear SS, Copy, Split, Scute Swarm
- [ ] All 7 buttons visible for standard creature token with SS and amount > 1
- [ ] 6 buttons visible when summoning sickness cleared (no Clear SS button)
- [ ] 6 buttons visible when amount = 1 (no Split button)
- [ ] 5 buttons for standard token (no SS, amount=1): Remove, Add, Untap, Tap, Copy
- [ ] 3 buttons for Emblems: Remove, Add, Copy
- [ ] 8 buttons for Scute Swarm with SS and amount > 1
- [ ] Buttons remain centered regardless of count

### Clear Summoning Sickness Button
- [ ] Appears when `summoningSicknessEnabled = true` and `summoningSick > 0`
- [ ] Hidden when `summoningSicknessEnabled = false`
- [ ] Hidden when `summoningSick = 0`
- [ ] Tap sets `summoningSick = 0` for that token
- [ ] Does not affect other tokens
- [ ] Button disappears after clearing (conditional rendering)

### Split Stack Button
- [ ] Appears when `!item.isEmblem && amount > 1`
- [ ] Hidden when `amount = 1` or `amount = 0`
- [ ] Hidden for Emblems
- [ ] Tap opens `SplitStackSheet` modal using `showModalBottomSheet`
- [ ] Sheet displays properly from card context (not ExpandedTokenScreen)
- [ ] Split functionality works identically to AppBar button in ExpandedTokenScreen
- [ ] After split completes, sheet closes and user stays on main list
- [ ] New split token appears correctly in main list
- [ ] Button updates based on new amount (disappears if amount becomes 1)

### Edge Cases
- [ ] Token with 0 amount → Opacity 0.5, buttons still functional
- [ ] Rapid button taps don't break layout
- [ ] Long token names don't affect P/T row
- [ ] Very long abilities text doesn't affect P/T row
- [ ] Multiple counter pills don't interfere with P/T row

---

## Success Criteria

After implementation:
- ✅ P/T never overlaps with buttons in any scenario
- ✅ P/T always displays at full precision (no truncation/abbreviation)
- ✅ Buttons always centered regardless of button count
- ✅ Clear Summoning Sickness button available for quick access
- ✅ Split Stack button available without navigating to detail view
- ✅ Layout consistent across all token types
- ✅ Visual hierarchy clear: Name → Type → Counters → Abilities → P/T → Actions
- ✅ No horizontal overflow on standard mobile screen sizes
- ✅ Cards slightly taller but consistently so (no jarring height changes)
- ✅ All existing functionality preserved
- ✅ Room for future button additions without redesign

---

## Future Extensibility

With this layout, future additions become trivial:

**Potential Future Buttons:**
- ⚡ Quick +1/+1 counter button
- 💀 Quick -1/-1 counter button
- 🎲 Randomize tap/untap (for chaos effects)
- 🔄 Flip tapped/untapped counts
- 🗑️ Quick delete (with long-press confirm)

**Layout supports up to ~8-9 buttons comfortably** before needing:
- Icon-only mode (remove spacing)
- Smaller icon size
- Or overflow menu for advanced actions

---

## Design Notes

**Status:** ✅ **APPROVED - Ready for Implementation**

**Selected Approach:** Option C - Dedicated P/T Row with Centered Controls

**Key Design Decisions:**
1. ✅ P/T gets full row width, right-aligned (like physical Magic cards)
2. ✅ Buttons centered for visual balance
3. ✅ Exact precision always shown (no K/M notation needed, space is available)
4. ✅ New quick-access buttons reduce need for detail view navigation
5. ✅ Consistent layout for all tokens (no conditional width changes)

**Trade-offs Accepted:**
- Vertical space increase: ~40-50px per card
- Benefit: Infinite P/T capacity, better UX, extensible design
