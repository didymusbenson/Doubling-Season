# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Doubling Season** is a cross-platform Flutter app for tracking Magic: The Gathering tokens during gameplay. It manages token stacks with tapped/untapped states, summoning sickness, counters (+1/+1, -1/-1, and custom counters), and provides a searchable database of 300+ token types.

The app targets iOS, Android, Web, macOS, and Windows platforms using Flutter's single codebase approach.

## Common Development Commands

### Building and Running
```bash
# Check Flutter installation
flutter doctor

# Run app (iOS simulator/Android emulator)
flutter run

# Run on specific device
flutter devices
flutter run -d <device-id>

# Build for production
flutter build ios          # iOS
flutter build apk          # Android APK
flutter build appbundle    # Android App Bundle
flutter build web          # Web
flutter build macos        # macOS
flutter build windows      # Windows
```

### Code Generation
Hive models require generated adapter code:
```bash
# Generate Hive adapters (after modifying @HiveType models)
flutter pub run build_runner build

# Watch for changes and auto-generate
flutter pub run build_runner watch

# Clean and regenerate
flutter pub run build_runner build --delete-conflicting-outputs
```

### Data Generation
To regenerate the token database from upstream Magic token data:
```bash
cd "AI STUFF"
python3 process_tokens.py
```
This fetches token data from the Cockatrice GitHub repository, processes it, and outputs `assets/token_database.json`.

The script:
- Fetches XML from `https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml`
- Parses token definitions (name, P/T, colors, abilities, type)
- Deduplicates using key: `name|pt|colors|type|abilities` (note: abilities are included in dedup key)
- Removes reminder text and normalizes formatting
- Outputs sorted JSON array to `assets/token_database.json`

### Testing
Testing is performed through manual functional testing by human experts. Do not generate automated test code.

## Architecture

### State Management (Provider Pattern)
The app uses the Provider package for state management with ChangeNotifier:

**TokenProvider** (`lib/providers/token_provider.dart`)
- Manages `Box<Item>` from Hive
- Provides reactive updates via `ValueListenable<Box<Item>>`
- Methods: `insertItem()`, `updateItem()`, `deleteItem()`, `addTokens()`, `tapTokens()`, `copyToken()`, `boardWipeDelete()`
- Critical: Uses `ValueListenableBuilder` for efficient Hive box updates

**SettingsProvider** (`lib/providers/settings_provider.dart`)
- Uses SharedPreferences for app-wide settings
- Stores: `tokenMultiplier`, `summoningSicknessEnabled`, `favoriteTokens`, `recentTokens`
- Notifies listeners on changes

**DeckProvider** (`lib/providers/deck_provider.dart`)
- Manages `LazyBox<Deck>` from Hive (memory optimized)
- Methods: `saveDeck()`, `deleteDeck()`, async `decks` getter

Provider setup in `main.dart`:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: tokenProvider),
    ChangeNotifierProvider.value(value: deckProvider),
    ChangeNotifierProvider.value(value: settingsProvider),
  ],
  child: MaterialApp(...)
)
```

### Data Persistence

**Hive (NoSQL Database)**
- Embedded database for Flutter (replaces SwiftData from iOS version)
- Models: `Item`, `TokenCounter`, `Deck`, `TokenTemplate`
- Type IDs (NEVER change - risk of data corruption):
  - `0` = Item
  - `1` = TokenCounter
  - `2` = Deck
  - `3` = TokenTemplate
- Setup: `lib/database/hive_setup.dart`
- Boxes: `items` (normal Box), `decks` (LazyBox for memory efficiency)

**SharedPreferences**
- Simple key-value store for user settings
- Managed by SettingsProvider
- Stores: multiplier, summoning sickness toggle, favorites list, recent tokens

**Token Database**
- Location: `assets/token_database.json` (bundled with app)
- Format: JSON array of TokenDefinition objects
- Loading: Asynchronous via `TokenDatabase.loadTokens()` using `compute()` isolate for performance
- Access: via `TokenDatabase` instance in TokenSearchScreen

**Auto-save Mechanism**
- Hive models extend `HiveObject`
- Changes persisted via `.save()` method (called automatically by setters)
- Item setters implement validation logic with auto-correction

### Key Screen Components

**ContentScreen** (`lib/screens/content_screen.dart`) - Main game board
- Displays token list using `ValueListenableBuilder` with Hive box
- FloatingActionMenu with game actions:
  - New token (opens TokenSearchScreen)
  - Untap all
  - Clear summoning sickness
  - Save deck
  - Load deck (opens LoadDeckSheet)
  - Board wipe
- Empty state with "Create your first token" prompt
- MultiplierView overlay at bottom
- AppBar with settings and help buttons

**TokenCard** (`lib/widgets/token_card.dart`) - Compact token display
- Shows name, P/T, abilities, counters, tapped/untapped counts
- Color identity border gradient (W=yellow, U=blue, B=purple, R=red, G=green, colorless=gray)
- Counter pills displayed with high contrast (solid background, white text)
- Tap to open ExpandedTokenScreen
- Quick actions: add/remove (with multiplier), tap/untap, copy
- Long-press for bulk operations
- Special handling for Scute Swarm (doubling button) and Emblems (no tapped/untapped UI)

**ExpandedTokenScreen** (`lib/screens/expanded_token_screen.dart`) - Detailed editor
- Editable fields for all token properties (name, P/T, abilities)
- ColorSelectionButton for W/U/B/R/G color identity
- Counter management via CounterPillView and CounterManagementPillView
- CounterSearchScreen dialog for adding new counters
- Stack splitting via SplitStackSheet
- Shows summoning sickness status
- Delete button

**TokenSearchScreen** (`lib/screens/token_search_screen.dart`) - Database search
- Three tabs: All / Recent / Favorites
- Live search with category filtering (Creature, Artifact, Enchantment, Emblem, Dungeon, Counter, Other)
- "Create Custom Token" button opens NewTokenSheet
- Quantity dialog applies multiplier on selection
- Uses `TokenDatabase` for loading and filtering

**SplitStackSheet** (`lib/widgets/split_stack_sheet.dart`) - Stack splitting
- Distribute tokens between original and new stack
- Tapped/untapped allocation with steppers
- Option to copy counters to both stacks
- Early dismiss pattern to avoid state crashes

### Data Models

**Item** (Hive-persisted active token):
```dart
@HiveType(typeId: 0)
class Item extends HiveObject {
  @HiveField(0) String name;
  @HiveField(1) String pt;
  @HiveField(2) String abilities;
  @HiveField(3) String _colors;              // Private with validation
  @HiveField(4) int _amount;                 // Private with auto-correction
  @HiveField(5) int _tapped;
  @HiveField(6) int _summoningSick;
  @HiveField(7) int _plusOneCounters;        // +1/+1 counters
  @HiveField(8) int _minusOneCounters;       // -1/-1 counters (auto-cancel)
  @HiveField(9) List<TokenCounter> counters; // Custom counters
  @HiveField(10) DateTime createdAt;

  // Computed properties
  bool get isEmblem => name/abilities contains "emblem"
  int get netPlusOneCounters => plusOneCounters - minusOneCounters
  String get formattedPowerToughness // Shows modified P/T
}
```

**TokenCounter** (Hive-persisted):
```dart
@HiveType(typeId: 1)
class TokenCounter extends HiveObject {
  @HiveField(0) String name;
  @HiveField(1) int amount;
}
```

**Deck** (Hive-persisted):
```dart
@HiveType(typeId: 2)
class Deck extends HiveObject {
  @HiveField(0) String name;
  @HiveField(1) List<TokenTemplate> templates;
}
```

**TokenTemplate** (Hive-persisted, nested in Deck):
```dart
@HiveType(typeId: 3)
class TokenTemplate extends HiveObject {
  @HiveField(0) String name;
  @HiveField(1) String pt;
  @HiveField(2) String abilities;
  @HiveField(3) String colors;

  factory TokenTemplate.fromItem(Item item)
  Item toItem({int amount, bool createTapped})
}
```

**TokenDefinition** (NOT persisted, loaded from JSON):
```dart
class TokenDefinition {
  String name;
  String abilities;
  String pt;
  String colors;
  String type;

  // Composite ID matching deduplication logic
  String get id => '$name|$pt|$colors|$type|$abilities'

  bool matches({required String searchQuery})
  Item toItem({required int amount, required bool createTapped})
  Category get category // Creature, Artifact, Emblem, etc.
}
```

### Data Flow

```
assets/token_database.json (bundled asset)
    ↓
TokenDatabase.loadTokens() (async with compute isolate)
    ↓
filteredTokens (search/category filters)
    ↓
User selects token + quantity dialog
    ↓
Item created with multiplier applied
    ↓
tokenProvider.insertItem(newItem)
    ↓
ValueListenable updates → ContentScreen rebuilds with TokenCard
```

### Multiplier System
- Global setting stored via SharedPreferences (`tokenMultiplier`, range 1-1024)
- Applied at creation time: `finalAmount = quantity * multiplier`
- Used in: TokenSearchScreen, NewTokenSheet, TokenCard actions, ExpandedTokenScreen
- MultiplierView provides ±1 increment/decrement buttons (NOT powers of 2)
- Long-press opens manual input dialog

### Counter Management
- **Power/Toughness Counters**: +1/+1 and -1/-1 auto-cancel each other
  - `netPlusOneCounters = plusOneCounters - minusOneCounters`
  - Applied to entire stack automatically
  - Display shows modified P/T with colored background when counters present

- **Custom Counters**: Selected via CounterSearchScreen from predefined list
  - Can be applied to entire stack or individual token
  - Stack splitting: user chooses whether to copy counters

### Summoning Sickness
- Toggleable via SharedPreferences (`summoningSicknessEnabled`)
- Tracked per-stack with `summoningSick` count
- Applied when tokens are added/copied
- Display shows summoning sickness icon + count
- Toggle setting via long-press on summoning sickness button

### Special Token Handling
- **Emblems**: Detected via `isEmblem` computed property (name/abilities contains "emblem")
  - No tapped/untapped UI
  - No color bar gradient
  - Centered layout

- **Scute Swarm**: Special doubling button that doubles stack size

## Important Implementation Notes

### Recent Migration Notes
The app was migrated from SwiftUI (iOS-only) to Flutter (cross-platform). Key architecture changes:
- **State Management**: SwiftUI @State/@StateObject → Provider + ChangeNotifier
- **Persistence**: SwiftData → Hive + SharedPreferences
- **Navigation**: NavigationStack/sheets → Navigator.push + MaterialPageRoute
- **Toolbar**: iOS AppBar icons → FloatingActionMenu (bottom-right)
- **Multiplier**: Changed from ×2/÷2 to ±1 increments

### Code Patterns to Follow

**Accessing providers in widgets**:
```dart
// Read-only access (doesn't rebuild on changes)
final tokenProvider = context.read<TokenProvider>();

// Reactive access (rebuilds on changes)
final multiplier = context.watch<SettingsProvider>().tokenMultiplier;

// Or use Consumer widget
Consumer<TokenProvider>(
  builder: (context, tokenProvider, child) {
    return ListView(...);
  },
)
```

**Reading token data**:
```dart
// In TokenSearchScreen
final _tokenDatabase = TokenDatabase();

@override
void initState() {
  super.initState();
  _tokenDatabase.loadTokens(); // Async load via compute isolate
}
```

**Creating tokens with multiplier**:
```dart
final settingsProvider = context.read<SettingsProvider>();
final tokenProvider = context.read<TokenProvider>();

final finalAmount = quantity * settingsProvider.tokenMultiplier;
final newItem = definition.toItem(
  amount: finalAmount,
  createTapped: _createTapped,
);

// Apply summoning sickness if enabled
if (settingsProvider.summoningSicknessEnabled) {
  newItem.summoningSick = finalAmount;
}

await tokenProvider.insertItem(newItem);
```

**Reactive Hive updates**:
```dart
// In ContentScreen
ValueListenableBuilder<Box<Item>>(
  valueListenable: tokenProvider.itemsListenable,
  builder: (context, box, _) {
    final items = box.values.toList();
    if (items.isEmpty) {
      return EmptyStateWidget();
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => TokenCard(item: items[index]),
    );
  },
)
```

**Counter management**:
```dart
// +1/+1 counters auto-cancel with -1/-1
item.plusOneCounters = item.plusOneCounters + 2;   // Adds 2 +1/+1 counters
item.minusOneCounters = item.minusOneCounters + 1; // Adds 1 -1/-1 counter
item.save(); // Persist to Hive

// Custom counters
item.counters.add(TokenCounter(name: "Shield", amount: 1));
item.save();

// Remove counter
final counter = item.counters.firstWhere((c) => c.name == "Shield");
counter.amount -= 1;
if (counter.amount <= 0) {
  item.counters.remove(counter);
}
item.save();
```

**Stack splitting pattern** (early dismiss to avoid crashes):
```dart
// In SplitStackSheet
ElevatedButton(
  onPressed: () {
    Navigator.of(context).pop(); // Dismiss FIRST

    // Perform split after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Create new item with split counts
      final newItem = Item(
        name: originalItem.name,
        pt: originalItem.pt,
        // ... split allocation
      );
      tokenProvider.insertItem(newItem);

      // Update original item
      originalItem.amount = remainingAmount;
      originalItem.tapped = remainingTapped;
      originalItem.save();
    });
  },
  child: Text('Split Stack'),
)
```

**Navigation patterns**:
```dart
// Push new screen
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => TokenSearchScreen(),
  ),
);

// Show dialog/bottom sheet
showDialog(
  context: context,
  builder: (context) => AlertDialog(...),
);

showModalBottomSheet(
  context: context,
  builder: (context) => LoadDeckSheet(),
);
```

### UI Conventions
- Use `Navigator.of(context).push()` for full-screen navigation
- Use `showDialog()` for alerts and confirmations
- Use `showModalBottomSheet()` for secondary sheets (deck loading, split stack)
- Color border gradient: `ColorUtils.gradientForColors()` creates LinearGradient from color identity string
- Empty states use centered Column with Text + action button
- Emblems have centered layout without color borders or tapped/untapped UI
- Counter pills use high contrast colors (solid background, white text) for light/dark mode

### Hive Type ID Management
**CRITICAL**: Never change Hive type IDs once assigned - this causes data corruption.

Current assignments (in `lib/utils/constants.dart`):
```dart
class HiveTypeIds {
  static const int item = 0;
  static const int tokenCounter = 1;
  static const int deck = 2;
  static const int tokenTemplate = 3;
}
```

When adding new Hive models:
1. Assign next available type ID (4, 5, 6, ...)
2. Add to HiveTypeIds class
3. Register in `lib/database/hive_setup.dart`

### Item Validation Logic
The `Item` model includes automatic validation in setters:
- Setting `amount` auto-corrects `tapped` and `summoningSick` if they exceed the new amount
- All setters call `.save()` to persist changes
- Counter cancellation: `netPlusOneCounters` computes `plusOneCounters - minusOneCounters`

### Token Database Deduplication
**Critical**: TokenDefinition.id must match Python script deduplication logic:
- Composite ID: `name|pt|colors|type|abilities`
- This ensures all token variants appear in search results
- Must match `process_tokens.py` line 118

### Python Script Maintenance
When modifying `process_tokens.py`:
- The deduplication key at line 118 must include abilities: `f"{name}|{token['pt']}|{token['colors']}|{type_text}|{abilities}"`
- Output path is hardcoded: `"assets/token_database.json"` (changed from `Doubling Season/TokenDatabase.json`)
- Run from repository root: `python3 "AI STUFF/process_tokens.py"`

## Future Feature Context

See `FeedbackAndIdeas.md` for user-requested features:
- Token artwork (download/on-demand/user upload)
- Combat tracking interface
- Condensed view mode
- New toolbar positioning (floating toolbox already implemented in Flutter version)

See `Premium.md` for planned paid features:
- Commander-specific tools (Brudiclad, Krenko, Chatterfang)
- Token modifier card toggles (Academy Manufactor, etc.)

## Project Structure

```
lib/
├── main.dart                           # Entry point, Provider setup, Hive init
├── models/
│   ├── item.dart                       # Active token model (Hive)
│   ├── item.g.dart                     # Generated Hive adapter
│   ├── token_counter.dart              # Counter model (Hive)
│   ├── token_counter.g.dart            # Generated adapter
│   ├── deck.dart                       # Deck model (Hive)
│   ├── deck.g.dart                     # Generated adapter
│   ├── token_template.dart             # Deck template (Hive)
│   ├── token_template.g.dart           # Generated adapter
│   └── token_definition.dart           # Database token (non-persisted)
├── screens/
│   ├── content_screen.dart             # Main game screen
│   ├── token_search_screen.dart        # Token database search
│   ├── expanded_token_screen.dart      # Token editor
│   ├── counter_search_screen.dart      # Counter selection
│   └── about_screen.dart               # App info
├── widgets/
│   ├── token_card.dart                 # Compact token display
│   ├── floating_action_menu.dart       # Main game actions menu
│   ├── multiplier_view.dart            # Multiplier control
│   ├── split_stack_sheet.dart          # Stack splitting
│   ├── load_deck_sheet.dart            # Deck loading
│   ├── new_token_sheet.dart            # Manual token creation
│   ├── counter_pill.dart               # Counter display
│   ├── counter_management_pill.dart    # Interactive counter
│   └── color_selection_button.dart     # Color identity selector
├── providers/
│   ├── token_provider.dart             # Token operations + Hive box
│   ├── deck_provider.dart              # Deck operations + Hive box
│   └── settings_provider.dart          # SharedPreferences wrapper
├── database/
│   ├── hive_setup.dart                 # Hive initialization
│   ├── token_database.dart             # Token JSON loader
│   └── counter_database.dart           # Predefined counters
└── utils/
    ├── constants.dart                  # Game/UI/Hive constants
    └── color_utils.dart                # MTG color helpers

assets/
└── token_database.json                 # 300+ bundled tokens

AI STUFF/
├── process_tokens.py                   # Token database generator
├── Improvements.md                     # Current bug fixes and tasks
├── FeedbackAndIdeas.md                 # User feature requests
├── Premium.md                          # Planned paid features
└── [other AI documentation]

android/                                # Android platform files
ios/                                    # iOS platform files (no native Swift code)
web/                                    # Web platform files
macos/                                  # macOS platform files
windows/                                # Windows platform files
```

## Dependencies (pubspec.yaml)

Key packages:
- **provider**: State management (^6.1.0)
- **hive**: NoSQL database (^2.2.3)
- **hive_flutter**: Flutter integration (^1.1.0)
- **shared_preferences**: Settings storage (^2.2.2)
- **gradient_borders**: UI enhancement (^1.0.0)
- **wakelock_plus**: Keep screen awake during gameplay (^1.1.0)

Dev dependencies:
- **build_runner**: Code generation (^2.4.0)
- **hive_generator**: Generate Hive adapters (^2.0.0)

## Platform-Specific Notes

- **iOS**: Uses Flutter's iOS engine, no native Swift code (unlike original SwiftUI app)
- **Android**: Full Android support, Material Design 3 theming
- **Web/Desktop**: Supported but primarily tested on mobile platforms
- **Asset Loading**: `rootBundle.loadString()` works cross-platform for token_database.json
