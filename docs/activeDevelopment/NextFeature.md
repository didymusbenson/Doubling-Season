# Next Feature

## WCAG Accessibility Fixes

### Overview
Fix contrast and theme inconsistencies in Split Stack View and Expanded Token View to meet WCAG AA standards (4.5:1 for text, 3:1 for UI components) and match the compliant patterns already used in Token Card.

### Problem
Both Split Stack View and Expanded Token View use hardcoded gray colors that:
- Fail WCAG contrast requirements in both light and dark modes
- Don't adapt to system theme changes
- Are inconsistent with the theme-aware patterns in token_card.dart

### Affected Files
1. `lib/widgets/split_stack_sheet.dart` - 13 changes
2. `lib/screens/expanded_token_screen.dart` - 14 changes
3. `lib/widgets/token_card.dart` - 1 change

**Exempt (Do Not Modify):**
- `lib/widgets/color_selection_button.dart` - Contains MTG game mechanic colors

### Critical Issues Found

#### Split Stack View Issues:
- **Lines 72, 76, 197, 201, 212, 216**: `TextStyle(color: Colors.grey)` - fails 4.5:1 contrast
- **Line 234**: `TextStyle(color: Colors.grey)` - fails on italic note text
- **Line 97**: `Colors.grey.withOpacity(0.1)` - fails 3:1 UI component contrast
- **Lines 108, 137**: Hardcoded `Colors.grey` and `Colors.blue` for disabled icon states
- **Line 173**: `Colors.blue.withOpacity(0.1)` for preview card
- **Line 246**: `backgroundColor: Colors.blue` - button background
- **Line 247**: `disabledBackgroundColor: Colors.grey` - disabled button

#### Expanded Token View Issues:
- **Lines 150, 583**: `Colors.grey.withOpacity(0.1)` - container backgrounds
- **Lines 160, 604**: `Colors.grey[600]` - label text
- **Line 634**: `Colors.grey` - placeholder text
- **Lines 390, 441, 468, 522, 681**: `Colors.blue.withOpacity(0.1)` - counter backgrounds
- **Line 356**: `Icon(Icons.add_circle, color: Colors.blue)` - add counter icon
- **Line 586**: `color: isEditing ? Colors.blue : Colors.transparent` - border color
- **Lines 667, 699**: Disabled icon colors using `Colors.grey`

#### Token Card Issues:
- **Line 128**: `Colors.blue.withOpacity(0.2)` - modified P/T background (highly visible on main screen)

### Semantic Color Handling

**Colors That Should REMAIN Hardcoded:**

These colors convey specific meaning and should NOT be changed to theme colors:

1. **ColorSelectionButton Widget** (`lib/widgets/color_selection_button.dart`):
   - **ENTIRE FILE EXEMPT** - Do not modify any colors in this file
   - Uses custom `Color(0xFFE8DDB5)` for White (not `Colors.yellow`)
   - Line 44: `Colors.grey.shade400` for unselected text - intentional game mechanic
   - Line 43: `Colors.white` for White symbol text - intentional
   - **Reason**: MTG color identity is game mechanics with precise color requirements
   - Widget already handles its own theming via opacity/lightness calculations

2. **ColorSelectionButton Usage** (expanded_token_screen.dart lines ~171-218):
   - **DO NOT MODIFY** the `color:` parameters passed to ColorSelectionButton instances
   - Lines include: `Colors.yellow`, `Colors.blue`, `Colors.purple`, `Colors.red`, `Colors.green`
   - **Reason**: These are parameters for the exempt ColorSelectionButton widget above
   - The widget handles these internally (e.g., White overrides yellow with custom beige)

3. **Counter Operation Icons** (add/remove buttons):
   - **Red** for decrement/remove operations (semantic: danger/subtract)
   - **Green** for increment/add operations (semantic: success/add)
   - **Reason**: Follow universal UI conventions - these colors communicate action meaning

3. **Delete Icon** (expanded_token_screen.dart line 90):
   - `Colors.red` for destructive delete action
   - **Reason**: Standard Material Design pattern for destructive operations

4. **Modified P/T Text** (expanded_token_screen.dart line 480):
   - `Colors.blue` text to indicate active counter modification
   - **Reason**: Could optionally use `Theme.of(context).colorScheme.primary` but blue is universally understood for "modified state"

**Colors That MUST Be Changed:**

All gray tones, neutral container backgrounds, disabled states, and non-semantic interactive highlights must use theme-aware colors to ensure:
- WCAG contrast compliance
- Dark mode support
- Theme consistency

### Recommended Fixes (Based on Token Card Patterns)

All fixes should follow the patterns already established in `token_card.dart`:

#### 1. Secondary Text (e.g., "Current amount: 5")
```dart
// ❌ Current
Text('Current amount: ${widget.item.amount}',
  style: const TextStyle(color: Colors.grey))

// ✅ Fix - use theme bodySmall
Text('Current amount: ${widget.item.amount}',
  style: Theme.of(context).textTheme.bodySmall)
```

#### 2. Label Text (e.g., "Colors", "Stats")
```dart
// ❌ Current
Text('Colors',
  style: TextStyle(fontSize: 12, color: Colors.grey[600]))

// ✅ Fix - use theme labelLarge with reduced opacity
Text('Colors',
  style: Theme.of(context).textTheme.labelLarge?.copyWith(
    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)
  ))
```

#### 3. Container Backgrounds
```dart
// ❌ Current
decoration: BoxDecoration(
  color: Colors.grey.withOpacity(0.1),
  borderRadius: BorderRadius.circular(12),
)

// ✅ Fix - use surfaceContainerHighest (Material 3)
decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.surfaceContainerHighest,
  borderRadius: BorderRadius.circular(12),
)
```

#### 4. Preview/Highlight Card Background
```dart
// ❌ Current
Card(
  color: Colors.blue.withOpacity(0.1),
  child: ...
)

// ✅ Fix - use primaryContainer
Card(
  color: Theme.of(context).colorScheme.primaryContainer,
  child: ...
)
```

#### 5. Disabled Icon Colors
```dart
// ❌ Current
color: _splitAmount > 1 ? Colors.blue : Colors.grey

// ✅ Fix - use primary color and theme disabled color
color: _splitAmount > 1
  ? Theme.of(context).colorScheme.primary
  : Theme.of(context).disabledColor
```

#### 6. Counter Display Backgrounds (Expanded Token View)
```dart
// ❌ Current
decoration: BoxDecoration(
  color: Colors.blue.withOpacity(0.1),
  borderRadius: BorderRadius.circular(4),
)

// ✅ Fix - use primaryContainer with reduced opacity
decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
  borderRadius: BorderRadius.circular(4),
)
```

#### 7. Button Colors
```dart
// ❌ Current (split_stack_sheet.dart:246-247)
ElevatedButton.styleFrom(
  backgroundColor: Colors.blue,
  disabledBackgroundColor: Colors.grey,
)

// ✅ Fix - use theme primary and disabled colors
ElevatedButton.styleFrom(
  backgroundColor: Theme.of(context).colorScheme.primary,
  disabledBackgroundColor: Theme.of(context).disabledColor,
)
```

#### 8. Action Icon Colors (Non-Semantic)
```dart
// ❌ Current (expanded_token_screen.dart:356)
Icon(Icons.add_circle, color: Colors.blue)

// ✅ Fix - use primary color
Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary)
```

#### 9. Border Colors
```dart
// ❌ Current (expanded_token_screen.dart:586)
border: Border.all(
  color: isEditing ? Colors.blue : Colors.transparent,
  width: 2,
)

// ✅ Fix - use primary for active state
border: Border.all(
  color: isEditing ? Theme.of(context).colorScheme.primary : Colors.transparent,
  width: 2,
)
```

#### 10. Modified P/T Background (Token Card)
```dart
// ❌ Current (token_card.dart:128)
decoration: BoxDecoration(
  color: Colors.blue.withOpacity(0.2),
  borderRadius: BorderRadius.circular(6),
)

// ✅ Fix - use primaryContainer with opacity for theme awareness
decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
  borderRadius: BorderRadius.circular(6),
)
```

### Implementation Plan

#### Order of Operations
Files can be edited **in parallel** for efficiency, then tested together:

1. **Phase 1 - Implementation** (Parallel):
   - Fix `lib/widgets/split_stack_sheet.dart` (13 changes)
   - Fix `lib/screens/expanded_token_screen.dart` (14 changes, excluding semantic colors)
   - Fix `lib/widgets/token_card.dart` (1 change)
   - **DO NOT TOUCH**: `lib/widgets/color_selection_button.dart` (entire file exempt)

2. **Phase 2 - Verification**:
   - Run automated contrast analysis
   - Manual visual testing in light mode
   - Manual visual testing in dark mode
   - Cross-reference with success criteria

#### Change Summary by File

**split_stack_sheet.dart** (13 changes):
- Lines 72, 76, 197, 201, 212, 216, 234: Secondary text → `Theme.of(context).textTheme.bodySmall` (7 instances)
- Line 97: Container background → `Theme.of(context).colorScheme.surfaceContainerHighest`
- Line 108: Icon color (decrement) → `Theme.of(context).colorScheme.primary` or `Theme.of(context).disabledColor`
- Line 137: Icon color (increment) → `Theme.of(context).colorScheme.primary` or `Theme.of(context).disabledColor`
- Line 173: Preview card → `Theme.of(context).colorScheme.primaryContainer`
- Line 246: Button background → `Theme.of(context).colorScheme.primary`
- Line 247: Disabled button → `Theme.of(context).disabledColor`

**expanded_token_screen.dart** (14 changes, excluding semantic colors):
- Line 150: Container background → `Theme.of(context).colorScheme.surfaceContainerHighest`
- Line 583: Container background (editing state) → `Theme.of(context).colorScheme.primaryContainer`
- Lines 160, 604: Label text → `Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7))` (2 instances)
- Line 634: Placeholder text → theme color with opacity
- Lines 390, 441, 468, 522, 681: Counter backgrounds → `Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)` (5 instances)
- Line 356: Icon color → `Theme.of(context).colorScheme.primary`
- Line 586: Border color → `Theme.of(context).colorScheme.primary`
- Lines 667, 699: Disabled icon gray → `Theme.of(context).disabledColor` (2 instances)
- **NOTE**: Lines ~171-218 ColorSelectionButton color parameters should NOT be modified (exempt)

**token_card.dart** (1 change):
- Line 128: Modified P/T background → `Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)`

**color_selection_button.dart** (0 changes):
- **ENTIRE FILE EXEMPT** - Do not modify any colors in this file

**Total: 28 changes across 3 files (1 file fully exempt)**

### Testing & Verification

#### Pre-Implementation Checklist
- [ ] Create test branch from `flutterMigration`
- [ ] Document current screenshots (light + dark mode) for before/after comparison
- [ ] Note specific areas where contrast is currently poor

#### Automated Contrast Analysis

After implementation, use this analysis approach:

1. **Screenshot Capture**:
   - Light mode: Split Stack sheet, Expanded Token screen, Token Card with counters
   - Dark mode: Same screens

2. **Contrast Verification** (using browser DevTools or online checker):
   - **Target**: 4.5:1 for text, 3:1 for UI components (WCAG AA)
   - **Test combinations**:
     - Secondary text (bodySmall) vs card background
     - Label text (0.7 opacity) vs container background
     - Container (`surfaceContainerHighest`) vs card background
     - Disabled icon (`disabledColor`) vs background
     - Preview card (`primaryContainer`) text vs background
     - Counter backgrounds (`primaryContainer` 0.5 opacity) vs card background

3. **Color Extraction Method**:
   - Use screenshot color picker to get exact RGB values
   - Calculate contrast ratios: https://webaim.org/resources/contrastchecker/
   - Document any failures for manual adjustment

#### Manual Visual Testing

1. **Light Mode Testing**:
   - Open app in light mode
   - Navigate to Split Stack sheet
     - Verify all gray text is now readable (no washed out appearance)
     - Check container backgrounds have subtle but visible distinction
     - Test disabled button state (should be clearly disabled but visible)
   - Navigate to Expanded Token View
     - Click editable fields - verify highlight color is appropriate
     - Check counter displays are clearly visible
     - Verify label text is readable but secondary
   - View Token Card with counters on main screen
     - Verify modified P/T background is clearly visible but not overwhelming

2. **Dark Mode Testing**:
   - Switch system to dark mode (or use app theme toggle if available)
   - Repeat all light mode tests
   - **Critical checks**:
     - Verify no "invisible" gray text on dark backgrounds
     - Check no overly bright/glowing elements
     - Confirm `primaryContainer` provides sufficient contrast
     - Verify text doesn't disappear into container backgrounds

3. **Interactive State Testing**:
   - Split Stack: Increment/decrement split amount - verify disabled states are clear
   - Expanded Token: Edit name field - verify blue border changes to theme color
   - Counter buttons: Test disabled states (e.g., decrement at 0)
   - Preview card: Verify content is clearly readable

#### Success Criteria

After implementation and testing, all of the following must be true:

- ✅ **WCAG Compliance**: All text meets 4.5:1 contrast ratio, all UI components meet 3:1
- ✅ **No Hardcoded Neutrals**: No instances of `Colors.grey` or `Colors.blue` except semantic colors documented above
- ✅ **Dark Mode Perfect**: All screens fully functional and readable in dark mode with no visual glitches
- ✅ **Pattern Consistency**: All changes follow established Material 3 patterns (`surfaceContainerHighest`, `primaryContainer`, etc.)
- ✅ **Visual Clarity**: All interactive states (disabled, editing, highlighted) are clearly distinguishable
- ✅ **No Regressions**: Token Card, Split Stack, and Expanded Token View maintain intended visual hierarchy

#### Visual Testing Report Template

After manual testing, report findings:

```
**Light Mode:**
- Split Stack Sheet: [PASS/FAIL] - Notes:
- Expanded Token View: [PASS/FAIL] - Notes:
- Token Card: [PASS/FAIL] - Notes:

**Dark Mode:**
- Split Stack Sheet: [PASS/FAIL] - Notes:
- Expanded Token View: [PASS/FAIL] - Notes:
- Token Card: [PASS/FAIL] - Notes:

**Contrast Analysis:**
- Minimum text contrast achieved: [ratio]
- Minimum component contrast achieved: [ratio]
- Any failures: [list]

**Decision:** [SHIP / NEEDS ADJUSTMENT]
```

### Known Limitations

1. **Material 3 Required**:
   - This fix assumes app uses Material 3 (`useMaterial3: true` in ThemeData)
   - `surfaceContainerHighest` requires Material 3
   - **Fallback**: If using Material 2, replace `surfaceContainerHighest` with `surfaceVariant`
   - **Verification**: Check `main.dart` ThemeData configuration before implementation

2. **Semantic Color Decisions Are Subjective**:
   - Decision to keep red/green for increment/decrement is a UX choice
   - Alternative approach: use `colorScheme.error` and `colorScheme.tertiary`
   - Current approach follows Material Design guidelines and universal conventions
   - Can be revisited in future if user feedback suggests otherwise

3. **Modified P/T Text Color** (expanded_token_screen.dart:480):
   - Currently remains `Colors.blue` as documented in semantic colors
   - Could optionally change to `Theme.of(context).colorScheme.primary` for full theme awareness
   - Deferred to post-implementation review based on visual testing

4. **Opacity Values May Need Tuning**:
   - Used 0.5 for `primaryContainer` backgrounds to ensure visibility
   - Used 0.7 for label text opacity
   - These values may need adjustment based on specific theme configurations
   - Visual testing will determine if adjustments needed

### Expected Outcomes

After successful implementation and verification:

- ✅ **WCAG AA Compliance**: All text achieves 4.5:1 contrast ratio, all UI components achieve 3:1
- ✅ **Theme Consistency**: All three files use consistent Material 3 design tokens
- ✅ **Dark Mode Excellence**: Perfect rendering in dark mode with no contrast failures or visibility issues
- ✅ **Pattern Alignment**: All changes follow established patterns from token_card.dart
- ✅ **Semantic Clarity**: Action colors (red/green) and game colors (WUBRG) remain meaningful
- ✅ **Zero Hardcoded Neutrals**: No `Colors.grey` or `Colors.blue` except documented semantic cases
- ✅ **Maintainable**: Future theme changes automatically propagate to all fixed components

### Implementation Readiness

**Current Status: 95%+ Ready for Autonomous Implementation**

**Remaining Pre-Implementation Verification:**
1. Confirm Material 3 enabled in `main.dart` (check `useMaterial3: true` in ThemeData)
2. Create test branch and capture baseline screenshots
3. Review semantic color policy and confirm approach

**After implementation is complete, user will:**
1. Run automated contrast analysis on screenshots
2. Perform manual visual testing in both light and dark modes
3. Complete Visual Testing Report Template
4. Make final ship/adjust decision

---

## Completed Features

Token List Reordering feature has been completed and implemented.
