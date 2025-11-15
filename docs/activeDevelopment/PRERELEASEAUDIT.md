# Version 1.1.1

## STATUS

TEST FLIGHT: PENDING
TEST TRACK: LIVE

## GOOGLE PLAY DATA SAFETY DECLARATIONS

### Network Usage (New in v1.1.1)
- [x] Update Data Safety section in Google Play Console
  - App now downloads artwork from Scryfall API (api.scryfall.com)
  - Downloads are cached locally on device
  - No user data is collected or transmitted

### Data Collection
- [x] Confirm: **NO** user data collection
  - App does not track which artwork users download
  - App does not collect analytics, search queries, or usage data
  - All data stored locally (Hive database, SharedPreferences, cached artwork)

### Data Sharing
- [x] Confirm: **NO** data sharing with third parties
  - Scryfall receives standard HTTP requests for artwork URLs
  - No personal or identifiable information transmitted

### Required Permissions
- [x] Verify `INTERNET` permission in `android/app/src/main/AndroidManifest.xml`
  - Required for downloading token artwork from Scryfall
  - Users can use app offline (artwork downloads optional)

### Privacy Policy
- [x] Consider adding privacy policy URL to Play Store listing
  - State: No user data collected
  - Explain: Artwork downloaded from Scryfall API (public data)
  - Explain: Artwork cached locally for offline use
  - Not strictly required for this app, but good practice

## APP STORE CONNECT PRIVACY DECLARATIONS

### App Privacy Section (New in v1.1.1)
- [x] Verify "Data Collection" is set to **NO**
  - App downloads public artwork from Scryfall API
  - No user data collected, stored, or transmitted
  - All data stored locally (Hive database, SharedPreferences, cached artwork)

- [x] Verify all Data Types are **NO**:
  - Contact Info, Location, Identifiers, Usage Data, etc.
  - App does not track users or collect personal information

- [x] Third-Party SDKs:
  - Scryfall API receives standard HTTP requests for artwork URLs
  - No personal or identifiable information transmitted

### Info.plist Permissions
- [x] No new permissions required
  - iOS apps have internet access by default (no declaration needed)
  - No camera, location, photo library, or other sensitive permissions used

### Privacy Policy URL
- [x] **NOT REQUIRED** for App Store Connect
  - Apple does not require privacy policy if no data is collected
  - Optional: Add for transparency and consistency with Google Play

