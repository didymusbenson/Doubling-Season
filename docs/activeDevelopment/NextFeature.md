# Quick Create Buttons at Bottom of Token List

## Overview
Adding two quick-access buttons at the bottom of the token list to streamline token creation without opening the floating action menu.

## User Feedback
Users requested easier access to token creation, specifically wanting buttons directly in the token list view for faster workflow.

## Design Specifications

### Button Layout
- **Position**: At the end of the scrollable token list (not fixed position)
- **Count**: Two buttons in a horizontal row
- **Labels**: "+ New" and "+ Custom"
- **Styling**: Similar to TokenCard buttons with matching borders/colors
- **Width**: Centered with padding (not full-width)
- **Visual Layer**: Same layer as token cards, scrolls with list content

### Behavior
- **+ New Button**: Opens TokenSearchScreen directly
- **+ Custom Button**: Opens NewTokenSheet directly
- **Empty State**: Buttons do NOT appear when token list is empty (existing empty state card remains)
- **Visibility**: Only visible when at least one token exists on the board
- **Reordering**: Buttons are NOT part of the reorderable list - tokens cannot be dragged "under" these buttons

### Implementation Details

#### Location
`lib/screens/content_screen.dart` - Modify `_buildTokenList()` method

#### Approach
1. Change `ReorderableListView.builder` itemCount to `items.length + 1`
2. Add conditional logic in `itemBuilder`:
   - If `index < items.length` ’ render TokenCard
   - If `index == items.length` ’ render button row widget
3. Handle reorder logic to ignore the button row index
4. Create new widget `_QuickCreateButtons` for the button row

#### Button Row Widget Structure
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _QuickCreateButton(
      label: "+ New",
      onTap: () => _showTokenSearch(),
    ),
    SizedBox(width: standard spacing),
    _QuickCreateButton(
      label: "+ Custom",
      onTap: () => _showNewTokenSheet(),
    ),
  ],
)
```

#### Styling Consistency
- Use `Theme.of(context).cardColor` for background
- Use `BorderRadius.circular(UIConstants.borderRadius)`
- Add subtle border or elevation to match token cards
- Maintain standard padding/spacing constants

### Navigation Pattern
- Both buttons close themselves and navigate using `Navigator.push()`
- No new methods needed - reuse existing `_showTokenSearch()`
- Add new method `_showNewTokenSheet()` to navigate to NewTokenSheet

### Layout Relationships
- **MultiplierView**: Remains fixed at bottom-left (different layer, no conflict)
- **FloatingActionMenu**: Remains fixed at bottom-right (different layer, no conflict)
- **Buttons**: Scroll with content, positioned logically after last token

### Considerations
- After token creation, user may need to scroll down to see buttons again (acceptable UX)
- Buttons only appear when scrolling to end of list (natural discovery pattern)
- No sheet closing conflicts - standard navigation flow

## Testing Checklist
- [ ] Buttons appear when 1+ tokens exist
- [ ] Buttons hidden on empty board
- [ ] "+ New" opens TokenSearchScreen
- [ ] "+ Custom" opens NewTokenSheet
- [ ] Tokens can be reordered without affecting button position
- [ ] Buttons cannot have tokens dragged below them
- [ ] Styling matches existing token cards
- [ ] Works in both light and dark mode
- [ ] No layout conflicts with MultiplierView/FloatingActionMenu
