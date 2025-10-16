# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Doubling Season** is an iOS SwiftUI app for tracking Magic: The Gathering tokens during gameplay. It manages token stacks with tapped/untapped states, summoning sickness, counters (+1/+1, -1/-1, and custom counters), and provides a searchable database of 300+ token types.

## Common Development Commands

### Building and Running
- Open `Doubling Season.xcodeproj` in Xcode
- Build: `Cmd+B`
- Run: `Cmd+R` on iOS simulator or device
- No package manager commands needed (SwiftUI/SwiftData only, no external dependencies)

### Data Generation
To regenerate the token database from upstream Magic token data:
```bash
cd "AI STUFF"
python3 process_tokens.py
```
This fetches token data from the Cockatrice GitHub repository, processes it, and outputs `Doubling Season/TokenDatabase.json`.

The script:
- Fetches XML from `https://raw.githubusercontent.com/Cockatrice/Magic-Token/master/tokens.xml`
- Parses token definitions (name, P/T, colors, abilities, type)
- Deduplicates using key: `name|pt|colors|type|abilities` (note: abilities are included in dedup key per Improvements.md)
- Removes reminder text and normalizes formatting
- Outputs sorted JSON array

### Testing
Testing is performed through manual functional testing by human experts. Do not generate automated test code.

## Architecture

### SwiftData Persistence
The app uses SwiftData (Apple's modern replacement for Core Data) with three main models:
- **Item** (`Item.swift`) - Active tokens on the battlefield
- **Deck** (`Deck.swift`) - Saved deck templates using JSON-encoded TokenTemplate structs
- **TokenCounter** (`Item.swift`) - Counter instances applied to tokens

All registered in `Doubling_SeasonApp.swift` ModelContainer schema.

### Key View Components

**ContentView** - Main hub
- Displays token list via `@Query(sort: \Item.createdAt)`
- Toolbar with game actions (untap, clear summoning sickness, save/load decks, board wipe)
- Manages sheets for token search and manual creation
- MultiplierView overlay at bottom

**TokenView** - Compact token card
- Shows name, P/T, abilities, counters, tapped/untapped counts
- Color identity bar on left edge (W=yellow, U=blue, B=purple, R=red, G=green, colorless=gray)
- Tap to open ExpandedTokenView sheet
- Quick actions: add/remove (with multiplier), tap/untap, copy
- Long-press for bulk operations
- Special handling for Scute Swarm (doubling button) and Emblems (no tapped/untapped UI)

**ExpandedTokenView** - Detailed editor
- Tap-to-edit fields for all token properties
- Counter management via CounterSearchView
- Stack splitting via SplitStackView
- Shows summoning sickness status

**TokenSearchView** - Database search interface
- Three tabs: All / Recent / Favorites
- Live search with category filtering (Creature, Artifact, Enchantment, Emblem, Dungeon, Counter, Other)
- "Create Custom Token" button that dismisses search and opens NewTokenSheet
- Quantity dialog applies multiplier on selection

**SplitStackView** - Stack splitting interface
- Distribute tokens between original and new stack
- Tapped/untapped allocation
- Counters are copied to both stacks
- **Critical**: Dismiss sheet BEFORE modifying the Item to avoid crashes (see Improvements.md)

### Data Models

**Item** (the active token model):
```swift
Item {
    name, pt, abilities, colors: String
    amount: Int              // Total tokens in stack
    tapped: Int              // Count of tapped tokens
    summoningSick: Int       // Count with summoning sickness
    counters: [TokenCounter] // Custom counters
    plusOneCounters: Int     // +1/+1 counters
    minusOneCounters: Int    // -1/-1 counters (auto-cancel with +1/+1)
    createdAt: Date          // For consistent ordering
}
```

**TokenDefinition** (from database):
```swift
TokenDefinition {
    name, abilities, pt, colors, type: String
    func toItem(amount: Int, createTapped: Bool) -> Item
    func matches(query: String) -> Bool
}
```

**Deck & TokenTemplate**:
```swift
TokenTemplate {             // Codable struct
    name, abilities, pt, colors: String
    init(from: Item)
    func createItem() -> Item
}

Deck {                      // SwiftData model
    name: String
    templatesData: Data     // JSON-encoded [TokenTemplate]
    var templates: [TokenTemplate]  // Computed property
}
```

### Data Flow

```
TokenDatabase.json (bundle resource)
    ↓
TokenDatabase.loadTokens() (async on init)
    ↓
filteredTokens (search/category filters)
    ↓
User selects token + quantity
    ↓
Item created with multiplier applied
    ↓
modelContext.insert(newItem)
    ↓
@Query updates → ContentView displays TokenView
```

### Multiplier System
- Global `@AppStorage("tokenMultiplier")` (1 to 1024)
- Applied at creation time: `finalAmount = quantity * multiplier`
- Used in: TokenSearchView, NewTokenSheet, TokenView copy/add buttons, ExpandedTokenView
- MultiplierView provides stepper (currently ×2/÷2, but Improvements.md specifies changing to +1/-1 increments)

### Counter Management
- **Power/Toughness Counters**: +1/+1 and -1/-1 auto-cancel each other
  - `netPlusOneCounters = plusOneCounters - minusOneCounters`
  - Applied to entire stack automatically
  - Display shows modified P/T with blue background when counters present

- **Custom Counters**: Selected via CounterSearchView from predefined list
  - Can be applied to entire stack or just one token
  - Stack splitting: user chooses whether to copy counters

### Summoning Sickness
- Toggleable via `@AppStorage("summoningSicknessEnabled")`
- Tracked per-stack with `summoningSick` count
- Applied when tokens are added/copied
- Display shows summoning sickness icon + count
- Long-press summoning sickness toolbar button to toggle setting

### Special Token Handling
- **Emblems**: Detected via `isEmblem` computed property (name/abilities contains "emblem")
  - No tapped/untapped UI
  - No color bar
  - Centered layout

- **Scute Swarm**: Special doubling button (ladybug icon) that doubles stack size

## Important Implementation Notes

### File References for Current Tasks
The `Improvements.md` file contains prioritized bug fixes and feature requests:
1. **Missing Token Types** - `process_tokens.py:118` deduplication includes abilities now
2. **Search UI Issue** - `TokenSearchView.swift:101-102` navigation title overlap with keyboard
3. **Multiplier Adjustment** - `MultiplierView.swift:21-48` should increment by 1, not powers of 2
4. **Split Stack Cancellation** - `ExpandedTokenView.swift:85-93` and `SplitStackView.swift:11-14` callback pattern
5. **Split Stack App Crashes** - `SplitStackView.swift:55` slider calculations, needs migration to stepper + early dismiss

### Code Patterns to Follow

**Reading token data**:
```swift
@StateObject private var database = TokenDatabase()  // In TokenSearchView
guard let url = Bundle.main.url(forResource: "TokenDatabase", withExtension: "json")
```

**Creating tokens with multiplier**:
```swift
let finalAmount = amount * multiplier
let newItem = Item(
    abilities: abilities,
    name: name,
    pt: pt,
    colors: colors,
    amount: finalAmount,
    createTapped: createTapped,
    applySummoningSickness: summoningSicknessEnabled
)
withAnimation {
    modelContext.insert(newItem)
}
```

**Counter management**:
```swift
// +1/+1 counters auto-cancel with -1/-1
item.addPowerToughnessCounters(2)   // Adds 2 +1/+1 counters
item.addPowerToughnessCounters(-1)  // Adds 1 -1/-1 counter

// Custom counters
item.addCounter(name: "Shield", amount: 1)
item.removeCounter(name: "Shield", amount: 1)
```

**Stack splitting pattern** (from Improvements.md):
```swift
// In SplitStackView, add:
var onSplitCompleted: (() -> Void)?

// In "Split Stack" button action:
dismiss()  // Dismiss FIRST
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    performSplit()
    onSplitCompleted?()
}

// In ExpandedTokenView sheet:
SplitStackView(item: item) {
    dismiss()  // Only called on completion, not cancel
}
```

### SwiftData Query Patterns
```swift
@Query(sort: \Item.createdAt, order: .forward) private var items: [Item]
@Query private var decks: [Deck]
@Environment(\.modelContext) private var modelContext
```

### UI Conventions
- Use `.sheet(isPresented:)` for secondary views (search, expanded view, split stack)
- Use `.alert()` for quantity inputs and confirmations
- Use `simultaneousGesture(TapGesture())` + `simultaneousGesture(LongPressGesture())` for dual-action buttons
- Color bar overlay pattern: `VStack(spacing: 0)` with conditional colors, `.frame(width: 10)`, `.allowsHitTesting(false)`
- Empty states use `ContentUnavailableView` in search views
- Emblems have centered layout without color bars or tapped/untapped UI

### Python Script Maintenance
When modifying `process_tokens.py`:
- The deduplication key at line 118 must include abilities: `f"{name}|{token['pt']}|{token['colors']}|{type_text}|{abilities}"`
- Output path is hardcoded: `"Doubling Season/TokenDatabase.json"`
- Run from repository root: `python3 "AI STUFF/process_tokens.py"`

## Future Feature Context

See `FeedbackAndIdeas.md` for user-requested features:
- Token artwork (download/on-demand/user upload)
- Combat tracking interface
- Condensed view mode
- New toolbar positioning (bottom floating toolbox)

See `Premium.md` for planned paid features:
- Commander-specific tools (Brudiclad, Krenko, Chatterfang)
- Token modifier card toggles (Academy Manufactor, etc.)

## Project Structure

```
Doubling Season/
├── Doubling_SeasonApp.swift      # Entry point, ModelContainer setup
├── ContentView.swift              # Main game view
├── Item.swift                     # Token + TokenCounter models
├── Deck.swift                     # Deck + TokenTemplate models
├── TokenView.swift                # Compact token card
├── ExpandedTokenView.swift        # Detailed token editor
├── TokenSearchView.swift          # Database search interface
├── TokenSearchRow.swift           # Search result row
├── TokenDefinition.swift          # Search model + TokenDatabase manager
├── TokenDatabase.swift            # Database loading logic
├── CounterSearchView.swift        # Counter selection interface
├── CounterDatabase.swift          # Predefined counter types
├── Counter.swift                  # Counter models
├── MultiplierView.swift           # Multiplier control
├── SplitStackView.swift           # Stack splitting interface
├── NewTokenSheet.swift            # Manual token creation
├── LoadDeckSheet.swift            # Deck loading interface
├── AboutView.swift                # App info
├── TokenDatabase.json             # Bundled token data (300+ tokens)
└── TokenLookup.json               # Additional token metadata

AI STUFF/
├── process_tokens.py              # Token database generator
├── swift_implementation_guide.md  # Token search implementation guide
├── Improvements.md                # Current bug fixes and tasks
└── [other AI documentation]
```
