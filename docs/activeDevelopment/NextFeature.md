---
## 📦 Latest Build Artifacts (v1.3.0+8)

**iOS (.ipa):**
`build/ios/ipa/Doubling Season.ipa` (21.9MB)

**Android (.aab):**
`build/app/outputs/bundle/release/app-release.aab` (44.2MB)

**Built:** 2025-11-20
**Status:** Ready to deploy

---

# Next Feature: Initial App Load Performance Investigation

## Overview
Investigate and address the lag/delay users experience on first app load, particularly on web platform where Hive database initialization may cause noticeable performance impact.

## Current Behavior

### What Happens on First Load
1. **Hive Initialization** (`initHive()` in `main.dart:31`)
   - Opens IndexedDB connections on web (slower than native platforms)
   - Opens `items` box (normal Box)
   - Opens `decks` box (LazyBox)

2. **Provider Initialization** (`_initializeProviders()` in `main.dart:87`)
   - TokenProvider init
   - DeckProvider init
   - SettingsProvider init (SharedPreferences)

3. **Database Maintenance** (`main.dart:103`)
   - Runs `DatabaseMaintenanceService.compactIfNeeded()`
   - On first web load: shows "last run was 20412 days ago" (defaults to very old date)
   - Compaction takes 0-500ms depending on database size
   - Runs weekly thereafter

4. **Asset Loading**
   - Loads `token_database.json` (300+ tokens)
   - Happens in TokenSearchScreen via `compute()` isolate

### Performance Issues
- **Web platform**: Noticeable lag on first load (5-15 seconds)
- **iOS/Android**: Minimal lag (1-2 seconds typical)
- User experience: App feels unresponsive during initialization

## Investigation Tasks

### 1. Profile Web Initialization
- [ ] Measure time for each initialization step:
  - Hive setup (IndexedDB connection)
  - Provider initialization
  - Database compaction
  - Asset loading
- [ ] Use Flutter DevTools Performance tab to identify bottlenecks
- [ ] Compare debug vs release builds

### 2. Evaluate Database Compaction Strategy
- [ ] Should we skip compaction on first run? (no data to compact anyway)
- [ ] Should compaction run in background after app loads?
- [ ] Consider moving compaction to separate isolate
- [ ] Test performance impact with various database sizes (0, 10, 50, 100+ tokens)

### 3. Optimize Hive Setup on Web
- [ ] Research Hive web-specific optimizations
- [ ] Consider lazy-loading decks box on web (delay until needed)
- [ ] Evaluate if we can defer non-critical box opens

### 4. Improve Splash Screen Experience
- [ ] Currently: Minimum 1500ms display time (`main.dart:73`)
- [ ] Consider showing loading indicator if initialization takes > 2 seconds
- [ ] Add progress feedback for long loads
- [ ] Option: Show "tip of the day" during load

### 5. Asset Loading Optimization
- [ ] Token database loads on-demand (only when TokenSearchScreen opens)
- [ ] This is already optimal - no changes needed
- [ ] Verify `compute()` isolate is working correctly on web

## Potential Solutions

### Option 1: Background Compaction
Move database compaction to post-load background task:
```dart
// After providers ready and app displayed
Future.microtask(() {
  DatabaseMaintenanceService.compactIfNeeded();
});
```

### Option 2: Skip First-Run Compaction
Add logic to skip compaction if database is empty or newly created:
```dart
if (itemsBox.isEmpty) {
  return; // Skip compaction on first run
}
```

### Option 3: Progressive Loading
Load critical components first, defer non-critical:
1. Load SettingsProvider (needed for UI theme)
2. Load TokenProvider (show empty board state)
3. Background: DeckProvider, maintenance tasks

### Option 4: Web-Specific Initialization Path
Detect web platform and use optimized initialization:
```dart
if (kIsWeb) {
  // Skip compaction, lazy-load decks
} else {
  // Standard initialization
}
```

### Option 5: Loading Screen with Progress Indicator (UX Improvement)
Show a loading screen after splash dismissal if initialization is taking longer than expected. Provides clear user feedback that the app is working.

**Simple Approach (5-10 minutes):**
Add loading indicator overlay to existing SplashScreen:
```dart
// In main.dart _MyAppState.build()
if (!_isInitialized) {
  return MaterialApp(
    home: SplashScreen(
      key: const ValueKey('splash'),
      onComplete: _skipSplash,
      showLoadingIndicator: true, // New optional prop
    ),
  );
}
```

**Better Approach (15-20 minutes):**
Create dedicated `LoadingScreen` shown between splash and main app:

```dart
class LoadingScreen extends StatelessWidget {
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Initializing database...'),
            SizedBox(height: 8),
            LinearProgressIndicator(), // Optional progress bar
          ],
        ),
      ),
    );
  }
}
```

**State Logic Update:**
- Current: `_minTimeElapsed && _providersReady` → Show ContentScreen
- New logic:
  - `!_minTimeElapsed` → Show SplashScreen
  - `_minTimeElapsed && !_providersReady` → Show LoadingScreen
  - `_minTimeElapsed && _providersReady` → Show ContentScreen

**Benefits:**
- Users know the app is working (not frozen)
- Explains what's happening ("Initializing database...")
- Professional UX for slower devices/connections
- Particularly helpful on web where initialization is slower

**Implementation Location:**
- `main.dart` (modify `_MyAppState.build()` logic)
- New file: `lib/screens/loading_screen.dart` (optional, if using dedicated screen)

## Success Criteria
- First load time on web < 3 seconds (stretch goal: < 2 seconds)
- No perceived lag on iOS/Android
- Database operations remain reliable
- No impact on app stability

## Next Steps
1. Profile current initialization performance
2. Identify biggest bottleneck (Hive? SharedPreferences? Compaction?)
3. Implement highest-impact optimization
4. Test across platforms (web, iOS, Android)
5. Gather user feedback on perceived performance

## Notes
- Web console shows: "DatabaseMaintenance: Starting compaction - last run was 20412 days ago"
- Compaction completed in 0ms on empty database (not the bottleneck)
- Main delay likely from IndexedDB/SharedPreferences initialization on web

---

# Secondary Issue: Token Creation Loading State (Android)

## Problem
On Android, tokens sometimes appear as "Token Name (loading...)" due to slow artwork download. iOS performs better due to faster network stack.

## Current Flow
1. **Placeholder created** with `amount=0` and name suffix `(loading...)`
2. **Dialogs dismissed** - user sees placeholder on board
3. **Artwork downloaded** from Scryfall CDN (SLOW on Android)
4. **Token finalized** - removes `(loading...)`, sets correct amount

**Code location:** `lib/screens/token_search_screen.dart:816-865`

The issue: If `ArtworkManager.downloadArtwork()` takes > 500ms, users see the loading state.

## TODO: Improve Loading State UX (Needs Refinement)

**Current behavior:** Placeholder shows as `"Goblin (loading...)"` with 0 amount

**Proposed behavior:** Show a special loading card view in the token list that displays:
- Message: "Taking longer than expected to create {token name}"
- Different visual treatment (distinct from normal token cards)
- Progress indicator or animation
- Maybe countdown or timeout indicator

**Questions to answer:**
- Should this replace the current placeholder or supplement it?
- At what threshold do we show this message? (1 second? 2 seconds?)
- Should we have a timeout where we give up on artwork and finalize anyway?
- What happens if artwork fails completely? (Currently: token still gets created)
- Should we allow user to cancel the creation?

**Alternative approaches to consider:**
1. **Skip pre-download entirely** - Create token immediately, lazy-load artwork
2. **Timeout-based** - If download > 500ms, finalize token without waiting
3. **Remove placeholder system** - Create final token immediately, download in background
4. **Better loading indicator** - Custom TokenCard variant for loading state

**Implementation notes:**
- Could be a custom widget: `LoadingTokenCard` that replaces normal TokenCard
- Needs to detect when placeholder has been in loading state too long
- Should gracefully handle artwork download failures

**Priority:** Medium - Impacts Android users primarily, iOS mostly unaffected
