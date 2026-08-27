# Android Compatibility Issues

## Problem Summary

Users on Android versions 11, 13, and 15 report:
- "Create custom token" button acting like a "back" button
- Modal sheets getting stuck
- Keyboard not opening (Android 11 & 13)
- General app crashes and non-functionality

**No reports from Android 16 users** - issues appear specific to older Android versions.

**Affected user percentage:** Less than 1% of total user base (important context for diagnosis).

## Root Causes Identified

### 1. CRITICAL: `autofocus: true` in Dialogs/Modals

**Well-known Flutter bug on Android < 8 (API < 26)** where `autofocus: true` inside dialogs or modal bottom sheets causes:
- Keyboard not opening
- Touch events being misrouted (explains "back button" behavior)
- Modal sheets getting stuck
- Focus conflicts between modal layer and activity layer

**Affected Files:**

#### `lib/screens/counter_search_screen.dart`
- **Line 151:** TextField with `autofocus: true` inside nested AlertDialog
  ```dart
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Set Quantity'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,  // LINE 151 - PROBLEMATIC
        decoration: const InputDecoration(
          hintText: 'Enter quantity',
          border: OutlineInputBorder(),
        ),
  ```

#### `lib/widgets/new_tracker_sheet.dart`
- **Line 259:** TextField with `autofocus: true` in value dialog
  ```dart
  void _showValueDialog() {
    final controller = TextEditingController(text: '$_defaultValue');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Default Value'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,  // LINE 259 - PROBLEMATIC
  ```

#### `lib/widgets/tracker_widget_card.dart`
- **Line 298:** TextField with `autofocus: true` in value edit dialog
  ```dart
  void _showValueEditDialog(BuildContext context) {
    final trackerProvider = context.read<TrackerProvider>();
    final controller = TextEditingController(text: '${widget.tracker.currentValue}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set ${widget.tracker.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,  // LINE 298 - PROBLEMATIC
  ```

#### `lib/screens/expanded_token_screen.dart`
- **Line 661:** +1/+1 counter editing field
- **Line 766:** -1/-1 counter editing field
- **Line 898:** Custom counter editing field
  ```dart
  if (isEditingPlusOne)
    Container(
      constraints: const BoxConstraints(minWidth: 40, maxWidth: 80),
      child: TextField(
        controller: _numericController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        autofocus: true,  // LINE 661 - PROBLEMATIC
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
  ```

#### `lib/screens/token_search_screen.dart`
- **Line 680:** TextField with `autofocus: true` inside modal bottom sheet (quantity input)
  ```dart
  _isEditingQuantity
      ? TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,  // LINE 680 - PROBLEMATIC IN MODAL
          style: const TextStyle(
  ```

---

### 2. HIGH PRIORITY: `android:windowSoftInputMode="adjustResize"` Conflict

**File:** `android/app/src/main/AndroidManifest.xml:26`

**Current configuration:**
```xml
android:windowSoftInputMode="adjustResize"
```

**Problem:**
When combined with `isScrollControlled: true` modal bottom sheets (used throughout the app), this setting causes on Android 9-13:
- Keyboard conflicts
- Touch event interception issues
- Navigation stack corruption (explains "back button" behavior)
- Modal sheets getting stuck

**All `showModalBottomSheet` calls use `isScrollControlled: true`** in:
1. `lib/widgets/floating_action_menu.dart:37`
2. `lib/screens/expanded_widget_screen.dart:165`
3. `lib/widgets/multiplier_view.dart:30`
4. `lib/screens/expanded_token_screen.dart:158, 1289`
5. `lib/screens/token_search_screen.dart:575`

---

### 3. MEDIUM PRIORITY: Missing Focus Management

No `FocusNode` usage or explicit focus dismissal in dialog/modal TextFields. On older Android versions, this causes focus to get "stuck" between the modal layer and the activity layer.

**Affected patterns:**
- TextEditingControllers created without FocusNode management
- No `FocusScope.of(context).unfocus()` after TextField submission
- No `onTapOutside` keyboard dismissal handlers

---

### 4. MEDIUM PRIORITY: Bleeding-Edge Build Tool Versions

**Files:** `android/settings.gradle.kts:22-23`, `android/app/build.gradle.kts`

**Current versions in use:**
- **Android Gradle Plugin (AGP) 8.9.1** - Released December 2024
- **Kotlin 2.1.0** - Released November 2024

**Problem:**
These are extremely recent versions that may have:
- Compatibility bugs with Flutter
- Android version-specific regressions (works on Android 16, broken on 11-15)
- R8 code optimizer changes that affect runtime behavior
- Untested edge cases in production environments

**Why this matters:**
- Symptoms match pattern: works on newest Android, fails on slightly older versions
- New AGP/Kotlin releases often have bugs that get fixed in minor versions
- R8 (bundled with AGP) behavior changes can cause unexpected issues
- Build tool bugs are invisible in code but affect all users

**Recommended stable versions:**
```kotlin
// android/settings.gradle.kts
id("com.android.application") version "8.1.4" apply false
id("org.jetbrains.kotlin.android") version "1.9.22" apply false
```

**Downgrade implications:**
- **Zero impact on Dart/Flutter code** - these are build tools only
- **No Kotlin code changes needed** - project has no native Kotlin code
- **Low risk** - AGP 8.1.4 and Kotlin 1.9.22 are battle-tested with millions of Flutter apps
- **Build script compatibility** - Current `build.gradle.kts` syntax should work with older versions

---

### 5. LOW PRIORITY (SKIP): ProGuard/R8 Rules

**File:** `android/app/proguard-rules.pro`

**Initial concern:** Missing ProGuard rules for Hive and Provider could cause code stripping in release builds.

**Why this is NOT the issue:**
- **Only <1% of users affected** - ProGuard stripping critical code would affect 100% of release build users
- App would crash immediately on launch if Hive/Provider code was stripped
- Hive and Provider likely have built-in ProGuard rules in their packages
- Current users are successfully using the app, indicating no code stripping issues

**Verdict:** Skip adding additional ProGuard rules unless crash logs show evidence of reflection/code-stripping errors.

---

### 6. LOW PRIORITY: Multiple Nested Navigator.pop() Calls

**Files with potential navigation issues:**

#### `lib/widgets/new_token_sheet.dart:62-64`
- Close button uses `Navigator.pop(context)` without proper context checking
- No back button interception

#### `lib/widgets/load_deck_sheet.dart`
- **Line 34:** Close button uses `Navigator.pop(context)` without context validation
- **Lines 133, 186:** Multiple nested Navigator.pop calls could cause "back button" confusion

#### `lib/widgets/split_stack_sheet.dart:327`
- Early dismiss pattern with `Navigator.pop(context)` + `Future.delayed`
- Timing might need platform-specific adjustment for Android

---

## Why Android 16 Works Fine

Android 16 likely has:
- Better WindowInsets handling
- Fixed TextField focus issues in modals
- Improved modal/dialog touch event layering
- Regression fixes for issues present in Android 11-15

---

## Recommended Fixes (Priority Order)

Based on <1% user impact and symptom pattern (works on Android 16, fails on 11-15):

**Priority 1 (HIGH):** Fix #1 - Replace `autofocus: true` with delayed focus
**Priority 2 (MEDIUM-HIGH):** Fix #2 - Change `windowSoftInputMode` to `adjustPan`
**Priority 3 (MEDIUM):** Fix #3 - Downgrade AGP/Kotlin to stable versions
**Priority 4 (LOW):** Fix #4 - Add keyboard dismissal handlers
**Priority 5 (SKIP):** Navigator.pop() cleanup (minor contributor)
**Priority 6 (SKIP):** ProGuard rules (not the issue)

---

### Fix #1: Replace `autofocus: true` with Delayed Focus (HIGH PRIORITY)

**Current pattern:**
```dart
TextField(
  autofocus: true,
  // ...
)
```

**Recommended pattern:**
```dart
class _MyDialogState extends State<MyDialog> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Delay focus request for Android compatibility
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: TextField(
        focusNode: _focusNode,
        // Remove autofocus: true
      ),
    );
  }
}
```

**Files requiring changes:**
1. `lib/screens/counter_search_screen.dart:151`
2. `lib/screens/token_search_screen.dart:680`
3. `lib/screens/expanded_token_screen.dart:661, 766, 898`
4. `lib/widgets/new_tracker_sheet.dart:259`
5. `lib/widgets/tracker_widget_card.dart:298`

---

### Fix #2: Change `windowSoftInputMode` (MEDIUM PRIORITY)

**File:** `android/app/src/main/AndroidManifest.xml:26`

**Option A - Simple fix:**
```xml
android:windowSoftInputMode="adjustPan"
```

**Option B - Better control (recommended):**
```xml
android:windowSoftInputMode="adjustNothing"
```

Then handle keyboard insets manually in modal bottom sheets:
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: YourSheetContent(),
    );
  },
);
```

---

### Fix #3: Downgrade AGP and Kotlin to Stable Versions (MEDIUM PRIORITY)

**File:** `android/settings.gradle.kts`

**Current (bleeding-edge):**
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}
```

**Recommended (stable, battle-tested):**
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.1.4" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}
```

**Why this might fix the issue:**
- New AGP releases often have Android version-specific bugs
- R8 optimizer bundled with AGP changes behavior between versions
- Kotlin 2.1.0 is very new and may have compatibility issues
- Symptoms match pattern: works on cutting-edge Android 16, fails on slightly older versions

**Testing after downgrade:**
1. Clean build: `flutter clean`
2. Rebuild: `flutter build apk --release`
3. Test on Android 11, 13, 15 devices
4. Verify no regressions on Android 16

---

### Fix #4: Add Keyboard Dismissal Handlers (LOW PRIORITY)

In modals with TextFields, add:
```dart
TextField(
  onTapOutside: (_) => FocusScope.of(context).unfocus(),
  // ...
)
```

Also add explicit focus dismissal after TextField submission:
```dart
onSubmitted: (value) {
  // Process value
  FocusScope.of(context).unfocus();
  Navigator.pop(context);
},
```

---

---

## Quick Verification Test

**Test #1 - Code-level fixes:**
1. **Comment out ALL `autofocus: true` lines** (~10 instances)
2. **Change `windowSoftInputMode` to `adjustPan`** in AndroidManifest.xml
3. **Rebuild and test on Android 11/13 devices**

**Test #2 - Build tool downgrade:**
1. **Downgrade AGP to 8.1.4 and Kotlin to 1.9.22** in settings.gradle.kts
2. **Run `flutter clean`**
3. **Rebuild and test on Android 11/13 devices**

**Recommended approach:** Try Test #1 first (code-level fixes). If issues persist, try Test #2 (build tool downgrade).

---

## Files Requiring Changes Summary

**High Priority:**
1. `android/app/src/main/AndroidManifest.xml` - Change windowSoftInputMode to `adjustPan`
2. `lib/screens/counter_search_screen.dart` - Remove autofocus, add FocusNode
3. `lib/screens/token_search_screen.dart` - Remove autofocus, add FocusNode
4. `lib/screens/expanded_token_screen.dart` - Remove autofocus (3 instances), add FocusNode
5. `lib/widgets/new_tracker_sheet.dart` - Remove autofocus, add FocusNode
6. `lib/widgets/tracker_widget_card.dart` - Remove autofocus, add FocusNode

**Medium Priority:**
7. `android/settings.gradle.kts` - Downgrade AGP to 8.1.4 and Kotlin to 1.9.22

**Low Priority (optional):**
8. All modal bottom sheet files - Add keyboard inset padding if using `adjustNothing`
9. Dialog TextFields - Add `onTapOutside` keyboard dismissal handlers

---

## Research Findings: AGP 8.9.1 and Kotlin 2.1.0

### AGP 8.9.1 Reality Check

**Finding:** AGP 8.9.1 may be a very recent patch or your version might actually be 8.9.0 (released March 2025). The official Android documentation shows AGP 8.9.0, 8.11.0, and 8.13, but not 8.9.1 specifically.

**Documented AGP 8.x Issues Found:**

1. **R8 Optimizer Changes (2023-2025):**
   - As of AGP 8.0, R8 runs in **full mode by default** instead of ProGuard compatibility mode
   - More aggressive optimization can cause runtime issues
   - Multiple reports of R8 errors in AGP 8.4.0, 8.5.0, 8.6.0
   - October 2024: R8 obfuscation changes in new AGP versions subtly modified how network-related code is processed

2. **AGP 8.6.0 Issues (October 2024):**
   - Flutter 3.23 had build failures with AGP 8.6 and Gradle 8.7
   - Developers reported various compilation and runtime issues

3. **No Android Version-Specific Bugs Found:**
   - No documented evidence of AGP 8.9.x causing issues specifically on Android 11-15 vs Android 16

**Verdict:** While AGP 8.9.x is very new and could have bugs, there's no smoking gun evidence linking it to your specific symptoms. However, R8's aggressive optimization in AGP 8.x could contribute to runtime behavior differences.

---

### Kotlin 2.1.0 Issues

**Finding:** Kotlin 2.1.0 (released November 2024) has documented compatibility issues with Flutter and runtime behavior changes.

**Documented Issues:**

1. **Flutter Compilation Failures:**
   - Flutter Android builds fail with Kotlin 2.1.0 due to metadata version mismatches
   - Error: "Module was compiled with an incompatible version of Kotlin. Binary version 2.2.0, expected 1.8.0"
   - Flutter's pinned Kotlin plugin (1.8.0) conflicts with dependencies compiled with Kotlin 2.x

2. **Runtime Behavior Changes:**
   - Compose recomposition behavior changed in Kotlin 2.1.0
   - Virtual functions won't be restarted or skipped; runtime will recompose parent composable instead
   - Lambda reflection behavior changed in Kotlin 2.0+ (still relevant in 2.1.0)

3. **Library Compatibility:**
   - Realm Kotlin had `NoSuchMethodError` with Kotlin 2.1.0
   - Some libraries not yet compatible with Kotlin 2.1.0's compiler changes

4. **Flutter-Specific Issues (December 2024):**
   - Flutter Gradle Plugin 1.0.0 doesn't automatically include plugin dependencies in compile classpath with Kotlin 2.1.0
   - Causes `GeneratedPluginRegistrant.java` compilation errors

**Verdict:** Kotlin 2.1.0 has documented Flutter compatibility issues and runtime behavior changes. While most reported issues are compilation errors (not runtime), the Compose recomposition changes could theoretically affect UI behavior.

---

### Bottom Sheet + Keyboard Issues (General Flutter)

**Finding:** Modal bottom sheet keyboard issues are **long-standing Flutter framework bugs**, not AGP-specific.

**Key Issues Found:**
- [Flutter Issue #71418](https://github.com/flutter/flutter/issues/71418) - showModalBottomSheet does not move along with keyboard
- [Flutter Issue #18564](https://github.com/flutter/flutter/issues/18564) - TextField hidden by keyboard inside modal bottom sheet
- [Flutter Issue #142860](https://github.com/flutter/flutter/issues/142860) - BottomSheet rebuilds unnecessarily when keyboard opens/closes

**Common Solutions:**
- Use `isScrollControlled: true` (already implemented in this app)
- Add `MediaQuery.of(context).viewInsets.bottom` padding
- Avoid `autofocus: true` in bottom sheet TextFields

**Verdict:** Your modal sheet + keyboard issues are likely **not caused by AGP/Kotlin versions**, but by the well-known Flutter framework issues combined with `autofocus: true` usage.

---

### Overall Assessment

**Most Likely Culprits (based on research):**
1. **`autofocus: true` in modals** - Matches documented Flutter bugs exactly
2. **`windowSoftInputMode="adjustResize"`** - Conflicts with `isScrollControlled: true`
3. **Kotlin 2.1.0 Flutter compatibility** - Has documented issues, but mostly compilation (not runtime)

**Unlikely Culprits:**
4. **AGP 8.9.x** - No evidence of Android version-specific bugs, though R8 changes could contribute
5. **ProGuard/R8 rules** - Would affect all users, not <1%

**Recommended Action:** Focus on fixing #1 and #2 first. If issues persist, try downgrading Kotlin to 1.9.22 (more impact than AGP downgrade based on research).

---

## Additional Resources

- [Flutter Issue #25741](https://github.com/flutter/flutter/issues/25741) - autofocus in dialogs on Android
- [Flutter Issue #36341](https://github.com/flutter/flutter/issues/36341) - Keyboard not showing in modal bottom sheet
- [Flutter Issue #71418](https://github.com/flutter/flutter/issues/71418) - Modal bottom sheet keyboard issues
- [Android WindowSoftInputMode Documentation](https://developer.android.com/guide/topics/manifest/activity-element#wsoft)
- [AGP 8.9.0 Release Notes](https://developer.android.com/build/releases/past-releases/agp-8-9-0-release-notes)
- [Kotlin 2.1.0 What's New](https://kotlinlang.org/docs/whatsnew21.html)
- [Flutter Issue #179253](https://github.com/flutter/flutter/issues/179253) - Kotlin 2.x compatibility with Flutter

---

## Testing Plan

After implementing fixes:
1. Test on Android 11 (API 30) - keyboard issues reported
2. Test on Android 13 (API 33) - keyboard issues reported
3. Test on Android 15 (API 35) - general crashes reported
4. Test on Android 16 (API 36) - ensure no regressions
5. Focus on:
   - Token search quantity input
   - Custom token creation
   - Counter editing dialogs
   - Tracker widget value editing
   - Modal sheet navigation (back button behavior)
