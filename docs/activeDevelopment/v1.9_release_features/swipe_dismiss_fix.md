# Swipe Dismiss Red Background Fix

**Status:** Resolved
**Date Fixed:** December 2025
**Verified:** March 22, 2026

## Issue

Corners flashed non-red on utility cards (TrackerWidget, ToggleWidget) when swiping to dismiss. TokenCard showed red correctly during swipe.

## Root Cause

Utility card base layers used opaque `Theme.of(context).cardColor`, which blocked the red `AnimatedContainer` behind them from showing through at the corners.

## Fix Applied

- Changed base layer in `TrackerWidgetCard` and `ToggleWidgetCard` from `cardColor` to `Colors.transparent`
- Added `Opacity` wrapper to both utility card types (matching TokenCard pattern)

## Files Changed

- `lib/widgets/tracker_widget_card.dart` — transparent base layer + Opacity wrapper
- `lib/widgets/toggle_widget_card.dart` — transparent base layer + Opacity wrapper
