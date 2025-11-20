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
