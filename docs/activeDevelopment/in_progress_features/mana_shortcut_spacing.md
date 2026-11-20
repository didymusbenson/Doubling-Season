# Mana shortcut spacing

The shared custom tablet keyboard now separates the 16 mana shortcut keys with
6px external gaps, 12px breaks at WUBRG / generic / Tap, and 12px end insets.
The 44px hit targets, 24px glyphs, shortcut order, and keyboard height are
unchanged. The 830px row centers when it fits and shows a horizontal scrollbar
below that width. Native and numeric-only paths are unchanged.

Validated with 43 focused regression tests on Flutter 3.41.2. The new tests
measure the 720px modal cap and full-width tablet layouts at 1133×744 and
744×1133, traverse all keys with Tab, and check that Tap is visible, labeled,
and inserts its symbol. Four configurations rendered using the Flutter test
renderer. Native installation/acceptance is not part of this checkpoint.
