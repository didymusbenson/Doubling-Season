---
## 📦 Latest Build Artifacts (v1.3.0+8)

**iOS (.ipa):**
`build/ios/ipa/Doubling Season.ipa` (21.9MB)

**Android (.aab):**
`build/app/outputs/bundle/release/app-release.aab` (44.2MB)

**Built:** 2025-11-20
**Status:** Ready to deploy

---

# Complete Requirements Document

## Issue #1: Initial App Load Performance Optimization

### Problem Statement
On first-time app installation, users experience 5-15 second lag on web and 1-2 second lag on iOS/Android. The splash screen dismisses too early, then the app is laggy with delayed FAB responses for ~60 seconds. Root cause: Hive box initialization is slow on first launch, and background tasks complete after splash dismissal.

### Current Implementation Analysis

**Initialization Flow:**
```
main()
  → initHive() [Instant - just registers adapters]
  → _MyAppState.initState()
    → _initializeProviders() [SEQUENTIAL - BLOCKING]:
        1. TokenProvider.init()
           - await Hive.openBox<Item>('items')
           - _ensureOrdersAssigned() [SYNCHRONOUS - blocks if data exists]
        2. DeckProvider.init()
           - await Hive.openLazyBox<Deck>('decks')
        3. SettingsProvider.init()
           - await SharedPreferences.getInstance()
        4. await DatabaseMaintenanceService.compactIfNeeded() [BLOCKING]
    → _startMinimumDisplayTimer() [Artificial 1500ms wait]
  → When BOTH _providersReady AND _minTimeElapsed: Show ContentScreen
```

**Problems:**
1. Provider initialization is sequential (not parallel)
2. Compaction runs during init, blocking transition
3. Artificial 1500ms minimum can expire before providers ready
4. Background tasks (order migration, compaction) block UI readiness

### Solution: Comprehensive Optimization (Option D)

**Changes Required:**

1. **Parallelize Provider Initialization**
   - Use `Future.wait()` to initialize all 3 providers simultaneously
   - Add timing logs for each provider

2. **Move Compaction to Background**
   - Run compaction AFTER app is displayed (post-frame callback)
   - Make it non-blocking, fire-and-forget
   - Still respects weekly interval

3. **Skip First-Run Compaction**
   - Check if items box is empty OR lastCompactKey is null
   - Skip compaction entirely on first run (nothing to compact)

4. **Remove Artificial Minimum**
   - Remove 1500ms minimum timer
   - Show splash until `_providersReady = true`
   - Add optional loading indicator if initialization takes > 2 seconds

5. **Add Debug Timing Logs**
   - Log start/end of each provider init
   - Log total initialization time
   - Log compaction skip/run status

### Implementation Details

**File: `lib/main.dart`**

**Change 1: Parallelize provider initialization**
```dart
Future<void> _initializeProviders() async {
  final stopwatch = Stopwatch()..start();

  try {
    debugPrint('═══ App Initialization Started ═══');

    // Initialize all providers in parallel
    final results = await Future.wait([
      _initTokenProvider(),
      _initDeckProvider(),
      _initSettingsProvider(),
    ]);

    tokenProvider = results[0] as TokenProvider;
    deckProvider = results[1] as DeckProvider;
    settingsProvider = results[2] as SettingsProvider;

    stopwatch.stop();
    debugPrint('═══ App Initialization Complete: ${stopwatch.elapsedMilliseconds}ms ═══');

    _providersReady = true;
    _checkReadyToTransition();

    // Run compaction in background AFTER app is ready
    _runBackgroundMaintenance();
  } catch (e, stackTrace) {
    // ... existing error handling
  }
}

Future<TokenProvider> _initTokenProvider() async {
  final stopwatch = Stopwatch()..start();
  final provider = TokenProvider();
  await provider.init();
  stopwatch.stop();
  debugPrint('TokenProvider initialized in ${stopwatch.elapsedMilliseconds}ms');
  return provider;
}

Future<DeckProvider> _initDeckProvider() async {
  final stopwatch = Stopwatch()..start();
  final provider = DeckProvider();
  await provider.init();
  stopwatch.stop();
  debugPrint('DeckProvider initialized in ${stopwatch.elapsedMilliseconds}ms');
  return provider;
}

Future<SettingsProvider> _initSettingsProvider() async {
  final stopwatch = Stopwatch()..start();
  final provider = SettingsProvider();
  await provider.init();
  stopwatch.stop();
  debugPrint('SettingsProvider initialized in ${stopwatch.elapsedMilliseconds}ms');
  return provider;
}

void _runBackgroundMaintenance() {
  // Run after first frame is rendered
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DatabaseMaintenanceService.compactIfNeeded().then((didCompact) {
      if (didCompact) {
        debugPrint('Background maintenance: Compaction completed');
      }
    }).catchError((e) {
      debugPrint('Background maintenance: Compaction failed - $e');
    });
  });
}
```

**Change 2: Remove artificial minimum timer**
```dart
// DELETE _startMinimumDisplayTimer() method entirely
// DELETE _minTimeElapsed field
// DELETE _checkReadyToTransition() logic related to _minTimeElapsed

// Simplified transition logic:
void _checkReadyToTransition() {
  if (_providersReady && !_isInitialized) {
    setState(() {
      _isInitialized = true;
    });
  }
}
```

**File: `lib/database/database_maintenance.dart`**

**Change 3: Skip first-run compaction**
```dart
static Future<bool> compactIfNeeded() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastCompactTimestamp = prefs.getInt(_lastCompactKey);

    // Skip compaction on first run (never compacted before)
    if (lastCompactTimestamp == null) {
      debugPrint('DatabaseMaintenance: Skipping compaction - first run (never compacted)');
      // Set timestamp so next run knows it's not first time
      await prefs.setInt(_lastCompactKey, DateTime.now().millisecondsSinceEpoch);
      return false;
    }

    // Check if items box is empty (nothing to compact)
    final itemsBox = Hive.box<Item>('items');
    if (itemsBox.isEmpty) {
      debugPrint('DatabaseMaintenance: Skipping compaction - items box is empty');
      return false;
    }

    final lastCompactDate = DateTime.fromMillisecondsSinceEpoch(lastCompactTimestamp);
    final now = DateTime.now();
    final daysSinceLastCompact = now.difference(lastCompactDate).inDays;

    // Check if compaction interval has elapsed
    if (daysSinceLastCompact < _compactionIntervalDays) {
      debugPrint(
        'DatabaseMaintenance: Skipping compaction - last run was $daysSinceLastCompact days ago '
        '(threshold: $_compactionIntervalDays days)',
      );
      return false;
    }

    // Perform compaction
    debugPrint(
      'DatabaseMaintenance: Starting compaction - last run was $daysSinceLastCompact days ago',
    );

    final itemCount = itemsBox.length;
    final stopwatch = Stopwatch()..start();
    await itemsBox.compact();
    stopwatch.stop();

    // Record successful compaction
    await prefs.setInt(_lastCompactKey, now.millisecondsSinceEpoch);

    debugPrint(
      'DatabaseMaintenance: Compaction complete in ${stopwatch.elapsedMilliseconds}ms. '
      'Active items: $itemCount',
    );

    return true;
  } on HiveError catch (e) {
    debugPrint('DatabaseMaintenance: HiveError during compaction - ${e.message}');
    return false;
  } catch (e, stackTrace) {
    debugPrint('DatabaseMaintenance: Unexpected error during compaction - $e');
    debugPrint('Stack trace: $stackTrace');
    return false;
  }
}
```

### Testing Checklist

- [ ] Fresh install on web: Measure initialization time (should be < 3 seconds)
- [ ] Fresh install on iOS: Measure initialization time (should be < 1 second)
- [ ] Fresh install on Android: Measure initialization time (should be < 1 second)
- [ ] Splash screen doesn't dismiss until app is fully ready
- [ ] FABs are immediately responsive after splash (no lag period)
- [ ] Debug logs show timing for each provider
- [ ] First-run compaction is skipped (log confirms)
- [ ] Subsequent launches: compaction runs in background without blocking
- [ ] Compaction respects weekly interval
- [ ] Empty database: compaction is skipped
- [ ] Provider initialization runs in parallel (logs show overlapping times)

---

## Issue #2: Token Creation Loading State

### Problem Statement
Tokens appear as "Token Name (loading...)" with amount=0 when artwork download is slow. This creates a broken, confusing state that interrupts user workflow. The placeholder system blocks token finalization on artwork download completion.

### Current Implementation Analysis

**Token Creation Flow:**
```
User selects token + quantity
  → Create placeholder Item (amount=0, name="Token (loading...)")
  → Insert placeholder to database
  → Close dialogs (user sees broken placeholder on board)
  → await ArtworkManager.downloadArtwork() [BLOCKS 0-5+ seconds]
  → Update placeholder (remove "(loading...)", set correct amount)
  → Modifying card mid-load interrupts state
```

**Problems:**
1. Placeholder creates broken state (0 amount, loading suffix)
2. Artwork download blocks token finalization
3. Card modification interrupts loading
4. User sees incomplete, confusing token

### Solution: Remove Placeholder System

**Changes Required:**

1. **Create Token Immediately** - Full data, no placeholder
2. **Set artworkUrl Synchronously** - Before download
3. **Fire-and-Forget Download** - Non-blocking background task
4. **Fade-In Animation** - 500ms fade, ONLY for newly downloaded artwork
5. **Empty Background** - Show card color until artwork loads
6. **Copy Behavior** - Both cards reference same URL, fade together
7. **Error Handling** - Silent fail + reset artworkUrl to null
8. **Preserve Precaching** - Keep existing precaching logic intact

### Implementation Details

**File: `lib/screens/token_search_screen.dart`**

**Replace lines 816-865 with new implementation:**

```dart
// Capture provider references BEFORE any async operations
final tokenProvider = context.read<TokenProvider>();
final settingsProvider = context.read<SettingsProvider>();
final finalAmount = _tokenQuantity * multiplier;

// Create final token immediately (no placeholder)
final newItem = token.toItem(
  amount: finalAmount,
  createTapped: _createTapped,
);

// Apply summoning sickness if enabled
if (settingsProvider.summoningSicknessEnabled) {
  newItem.summoningSick = finalAmount;
}

// Assign artwork URL immediately (synchronous, no download)
if (token.artwork.isNotEmpty) {
  final firstArtwork = token.artwork[0];
  newItem.artworkUrl = firstArtwork.url;
  newItem.artworkSet = firstArtwork.set;
}

// Insert token immediately - it's now visible and fully functional
await tokenProvider.insertItem(newItem);

// Close dialogs - token is on board and usable
if (context.mounted) {
  Navigator.pop(context); // Close quantity dialog
  Navigator.pop(context); // Close search screen
}

// Download artwork in background (non-blocking, fire-and-forget)
if (token.artwork.isNotEmpty) {
  final artworkUrl = token.artwork[0].url;
  ArtworkManager.downloadArtwork(artworkUrl).then((file) {
    if (file == null) {
      // Download failed - reset artworkUrl so it doesn't try to load
      debugPrint('Artwork download failed for ${token.name}, resetting URL');
      // Find the item again (it might have been deleted/modified)
      final currentItem = tokenProvider.items.firstWhereOrNull(
        (item) => item.artworkUrl == artworkUrl
      );
      if (currentItem != null) {
        currentItem.artworkUrl = null;
        currentItem.artworkSet = null;
        currentItem.save();
      }
    } else {
      debugPrint('Artwork downloaded and cached for ${token.name}');
    }
  }).catchError((error) {
    debugPrint('Error during background artwork download: $error');
    // Silent fail - reset artworkUrl on error
    final currentItem = tokenProvider.items.firstWhereOrNull(
      (item) => item.artworkUrl == artworkUrl
    );
    if (currentItem != null) {
      currentItem.artworkUrl = null;
      currentItem.artworkSet = null;
      currentItem.save();
    }
  });
}
```

**File: `lib/widgets/token_card.dart`**

**Add fade-in animation logic:**

Modify `_TokenCardState` to track artwork appearance timing:

```dart
class _TokenCardState extends State<TokenCard> {
  final DateTime _createdAt = DateTime.now();
  bool _artworkAnimated = false;

  // ... existing code ...
}
```

Modify `_buildFullViewArtwork` method (line 520) to add fade animation:

```dart
Widget _buildFullViewArtwork(BuildContext context, BoxConstraints constraints) {
  final crop = ArtworkManager.getCropPercentages();

  return Positioned.fill(
    child: FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(item.artworkUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          // Determine if artwork should animate
          // If it appears > 100ms after card creation = downloaded (animate)
          // If it appears < 100ms after card creation = cached (no animation)
          final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
          final shouldAnimate = elapsed > 100 && !_artworkAnimated;

          if (shouldAnimate) {
            _artworkAnimated = true;
          }

          return AnimatedOpacity(
            opacity: 1.0,
            duration: shouldAnimate ? const Duration(milliseconds: 500) : Duration.zero,
            curve: Curves.easeIn,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
              child: CroppedArtworkWidget(
                imageFile: snapshot.data!,
                cropLeft: crop['left']!,
                cropRight: crop['right']!,
                cropTop: crop['top']!,
                cropBottom: crop['bottom']!,
                fillWidth: true,
              ),
            ),
          );
        }
        // Show empty background while loading
        return const SizedBox.shrink();
      },
    ),
  );
}
```

Modify `_buildFadeoutArtwork` method (line 548) similarly:

```dart
Widget _buildFadeoutArtwork(BuildContext context, BoxConstraints constraints) {
  final crop = ArtworkManager.getCropPercentages();
  final artworkWidth = constraints.maxWidth * 0.50;

  return Positioned(
    right: 0,
    top: 0,
    bottom: 0,
    width: artworkWidth,
    child: FutureBuilder<File?>(
      future: ArtworkManager.getCachedArtworkFile(item.artworkUrl!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          // Same animation logic as full view
          final elapsed = DateTime.now().difference(_createdAt).inMilliseconds;
          final shouldAnimate = elapsed > 100 && !_artworkAnimated;

          if (shouldAnimate) {
            _artworkAnimated = true;
          }

          return AnimatedOpacity(
            opacity: 1.0,
            duration: shouldAnimate ? const Duration(milliseconds: 500) : Duration.zero,
            curve: Curves.easeIn,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(UIConstants.smallBorderRadius),
                bottomRight: Radius.circular(UIConstants.smallBorderRadius),
              ),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.0, 0.50],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: CroppedArtworkWidget(
                  imageFile: snapshot.data!,
                  cropLeft: crop['left']!,
                  cropRight: crop['right']!,
                  cropTop: crop['top']!,
                  cropBottom: crop['bottom']!,
                  fillWidth: false,
                ),
              ),
            ),
          );
        }
        // Show empty background while loading
        return const SizedBox.shrink();
      },
    ),
  );
}
```

### Copy Behavior Verification

**File: `lib/providers/token_provider.dart` (lines 270-271)**

Current implementation already handles copy correctly:
```dart
newItem.artworkUrl = original.artworkUrl;
newItem.artworkSet = original.artworkSet;
```

Both original and copy reference the same URL. The `ArtworkManager.getCachedArtworkFile()` checks cache first (lines 60-64), so:
- If artwork is already cached: Both cards show immediately
- If artwork is being downloaded: Both cards' FutureBuilders wait for same file, fade in together

**No changes needed** - copy behavior is correct as-is.

### Precaching Preservation

**Note:** Existing precaching logic (if any) must be preserved. The implementation should:
- Keep any existing precache calls intact
- Ensure background downloads don't interfere with precaching
- ArtworkManager already handles "already cached" case (lines 60-64)

### Testing Checklist

- [ ] Token appears instantly with correct amount/P/T/abilities
- [ ] Token name does NOT have "(loading...)" suffix at any point
- [ ] Token is fully interactive immediately (tap, add/remove, buttons work)
- [ ] Artwork fades in over 500ms when downloaded (slow connection)
- [ ] Artwork appears instantly when cached (no animation)
- [ ] Multiple rapid token creations don't block each other
- [ ] Copy token before artwork loads: both fade in together
- [ ] Copy token after artwork loads: copy shows artwork immediately
- [ ] Artwork download failure: token works, artworkUrl reset to null, no crash
- [ ] Slow network (throttle to 3G): tokens still instant, artwork fades in later
- [ ] Empty card background shown while artwork loading
- [ ] Precaching still works (if applicable)

---

## Final Notes

Both implementations are independent and can be done in any order. Issue #1 affects all users on every first launch. Issue #2 affects token creation on slow connections.

**Recommended order: Issue #1 first** (broader impact), then Issue #2.

All requirements are complete and ready for autonomous implementation.
