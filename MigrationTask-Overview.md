# Flutter Migration Overview & Checklist
# Doubling Season - SwiftUI to Flutter

**Last Updated:** 2025-10-28
**Target:** Feature & UX parity with SwiftUI iOS app
**Platforms:** iOS (primary), Android (future)

---

## NAVIGATION

This migration guide has been split into manageable sections:

- **[Phase 1: Foundation & Data Layer](./MigrationTask-Phase1.md)** - Data models, Hive setup, state management
- **[Phase 2: Core UI Components](./MigrationTask-Phase2.md)** - Token cards, multiplier view, content screen
- **[Phase 3: Token Interactions](./MigrationTask-Phase3.md)** - Search, creation, dialogs
- **[Phase 4: Advanced Features](./MigrationTask-Phase4.md)** - Expanded view, split stack, counter management, deck loading
- **[Phase 5: Polish & Bug Fixes](./MigrationTask-Phase5.md)** - Final polish, gradient borders, testing
- **[Implementation Patterns](./MigrationTask-Patterns.md)** - Critical patterns, outstanding questions, decision log

---

## EXECUTIVE SUMMARY

### Objective
Migrate Doubling Season iOS app from SwiftUI/SwiftData to Flutter with 100% feature parity and equivalent UX. The app tracks Magic: The Gathering tokens during gameplay with support for tapped/untapped states, summoning sickness, counters, and deck management.

### Architecture Overview
- **Current**: SwiftUI + SwiftData (iOS only)
- **Target**: Flutter + Hive + Provider (iOS + Android)
- **Estimated Effort**: 3-6 weeks (2-3 weeks full-time)
- **LOC**: ~2000 lines SwiftUI → ~2500 lines Flutter

### Key Migration Decisions
- **Database**: Hive (not SQL) - matches SwiftData's object-oriented approach
- **State Management**: Provider pattern (not Riverpod/Bloc) - simpler for app scale
- **Navigation**: Navigator 2.0 with sheets/dialogs (not go_router) - matches SwiftUI patterns
- **Testing**: Manual functional testing only (per CLAUDE.md)

---

## SUCCESS CRITERIA

### Functional Requirements (Must-Have)
- [ ] All 300+ token definitions searchable and creatable
- [ ] Token stacks with tapped/untapped counts
- [ ] Summoning sickness tracking (toggle-able)
- [ ] +1/+1 and -1/-1 counters with auto-cancellation
- [ ] Custom counters (40+ predefined types)
- [ ] Stack splitting with counter/tapped distribution
- [ ] Deck save/load functionality
- [ ] Multiplier system (1-1024, +1/-1 increments)
- [ ] Search with tabs (All/Recent/Favorites) and category filters
- [ ] Color identity gradients (WUBRG)
- [ ] Special token handling (Emblems, Scute Swarm)
- [ ] Board wipe functionality

### UX Requirements (Must-Have)
- [ ] Tap-to-edit fields (ExpandedTokenView)
- [ ] Simultaneous tap + long-press gestures for bulk operations
- [ ] Smooth animations (token creation, deletion, tapping)
- [ ] 60fps scrolling with 100+ tokens
- [ ] Keyboard avoidance in search view
- [ ] Counter pills with high-contrast inverted colors
- [ ] Empty state guidance
- [ ] Settings persistence across sessions

### Non-Functional Requirements
- [ ] No crashes or data corruption
- [ ] Offline-first (no network required except token art in future)
- [ ] App never goes to sleep during gameplay
- [ ] Dark mode support
- [ ] Identical visual appearance to SwiftUI version

---

## PRE-MIGRATION CHECKLIST

### Environment Setup
- [ ] Flutter SDK 3.35.7+ installed
- [ ] Xcode 26.0.1+ with CocoaPods configured
- [ ] VS Code with Flutter/Dart extensions
- [ ] iOS Simulator tested and working
- [ ] `flutter doctor` shows all checkmarks for iOS

### Project Initialization
```bash
# Create Flutter project
cd ~/Documents/Repos
flutter create doubling_season
cd doubling_season

# Add dependencies to pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
  build_runner: ^2.4.0
  hive_generator: ^2.0.0

# Run pub get
flutter pub get

# Start build_runner in watch mode (keep running during development)
flutter packages pub run build_runner watch --delete-conflicting-outputs
```

### File Structure Setup
```
lib/
├── main.dart
├── models/
│   ├── item.dart
│   ├── token_counter.dart
│   ├── deck.dart
│   ├── token_template.dart
│   └── token_definition.dart
├── providers/
│   ├── token_provider.dart
│   ├── deck_provider.dart
│   └── settings_provider.dart
├── database/
│   ├── hive_setup.dart
│   ├── token_database.dart
│   └── counter_database.dart
├── screens/
│   ├── content_screen.dart
│   ├── expanded_token_screen.dart
│   ├── token_search_screen.dart
│   ├── counter_search_screen.dart
│   └── about_screen.dart
├── widgets/
│   ├── token_card.dart
│   ├── counter_pill.dart
│   ├── counter_management_pill.dart
│   ├── multiplier_view.dart
│   ├── split_stack_sheet.dart
│   ├── new_token_sheet.dart
│   └── load_deck_sheet.dart
└── utils/
    ├── constants.dart
    └── color_utils.dart

assets/
└── token_database.json
```

### Git Branch Setup
- [ ] Confirm on `flutterMigration` branch
- [ ] Create backup of current SwiftUI code
- [ ] Add Flutter project to branch

---

## TESTING CHECKLIST

### Functional Testing (Manual)
- [ ] Token creation from database search
- [ ] Token creation (manual entry)
- [ ] Token display (name, P/T, abilities, colors, counters)
- [ ] Tapping/untapping tokens (single and bulk)
- [ ] Summoning sickness application and clearing
- [ ] Counter management (+1/+1, -1/-1 auto-cancellation, custom counters)
- [ ] Counter interaction: +1/+1 then -1/-1 cancellation logic
- [ ] Stack splitting (preserve counters, tapped states)
- [ ] Deck saving and loading
- [ ] Multiplier application (1-1024 range, +1/-1 increments)
- [ ] Search functionality (All/Recent/Favorites tabs, category filters)
- [ ] Color identity display (gradient borders)
- [ ] Emblem handling (no tapped/untapped UI, centered layout)
- [ ] Scute Swarm doubling button
- [ ] Board wipe with confirmation
- [ ] Settings persistence (multiplier, summoning sickness toggle)
- [ ] Swipe-to-delete tokens
- [ ] App survives restart (data persistence)
- [ ] Dark mode rendering
- [ ] No crashes during normal gameplay

### Performance Testing
- [ ] 60fps scrolling with 100+ tokens
- [ ] Hot reload works without data loss
- [ ] App memory usage stable over long session
- [ ] No lag when adding/removing tokens rapidly

### Edge Cases
- [ ] Negative values rejected (amounts, counters)
- [ ] Empty token name handling
- [ ] Corrupted Hive data recovery
- [ ] Very long token names (text overflow)
- [ ] Zero token amounts (opacity change)
- [ ] Maximum multiplier (1024)

---

## CONFIDENCE LEVEL ASSESSMENT

### Current Confidence for Autonomous Implementation

| Area | Confidence | Blocker? | Notes |
|------|-----------|----------|-------|
| **Data Models & Hive** | 95% | No | Clear patterns provided |
| **State Management** | 90% | No | Provider pattern well-documented |
| **Basic UI Components** | 95% | No | ColorSelectionButton verified |
| **Gesture Handling** | 75% | No | Acceptable UX workaround documented |
| **Search & Filtering** | 90% | No | Straightforward implementation |
| **Counter Logic** | 98% | No | SwiftUI code fully detailed + "Add to All/One" dialog |
| **Stack Splitting** | 90% | No | Early dismiss pattern documented |
| **Dialogs** | 95% | No | All dialog implementations verified |
| **Platform Integration** | 85% | No | Screen timeout method provided |

**Overall Confidence**: **95%** (Updated)

**Confidence by Phase:**
- **Phase 1** (Foundation & Data Layer): 95% - Complete with full implementation guide
- **Phase 2** (Core UI Components): 95% - Complete with ColorSelectionButton implementation
- **Phase 3** (Token Interactions): 95% - Complete with all dialog implementations + ColorSelectionButton
- **Phase 4** (Advanced Features): 95% - Complete with all critical patterns verified
- **Phase 5** (Polish & Bug Fixes): 90% - Complete testing checklist and optimization guide

An autonomous agent can now complete **all 5 phases** with **very high fidelity** using this documentation.

**Remaining questions** (minor refinements only, not blockers):
1. Gradient border approach - package vs CustomPainter (solution provided for both)
2. MultiplierView overlay positioning - fixed padding approach provided

**What's new in this version (v2.1):**
- ✅ **LoadDeckSheet bug note** - Documents bug in SwiftUI source (creates amount: 0)
- ✅ **CounterSearchView "Add to All vs Add to One" dialog** - Critical UX pattern added
- ✅ **NewTokenSheet uses ColorSelectionButton** - Verified against SwiftUI source
- ✅ **ExpandedTokenView uses ColorSelectionButton** - Verified against SwiftUI source
- ✅ Complete Phase 3 implementation (~1,300 lines)
- ✅ Complete Phase 4 implementation (~2,400 lines)
- ✅ Complete Phase 5 implementation (~600 lines)
- ✅ All dialog implementations with full code
- ✅ Split stack early dismiss pattern (prevents Hive crashes)
- ✅ Tap-to-edit field pattern for ExpandedTokenView
- ✅ Counter management complete implementation
- ✅ Deck save/load complete implementation
- ✅ Comprehensive testing checklist (70+ test cases)

---

## IMPLEMENTATION TIMELINE

### Week 1: Phase 1 - Foundation & Data Layer
- Set up Flutter project with dependencies
- Implement all data models with Hive annotations
- Set up Provider classes
- Load token database from JSON
- **Validation**: Run Phase 1 tests

### Week 2: Phase 2 - Core UI Components
- Implement color utilities and counter pills
- Build TokenCard widget
- Build MultiplierView widget
- Build ContentScreen with toolbar
- **Validation**: Visual inspection of all components

### Week 3: Phase 3 - Token Interactions
- Build TokenSearchScreen with tabs and filters
- Build NewTokenSheet for custom tokens
- Implement all dialog functions
- Test search, favorites, and recent features
- **Validation**: End-to-end token creation flow

### Week 4: Phase 4 - Advanced Features
- Build LoadDeckSheet
- Build CounterSearchScreen
- Build SplitStackSheet with early dismiss
- Build ExpandedTokenView with tap-to-edit
- **Validation**: Complex interactions working

### Week 5: Phase 5 - Polish & Bug Fixes
- Implement gradient borders
- Add wakelock for screen timeout
- Verify dark mode rendering
- Complete manual testing checklist
- **Validation**: Production-ready quality

**Total Estimated Time**: 3-5 weeks (full-time equivalent: 2-3 weeks)

---

## NEXT STEPS FOR AUTONOMOUS IMPLEMENTATION

1. **Set up environment** (Flutter SDK, Xcode, CocoaPods) - 1 hour
2. **Create project and add dependencies** - 30 minutes
3. **Implement Phase 1** (Foundation) - 10-15 hours
4. **Implement Phase 2** (Core UI) - 10-15 hours
5. **Implement Phase 3** (Token Interactions) - 12-16 hours
6. **Implement Phase 4** (Advanced Features) - 14-18 hours
7. **Implement Phase 5** (Polish & Testing) - 10-14 hours

**Total**: 57-79 hours (~2-3 weeks full-time)

---

## DOCUMENT STATISTICS

- **Total Lines**: ~6,200+
- **Code Examples**: 50+
- **Checklists**: 100+
- **Phases**: 5 (all complete)
- **Estimated Implementation Time**: 57-79 hours

**Current Version**: 2.1 (2025-10-28)
**Previous Version**: 2.0 (2025-10-28)
**Changes in 2.1**:
- LoadDeckSheet bug note added
- CounterSearchView "Add to All/One" dialog pattern
- ColorSelectionButton verified in NewTokenSheet and ExpandedTokenView
- Confidence increased to 95%

**Next Review**: After Phase 1-2 completion
**Final Review**: After Phase 5 completion

---

**Ready for Autonomous Implementation**: ✅ Yes (95% confidence)
