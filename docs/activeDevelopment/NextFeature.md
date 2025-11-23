---
## 📦 Latest Build Artifacts (v1.3.0+8)

**iOS (.ipa):**
`build/ios/ipa/Doubling Season.ipa` (21.9MB)

**Android (.aab):**
`build/app/outputs/bundle/release/app-release.aab` (44.2MB)

**Built:** 2025-11-20
**Status:** Ready to deploy

---

# Next Feature: Widgets System & Menu Consolidation

**Status:** 🔍 **REFINEMENT PHASE** - Do NOT implement yet. Planning and design discussion required.

## Overview

Two major interconnected features to plan and refine before implementation:

### 1. Floating Action Menu Consolidation
### 2. Widgets System

---

## Part 1: Floating Action Menu Consolidation

### Problem
The floating action menu (FloatingActionMenu) is getting crowded. We need to add a "Widgets" button, and the current structure doesn't scale well.

### Current Menu Structure
1. New Token
2. +1/+1 Everything
3. Untap Everything
4. Clear Summoning Sickness
5. Save Deck
6. Load Deck
7. Board Wipe

### Proposed New Menu Structure
1. **New Token**
2. **Widgets** (NEW - opens widget selection dialog)
3. **Board Update** (NEW - opens submenu with bulk operations)
   - Untap All
   - Clear Summoning Sickness
   - +1/+1 Everything
   - -1/-1 Everything (NEW feature)
   - Board Wipe
4. **Save Deck**
5. **Load Deck**

### Rationale
- Groups related bulk operations into a logical submenu
- Reduces top-level menu items from 7 to 5
- Makes room for Widgets button without further crowding
- "Board Update" clearly indicates batch operations on all tokens

### -1/-1 Everything Feature (NEW)
**Context:** From `FeedbackIdeas.md` lines 11-18

Mirrors the existing +1/+1 Everything feature:
- Adds a -1/-1 counter to all tokens with power/toughness
- Useful for: Night of Souls' Betrayal, Black Sun's Zenith, etc.
- Same snapshot-based iteration pattern
- Same P/T pop animation
- Red color theme (debuff/weakening)

### Alternative Proposals

**Alternative 1: Further consolidation**
```
1. New Token
2. Widgets
3. Board Actions (submenu: Untap, Clear SS, +1/+1, -1/-1, Wipe)
4. Decks (submenu: Save, Load)
```
Reduces to 4 top-level items. Groups deck operations together.

**Alternative 2: Icon-only menu**
Use icons without text labels, add tooltips. Allows more items in less space. May hurt discoverability.

**Alternative 3: Contextual visibility**
Only show certain actions when relevant (e.g., hide Board Update when board is empty). Dynamic but potentially confusing.

**Questions to Answer:**
- [ ] Should "Board Update" have a confirmation dialog before opening submenu?
- [ ] Icon for "Board Update" menu item? (Currently thinking: refresh/update icon)
- [ ] Should submenu items have icons or text labels?
- [ ] Do we need a "Close" button in the Board Update submenu?
- [ ] Should we add analytics to track which bulk operations are most used?

---

## Part 2: Widgets System

### Concept

**Widgets** (also called "Card Widgets" or "Commander Widgets") are special cards that appear in the token list alongside regular tokens. They are NOT tokens themselves, but provide specialized controls and tracking for specific commanders or game mechanics.

### Core Widget Design (CONFIRMED)

**Widget Placement:**
- Widgets appear **IN the token list**, mixed with tokens
- When added, widgets insert at the **top of the list** (but can be reordered)
- Users can drag widgets to reorder them like any other card
- Swiping a widget away dismisses it (removes from list)
- Multiple widgets can be active simultaneously

**Widget Selection Menu:**
- Accessed via FAB menu → "Widgets" button
- Shows list of available widget types (Krenko, Chatterfang, Rhys, etc.)
- Active widgets shown with **checkmark or highlight**
- Tapping a widget adds it to the token list (if not already present)
- Tapping an active widget removes it from the list

**Use Case Example:**
1. Player has Krenko, Mob Boss on their battlefield
2. Player opens FAB menu → Widgets
3. Player taps "Krenko, Mob Boss" widget
4. Krenko widget card appears at top of token list
5. Player uses widget to track Krenko's power and create goblins
6. When done, player swipes widget away or unchecks it in menu

### Examples of Widgets
- **Krenko Widget**: Tracks Krenko's power and nontoken goblin count, creates goblin tokens on demand
- **Chatterfang Widget**: Auto-creates squirrels when other tokens are created
- **Rhys Widget**: Doubles all tokens or creates Elf Warriors
- **Doubling Season Widget**: Automatically doubles token multiplier when active
- **Cathars' Crusade Widget**: Reminder to add +1/+1 counters when tokens enter

### Widget Characteristics

**Similarities to Tokens:**
- Use TokenCard visual design (same styling as tokens)
- Appear in the same scrollable list as tokens
- Can be reordered via drag-and-drop
- Can be dismissed via swipe gesture
- Persist across sessions (Hive storage)
- Have order field for positioning

**Differences from Tokens:**
- Different action buttons (widget-specific controls, NOT tap/untap/add/remove)
- No amount, tapped/untapped counts, or summoning sickness
- No P/T or counters (unless widget-specific)
- Custom UI per widget type
- Distinguished visually (different icon, color scheme, or border)

### Key Design Questions

#### 1. Widget Data Model

**Proposed Base Model:**
```dart
@HiveType(typeId: X)
class CardWidget extends HiveObject {
  @HiveField(0) String widgetType; // 'krenko', 'chatterfang', 'doublingseason'
  @HiveField(1) Map<String, dynamic> state; // Widget-specific state (power, counters, etc.)
  @HiveField(2) DateTime createdAt;
  @HiveField(3) double order; // For reordering in token list
}
```

**Storage Strategy (CONFIRMED):**
- [ ] **Same Hive box as tokens?** OR separate `widgets` box?
  - **Recommendation:** Separate box to avoid type confusion, but both use `order` field for unified list display
- [x] Widgets do NOT have a "disabled" state - they are either in the list or not
- [x] Swiping widget deletes it from the list (can be re-added via menu)
- [ ] Widget state persists even when widget is removed (so re-adding restores previous values)?

**Questions:**
- [ ] How do we handle widget-specific state? (Generic Map? Subclasses? JSON serialization?)
- [ ] Should we merge tokens and widgets into one unified list view, or keep separate boxes?
- [ ] How do we distinguish widgets visually in the list?

#### 2. Unified List Display

**Challenge:** How do we display widgets and tokens in one unified list?

**Options:**
- **Option A:** Merge into single list, sorted by `order` field
  - Widgets and tokens both implement a common interface for rendering
  - List builder checks type and renders appropriate card
  - Pro: Simple, unified drag-and-drop
  - Con: More complex rendering logic

- **Option B:** Two separate lists, visually unified
  - Widgets box and tokens box separate
  - UI combines them for display
  - Pro: Clean data separation
  - Con: Complex drag-and-drop between types

**Recommendation:** Start with Option A (single merged list), use type checking in item builder

#### 3. Widget UI Rendering

**Challenge:** Each widget has different controls and layout

**Option A: Hardcoded widget cards**
```dart
Widget buildWidgetCard(CardWidget widget) {
  switch (widget.widgetType) {
    case 'krenko':
      return KrenkoWidgetCard(widget: widget);
    case 'chatterfang':
      return ChatterfangWidgetCard(widget: widget);
    // ...
  }
}
```

**Option B: Generic widget card with configuration**
```dart
class WidgetCard extends StatelessWidget {
  final CardWidget widget;
  final WidgetConfig config; // Defines layout, buttons, fields

  // Config loaded from registry
}
```

**Recommendation:** Start with Option A (hardcoded), extract common patterns later

#### 4. Token Creation with Special Rules

Some widgets create tokens with special rules. **Can we standardize these rule types?**

**Common Rule Types:**
1. **Multiplier Modifier**: "Double all token creation" (Doubling Season, Parallel Lives)
2. **Replacement Effect**: "When you create X, also create Y" (Chatterfang, Academy Manufactor)
3. **Power-based Creation**: "Create N tokens where N = [calculation]" (Krenko)
4. **Copy Effect**: "Create copies of existing tokens" (Rhys, Brudiclad)
5. **Conditional Creation**: "If condition, create token" (varies)

**Standardization Approach:**

**Option A: Rule Engine Pattern**
```dart
abstract class TokenCreationRule {
  int modifyAmount(int baseAmount);
  List<TokenTemplate> additionalTokens(TokenTemplate original);
  bool shouldApply(TokenCreationContext context);
}

class DoublingRule extends TokenCreationRule {
  int modifyAmount(int baseAmount) => baseAmount * 2;
}

class ChatterfangRule extends TokenCreationRule {
  List<TokenTemplate> additionalTokens(TokenTemplate original) {
    return [SquirrelTemplate(amount: original.amount)];
  }
}
```

**Option B: Widget Behavior Interface**
```dart
abstract class WidgetBehavior {
  Future<void> onTokenCreated(Item token, TokenProvider provider);
  Future<void> onTokenTapped(Item token, TokenProvider provider);
  Future<void> customAction(String actionId, Map<String, dynamic> params);
}
```

**Option C: Event-based System**
```dart
// Widgets register for events
enum TokenEvent { created, tapped, destroyed, modified }

class Widget {
  void onEvent(TokenEvent event, Item token) {
    // Widget-specific behavior
  }
}
```

**Recommendation:** Keep it simple for now - widgets create tokens directly via methods in TokenProvider. Event-based system can be added later if needed.

#### 5. Widget Selection Menu UI

**Requirements (CONFIRMED):**
- Shows list of all available widget types
- Indicates which widgets are currently active (checkmark or highlight)
- Tapping inactive widget adds it to token list
- Tapping active widget removes it from token list (or shows confirmation?)
- Visual design similar to other action sheets

**Implementation approach:**
- Widget registry maps widget types to display info (name, description, icon, color)
- Menu queries active widgets from Hive box
- Toggle logic: check if widget exists → add or remove

#### 6. Widget State Persistence

Widgets need to persist state (e.g., Krenko's power, nontoken goblin count).

**Option A: Generic Map in CardWidget model**
```dart
Map<String, dynamic> state = {
  'power': 3,
  'nontokenGoblins': 2,
};
```
Pro: Flexible, easy to implement. Con: No type safety, prone to errors.

**Option B: Subclass per widget type**
```dart
class KrenkoWidget extends CardWidget {
  @HiveField(10) int power;
  @HiveField(11) int nontokenGoblins;
}
```
Pro: Type-safe, clear structure. Con: Requires Hive adapter per widget type, more boilerplate.

**Option C: JSON serialization with typed classes**
```dart
class WidgetState {
  Map<String, dynamic> toJson();
  static WidgetState fromJson(Map<String, dynamic> json, String type);
}

class KrenkoState extends WidgetState {
  int power;
  int nontokenGoblins;
}
```
Pro: Flexible + type-safe, good balance. Con: More complex serialization, but manageable.

**Recommendation:** Start with Option A (Map) for MVP, migrate to Option C if needed for type safety.

### Implementation Priorities

**Phase 1: Foundation**
- [ ] Finalize Widget data model
- [ ] Create Widget Hive box and storage
- [ ] Implement widget selection dialog ("Add Widget" button)
- [ ] Create base WidgetCard UI component

**Phase 2: First Widget (Krenko)**
- [ ] Implement Krenko widget following refined design
- [ ] Test token creation with special rules
- [ ] Validate persistence and state management
- [ ] Learn from implementation challenges

**Phase 3: Standardization**
- [ ] Extract common patterns from Krenko implementation
- [ ] Create reusable widget components/behaviors
- [ ] Document widget creation guide

**Phase 4: Expansion**
- [ ] Add Chatterfang widget
- [ ] Add Doubling Season widget
- [ ] Add Rhys widget
- [ ] Iterate on standardization

### Questions That MUST Be Answered Before Implementation

#### Architecture:
- [ ] Where do widgets appear in the UI? (mixed with tokens, dedicated section, collapsible banner?)
- [ ] Separate Hive box or same box as tokens?
- [ ] How do we version widget types for future expansion?
- [ ] Can users have multiple widgets active simultaneously?

#### Data Model:
- [ ] Base Widget class structure?
- [ ] How to handle widget-specific state? (Map, subclasses, JSON?)
- [ ] Do widgets have order/position like tokens?
- [ ] Can widgets be disabled without deleting?

#### Behavior System:
- [ ] How do widgets hook into token creation? (events, callbacks, rules engine?)
- [ ] How do we prevent widget conflicts? (e.g., two doubling effects)
- [ ] Should widgets have priority/ordering for rule application?
- [ ] How do widgets access TokenProvider and SettingsProvider?

#### UI/UX:
- [ ] What actions are common across all widgets? (delete, disable, configure?)
- [ ] How do users discover available widgets?
- [ ] Should widgets have help/info tooltips explaining what they do?
- [ ] Do widgets need configuration screens or inline controls?

#### Token Creation Standardization:
- [ ] What rule types do we need to support? (multiplier, replacement, conditional, copy?)
- [ ] How do rules combine? (Doubling Season + Parallel Lives = x4?)
- [ ] Should widgets modify the global multiplier or apply separately?
- [ ] How do we show users what rules are active?

#### Performance:
- [ ] How many widgets can be active at once before performance issues?
- [ ] Do widget rules run on every token creation (performance impact)?
- [ ] Should we batch widget rule application for bulk operations?
- [ ] Memory footprint of widget state storage?

### Success Criteria

Before implementing, we should be able to answer:
1. **What is a widget?** (clear, concise definition)
2. **How do widgets work?** (behavior system, rule application)
3. **Where do widgets live?** (UI placement, data storage)
4. **What can widgets do?** (capabilities, limitations)
5. **How do users interact with widgets?** (creation, configuration, deletion)
6. **How do widgets stay performant?** (optimization strategy)

### Reference Materials

**Existing Documentation:**
- `commanderWidgets.md` - Krenko Mode detailed design (good foundation)
- `FeedbackIdeas.md` - User feedback on replacement effects and doublers
- `PremiumVersionIdeas.md` - Token modifier cards concept

**Related Code:**
- `lib/widgets/token_card.dart` - Visual design to mirror
- `lib/models/item.dart` - Data model pattern to follow
- `lib/providers/token_provider.dart` - Provider pattern for widget management

---

## Timeline

**Now → Refinement Complete:** Design discussion, answer key questions, document decisions
**After Refinement:** Implementation can begin with clear architectural foundation
**No deadline:** This is a major feature that must be done right

---

## Notes for Implementation

- Start with Krenko widget as proof-of-concept (already well-designed in commanderWidgets.md)
- Extract patterns and create framework AFTER seeing what works
- Don't over-engineer - build one widget well, then generalize
- Performance matters - test with 10+ widgets and 100+ tokens on screen
- User testing after first widget to validate approach before expanding

---

**⚠️ CRITICAL: Do NOT begin implementation until these design questions are answered and documented.**
