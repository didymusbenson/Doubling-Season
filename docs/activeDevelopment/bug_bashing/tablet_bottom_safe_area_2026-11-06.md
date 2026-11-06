# iOS fullscreen table bottom gap (2026-11-06)

## Report and diagnosis

The user reported a blank bottom bar in installed iPad build 13 (08956a8),
matching the former system-bar space. The table's outer SafeArea still consumes
bottom padding after GameSystemUi requests hidden system chrome. iOS can retain
the home-indicator safe-area inset while the indicator is hidden. This provides
a code-level explanation for the gap; the reported device is not available for
native reproduction or acceptance.

## Fix

GameSystemUi consumes bottom padding and viewPadding only for the active native
iOS table subtree. Top/side cutout padding and keyboard viewInsets are preserved.
Android, web, desktop, startup and overlay routes keep their own platform insets.
Lifecycle changes restore/reapply the inset policy without remounting the game.

## Validation

- flutter test test/game_system_ui_test.dart: 9 passed.
- flutter analyze lib/ui/game_system_ui.dart test/game_system_ui_test.dart: clean.
- git diff --check: clean.
- Regression asserts SafeArea extends to the bottom, retains top/side padding,
  preserves keyboard occlusion, restores padding while inactive and removes it
  on resume without replacing the table element.
- Existing system-bar lifecycle and Android keyboard-delay tests still pass.
- Physical iPad visual/functional acceptance remains pending. No installation
  or distribution was performed for this scoped fix.
