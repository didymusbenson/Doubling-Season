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

**UI Layout - Add artwork field to token details:**
```
┌─────────────────────────────┐
│ Name: Goblin           1/1  │
│ Type: Creature — Goblin     │
│ Colors: [R]                 │
│ Artwork: None          [→]  │  ← NEW: Tappable row
│ Abilities: Haste            │
│ ...rest of existing UI...   │
└─────────────────────────────┘
```

**Artwork Field Behavior:**
- **Default state**: Displays "Artwork: None" (no artwork selected by default)
- **After selection**: Displays "Artwork: [Set Code]" (e.g., "Artwork: M15" or "Artwork: KLD")
- **Tappable row**: User taps anywhere on the artwork row to open selection sheet
- **Visual indicator**: Chevron/arrow (→) on right side indicating it's tappable
- **Positioning**: Between Colors and Abilities in the detail screen layout

**Artwork Display in Detail View:**
- **When artwork selected**: Show full card image at top of screen (above token details)
  - Full, unmodified card image (no cropping, no fade)
  - Full color, no opacity overlay
  - Use `Image.file()` to load from cache
  - Aspect ratio: Preserve original (standard Magic card ratio ~63:88)
  - Image tappable for full-screen preview (optional)
- **When no artwork**: Don't show image area, start with Name field

**Artwork Selection Sheet (Bottom Sheet):**

**Sheet Title:** "Select Token Artwork"

**Case 1: Artwork available (most tokens)**
```
┌─────────────────────────────────────┐
│ Select Token Artwork           [×]  │
├─────────────────────────────────────┤
│ ┌─────────────┐                     │
│ │ [Thumbnail] │ M15                 │  ← Tappable row
│ │   Goblin    │ Core Set 2015       │
│ └─────────────┘                     │
│                                     │
│ ┌─────────────┐                     │
│ │ [Thumbnail] │ KLD                 │  ← Tappable row
│ │   Goblin    │ Kaladesh            │
│ └─────────────┘                     │
│                                     │
│ ┌─────────────┐                     │
│ │ [Thumbnail] │ DOM                 │  ← Tappable row
│ │   Goblin    │ Dominaria           │
│ └─────────────┘                     │
│                                     │
│ ... (scrollable if many options)    │
└─────────────────────────────────────┘
```

**Each artwork option displays:**
- Thumbnail image (small preview of card art)
- Set code (e.g., "M15", "KLD") - prominent
- Set name (e.g., "Core Set 2015") - secondary text below set code
- Token name on thumbnail for clarity

**Sheet behavior:**
- Scrollable list if more than ~4-5 artwork variants
- Each row is tappable
- Close button [×] in top-right to dismiss without selection

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
   - Sees "Artwork: None" field

2. **User taps "Artwork" row**
   - Bottom sheet opens showing available art variants
   - Sheet shows thumbnails with set codes OR "No token art available"

3. **User taps an artwork option**
   - Confirmation dialog appears with large preview
   - Shows set code and name

4. **User taps "Confirm"**
   - If not cached: Download progress dialog appears
   - Image downloads and caches
   - Dialog dismisses on completion (or error)

5. **Sheet closes, returns to ExpandedTokenScreen**
   - Artwork field now shows "Artwork: M15" (selected set code)
   - Full card image appears at top of screen
   - Image persisted to `item.artworkUrl`

6. **User navigates back to ContentScreen (list view)**
   - TokenCard now displays with artwork background (fade effect from mockup)
   - Artwork persists across app restarts

**Changing/Removing Artwork:**

- **Change artwork**: Tap "Artwork: [Set Code]" row → Opens selection sheet again
- **Remove artwork**: Long-press on artwork image in detail view → Confirmation dialog → Sets back to "None"
- **Alternative removal**: Add "Remove Artwork" option at top of selection sheet when artwork already selected

**Error Handling:**

- **Download fails**: Show error dialog, remain on "Artwork: None", allow retry
- **Image fails to load from cache**: Fallback to no artwork display, log error
- **No network connection**: Show alert when user tries to download, explain network required

### 7. Add Artwork Display to TokenCard
**File:** `lib/widgets/token_card.dart`

**Reference mockup:** `docs/activeDevelopment/crudemockup.png`

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
