# Quick Create FAB for Token Search

## Overview
Adding a dedicated FAB (Floating Action Button) next to the menu button for quick access to token search without opening the menu.

## User Feedback
Users requested easier access to token creation. Initial attempts with buttons in the scrollable list proved complex due to reordering conflicts. A dedicated FAB is a simpler, more intuitive solution.

## Design Specifications

### Layout
Bottom bar arrangement (left to right):
- **Multiplier View** (bottom-left, fixed)
- **Space** (flexible gap)
- **"+" FAB** (bottom-right area, opens TokenSearchScreen)
- **Menu FAB** (bottom-right, opens action menu)

Visual: `[Multiplier][space][+][Menu]`

### Implementation Details

#### Location
`lib/screens/content_screen.dart` - Modify the Stack's positioned widgets

#### Changes Made
1. Wrapped existing FloatingActionMenu in a Row with new FAB:
```dart
Positioned(
  bottom: UIConstants.standardPadding,
  right: UIConstants.standardPadding,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FloatingActionButton(
        heroTag: 'new_token_fab',
        onPressed: _showTokenSearch,
        child: const Icon(Icons.add, size: 28),
      ),
      const SizedBox(width: UIConstants.smallPadding),
      FloatingActionMenu(...),
    ],
  ),
)
```

### Behavior
- **"+" FAB**: Opens TokenSearchScreen directly (search and create tokens from database)
- **Menu FAB**: Opens FloatingActionMenu (custom tokens, board updates, deck management)
- **Always visible**: FABs remain on screen regardless of token count
- **No reordering conflicts**: FABs are fixed overlays, not part of list

### Benefits Over List Button Approach
1. **Simpler implementation**: No ReorderableListView conflicts
2. **Always accessible**: Users don't need to scroll to access
3. **Familiar pattern**: FABs are standard UI for primary actions
4. **No edge cases**: No empty state handling, no dragging artifacts
5. **Better UX**: Fixed position makes it more discoverable

### Navigation Pattern
- Opens TokenSearchScreen as fullscreen dialog using `Navigator.push()`
- Reuses existing `_showTokenSearch()` method
- Consistent with existing navigation patterns
- Menu still provides access to custom token creation via NewTokenSheet

## Testing Checklist
- [ ] "+" FAB opens TokenSearchScreen
- [ ] Menu FAB still opens action menu
- [ ] Menu "New Token" option also opens TokenSearchScreen (duplicate access is okay)
- [ ] FABs positioned correctly (side by side, bottom-right)
- [ ] Spacing between FABs looks clean
- [ ] No overlap with MultiplierView
- [ ] Works in both light and dark mode
- [ ] Hero tags prevent animation conflicts
