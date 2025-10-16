# Version Improvements
This document addresses a number of bugs and feedback items in a SwiftUI token counter app for Magic: the Gathering. Before implementing fixes, read these relevant files

- Doubling Season/TokenSearchView.swift
- Doubling Season/MultiplierView.swift
- Doubling Season/SplitStackView.swift
- Doubling Season/ExpandedTokenView.swift
- AI STUFF/process_tokens.py

Implementation Priority:
1. Missing Token Types (regenerates data)
2. Search UI Issue (UI fix)
3. Multiplier Adjustment (UI fix)
4. Split Stack Cancellation (behavioral fix)
5. Split Stack App Crashes (critical fix)

Testing Scope: 
Testing is performed by human experts with hands on exploration and functional testing. Do not generate test code.

Post-Implementation Verification:
Validate through code analysis that the changes made account for the following requirements
- [ ] Search title hides/shows with keyboard
- [ ] "Decayed" zombie appears in token database
- [ ] Multiplier increments by 1
- [ ] No crashes when splitting 1-2 token stacks
- [ ] Cancel keeps expanded view open
- [ ] Complete split closes expanded view

## Search UI Issue

Problem: In [TokenSearchView.swift](Doubling Season/TokenSearchView.swift:101-102), the navigation title "Select Token" overlaps with the search bar when search results are empty and the keyboard is visible.

Current Implementation:
- Line 101: .navigationTitle("Select Token") - Always visible
- Line 102: .navigationBarTitleDisplayMode(.large) - Large title mode
- Line 136: Search TextField without focus state tracking

Solution: Hide navigation title when search field is focused (iOS best practice for search-focused views).

Changes Required: 
Add focus state property after line 31:
`@FocusState private var isSearchFieldFocused: Bool`

Update TextField at line 136 to include:
`.focused($isSearchFieldFocused)`

Replace lines 101-102 with:
`.navigationTitle(isSearchFieldFocused ? "" : "Select Token")`
`.navigationBarTitleDisplayMode(isSearchFieldFocused ? .inline : .large)`

Expected Result: Navigation title disappears when user taps search field, reappears when keyboard dismisses. No visual overlap in any state.

## Missing Token Types

Problem: The deduplication script in `process_tokens.py` (line 118) doesn't include abilities in its unique key, causing tokens with identical stats but different abilities to be incorrectly removed as duplicates.

Changes Required:
1. Update line 118 in `process_tokens.py`:
   ```python
   unique_key = f"{name}|{token['pt']}|{token['colors']}|{type_text}|{abilities}"```

Re-run `python AI\ STUFF/process_tokens.py`, the script to regenerate TokenDatabase.json
Verify these tokens now appear:

- Zombie (2/2, B) with "Decayed"
- Other ability-variant tokens
Testing: Search TokenDatabase.json for "Decayed" to confirm presence

## Multiplier Adjustment

Problem: In [MultiplierView.swift](Doubling Season/MultiplierView.swift:21-48), the multiplier stepper increments by powers of 2 (×1, ×2, ×4, ×8, etc.). User feedback indicates they want finer control with increments of 1 (×1, ×2, ×3, ×4, etc.).

Current Implementation:
- Line 23: Decrement button divides by 2: multiplier = max(1, multiplier / 2)
- Line 43: Increment button multiplies by 2: multiplier = min(1024, multiplier * 2)
Manual input via long-press still allows any value
Solution: Change stepper buttons to increment/decrement by 1 instead of doubling/halving.

Changes Required:
Update decrement button logic at line 23:
`multiplier = max(1, multiplier - 1)`

Update increment button logic at line 43:
`multiplier = min(1024, multiplier + 1)`

Expected Result: Multiplier steps by 1 (×1 → ×2 → ×3 → ×4, etc.) instead of powers of 2. Manual input functionality remains unchanged.

## Split Stack App Crashes

According to feedback, the cause appears to be in line 55  of SplitStackView and how we handle the slider. Instead of using a slider for how many tokens we're going to split. These crashes happen either when you tap "split stack" from exapanded view but only have 1-2 tokens in the stack, or on the splitstackview if you have 3+ tokens in the stack.

The crashes occur due to calculations of the item amount and button statuses. The root cause appears to be in the state initialization on Line 16 where the split amount initializes to 1 but the view updates and maxSplit changes (if the item amount changes during the split operation). The OnChange handler clamps the value, but only after the slider tries to render an invalid value.

Example: It Crashes on Split Completion when you split 2 tokens from a stack of 3:

- performSplit() executes (line 192)
- Line 202: item.amount = originalAmount (becomes 1)
- Line 207: modelContext.insert(newItem)
- Line 142: dismiss() is called
- BUT the view is still bound to item, which now has amount = 1
- The view tries to re-render with maxSplit = 0 (since 1-1=0, but max(1,0)=1)
- If splitAmount is still 2, the slider crashes trying to use value 2 in range 1...1

We will mitigate this issue by moving away from a slider and instead having a number selector like the one used while creating new tokens. The large number will have left and right arrows to step the value, and the user can tap to manually input the value. Validations and checks will be added to ensure the integrity of the item being handled.

After moving away from a slider into a stepper these steps need to be taken to mitigate the crashes

1. Dismiss the sheet before modifying the item
2. Add validation to onAppear that will initialize the splitAmount based on maxSplit

The onAppear validation should provide a safety net while the sheet dismisal before modification should mitigate the crashes.

## Split Stack cancellation

Problem: When user cancels split stack operation, the expanded token view incorrectly dismisses along with the sheet.
Solution: Add completion callback to only dismiss expanded view when split actually completes.

Changes Required:

1. Modify [SplitStackView.swift](Doubling Season/SplitStackView.swift:11-14):
- Add optional completion callback property: var onSplitCompleted: (() -> Void)?
- In the "Split Stack" button action (line 140), call dismiss() first
- After dismissing, use DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) to delay the split operation
- Inside the delayed block, call performSplit() then onSplitCompleted?()
- Do NOT call the callback in the "Cancel" button action
2. Modify [ExpandedTokenView.swift](Doubling Season/ExpandedTokenView.swift:85-93):
- Update the .sheet(isPresented: $isShowingSplitView) modifier to pass a trailing closure: SplitStackView(item: item) { dismiss() }
- Remove the entire .onChange(of: isShowingSplitView) modifier (lines 88-93)

Result: Expanded view only dismisses when split completes, not when user cancels.

