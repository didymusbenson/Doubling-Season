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

## Problem Statement
On Android (and occasionally web/slow connections), tokens appear as "Token Name (loading...)" due to artwork download blocking token creation. This interrupts user workflow and creates confusion about whether the token was created successfully.

**Design Goal:** Don't interrupt the user's functional use of the app just because of art caching and loading. Most of the time this should be imperceptible, but on slow connections it must still perform gracefully.

## Current (Problematic) Flow
1. **Placeholder created** with `amount=0` and name suffix `(loading...)`
2. **Dialogs dismissed** - user sees placeholder on board (confusing!)
3. **Artwork downloaded** from Scryfall CDN (BLOCKS on slow connections)
4. **Token finalized** - removes `(loading...)`, sets correct amount

**Code location:** `lib/screens/token_search_screen.dart:816-865`

**The issue:** If `ArtworkManager.downloadArtwork()` takes > 500ms, users see confusing loading state and cannot interact with incomplete token.

## Solution: Remove Blocking Placeholder System

**New flow:**
1. **Token created immediately** with full data (name, amount, P/T, counters, etc.)
2. **Dialogs dismissed** - user sees fully functional token on board
3. **Artwork URL assigned** to token (synchronous, instant)
4. **Artwork downloads in background** (non-blocking, fire-and-forget)
5. **Artwork fades in smoothly** once loaded (1 second fade animation)

### Implementation Requirements

#### 1. Remove Placeholder Logic
**Location:** `lib/screens/token_search_screen.dart:816-865`

**Current code to remove:**
- Lines 816-824: Placeholder creation with `amount=0` and `"(loading...)"`
- Lines 832-847: Blocking artwork download in try/catch
- Lines 849-865: Finalizing placeholder with actual data

**New code pattern:**
```dart
// Capture provider references
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

// Assign artwork URL immediately (sync, no download)
if (token.artwork.isNotEmpty) {
  newItem.artworkUrl = token.artwork[0].url;
  newItem.artworkSet = token.artwork[0].set;
}

// Insert token immediately
await tokenProvider.insertItem(newItem);

// Close dialogs - token is now visible and functional
if (context.mounted) {
  Navigator.pop(context); // Close quantity dialog
  Navigator.pop(context); // Close search screen
}

// Download artwork in background (non-blocking, fire-and-forget)
if (token.artwork.isNotEmpty) {
  ArtworkManager.downloadArtwork(token.artwork[0].url)
      .catchError((error) {
        debugPrint('Background artwork download failed: $error');
        // Silent failure - artwork will lazy-load from URL
      });
}
```

#### 2. Add Fade-In Animation to Artwork Widget
**Location:** `lib/widgets/cropped_artwork_widget.dart` (or wherever artwork is rendered in TokenCard)

**Requirements:**
- Artwork starts at opacity 0.0 when URL is first set
- Fades to opacity 1.0 over 1 second once image loads
- Use `FadeInImage` widget or `AnimatedOpacity` with image loading callback
- Show card background color while artwork is transparent/loading
- No jarring "pop" - smooth elegant reveal

**Example implementation options:**
```dart
// Option A: FadeInImage (built-in fade)
FadeInImage(
  placeholder: MemoryImage(kTransparentImage), // or solid color
  image: NetworkImage(artworkUrl),
  fadeInDuration: Duration(seconds: 1),
  fit: BoxFit.cover,
)

// Option B: AnimatedOpacity with custom loading
AnimatedOpacity(
  opacity: _imageLoaded ? 1.0 : 0.0,
  duration: Duration(seconds: 1),
  child: Image.network(artworkUrl, ...),
)
```

#### 3. Verify Copy Behavior
**Location:** `lib/providers/token_provider.dart:231-291` (copyToken method)

**Current behavior (verified correct):**
- Lines 259-260: Copies `artworkUrl` and `artworkSet` from original
- Copied tokens reference the same artwork URL
- Both original and copy will display artwork once cached

**No changes needed** - copy functionality already works correctly with this approach.

### Edge Cases & Error Handling

**Scenario 1: Artwork download fails**
- Token still fully functional (has all data)
- Artwork widget will attempt lazy-load from URL on display
- If lazy-load fails: Shows card background color (graceful degradation)

**Scenario 2: User copies token before artwork loads**
- Both tokens have same `artworkUrl`
- Both will fade in artwork when download completes
- Only one download occurs (cached)

**Scenario 3: Slow network connection (5+ seconds)**
- Token appears instantly, fully functional
- User can interact immediately (add/remove, tap, view details, copy)
- Artwork fades in whenever it's ready (no timeout needed)

**Scenario 4: User creates multiple tokens rapidly**
- All tokens appear instantly
- Artwork downloads happen in parallel (non-blocking)
- Each fades in independently as it loads

### Testing Checklist
- [ ] Token appears instantly when created (no delay)
- [ ] Token name does NOT have "(loading...)" suffix
- [ ] Token has correct amount, P/T, abilities immediately
- [ ] User can interact with token buttons immediately
- [ ] User can tap to open ExpandedTokenScreen immediately
- [ ] User can copy token before artwork loads
- [ ] Artwork fades in smoothly (1 second) once loaded
- [ ] Multiple rapid token creations don't block each other
- [ ] Slow network (throttle to 3G in DevTools): tokens still instant
- [ ] Artwork download failure: token still works, no crash

### Performance Benefits
- **Fast connections:** Imperceptible (~100ms artwork appears)
- **Slow connections:** Token creation never blocked, always instant
- **No placeholder confusion:** Users never see "(loading...)"
- **No interaction blocking:** Tokens fully functional immediately
- **Parallel downloads:** Multiple tokens load artwork concurrently

**Priority:** High - Significantly improves UX on Android and slow connections

---

# Third Issue: Krenko Mode (Commander-Specific Feature)

## Overview
"Krenko Mode" is a special setting for players using Krenko, Mob Boss in Commander. When enabled, provides quick token generation based on Krenko's power and the number of goblins controlled.

**Magic Context:** Krenko, Mob Boss has the ability "Tap: Create X 1/1 red Goblin creature tokens, where X is the number of Goblins you control."

## UI Components

### 1. Settings Toggle
**Location:** Settings screen (with other gameplay options like Summoning Sickness, Multiplier)

- **Label:** "Krenko Mode"
- **Type:** Toggle switch
- **Description:** "Enables quick goblin token generation for Krenko, Mob Boss decks"
- **Default:** Off
- **Storage:** SharedPreferences (`krenkoModeEnabled`)

### 2. Krenko Banner (Top of Token List)
**Location:** Above token list in ContentScreen, only visible when Krenko Mode enabled

**Layout:** Horizontal banner spanning full width, fixed at top (cannot be reordered)

**Contains:**
- **"Krenko's Power"** - Stepper with inline input (range: 1-99)
  - Starts at 3 (Krenko's base power)
  - User can +/- with stepper or tap to enter manually
  - Storage: SharedPreferences (`krenkoPower`)

- **"Nontoken Goblins"** - Stepper with inline input (range: 0-99)
  - Represents non-token goblins on battlefield (Krenko himself, other creatures)
  - User can +/- with stepper or tap to enter manually
  - Storage: SharedPreferences (`nontokenGoblins`)

- **"Waaagh!" Button** - Primary action button
  - Opens confirmation dialog with three options
  - Style: Red color theme (matches Board Wipe icon)

**Visual Design:**
- Banner background: Card color with red accent/border
- Text: Theme-appropriate (light/dark mode compatible)
- Compact height: ~80-100px to not dominate screen
- Padding: Standard app padding

### 3. Waaagh! Confirmation Dialog
**Triggered by:** Tapping "Waaagh!" button in Krenko Banner

**Dialog Title:** "Create Goblin Tokens"

**Three Options (buttons):**

1. **"Krenko's Power" Button**
   - Label: "Create [X] Goblins" (where X = Krenko's Power × Global Multiplier)
   - Action: Create X 1/1 Red Goblin tokens
   - Example: If power = 5, multiplier = 2, creates 10 goblins

2. **"For Each Goblin You Control" Button**
   - Label: "Create [Y] Goblins" (where Y = (Total Token Goblins + Nontoken Goblins) × Global Multiplier)
   - Action: Count all goblin tokens, add nontoken count, multiply, create that many 1/1 Red Goblin tokens
   - Example: If you have 8 token goblins + 2 nontoken = 10, multiplier = 1, creates 10 goblins

3. **"Cancel" Button**
   - Label: "Cancel"
   - Action: Dismiss dialog, do nothing

**Dialog Style:**
- Standard AlertDialog with red accent
- Show calculated amounts in button labels (dynamic)
- Buttons stack vertically for clarity

## Token Creation Logic

### Standard Goblin Token Definition
**Name:** "Goblin"
**Power/Toughness:** "1/1"
**Colors:** "R" (Red)
**Type:** "Creature - Goblin"
**Abilities:** "" (empty)

### Token Creation Behavior

**If matching token already exists:**
- Search for existing token with:
  - name = "Goblin"
  - pt = "1/1"
  - colors = "R"
  - type contains "Goblin"
  - abilities = "" (empty)
- If found: Add to that token's amount (don't create new card)
- If multiple matches: Add to first match (shouldn't happen with standard goblin)

**If no matching token exists:**
- Create new token card with standard goblin definition
- Set amount to calculated value
- Insert into token list

**Summoning Sickness:**
- Apply if global summoning sickness setting is enabled
- Set `summoningSick = amount` on creation

### Calculation Details

**Option 1: Krenko's Power**
```dart
final krenkosPower = settingsProvider.krenkoPower; // e.g., 5
final multiplier = settingsProvider.tokenMultiplier; // e.g., 2
final goblinsToCreate = krenkosPower * multiplier; // = 10
```

**Option 2: For Each Goblin You Control**
```dart
// Step 1: Count all tokens with "Goblin" in type
int tokenGoblinCount = 0;
for (final item in tokenProvider.items) {
  if (item.type.toLowerCase().contains('goblin')) {
    tokenGoblinCount += item.amount; // Sum all goblin token amounts
  }
}

// Step 2: Add nontoken goblins
final nontokenGoblins = settingsProvider.nontokenGoblins; // e.g., 2
final totalGoblins = tokenGoblinCount + nontokenGoblins; // e.g., 10

// Step 3: Apply multiplier
final multiplier = settingsProvider.tokenMultiplier; // e.g., 1
final goblinsToCreate = totalGoblins * multiplier; // = 10
```

**Important:** Type matching is case-insensitive and substring-based:
- "Creature - Goblin" ✓
- "Creature - Goblin Warrior" ✓
- "Artifact Creature - Goblin" ✓
- "Creature - Elf" ✗

## Theme Override

### Red Color Theme
When Krenko Mode is enabled, override blue theme colors with red:

**Components to recolor:**
- **FloatingActionButton** (multiplier, new token, menu)
  - Current: Blue
  - Krenko Mode: Red (use same red as Board Wipe icon)

- **TokenCard borders/accents** (optional - TBD)
  - May keep existing color identity system
  - Or add subtle red accent when Krenko Mode active

- **Krenko Banner**
  - Red accent/border
  - "Waaagh!" button: Red background

**Color Reference:**
- Board Wipe icon uses: `Colors.red` or similar
- Need to identify exact color value in FloatingActionMenu
- Ensure red works in both light and dark modes

**Implementation:**
- Check `settingsProvider.krenkoModeEnabled` in widget builds
- Conditional color selection: `krenkoModeEnabled ? Colors.red : Colors.blue`
- Apply to FABs, primary buttons, accents

## Implementation Notes

### Settings Provider
Add to `lib/providers/settings_provider.dart`:
```dart
bool get krenkoModeEnabled => _prefs.getBool('krenkoModeEnabled') ?? false;
Future<void> setKrenkoModeEnabled(bool value) async {
  await _prefs.setBool('krenkoModeEnabled', value);
  notifyListeners();
}

int get krenkoPower => _prefs.getInt('krenkoPower') ?? 3;
Future<void> setKrenkoPower(int value) async {
  await _prefs.setInt('krenkoPower', value.clamp(1, 99));
  notifyListeners();
}

int get nontokenGoblins => _prefs.getInt('nontokenGoblins') ?? 0;
Future<void> setNontokenGoblins(int value) async {
  await _prefs.setInt('nontokenGoblins', value.clamp(0, 99));
  notifyListeners();
}
```

### New Widgets Needed
1. **`KrenkoBanner`** (`lib/widgets/krenko_banner.dart`)
   - Horizontal layout with steppers and button
   - Conditionally rendered in ContentScreen when mode enabled
   - Fixed position at top of token list

2. **`KrenkoDialog`** (`lib/widgets/krenko_dialog.dart`)
   - AlertDialog with three option buttons
   - Calculates goblin counts dynamically
   - Shows calculated amounts in button labels

3. **`InlineStepperField`** (reusable widget)
   - Combines stepper buttons with tap-to-edit number
   - Similar to multiplier input pattern
   - Range validation

### Token Provider
Add method to `lib/providers/token_provider.dart`:
```dart
Future<void> createOrAddGoblins(int amount, bool applyMultiplier) async {
  final finalAmount = applyMultiplier
      ? amount * settingsProvider.tokenMultiplier
      : amount;

  // Search for existing standard goblin token
  final existingGoblin = items.firstWhereOrNull((item) =>
    item.name == 'Goblin' &&
    item.pt == '1/1' &&
    item.colors == 'R' &&
    item.type.toLowerCase().contains('goblin') &&
    item.abilities.isEmpty
  );

  if (existingGoblin != null) {
    // Add to existing
    existingGoblin.amount += finalAmount;
    await existingGoblin.save();
  } else {
    // Create new
    final newGoblin = Item(
      name: 'Goblin',
      pt: '1/1',
      colors: 'R',
      type: 'Creature - Goblin',
      abilities: '',
      amount: finalAmount,
      // ... other fields
    );
    await insertItem(newGoblin);
  }
}
```

## Questions to Answer (TODO)

- [ ] Should Krenko Banner be collapsible/expandable?
- [ ] Should there be a "reset" button for power/nontoken counts?
- [ ] Do we want a history/counter of how many times Krenko has activated?
- [ ] Should the standard goblin token have artwork auto-assigned?
- [ ] Exact red color value to use (match Board Wipe icon)?
- [ ] Should TokenCard borders get red accent in Krenko Mode, or just FABs?
- [ ] Should we show a summary after creation? ("Created 10 goblins!")
- [ ] Edge case: What if multiplier is set to 1024 and user has 50 goblins? (50k tokens)

## Testing Checklist

- [ ] Toggle Krenko Mode on/off in settings
- [ ] Krenko Banner appears at top of token list when enabled
- [ ] Krenko Banner hidden when mode disabled
- [ ] Stepper +/- buttons work for both fields
- [ ] Tap-to-edit manual input works for both fields
- [ ] Range validation (1-99 for power, 0-99 for nontoken)
- [ ] "Waaagh!" button opens dialog
- [ ] Dialog shows correct calculated amounts (dynamic)
- [ ] "Krenko's Power" creates correct number of goblins
- [ ] "For Each Goblin" counts all token types containing "goblin"
- [ ] "For Each Goblin" includes nontoken count
- [ ] Both options apply global multiplier
- [ ] Existing goblin token gets amount added (not new card)
- [ ] New goblin token created if none exists
- [ ] Summoning sickness applied if enabled
- [ ] FABs change to red when Krenko Mode enabled
- [ ] Colors work in both light and dark mode
- [ ] Values persist across app restarts (SharedPreferences)

**Priority:** Medium-High - Popular commander deck archetype, high user value
