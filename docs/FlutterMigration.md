# Flutter Migration Guide
# Doubling Season - SwiftUI to Flutter Migration

## Executive Summary

This document outlines the migration path from the current iOS-only SwiftUI implementation to a cross-platform Flutter architecture. The migration involves converting SwiftUI views to Flutter widgets, replacing SwiftData persistence with a Flutter-compatible solution (sqflite or drift), and adapting iOS-specific patterns to multi-platform equivalents.

**Estimated Effort**: Medium-Large (3-6 weeks for full feature parity)
- Core UI migration: 2-3 weeks
- Data persistence layer: 1 week
- Platform-specific polish: 1-2 weeks

**Target Platforms**: iOS, Android (Web/Desktop optional)

---

## High-Level Architecture Changes

### Directory Structure

**Current (SwiftUI)**:
```
Doubling Season/
├── Doubling_SeasonApp.swift
├── ContentView.swift
├── Item.swift
├── Deck.swift
├── Views/
│   ├── TokenView.swift
│   ├── ExpandedTokenView.swift
│   └── ...
└── TokenDatabase.json
```

**Proposed (Flutter)**:
```
doubling_season/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── models/
│   │   ├── item.dart                # Token model
│   │   ├── deck.dart                # Deck model
│   │   ├── token_definition.dart
│   │   └── counter.dart
│   ├── providers/
│   │   ├── token_provider.dart      # State management for tokens
│   │   ├── deck_provider.dart
│   │   └── settings_provider.dart   # AppStorage equivalents
│   ├── database/
│   │   ├── database_helper.dart     # sqflite/drift setup
│   │   └── token_database.dart      # JSON loading logic
│   ├── screens/
│   │   ├── content_screen.dart      # Main game view
│   │   ├── expanded_token_screen.dart
│   │   └── token_search_screen.dart
│   ├── widgets/
│   │   ├── token_card.dart          # TokenView equivalent
│   │   ├── counter_pill.dart
│   │   ├── multiplier_view.dart
│   │   └── split_stack_sheet.dart
│   └── utils/
│       ├── color_utils.dart
│       └── constants.dart
├── assets/
│   └── token_database.json
└── pubspec.yaml
```

### Component Philosophy Changes

| SwiftUI Concept | Flutter Equivalent | Notes |
|-----------------|-------------------|-------|
| View Protocol | Widget (StatelessWidget/StatefulWidget) | All UI components are widgets |
| @State | setState() in StatefulWidget | Local component state |
| @StateObject | ChangeNotifier + Provider | For observable objects |
| @ObservedObject | Provider/Consumer | For injected observables |
| @AppStorage | SharedPreferences | Persistent key-value storage |
| @Query (SwiftData) | ValueListenableBuilder + Hive | Reactive database queries |
| @Environment | Provider.of() or context.read() | Dependency injection |
| ModelContainer | Database singleton | Initialize in main() |
| NavigationStack | Navigator 2.0 or go_router | Declarative routing |

### State Management Choice

**Recommended**: Provider or Riverpod
- Provider: Simpler, officially recommended by Flutter team
- Riverpod: More powerful, better for complex state dependencies

For this app, **Provider** is sufficient given the relatively straightforward state needs.

---

## General Conversion Patterns

### 1. SwiftUI Views → Flutter Widgets

#### Basic View Structure
**SwiftUI**:
```swift
struct MyView: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("\(count)")
            Button("Increment") { count += 1 }
        }
    }
}
```

**Flutter**:
```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count'),
        ElevatedButton(
          onPressed: () => setState(() => count++),
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

### 2. Layout Components

| SwiftUI | Flutter | Notes |
|---------|---------|-------|
| VStack | Column | Vertical linear layout |
| HStack | Row | Horizontal linear layout |
| ZStack | Stack | Overlapping children |
| Spacer() | Spacer() / Expanded() | Fill available space |
| padding() | Padding(padding: EdgeInsets...) | Wrapper widget |
| background() | Container(decoration: BoxDecoration()) | Use Container or DecoratedBox |
| frame() | SizedBox / Container(width:, height:) | Fixed dimensions |
| List | ListView.builder | Scrollable list |

### 3. Sheets and Modals

**SwiftUI .sheet()**:
```swift
.sheet(isPresented: $showSheet) {
    DetailView()
}
```

**Flutter showModalBottomSheet()** (for bottom sheets):
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => DetailScreen(),
);
```

**Flutter showDialog()** (for centered dialogs):
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    content: DetailWidget(),
  ),
);
```

**Pattern**: Replace all `.sheet()` modifiers with button handlers calling `showModalBottomSheet()` or `Navigator.push()` for full-screen.

### 4. Alerts and Dialogs

**SwiftUI**:
```swift
.alert("Title", isPresented: $showAlert) {
    TextField("Enter amount", text: $amount)
    Button("OK") { }
}
```

**Flutter**:
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Title'),
    content: TextField(
      onChanged: (value) => setState(() => amount = value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('OK'),
      ),
    ],
  ),
);
```

### 5. Navigation

**SwiftUI NavigationStack**:
```swift
NavigationStack {
    List { }
        .navigationTitle("Tokens")
}
```

**Flutter**:
```dart
Scaffold(
  appBar: AppBar(title: Text('Tokens')),
  body: ListView.builder(...),
)
```

### 6. Gestures

| SwiftUI | Flutter | Implementation |
|---------|---------|----------------|
| .onTapGesture | GestureDetector(onTap: ...) | Simple tap |
| .onLongPressGesture | GestureDetector(onLongPress: ...) | Long press |
| simultaneousGesture | GestureDetector(onTap: ..., onLongPress: ...) | Multiple gestures on same widget |

### 7. State Management (@State, @AppStorage, @Query)

#### @State → setState()
Local component state moves to StatefulWidget's State class.

#### @AppStorage → SharedPreferences
**SwiftUI**:
```swift
@AppStorage("tokenMultiplier") private var multiplier = 1
```

**Flutter** (setup in settings_provider.dart):
```dart
class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  int get tokenMultiplier => _prefs.getInt('tokenMultiplier') ?? 1;

  Future<void> setTokenMultiplier(int value) async {
    await _prefs.setInt('tokenMultiplier', value);
    notifyListeners();
  }
}
```

#### @Query (SwiftData) → Hive Boxes
**SwiftUI**:
```swift
@Query(sort: \Item.createdAt) private var items: [Item]
```

**Flutter** (using Hive):
```dart
class TokenProvider extends ChangeNotifier {
  late Box<Item> itemsBox;

  Future<void> init() async {
    itemsBox = await Hive.openBox<Item>('items');
  }

  List<Item> get items {
    final allItems = itemsBox.values.toList();
    allItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return allItems;
  }

  Future<void> insertItem(Item item) async {
    await itemsBox.add(item);
    notifyListeners();
  }

  Future<void> updateItem(Item item) async {
    await item.save(); // HiveObject method
    notifyListeners();
  }
}
```

**Usage in widget**:
```dart
Consumer<TokenProvider>(
  builder: (context, provider, child) {
    return ListView.builder(
      itemCount: provider.items.length,
      itemBuilder: (context, index) => TokenCard(provider.items[index]),
    );
  },
)
```

### 8. SwiftData → Hive

**Migration Strategy**:
1. Add `@HiveType` and `@HiveField` annotations to model classes
2. Run code generator to create TypeAdapters
3. Register adapters and open boxes in `main()`
4. Wrap Hive box operations in Provider classes for reactive updates

**Why Hive over SQL**:
- SwiftData is object-oriented, not relational - Hive matches this paradigm
- No complex queries needed (just CRUD operations)
- 3-10x faster than SQL for small datasets
- Less boilerplate (no toMap/fromMap, no schema migrations)
- Perfect for 10-100 objects per collection

**Code Example**:
```dart
// models/item.dart
import 'package:hive/hive.dart';

part 'item.g.dart'; // Generated file

@HiveType(typeId: 0)
class Item extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String pt;

  @HiveField(2)
  String abilities;

  @HiveField(3)
  String colors;

  @HiveField(4)
  int amount;

  @HiveField(5)
  int tapped;

  @HiveField(6)
  int summoningSick;

  @HiveField(7)
  int plusOneCounters;

  @HiveField(8)
  int minusOneCounters;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  List<TokenCounter> counters;

  Item({
    required this.name,
    required this.pt,
    this.abilities = '',
    this.colors = '',
    this.amount = 1,
    this.tapped = 0,
    this.summoningSick = 0,
    this.plusOneCounters = 0,
    this.minusOneCounters = 0,
    required this.createdAt,
    this.counters = const [],
  });

  // Computed properties (not stored)
  int get netPlusOneCounters => plusOneCounters - minusOneCounters;
  bool get isEmblem => name.toLowerCase().contains('emblem');
}
```

**Generate TypeAdapter**:
```bash
flutter packages pub run build_runner build
# Creates item.g.dart with ItemAdapter
```

**Initialize in main.dart**:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(TokenCounterAdapter());
  Hive.registerAdapter(DeckAdapter());

  runApp(MyApp());
}
```

### 9. Animations

| SwiftUI | Flutter | Notes |
|---------|---------|-------|
| withAnimation { } | setState() (implicit) | Flutter has implicit animations for most properties |
| .animation() | AnimatedContainer, AnimatedOpacity | Wrapper widgets |
| .transition() | AnimatedSwitcher | Widget transitions |

For most cases, Flutter's implicit animations are sufficient. Explicit animations require AnimationController.

---

## Component-by-Component Migration Checklist

### Core App Components

#### ✓ Doubling_SeasonApp.swift → main.dart
- [ ] Create `main()` entry point
- [ ] Initialize Hive with `await Hive.initFlutter()`
- [ ] Register all TypeAdapters (ItemAdapter, TokenCounterAdapter, DeckAdapter, TokenTemplateAdapter)
- [ ] Initialize SharedPreferences
- [ ] Initialize all providers (call their init() methods to open Hive boxes)
- [ ] Call `runApp()` with MultiProvider wrapping MaterialApp
- [ ] Configure MaterialApp with theme (light/dark mode support)
- [ ] Remove ModelContainer setup (replaced by Hive boxes)

#### ✓ ContentView.swift → screens/content_screen.dart
- [ ] Convert to StatelessWidget consuming TokenProvider
- [ ] Replace `@Query` items with `Consumer<TokenProvider>` or `context.watch<TokenProvider>()`
- [ ] Convert toolbar buttons to AppBar actions or FloatingActionButton
  - [ ] Plus button → FAB with onPressed: () => showTokenSearch()
  - [ ] Untap all → AppBar action calling provider.untapAll()
  - [ ] Clear summoning sickness → AppBar action
  - [ ] Save deck → AppBar action with long-press for name input
  - [ ] Load deck → AppBar action opening LoadDeckSheet
  - [ ] Board wipe → AppBar action with confirmation dialog
- [ ] Convert empty state to custom widget (not ContentUnavailableView)
  - [ ] Show when `provider.items.isEmpty`
  - [ ] Make "Create your first token" a blue TextButton
- [ ] Replace `.sheet(isPresented:)` with button handlers calling `showModalBottomSheet()` or `Navigator.push()`
- [ ] Add MultiplierView overlay at bottom using Stack + Positioned

#### ✓ Item.swift → models/item.dart
- [ ] Convert SwiftData @Model to Hive model (extend HiveObject)
- [ ] Add `@HiveType(typeId: 0)` annotation to class
- [ ] Add `@HiveField(n)` annotations to all properties (n = 0, 1, 2, etc.)
- [ ] Handle counters relationship as `HiveList<TokenCounter>` or List with separate box
- [ ] Convert computed properties to getters:
  - [ ] `netPlusOneCounters` → `int get netPlusOneCounters`
  - [ ] `isEmblem` → `bool get isEmblem`
  - [ ] `appliedPT` → `String get appliedPT`
- [ ] Port all methods (addCounter, removeCounter, addPowerToughnessCounters, etc.)
- [ ] Handle Date (createdAt) as `DateTime` (Hive handles this automatically)
- [ ] Run `flutter packages pub run build_runner build` to generate TypeAdapter

#### ✓ TokenCounter.swift → models/counter.dart
- [ ] Convert @Model to Hive model (extend HiveObject)
- [ ] Add `@HiveType(typeId: 1)` annotation
- [ ] Add `@HiveField(n)` annotations to all properties
- [ ] Remove @Relationship back-reference (Hive handles object relationships)
- [ ] Run code generator to create TypeAdapter

#### ✓ Deck.swift → models/deck.dart
- [ ] Convert @Model to Hive model (extend HiveObject)
- [ ] Add `@HiveType(typeId: 2)` annotation
- [ ] Add `@HiveField(n)` annotations to all properties
- [ ] Handle `templates` as List<TokenTemplate> directly (Hive serializes complex objects)
- [ ] Create TokenTemplate as Hive model with `@HiveType(typeId: 3)`
- [ ] Run code generator to create TypeAdapters for both Deck and TokenTemplate

#### ✓ TokenDefinition.swift → models/token_definition.dart
- [ ] Convert struct to Dart class with immutable fields (final)
- [ ] Port composite ID logic: `get id => "$name|$pt|$colors|$type|$abilities"`
- [ ] Port `toItem()` method to create Item instances
- [ ] Port `matches()` search logic

### View Components → Widgets

#### ✓ TokenView.swift → widgets/token_card.dart
- [ ] Convert to StatelessWidget taking Item as parameter
- [ ] Port color gradient logic to `gradientForColors()` utility function
- [ ] Replace Card/VStack with Card(child: Padding(child: Column(...)))
- [ ] Convert HStacks to Rows, VStacks to Columns
- [ ] Port counter pill display:
  - [ ] Use Wrap widget for pill layout
  - [ ] CounterPillView → counter_pill.dart widget
  - [ ] Apply inverted color scheme (colored background, white text)
- [ ] Convert tap gesture to GestureDetector or InkWell
  - [ ] onTap: open ExpandedTokenView with Navigator.push()
- [ ] Port quick action buttons (add/remove/tap/untap/copy):
  - [ ] Use Row of IconButtons
  - [ ] Apply multiplier from SettingsProvider
  - [ ] Call TokenProvider methods (addTokens, removeTokens, tapTokens, etc.)
- [ ] Port long-press gesture for bulk operations (tap all, untap all)
- [ ] Special handling for emblems (no tapped/untapped UI, centered layout)
- [ ] Add Scute Swarm doubling button if name matches

#### ✓ ExpandedTokenView.swift → screens/expanded_token_screen.dart
- [ ] Convert to StatefulWidget (for local editing state)
- [ ] Create full-screen route with Scaffold and AppBar
- [ ] Port all tap-to-edit fields:
  - [ ] Name, P/T, abilities: use TextField or TextFormField
  - [ ] Use FocusNode for field switching
  - [ ] Save changes on field blur or explicit save button
- [ ] Port counter display section:
  - [ ] CounterManagementPillView → counter_management_pill.dart
  - [ ] Add +/- buttons for each counter
  - [ ] Wire up to Item.addCounter / removeCounter
- [ ] Port summoning sickness toggle
- [ ] Port stack splitting button:
  - [ ] Open SplitStackSheet with showModalBottomSheet()
  - [ ] Pass callback for completion
- [ ] Port special actions (Scute Swarm doubling, copy stack, delete)
- [ ] Update TokenProvider on changes (call provider.updateItem())

#### ✓ TokenSearchView.swift → screens/token_search_screen.dart
- [ ] Convert to StatefulWidget with TabController (3 tabs: All/Recent/Favorites)
- [ ] Load TokenDatabase on init (async JSON parsing)
- [ ] Port search bar: use TextField in AppBar or dedicated search widget
- [ ] Port category filter buttons (Creature, Artifact, etc.):
  - [ ] Use ToggleButtons or FilterChip widgets
  - [ ] Update filter state and rebuild filtered list
- [ ] Port filteredTokens logic to local state
- [ ] Display results with ListView.builder
  - [ ] Use TokenSearchRow widget for each item
- [ ] Port "Create Custom Token" button:
  - [ ] Place in floating position or as first list item
  - [ ] Opens NewTokenSheet on tap
- [ ] Port token selection flow:
  - [ ] Show quantity alert dialog
  - [ ] Apply multiplier from SettingsProvider
  - [ ] Create Item and insert via TokenProvider
  - [ ] Close sheet with Navigator.pop()

#### ✓ TokenSearchRow.swift → widgets/token_search_row.dart
- [ ] Convert to StatelessWidget taking TokenDefinition
- [ ] Port layout (name, P/T, abilities, color indicators)
- [ ] Use ListTile or custom Row/Column layout
- [ ] Port color indicators as small colored circles

#### ✓ NewTokenSheet.swift → widgets/new_token_sheet.dart
- [ ] Convert to StatefulWidget
- [ ] Use Form widget with TextFormField for all inputs
- [ ] Port color picker (W/U/B/R/G toggles):
  - [ ] Use Checkbox or ToggleButtons
  - [ ] Build colors string from selection
- [ ] Port "Create Tapped" toggle
- [ ] Port quantity input
- [ ] Create button applies multiplier and inserts via TokenProvider

#### ✓ MultiplierView.swift → widgets/multiplier_view.dart
- [ ] Convert to StatelessWidget consuming SettingsProvider
- [ ] Display current multiplier value
- [ ] **IMPORTANT**: Change from ×2/÷2 buttons to +1/-1 buttons per Improvements.md
- [ ] Use Row with IconButtons for increment/decrement
- [ ] Call SettingsProvider.setTokenMultiplier()
- [ ] Ensure multiplier range 1-1024 is enforced

#### ✓ SplitStackView.swift → widgets/split_stack_sheet.dart
- [ ] Convert to StatefulWidget
- [ ] **CRITICAL**: Implement early dismiss pattern to avoid crashes:
  - [ ] Add `onSplitCompleted` callback parameter
  - [ ] Split button: dismiss sheet FIRST with Navigator.pop()
  - [ ] Then use `Future.delayed()` or `SchedulerBinding.addPostFrameCallback()` to perform split
  - [ ] Call onSplitCompleted callback after split
- [ ] **Replace slider with stepper** per Improvements.md:
  - [ ] Use TextField with number input or custom stepper buttons
  - [ ] Show remaining counts for each stack
- [ ] Port tapped/untapped allocation UI
- [ ] Port counter copying UI
- [ ] Cancel button: just Navigator.pop() without callback

#### ✓ LoadDeckSheet.swift → widgets/load_deck_sheet.dart
- [ ] Convert to StatelessWidget consuming DeckProvider
- [ ] Display decks with ListView.builder
- [ ] Load button: iterate templates, create Items, insert via TokenProvider
- [ ] Delete button: confirm with dialog, then DeckProvider.deleteDeck()

#### ✓ CounterSearchView.swift → screens/counter_search_screen.dart
- [ ] Convert to StatefulWidget
- [ ] Load predefined counters from CounterDatabase
- [ ] Port search bar
- [ ] Display counters with ListView.builder
- [ ] Selection: show quantity dialog, then add counter to Item

#### ✓ AboutView.swift → screens/about_screen.dart
- [ ] Convert to StatelessWidget
- [ ] Port all text content to Column with Text widgets
- [ ] Use Scaffold with AppBar

### Supporting Files

#### ✓ TokenDatabase.swift → database/token_database.dart
- [ ] Port JSON loading logic using `rootBundle.loadString('assets/token_database.json')`
- [ ] Parse JSON with `jsonDecode()`
- [ ] Map to List<TokenDefinition>
- [ ] Implement search/filter methods

#### ✓ CounterDatabase.swift → database/counter_database.dart
- [ ] Port predefined counter list to Dart List<String>
- [ ] Keep same counter names

#### ✓ TokenDatabase.json → assets/token_database.json
- [ ] Copy file to assets/ directory
- [ ] Add to pubspec.yaml under assets:

```yaml
flutter:
  assets:
    - assets/token_database.json
```

### Database Layer (New)

#### ✓ Create database/hive_setup.dart
- [ ] Import Hive and generated TypeAdapters
- [ ] Create initHive() function to:
  - [ ] Initialize Hive with `await Hive.initFlutter()`
  - [ ] Register all TypeAdapters (ItemAdapter, TokenCounterAdapter, DeckAdapter, TokenTemplateAdapter)
  - [ ] Open all boxes that need early initialization
- [ ] Call initHive() in main() before runApp()
- [ ] No schema migrations needed (Hive handles schema changes automatically)

#### ✓ Create providers/token_provider.dart
- [ ] Extend ChangeNotifier
- [ ] Open Hive box in init(): `itemsBox = await Hive.openBox<Item>('items')`
- [ ] Implement CRUD methods:
  - [ ] items getter - return itemsBox.values.toList() sorted by createdAt
  - [ ] insertItem(Item) - await itemsBox.add(item), then notifyListeners()
  - [ ] updateItem(Item) - await item.save() (HiveObject method), then notifyListeners()
  - [ ] deleteItem(Item) - await item.delete(), then notifyListeners()
  - [ ] untapAll() - iterate items, update, save each, then notifyListeners()
  - [ ] clearSummoningSickness() - iterate items, update, save each, then notifyListeners()
  - [ ] boardWipe() - await itemsBox.clear(), then notifyListeners()
- [ ] Each method calls notifyListeners() after Hive operations

#### ✓ Create providers/deck_provider.dart
- [ ] Similar structure to TokenProvider
- [ ] Open Hive box: `decksBox = await Hive.openBox<Deck>('decks')`
- [ ] Methods: decks getter, saveDeck(), deleteDeck(), loadDeckToBoard()

#### ✓ Create providers/settings_provider.dart
- [ ] Wrap SharedPreferences for reactive settings
- [ ] Properties: tokenMultiplier, summoningSicknessEnabled, favoriteTokens (Set<String>)
- [ ] Getters and setters with notifyListeners()

---

## Python Script Considerations

### process_tokens.py
The token generation script is iOS/Swift-specific and outputs to `Doubling Season/TokenDatabase.json`. This should continue to work without changes, as Flutter will consume the same JSON format.

**Action Items**:
- [ ] Update output path in script if Flutter project is in separate directory
- [ ] Ensure JSON format matches TokenDefinition.fromJson() expectations
- [ ] Consider moving script to project root or dedicated `tools/` directory

---

## Testing Strategy

### Manual Testing Approach (No Automated Tests)
Per CLAUDE.md, testing is performed through manual functional testing by human experts.

**Testing Checklist**:
- [ ] Token creation (from database search)
- [ ] Token creation (manual)
- [ ] Token display (name, P/T, abilities, colors, counters)
- [ ] Tapping/untapping tokens
- [ ] Summoning sickness application and clearing
- [ ] Counter management (+1/+1, -1/-1 auto-cancellation, custom counters)
- [ ] Stack splitting (preserve counters, tapped states)
- [ ] Deck saving and loading
- [ ] Multiplier application (1-1024 range, +1/-1 increments)
- [ ] Search functionality (All/Recent/Favorites tabs, category filters)
- [ ] Color identity display (gradient borders)
- [ ] Emblem handling (no tapped/untapped UI)
- [ ] Scute Swarm doubling button
- [ ] Board wipe with confirmation
- [ ] Settings persistence (multiplier, summoning sickness toggle)
- [ ] iOS platform testing (primary target)
- [ ] Android platform testing (ensure UI adapts correctly)

---

## Migration Sequence Recommendation

### Phase 1: Foundation (Week 1)
1. [ ] Set up Flutter project structure and dependencies (provider, hive, hive_flutter, shared_preferences)
2. [ ] Create all model classes with Hive annotations (Item, Deck, TokenTemplate, TokenCounter)
3. [ ] Run build_runner to generate TypeAdapters
4. [ ] Create hive_setup.dart and initialize in main()
5. [ ] Port TokenDatabase JSON loading logic (load from assets, keep in memory)
6. [ ] Set up all Providers (TokenProvider, DeckProvider, SettingsProvider)
7. [ ] Create main.dart with Hive init and provider setup

### Phase 2: Core UI (Week 2)
1. [ ] Build ContentScreen (main game view with empty state)
2. [ ] Build TokenCard widget (display only, no interactions)
3. [ ] Build MultiplierView widget
4. [ ] Wire up TokenProvider to display tokens in ContentScreen
5. [ ] Implement toolbar actions (untap all, board wipe, etc.)

### Phase 3: Token Interactions (Week 3)
1. [ ] Build TokenSearchScreen with tabs and search
2. [ ] Implement token creation flow (search → quantity → insert)
3. [ ] Build NewTokenSheet for manual creation
4. [ ] Add tap/untap gestures to TokenCard
5. [ ] Implement add/remove token quick actions

### Phase 4: Advanced Features (Week 4)
1. [ ] Build ExpandedTokenScreen with editable fields
2. [ ] Implement counter management UI (CounterSearchScreen, counter pills)
3. [ ] Build SplitStackSheet with early dismiss pattern
4. [ ] Implement deck save/load functionality (LoadDeckSheet)
5. [ ] Add special token handling (Emblems, Scute Swarm)

### Phase 5: Polish and Bug Fixes (Week 5-6)
1. [ ] Fix navigation issues from Improvements.md (keyboard overlap, etc.)
2. [ ] Verify counter pill visibility (inverted color scheme)
3. [ ] Test and fix stack splitting crashes
4. [ ] Android-specific UI adjustments
5. [ ] Performance optimization (Hive box operations, list scrolling)
6. [ ] Dark mode testing and theme refinement

---

## Known SwiftUI-Specific Issues to Fix During Migration

From `Improvements.md`, the following bugs should be addressed during migration:

1. **Search UI Keyboard Overlap** (TokenSearchView:101-102)
   - Flutter solution: Use `resizeToAvoidBottomInset: true` in Scaffold, or wrap content in SingleChildScrollView

2. **Multiplier Adjustment** (MultiplierView:21-48)
   - Change from ×2/÷2 to +1/-1 increments
   - Flutter: Simple +/- IconButtons with `multiplier + 1` / `multiplier - 1`

3. **Split Stack Cancellation** (ExpandedTokenView:85-93, SplitStackView:11-14)
   - Implement callback pattern: `onSplitCompleted` parameter
   - Cancel button: just Navigator.pop()
   - Split button: Navigator.pop() then perform split in callback

4. **Split Stack App Crashes** (SplitStackView:55)
   - Replace Slider with TextField or Stepper
   - Dismiss sheet BEFORE modifying Item (use Future.delayed or post-frame callback)

---

## Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0           # State management
  hive: ^2.2.3               # NoSQL object storage
  hive_flutter: ^1.1.0       # Hive Flutter extensions
  shared_preferences: ^2.0.0 # Persistent settings

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
  build_runner: ^2.4.0       # Code generation for Hive
  hive_generator: ^2.0.0     # Generates TypeAdapters
```

**Optional Enhancements**:
- **go_router** - For declarative routing (if complex navigation is needed)
- **freezed** + **json_serializable** - Code generation for immutable models (optional with Hive)

---

## Post-Migration Considerations

### Platform-Specific Polish
- [ ] iOS-specific: Cupertino widgets for more native feel (CupertinoButton, CupertinoAlertDialog)
- [ ] Android-specific: Material Design 3 components (Material 3 theme, adaptive widgets)
- [ ] Haptic feedback on token interactions (use `HapticFeedback.lightImpact()`)
- [ ] Platform-specific navigation patterns (iOS back swipe gesture vs Android back button)

### Future Enhancements from FeedbackAndIdeas.md
These can be implemented post-migration:
- Token artwork (use `cached_network_image` package)
- Combat tracking interface
- Condensed view mode
- Bottom floating toolbox (easier in Flutter with Stack + Positioned)

### Performance Optimization
- [ ] Use `const` constructors wherever possible (reduces rebuilds)
- [ ] Implement `ListView.builder` pagination for large token lists
- [ ] Profile database queries and add indexes if needed
- [ ] Consider using `compute()` for heavy JSON parsing on background isolate

---

## Migration Validation Checklist

Before considering migration complete:
- [ ] All core features functional on iOS
- [ ] All core features functional on Android
- [ ] Database persistence working (tokens/decks survive app restart)
- [ ] Settings persistence working (multiplier, summoning sickness toggle)
- [ ] No crashes or exceptions in normal usage
- [ ] UI is responsive and smooth (60fps scrolling)
- [ ] Search is performant with 300+ tokens
- [ ] Color gradients match SwiftUI version
- [ ] Counter auto-cancellation logic works (+1/+1 vs -1/-1)
- [ ] All improvements from Improvements.md are addressed

---

## Notes and Open Questions

**Q**: Should we maintain a separate iOS SwiftUI version and Flutter version?
**A**: No. Once migration to Flutter is complete, the SwiftUI version will be sunset. No parallel maintenance.

**Q**: What about iOS-specific features like Widgets or Live Activities?
**A**: Not needed. Focus is on core cross-platform functionality only.

**Q**: Should we use Hive or SQL (sqflite/drift)?
**A**: Use Hive. SwiftData is object-oriented (not relational), and Hive provides better performance (3-10x faster) with less boilerplate for small-scale object storage.

**Q**: How to handle the current git branch setup?
**A**: Create new `flutter` branch for migration work. Develop on flutter branch until migration is complete and tested, then merge to main. SwiftUI code remains on main until flutter branch is ready for final merge.

---

## Conclusion

This migration is **feasible and straightforward** given the app's architecture:
- No complex animations or custom graphics
- Straightforward CRUD data model
- No third-party SDK dependencies
- Clear separation of concerns (Views, Models, Data)

The main effort is in **systematic translation** of SwiftUI views to Flutter widgets and setting up the database layer. Following this checklist sequentially will ensure a smooth migration with feature parity.

**Estimated completion**: 3-6 weeks with a single developer working part-time, or 2-3 weeks full-time.
