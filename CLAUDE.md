# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## User Communication Style

- "fuck it we ball" = yes / confirmed / proceed

## Maintaining This Document

**CRITICAL**: Claude must proactively maintain this file as a living document.

### When to Update CLAUDE.md

Claude should **proactively offer** to update this file when:

1. **Project Configuration Changes** — Bundle identifiers, version numbers, platform support, deployment targets
2. **Architectural Changes** — New state management patterns, database schema, navigation, new providers
3. **Development Workflow Changes** — New slash commands, build process changes, deployment procedures
4. **Documentation Gaps Discovered** — Undocumented critical config, missing conventions, errors from outdated instructions
5. **Dependency Changes** — Major package additions/removals, build tool updates

After completing significant work, Claude should ask:
> "Should I update CLAUDE.md to document [specific change/pattern/convention]?"

An outdated CLAUDE.md leads to repeated mistakes, inconsistent patterns, and missing critical knowledge. Keep it current.

## Project Overview

**Tripling Season** is a cross-platform Flutter app for tracking Magic: The Gathering tokens during gameplay. It manages token stacks with tapped/untapped states, summoning sickness, counters (+1/+1, -1/-1, and custom counters), token artwork display, and provides a searchable database of 883 token types.

**Note:** The app's official name is "Tripling Season" (as of December 2025). Display name, bundle identifiers, and package names reflect this branding.

The app targets iOS, Android, Web, macOS, and Windows platforms using Flutter's single codebase approach.

**Current Version:** 1.8.0+16 (as of December 2025)

## Experimental Feature: Utilities (formerly "Widget Cards")

**IMPORTANT TERMINOLOGY:**
- **User-facing:** "Utilities" (appears in all UI text, menus, documentation)
- **Internal code:** "Widget" class names and file names (TrackerWidget, ToggleWidget, widget_selection_screen.dart)
- **Hive boxes:** `'trackerWidgets'` and `'toggleWidgets'` (DO NOT rename - migration risk)

**Why the split?** Renaming Hive boxes or classes risks data loss for existing users. "Widget" also conflicts with Flutter's own widget terminology. Solution: user-facing strings say "Utilities," internal code stays stable.

**Development guideline:**
- Use "utility" in user-facing strings and documentation
- Use "widget" when referring to class names in code or technical discussion
- See `docs/activeDevelopment/cardWidgets.md` for full feature specification

**Data model:**
- `TrackerWidget` class (typeId: 6) - stores in `Box<TrackerWidget>('trackerWidgets')`
  - Supports optional action button via `hasAction`, `actionButtonText`, `actionType` fields
  - `actionType` string dispatches to the correct behavior (e.g., `'krenko_mob_boss'`, `'cathars_crusade'`, `'academy_manufactor'`)
  - Commander-specific utilities (Krenko, Cathars' Crusade, Academy Manufactor) all use this model — no separate model per card
- `ToggleWidget` class (typeId: 7) - stores in `Box<ToggleWidget>('toggleWidgets')`
- DO NOT change typeIds or box names - breaks existing user data

## Project Configuration

### Critical Identifiers (NEVER use defaults)

**iOS Bundle Identifier:** `LooseTie.Doubling-Season`
- Location: `ios/Runner.xcodeproj/project.pbxproj`
- **WARNING**: Flutter defaults to `com.example.doublingSeason` - MUST be changed

**Android Application ID:** `com.loosetie.doublingseason`
- Location: `android/app/build.gradle.kts` (also set as `namespace`)

**App Version:**
- Current: `1.8.0+16` (Version 1.8.0, Build 16)
- Location: `pubspec.yaml` → `version: X.Y.Z+B`
- **Tip**: Use `/shipfortestflight` to auto-increment version and build IPA

**Display Name:** `Doubling Season`
- iOS: `ios/Runner/Info.plist` → `CFBundleDisplayName`
- Android: `android/app/src/main/AndroidManifest.xml` → `android:label`

**App Icon & Splash Screen:**
- Source asset: `assets/AppIconSource.png`
- Splash color: `#E8E4A0` (cream/beige)
- Regenerate icons: `flutter pub run flutter_launcher_icons`
- Regenerate splash: `flutter pub run flutter_native_splash:create`

## Common Development Commands

### Building and Running
```bash
flutter doctor
flutter run
flutter run -d <device-id>
flutter build ios / apk / appbundle / web / macos / windows
```

### Deploying to Physical iPhone

**Apple Developer Team ID:** `84W8Q8DV3S`

**CRITICAL: "Run" vs "Install"**
- **`flutter run`**: Temporary — app disappears when session ends. For debugging only.
- **`flutter install`**: Permanent — app stays on home screen after disconnecting. Use this when the user wants the app on their device.

```bash
# Use /shiptomyphone slash command, or manually:
flutter clean
flutter build ios --release
flutter install -d <device-id>
```

- Device ID for didym's iPhone: `00008150-000544E41E91401C`
- USB is more reliable than wireless for install
- If `flutter install` reports connection errors, check the iPhone home screen first — it often installs despite the error

### Code Generation
```bash
# After modifying @HiveType models:
flutter pub run build_runner build --delete-conflicting-outputs
```

### Data Generation
```bash
python3 docs/housekeeping/process_tokens_with_popularity.py
```
Fetches token XML from Cockatrice GitHub, deduplicates using key `name|pt|colors|type|abilities`, outputs to `assets/token_database.json`. Use `/regen-tokens` slash command for guided workflow.

### TestFlight Deployment
```bash
flutter build ipa --release
# IPA output: build/ios/ipa/Doubling Season.ipa — upload via Apple Transporter
```
Use `/shipfortestflight` for automated workflow (auto-increments version, builds, opens Transporter).

### Available Slash Commands
- **`/checkpoint`** - Stage and commit all changes (no Claude attribution)
- **`/regen-tokens`** - Regenerate token database from upstream Magic token data
- **`/shipfortestflight`** - Auto-increment version, build IPA, prepare for TestFlight
- **`/shiptomyphone`** - Build iOS release and permanently install on connected iPhone

### Git Commit Conventions

**CRITICAL: NO CLAUDE ATTRIBUTION**
- **NEVER** add "🤖 Generated with [Claude Code]" footer
- **NEVER** add "Co-Authored-By: Claude <noreply@anthropic.com>" trailer
- Commits belong to the user, not to Claude

### Testing
Manual functional testing only. Do not generate automated test code.

## Architecture

### State Management (Provider Pattern)

**TokenProvider** (`lib/providers/token_provider.dart`)
- Manages `Box<Item>` from Hive
- Reactive updates via `ValueListenable<Box<Item>>`
- Methods: `insertItem()`, `updateItem()`, `deleteItem()`, `addTokens()`, `tapTokens()`, `copyToken()`, `boardWipeDelete()`, `addPlusOneToAll()`

**SettingsProvider** (`lib/providers/settings_provider.dart`)
- SharedPreferences wrapper
- Stores: `tokenMultiplier`, `summoningSicknessEnabled`, `artworkDisplayStyle`, `favoriteTokens`, `recentTokens`

**DeckProvider** (`lib/providers/deck_provider.dart`)
- Manages `Box<Deck>` from Hive (regular Box, NOT LazyBox — LazyBox was the boot-bricking vulnerability)
- Methods: `saveDeck()`, `deleteDeck()`, sync `decks` getter

### Data Persistence

**Hive (NoSQL Database)**
- Models: `Item`, `TokenCounter`, `Deck`, `TokenTemplate`, `ArtworkVariant`, `TokenArtworkPreference`, `TrackerWidget`, `ToggleWidget`
- Setup: `lib/database/hive_setup.dart` — resilient boot with backup/restore, NEVER throws
- Boxes: `items`, `decks`, `artworkPreferences`, `trackerWidgets`, `toggleWidgets`

**SharedPreferences** — simple key-value settings, managed by SettingsProvider

**Token Database** — `assets/token_database.json`, loaded async via `TokenDatabase.loadTokens()` using `compute()` isolate

**Auto-save** — Hive models extend `HiveObject`, all setters call `.save()`

### Hive Type IDs and Schema Rules

**CRITICAL — NEVER change type IDs once assigned. Causes data corruption.**

| ID | Class |
|----|-------|
| 0 | Item |
| 1 | TokenCounter |
| 2 | Deck |
| 3 | TokenTemplate |
| 4 | ArtworkVariant |
| 5 | TokenArtworkPreference |
| 6 | TrackerWidget |
| 7 | ToggleWidget |

Next new model gets ID **8**. Add to `HiveTypeIds` in `lib/utils/constants.dart` and register in `hive_setup.dart`.

**CRITICAL — Always specify `defaultValue` when adding new fields to existing models.**
Without it, Hive cannot deserialize old user data → data loss on upgrade.
```dart
@HiveField(13, defaultValue: null)
String? artworkUrl;

@HiveField(11, defaultValue: 0.0)
double order;
```
After adding fields: run `build_runner build --delete-conflicting-outputs`, test upgrade path.

**Historical note:** v1.7→v1.8 migration lost user decks because `TokenTemplate` fields were added without `defaultValue`. Fixed in v1.8.1.

### Key Screen Components

**ContentScreen** (`lib/screens/content_screen.dart`) — Main game board
- `ValueListenableBuilder` on Hive box for reactive token list
- FloatingActionMenu: new token, +1/+1 Everything, untap all, clear sickness, save/load deck, board wipe

**TokenCard** (`lib/widgets/token_card.dart`) — Compact token display
- Color identity border gradient, counter pills, artwork display, animated P/T
- **Canonical reference for all board items** (see Utility Development Pattern)

**ExpandedTokenScreen** (`lib/screens/expanded_token_screen.dart`) — Token editor
- Editable name/P/T/abilities, color selection, artwork selection, counter management, stack splitting

**TokenSearchScreen** (`lib/screens/token_search_screen.dart`) — Database search
- Three tabs: All / Recent / Favorites, live search, category filtering, artwork precaching

**SplitStackSheet** (`lib/widgets/split_stack_sheet.dart`) — Stack splitting (see critical pattern below)

### Data Models

**Item** (typeId: 0) — key fields:
- HiveFields 0-12: abilities, name, pt, colors, amount, tapped, summoningSick, plusOneCounters, minusOneCounters, counters, createdAt, order, type
- HiveFields 13-15: artworkUrl, artworkSet, artworkOptions (nullable, defaultValue: null)
- `netPlusOneCounters = plusOneCounters - minusOneCounters` (auto-cancel logic)
- `isEmblem` — detected from name/abilities containing "emblem"
- Setting `amount` auto-corrects `tapped` and `summoningSick` if they exceed new value

**TokenTemplate** (typeId: 3) — nested in Deck, stores name/pt/abilities/colors + artworkUrl

**TokenDefinition** — NOT persisted, loaded from JSON. Composite ID: `name|pt|colors|type|abilities` (must match Python dedup key)

### Data Flow

```
assets/token_database.json → TokenDatabase.loadTokens() (compute isolate)
→ User selects token + quantity
→ Item created with multiplier applied
→ tokenProvider.insertItem(newItem)
→ ValueListenable updates → ContentScreen rebuilds
```

### Multiplier System
- Stored in SharedPreferences (`tokenMultiplier`, range 1-1024)
- Applied at creation time: `finalAmount = quantity * multiplier`
- MultiplierView: ±1 increments (NOT powers of 2). Long-press opens manual input.

### Counter Management
- +1/+1 and -1/-1 auto-cancel: `netPlusOneCounters = plusOneCounters - minusOneCounters`
- **+1/+1 Everything**: `TokenProvider.addPlusOneToAll()` — snapshot-based iteration, adds one +1/+1 to all tokens with P/T
- Custom counters selected via CounterSearchScreen from predefined list

### Summoning Sickness
Applied only when ALL: setting enabled AND `hasPowerToughness` AND `!hasHaste`.
Copied tokens inherit parent's sickness state. Toggle setting via long-press on sickness button.

### Artwork Display
Two styles stored in SharedPreferences (`artworkDisplayStyle`):
- **Full View** (`fullView`): artwork fills card width
- **Fadeout** (`fadeout`, default): artwork on right 50% with gradient fade

See full implementation details: `docs/activeDevelopment/patterns/artwork_display.md`

### Special Token Handling
- **Emblems**: `isEmblem` computed property — no tapped/untapped UI, no color border, centered layout
- **Scute Swarm**: special doubling button that doubles stack size

## Important Implementation Notes

### Critical Code Patterns

**Summoning sickness must be applied AFTER insert** (setter calls `.save()`, needs a valid Hive key):
```dart
await tokenProvider.insertItem(newItem);
if (settingsProvider.summoningSicknessEnabled &&
    newItem.hasPowerToughness &&
    !newItem.hasHaste) {
  newItem.summoningSick = finalAmount;
}
```

**Stack splitting — dismiss BEFORE performing the split** (avoids state crashes):
```dart
onPressed: () {
  Navigator.of(context).pop(); // Dismiss FIRST
  WidgetsBinding.instance.addPostFrameCallback((_) {
    tokenProvider.insertItem(newItem);
    originalItem.amount = remainingAmount;
    originalItem.save();
  });
},
```

**Artwork field updates — always batch into one write** using `item.updateArtwork(url:, set:, options:)` to avoid multiple saves.

### Utility Development Pattern

**CRITICAL: TokenCard is the canonical reference for all board items.**

When implementing features for any utility type (TrackerWidget, ToggleWidget, future types):
1. Check `lib/widgets/token_card.dart` first — copy existing patterns rather than reimplementing
2. For artwork: follow `docs/activeDevelopment/patterns/artwork_display.md`
3. Layer order in Stack: base background → artwork → content (always)

### UI Conventions
- `Navigator.of(context).push()` for full-screen navigation
- `showDialog()` for alerts/confirmations
- `showModalBottomSheet()` for secondary sheets (deck loading, split stack)
- Color border gradient: `ColorUtils.gradientForColors()` from color identity string
- Counter pills: solid background, white text (high contrast for light/dark mode)

### Token Database Deduplication
`TokenDefinition.id` composite key `name|pt|colors|type|abilities` must match the Python script's dedup key exactly. If they diverge, token variants will be missing from search.

### Python Script Maintenance
- Dedup key: `f"{name}|{token['pt']}|{token['colors']}|{type_text}|{abilities}"`
- Output hardcoded to `assets/token_database.json`
- Run from repo root: `python3 docs/housekeeping/process_tokens_with_popularity.py`

## Docs Workflow (Context Preservation)

The `docs/activeDevelopment/` directory preserves context between sessions so work can be resumed after breaks or usage caps.

### Directory Structure

| Directory | Purpose |
|-----------|---------|
| `todo_features/` | Planned features not yet started |
| `in_progress_features/` | Features currently being implemented |
| `bug_bashing/` | Active bug investigations and fixes |
| `new_release/` | Completed work staged for the next prod release (moved here after acceptance testing) |
| `patterns/` | Reusable implementation patterns (artwork display, etc.) |

### Workflow Rules

**Starting a feature:** Move or create doc in `in_progress_features/`. Update as work progresses.

**Bug reports:** Create doc in `bug_bashing/` immediately. Document symptoms, findings, root cause, fix plan.

**Completing work:** Move doc to `new_release/` after acceptance testing passes and changes are committed. Docs stay there until the prod release ships.

**Why this matters:** Sessions end unexpectedly. These docs let Claude resume exactly where things left off.

## Future Feature Context

**Planned Features:**
- See `docs/activeDevelopment/FeedbackIdeas.md` for user-requested features (-1/-1 Everything, combat tracking, condensed view, enhanced artwork)
- See `docs/activeDevelopment/NextFeature.md` for current development focus

## Project Structure

Key files (Claude can glob/grep for the rest):

```
lib/
├── main.dart                    # Entry point, Provider setup, Hive init, boot dialog
├── models/item.dart             # Active token model — primary data model, read carefully
├── database/hive_setup.dart     # Resilient Hive boot (backup/restore, never throws)
├── utils/constants.dart         # HiveTypeIds, game constants
├── utils/artwork_manager.dart   # Scryfall download, local cache, image resize (768px cap)
├── providers/                   # TokenProvider, DeckProvider, SettingsProvider
├── screens/content_screen.dart  # Main game board
├── widgets/token_card.dart      # Canonical reference for all board item UI
└── widgets/split_stack_sheet.dart  # Early-dismiss pattern (critical)

assets/token_database.json       # 883 bundled tokens
docs/activeDevelopment/patterns/ # Reusable implementation patterns
```

## Dependencies

Key packages: `provider`, `hive`, `hive_flutter`, `shared_preferences`, `gradient_borders`, `wakelock_plus`, `package_info_plus`

Dev: `build_runner`, `hive_generator`, `flutter_lints`, `flutter_launcher_icons`, `flutter_native_splash`

## Platform-Specific Notes

- **iOS**: Flutter engine only, no native Swift code
- **Android**: Full support, Material Design 3. Primary platform for bug reports.
- **Web/Desktop**: Supported but primarily tested on mobile
- **Asset Loading**: `rootBundle.loadString()` works cross-platform
