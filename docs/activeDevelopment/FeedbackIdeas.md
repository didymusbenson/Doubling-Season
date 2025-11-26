## Code Quality: Hardcoded Timing Delays

**Status:** Technical debt - document for future review

Throughout the codebase, there are several hardcoded timing delays (magic numbers) that could benefit from documentation or centralization:

### Current Delays
- `token_search_screen.dart:507`: `UIConstants.sheetDismissDelay` (300ms) - Wait for sheet animation before operations
- `token_card.dart:575`: `elapsed > 100` milliseconds - Animation timing check for P/T pop effect
- Various sheet dismissal delays to avoid state conflicts

### Recommendations
1. **Document timing rationale**: Add comments explaining why specific durations were chosen
2. **Consider platform variations**: Some delays may need adjustment for slower devices
3. **Centralize constants**: Move magic numbers to `lib/utils/constants.dart` with descriptive names
4. **Review necessity**: Some delays may be workarounds for underlying issues that could be fixed differently

**Priority:** Low - Current delays work correctly, but maintenance and clarity would improve

**Decision:** Document for now, revisit if timing issues emerge on different devices/platforms

---

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

## Gradient Backgrounds in Fadeout Mode

**Status:** Experimental idea - needs more exploration

Currently, color identity gradients only appear on tokens without artwork. Consider showing the gradient on the left 50% of cards in Fadeout mode even when artwork is present.

### Concept
In Fadeout mode:
- Left 50%: Color identity gradient (provides visual color coding)
- Right 50%: Artwork fades in from transparent to opaque
- Creates visual continuity showing both color identity and artwork

### Potential Benefits
- Color-coded identifier at a glance (useful when scanning board state)
- More visually distinct from Full View mode
- Makes better use of the "empty" left side in Fadeout mode

### Concerns
- May create visual noise or compete with artwork
- Gradient might bleed through the artwork's transparent fade area
- Need to test with various artwork/color combinations
- Could confuse visual hierarchy (is gradient part of the card or the artwork?)

### Implementation Notes (if pursued)
- Gradient should be constrained to exactly left 50% (not full-card behind fadeout)
- Consider opacity adjustments for subtlety (e.g., 0.6 alpha on gradient)
- May need different blend modes or masking to prevent "on top of art" effect
- Test with colorless, mono-color, and multi-color tokens

**Decision:** Tabled for now. Focus on core features first, revisit after user feedback on gradients.

## Symbol String Replacement

**Status:** Nice-to-have enhancement for visual polish

Replace bracketed variables in abilities text with proper Magic symbols in the **card view** only.

### Requirements

**Card View (TokenCard):**
- Parse abilities text and replace recognized `{variable}` patterns with corresponding symbols
- Example: `"{T}: Add one mana"` → `"⚪: Add one mana"` (using tap symbol)
- Example: `"Flying, {W}{U}"` → `"Flying, ⚪⚫"` (using mana symbols)
- Only replace variables from a predefined whitelist (to be determined)
- Unrecognized variables render as-is with brackets: `{CUSTOM}` stays as `{CUSTOM}`

**Expanded View (ExpandedTokenScreen):**
- Show raw text with brackets intact (no symbol replacement)
- Allow user to edit text freely, including adding/modifying `{variables}`
- User can manually type `{T}`, `{W}`, etc. and they will display as symbols in card view

### Implementation Notes

- Requires an "abilities text parser/renderer" component
- Parser should be stateless and reusable
- Symbol mapping will be defined later (specific Unicode characters or custom icons)
- No data model changes - symbols are purely display-level transformations
- Backwards compatible with existing tokens (parser handles plain text gracefully)

### Common Variables (Examples)

The exact symbol mappings will be determined later, but common variables include:
- `{T}` - Tap symbol
- `{W}`, `{U}`, `{B}`, `{R}`, `{G}` - Mana symbols (White, Blue, Black, Red, Green)
- `{C}` - Colorless mana
- `{X}` - Variable mana cost
- Numbers: `{1}`, `{2}`, etc. - Generic mana costs

**Priority:** Low - Visual enhancement that improves readability but not critical to functionality.

## Uncentering Full View Artwork

**Status:** Nice-to-have UI enhancement

Currently, Full View artwork mode centers the artwork vertically on the token card (equal cropping from top/bottom). This can cut off important elements of the artwork.

**Requested Change:**
- Align artwork to the top of the card instead of centering vertically
- This matches the Fadeout mode behavior (top-aligned)
- Would make both display styles consistent in vertical alignment

**Implementation:**
- Simple one-line change in `CroppedArtworkWidget` (line 96)
- Change `final dstTop = (size.height - scaledHeight) / 2;` to `final dstTop = 0;`

**Priority:** Low - Minor visual preference, current centered alignment is functional

## Sort By Options

**Status:** Feature idea - not yet implemented

Allow users to customize how token search results are sorted in TokenSearchScreen.

**Current Behavior:**
- Results are hardcoded to sort by popularity first, then alphabetically
- No user control over sort order

**Proposed Options:**
1. **Alphabetical** - Sort tokens A-Z by name
2. **Popular** - Sort by popularity/usage frequency (current default)
3. **Recent** - Sort by most recently used tokens first

**Implementation Notes:**
- Add sort dropdown/segmented control to TokenSearchScreen
- Store preference in SharedPreferences (persist across sessions)
- Apply sort to filtered results (after search query + category filters)
- Default to "Popular" to maintain current behavior for new users

**Benefits:**
- Users who know exact token names can find them faster with alphabetical sort
- "Recent" sort provides quick access pattern different from existing Recent tab
- Flexibility for different user preferences and search patterns

**Priority:** Medium - Nice QoL improvement, current popularity sort works but isn't ideal for all use cases

## Condensed Condensed View

Even more condensed than current condensed view, only has Tapped/Untapped Power/Toughness no names or anything else. Tap to expand into a larger detailed card (instead of a detail sheet).

## Commander Widgets

**Status:** Moved to dedicated documentation

See `docs/activeDevelopment/commanderWidgets.md` for complete details on:
- Krenko Mode (first implementation)
- Future Commander Mode evolution (Chatterfang, Rhys, Brudiclad, etc.)
- System design, migration path, and testing priorities

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


# BETA TESTER SURVEY FEEDBACK

## Addressed by Current Implementation:

### 1. Time/Speed During Actual Play ✅
**Feedback:** "The actions of calculating the tokens or digging through my token box usually takes much longer than turns"

**Current Implementation:**
- **Token Search:** Live search with Recent/Favorites tabs (immediate access to commonly used tokens)
- **Bulk Operations:** Add/remove tokens in bulk via multiplier system (1-1024 range)
- **Quick Actions:** Tap/untap/copy directly from TokenCard without opening detail view
- **Global Actions:** "Untap All", "Clear Summoning Sickness", global +1/+1 counters
- **Deck System:** Save/load entire board states instantly

**Speed is addressed** - operations are single-tap where possible, no physical sorting required.

### 2. Cognitive Load / Math Complexity ✅
**Feedback:** "I have a nervous system disorder that makes my brain foggy. Math is hard sometimes"

**Current Implementation:**
- **App does the math:** Users select quantity + multiplier, app calculates final amount automatically
- **Counter math automated:** +1/+1 and -1/-1 counters auto-cancel, modified P/T displayed automatically
- **No manual tracking:** All amounts, tapped/untapped counts, summoning sickness tracked by app
- **Visual feedback:** Clear display of current state, no mental arithmetic required during play

**Math is fully automated** - users never need to calculate, just tap buttons.

### 3. Trigger Management (Partial) ⚠️
**Feedback:** "Keeping track of triggers and the sheer amount of them once i have doublers and tripplers on the battlefield"

**Partially Addressed:**
- ✅ "Global +1/+1 Everything" handles effects like Cathars' Crusade (apply counters to all tokens at once)
- ✅ Summoning sickness tracking (auto-applied when tokens enter)
- ❌ No trigger reminder system
- ❌ No stack/priority tracking
- ❌ No ETB ability tracking

**Note:** This is explicitly a token-tracking app, not a comprehensive rules engine. Global counter tools help with mass triggers, but players still manage the stack mentally.

## Not Addressed (Requires New Features):

### 4. Complex Calculation with Multiple Stacking Effects ❌
**Feedback:**
- "Exponentially increasing tokens. For example hare apparent with 2-3+ token doublers"
- "Multiple doubling season effects: Doubling Season (x2) + Parallel Lives (x2) + Anointed Procession (x2) = x8"

**Current Limitation:**
- Global multiplier is **manual input** (user sets 1-1024), not an automatic doubler calculator
- User must calculate: "I have 3 doublers, so x8" → manually set multiplier to 8
- No automatic "I have Doubling Season + Parallel Lives → multiply by 4"

**Potential Solution:** See `docs/activeDevelopment/PremiumVersionIdeas.md` for planned "Token Modifier Card Toggles" feature (track active doublers, auto-calculate multiplier).

### 5. Replacement Effects That Aren't Multipliers ❌
**Feedback:** "Having a board state of chatterfang academy manufacturer, doubling season and parallel lives then making a treasure token"

**Current Limitation:**
- Academy Manufacturer: "Create 1 treasure" → "Create 1 treasure + 1 food + 1 clue" **NOT SUPPORTED**
- Chatterfang: "Create N tokens" → "Create N tokens + N squirrels" **NOT SUPPORTED**
- These are replacement effects, not multipliers - require special handling per card

**Potential Solution:** See `docs/activeDevelopment/PremiumVersionIdeas.md` for:
- Chatterfang Mode (auto-creates matching squirrels)
- Academy Manufactor toggle (prompts for additional token types)
- Other commander-specific replacement effects

## Summary:
- ✅ **Speed/efficiency** - fully addressed with quick actions and bulk operations
- ✅ **Math/cognitive load** - fully automated, no manual calculation required
- ⚠️ **Trigger tracking** - mass counter application helps, but no comprehensive trigger system
- ❌ **Stacking doublers** - planned feature, not yet implemented (manual workaround exists)
- ❌ **Replacement effects** - planned premium features for specific cards (Chatterfang, Academy Manufactor)