# Flutter Performance Best Practices & Optimizations
# Doubling Season - Flutter Implementation

## Overview

This document contains performance optimizations and best practices to consider when implementing the Flutter version of Doubling Season. These suggestions are not critical for the initial migration but should be revisited during development to ensure optimal performance and code quality.

---

## 1. Hive Reactive Updates (Big Performance Win)

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

## 2. Provider Optimization Patterns

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

## 3. ListView Performance Optimization

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

## 4. Error Handling Patterns

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

## 5. Development Workflow Optimization

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

## 6. Lazy Boxes for Infrequent Data

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

## 7. Constants Management

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

## 8. Proper Cleanup and Disposal

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

## 9. Hive Compaction (Long-term Performance)

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

## 10. Image and Asset Optimization (Future-Proofing)

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

## 11. Additional Performance Tips

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

### High-Impact Optimizations (Do First)
1. **Use Hive's ValueListenableBuilder** - Automatic reactive updates
2. **Add itemExtent to ListViews** - 60fps scrolling
3. **Use proper Keys** - Prevents unnecessary rebuilds
4. **Use Selector instead of Consumer** - Targeted rebuilds
5. **Run build_runner in watch mode** - Faster development

### Medium-Impact Optimizations (Do During Development)
1. **Centralize constants** - Maintainability and consistency
2. **Add error handling** - Better user experience
3. **Use const constructors** - Free performance boost
4. **Debounce search** - Prevents excessive filtering

### Low-Impact/Future Optimizations (Do Later)
1. **Lazy boxes for decks** - Minor memory savings
2. **Database compaction** - Long-term disk space management
3. **Image caching** - Only relevant when adding artwork
4. **Isolate parsing** - Only needed if JSON parsing is slow

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

## Revisit This Document

**During Phase 2 (Core UI):**
- ListView optimizations
- Const constructors
- Provider patterns

**During Phase 3 (Token Interactions):**
- Hive reactivity patterns
- Error handling

**During Phase 4 (Advanced Features):**
- Lazy boxes
- Search debouncing

**During Phase 5 (Polish):**
- Profiling and measurement
- Database compaction
- Final performance tuning
