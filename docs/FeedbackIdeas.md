## FLUTTER IN APP PURCHASE HANDLING.
Add in-app purchases for "tip jar" in order for users to support the developer and unlock app icons.
  Flutter provides three main patterns for handling platform differences:
  1. **Use existing packages** (preferred): Packages like `in_app_purchase`, `share_plus`, `url_launcher`
  abstract platform differences
  2. **Platform checks in Dart**: Use `Platform.isIOS` / `Platform.isAndroid` for minor variations
  3. **Platform channels**: Write custom native code when needed
  
## App Icon and Splash Screen

### Icon 

The application's Icon should be "AppIconSource.png" - It will need to be resized to appropriately fit each target's (ios, android) app store standards.

### Splash Screen

**Implementation Type:** Flutter splash screen (custom widget shown during app initialization)

**Platforms:** iOS and Android (can migrate to native splash later when image assets are created)

**Content:**
Display 5 lines of text, lowercase, right-aligned:
```
angels&
merfolk&
zombies&
goblins&
elves&
```

**Visual Design:**
- **Layout:** 5 equal-height horizontal bars stacking to fill entire screen (each bar is 1/5 screen height)
- **Background colors:** Each line has its own solid color bar (full width, no gradients):
  - `angels&` → Cream background using `ColorUtils.getColorsForIdentity('W').first` (0xFFE8DDB5)
  - `merfolk&` → Blue background using `ColorUtils.getColorsForIdentity('U').first`
  - `zombies&` → Purple background using `ColorUtils.getColorsForIdentity('B').first`
  - `goblins&` → Red background using `ColorUtils.getColorsForIdentity('R').first`
  - `elves&` → Green background using `ColorUtils.getColorsForIdentity('G').first`
- **Text:**
  - Color: White (Colors.white) on all lines
  - Font: System default (SF Pro Display on iOS, Roboto on Android)
  - Weight: FontWeight.w700 (bold)
  - Size: Auto-calculated to be as large as possible without text wrapping to second line
  - Alignment: Right-aligned with 4px right padding (minimal, "against the wall")
  - Case: Lowercase (stylistic choice)
  - Letter spacing: Default

**Font Sizing Logic:**
- Maximum font size where text fits on single line within constraints:
  - Available width = screen width - 8px (4px padding on each side)
  - Use FittedBox with BoxFit.scaleDown or TextPainter to calculate optimal size
  - Test against longest line ("merfolk&" or "zombies&")

**Behavior:**
- **Display duration:** Minimum 1.5 seconds, waits for both timer AND app initialization (Hive + Provider init)
- **Dismissal:**
  - Automatically transitions when BOTH conditions met: 1.5s elapsed AND providers ready
  - User can tap anywhere on splash to skip timer (still requires providers to be ready)
- **Transition:** Cross-fade (splash opacity 1.0→0.0 while ContentScreen opacity 0.0→1.0 simultaneously)
  - Duration: 300ms
  - Curve: Curves.easeInOut

**Implementation Steps:**
1. Create `lib/screens/splash_screen.dart` as StatelessWidget
2. Import `lib/utils/color_utils.dart` for color references
3. Use Column with 5 Expanded widgets (equal height distribution)
4. Each Expanded contains a Container with:
   - Full-width background color
   - Right-aligned Text widget with auto-calculated font size
5. Wrap entire splash in GestureDetector with onTap to skip
6. In `lib/main.dart`:
   - Track three states: _isInitialized, _providersReady, _minTimeElapsed
   - Start 1.5s timer in initState
   - Initialize providers async in initState
   - Only set _isInitialized when BOTH conditions are true
   - Use AnimatedSwitcher to cross-fade between splash and content
   - Tap handler allows skipping timer but still waits for providers

**Technical Notes:**
- Import ColorUtils to ensure splash colors exactly match token card border colors
- Use MediaQuery.of(context).size to get screen dimensions for font sizing
- Consider using LayoutBuilder if needed for responsive calculations
- Ensure splash screen has no dependencies on providers (shows before they're ready)

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

