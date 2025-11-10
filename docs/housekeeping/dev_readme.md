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

### Android Studio / Android Emulator

#### First-Time Android Setup

1. **Install Android SDK Command-line Tools** (required for Flutter):
   - Open Android Studio
   - Go to **Settings/Preferences > Appearance & Behavior > System Settings > Android SDK**
   - Select the **SDK Tools** tab
   - Check **Android SDK Command-line Tools (latest)**
   - Click **Apply** and let it install

2. **Accept Android Licenses**:
   ```bash
   flutter doctor --android-licenses
   # Type 'y' to accept all licenses
   ```

3. **Verify Setup**:
   ```bash
   flutter doctor
   # Should show all green checkmarks for Android toolchain
   ```

#### Running on Android Emulator

```bash
# List available emulators
flutter emulators

# Launch the Android emulator
flutter emulators --launch Medium_Phone_API_36.1

# Or create a new emulator with a custom name
flutter emulators --create --name my_emulator

# Once emulator is running, start the app
flutter run

# Or specify the device explicitly
flutter run -d emulator-5554
```

#### Running in Android Studio

1. Open Android Studio
2. Click **Open** and select the `Doubling Season` project folder
3. Wait for Gradle sync to complete
4. Click the device dropdown in the toolbar and select an emulator (or click **Device Manager** to create one)
5. Click the green **Run** button (▶️) or press `Shift+F10`

#### Android Build Commands

```bash
# Build APK for testing
flutter build apk

# Build app bundle for Play Store release
flutter build appbundle

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Install APK on connected device
flutter install
```

APK files are created in `build/app/outputs/flutter-apk/`
App bundles are created in `build/app/outputs/bundle/release/`

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

## Release Preparation

## iOS App Store Release

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

## Android Play Store Release

### 1. Update Version and Build Number

Edit `pubspec.yaml`:
```yaml
version: 1.0.0+1  # Format: version+build_number
```

The version number (e.g., `1.0.0`) is what users see. The build number (e.g., `1`) must increment for each upload to Google Play Console.

### 2. Configure App Icons

Android app icons are typically placed in `android/app/src/main/res/`. Flutter can generate these automatically:

```bash
# Using flutter_launcher_icons package
flutter pub add dev:flutter_launcher_icons
```

Add to `pubspec.yaml`:
```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/icon.png"  # Your 1024x1024 icon
```

Then run:
```bash
flutter pub run flutter_launcher_icons
```

### 3. Configure Signing Key

Create a keystore (one-time setup):
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=/Users/YourUsername/upload-keystore.jks
```

**Important:** Add `android/key.properties` to `.gitignore`

Verify `android/app/build.gradle` has signing configuration:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 4. Review Android Configuration

Edit `android/app/build.gradle`:
- `applicationId` - Must match Google Play Console
- `minSdkVersion` - Minimum Android version (21+ recommended)
- `targetSdkVersion` - Latest stable Android API level
- `versionCode` and `versionName` should match `pubspec.yaml`

Edit `android/app/src/main/AndroidManifest.xml`:
- `android:label` - App name
- Add required permissions (internet, etc.)

### 5. Build Release Bundle

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build app bundle (recommended for Play Store)
flutter build appbundle --release

# Or build APK
flutter build apk --release
```

The `.aab` file will be created in `build/app/outputs/bundle/release/`

### 6. Upload to Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app (or create a new app)
3. Navigate to **Production > Releases**
4. Click **Create new release**
5. Upload the `.aab` file from `build/app/outputs/bundle/release/`
6. Add release notes
7. Click **Review release** then **Start rollout to Production**

### Common Release Checklist

- [ ] Version and build number incremented in `pubspec.yaml`
- [ ] App icons generated for Android
- [ ] Signing keystore created and `key.properties` configured
- [ ] Application ID matches Google Play Console
- [ ] Tested in release mode: `flutter run --release`
- [ ] Build app bundle successful: `flutter build appbundle`
- [ ] Uploaded to Google Play Console
- [ ] Release notes added
- [ ] Submitted for review

### Troubleshooting

**Signing Issues:**
```bash
# Verify keystore
keytool -list -v -keystore ~/upload-keystore.jks -alias upload

# Check key.properties path is correct
cat android/key.properties
```

**Build Fails:**
```bash
# Clean and rebuild
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter build appbundle
```

**Version Already Exists:**
- Increment the build number in `pubspec.yaml` (e.g., `1.0.0+2`)

## Project Structure

- `lib/` - Dart source code
- `assets/` - Images and resources
- `pubspec.yaml` - Dependencies and configuration
