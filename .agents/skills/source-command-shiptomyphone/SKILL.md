---
name: "source-command-shiptomyphone"
description: "Build iOS release and permanently install it on connected iPhone"
---

# source-command-shiptomyphone

Use this skill when the user asks to run the migrated source command `shiptomyphone`.

## Command Template

Build and permanently install the app on a connected iPhone for testing.

**CRITICAL: Understanding "Install" vs "Run"**
- **`flutter install`**: Permanently installs the app on the device. App remains on home screen after disconnecting. This is what we use.
- **`flutter run`**: Launches app temporarily while connected. App disappears when the session ends. Do NOT use for this command.

**Process:**
1. Run `flutter devices` to verify iPhone is connected
2. Run `flutter clean` to clear build cache
3. Run `flutter build ios --release` to build the release version
4. Run `flutter install -d 00008150-000544E41E91401C` to permanently install on didym's iPhone
5. If `flutter install` fails with connection errors, tell the user to check their iPhone home screen - the app often installs successfully despite the error message

**Device ID:** `00008150-000544E41E91401C` (didym's iPhone)

**Expected Output:**
- App is permanently installed on the iPhone
- App icon appears on the home screen
- App remains after disconnecting from Mac

**Important Notes:**
- iPhone must be connected via USB or WiFi (USB is more reliable)
- Device must be trusted on the Mac
- App uses automatically managed signing with team `84W8Q8DV3S`
- User should delete existing app from iPhone first for cleanest installation
- Wireless connection can have issues - recommend USB cable if problems occur
- The app will persist on the device after disconnecting (unlike `flutter run`)

**Troubleshooting:**
- If device not found: Check USB connection or WiFi pairing
- If signing fails: Open `ios/Runner.xcworkspace` in Xcode and verify team is selected
- If `flutter install` reports connection errors: Do NOT retry - just tell the user to check their iPhone home screen, as the app usually installs successfully despite the error
- If app already exists: Delete from iPhone first, then reinstall
