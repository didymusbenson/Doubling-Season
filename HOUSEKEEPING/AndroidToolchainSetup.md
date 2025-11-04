# Android Toolchain Setup

Complete Android development setup for Flutter. Run these commands to install Android SDK command-line tools and accept all required licenses.

## Prerequisites

- Android Studio installed
- Flutter SDK installed
- macOS/Linux/Windows

## Automated Setup Commands

### 1. Verify Current Status

```bash
flutter doctor -v
```

Look for Android toolchain issues (missing cmdline-tools or unaccepted licenses).

### 2. Install Android SDK Command-line Tools

**For macOS (ARM):**
```bash
cd ~/Library/Android/sdk
curl -o commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip
unzip -q commandlinetools.zip
mkdir -p cmdline-tools/latest
mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
rm commandlinetools.zip
```

**For macOS (Intel):**
```bash
cd ~/Library/Android/sdk
curl -o commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip
unzip -q commandlinetools.zip
mkdir -p cmdline-tools/latest
mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
rm commandlinetools.zip
```

**For Linux:**
```bash
cd ~/Android/Sdk
curl -o commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q commandlinetools.zip
mkdir -p cmdline-tools/latest
mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
rm commandlinetools.zip
```

**For Windows (PowerShell):**
```powershell
cd $env:LOCALAPPDATA\Android\Sdk
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -OutFile "commandlinetools.zip"
Expand-Archive -Path "commandlinetools.zip" -DestinationPath "."
New-Item -ItemType Directory -Force -Path "cmdline-tools\latest"
Move-Item -Path "cmdline-tools\*" -Destination "cmdline-tools\latest\" -ErrorAction SilentlyContinue
Remove-Item "commandlinetools.zip"
```

### 3. Accept All Android SDK Licenses

```bash
yes | flutter doctor --android-licenses
```

This automatically accepts all 5-7 Android SDK licenses (GoogleTV, GoogleXR, SDK, SDK Preview, Intel HAXM).

### 4. Verify Setup Complete

```bash
flutter doctor
```

Should show:
```
[✓] Flutter
[✓] Android toolchain - develop for Android devices
[✓] Android Studio
• No issues found!
```

### 5. Check Available Emulators

```bash
flutter emulators
```

### 6. Test Run

```bash
# Launch an emulator
flutter emulators --launch <emulator-id>

# Run your Flutter app
flutter run
```

## Alternative: Manual Installation via Android Studio

If automated commands fail:

1. Open Android Studio
2. Go to **Settings/Preferences > Appearance & Behavior > System Settings > Android SDK**
3. Select **SDK Tools** tab
4. Check **Android SDK Command-line Tools (latest)**
5. Click **Apply**
6. Run `flutter doctor --android-licenses` and accept all

## Troubleshooting

**Android SDK not found:**
- Set ANDROID_HOME environment variable:
  ```bash
  # macOS/Linux (add to ~/.zshrc or ~/.bashrc)
  export ANDROID_HOME=$HOME/Library/Android/sdk  # macOS
  export ANDROID_HOME=$HOME/Android/Sdk          # Linux

  # Windows (System Environment Variables)
  ANDROID_HOME = C:\Users\<YourUsername>\AppData\Local\Android\Sdk
  ```

**cmdline-tools still missing after install:**
- Ensure the directory structure is: `sdk/cmdline-tools/latest/bin/`
- The `latest` subdirectory is required

**License acceptance fails:**
- Run manually: `flutter doctor --android-licenses`
- Type `y` for each prompt

**Wrong download URL for your platform:**
- Check latest URLs at: https://developer.android.com/studio#command-line-tools-only
- Update the version number in the commands above if needed

## Quick Copy-Paste for Claude

Tell Claude:
> "Set up my Android toolchain for Flutter. Follow the instructions in HOUSEKEEPING/AndroidToolchainSetup.md"

Or simply:
> "Install Android SDK command-line tools and accept all licenses for Flutter development"
