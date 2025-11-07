## FLUTTER IN APP PURCHASE HANDLING.
Add in-app purchases for "tip jar" in order for users to support the developer and unlock app icons.
  Flutter provides three main patterns for handling platform differences:
  1. **Use existing packages** (preferred): Packages like `in_app_purchase`, `share_plus`, `url_launcher`
  abstract platform differences
  2. **Platform checks in Dart**: Use `Platform.isIOS` / `Platform.isAndroid` for minor variations
  3. **Platform channels**: Write custom native code when needed

## Condensed Condensed View

Even more condensed than current condensed view, only has Tapped/Untapped Power/Toughness no names or anything else. Tap to expand into a larger detailed card (instead of a detail sheet).

## Art Options

### One-time download
Prompt users on first launch to ask them if they want to download token artwork. If they do, run a script that parses all art urls and downloads artwork for the token database. 

If users choose not to download on first load, the settings menu will offer the option to download all art at a later time.

### Import on demand
Acquire token art on-demand by having the user request it on the token details. This will require the user to connect to internet and will download all available artwork for a given token to the user's app data, then ask them which art they want to use. This should allow them to change the token art later as desired.

Import on demand can be implemented whether or not the one-time download is offered.

### User Upload
No internet connection required. User provides their own artwork which is parsed and used for the assigned token, saved to their local token database for their own use.

## Combat
A way to represent tokens in combat? Not sure how we would handle this. Maybe have a combat button that we can assign tokens to a temporary sheet and resolve attacks/blocks etc. Then have it adjust amounts/tapped amounts based on the outcome of combat. 

Combat would also calculate total damage (when possible) or total damage + wildcards based on the tokens that have wildcard p/t.

## General feedback
Usability is unclear for some players. They tap on "create new" in the reminder text on empty screens, and don't know they can long press things in order to customize how many they add/remove. Controls need to be made more usable and users need easy access to understanding things.

## Snackbar Notifications (REMOVED)
**Status:** All snackbar notifications have been removed due to UI/UX issues and intermittent framework bugs.

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

## New Toolbars
Instead of a top banner, a toolbox icon in a bottom left corner bubble of the app that the user can tap to expand into a larger floating toolbox bubble and interact with. It would have the list of tools. The top right corner of the app can have the info tools (about doubling season, help docs etc.)

In this case, move the multiplier to the bottom left of the app?

In this case, have the container of the bottom tools (multiplier, combat controls, toolbox) be a fading gradient so that tokens "below the fold" disappear under it. There should be padding at the bottom of the last token that's roughly the height of those bottom tools (so that users can scroll up and not have tokens blocked by floating tool buttons).

## Reordering (hold and drag)
- if the user long-presses the token, have it "pop up" to be dragged to a new spot in the list.

## Individual token setting (inside expanded view) to default to entering tapped
- on expanded view include a toggle for "new tokens enter tapped"

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
