---
name: "source-command-shipfortestflight"
description: "Auto-increment version, build IPA, and prepare for TestFlight upload"
---

# source-command-shipfortestflight

Use this skill when the user asks to run the migrated source command `shipfortestflight`.

## Command Template

Build and prepare an IPA for TestFlight upload with automatic version incrementing.

**Process:**
1. Read current version from `pubspec.yaml` (format: `MAJOR.MINOR.PATCH+BUILD`)
2. Auto-increment the patch version (e.g., 1.0.3 → 1.0.4)
3. Reset the build number to 1 (e.g., +5 → +1)
4. Update `pubspec.yaml` with the new version
5. Run `flutter clean` to clear build cache
6. Run `flutter build ipa --release` to build the IPA
7. Open Finder to the IPA location: `build/ios/ipa/`
8. Open Apple Transporter app for drag-and-drop upload

**Expected Output:**
- IPA file location: `build/ios/ipa/Doubling Season.ipa`
- The IPA is ready to drag into Apple Transporter for TestFlight submission

**Important Notes:**
- This increments the PATCH version (third number), not MAJOR or MINOR
- Build number is RESET to 1 when version increments
- Build number only increments for multiple builds of the same version
- Ensure you have Apple Transporter installed (`/Applications/Transporter.app`)
- After upload to TestFlight, remember to add release notes in App Store Connect
- Version format in pubspec.yaml: `version: MAJOR.MINOR.PATCH+BUILD`
- The build process can take several minutes

**Post-Upload Steps:**
1. Open App Store Connect (https://appstoreconnect.apple.com)
2. Navigate to TestFlight tab
3. Wait for processing (usually 10-30 minutes)
4. Add release notes and submit for beta review
