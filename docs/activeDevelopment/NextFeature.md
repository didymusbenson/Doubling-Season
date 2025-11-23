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

**Widgets** are persistent UI elements (similar to token cards) that apply special rules and provide specialized controls for specific commanders or game mechanics.

This is a generalization of the "Commander Mode" concept (see `commanderWidgets.md`), but more flexible and modular.

### Examples of Widgets
- **Krenko Widget**: Generates goblins based on Krenko's power and goblin count
- **Chatterfang Widget**: Auto-creates squirrels when other tokens are created
- **Rhys Widget**: Doubles all tokens or creates Elf Warriors
- **Doubling Season Widget**: Automatically doubles token multiplier when active
- **Cathars' Crusade Widget**: Reminder to add +1/+1 counters when tokens enter

### Widget Characteristics

**Similarities to Tokens:**
- Follow same card styling (TokenCard visual design)
- Appear in token list (or dedicated widget area?)
- Can be reordered, deleted
- Persist across sessions (Hive storage)

**Differences from Tokens:**
- Different action buttons (not tap/untap/add/remove)
- No tapped/untapped state (usually)
- No summoning sickness
- Custom functionality per widget type
- Many have "create token with special rules" capability

### Key Design Questions

#### 1. Widget Placement
**Option A:** Mixed with tokens in main list
- Pros: Simple, reorderable with tokens
- Cons: May clutter token view, confusing for users

**Option B:** Dedicated "Widgets" section above/below token list
- Pros: Clear separation, doesn't clutter tokens
- Cons: Fixed position, takes screen space even when not in use

**Option C:** Collapsible "Widgets" banner at top (like Krenko Mode banner)
- Pros: Can hide when not needed, clear separation
- Cons: Limited to one widget at a time? Or stacked banners?

**Recommendation needed:** Where do widgets live in the UI?

#### 2. Widget Data Model

**Proposed Base Model:**
```dart
@HiveType(typeId: X)
class Widget extends HiveObject {
  @HiveField(0) String widgetType; // 'krenko', 'chatterfang', 'doublingseason'
  @HiveField(1) Map<String, dynamic> state; // Widget-specific state (power, counters, etc.)
  @HiveField(2) DateTime createdAt;
  @HiveField(3) double order; // For reordering
  @HiveField(4) bool isActive; // Can widgets be toggled on/off?
}
```

**Questions:**
- [ ] Do widgets need unique IDs separate from tokens?
- [ ] Should widgets be in the same Hive box as tokens or separate box?
- [ ] How do we handle widget-specific state? (Generic Map? Subclasses?)
- [ ] Do widgets have a "disabled" state or do users delete them when not needed?

#### 3. Token Creation with Special Rules

Many widgets create tokens with special rules. **Can we standardize these rule types?**

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

**Recommendation needed:** Which pattern fits best? Or hybrid approach?

#### 4. Widget Action Buttons

Widgets need custom action buttons. How do we define these?

**Option A: Hardcoded per widget type**
```dart
Widget buildActions(WidgetType type) {
  switch (type) {
    case WidgetType.krenko:
      return KrenkoActions();
    case WidgetType.chatterfang:
      return ChatterfangActions();
  }
}
```

**Option B: Action definition in widget model**
```dart
class Widget {
  List<WidgetAction> actions; // Defined per instance
}

class WidgetAction {
  String label;
  IconData icon;
  void Function() onPressed;
}
```

**Option C: Declarative action system**
```dart
class Widget {
  List<ActionDefinition> getActions() {
    return [
      ActionDefinition(
        id: 'create_goblins',
        label: 'Waaagh!',
        icon: Icons.add,
        params: {'calculation': 'power_based'},
      ),
    ];
  }
}
```

**Recommendation needed:** How do we define widget-specific actions?

#### 5. Widget State Persistence

Widgets need to persist state (e.g., Krenko's power, nontoken goblin count).

**Option A: Generic Map in Widget model**
```dart
Map<String, dynamic> state = {
  'power': 3,
  'nontokenGoblins': 2,
};
```
Pro: Flexible. Con: No type safety.

**Option B: Subclass per widget type**
```dart
class KrenkoWidget extends Widget {
  int power;
  int nontokenGoblins;
}
```
Pro: Type-safe. Con: Requires Hive adapter per widget type.

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
Pro: Flexible + type-safe. Con: More complex serialization.

**Recommendation needed:** How do we handle widget state?

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
