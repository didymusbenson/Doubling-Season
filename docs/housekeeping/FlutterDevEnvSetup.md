# Flutter Development Environment Setup Guide
# macOS with VS Code

This guide will get you from zero to ready for Flutter development. Follow these steps in order.

---

## Prerequisites Check

You should already have:
- ✓ macOS (you're on Darwin 24.6.0)
- ✓ Xcode (for SwiftUI development)
- ✓ VS Code installed

---

## Step 1: Install Flutter SDK

### Option A: Using Homebrew (Recommended)
```bash
# Install Flutter
brew install --cask flutter

# Add Flutter to PATH (if not auto-added)
echo 'export PATH="$PATH:/usr/local/Caskroom/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Option B: Manual Installation
```bash
# Download Flutter
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable

# Add to PATH
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Verify Installation
```bash
flutter --version
# Should show Flutter version info
```

---

## Step 2: Run Flutter Doctor

```bash
flutter doctor
```

This will check your environment and show what's missing. You'll likely see:

```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.x.x)
[✓] Xcode - develop for iOS and macOS
[!] Android toolchain - Android SDK not found
[✓] VS Code (version x.x.x)
[!] Connected device
```

**Don't worry about the warnings yet - we'll fix them.**

---

## Step 3: Set Up iOS Development

### Accept Xcode License
```bash
sudo xcodebuild -license accept
```

### Install CocoaPods (if not already installed)
```bash
sudo gem install cocoapods
pod setup
```

### Configure Xcode Command Line Tools
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### Test iOS Simulator
```bash
# List available simulators
xcrun simctl list devices

# Open iOS Simulator
open -a Simulator
```

---

## Step 4: Set Up Android Development

### Install Android Studio
```bash
# Using Homebrew
brew install --cask android-studio
```

**OR** download from: https://developer.android.com/studio

### Initial Android Studio Setup
1. Open Android Studio
2. Complete the setup wizard (will install Android SDK)
3. Go to **More Actions** > **SDK Manager**
4. Under **SDK Platforms**, install:
   - ✓ Android 13.0 (Tiramisu) - API 33
   - ✓ Android 12.0 (S) - API 31
5. Under **SDK Tools**, ensure these are checked:
   - ✓ Android SDK Build-Tools
   - ✓ Android SDK Command-line Tools
   - ✓ Android Emulator
   - ✓ Android SDK Platform-Tools
6. Click **Apply** and wait for downloads

### Accept Android Licenses
```bash
flutter doctor --android-licenses
# Press 'y' to accept all licenses
```

### Create Android Emulator
1. In Android Studio: **More Actions** > **Virtual Device Manager**
2. Click **Create Device**
3. Select **Pixel 5** or **Pixel 7**
4. Select system image: **Tiramisu (API 33)** - download if needed
5. Click **Finish**

### Set ANDROID_HOME (if needed)
```bash
# Add to ~/.zshrc
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc
source ~/.zshrc
```

---

## Step 5: Install VS Code Extensions

Open VS Code and install these extensions:

### Essential Extensions
1. **Flutter** (Dart-Code.flutter)
   - Official Flutter support
   - Includes Dart language support
   - Hot reload, debugging, widget inspector

2. **Dart** (Dart-Code.dart-code)
   - Usually installed automatically with Flutter extension
   - Syntax highlighting, code completion

### Highly Recommended Extensions
3. **Pubspec Assist** (jeroen-meijer.pubspec-assist)
   - Easy dependency management
   - Add packages with command palette

4. **Flutter Widget Snippets** (alexisvt.flutter-snippets)
   - Code snippets for common widgets
   - `stless` → StatelessWidget template
   - `stful` → StatefulWidget template

5. **Error Lens** (usernamehw.errorlens)
   - Inline error/warning display
   - Makes debugging easier

6. **Bracket Pair Colorizer 2** (CoenraadS.bracket-pair-colorizer-2)
   - Color-codes matching brackets
   - Helpful for deeply nested widgets

### Optional but Useful
7. **GitLens** (eamodio.gitlens)
   - Enhanced Git integration
   - Blame annotations, commit history

8. **Todo Tree** (Gruntfuggly.todo-tree)
   - Highlights TODO comments
   - Useful with migration checklist

9. **Material Icon Theme** (PKief.material-icon-theme)
   - Better file icons for Flutter projects

### Install Via Command Line
```bash
# Essential
code --install-extension Dart-Code.flutter
code --install-extension Dart-Code.dart-code

# Recommended
code --install-extension jeroen-meijer.pubspec-assist
code --install-extension alexisvt.flutter-snippets
code --install-extension usernamehw.errorlens
code --install-extension CoenraadS.bracket-pair-colorizer-2
```

---

## Step 6: Configure VS Code Settings

### Open VS Code Settings (JSON)
`Cmd+Shift+P` → "Preferences: Open Settings (JSON)"

### Add Flutter-Specific Settings
```json
{
  // Dart & Flutter
  "dart.flutterSdkPath": "/usr/local/Caskroom/flutter",
  "dart.previewFlutterUiGuides": true,
  "dart.previewFlutterUiGuidesCustomTracking": true,

  // Editor
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true
  },

  // Dart formatting
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.formatOnType": true,
    "editor.rulers": [80],
    "editor.selectionHighlight": false,
    "editor.suggest.snippetsPreventQuickSuggestions": false,
    "editor.suggestSelection": "first",
    "editor.tabCompletion": "onlySnippets",
    "editor.wordBasedSuggestions": false
  },

  // Flutter hot reload on save
  "dart.flutterHotReloadOnSave": "always",

  // Show device selector in status bar
  "dart.showDeviceSelector": true
}
```

---

## Step 7: Verify Everything Works

### Run Flutter Doctor Again
```bash
flutter doctor -v
```

You should see all checkmarks:
```
[✓] Flutter (Channel stable)
[✓] Xcode - develop for iOS and macOS
[✓] Android toolchain - develop for Android devices
[✓] Chrome - develop for the web
[✓] VS Code (version x.x.x)
[✓] Connected device (3 available)
```

### Create Test Project
```bash
cd ~/Desktop
flutter create test_app
cd test_app
code .
```

### Test iOS Build
```bash
# Start iOS Simulator
open -a Simulator

# Run app
flutter run
# OR press F5 in VS Code
```

You should see the Flutter demo app running.

### Test Android Build
```bash
# Start Android emulator (from Android Studio or command line)
# In Android Studio: Device Manager → Launch emulator

# OR command line:
emulator -avd Pixel_5_API_33

# Run app
flutter run
# Select Android device when prompted
```

### Test Hot Reload
1. With app running, edit `lib/main.dart`
2. Change the title: `title: 'Flutter Demo'` → `title: 'Test App'`
3. Save file (`Cmd+S`)
4. Should see **"Performing hot reload..."** in terminal
5. App updates without restart

---

## Step 8: Install Development Tools

### Flutter/Dart DevTools
```bash
# Should be included with Flutter, but verify:
flutter pub global activate devtools

# Run DevTools
flutter pub global run devtools
```

### Build Runner (for Hive code generation)
You'll install this per-project, but good to know:
```bash
# In your Flutter project:
flutter pub add --dev build_runner
flutter pub add --dev hive_generator
```

### iOS Deployment Tools (Optional)
If you plan to deploy to physical iOS device:
```bash
# Install ios-deploy
brew install ios-deploy
```

### App Store Deployment Tools
For uploading builds to TestFlight and the App Store:

**Apple Transporter** (Recommended for TestFlight uploads)
- Download from Mac App Store: https://apps.apple.com/us/app/transporter/id1450874784
- OR install via command:
  ```bash
  # Not available via Homebrew - must use Mac App Store
  open "macappstore://apps.apple.com/app/transporter/id1450874784"
  ```
- Used for uploading IPA files to App Store Connect
- Simpler than command-line tools (altool/xcrun)
- Provides upload progress and validation feedback

---

## Step 9: Set Up Device Testing

### iOS Physical Device
1. Connect iPhone/iPad via USB
2. Open Xcode
3. Go to **Window** > **Devices and Simulators**
4. Select your device
5. Trust the device (you'll see prompt on device)
6. Run: `flutter devices` - should show your device

### Android Physical Device
1. On Android device:
   - Go to **Settings** > **About Phone**
   - Tap **Build Number** 7 times (enables Developer Options)
   - Go to **Developer Options**
   - Enable **USB Debugging**
2. Connect via USB
3. Accept debugging prompt on device
4. Run: `flutter devices` - should show your device

---

## Step 10: Project-Specific Setup (When Ready)

When you're ready to start the Flutter migration:

### Create New Flutter Project
```bash
cd ~/Documents
flutter create doubling_season
cd doubling_season
code .
```

### Add Dependencies (from migration plan)
Edit `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
  build_runner: ^2.4.0
  hive_generator: ^2.0.0
```

Then run:
```bash
flutter pub get
```

### Set Up Build Runner Watch Mode
```bash
flutter packages pub run build_runner watch --delete-conflicting-outputs
```

Leave this running in a terminal while you develop.

---

## VS Code Keyboard Shortcuts

### Essential Shortcuts
| Action | Shortcut |
|--------|----------|
| Hot Reload | `Cmd+S` (save file) |
| Hot Restart | `Cmd+Shift+F5` |
| Open Command Palette | `Cmd+Shift+P` |
| Quick Fix | `Cmd+.` |
| Go to Definition | `F12` |
| Show Widget Inspector | `Cmd+Shift+I` (when debugging) |
| Format Document | `Shift+Option+F` |
| Start Debugging | `F5` |
| Stop Debugging | `Shift+F5` |

### Flutter-Specific Commands
`Cmd+Shift+P` then type:
- `Flutter: New Project`
- `Flutter: Hot Reload`
- `Flutter: Hot Restart`
- `Flutter: Run Flutter Doctor`
- `Dart: Open DevTools`
- `Flutter: Select Device`

---

## Troubleshooting

### "Flutter SDK not found"
```bash
# Verify PATH
echo $PATH | grep flutter

# Re-add to PATH if needed
echo 'export PATH="$PATH:$(brew --prefix)/Caskroom/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### "Android licenses not accepted"
```bash
flutter doctor --android-licenses
```

### iOS Simulator not starting
```bash
# Reset simulator
xcrun simctl erase all

# Restart simulator
killall Simulator
open -a Simulator
```

### Android Emulator slow
```bash
# Enable hardware acceleration (if not already)
# In Android Studio: SDK Manager > SDK Tools >
# Check "Intel x86 Emulator Accelerator (HAXM)"
```

### VS Code not detecting Flutter
1. Restart VS Code
2. `Cmd+Shift+P` → "Dart: Capture Logs"
3. Check for errors
4. Verify Flutter extension is enabled

### Build errors after dependency changes
```bash
flutter clean
flutter pub get
flutter run
```

---

## Quick Reference Commands

```bash
# Check Flutter installation
flutter doctor -v

# List available devices
flutter devices

# Create new project
flutter create project_name

# Run app
flutter run

# Run on specific device
flutter run -d <device-id>

# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Update dependencies
flutter pub upgrade

# Run tests
flutter test

# Build for release (iOS)
flutter build ios --release

# Build IPA for App Store/TestFlight
flutter build ipa --release

# Build for release (Android)
flutter build apk --release
```

---

## Next Steps

Once this setup is complete, you're ready to:

1. ✓ Create new Flutter project
2. ✓ Start migration from `FlutterMigration.md`
3. ✓ Reference `FlutterOptimizations.md` during development
4. ✓ Test on both iOS and Android

---

## Resources

### Official Documentation
- Flutter Docs: https://docs.flutter.dev
- Dart Docs: https://dart.dev/guides
- Hive Docs: https://docs.hivedb.dev

### VS Code Flutter Docs
- Flutter in VS Code: https://flutter.dev/docs/development/tools/vs-code

### Community
- Flutter Discord: https://discord.gg/flutter
- r/FlutterDev: https://reddit.com/r/FlutterDev
- Stack Overflow: [flutter] tag

---

## Estimated Setup Time

- Steps 1-4 (SDK Installation): **30-45 minutes**
- Steps 5-6 (VS Code Setup): **10 minutes**
- Steps 7-8 (Verification): **15 minutes**
- Step 9 (Device Setup): **10 minutes** (optional)

**Total: ~1-1.5 hours** for complete setup

---

You're now ready to start Flutter development! 🚀
