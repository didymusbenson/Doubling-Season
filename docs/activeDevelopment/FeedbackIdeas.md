## FLUTTER IN APP PURCHASE HANDLING.
Add in-app purchases for "tip jar" in order for users to support the developer and unlock app icons.
Flutter provides three main patterns for handling platform differences:
1. **Use existing packages** (preferred): Packages like `in_app_purchase`, `share_plus`, `url_launcher`
   abstract platform differences
2. **Platform checks in Dart**: Use `Platform.isIOS` / `Platform.isAndroid` for minor variations
3. **Platform channels**: Write custom native code when needed

## Global Counter Tools

### -1/-1 Everything
Similar to "+1/+1 Everything", adds a -1/-1 counter to all tokens with power/toughness. Useful for effects like Night of Souls' Betrayal, Black Sun's Zenith, etc.

Implementation would mirror the +1/+1 tool:
- Same position in action menu
- Same snapshot-based iteration
- Same P/T pop animation
- Red color theme (debuff/weakening)

## Condensed Condensed View

Even more condensed than current condensed view, only has Tapped/Untapped Power/Toughness no names or anything else. Tap to expand into a larger detailed card (instead of a detail sheet).

## Commander Mode (Evolution of Krenko Mode)

### Concept
Replace the single-purpose "Krenko Mode" (documented in NextFeature.md) with a flexible "Commander Mode" system that provides specialized tools for multiple popular token-generating commanders. This allows adding commander-specific features without cluttering the UI for users who don't need them.

### Core UI Structure
**Top Banner** (similar to Krenko Mode banner, but adaptive):
- **Commander Selection Field**: Tap to open commander picker
  - Shows "Select Commander..." when none chosen
  - Shows commander name when selected
  - Opens modal with predefined commander list
- **Commander-Specific Controls**: Dynamic content based on selected commander
  - Krenko: Power stepper + Nontoken Goblins + "Waaagh!" button
  - Chatterfang: (Controls TBD)
  - Rhys: (Controls TBD)
  - Each commander gets custom UI tailored to their mechanics

### Settings Integration
**Location:** Settings screen
- **Toggle:** "Commander Mode" (on/off)
- **Commander Selection:** Dropdown or modal picker showing available commanders
- **Storage:**
  - `commanderModeEnabled` (bool)
  - `selectedCommander` (string, e.g., "krenko", "chatterfang", "rhys")
  - Commander-specific state (e.g., `krenkoPower`, `chatterfangSquirrels`, etc.)

### MVP Commanders

#### 1. Krenko, Mob Boss
**Ability:** "Tap: Create X 1/1 red Goblin creature tokens, where X is the number of Goblins you control."

**Controls:**
- **Krenko's Power** stepper (1-99, default 3)
- **Nontoken Goblins** stepper (0-99, default 0)
- **"Waaagh!" Button**: Creates 1/1 red Goblin tokens
  - Option A: Based on Krenko's power × multiplier
  - Option B: Based on total goblins controlled × multiplier
  - Adds to existing goblin token or creates new

**Color Theme:** Red (matches goblin tribal theme)

**Implementation:** Already documented in NextFeature.md - migrate to commander system

---

#### 2. Chatterfang, Squirrel General
**Ability:** "If one or more tokens would be created under your control, those tokens plus that many 1/1 green Squirrel creature tokens are created instead."

**Controls:**
- **Token Being Created** selector (dropdown or text field)
  - User selects/inputs token name and amount
  - Example: "3 Treasure" or "5 Food"
- **"Create with Chatterfang" Button**
  - Creates the original tokens (e.g., 3 Treasure)
  - ALSO creates equal number of 1/1 green Squirrel tokens (3 Squirrels)
  - Applies global multiplier to both types
  - Adds to existing squirrel token or creates new

**Alternative Simpler Approach:**
- **Token Amount** stepper (how many tokens being created)
- **"Add Squirrels" Button**
  - Just creates squirrel tokens equal to amount × multiplier
  - User handles creating other tokens manually
  - Simpler implementation, covers 80% of use cases

**Squirrel Token Definition:**
- Name: "Squirrel"
- P/T: "1/1"
- Colors: "G" (Green)
- Type: "Creature - Squirrel"
- Abilities: ""

**Color Theme:** Green (matches squirrel tribal theme)

**Questions to Answer:**
- [ ] Do we need to track what tokens triggered Chatterfang? (probably not)
- [ ] Should there be a "quick add squirrels" that counts recent tokens? (nice to have)
- [ ] Do we need second ability tracking? ("Each opponent loses 1 life per dying creature token")

---

#### 3. Rhys the Redeemed
**Abilities:**
- **Ability 1:** "{2}{G/W}, Tap: Create a 1/1 green and white Elf Warrior creature token."
- **Ability 2:** "{4}{G/W}{G/W}, Tap: For each creature token you control, create a token that's a copy of that creature."

**Controls:**
- **Ability 1 Button**: "Create Elf Warrior"
  - Creates 1 Elf Warrior × global multiplier
  - Simple token creation

- **Ability 2 Button**: "Double All Tokens" (this is the complex one)
  - For EACH token type on board:
    - Count total amount (including tapped/untapped/summoning sick)
    - Create NEW token card with same properties (name, P/T, abilities, colors, type, counters, artwork)
    - Set amount to original amount × global multiplier
    - Result: Doubles your token count (or more with multiplier)
  - Example: If you have 5 Elves, 3 Goblins, creates 5 new Elves + 3 new Goblins
  - **With multiplier:** If multiplier is 2, creates 10 Elves + 6 Goblins (quadruples!)

**Elf Warrior Token Definition:**
- Name: "Elf Warrior"
- P/T: "1/1"
- Colors: "GW" (Green/White)
- Type: "Creature - Elf Warrior"
- Abilities: ""

**Color Theme:** Green/White (matches Selesnya tokens theme)

**Implementation Complexity:** HIGH
- Ability 2 requires deep-copying all token properties
- Must handle counters, artwork, abilities, everything
- Need to clarify: Do copied tokens enter tapped? (probably untapped)
- Multiplier interaction creates explosive growth (intentional, but need UI warning?)

**Questions to Answer:**
- [ ] Do copied tokens enter tapped or untapped? (Magic rule: untapped)
- [ ] Do copied tokens have summoning sickness? (Probably yes if global setting enabled)
- [ ] Should there be a confirmation dialog for "Double All Tokens"? (YES - it's powerful/destructive)
- [ ] Do we copy counters too? (Magic rule: yes, they're copies)
- [ ] Do we copy artwork URLs? (Yes, easier implementation)
- [ ] Performance: What if user has 20 different token types? (Should be fine, but test)

---

### System Design

**Commander Registry** (code organization):
```dart
enum Commander {
  krenko('krenko', 'Krenko, Mob Boss'),
  chatterfang('chatterfang', 'Chatterfang, Squirrel General'),
  rhys('rhys', 'Rhys the Redeemed');

  final String id;
  final String displayName;
  const Commander(this.id, this.displayName);
}
```

**Dynamic Banner Widget:**
```dart
Widget buildCommanderBanner(Commander commander) {
  switch (commander) {
    case Commander.krenko:
      return KrenkoBanner();
    case Commander.chatterfang:
      return ChatterfangBanner();
    case Commander.rhys:
      return RhysBanner();
  }
}
```

**Color Theme System:**
```dart
Color getCommanderThemeColor(Commander? commander) {
  if (commander == null) return Colors.blue; // Default
  switch (commander) {
    case Commander.krenko: return Colors.red;
    case Commander.chatterfang: return Colors.green;
    case Commander.rhys: return Colors.lightGreen; // Green/White blend
  }
}
```

### Migration Path

**Phase 1:** Implement Commander Mode framework
- Add commander selection UI
- Create base banner widget system
- Implement theme color switching

**Phase 2:** Migrate Krenko Mode
- Move Krenko banner to commander system
- Update settings to use new storage keys
- Maintain backward compatibility (auto-select Krenko if old setting enabled)

**Phase 3:** Add Chatterfang
- Implement squirrel token creation
- Add Chatterfang banner widget

**Phase 4:** Add Rhys
- Implement Elf Warrior creation
- Implement "Double All Tokens" (most complex)

### Future Expansion
Other popular token commanders to consider:
- **Brudiclad, Telchor Engineer**: Convert tokens to copies
- **Trostani, Selesnya's Voice**: Populate mechanic
- **Ghired, Conclave Exile**: Populate on attack
- **Adrix and Nev, Twincasters**: Double token creation
- **Mondrak, Glory Dominus**: Triple token creation
- **Jetmir, Nexus of Revels**: Rewards for token count
- **Hazezon, Shaper of Sand**: Desert token tracking

Each can be added without affecting existing commanders - modular system.

### Benefits
- **Scalable**: Easy to add new commanders without UI clutter
- **Targeted**: Users only see tools for their chosen commander
- **Flexible**: Each commander gets custom controls for their mechanics
- **Theme Integration**: Each commander can have unique color scheme
- **User Choice**: Players pick their commander, app adapts to their deck

### Testing Priorities
- [ ] Commander selection persists across app restarts
- [ ] Theme colors update when commander changes
- [ ] Disabling Commander Mode hides banner and restores default theme
- [ ] Each commander's token creation works correctly
- [ ] Multiplier applies correctly for each commander
- [ ] Rhys "Double All Tokens" handles complex board states
- [ ] Performance with 10+ different token types (Rhys doubling)

## Combat
A way to represent tokens in combat? Not sure how we would handle this. Maybe have a combat button that we can assign tokens to a temporary sheet and resolve attacks/blocks etc. Then have it adjust amounts/tapped amounts based on the outcome of combat.

Combat would also calculate total damage (when possible) or total damage + wildcards based on the tokens that have wildcard p/t.


## Snackbar Notifications (REMOVED)
**Status:** All snackbar notifications have been removed due to UI/UX issues and intermittent framework bugs.

**Future Snackbar Needs:**
- **Artwork download failure**: When background artwork download fails, show error snackbar to inform user (currently fails silently and resets to no artwork)

**Previous Locations (for reference):**
- `lib/screens/content_screen.dart:467-469` - Save deck validation ("Please enter a deck name")
- `lib/screens/content_screen.dart:494-496` - Save deck confirmation ("Deck saved")
- `lib/widgets/load_deck_sheet.dart:112-114` - Load deck confirmation (empty board)
- `lib/widgets/load_deck_sheet.dart:157-159` - Load deck confirmation (after clear/add)
- `lib/widgets/load_deck_sheet.dart:206-208` - Delete deck confirmation
- `lib/widgets/split_stack_sheet.dart:341-343` - Split stack confirmation
- `lib/widgets/new_token_sheet.dart:210-212` - New token validation ("Please enter a token name")
- `lib/screens/counter_search_screen.dart:252-254` - Counter added (all tokens)
- `lib/screens/counter_search_screen.dart:258-260` - Split validation ("Cannot split - only 1 token")
- `lib/screens/counter_search_screen.dart:281-283` - Split + counter added (1 token)
- `lib/screens/counter_search_screen.dart:294-296` - Custom counter added (all tokens)
- `lib/screens/counter_search_screen.dart:300-302` - Split validation (custom counter)
- `lib/screens/counter_search_screen.dart:323-325` - Split + custom counter added (1 token)

**Issues Encountered:**
1. Snackbars blocked UI elements at the bottom of the screen
2. Caused intermittent Flutter framework assertions (`_dependents.isEmpty`) when shown during widget tree transitions
3. Timing conflicts between dialog dismissal and snackbar display
4. Race conditions with splash screen to main app transition

**Future Implementation:**
If user feedback indicates that confirmation/validation messages are needed, consider alternative approaches:
- Non-blocking toast overlays positioned at top of screen
- Brief visual feedback animations on affected UI elements
- Status indicators within the UI context (e.g., deck list updates to show newly saved deck)
- Dialog-based confirmations for critical operations (already in place for destructive actions)

## Individual token setting (inside expanded view) to default to entering tapped
- on expanded view include a toggle for "new tokens enter tapped"

## New tokens enter tapped on detail view
- Add a toggle to the token detail view that automatically increases the tapped count when the token amount increases
- When enabled, any increase to the token amount (via add action or manual input) will automatically increment the tapped count by the same amount
- This ensures newly added tokens are tracked as tapped without manual adjustment
- Useful for tokens that typically enter the battlefield tapped

## Import token list from deck source (moxfield, arkidect)
- user pastes a link to their deck list and it automatically populates the tokens they need to use

## Future Non-Token Type Handling (Counters, States, Bounties, Dungeons)
**TODO: Flesh out requirements**

Currently excluded from search results (not traditional tokens):
- **Counters** (6 tokens): Energy Reserve, Poison Counter, Radiation, Experience Counter, etc.
- **States** (12 tokens): The Monarch, The Ring, On an Adventure, etc.
- **Bounties** (12 tokens): Outlaw bounty mechanic
- **Dungeons** (4 tokens): Dungeon cards

These are game state markers, not creature/artifact tokens. Need to determine:
- Should they have a dedicated UI section?
- Should they be accessible through search with a special filter?
- Should they be integrated with the counter management system?
- Are they useful enough to include at all, or should they remain excluded?

**IMPORTANT:** Currently filtered out in `HOUSEKEEPING/process_tokens_with_popularity.py` in the `clean_token_data()` function. If we decide to support these types in the future, we'll need to remove that filtering logic and regenerate the token database.

## Code Quality / Lint Issues (Low Priority)

Minor lint warnings that don't affect functionality:

- Unnecessary string interpolation braces in token_provider.dart (4 instances)
  - Lines 135, 169, 193, 216: Use `$variable` instead of `${variable}` for simple variables

- Parameter name shadows type name in token_search_screen.dart:668
  - Parameter `num` shadows Dart's built-in `num` type
  - Consider renaming to `number`, `count`, or `quantity`

- Private field could be final in counter_database.dart:35
  - `_favoriteCounters` could be marked as `final` since it's never reassigned

- Use SizedBox instead of Container for whitespace
  - color_filter_button.dart:39: Container used only for spacing
  - color_selection_button.dart:56: Container used only for spacing
  - Replace with `SizedBox(width: X)` or `SizedBox(height: Y)` for better performance

## Precaching and Plus One Everything Concerns (v1.3.0 Build Review)

### Error Messages Not Displayed to User
- `TokenProvider` sets `_errorMessage` in methods like `addPlusOneToAll()` but no UI consumes this field
- Users won't see error messages if bulk operations fail
- **Impact**: Silent failures lead to confusion when +1/+1 counters aren't applied to all tokens
- **Potential fix**: Add error snackbar display in ContentScreen when `TokenProvider.errorMessage` changes

### No Confirmation Dialog for Global +1/+1
- The "Global +1/+1" feature has no confirmation dialog and can't be undone
- Accidental taps could modify hundreds of tokens
- **Recommendation**: Add confirmation dialog similar to "Untap All" pattern

### Performance: Animation Controllers on Every Card
- `_AnimatedPowerToughness` creates a `SingleTickerProviderStateMixin` for every token card
- With 50+ tokens on screen, this creates 50+ animation controllers
- **Impact**: Memory overhead and unnecessary animations when tokens are off-screen
- **Better approach**: Use `AnimatedContainer` or `ImplicitlyAnimatedWidget` which are lighter weight

### Bulk Operation Performance
- `addPlusOneToAll()` uses `await item.save()` inside a loop
- For 100 tokens, this is 100 sequential database writes
- **Better approach**: Collect all changes first, then batch save or use `Future.wait()`

### Silent Failures in Art Precaching
- Precaching errors are caught with just `debugPrint` - no user feedback
- **Impact**: Users won't know why artwork isn't appearing
- **Minor issue** since it retries during actual creation
