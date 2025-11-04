# Flutter Performance Best Practices & Optimizations
# Doubling Season - Flutter Implementation

## Overview

This document contains performance optimizations and best practices for the Flutter version of Doubling Season. The migration is complete and many optimizations have been implemented. This document tracks implementation status and identifies remaining opportunities.

## Implementation Status Summary

### ✅ Completed Optimizations (7/11)
1. **Hive ValueListenableBuilder** - `lib/providers/token_provider.dart:12`, `lib/screens/content_screen.dart:89`
2. **Proper ListView Keys** - `lib/screens/content_screen.dart:130`
3. **Centralized Constants** - `lib/utils/constants.dart` (fully implemented)
4. **App Lifecycle Management** - `lib/main.dart:60-88`
5. **Provider Disposal** - All providers have proper cleanup
6. **LazyBox for Decks** - `lib/providers/deck_provider.dart:6`
7. **Isolate JSON Parsing** - `lib/database/token_database.dart:49`

### ⚠️ Partially Completed (2/11)
1. **Const Constructors** - Declared but not consistently used as `const TokenCard(...)`
2. **Error Handling** - Present in init, missing in CRUD operations

### ❌ Not Implemented (4/11)
1. **ListView itemExtent** - Missing from `content_screen.dart:95` (HIGH PRIORITY)
2. **Selector Pattern** - Still using Consumer, causes unnecessary rebuilds (HIGH PRIORITY)
3. **Search Debouncing** - Direct updates without 300ms delay (MEDIUM PRIORITY)
4. **Database Compaction** - No maintenance service (LOW PRIORITY)

### Next Steps
**Highest Priority Fixes:**
1. Add `itemExtent: 120.0` to ListView (1-line change for 60fps scrolling)
2. Replace `Consumer<TokenProvider>` with `Selector` in content_screen.dart
3. Implement search debouncing in token_search_screen.dart
4. Add try-catch blocks to TokenProvider CRUD operations

---

## 1. Hive Reactive Updates (Big Performance Win) ✅ IMPLEMENTED

**Status:** ✅ Complete - Implemented in `lib/providers/token_provider.dart:12` and `lib/screens/content_screen.dart:89`

### Current Approach (Manual Notifications)
```dart
class TokenProvider extends ChangeNotifier {
  late Box<Item> itemsBox;
  List<Item> _items = [];

  List<Item> get items => _items;

  Future<void> insertItem(Item item) async {
    await itemsBox.add(item);
    _items = itemsBox.values.toList();
    notifyListeners();  // Manual notification
  }
}
```

### Optimized Approach (Hive Built-in Reactivity)
```dart
class TokenProvider extends ChangeNotifier {
  late Box<Item> itemsBox;

  // Expose Hive's listenable for reactive updates
  ValueListenable<Box<Item>> get listenable => itemsBox.listenable();

  List<Item> get items {
    final allItems = itemsBox.values.toList();
    allItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return allItems;
  }

  Future<void> insertItem(Item item) async {
    await itemsBox.add(item);
    // No need for notifyListeners() - Hive handles it
  }
}
```

### In Widget
```dart
// Use ValueListenableBuilder instead of Consumer
ValueListenableBuilder<Box<Item>>(
  valueListenable: provider.listenable,
  builder: (context, box, _) {
    final items = box.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => TokenCard(items[index]),
    );
  },
)
```

**Benefits:**
- Automatically rebuilds only when box contents change
- No manual `notifyListeners()` calls needed
- More efficient than Provider's ChangeNotifier pattern for database-backed data

---

## 2. Provider Optimization Patterns ❌ NOT IMPLEMENTED

**Status:** ❌ Missing - `lib/screens/content_screen.dart:83` uses `Consumer<TokenProvider>` which rebuilds entire token list unnecessarily. Should use `Selector` for targeted rebuilds.

**Priority:** HIGH - Causes unnecessary rebuilds of the entire widget tree

### When to Use Each Pattern

#### Consumer (Rebuilds on Any Provider Change)
```dart
// BAD - Rebuilds entire widget tree when anything in provider changes
Consumer<TokenProvider>(
  builder: (context, provider, child) {
    return Column(
      children: [
        Text('Items: ${provider.items.length}'),
        Text('Multiplier: ${provider.multiplier}'),
      ],
    );
  },
)
```

#### Selector (Rebuilds Only When Specific Value Changes)
```dart
// GOOD - Only rebuilds when multiplier changes
Selector<SettingsProvider, int>(
  selector: (_, settings) => settings.tokenMultiplier,
  builder: (_, multiplier, __) => Text('×$multiplier'),
)

// GOOD - Only rebuilds when items list changes
Selector<TokenProvider, int>(
  selector: (_, provider) => provider.items.length,
  builder: (_, count, __) => Text('$count tokens'),
)
```

#### context.read() (One-Time Access, No Rebuild)
```dart
// GOOD - For button actions that don't need rebuilds
ElevatedButton(
  onPressed: () {
    context.read<TokenProvider>().deleteItem(item);
  },
  child: Text('Delete'),
)
```

#### context.watch() (Equivalent to Consumer)
```dart
// Use for simple cases where you need the whole provider
Widget build(BuildContext context) {
  final items = context.watch<TokenProvider>().items;
  return ListView.builder(...);
}
```

### Best Practices
- Use `Selector` whenever you only need part of a provider
- Use `context.read()` for actions (buttons, callbacks)
- Use `context.watch()` or `Consumer` only when you need reactive updates
- Never use `context.watch()` inside button callbacks (causes unnecessary rebuilds)

---

## 3. ListView Performance Optimization ⚠️ PARTIALLY IMPLEMENTED

**Status:** ⚠️ Partial
- ✅ **Keys**: Properly implemented with `ValueKey(item.key)` in `content_screen.dart:130`
- ❌ **itemExtent**: Missing from ListView.builder at `content_screen.dart:95`
- ⚠️ **Const Constructors**: Declared but not consistently used

**Priority:** HIGH - Adding itemExtent is a 1-line change for 60fps scrolling

### Optimized ListView Configuration

```dart
ListView.builder(
  itemCount: items.length,
  itemExtent: 120.0,  // CRITICAL: Fixed height = 60fps scrolling
  physics: const AlwaysScrollableScrollPhysics(),
  itemBuilder: (context, index) {
    final item = items[index];
    return TokenCard(
      key: ValueKey(item.key),  // CRITICAL: Proper keys for Hive objects
      item: item,
    );
  },
)
```

### Why These Matter

**itemExtent:**
- Tells Flutter the exact height of each item
- Enables instant scroll calculations (no layout measurement needed)
- **Result**: Smooth 60fps scrolling even with 100+ items

**Keys:**
- `ValueKey(item.key)` uses Hive's unique key for each object
- Prevents Flutter from rebuilding identical widgets
- Essential when items can be added/removed/reordered

### Const Constructors
```dart
class TokenCard extends StatelessWidget {
  final Item item;

  const TokenCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Padding(  // Use const wherever possible
      padding: EdgeInsets.all(8.0),
      child: Card(...),
    );
  }
}
```

**Benefits:**
- Const widgets aren't rebuilt unnecessarily
- Reduces garbage collection pressure
- Free performance boost

---

## 4. Error Handling Patterns ⚠️ PARTIALLY IMPLEMENTED

**Status:** ⚠️ Partial
- ✅ Implemented for app initialization in `lib/main.dart:32-41`
- ✅ Implemented for token database loading in `lib/database/token_database.dart:45-57`
- ❌ Missing for CRUD operations in TokenProvider (insertItem, updateItem, deleteItem)
- ❌ Missing user-facing error feedback (SnackBars)

**Priority:** MEDIUM - Important for production but app works without it

### Database Operations
```dart
class TokenProvider extends ChangeNotifier {
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> insertItem(Item item) async {
    try {
      await itemsBox.add(item);
      _errorMessage = null;
    } on HiveError catch (e) {
      _errorMessage = 'Failed to save token: ${e.message}';
      debugPrint('Hive error: $e');
      // Show snackbar or dialog to user
    } catch (e) {
      _errorMessage = 'Unexpected error occurred';
      debugPrint('Error saving item: $e');
    }
    notifyListeners();
  }
}
```

### User Feedback
```dart
// In widget after operation
if (provider.errorMessage != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(provider.errorMessage!)),
  );
}
```

### Common Error Scenarios
- **Disk full**: Hive can't write to storage
- **Corrupted data**: Hive box fails to open
- **Type mismatch**: Hive TypeAdapter version mismatch
- **Concurrent access**: Multiple isolates accessing same box

---

## 5. Development Workflow Optimization ✅ APPLICABLE

**Status:** ✅ Available - Use `flutter pub run build_runner watch` during development

**Note:** This is a development practice, not a code implementation. The Hive initialization in `lib/database/hive_setup.dart` is properly set up to support hot reload.

### Build Runner Watch Mode
```bash
# Instead of manually running build_runner after every model change:
flutter packages pub run build_runner build --delete-conflicting-outputs

# Use watch mode during development:
flutter packages pub run build_runner watch --delete-conflicting-outputs
```

**Benefits:**
- Auto-generates TypeAdapters when you save model files
- No need to remember to run build command
- Faster development iteration

### Hot Reload Considerations
```dart
// In main.dart, ensure Hive is initialized only once
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if already initialized (for hot reload)
  if (!Hive.isBoxOpen('items')) {
    await Hive.initFlutter();
    Hive.registerAdapter(ItemAdapter());
    // ... register other adapters
  }

  runApp(MyApp());
}
```

---

## 6. Lazy Boxes for Infrequent Data ✅ IMPLEMENTED

**Status:** ✅ Complete - `lib/providers/deck_provider.dart:6` uses `LazyBox<Deck>` for memory-efficient deck storage

**Memory Savings:** Estimated ~48KB saved (20 decks * ~2.5KB each not loaded into memory)

### When to Use Lazy Boxes
Lazy boxes load values on-demand instead of keeping everything in memory.

**Use for:**
- Decks (rarely accessed, only when loading)
- Settings (read once on startup)
- Large objects that aren't needed frequently

**Don't use for:**
- Active tokens (accessed constantly during gameplay)
- Search results (needs to be fast)

### Implementation
```dart
class DeckProvider extends ChangeNotifier {
  late LazyBox<Deck> decksBox;  // Use LazyBox instead of Box

  Future<void> init() async {
    decksBox = await Hive.openLazyBox<Deck>('decks');
  }

  Future<List<Deck>> getDecks() async {
    final keys = decksBox.keys.toList();
    final decks = <Deck>[];

    for (final key in keys) {
      final deck = await decksBox.get(key);  // Loaded on-demand
      if (deck != null) decks.add(deck);
    }

    return decks;
  }

  Future<void> saveDeck(Deck deck) async {
    await decksBox.add(deck);  // Same API as regular Box
  }
}
```

**Memory Savings:**
- Regular Box: All decks in memory (~50KB for 20 decks)
- Lazy Box: Only accessed decks in memory (~2KB typical)

---

## 7. Constants Management ✅ IMPLEMENTED

**Status:** ✅ Complete - `lib/utils/constants.dart` fully implemented with all constant classes

**Implemented Constants:**
- GameConstants (multiplier limits, default values)
- HiveTypeIds (type IDs 0-3)
- UIConstants (dimensions, colors, animations)
- PreferenceKeys (SharedPreferences keys)
- AssetPaths (asset file paths)

### Centralized Constants File

```dart
// lib/utils/constants.dart

/// Game mechanics constants
class GameConstants {
  static const int minMultiplier = 1;
  static const int maxMultiplier = 1024;
  static const int defaultTokenAmount = 1;
  static const int defaultTapped = 0;
  static const int defaultSummoningSick = 0;
}

/// Hive type IDs (must be unique and never change)
class HiveTypeIds {
  static const int item = 0;
  static const int tokenCounter = 1;
  static const int deck = 2;
  static const int tokenTemplate = 3;
}

/// UI constants
class UIConstants {
  static const double tokenCardHeight = 120.0;
  static const double tokenCardPadding = 8.0;
  static const double counterPillHeight = 24.0;

  // Color values for MTG colors
  static const String colorWhite = 'W';
  static const String colorBlue = 'U';
  static const String colorBlack = 'B';
  static const String colorRed = 'R';
  static const String colorGreen = 'G';
}

/// SharedPreferences keys
class PreferenceKeys {
  static const String tokenMultiplier = 'tokenMultiplier';
  static const String summoningSicknessEnabled = 'summoningSicknessEnabled';
  static const String favoriteTokens = 'favoriteTokens';
  static const String recentTokens = 'recentTokens';
}

/// Asset paths
class AssetPaths {
  static const String tokenDatabase = 'assets/token_database.json';
}
```

### Usage
```dart
// Instead of:
@HiveType(typeId: 0)
class Item extends HiveObject { ... }

// Use:
@HiveType(typeId: HiveTypeIds.item)
class Item extends HiveObject { ... }

// Instead of:
if (multiplier < 1 || multiplier > 1024) { ... }

// Use:
if (multiplier < GameConstants.minMultiplier ||
    multiplier > GameConstants.maxMultiplier) { ... }
```

**Benefits:**
- Single source of truth
- Easy to change values globally
- Self-documenting code
- Prevents magic number bugs

---

## 8. Proper Cleanup and Disposal ✅ IMPLEMENTED

**Status:** ✅ Complete - All providers properly dispose of resources and app lifecycle is managed

**Implemented:**
- `lib/providers/token_provider.dart:140` - Closes items box on disposal
- `lib/providers/deck_provider.dart:40` - Closes decks box on disposal
- `lib/main.dart:60-88` - App lifecycle observer with proper Hive shutdown

### Provider Disposal
```dart
class TokenProvider extends ChangeNotifier {
  late Box<Item> itemsBox;

  Future<void> init() async {
    itemsBox = await Hive.openBox<Item>('items');
  }

  @override
  void dispose() {
    itemsBox.close();  // Close Hive box
    super.dispose();
  }
}
```

### App Shutdown
```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App going to background or closing
      Hive.close();  // Close all boxes
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(...);
  }
}
```

**Why This Matters:**
- Ensures data is flushed to disk
- Prevents data corruption
- Frees system resources
- iOS/Android requirement for proper backgrounding

---

## 9. Hive Compaction (Long-term Performance) ❌ NOT IMPLEMENTED

**Status:** ❌ Missing - No database maintenance service implemented

**Priority:** LOW - Only matters for long-term disk space usage (20-50% savings possible after months of use)

**When to implement:** If users report large app size or after observing database file growth patterns

### When to Compact
Hive files grow over time as you add/delete objects. Compaction reclaims disk space.

```dart
class DatabaseMaintenanceService {
  static Future<void> performMaintenance() async {
    final itemsBox = Hive.box<Item>('items');
    final decksBox = Hive.box<Deck>('decks');

    // Compact if box has grown large relative to content
    if (itemsBox.length > 50 || _shouldCompact(itemsBox)) {
      await itemsBox.compact();
    }

    if (decksBox.length > 10 || _shouldCompact(decksBox)) {
      await decksBox.compact();
    }
  }

  static bool _shouldCompact(Box box) {
    // Heuristic: compact if file size > 2x expected size
    // (Requires platform channel to get file size)
    return false;  // Implement based on needs
  }
}
```

### When to Run
```dart
// Option 1: On app startup (once per day)
void main() async {
  // ... Hive initialization

  final prefs = await SharedPreferences.getInstance();
  final lastCompact = prefs.getInt('lastCompactionDate') ?? 0;
  final today = DateTime.now().millisecondsSinceEpoch ~/ 86400000;

  if (today > lastCompact) {
    await DatabaseMaintenanceService.performMaintenance();
    await prefs.setInt('lastCompactionDate', today);
  }

  runApp(MyApp());
}

// Option 2: Manual trigger in settings
// "Clear Cache" or "Optimize Database" button
```

**Benefits:**
- Reclaims disk space (can save 20-50% on frequently-modified data)
- Improves read performance
- Reduces app storage footprint

---

## 10. Image and Asset Optimization (Future-Proofing) ✅ IMPLEMENTED (JSON Only)

**Status:** ✅ JSON parsing optimized with compute() isolate in `lib/database/token_database.dart:49`
- Token artwork features not yet implemented (future feature)
- `cached_network_image` package to be added when artwork is implemented

### Token Artwork (Future Feature)
When you add token artwork images:

```dart
// Use cached_network_image package
dependencies:
  cached_network_image: ^3.3.0

// In TokenCard widget
CachedNetworkImage(
  imageUrl: tokenImageUrl,
  memCacheHeight: 200,  // Limit memory usage
  memCacheWidth: 200,
  maxHeightDiskCache: 400,
  maxWidthDiskCache: 400,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  fadeInDuration: Duration(milliseconds: 200),
)
```

### Asset Bundle Optimization
```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/token_database.json
    # Don't include large images directly - use network loading

  # Use asset variants for different screen densities
  # assets/2.0x/, assets/3.0x/ for hdpi/xhdpi
```

### JSON Loading Optimization
```dart
// For large JSON files like TokenDatabase
class TokenDatabase extends ChangeNotifier {
  List<TokenDefinition> _allTokens = [];

  Future<void> loadTokens() async {
    // Load in background isolate to avoid UI jank
    final jsonString = await rootBundle.loadString(AssetPaths.tokenDatabase);

    // Parse in compute() for large files (>100KB)
    _allTokens = await compute(_parseTokens, jsonString);
    notifyListeners();
  }

  static List<TokenDefinition> _parseTokens(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((json) => TokenDefinition.fromJson(json))
        .toList();
  }
}
```

**Benefits:**
- Keeps UI responsive during JSON parsing
- Memory cache prevents re-downloading images
- Disk cache works offline
- Automatic size limits prevent OOM crashes

---

## 11. Additional Performance Tips ❌ NOT IMPLEMENTED

**Status:** ❌ Missing multiple optimizations:
- Anonymous functions in build() creating new closures on every rebuild
- No RepaintBoundary usage
- **Search debouncing missing** in `lib/screens/token_search_screen.dart:35-37` (MEDIUM PRIORITY)

### Avoid Anonymous Functions in build()
```dart
// BAD - Creates new function object on every rebuild
ListView.builder(
  itemBuilder: (context, index) {
    return GestureDetector(
      onTap: () => _handleTap(items[index]),  // New closure every rebuild
      child: TokenCard(items[index]),
    );
  },
)

// GOOD - Pass data to widget, handle tap inside
ListView.builder(
  itemBuilder: (context, index) {
    return TokenCard(
      item: items[index],
      onTap: _handleTap,  // Same function reference
    );
  },
)
```

### Use RepaintBoundary for Complex Widgets
```dart
// For complex widgets that don't change often
RepaintBoundary(
  child: ComplexTokenVisualization(item: item),
)
```

### Debounce Search Input
```dart
// In TokenSearchView
Timer? _debounce;

void _onSearchChanged(String query) {
  _debounce?.cancel();
  _debounce = Timer(Duration(milliseconds: 300), () {
    // Only search after user stops typing
    setState(() => _searchQuery = query);
  });
}

@override
void dispose() {
  _debounce?.cancel();
  super.dispose();
}
```

---

## Summary

### ✅ High-Impact Optimizations - COMPLETED (3/5)
1. ✅ **Use Hive's ValueListenableBuilder** - Automatic reactive updates
2. ❌ **Add itemExtent to ListViews** - 60fps scrolling (NEEDS IMPLEMENTATION)
3. ✅ **Use proper Keys** - Prevents unnecessary rebuilds
4. ❌ **Use Selector instead of Consumer** - Targeted rebuilds (NEEDS IMPLEMENTATION)
5. ✅ **Run build_runner in watch mode** - Faster development

### ⚠️ Medium-Impact Optimizations - PARTIALLY COMPLETED (2/4)
1. ✅ **Centralize constants** - Maintainability and consistency
2. ⚠️ **Add error handling** - Better user experience (PARTIAL - missing CRUD operations)
3. ⚠️ **Use const constructors** - Free performance boost (PARTIAL - not consistently used)
4. ❌ **Debounce search** - Prevents excessive filtering (NEEDS IMPLEMENTATION)

### ✅ Low-Impact/Future Optimizations - MOSTLY COMPLETE (3/4)
1. ✅ **Lazy boxes for decks** - Minor memory savings
2. ❌ **Database compaction** - Long-term disk space management (FUTURE)
3. N/A **Image caching** - Only relevant when adding artwork (FUTURE FEATURE)
4. ✅ **Isolate parsing** - Only needed if JSON parsing is slow

### 🎯 Immediate Action Items (Quick Wins)
1. **Add `itemExtent: 120.0` to ListView.builder** - Single line change in `content_screen.dart:95`
2. **Replace Consumer with Selector** - Prevents unnecessary full-list rebuilds in `content_screen.dart:83`
3. **Add search debouncing** - 300ms delay in `token_search_screen.dart` to prevent excessive filtering

---

## When to Profile

Before optimizing blindly, use Flutter DevTools to profile:

```bash
flutter run --profile
# Open DevTools, use Performance tab
```

**Look for:**
- Frame rendering time (aim for <16ms for 60fps)
- Overdraw (red areas in Performance Overlay)
- Memory leaks (increasing memory over time)
- Excessive rebuilds (Enable performance overlay in app)

**Enable performance overlay:**
```dart
MaterialApp(
  showPerformanceOverlay: true,  // Shows FPS
  debugShowCheckedModeBanner: false,
  // ...
)
```

---

## Performance Monitoring Recommendations

**Current Performance Status:** Good - App is functional and responsive

**When to revisit optimizations:**
1. **If scrolling feels laggy** → Add itemExtent to ListView (section 3)
2. **If UI feels sluggish during token operations** → Implement Selector pattern (section 2)
3. **If search typing feels slow** → Add debouncing (section 11)
4. **If app size grows significantly** → Implement compaction (section 9)
5. **Before production release** → Add comprehensive error handling (section 4)

**Profiling checklist:**
- Run `flutter run --profile` and check frame times (aim for <16ms)
- Enable performance overlay to spot jank
- Use DevTools to identify unnecessary rebuilds
- Monitor memory usage during extended gameplay sessions

**Migration Status:** ✅ Complete - Flutter migration finished, 64% of optimizations implemented
