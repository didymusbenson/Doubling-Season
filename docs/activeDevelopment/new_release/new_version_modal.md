# What's New Modal

## Overview

A one-time dismissable modal that appears on app launch after updating to a new version. Shows version-specific release notes. Once dismissed, it never shows again for that version. Also accessible on-demand from the About screen.

## Core Behavior

- On launch, compare the current app version to the last-dismissed version stored in SharedPreferences
- If they differ (or no stored version exists), show the modal automatically
- On dismiss, store the current version string so the modal won't reappear
- The modal is a standard `showDialog` AlertDialog, consistent with existing dialog patterns

## Persistence

**Storage:** SharedPreferences (via `SettingsProvider`)
- New key: `lastDismissedWhatsNewVersion` (String, nullable)
- On launch: get current version from `PackageInfo.fromPlatform()` (`package_info_plus`, already a dependency)
- Compare `packageInfo.version` to the stored value
- On dismiss: write `packageInfo.version` to the key

No Hive involvement — this is simple key-value state, fits naturally in SharedPreferences alongside existing settings.

## Modal Design

- **Title:** "What's New in [version]" (e.g., "What's New in 1.9.0")
- **Body:** Version-specific content rendered from a static map
- **Dismiss button:** Single "Got it" or "OK" TextButton
- Uses `showDialog()` with `AlertDialog`, matching existing patterns in the codebase (see `_clearArtworkCache` confirmation dialog in about_screen.dart for reference)

## Content Management

A static `Map<String, String>` (or `Map<String, Widget>` if rich content is needed) stored in a dedicated file, e.g., `lib/utils/whats_new_content.dart`:

```dart
const Map<String, String> whatsNewContent = {
  '1.9.0': 'New feature highlights for 1.9.0...',
  '1.8.0': 'New feature highlights for 1.8.0...',
};
```

Only the entry matching the current version is displayed. If no entry exists for the current version, the modal is not shown (graceful fallback for minor patches without notable changes).

## About Screen Integration

**File:** `lib/screens/about_screen.dart`

Add a "What's New" button to the About screen, placed between the version text and the first Card (the "About" description card). Uses `OutlinedButton.icon` to match the existing "View Open Source Licenses" button style at the bottom of the screen.

Tapping it shows the same modal content unconditionally — it does not check or update the dismissed version. This lets users revisit release notes anytime.

If there is no whats-new entry for the current version, the button should either be hidden or show a fallback message like "No release notes for this version."

## Launch Integration

The version check and modal trigger should run in `main.dart` after the app is fully initialized and the first frame is rendered. Use `WidgetsBinding.instance.addPostFrameCallback` or similar to avoid blocking app startup. The check runs after Hive init and Provider setup are complete.

Flow:
1. App boots normally (Hive init, Provider setup, first frame)
2. Post-frame callback reads SharedPreferences for `lastDismissedWhatsNewVersion`
3. Gets current version from `PackageInfo.fromPlatform()`
4. If versions differ and content exists for current version, show modal
5. On dismiss, write current version to SharedPreferences

## Implementation Steps

### 1. Content Map (`lib/utils/whats_new_content.dart`)
- Create file with `whatsNewContent` map
- Add entry for the current version

### 2. Modal Helper Function
- Create a reusable function (e.g., `showWhatsNewDialog(BuildContext context)`) that:
  - Gets current version from `PackageInfo.fromPlatform()`
  - Looks up content from the map
  - Shows an `AlertDialog` with the content
  - Returns whether it was shown (for the launch flow to know whether to store dismissal)

### 3. SettingsProvider Changes (`lib/providers/settings_provider.dart`)
- Add getter/setter for `lastDismissedWhatsNewVersion`
- `String? get lastDismissedWhatsNewVersion`
- `Future<void> setLastDismissedWhatsNewVersion(String version)`

### 4. Launch Check (`lib/main.dart`)
- After app initialization, add post-frame callback
- Compare versions, show modal if needed, store dismissal on close

### 5. About Screen Button (`lib/screens/about_screen.dart`)
- Add "What's New" `OutlinedButton.icon` with `Icons.new_releases` icon
- On tap, call the same modal helper function (no dismissal tracking)

## Edge Cases

- **No content for current version:** Do not show modal on launch. Hide or disable the About screen button.
- **First install (no stored version):** Show the modal — new users see what the current version offers.
- **Downgrade:** Version string will differ, so the modal shows if content exists for the "new" (actually older) version. Acceptable behavior.
- **Version string format:** Compare full version string (e.g., "1.9.0"), not build number. Build number bumps without version changes should not re-trigger the modal.
