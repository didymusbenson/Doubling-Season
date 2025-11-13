# Next Feature: Token Artwork Display

## Overview
Add the ability to display official Magic: The Gathering token artwork in the app by utilizing Scryfall's CDN image URLs. Images will be downloaded on-demand at the user's request and cached locally for offline use.

## Legal & Attribution Requirements

### Scryfall CDN Usage
- **Approved method**: Direct CDN links from `cards.scryfall.io` (provided in Cockatrice XML)
- **No API integration required**: Using direct image URLs (not hitting Scryfall's REST API)
- **Image format**: Full card images (`/large/front/...`) which include copyright text on card frame
- **No modifications allowed**: Images must be displayed as-is (no cropping, distortion, color shifting, etc.)
- **No paywall**: Artwork feature must remain free (can monetize other features separately)

### Attribution Requirements
Must add copyright notice to About screen (Credits section):

```
Card images © Wizards of the Coast LLC, a subsidiary of Hasbro, Inc.
Images provided by Scryfall. Scryfall is not produced by or endorsed
by Wizards of the Coast.

Doubling Season is unofficial Fan Content permitted under the Fan
Content Policy. Not approved/endorsed by Wizards. Portions of the
materials used are property of Wizards of the Coast. © Wizards of
the Coast LLC.
```

This covers:
- WotC copyright acknowledgment
- Scryfall credit for image hosting
- Required WotC Fan Content Policy statement
- General materials acknowledgment

## Data Source: Cockatrice XML

Token artwork URLs are already available in the source XML but currently stripped during processing.

**Example XML structure:**
```xml
<card>
    <name>A Mysterious Creature</name>
    <text>...</text>
    <prop>
        <type>Creature</type>
        <pt>2/2</pt>
    </prop>
    <set picURL="https://cards.scryfall.io/large/front/c/7/c76a6163-6fd9-4cdf-9b14-07f75c2f0fa1.jpg?1720338560">ACR</set>
    <set picURL="https://cards.scryfall.io/large/front/2/4/241b3b6d-a25f-4a43-b5d6-1d1079e7e498.jpg?1705432997">MKM</set>
</card>
```

**Key observations:**
- Each token can have **multiple art variants** (different sets)
- Set code provided (e.g., "ACR", "MKM")
- Direct CDN URLs to full card images
- URLs include cache-busting timestamp parameter

## Required Changes

### 1. Update Token Database Processing Script
**File:** `docs/housekeeping/process_tokens_with_popularity.py`

**Current behavior:** Script ignores `<set picURL="...">` tags entirely

**Required behavior:** Extract and store artwork URLs with set information

**Implementation approach:**
- Parse all `<set>` tags for each token
- Extract `picURL` attribute and set code (tag content)
- Store as array of art variant objects: `[{set: "ACR", url: "https://..."}, ...]`
- Preserve deduplication logic (may need to handle art merging for duplicates)
- Consider storage format in JSON (array of objects vs parallel arrays)

**Output schema addition to `token_database.json`:**
```json
{
  "name": "A Mysterious Creature",
  "abilities": "...",
  "pt": "2/2",
  "colors": "",
  "type": "Creature",
  "artwork": [
    {
      "set": "ACR",
      "url": "https://cards.scryfall.io/large/front/c/7/c76a6163-6fd9-4cdf-9b14-07f75c2f0fa1.jpg?1720338560"
    },
    {
      "set": "MKM",
      "url": "https://cards.scryfall.io/large/front/2/4/241b3b6d-a25f-4a43-b5d6-1d1079e7e498.jpg?1705432997"
    }
  ]
}
```

**Deduplication considerations:**
- When merging duplicate tokens, combine artwork arrays
- Remove duplicate URLs (same token printed in multiple sets may have same art)
- Maintain set information for user preference

### 2. Update TokenDefinition Model
**File:** `lib/models/token_definition.dart`

**Add artwork field:**
```dart
class ArtworkVariant {
  final String set;
  final String url;

  ArtworkVariant({required this.set, required this.url});

  factory ArtworkVariant.fromJson(Map<String, dynamic> json) {
    return ArtworkVariant(
      set: json['set'] as String,
      url: json['url'] as String,
    );
  }
}

class TokenDefinition {
  final String name;
  final String abilities;
  final String pt;
  final String colors;
  final String type;
  final List<ArtworkVariant> artwork;  // ← Add this

  // Update fromJson to parse artwork array
}
```

**Note:** TokenDefinition is NOT persisted to Hive - it's only loaded from JSON

### 3. Add Artwork Fields to Item Model
**File:** `lib/models/item.dart`

**Store both URL and set code for display flexibility:**

```dart
@HiveField(13)  // Next available after type at 12
String? artworkUrl;  // Full CDN URL for image loading, null = no artwork

@HiveField(14)  // Store set code separately for UI display
String? artworkSet;  // Set code (e.g., "M15", "KLD"), null = no artwork
```

**Rationale for storing both:**
- **artworkUrl**: Used for actual image loading (caching, display)
- **artworkSet**: Used for UI display ("Artwork: M15" in detail view)
- Both nullable - `null` means "Artwork: None" (default state)
- When user selects artwork, both fields are populated simultaneously
- Small storage overhead (~10 bytes for set code) but significant UX benefit

**Why not just store URL:**
- Would need to parse set code from URL or look up in TokenDefinition
- URL parsing is fragile (URLs could change format)
- TokenDefinition lookup requires matching token definition (what if custom token?)
- Storing set code explicitly is cleaner and more reliable

**Why not just store set code:**
- Would need to look up URL every time we display image
- Requires keeping TokenDefinition in memory or re-loading JSON
- Breaks if user has custom token or token database changes
- Direct URL access is faster and more reliable

**Migration strategy:**
- Add both fields with default `null`
- Existing tokens will have no artwork (expected behavior)
- Users can add artwork on-demand via ExpandedTokenScreen

### 4. Add Artwork Fields to TokenTemplate Model
**File:** `lib/models/token_template.dart`

**Add both artwork fields to deck save/load:**
```dart
@HiveField(6)  // Next available after type at 5
String? artworkUrl;  // Preserve user's artwork choice in saved decks

@HiveField(7)  // Store set code as well
String? artworkSet;  // Set code for UI display
```

**Update fromItem() and toItem():**
```dart
factory TokenTemplate.fromItem(Item item) {
  return TokenTemplate(
    // ... existing fields
    artworkUrl: item.artworkUrl,
    artworkSet: item.artworkSet,
  );
}

Item toItem({int amount = 1, bool createTapped = false}) {
  return Item(
    // ... existing fields
    artworkUrl: artworkUrl,
    artworkSet: artworkSet,
  );
}
```

**Why preserve both fields:**
- Saved decks should restore exact user choices including artwork
- When loading a deck, tokens should appear with same artwork as when saved
- Both URL and set code needed for complete restoration

### 5. Create Artwork Management System

**New file:** `lib/utils/artwork_manager.dart`

**Responsibilities:**
- Download artwork from Scryfall CDN
- Cache images locally in app data directory
- Provide cached image paths for display
- Handle download failures gracefully
- Track which tokens have artwork downloaded

**Key methods:**
```dart
class ArtworkManager {
  // Get local path for cached artwork (null if not downloaded)
  static Future<String?> getCachedArtworkPath(String url);

  // Download artwork and cache locally
  static Future<bool> downloadArtwork(String url, {Function(double)? onProgress});

  // Check if artwork is already cached
  static Future<bool> isArtworkCached(String url);

  // Delete cached artwork (for user cleanup)
  static Future<void> deleteCachedArtwork(String url);

  // Get cache directory path
  static Future<String> getArtworkCacheDirectory();

  // Get total cache size (for user info)
  static Future<int> getTotalCacheSize();

  // Clear all cached artwork
  static Future<void> clearAllArtwork();
}
```

**Implementation notes:**
- Use `path_provider` package for app data directory
- Generate filename from URL hash (deterministic, handles URL changes)
- Store as `.jpg` files in dedicated artwork cache subdirectory
- Consider rate limiting downloads (respect Scryfall's infrastructure)
- Add User-Agent header to requests (good etiquette): "DoublingSeason/1.0"

### 6. Add Artwork Display to ExpandedTokenScreen
**File:** `lib/screens/expanded_token_screen.dart`

**UI Layout - Redesigned layout with artwork selection:**

The Token Details view should be restructured to accommodate artwork selection in a compact, two-row layout:

```
┌─────────────────────────────────────────┐
│ [Full card artwork image if selected]  │  ← Optional: Only shown when artwork selected
│                                         │
├─────────────────────────────────────────┤
│ Name: Goblin               │ 1/1       │  ← Row 1: Name field | Stats (P/T)
├─────────────────────────────────────────┤
│ Type: Creature — Goblin    │ [Art Box] │  ← Row 2: Type field | Art selection
├─────────────────────────────────────────┤
│ Colors: [R]                             │
│ Abilities: Haste                        │
│ ...rest of existing UI...               │
└─────────────────────────────────────────┘
```

**Layout Requirements:**

**Row 1: [Name][Stats]**
- Name field occupies left portion (~70-75% width)
- Stats (P/T) occupies right portion (~25-30% width)
- Same height for both fields
- Existing layout - no changes needed

**Row 2: [Type][Art]**
- Type field occupies left portion (~70-75% width) - **SHRINK from current full width**
- Art selection box occupies right portion (~25-30% width) - **SAME width as Stats above it**
- Same height for both fields
- Type field may need to be condensed/truncated if long (e.g., "Creature — Elf Warrior")

**Art Selection Box Specifications:**
- **Width**: Matches Stats box width exactly (aligned vertically)
- **Height**: Matches Type field height
- **Default state (no artwork)**: Displays text "select" (centered, same styling as other fields)
- **After selection**: Displays thumbnail image of selected artwork (fills box)
- **Behavior**: Entire box is tappable to open artwork selection sheet
- **Visual indicator**: Consider subtle border or tap affordance (optional)
- **Alignment**: Top-aligned with Type field on same row

**Artwork Display in Detail View:**
- **When artwork selected**: Show full card image at top of screen (above token details grid)
  - Full, unmodified card image (no cropping, no fade)
  - Full color, no opacity overlay
  - Use `Image.file()` to load from cache
  - Aspect ratio: Preserve original (standard Magic card ratio ~63:88)
  - Image tappable for full-screen preview (optional)
- **When no artwork**: Don't show image area, start directly with Name/Stats row

**Artwork Field Behavior:**
- **Default state**: Displays word "select" in art box (no artwork selected by default)
- **After selection**: Displays thumbnail of selected artwork in art box
- **Tappable**: User taps anywhere on art box to open selection sheet
- **Positioning**: Top-right of detail fields, same row as Type field

**Artwork Selection Sheet (Bottom Sheet):**

**Sheet Title:** "Select Token Artwork"

**Data Requirements:**
- Artwork options come from `<set picurl=""></set>` tags in source XML (Cockatrice tokens.xml)
- Each token's metadata must include array of artwork variants with **both**:
  - **URL**: Full Scryfall CDN image URL (for downloading/displaying)
  - **Set code**: 3-4 character set code from `<set>` tag content (e.g., "M15", "KLD")
- This data is stored in `token_database.json` (see section 1 for processing script requirements)
- TokenDefinition model must parse and expose this artwork array (see section 2)

**Case 1: Artwork available (most tokens)**
```
┌─────────────────────────────────────┐
│ Select Token Artwork           [×]  │
├─────────────────────────────────────┤
│ ┌─────────────┐                     │
│ │ [Thumbnail] │ M15                 │  ← Tappable row
│ │   or Loader │ Core Set 2015       │     (thumbnail fetched from URL)
│ └─────────────┘                     │
│                                     │
│ ┌─────────────┐                     │
│ │ [Thumbnail] │ KLD                 │  ← Tappable row
│ │   or Loader │ Kaladesh            │     (thumbnail fetched from URL)
│ └─────────────┘                     │
│                                     │
│ ┌─────────────┐                     │
│ │ [Thumbnail] │ DOM                 │  ← Tappable row
│ │   or Loader │ Dominaria           │     (thumbnail fetched from URL)
│ └─────────────┘                     │
│                                     │
│ ... (scrollable if many options)    │
└─────────────────────────────────────┘
```

**Each artwork option displays:**
- **Thumbnail image**: Small preview loaded from Scryfall URL
  - Shows loading indicator while fetching thumbnail
  - Thumbnail may be generated on-the-fly or cached
- **Set code**: 3-4 character code (e.g., "M15", "KLD") - **prominent, from stored metadata**
- **Set name**: Full set name (e.g., "Core Set 2015") - secondary text below set code
  - May require set code → name lookup table or hardcoded mapping
- Each option is a **tappable row** that selects that artwork variant

**Sheet behavior:**
- Scrollable list if more than ~4-5 artwork variants
- Each row is tappable (selects that artwork)
- Close button [×] in top-right to dismiss without selection
- Thumbnails load asynchronously (show spinner/placeholder while loading)

**Case 2: No artwork available (some tokens)**
```
┌─────────────────────────────────────┐
│ Select Token Artwork           [×]  │
├─────────────────────────────────────┤
│                                     │
│         No token art available      │
│                                     │
│   This token doesn't have official │
│   artwork in the database.          │
│                                     │
└─────────────────────────────────────┘
```

**Confirmation Preview Dialog:**

When user taps an artwork option, show larger preview before confirming:

```
┌─────────────────────────────────────┐
│                                     │
│   [Large Card Image Preview]        │
│                                     │
│   Goblin - M15                      │
│   Core Set 2015                     │
│                                     │
│   ┌────────┐    ┌──────────┐       │
│   │ Cancel │    │ Confirm  │       │
│   └────────┘    └──────────┘       │
└─────────────────────────────────────┘
```

**Confirmation dialog details:**
- Shows full-size card image (not just thumbnail)
- Displays set code and set name for clarity
- Two buttons: Cancel (dismiss, return to selection sheet) / Confirm (download and save)
- If image already cached: instant confirmation, no download progress
- If image not cached: Show download progress after Confirm

**Complete User Flow:**

1. **User opens ExpandedTokenScreen** (detail view for a token)
   - Sees art selection box on Row 2 (next to Type field)
   - Box displays text "select" (no artwork yet)
   - No full card image at top (artwork not selected)

2. **User taps on art selection box**
   - Bottom sheet opens showing available art variants
   - Sheet displays:
     - List of artwork options with thumbnails (or loading indicators while fetching)
     - Set codes (e.g., "M15", "KLD") prominently displayed
     - Set names below codes (e.g., "Core Set 2015", "Kaladesh")
   - OR "No token art available" message if token has no artwork

3. **User taps an artwork option**
   - Confirmation dialog appears with large preview
   - Shows full card image preview
   - Displays set code and set name for clarity

4. **User taps "Confirm"**
   - If not cached: Download progress dialog appears
   - Image downloads and caches locally
   - Dialog dismisses on completion (or shows error if download fails)

5. **Bottom sheet closes, returns to ExpandedTokenScreen**
   - **Art box now displays thumbnail image** (replaces "select" text)
   - **Full card image appears at top of screen** (above detail fields)
   - Both URL and set code persisted to `item.artworkUrl` and `item.artworkSet`
   - Changes saved to Hive database

6. **User navigates back to ContentScreen (list view)**
   - TokenCard may display with artwork background (if Method 1 or 2 from TokenCard section is implemented)
   - Artwork persists across app restarts and deck save/load

**Changing/Removing Artwork:**

- **Change artwork**: Tap art box again (which now shows thumbnail) → Opens selection sheet → Select different artwork variant
- **Remove artwork**: Long-press on art box or full artwork image in detail view → Confirmation dialog → Sets back to "select" text
- **Alternative removal**: Add "Remove Artwork" option at top of selection sheet when artwork already selected

**Error Handling:**

- **Download fails**: Show error dialog, art box remains showing "select", allow retry
- **Image fails to load from cache**: Fallback to no artwork display (show "select" again), log error
- **No network connection**: Show alert when user tries to download, explain network required
- **Thumbnail fails to load in bottom sheet**: Show placeholder icon or "No preview" text in thumbnail area

### 7. Add Artwork Display to TokenCard
**File:** `lib/widgets/token_card.dart`

**Reference mockup:** `docs/activeDevelopment/crudemockup.png`

## TokenCard Artwork Display Methods

There are two proposed methods for displaying artwork on TokenCard. This section details both approaches.

---

## Method 1: Fadeout Method (RIGHT-SIDE PLACEMENT)

### Overview
Artwork is displayed on the right-hand side of the TokenCard with a gradient that fades the art into the card's background color. The source card image is cropped to focus on the central artwork, excluding card borders and text areas.

### Artwork Cropping Specifications

**Source Image:** Full Scryfall card image from CDN (`/large/front/...`)

**Crop Percentages (applied to source image before display):**
- **Left edge**: Crop in 8.8% from left
- **Right edge**: Crop in 8.8% from right
- **Top edge**: Crop in 14.5% from top
- **Bottom edge**: Crop in 36.8% from bottom

**Rationale for crop values:**
- Removes card border and frame elements
- Removes text box at bottom (which contains 36.8% of card height)
- Removes name/mana cost area at top
- Centers on the actual artwork portion of the card
- Values should work for most token card layouts safely

**Crop result:**
- Focuses on the central character/subject artwork
- Removes all card text, borders, and frame decoration
- Preserves aspect ratio of cropped region (not the original card ratio)

**Implementation approach:**
```dart
// Pseudo-code for cropping logic
final imageWidth = sourceImage.width;
final imageHeight = sourceImage.height;

final cropLeft = imageWidth * 0.088;
final cropRight = imageWidth * 0.088;
final cropTop = imageHeight * 0.145;
final cropBottom = imageHeight * 0.368;

final croppedImage = cropImage(
  sourceImage,
  left: cropLeft,
  top: cropTop,
  width: imageWidth - cropLeft - cropRight,
  height: imageHeight - cropTop - cropBottom,
);
```

### Card Layout Specifications

**Artwork Placement:**
- **Position:** Right-hand side of TokenCard
- **Alignment:** Flush with right edge of card (respects card's rounded corner radius)
- **Height:** Fills entire card height from top to bottom
- **Width:** **30% of card width** (occupies rightmost 30% of card)

**Gradient Fade Specifications:**
- **Direction:** Left-to-right (fades FROM background color INTO artwork)
- **Fade region:** Extends **25% into the artwork** (measured from left edge of artwork region)
- **Fade start point:** Left edge of artwork region (at 70% of card width from left)
- **Fade end point:** 25% into artwork region (at 77.5% of card width from left)
  - Calculation: 70% + (30% × 0.25) = 77.5%
- **Fade behavior:**
  - At 70% card width: Artwork opacity = 0% (pure background color)
  - At 77.5% card width: Artwork opacity = 100% (full artwork visibility)
  - At 77.5%-100% card width: Full artwork at 100% opacity (no fade)
- **Fade curve:** [TODO: Linear? Ease-out? Ease-in-out? Specify preferred curve]
- **Background color source:** Current TokenCard background color (light/dark mode adaptive)
- **Gradient implementation:** Opacity gradient on artwork layer (not color gradient)

**Visual Integration:**
- Artwork respects card's rounded corners (clip to card shape)
- Gradient creates seamless transition from solid background into artwork
- Left 70% of card remains pure solid background (no artwork influence)
- Color identity border maintained around entire card (not obscured by artwork)

**Fade Zone Breakdown:**
```
|← 70% solid background →|← 7.5% fade zone →|← 22.5% full artwork →|
|                        |                  |                      |
| [Token Info Area]      | [Gradient Fade]  | [Full Art Visible]   |
| 0%----------------70%  | 70%-------77.5%  | 77.5%---------100%   |
```

### Text and UI Element Placement

**Critical requirement:** All text and interactive elements must remain readable and accessible.

**Text Contrast Solution: Background Boxes/Pills**

All key text elements must have background boxes that match the card's background color. This ensures readability regardless of whether text overlaps the artwork/fade zone.

**Elements requiring background boxes:**
1. **Name/Title** - Background box matching card background
2. **Type line** - Background box matching card background
3. **Abilities text** - Background box matching card background
4. **Power/Toughness (P/T)** - Background box matching card background
5. **Status counts** (tapped count, summoning sickness count, counter counts) - Background boxes matching card background

**Background box specifications:**
- **Color:** Matches TokenCard background color (light/dark mode adaptive)
- **Opacity:** Solid/opaque (not semi-transparent) to ensure full text readability
- **Padding:** Minimal padding to avoid increasing card height
  - Horizontal padding: Small (~4-6px) for text breathing room
  - Vertical padding: Minimal or none (~0-2px) to prevent card bloat
  - Only add padding necessary for visual separation from artwork
- **Border radius:** Rounded corners matching app's design language (~4-6px)
- **Style:** Tight-fitting rectangular or pill-shaped boxes (subtle, not overly prominent)
- **Behavior:** Boxes overlay the artwork/fade zone where needed
- **Height constraint:** Boxes should not increase overall card height compared to cards without artwork

**Layout zones:**
- **Left 70% (solid background):** Text elements can appear directly on background OR use background boxes (boxes blend in seamlessly since they match background)
- **Middle 7.5% (fade zone):** Text elements MUST use background boxes to remain readable over gradient
- **Right 22.5% (full artwork):** Text elements MUST use background boxes to remain readable over full-opacity artwork

**Button row placement:**
- Action buttons (- + tap, etc.) can appear anywhere on card
- Buttons should use existing button styling (which already provides contrast)
- Buttons must remain fully interactive (artwork must not block touch events)
- Button backgrounds already provide contrast, no additional background boxes needed

**Text positioning strategy:**
- Text elements can be positioned flexibly across the card
- Background boxes ensure readability regardless of artwork content or placement
- Boxes create consistent visual treatment across all tokens (with or without artwork)

### Artwork Opacity and Effects

**Base opacity:**
- Artwork displayed at **100% opacity** in the full artwork zone (77.5%-100% of card width)
- Artwork fades from 0% to 100% opacity in the fade zone (70%-77.5% of card width)
- No additional semi-transparent overlay applied to artwork
- Artwork displays at natural full color and brightness

**Color treatment:**
- **Full color:** Display artwork at full saturation and color fidelity
- **No desaturation:** Artwork preserves original colors from Scryfall image
- **No tinting:** No color overlay or blending with card background
- **Natural appearance:** Artwork appears as intended by original artist

**Additional effects:**
- **No blur:** Artwork displays sharp and clear
- **No darkening/lightening:** Artwork brightness unchanged from source
- **Contrast ensured by:** Background boxes on text elements (not artwork modification)

**Effect summary:**
The fadeout method relies on **opacity-based gradient** and **text background boxes** for readability, rather than modifying the artwork itself. This preserves the artistic integrity of the token art while ensuring UI elements remain readable.

### Responsive Behavior

**Card width variations:**
- **Proportional scaling:** Artwork width scales as fixed 30% of card width
- **Fade zone scales:** Fade region always extends 25% into artwork (7.5% of total card width)
- **Minimum width handling:** [TODO: Specify minimum card width before artwork is hidden/adjusted, or confirm artwork always displays at 30%]
- **Consistent percentages:** Layout maintains 70% info / 7.5% fade / 22.5% art ratio across all card widths

**Card height variations:**
- Artwork scales to fill entire card height (top to bottom)
- Cropped artwork region maintains its aspect ratio
- Artwork uses `BoxFit.cover` behavior (may crop further horizontally or vertically to fill space)
- Vertical centering of cropped artwork within card height

### Fallback Behavior

- **No artwork selected:** Display current TokenCard design (no visual changes)
- **Artwork fails to load:** Display current TokenCard design (graceful degradation)
- **Artwork download in progress:** Display current TokenCard design (show artwork when loaded)
- **No placeholder:** Never show broken image icon or empty image box

### Implementation Notes

**Widget structure (refined):**
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final cardWidth = constraints.maxWidth;
    final artworkWidth = cardWidth * 0.30;  // 30% of card width

    return Stack(
      children: [
        // Base card background (solid color)
        Container(
          decoration: BoxDecoration(
            color: cardBackgroundColor,  // Light/dark mode adaptive
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        // Artwork layer (right side, 30% of card)
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: artworkWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,  // Fade start (0% opacity)
                    Colors.white,        // Fade end (100% opacity)
                  ],
                  stops: [0.0, 0.25],  // Fade over first 25% of artwork width
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Image.file(
                croppedArtworkFile,
                fit: BoxFit.cover,
                width: artworkWidth,
                height: double.infinity,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),

        // Text elements with background boxes (on top of artwork/fade)
        Positioned(
          left: 8,
          top: 8,
          child: _buildTextWithBackground(
            text: tokenName,
            backgroundColor: cardBackgroundColor,
          ),
        ),

        Positioned(
          left: 8,
          top: 40,
          child: _buildTextWithBackground(
            text: tokenType,
            backgroundColor: cardBackgroundColor,
          ),
        ),

        // ... other text elements with background boxes

        // Action buttons (already have contrast, no special treatment needed)
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Row(
            children: [
              // - + tap buttons etc.
            ],
          ),
        ),

        // Color identity border (outermost layer)
        Container(
          decoration: BoxDecoration(
            border: Border.all(/* gradient border */),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  },
)

// Helper method for text with background box (minimal padding)
Widget _buildTextWithBackground({
  required String text,
  required Color backgroundColor,
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),  // Minimal padding
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text),
  );
}
```

**Image cropping approach:**
- **Recommended: Option B - Crop on-the-fly during display**
  - Use `FractionalTranslation` or custom `FittedBox` with `Alignment`
  - Apply crop percentages as offset and scale transforms
  - Lighter storage (only store original image)
  - More flexible (can adjust crop values without re-downloading)
- **Alternative: Option A - Pre-crop when caching**
  - Save cropped version alongside original
  - Faster display performance (no runtime crop calculation)
  - Higher storage cost (two images per token)
- **Not recommended: Option C - CustomPainter**
  - Unnecessary complexity for simple crop operation
  - Use only if Option A/B prove insufficient

**Crop implementation example (on-the-fly):**
```dart
// Apply crop by translating and scaling the image
Transform(
  transform: Matrix4.identity()
    ..scale(1.0 / (1 - 0.088 - 0.088), 1.0 / (1 - 0.145 - 0.368))
    ..translate(-cropLeft, -cropTop),
  child: Image.file(sourceImage),
)
```

### Open Questions / TODO

Remaining items to specify before implementation:

- [ ] **Fade curve:** Linear, ease-out, ease-in-out, or custom curve? (Currently defaults to linear in gradient)
- [ ] **Minimum card width:** At what screen/card width should artwork be hidden or adjusted? (Or always show at 30%?)
- [ ] **Cropping approach:** Confirm preference for on-the-fly cropping (Option B) vs. pre-cropping (Option A)

### Resolved Specifications

The following have been defined:

- ✅ **Artwork width:** 30% of card width
- ✅ **Fade distance:** 25% into artwork (7.5% of total card width)
- ✅ **Artwork base opacity:** 100% in full art zone, 0-100% gradient in fade zone
- ✅ **Opacity overlay:** None - full color natural artwork
- ✅ **Text contrast method:** Background boxes/pills matching card background
- ✅ **Safe zones:** All text uses background boxes for universal readability
- ✅ **Button placement:** Can appear anywhere (existing button styling provides contrast)
- ✅ **Color treatment:** Full color, no desaturation or tinting
- ✅ **Artwork placement:** Right side of card
- ✅ **Crop percentages:** 8.8% left/right, 14.5% top, 36.8% bottom

---

## Method 2: Full Card Method

### Overview
Artwork fills the entire width of the TokenCard with a semi-transparent overlay of the card's background color to ensure text readability. This creates a "faded" artwork background that gives each token a unique visual identity while maintaining UI element legibility.

### Artwork Cropping Specifications

**Source Image:** Full Scryfall card image from CDN (`/large/front/...`)

**Crop Percentages (applied to source image before display):**
- **Left edge**: Crop in 8.8% from left
- **Right edge**: Crop in 8.8% from right
- **Top edge**: Crop in 14.5% from top
- **Bottom edge**: Crop in 36.8% from bottom

**Note on bottom crop:**
- 36.8% bottom crop maintained for consistency with fadeout method
- Less critical since token cards rarely reach heights where bottom crop matters
- Edge case: Very tall cards may show more vertical artwork, but width-based cropping takes priority

**Crop result:**
- Focuses on the central character/subject artwork
- Removes all card text, borders, and frame decoration
- Preserves aspect ratio of cropped region

### Card Layout Specifications

**Artwork Placement:**
- **Position:** Full-width background layer
- **Alignment:** Top-aligned (justified to top of card)
- **Width:** 100% of card width (fills entire horizontal space)
- **Height:** As much vertical space as card allows, no overflow
  - **Critical:** Card height does NOT expand to accommodate artwork
  - Artwork constrained to existing card height

**Alpha Overlay Specifications:**
- **Overlay color:** Card background color (light/dark mode adaptive)
  - Same color as TokenCard would normally use without artwork
  - Inherits from theme (light mode = light overlay, dark mode = dark overlay)
- **Opacity:** **0.5 alpha (50% transparent)** - Starting value
- **Adjustable range:** 0.4 to 0.6 (40%-60% transparency)
  - Adjust if contrast issues arise during testing
  - Lower values (0.4) = more visible artwork, less contrast
  - Higher values (0.6) = less visible artwork, more contrast
- **Purpose:** "Fades" artwork to ensure text/UI elements remain readable
- **Layer order:** Overlay sits between artwork and text elements

**Visual Integration:**
- Artwork respects card's rounded corners (clip to card shape)
- Overlay creates consistent "washed out" effect across all artwork
- Color identity border maintained around entire card (not obscured by artwork)

**Artwork Fit Behavior:**
- **BoxFit:** `BoxFit.cover` - Fill card width, crop vertically if needed
- **Justification:** Top-aligned (artwork anchored to top of card)
- **Priority:** Width > Height (always fill width, allow vertical cropping)
- **No overflow:** Artwork never extends beyond card boundaries

### Text and UI Element Placement

**Text Contrast Strategy: TBD During Implementation**

Two potential approaches (to be determined based on visual testing):

**Option A: Direct text on overlay (no background boxes)**
- Text elements render directly on top of alpha overlay
- Overlay provides sufficient contrast for readability
- Cleaner visual appearance
- Used if 0.5 alpha overlay provides adequate contrast

**Option B: Text with background boxes (same as fadeout method)**
- Add minimal background boxes to key text elements if contrast insufficient
- Boxes match card background color (solid/opaque)
- Minimal padding: ~6px horizontal, ~1-2px vertical
- Used if alpha overlay alone doesn't provide enough text readability

**Option C: Hybrid approach**
- Increase alpha overlay opacity (toward 0.6) for better contrast
- No background boxes needed if higher opacity solves contrast issue
- Trade-off: Less visible artwork, but cleaner UI

**Decision criteria:**
- Test readability with black text on various artwork colors
- Ensure P/T numbers, abilities text, and counts are always legible
- Prioritize clean appearance while maintaining accessibility

**UI Elements:**
- All existing TokenCard elements remain in same positions
- Name, type, abilities, P/T, status counts, action buttons
- Color identity border maintained as outermost layer

### Artwork Opacity and Effects

**Base artwork:**
- Artwork displayed at **100% opacity** beneath overlay
- Full color, no desaturation or tinting of artwork itself
- Sharp and clear (no blur)

**Overlay effect:**
- Semi-transparent background color overlay creates "faded" appearance
- Overlay is what reduces artwork visibility, not the artwork itself
- Adjustable overlay opacity allows fine-tuning of artwork prominence

**Effect summary:**
The full card method uses a **semi-transparent color overlay** to fade the artwork while keeping text readable. Text may or may not need background boxes depending on contrast testing results.

### Responsive Behavior

**Card width variations:**
- **Full width:** Artwork always fills 100% of card width
- Artwork scales proportionally with card width
- Cropped region maintains aspect ratio

**Card height variations:**
- Artwork scales to fill card width (primary constraint)
- Vertical dimension determined by aspect ratio of cropped artwork
- If artwork is taller than card: Crop vertically (top-aligned, trim bottom)
- If artwork is shorter than card: [EDGE CASE - unlikely with typical token card heights]
- **No card height expansion:** Card maintains existing height regardless of artwork

### Fallback Behavior

- **No artwork selected:** Display current TokenCard design (no visual changes)
- **Artwork fails to load:** Display current TokenCard design (graceful degradation)
- **Artwork download in progress:** Display current TokenCard design (show artwork when loaded)
- **No placeholder:** Never show broken image icon or empty image box

### Implementation Notes

**Widget structure (proposed):**
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final cardWidth = constraints.maxWidth;
    final cardHeight = constraints.maxHeight;

    return Stack(
      children: [
        // Artwork layer (full width background, top-aligned)
        Positioned(
          left: 0,
          top: 0,
          width: cardWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              croppedArtworkFile,
              fit: BoxFit.cover,
              width: cardWidth,
              height: cardHeight,
              alignment: Alignment.topCenter,  // Top-aligned, crop bottom if needed
            ),
          ),
        ),

        // Alpha overlay (background color at 50% opacity)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: cardBackgroundColor.withOpacity(0.5),  // Adjustable: 0.4-0.6
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Text elements (directly on overlay OR with background boxes - TBD)
        // Option A: Direct text
        Positioned(
          left: 8,
          top: 8,
          child: Text(
            tokenName,
            style: TextStyle(/* existing styling */),
          ),
        ),

        // Option B: Text with background boxes (if needed for contrast)
        Positioned(
          left: 8,
          top: 8,
          child: _buildTextWithBackground(
            text: tokenName,
            backgroundColor: cardBackgroundColor,
          ),
        ),

        // ... other text elements

        // Action buttons
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Row(
            children: [
              // - + tap buttons etc.
            ],
          ),
        ),

        // Color identity border (outermost layer)
        Container(
          decoration: BoxDecoration(
            border: Border.all(/* gradient border */),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  },
)
```

**Image cropping approach:**
- Same as fadeout method: On-the-fly cropping recommended (Option B)
- Apply crop percentages via transform or alignment during display
- Store only original images for flexibility

**Alpha overlay tuning:**
```dart
// Adjustable constant for easy testing
const double _artworkOverlayOpacity = 0.5;  // Range: 0.4 - 0.6

Container(
  color: cardBackgroundColor.withOpacity(_artworkOverlayOpacity),
)
```

### Open Questions / TODO

Items to resolve during implementation:

- [ ] **Text contrast solution:** Option A (direct text), Option B (background boxes), or Option C (higher opacity)?
- [ ] **Final overlay opacity:** Stick with 0.5 or adjust based on visual testing?
- [ ] **Edge case handling:** If artwork is shorter than card height (unlikely), fill with background color or stretch artwork?

### Resolved Specifications

- ✅ **Artwork width:** 100% of card width
- ✅ **Artwork placement:** Full-width background, top-aligned
- ✅ **Alpha overlay color:** Card background color (theme-adaptive)
- ✅ **Starting opacity:** 0.5 alpha overlay (adjustable 0.4-0.6)
- ✅ **Crop percentages:** 8.8% left/right, 14.5% top, 36.8% bottom
- ✅ **BoxFit behavior:** BoxFit.cover (fill width, crop vertically)
- ✅ **Card height:** No expansion - artwork fits within existing card height
- ✅ **Color treatment:** Full color artwork with color overlay fade effect

---

## Original Mockup-Based Design (DEPRECATED - REFERENCE ONLY)

**UI Layout: Left-aligned artwork with gradient fade**

```
┌──────────────────────────────────────────────────────┐
│ [ARTWORK]│                                            │
│ [ARTWORK]│ Elf Warrior           ⊙1 🗡1 ⬡0          │
│ [ARTWORK]│ Creature — Elf Warrior                    │
│ [fade→→]│                                      1/1    │
│          │ [- + 🗡 ⬡ ⊙ ⊡ ↗]                          │
└──────────────────────────────────────────────────────┘
```

**Design Requirements Based on Mockup:**

1. **Artwork Placement:**
   - Left-aligned, flush with card border (respects card's rounded corner radius)
   - Fills entire height of card from top to bottom
   - Width: Approximately 40-50% of card width (based on mockup proportions)
   - Artwork source: Cropped/zoomed portion of full card art showing character/subject
   - Art should extend behind the name text area

2. **Gradient Fade:**
   - Starts at artwork right edge, extends into solid background
   - Fade distance: Approximately 30-40% of card width (smooth transition zone)
   - Background color after fade: Current TokenCard background (light gray in mockup)
   - **Opacity overlay on artwork:** Semi-transparent white/gray overlay (~20-30% opacity)
     - Makes artwork more subtle, prevents overpowering text
     - Creates "washed out" or "desaturated" effect visible in mockup
     - Ensures artwork doesn't compete with token information

3. **Text Contrast Handling (Based on Mockup):**
   - **Name text ("Elf Warrior")**: White text with subtle dark stroke/shadow
     - Appears over artwork area with good readability
     - Stroke provides definition against varying artwork colors
   - **Type text ("Creature — Elf Warrior")**: Appears to have semi-transparent background pill/highlight
     - Light background behind text for contrast
     - Italic styling (as currently implemented)
   - **P/T ("1/1")**: Large, bold, positioned in gradient fade area (safe zone)
   - **Status icons (⊙ 🗡 ⬡)**: Positioned in top-right, in solid background area
   - **Action buttons**: Positioned at bottom, fully in solid background area (no artwork)

4. **Layout Observations from Mockup:**
   - Green color identity border maintained (visible around entire card)
   - Card retains rounded corners
   - Artwork respects card shape (rounded corner on top-left)
   - Button row at bottom is completely clear of artwork (solid background)
   - P/T is very large and positioned in lower-right quadrant
   - Name and type are in upper-left, overlaying artwork

5. **Technical Implementation Notes:**
   - Use `Stack` widget with artwork as bottom layer
   - `ClipRRect` to respect card's rounded corners
   - Apply opacity overlay to artwork using `ColorFiltered` or `Container` with semi-transparent color
   - Gradient fade using `ShaderMask` or positioned `Container` with `LinearGradient`
   - Text stroke using `Stack` with multiple `Text` widgets (shadow copies) or custom `TextPainter`
   - Ensure artwork doesn't block touch interactions with buttons

6. **Fallback Behavior:**
   - If no artwork: display as current TokenCard (no visual changes)
   - If artwork fails to load: display as current TokenCard (graceful degradation)
   - Don't show placeholder/broken image - just render without art

**Specific Design Values (From Mockup Analysis):**
- **Artwork width:** ~40-45% of card width
- **Gradient fade zone:** ~30-35% of card width
- **Artwork opacity overlay:** ~20-30% white/light gray
- **Text contrast method:**
  - Name: Dark stroke/shadow on white text
  - Type: Semi-transparent background pill
- **Gradient curve:** Appears to be ease-out (quick fade near artwork, gradual finish)

**Open Design Questions (TODO: User to Refine):**
- [ ] Exact artwork width percentage (40%? 45%? 50%?)
- [ ] Exact opacity overlay value (20%? 25%? 30%?)
- [ ] Gradient fade curve parameters (ease-out confirmed, but specific values?)
- [ ] Type text background: pill shape or simple rectangular highlight?
- [ ] Should artwork appear in condensed view mode? (if/when implemented)
- [ ] Artwork cropping strategy: center crop? smart crop? user-selectable crop?

### 8. Update NewTokenSheet
**File:** `lib/widgets/new_token_sheet.dart`

**Decision:** Should custom tokens support artwork?

**Option A: No artwork support** (simpler)
- Custom tokens are user-created, no official artwork exists
- User can add artwork later via ExpandedTokenScreen if desired

**Option B: Allow user upload** (more complex)
- Add image picker for custom artwork
- Store in same cache system
- Requires `image_picker` package
- Higher complexity, lower priority

**Recommendation:** Option A for initial implementation

### 9. Update About Screen Credits
**File:** `lib/screens/about_screen.dart`

**Update Credits card to include artwork attribution:**
```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Credits',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Token database sourced from the Cockatrice project.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Card images © Wizards of the Coast LLC, a subsidiary of Hasbro, Inc. '
          'Images provided by Scryfall. Scryfall is not produced by or endorsed '
          'by Wizards of the Coast.\n\n'
          'Doubling Season is unofficial Fan Content permitted under the Fan '
          'Content Policy. Not approved/endorsed by Wizards. Portions of the '
          'materials used are property of Wizards of the Coast. © Wizards of '
          'the Coast LLC.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    ),
  ),
)
```

### 10. Add Settings/Management UI (Optional)

**Potential settings in SettingsProvider:**
- Enable/disable artwork display globally
- Default artwork preference (first set, newest set, user choice)
- Cache management (view size, clear cache)

**Settings screen additions:**
- "Artwork Settings" section
- "Clear Artwork Cache" button with confirmation
- Display total cache size

## Implementation Order

1. **Update token database script** - Extract artwork URLs from XML
2. **Regenerate token database** - Run script to update `assets/token_database.json`
3. **Update TokenDefinition model** - Add artwork field and parsing
4. **Add artworkUrl to Item model** - HiveField 13
5. **Add artworkUrl to TokenTemplate model** - HiveField 6
6. **Run build_runner** - Regenerate Hive adapters
7. **Create ArtworkManager utility** - Download and caching logic
8. **Update ExpandedTokenScreen** - Add artwork display and management
9. **Update About screen** - Add attribution notice
10. **Test artwork download** - Verify caching and display
11. **Test deck save/load** - Verify artwork URLs preserved
12. **Test offline mode** - Verify cached images display without network
13. **(Optional) Add TokenCard preview** - If desired
14. **(Optional) Add settings UI** - Cache management

## User Experience Flow

### First-time artwork addition:
1. User creates/selects a Goblin token (no artwork yet)
2. User taps token to open ExpandedTokenScreen
3. User sees "Add Artwork" button below where image would display
4. User taps "Add Artwork"
5. Bottom sheet shows available art variants (e.g., "M15", "KLD", "DOM")
6. User selects preferred variant
7. Progress dialog shows download status
8. Artwork displays in ExpandedTokenScreen
9. Artwork cached for future use

### Subsequent uses:
1. User creates another Goblin token (same definition)
2. Option to use previously selected artwork automatically OR
3. Prompt user to select artwork (user preference)
4. If artwork already cached, instant display (no download)

### Changing artwork:
1. User opens token with existing artwork
2. User taps "Change Artwork" button
3. Select different variant from bottom sheet
4. New artwork downloads and replaces old selection
5. Old cached image may be retained (other tokens might use it)

### Removing artwork:
1. Long-press on artwork image
2. Confirmation dialog: "Remove artwork?"
3. Set `item.artworkUrl = null` and save
4. Cached file remains (other tokens might use it)

## Technical Considerations

### Deduplication Strategy
**Problem:** Multiple tokens may have identical artwork (same token, different sets)

**Solution options:**
1. **Hash-based deduplication** - Store images by content hash, reference by URL
2. **URL-based storage** - Store by URL hash, multiple tokens can reference same URL
3. **Hybrid approach** - Store by URL, detect duplicate content and symlink/reference

**Recommendation:** URL-based storage (option 2)
- Simple implementation
- Scryfall URLs are stable and canonical
- Natural deduplication (same URL = same file)

### Storage Location
- **iOS**: `Library/Application Support/artwork_cache/`
- **Android**: `{app_data}/artwork_cache/`
- **Web**: Browser cache storage (requires different implementation)
- **Desktop**: OS-appropriate app data directory

### Cache Invalidation
**When to re-download:**
- Never automatically (URLs are stable, images don't change)
- Only on user request ("Refresh artwork" feature - low priority)
- Cache persists across app updates

### Network Handling
- Check network availability before download
- Provide clear error messages if download fails
- Allow retry on failure
- Consider background download queue (low priority optimization)

### Performance Considerations
- Image loading should be async (don't block UI)
- Use `Image.file()` with `cacheWidth` to reduce memory usage
- Consider thumbnail generation for list view (if implemented)
- Lazy loading - only download when user requests

## Testing Checklist

- [ ] Token database includes artwork URLs for all tokens with available art
- [ ] TokenDefinition correctly parses artwork array
- [ ] Item model stores artwork URL persistently
- [ ] TokenTemplate preserves artwork URL in deck save/load
- [ ] ArtworkManager downloads images successfully
- [ ] Downloaded images cached in correct directory
- [ ] Cached images display in ExpandedTokenScreen
- [ ] Download progress indicator works
- [ ] Download error handling displays helpful messages
- [ ] Multiple art variants display as options
- [ ] Selecting different variant updates token
- [ ] Removing artwork clears URL but preserves cache
- [ ] Offline mode displays cached images
- [ ] Offline mode handles missing images gracefully
- [ ] Attribution notice appears in About screen
- [ ] No modifications made to Scryfall images
- [ ] Network requests include User-Agent header
- [ ] Large images don't cause memory issues
- [ ] Fast image loading from cache

## Success Criteria

After implementation:
- ✅ Token database contains artwork URLs from Cockatrice XML
- ✅ Users can add artwork to any token with available art
- ✅ Users can select from multiple art variants (if available)
- ✅ Artwork downloads and caches locally for offline use
- ✅ Artwork displays correctly in ExpandedTokenScreen
- ✅ Artwork persists across app restarts
- ✅ Saved decks preserve user's artwork choices
- ✅ About screen includes proper attribution notice
- ✅ No paywall restricts artwork access
- ✅ Images displayed without modifications
- ✅ Graceful handling of download failures
- ✅ Good performance (no UI blocking during download)

## Future Enhancements (Not in Initial Implementation)

- Artwork preview thumbnails in TokenCard
- Automatic artwork selection on token creation
- Full-screen artwork viewer
- User-uploaded custom artwork
- Bulk artwork download ("Download all artwork" option)
- Artwork preferences (always use newest set, etc.)
- Cache size management and cleanup tools
- Alternative art variants from other sources (if legally permissible)

---

## Other Features Under Consideration

(No features currently under consideration)
