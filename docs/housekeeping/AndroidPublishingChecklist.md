# Android Publishing Checklist

Track your progress getting set up as an Android developer and publishing Doubling Season to Google Play.

## Google Play Console Setup

- [x] Create Google Play Developer account at [play.google.com/console](https://play.google.com/console)
  - [x] Pay $25 USD one-time registration fee
  - [x] Phone number verification (completed with physical Android device)
  - [ ] **WAITING: Account verification to complete (in progress)**
- [x] Verify identity with government-issued ID (completed)
- [x] Set up payment profile (existing Google Payments profile linked)
- [x] Set up physical Android device for testing

## App Signing Setup

- [x] Generate upload keystore
  - [x] Store keystore password in secure location (password manager)
  - [x] Note the alias used ("upload")
  - [x] **BACKUP THE KEYSTORE FILE** (backed up in 2 locations)

- [x] Configure signing in Flutter project
  - [x] Create `android/key.properties` file (created and gitignored)
  - [x] Update `android/app/build.gradle.kts` with signing config
  - [x] Test that signing works: ✓ Successfully built `app-release.aab`

- [ ] Enable Google Play App Signing in Play Console (do this when creating app)

## Store Assets Preparation

- [ ] App icon (512x512 PNG)
- [ ] Feature graphic (1024x500 PNG)
- [ ] Screenshots (2-8 per device type):
  - [ ] Phone screenshots
  - [ ] 7" tablet screenshots (optional)
  - [ ] 10" tablet screenshots (optional)
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] Privacy policy URL (required - host on GitHub Pages or website)

## App Listing Requirements

- [ ] Complete content rating questionnaire (IARC classification)
- [ ] Declare target audience
- [ ] Complete app content declarations
- [ ] Set up app categories and tags
- [ ] Add contact email and website

## Data Safety Declarations

- [ ] Complete Data Safety form in Play Console:
  - **Data Collection**: NO (app does not collect user data)
  - **Data Sharing**: NO (no data shared with third parties)
  - **Network Usage**: YES (downloads token artwork from Scryfall API)
    - Purpose: App functionality (artwork display)
    - Data type: Public artwork images
    - Storage: Cached locally on device
  - **Security Practices**:
    - Data is encrypted in transit (HTTPS)
    - No user data stored or transmitted
    - Artwork downloads are optional (app works offline)

- [ ] Verify required permissions:
  - `INTERNET` permission in `AndroidManifest.xml` (required for artwork downloads)

## Build Configuration

- [ ] Verify bundle identifier in `android/app/build.gradle.kts`:
  - Application ID: `LooseTie.DoublingSeason`
  - Namespace: `LooseTie.DoublingSeason`
- [ ] Set appropriate version in `pubspec.yaml`:
  - Format: `version: 1.0.0+1` (version+build number)
- [ ] Verify `minSdkVersion` and `targetSdkVersion` in `android/app/build.gradle.kts`
- [ ] Test on physical Android device

## Build and Upload

- [ ] Build release app bundle:
  ```bash
  flutter build appbundle --release
  ```
- [ ] Verify output: `build/app/outputs/bundle/release/app-release.aab`

- [ ] Create app in Google Play Console
- [ ] Upload `.aab` file to **internal testing** track first
- [ ] Complete all required store listing fields
- [ ] Add internal testers (yourself at minimum)
- [ ] Test the internal release thoroughly

- [ ] Promote to **closed testing** (optional)
- [ ] Submit to **production** track
- [ ] Wait for review (typically 1-3 days)

## Post-Launch

- [ ] Monitor crash reports in Play Console
- [ ] Respond to user reviews
- [ ] Track app performance metrics
- [ ] Plan update cadence

## Notes

**Key Differences from iOS:**
- Uses `.aab` (Android App Bundle) instead of `.apk`
- Review process is typically faster (1-3 days vs 1-2 weeks)
- Less strict review guidelines than Apple
- No need for App Transporter equivalent - direct web upload

**App Version Management:**
- Version name (user-facing): `1.0.0` in `pubspec.yaml`
- Version code (internal): Build number in `pubspec.yaml` (e.g., `1.0.0+1`)
- Both increment with each release
- Google Play enforces strict version code increments

**Useful Commands:**
```bash
# Build app bundle (for Play Store)
flutter build appbundle --release

# Build APK (for direct distribution/testing)
flutter build apk --release

# Install on connected device
flutter install
```
