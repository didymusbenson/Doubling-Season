# Doubling Season

Magic: The Gathering token tracker for iOS and Android.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed
- Xcode (for iOS development)
- Android Studio or Android SDK (for Android development)

## Build & Run

### Install Dependencies
```bash
flutter pub get
```

### iOS Simulator
```bash
# Open iOS simulator
open -a Simulator

# Run the app
flutter run
```

Or open in Xcode:
```bash
open ios/Runner.xcworkspace
```
Then press `Cmd+R` to build and run.

### Android Emulator
```bash
# List available devices
flutter devices

# Run on Android
flutter run
```

### Development Tips
```bash
# Hot reload - press 'r' in terminal while app is running
# Hot restart - press 'R'
# Quit - press 'q'

# Run with device selection
flutter run -d <device-id>

# Run in release mode
flutter run --release
```

## App Store Release Preparation

### 1. Update Version and Build Number

Edit `pubspec.yaml`:
```yaml
version: 1.0.0+1  # Format: version+build_number
```

The version number (e.g., `1.0.0`) is what users see. The build number (e.g., `1`) must be unique and increment for each upload to App Store Connect.

### 2. Configure App Icons

Place your app icon in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`. Ensure you have all required sizes:
- 1024x1024 (App Store)
- 180x180 (iPhone 3x)
- 120x120 (iPhone 2x)
- 167x167 (iPad Pro)
- 152x152 (iPad 2x)
- 76x76 (iPad 1x)

Or use a tool like [App Icon Generator](https://www.appicon.co/) to generate all sizes.

### 3. Review iOS Configuration

Open `ios/Runner.xcworkspace` in Xcode and verify:

**General Tab:**
- Display Name
- Bundle Identifier (must match App Store Connect)
- Version matches pubspec.yaml
- Build number matches pubspec.yaml
- Deployment Target (minimum iOS version)

**Signing & Capabilities Tab:**
- Team is selected
- Automatically manage signing is enabled (or manual provisioning profile is configured)
- Certificate is valid and not expired

**Info Tab:**
- Privacy usage descriptions (if needed):
  - NSPhotoLibraryUsageDescription
  - NSCameraUsageDescription
  - etc.

### 4. Build Release Archive

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build iOS release (creates .app bundle)
flutter build ios --release

# Or build archive for App Store submission
flutter build ipa
```

The `.ipa` file will be created in `build/ios/ipa/`.

### 5. Upload to App Store Connect

**Option A: Using Xcode (Traditional Method)**

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device (arm64)" as the target
3. Go to **Product > Archive**
4. Once archiving completes, the Organizer window opens
5. Select your archive and click **Distribute App**
6. Choose **App Store Connect**
7. Choose **Upload**
8. Select signing options (automatic or manual)
9. Review and click **Upload**

**Option B: Using Command Line**

```bash
# Build the IPA
flutter build ipa

# Upload using Transporter app or xcrun
xcrun altool --upload-app \
  --type ios \
  --file build/ios/ipa/*.ipa \
  --username "your-apple-id@email.com" \
  --password "app-specific-password"
```

**Option C: Using Transporter App**

1. Open the Transporter app (download from Mac App Store)
2. Drag and drop the `.ipa` file from `build/ios/ipa/`
3. Click **Deliver**

### 6. Post-Upload Steps

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app
3. Wait for the build to process (5-30 minutes)
4. Once processed, it will appear in **TestFlight** builds
5. Select the build for your new version
6. Complete App Store metadata if needed
7. Submit for review

### Common Release Checklist

- [ ] Version and build number incremented in `pubspec.yaml`
- [ ] App icons are present and correct sizes
- [ ] Bundle identifier matches App Store Connect
- [ ] Signing certificate is valid
- [ ] Privacy descriptions added to Info.plist (if needed)
- [ ] Tested in release mode: `flutter run --release`
- [ ] Build archive successful: `flutter build ipa`
- [ ] Uploaded to App Store Connect
- [ ] Build processed and appears in TestFlight
- [ ] TestFlight testing completed (optional)
- [ ] Submitted for App Review

### Troubleshooting

**Signing Issues:**
```bash
# Open Xcode to resolve signing
open ios/Runner.xcworkspace
# Go to Signing & Capabilities, reselect team
```

**Build Fails:**
```bash
# Clean and rebuild
flutter clean
cd ios
rm -rf Pods/ Podfile.lock
pod install
cd ..
flutter pub get
flutter build ipa
```

**Version Already Exists:**
- Increment the build number in `pubspec.yaml` (e.g., `1.0.0+2`)

## Project Structure

- `lib/` - Dart source code
- `assets/` - Images and resources
- `pubspec.yaml` - Dependencies and configuration
