# Next Feature Development

Ready to prioritize the next feature.

## Active Focus

### Status View Feature

A new view accessible from the app bar that provides statistical insights about all tokens on the board.

**Requirements:**

1. **Modal or sheet? Todo: Decide which fits best.**

2. **Total Token Count**
   - Display the total number of all tokens currently on the board

3. **Total Power**
   - Calculate by summing the power value from all tokens with P/T
   - Special handling for non-numerical power (e.g., `*/*`):
     - Display: "X total power and 3 [token names] with variable power"
   - Account for +1/+1 counters modifying power values

4. **Total Untapped Power**
   - Calculate power sum for only untapped creatures
   - Exclude tapped creatures from this calculation
   - Handle variable power same as above

5. **Total Creatures** (with tapped/untapped breakdown)
   - Count all creature tokens
   - Display format: Show total with tapped and untapped counts in the same row/group
   - Example: "15 creatures (10 untapped, 5 tapped)"

6. **Total Artifacts** (with tapped/untapped breakdown)
   - Count tokens with "artifact" in the type line
   - Display both tapped and untapped counts
   - Note: Artifact creatures count here too

7. **Total Enchantments**
   - Count tokens with "enchantment" in the type line
   - No tapped/untapped breakdown needed (enchantments don't tap typically)
   - Just show total count

**Technical Implementation:**

1. **Data Source & Access**
   - Access tokens via `TokenProvider.items` (already sorted by order)
   - Iterate once through all tokens to gather statistics
   - Filter out emblems using `item.isEmblem` computed property

2. **Power/Toughness Parsing**
   - Parse `item.pt` string (format: "power/toughness", e.g., "2/2", "3/4")
   - Must account for `item.netPlusOneCounters` when calculating modified power
   - Handle non-numeric power: `*`, `X`, `1+*`, etc.
   - Logic:
     ```dart
     // Split on '/', parse first part as power
     final parts = item.pt.split('/');
     if (parts.length == 2) {
       final basePower = int.tryParse(parts[0].trim());
       if (basePower != null) {
         final modifiedPower = basePower + item.netPlusOneCounters;
         // Add to total
       } else {
         // Track as variable power token
       }
     }
     ```

3. **Type Detection**
   - Artifact detection: `item.type.toLowerCase().contains('artifact')`
   - Enchantment detection: `item.type.toLowerCase().contains('enchantment')`
   - Creature detection: Use `item.hasPowerToughness` (more reliable than type parsing)
   - Note: "Artifact Creature" tokens count as both artifacts AND creatures

4. **Tapped/Untapped Calculation**
   - Each Item has `amount` (total) and `tapped` (count of tapped)
   - Untapped count: `item.amount - item.tapped`
   - For power calculations: sum power × untapped count for each stack

5. **Performance Considerations**
   - Single-pass iteration through `tokenProvider.items`
   - O(n) complexity where n = number of token stacks (typically < 50)
   - Calculations are synchronous (no need for async/isolate)
   - Question: Should status view auto-update when tokens change?

6. **UI Pattern Decision**
   - **Option A: Modal Dialog** (`showDialog`)
     - Pros: Lightweight, centered, good for quick info view
     - Cons: Smaller display area, less room for detailed breakdowns
     - Pattern: `AlertDialog` with title, content, and close button

   - **Option B: Bottom Sheet** (`showModalBottomSheet`)
     - Pros: More vertical space, feels like action/detail view
     - Cons: Covers bottom UI (multiplier, FAB), may feel heavy
     - Pattern: `isScrollControlled: true`, custom content

   - **Option C: Full Screen** (`Navigator.push` with Scaffold)
     - Pros: Maximum space, can show detailed breakdowns/charts
     - Cons: Most heavyweight, may be overkill for simple stats
     - Pattern: Like AboutScreen - AppBar + ScrollView

7. **Reactive Updates**
   - If auto-updating: Wrap in `ValueListenableBuilder` or `Consumer<TokenProvider>`
   - If static snapshot: Calculate once when opened, no reactivity
   - Trade-off: Auto-update is nicer UX but more complex

8. **Variable Power Display Format**
   - Current requirement: "X total power and 3 [token names] with variable power"
   - Question: Should we list all token names, or just say "3 tokens"?
   - If listing names, handle duplicates gracefully
   - Example outputs:
     - "42 total power and 2 tokens with variable power"
     - "42 total power and 1 Hydra, 1 Ooze with variable power"

**Finalized Decisions:**

1. **UI Pattern**: Bottom sheet (`showModalBottomSheet`)
   - `isScrollControlled: true`
   - Custom content with cards layout
   - Similar pattern to FloatingActionMenu and other sheets

2. **Reactivity**: Static snapshot
   - Calculate stats once when sheet opens
   - User closes and reopens to refresh
   - No reactive updates (simpler implementation)

3. **Zero-Amount Stacks**: Exclude from all calculations
   - Only count stacks where `item.amount > 0`
   - Critical for boards with ~30 stacks mostly at zero

4. **Type Detection & Overlapping Counts**:
   - Artifacts: `item.type.toLowerCase().contains('artifact')`
   - Enchantments: `item.type.toLowerCase().contains('enchantment')`
   - Creatures: Use `item.hasPowerToughness`
   - **Tokens can be counted in multiple categories** (e.g., Artifact Creature counts in both)

5. **Visual Layout**: Card-based grouping
   - Similar to AboutScreen card layout
   - Group related stats in cards (Power stats, Permanents, etc.)

6. **Stat Display Order**:
   1. Total Tokens
   2. Total Creatures (with untapped/tapped/summoning sick breakdown)
   3. Total Power / Total Untapped Power
   4. Total Artifacts (tapped/untapped)
   5. Total Enchantments

7. **Variable Power Handling**:
   - **Include counter bonuses in total power** (we can calculate this)
   - **Cannot include unknown base** (X, *, etc.)
   - Display format:
     ```
     Total Power - 21

     untracked -
     • 3 X/X Hydra
     • 2 */* Tarmogoyf
     ```
   - "untracked" label in greyed text on left
   - Bulleted list on right showing base P/T and name
   - **Deduplication key**: `basePT|name` (e.g., "X/X Hydra" vs "*/1 Hydra")
   - Show BASE P/T only (no counter modifications in display)
   - The total "21" already includes all counter bonuses

8. **Additional Stats**:
   - Include summoning sick count in creatures breakdown
   - No total +1/+1 counters stat needed
   - No total toughness needed

9. **Performance**: O(n) single-pass iteration
   - Typical board: ~30 stacks (most at zero)
   - Performance is acceptable for synchronous calculation

**Implementation Checklist:**

- [ ] Create `status_sheet.dart` widget in `lib/widgets/`
- [ ] Add status calculation logic (single-pass iteration)
- [ ] Handle variable power deduplication by `basePT|name`
- [ ] Create card-based layout with grey "untracked" labels
- [ ] Wire up status button in AppBar to open sheet
- [ ] Test with large boards (~30 stacks)
- [ ] Test variable power display with counters
- [ ] Test overlapping types (Artifact Creature)
- [ ] Test zero-amount stack exclusion

---

## Available Feature Ideas

See the following documents for potential next features:
- `FeedbackIdeas.md` - User-requested features from beta tester survey
- `PremiumVersionIdeas.md` - Planned paid features (token doublers, commander tools, etc.)
- `commanderWidgets.md` - Commander Mode system design

---

## Process for Adding New Utility Types (Reference Checklist)

When implementing new utility types, follow the comprehensive checklist that was used for Krenko and Cathar's Crusade implementations. This checklist covers:

1. Data Model creation with Hive annotations
2. Constants and type IDs
3. Hive setup and registration
4. Provider implementation with CRUD methods
5. Main app initialization
6. Widget card UI (use TokenCard as reference for artwork)
7. Widget definition and database integration
8. ContentScreen integration for display and reordering
9. Widget selection screen integration
10. Code generation
11. Testing checklist including artwork display modes

Refer to git history for Cathar's Crusade and Krenko implementations as examples.
