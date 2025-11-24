# IMPORTANT! READ THIS FIRST!

## ✅ IMPLEMENTATION COMPLETE (Session: 2025-11-24)

**STATUS: READY FOR PRODUCTION**

All three phases have been successfully implemented, tested, and committed. The custom artwork feature is now fully functional.

### Implemented Features:

**Phase 1 - Artwork Preference Infrastructure:**
- ✅ TokenArtworkPreference Hive model (TypeId: 4)
- ✅ ArtworkPreferenceManager utility for preference operations
- ✅ Preference loading integrated into token creation flows
- ✅ Preference saving when artwork selected

**Phase 2 - Gradient Backgrounds:**
- ✅ Color-based gradients for all tokens (based on color identity)
- ✅ Gradient shows immediately on token creation
- ✅ Gradient acts as loading placeholder while artwork downloads
- ✅ Gradient disappears automatically once artwork loads
- ✅ Gradient remains as fallback if artwork fails to download

**Phase 3 - Custom Artwork Upload:**
- ✅ Custom artwork tile in artwork selection sheet (first grid position)
- ✅ Image picker integration (gallery access)
- ✅ File storage in app documents directory (`custom_artwork/`)
- ✅ Educational dialog before upload (cropping guidance)
- ✅ File validation (5MB limit, format checks)
- ✅ Custom artwork displays without cropping (0% on all sides)
- ✅ Scryfall artwork maintains standard crop (8.8%/14.5%/36.8%)
- ✅ Upload replacement (old file deleted before new upload)
- ✅ Delete functionality with immediate UI update
- ✅ Artwork preference persistence across app sessions

### Bug Fixes Applied:
1. ✅ **Delete button clears "currently selected"** - Parent widget notified via `onRemoveArtwork()` callback
2. ✅ **Upload replacement works correctly** - Old custom image deleted before uploading new one
3. ✅ **Cropping behavior verified** - Custom artwork: 0% crop, Scryfall artwork: standard crop
4. ✅ **Gradient loading state** - Shows while loading, hides when artwork available
5. ✅ **Android build compilation** - Fixed missing callback parameter in `_CustomArtworkTile`

### Final Code Changes:
- `lib/models/token_artwork_preference.dart` - NEW Hive model (generated adapter)
- `lib/utils/artwork_preference_manager.dart` - NEW preference manager utility
- `lib/utils/constants.dart` - Added HiveTypeIds.artworkPreference = 4
- `lib/database/hive_setup.dart` - Registered adapter and opened artworkPreferences box
- `lib/widgets/artwork_selection_sheet.dart` - Custom upload tile, delete/upload handlers, callbacks
- `lib/utils/artwork_manager.dart` - Updated `getCropPercentages()` for conditional cropping
- `lib/widgets/token_card.dart` - Gradient layer with conditional visibility, artwork layer integration
- `lib/widgets/cropped_artwork_widget.dart` - No changes needed (supports both URL types)

### Testing Completed:
- ✅ Token creation shows gradient immediately
- ✅ Gradient visible during artwork download
- ✅ Gradient disappears when artwork loads
- ✅ Custom artwork upload flow works
- ✅ Delete custom artwork clears UI immediately
- ✅ Upload new artwork replaces old file
- ✅ Custom artwork displays without cropping
- ✅ Scryfall artwork displays with cropping
- ✅ Preference persistence verified
- ✅ Android build successful
- ✅ iOS build successful

### Known Limitations:
- Android emulator may have intermittent network socket exceptions (emulator issue, not code)
- Custom artwork not portable across devices (file:// paths are device-specific)
- Deck templates with custom artwork gracefully fallback on other devices

### Next Steps:
- Continue user testing on physical devices
- Gather feedback on gradient appearance (can adjust opacity/style if needed)
- Consider future enhancement: iCloud sync for custom artwork files

# Custom Artwork Feature - Implementation Specification

## Problem Statements

### Problem 1: Artless Tokens Feel Empty
Tokens without artwork (primarily custom tokens) have no ability to set art because they lack CDN URLs from Scryfall. This creates a "hollow" visual experience with plain card backgrounds.

### Problem 2: Players Want Custom Artwork
Players may have their own artwork (commissioned art, personal photos, custom designs) that they want to use instead of official token artwork. The current implementation only supports Scryfall-sourced artwork.

---

## Architectural Foundation: Artwork Preference System

### Overview
To support "remembering" artwork choices across token instances, we introduce a **Token Artwork Preference** system that stores user artwork selections independently from individual token instances.

### Core Concept
- **Preference = Default for Token Type**, not per-instance binding
- When creating a new token, the app checks if a preference exists for that token type
- If preference exists → use that artwork as default
- If no preference → use first available Scryfall artwork (current behavior)
- User can manually change artwork on individual token instances without affecting others

### Data Model

**New Hive Model: TokenArtworkPreference**
```dart
// lib/models/token_artwork_preference.dart

import 'package:hive/hive.dart';

part 'token_artwork_preference.g.dart';

@HiveType(typeId: 4)
class TokenArtworkPreference extends HiveObject {
  /// Composite ID matching deduplication logic: "name|pt|colors|type|abilities"
  /// This matches the TokenDefinition.id format from the database
  @HiveField(0)
  String tokenIdentity;

  /// Currently selected/last used artwork (Scryfall URL or file:// path)
  /// This is applied as default when creating new tokens of this type
  @HiveField(1)
  String? lastUsedArtwork;

  /// User's custom uploaded artwork (file:// path), persists independently
  /// Remains available even when user switches to Scryfall artwork
  /// Null if user has never uploaded custom art for this token type
  @HiveField(2)
  String? customArtworkPath;

  TokenArtworkPreference({
    required this.tokenIdentity,
    this.lastUsedArtwork,
    this.customArtworkPath,
  });

  /// Helper: Is custom artwork available for this token type?
  bool get hasCustomArtwork =>
      customArtworkPath != null && customArtworkPath!.isNotEmpty;

  /// Helper: Is currently using custom artwork?
  bool get isUsingCustomArtwork =>
      lastUsedArtwork != null &&
      lastUsedArtwork!.startsWith('file://');
}
```

**Token Identity Key:** Uses composite ID matching database deduplication:
- Format: `"name|pt|colors|type|abilities"`
- Example: `"Treasure|||Artifact|{T}, Sacrifice this artifact: Add one mana of any color."`
- Same format as `TokenDefinition.id` in `lib/models/token_definition.dart`

**Field Separation Rationale:**
- `lastUsedArtwork`: Active preference, determines what new tokens get
- `customArtworkPath`: Persistent storage, survives switching to Scryfall
- User can toggle between custom and Scryfall without losing custom artwork

### Hive Setup Changes

**Update `lib/utils/constants.dart`:**
```dart
class HiveTypeIds {
  static const int item = 0;
  static const int tokenCounter = 1;
  static const int deck = 2;
  static const int tokenTemplate = 3;
  static const int artworkPreference = 4; // NEW
}
```

**Update `lib/database/hive_setup.dart`:**
```dart
import '../models/token_artwork_preference.dart';

class HiveSetup {
  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters (synchronous, must happen before opening boxes)
    Hive.registerAdapter(ItemAdapter());
    Hive.registerAdapter(TokenCounterAdapter());
    Hive.registerAdapter(DeckAdapter());
    Hive.registerAdapter(TokenTemplateAdapter());
    Hive.registerAdapter(TokenArtworkPreferenceAdapter()); // NEW

    // Open boxes in parallel for optimal startup performance
    await Future.wait([
      Hive.openBox<Item>('items'),
      Hive.openLazyBox<Deck>('decks'),
      Hive.openBox<TokenArtworkPreference>('artworkPreferences'), // NEW
    ]);
  }
}
```

**Performance Impact:**
- Parallel box opening minimizes startup delay
- Estimated impact: +10-20ms (negligible)
- Preference box expected to contain 10s-100s of entries (efficient at this scale)

**Migration:**
- Users upgrading from older versions: Hive auto-creates missing box (graceful)
- No migration script needed
- Existing tokens unaffected (preferences created on-demand)

### Artwork Preference Manager

**New Utility: `lib/utils/artwork_preference_manager.dart`**

```dart
import 'package:hive/hive.dart';
import '../models/token_artwork_preference.dart';

class ArtworkPreferenceManager {
  static const String _boxName = 'artworkPreferences';

  /// Get the Hive box (assumes already opened in HiveSetup)
  Box<TokenArtworkPreference> get _box => Hive.box<TokenArtworkPreference>(_boxName);

  /// Get preferred artwork for a token type (returns null if no preference set)
  String? getPreferredArtwork(String tokenIdentity) {
    final preference = _box.get(tokenIdentity);
    return preference?.lastUsedArtwork;
  }

  /// Set preferred artwork for a token type (creates preference if doesn't exist)
  Future<void> setPreferredArtwork(String tokenIdentity, String artworkUrl) async {
    var preference = _box.get(tokenIdentity);

    if (preference == null) {
      // Create new preference
      preference = TokenArtworkPreference(
        tokenIdentity: tokenIdentity,
        lastUsedArtwork: artworkUrl,
      );
      await _box.put(tokenIdentity, preference);
    } else {
      // Update existing preference
      preference.lastUsedArtwork = artworkUrl;
      await preference.save();
    }
  }

  /// Set custom artwork for a token type (stores file path separately)
  Future<void> setCustomArtwork(String tokenIdentity, String filePath) async {
    var preference = _box.get(tokenIdentity);

    if (preference == null) {
      preference = TokenArtworkPreference(
        tokenIdentity: tokenIdentity,
        lastUsedArtwork: filePath,
        customArtworkPath: filePath,
      );
      await _box.put(tokenIdentity, preference);
    } else {
      preference.customArtworkPath = filePath;
      preference.lastUsedArtwork = filePath;
      await preference.save();
    }
  }

  /// Get custom artwork path for a token type (returns null if never uploaded)
  String? getCustomArtworkPath(String tokenIdentity) {
    final preference = _box.get(tokenIdentity);
    return preference?.customArtworkPath;
  }

  /// Check if custom artwork exists for a token type
  bool hasCustomArtwork(String tokenIdentity) {
    final preference = _box.get(tokenIdentity);
    return preference?.hasCustomArtwork ?? false;
  }

  /// Remove custom artwork for a token type (also deletes file)
  Future<void> removeCustomArtwork(String tokenIdentity) async {
    final preference = _box.get(tokenIdentity);
    if (preference == null) return;

    // Delete file if exists
    if (preference.customArtworkPath != null) {
      // TODO: Delete file from filesystem
      // final file = File(preference.customArtworkPath!.replaceFirst('file://', ''));
      // if (await file.exists()) await file.delete();
    }

    // Clear custom artwork fields
    preference.customArtworkPath = null;

    // If this was the active artwork, clear it too
    if (preference.isUsingCustomArtwork) {
      preference.lastUsedArtwork = null;
    }

    await preference.save();
  }

  /// Clear all preferences (for testing/debugging)
  Future<void> clearAll() async {
    await _box.clear();
  }
}
```

**Usage Pattern:**
```dart
// In providers or screens:
final artworkPrefManager = ArtworkPreferenceManager();

// When creating token:
final preferredArtwork = artworkPrefManager.getPreferredArtwork(tokenIdentity);
newItem.artworkUrl = preferredArtwork ?? firstAvailableScryfall;

// When user selects artwork:
await artworkPrefManager.setPreferredArtwork(tokenIdentity, selectedUrl);
item.artworkUrl = selectedUrl;
```

---

## Feature 1: Custom Gradient Backgrounds

### Status
**READY FOR DESIGN REVIEW** - Quick win, low complexity, addresses Problem 1

### Product Requirements (Defined)
- Artless tokens receive a gradient background using the token's color identity
- Gradient style should complement or match the existing color border gradient
- Existing text readability must be maintained via semi-transparent background masks (already implemented for artwork overlays)
- This feature should be implemented regardless of Custom Upload feature status

### Technical Approach (Known)
- Leverage existing `ColorUtils.gradientForColors()` utility
- Apply gradient as background layer in TokenCard Stack (similar to artwork layer)
- Use existing `_buildTextWithBackground()` pattern for text contrast
- Conditional rendering: show gradient only when `item.artworkUrl == null`

### Design Decisions (RESOLVED)

**✓ Q1: Gradient Style**
- **Decision:** Use identical gradient to border (same colors, same stops)
- **Coverage:** Always full card, regardless of artwork display style setting
- **Future Exploration:** If initial implementation is unsatisfactory, explore alternatives:
  - Modified opacity (e.g., lighter/more subtle gradient)
  - Different color distribution (e.g., radial instead of linear)
  - Partial coverage (e.g., bottom 50% of card)
  - Color-shifted variants (e.g., darker/lighter hues)

**✓ Q2: Display Style Interaction**
- **Decision:** Gradient is always full-card regardless of artwork display style setting (Full View / Fadeout)
- **Rationale:** Simplifies implementation, consistent behavior

**✓ Q3: Token Scope**
- **Decision:** Apply gradient to ANY token without artwork set, including:
  - Database tokens without artwork
  - Custom tokens created via NewTokenSheet
  - Tokens that HAD artwork but it was REMOVED by user
- **Behavior:** If `item.artworkUrl == null || item.artworkUrl.isEmpty`, show gradient
- **Rationale:** Consistent visual treatment for all artless tokens

**✓ Q4: Colorless Tokens**
- **Decision:** Use solid grey color (same as border treatment for colorless tokens)
- **Implementation:** `ColorUtils.gradientForColors('')` should return grey gradient

**✓ Q5: Multi-Color Gradients**
- **Decision:** Use multiple color stops showing all colors (like border)
- **Behavior:** WUBRG token shows gradient transitioning through all 5 colors (white → blue → black → red → green)
- **Implementation:** Reuse existing `ColorUtils.gradientForColors()` utility (same as border)
- **Rationale:** Consistent with border visual language, creates vibrant "changing" color effect

---

## Feature 2: Custom Artwork Upload

### Status
**READY FOR IMPLEMENTATION** - Core architecture resolved, UI flow needs refinement

### Product Requirements (Defined)
- Users can upload their own image artwork for any token
- Uploaded artwork stored in a "user artwork slot" (one custom image per token type)
- Uploading new artwork overwrites previous custom artwork for that token type
- Custom artwork should NOT use Scryfall crop percentages (8.8%/14.5%/36.8%)
- Uploaded artwork is "remembered" via TokenArtworkPreference system (see Architectural Foundation)
- When creating a new token of the same type, custom artwork is applied as default if it was last used
- User can toggle between Scryfall and custom artwork without losing custom file
- When user creates token with NO existing preference → default to first available Scryfall artwork (current behavior)

### Cropping Strategy (Defined - User Pre-Crops)
- **Decision Made:** User must crop image before uploading
- **Reasoning:** In-app cropping UI is "extremely complex" (per product brief)
- **Implementation Requirement:** Notify users that custom artwork should be pre-cropped to desired framing

---

## Resolved Design Decisions

### Data Model & Storage

**✓ RESOLVED Q1: File Storage Location**
- **Decision:** Use `getApplicationDocumentsDirectory()` + `custom_artwork/` subfolder
- **File Naming:** `<tokenIdentityHash>_<timestamp>.<extension>`
  - `tokenIdentityHash`: MD5 or similar hash of composite ID (prevents filename collisions)
  - `timestamp`: Unix timestamp ensures uniqueness when uploading multiple times
  - `extension`: Matches uploaded file format (png, jpg, jpeg, heic)
- **Example:** `custom_artwork/a3f2b1c9_1709847123.png`
- **Rationale:** Documents directory persists across app updates, not subject to OS purging

**✓ RESOLVED Q2: Data Model Changes**
- **Decision:** Reuse `Item.artworkUrl` for both Scryfall URLs and local file paths
- **No new Hive fields needed** on Item model
- **Detection:** URL scheme (`https://` = Scryfall, `file://` = custom)
- **Rationale:** Minimal code changes, existing artwork display logic works for both sources

**✓ RESOLVED Q3: TokenTemplate Persistence**
- **Decision:** Deck templates store artwork URLs as-is (including `file://` paths)
- **Limitation:** Custom artwork not portable across devices (deck loads, but custom art missing on other device)
- **Fallback:** If file missing when loading deck → gracefully show no artwork
- **Future Enhancement:** Cloud sync of custom artwork files (out of scope for v1)

**✓ RESOLVED Q4: Artwork Association**
- **Decision:** Use composite ID matching database deduplication (see Architectural Foundation)
- **Storage:** Hive box `Box<TokenArtworkPreference>` with TypeId 4
- **Key Format:** `"name|pt|colors|type|abilities"`
- **Rationale:** Precise matching, consistent with existing deduplication logic

**✓ RESOLVED Q5: Multiple Custom Tokens with Same Name**
- **Decision:** Tokens with different composite IDs have separate artwork preferences
- **Example:**
  - "Custom Dragon|3/3|R|Creature|Flying" → preference A (pirate.png)
  - "Custom Dragon|5/5|R|Creature|Haste" → preference B (dragon.png)
- **Rationale:** Composite ID distinguishes variants, prevents wrong art on wrong tokens

### UI/UX Flow

**✓ RESOLVED Q6: Artwork Selection UI**

**Decision:** Add "Upload Custom Artwork" tile to existing ArtworkSelectionSheet grid

### Current Implementation (ArtworkSelectionSheet)
The existing artwork selection flow:
1. User taps "Artwork" box in ExpandedTokenScreen
2. Modal bottom sheet opens (`artwork_selection_sheet.dart`)
3. Sheet displays:
   - Header: "Select Token Artwork" with close/download buttons
   - Currently Selected section (shows active artwork with remove button)
   - Grid of Scryfall artwork variants (3 columns)
   - Tapping a variant → preview dialog → confirm → applies artwork

### Proposed Update: Add Custom Upload Tile

**Add "Custom Artwork" tile as FIRST item in the grid:**

```
CASE 1: No custom artwork uploaded yet
┌─────────────────────────────────────────┐
│ Select Token Artwork        [↓] [X]     │
├─────────────────────────────────────────┤
│ Currently Selected                      │
│ ┌────┐ Scryfall Art           [🗑️]     │ ← Shows current Scryfall selection
│ │img │ SET: MKM                         │
│ └────┘                                  │
├─────────────────────────────────────────┤
│  Grid of Artwork Options:               │
│  ┌─────┬─────┬─────┐                    │
│  │  📷 │ MKM │ CMM │                    │ ← Upload tile shows camera icon
│  │  +  │  ✓  │     │                    │    (checkmark on currently selected)
│  └─────┴─────┴─────┘                    │
│  Upload  Set1  Set2                     │
│  ┌─────┬─────┬─────┐                    │
│  │ NEO │ ... │ ... │                    │
│  └─────┴─────┴─────┘                    │
└─────────────────────────────────────────┘

CASE 2: Custom artwork uploaded and selected
┌─────────────────────────────────────────┐
│ Select Token Artwork        [↓] [X]     │
├─────────────────────────────────────────┤
│ Currently Selected                      │
│ ┌────┐ Pirate.png (Custom)     [🗑️]    │ ← Shows custom art
│ │img │ SET: Custom Upload               │
│ └────┘                                  │
├─────────────────────────────────────────┤
│  Grid of Artwork Options:               │
│  ┌─────┬─────┬─────┐                    │
│  │ img │ MKM │ CMM │                    │ ← Tile shows custom thumbnail + checkmark
│  │  ✓  │     │     │                    │
│  └─────┴─────┴─────┘                    │
│ Custom  Set1  Set2                      │
│  ┌─────┬─────┬─────┐                    │
│  │ NEO │ ... │ ... │                    │
│  └─────┴─────┴─────┘                    │
└─────────────────────────────────────────┘
```

**Implementation Details:**

1. **Custom Artwork Tile - Two States:**

   **State A: No Custom Artwork Yet**
   - Icon: Camera (📷) or Upload icon
   - Label: "Upload" (below icon)
   - Background: Distinct color (e.g., primary color) to differentiate from Scryfall tiles
   - Position: First item (index 0) in grid
   - Tap behavior: Show educational dialog → open image picker

   **State B: Custom Artwork Exists**
   - Icon: Thumbnail of custom artwork (scaled to fit tile)
   - Label: "Custom" (below thumbnail)
   - Checkmark overlay if currently selected
   - **Edit indicator:** Small edit/pencil icon overlay (top-right or center) to indicate "tap to change"
   - Position: First item (index 0) in grid
   - Tap behavior: Show replacement dialog (see below)

2. **Upload Tile Behavior (State A - No Custom Art):**
   - Tap → Show educational dialog (pre-crop guidance)
   - User confirms → Open image picker directly
   - User selects image → Validate (size, format)
   - Save file → Update preference → Apply to token
   - Sheet refreshes, tile now shows State B (custom thumbnail)

3. **Custom Art Tile Behavior (State B - Custom Art Exists):**
   - Tap → Show dialog:
     ```
     ┌──────────────────────────────┐
     │  Custom Artwork              │
     ├──────────────────────────────┤
     │  [Preview of current image]  │
     │                              │
     │  Upload a new image to       │
     │  replace the current one?    │
     │                              │
     │  [ Cancel ]  [ Upload New ]  │
     └──────────────────────────────┘
     ```
   - Cancel → Dismiss dialog
   - Upload New → Show educational dialog → open image picker → replace custom art

4. **Currently Selected Section:**
   - When custom artwork active: Show "(Custom)" label next to filename
   - When Scryfall artwork active: Show set code as normal
   - Remove button works for both custom and Scryfall
   - Removing custom artwork: Deletes file, tile reverts to State A (upload prompt)

5. **Grid Modifications:**
   - Insert custom tile at beginning: `[customTile, ...scryfall variants]`
   - Grid layout unchanged (3 columns, existing styling)
   - Custom tile uses same `_ArtworkOption` pattern (consistency)
   - Tile state determined by checking `ArtworkPreferenceManager.hasCustomArtwork(tokenIdentity)`

6. **No Additional Menus:**
   - Educational dialog is ONLY alert before picker (not a separate screen)
   - Replacement dialog is simple confirmation (not a separate screen)
   - No separate custom artwork management screen

**Code Changes Required:**
- `lib/widgets/artwork_selection_sheet.dart`:
  - Add `_CustomUploadTile` widget (similar to `_ArtworkOption`)
  - Insert tile at index 0 in GridView
  - Update itemCount: `artworkVariants.length + 1`
  - Update itemBuilder: `if (index == 0) return _CustomUploadTile() else ...`
  - Handle upload flow (dialog → picker → validation → save)
- Currently Selected section already supports both URL types (no changes needed)

**Advantages:**
- ✅ No additional navigation (stays in one sheet)
- ✅ Discoverable (user sees upload option with Scryfall options)
- ✅ Consistent UI pattern (tile grid)
- ✅ Minimal code changes (add tile to existing grid)
- ✅ Scalable (can add more upload sources as tiles in future)
- ✅ Simple mental model (all artwork sources in one place)

**User Flow Example:**
1. User opens artwork selection → sees grid with "Upload" tile + Scryfall options
2. Taps "Upload" → dialog: "For best results, crop your image beforehand..."
3. Confirms → image picker opens
4. Selects photo → validates → saves
5. Sheet closes, token now shows custom artwork
6. Next time: custom artwork appears in "Currently Selected" section

**✓ RESOLVED: Upload Tile Visibility**
- **Decision:** Custom artwork tile ALWAYS appears (first item in grid)
- **Behavior:**
  - No custom art uploaded → Shows camera icon + "Upload" label
  - Custom art uploaded → Shows thumbnail + "Custom" label
  - User can replace by tapping tile → confirmation dialog → new upload
- **Rationale:** Consistent grid position, clear upload/replace workflow

**✓ RESOLVED Q7: Custom Artwork Display**
- **Decision:** Use same artwork preview widget as Scryfall (existing implementation)
- **Label:** Show "(Custom)" suffix when displaying custom artwork
- **Fallback:** If custom file missing → show placeholder + error message

**✓ RESOLVED Q8: Artwork Management**
- **Decision:**
  - ✅ Users CAN delete/clear custom artwork (via "Remove Custom Artwork" button or equivalent)
  - ✅ Users CAN replace custom artwork (upload new image → overwrites previous)
  - ✅ Users CAN switch to Scryfall after uploading custom (custom file persists, can switch back)
- **Behavior:** Deleting custom artwork also removes file from filesystem

**✓ RESOLVED Q9: File Picker**
- **Package:** `image_picker: ^1.0.0` (or latest stable)
- **Sources:** Photo library AND camera (user chooses via system picker)
- **Platform Support:**
  - iOS: Full support
  - Android: Full support
  - Web: Photo library only (no camera access)
  - macOS/Windows: File picker only
- **Configuration:** Set `maxWidth: 2048, maxHeight: 2048, imageQuality: 85` to prevent oversized files

**✓ RESOLVED Q10: User Notification/Education**
- **Decision:** Show alert dialog BEFORE file picker opens
- **Message:**
  ```
  "Upload Custom Artwork"

  For best results, crop your image before uploading.
  Recommended: Portrait orientation (3:4 ratio).

  Maximum file size: 5MB
  Supported formats: PNG, JPEG
  ```
- **Buttons:** [Cancel] [Choose Image]
- **Rationale:** Proactive education, prevents user frustration with poorly framed artwork

### Image Processing

**✓ RESOLVED Q11: File Format Support**
- **Supported Formats:** PNG, JPEG (jpg/jpeg extensions), HEIC (iOS)
- **Validation:** Check file extension before processing, reject unsupported formats
- **No Conversion:** Store original format as-is (simpler implementation, preserves quality)
- **Error Handling:** Show user-friendly error if unsupported format selected

**✓ RESOLVED Q12: File Size Limits**
- **Maximum File Size:** 5MB (reasonable for high-quality artwork, prevents abuse)
- **Behavior:** Reject oversized files with error message
- **No Auto-Compression:** User must compress before upload (simpler, predictable)
- **Error Message:** "Image too large (X MB). Please choose an image under 5MB."

**✓ RESOLVED Q13: Image Resizing**
- **Decision:** Resize/compress via `image_picker` configuration during selection
- **Configuration:**
  ```dart
  maxWidth: 2048,
  maxHeight: 2048,
  imageQuality: 85,  // 0-100, good balance of quality/size
  ```
- **Rationale:**
  - Reduces storage footprint without user effort
  - 2048px sufficient for high-DPI displays
  - Quality 85 visually lossless for most images
- **Storage Original:** No, store resized version from picker

**✓ RESOLVED Q14: Display Mode for Custom Artwork**
- **Decision:** Custom artwork respects user's artwork display style setting (Full View / Fadeout)
- **Crop Percentages:** 0% on all sides (no crop, assumes user pre-cropped)
- **Rationale:**
  - Consistent with user's preference for official artwork
  - User already cropped image, don't crop again
  - Simpler than maintaining separate display modes
- **Implementation:** Pass `cropLeft: 0, cropRight: 0, cropTop: 0, cropBottom: 0` for custom artwork

**✓ RESOLVED Q15: Aspect Ratio Handling**
- **Decision:** Maintain aspect ratio, allow overflow (clipped by card bounds)
- **Tall Images (Portrait):** Fill width, crop top/bottom overflow
- **Wide Images (Landscape):** Fill height, crop left/right overflow
- **No Hard Validation:** Accept any aspect ratio, let `CroppedArtworkWidget` handle scaling
- **User Guidance:** Recommend 3:4 portrait in upload dialog (matches typical card art)
- **Rationale:** Flexible, predictable behavior without complex validation logic

### Persistence & Caching

**✓ RESOLVED Q16: Artwork Association Scope**
- **Decision:** Custom art auto-applies to ALL tokens matching the composite ID (both database and custom tokens)
- **Behavior:**
  - User uploads custom art for "Treasure" (from database) → preference saved
  - Future "Treasure" tokens (database or custom with matching ID) → use custom art
- **Multiple Scryfall Options:** Custom artwork becomes the preferred default, but user can switch to any Scryfall option
- **Rationale:** Consistent behavior regardless of token source (database vs. custom)

**✓ RESOLVED Q17: Cross-Instance Persistence**
- **Decision:** Soft default (tokens can diverge)
- **Behavior:**
  - User creates Token A with custom art → preference saved
  - User creates Token B (same composite ID) → automatically gets custom art from preference
  - User can manually change Token B to different artwork → only Token B changes
- **Existing Instances:** NOT auto-updated when preference changes
- **Rationale:** Predictable, non-surprising behavior (changing one token doesn't affect others on the board)

**✓ RESOLVED Q18: Artwork Sync Across Tokens**
- **Decision:** NO automatic sync across existing instances
- **Behavior:**
  - User uploads custom art for Token A → preference updated, only Token A changes
  - Token B (same composite ID, already on board) → keeps its current artwork
  - New tokens created AFTER preference change → get new custom art
- **Rationale:** Avoids surprising users with mass updates, keeps implementation simple

**✓ RESOLVED Q19: Deck Loading with Custom Artwork**
- **Decision:** V1 does NOT support cross-device custom artwork
- **Behavior:**
  - Deck template stores `file://` paths
  - Loading deck on different device → file path invalid, gracefully fallback to no artwork
  - Preference system still works (if user uploaded custom art on this device, it applies)
- **Future Enhancement:** iCloud sync of custom artwork files (out of scope for v1)
- **Mitigation:** Document limitation in release notes

**✓ RESOLVED Q20: App Reinstall / Data Loss**
- **Decision:** Graceful fallback, no crashes
- **Behavior:**
  - App reinstall → Hive boxes cleared, custom artwork files deleted
  - Existing tokens (if somehow persisted) with `file://` URLs → show no artwork
  - No error state, just empty artwork
- **Implementation:** `ArtworkManager.getCachedArtworkFile()` returns `null` if file missing
- **Rationale:** Silent failure better than crash, user can re-upload if needed

### Migration & Compatibility

**✓ RESOLVED Q21: Existing Token Migration**
- **Decision:** Gradient backgrounds apply to ALL artless tokens (existing and new)
- **Behavior:**
  - After feature release, any token with `artworkUrl == null` gets gradient
  - No database migration needed (rendering logic change only)
  - Works retroactively for existing tokens on board
- **Rationale:** Immediate visual improvement for all users, no migration complexity

**✓ RESOLVED Q22: Hive Migration**
- **Decision:** New box only, no existing box changes
- **Migration:**
  - `TokenArtworkPreference` is NEW Hive box (TypeId 4)
  - No changes to existing `Item`, `Deck`, `TokenTemplate` models
  - No regeneration of existing adapters needed
  - Only generate adapter for `TokenArtworkPreference`
- **Upgrade Path:**
  - User upgrades app → Hive creates new `artworkPreferences` box automatically
  - Existing tokens unaffected, preferences created on-demand when user selects artwork
- **Rationale:** Zero-risk migration, no data loss possible

**✓ RESOLVED Q23: Backwards Compatibility**
- **Decision:** Graceful degradation
- **Behavior:**
  - User downgrades to older version → `artworkPreferences` box ignored
  - Older version doesn't know about TypeId 4 → no errors (box simply not opened)
  - Tokens with `file://` artwork URLs → older version treats as invalid URL, shows no artwork
  - No crashes, no data corruption
- **Limitation:** Custom artwork functionality lost on downgrade, but app remains functional
- **Rationale:** Hive handles unknown type IDs gracefully, URL scheme makes detection easy

---

## Feature 3: Custom Tokens in Recent/Favorites

### Status
**DEFERRED** - Addresses broader custom token discoverability, depends on Feature 2 design

### Product Requirements (Defined)
- Custom tokens (created via NewTokenSheet) should appear in Recent tab
- Custom tokens should be favoritable like database tokens

### Technical Challenges (Identified)

**Current Implementation:**
- Recent/Favorites stored in SharedPreferences (SettingsProvider)
- Recent: List of token names (`List<String>`)
- Favorites: List of token names (`List<String>`)
- Assumes tokens exist in `TokenDatabase` (can be looked up by name)

**Problem:**
- Custom tokens don't exist in TokenDatabase
- Name alone is insufficient (multiple custom tokens can share same name)
- No unique identifier for custom tokens

### Deferred Design Questions (Not Blocking Feature 2)

**Q24: Custom Token Identity** (Deferred)
**Q25: Storage Format** (Deferred)
**Q26: Data Model** (Deferred)
**Q27: UI Integration** (Deferred)
**Q28: Lifecycle Management** (Deferred)
**Q29: Favorites Limit** (Deferred)

**Recommendation:** Implement Feature 2 (Custom Artwork Upload) first, gather user feedback, then design Feature 3 based on actual usage patterns.

---

## Implementation Priority & Phasing

### Recommended Phases

**Phase 1: Artwork Preference Infrastructure (Foundation)**
- Create `TokenArtworkPreference` Hive model and adapter
- Create `ArtworkPreferenceManager` utility
- Update `HiveSetup` to register and open new box
- Integrate preference loading into token creation flows
- **Estimated Effort:** 1-2 days
- **Risk:** Low (additive, no existing code changes)
- **Can ship:** No (infrastructure only, no user-facing features)

**Phase 2: Gradient Backgrounds (Quick Win)**
- Implement gradient background rendering in `TokenCard`
- Resolve gradient style questions (Q1-Q5) with product owner
- **Dependencies:** None (can implement independently)
- **Estimated Effort:** 1 day
- **Risk:** Low (rendering logic only)
- **Can ship:** Yes (immediate visual improvement)

**Phase 3: Custom Artwork Upload (Core Feature)**
- Add custom artwork upload UI (MUST refine flow first - see Q6)
- Implement file management (save, delete, validation)
- Integrate with preference system from Phase 1
- Update `CroppedArtworkWidget` to handle file:// URLs
- Update `ArtworkManager` to support custom file paths
- **Dependencies:** Phase 1 (preference infrastructure)
- **Estimated Effort:** 3-5 days
- **Risk:** Medium (file management, cross-platform testing)
- **Can ship:** Yes (high user value)

**Phase 4: Custom Tokens in Recent/Favorites (Enhancement)**
- **Status:** DEFERRED until after Phase 3 ships
- Gather user feedback on custom artwork usage
- Design data model based on actual patterns
- **Dependencies:** Phase 3 shipped and validated

---

## Technical Dependencies

### Required Packages

**Add to `pubspec.yaml`:**
```yaml
dependencies:
  image_picker: ^1.0.7  # Image selection from gallery/camera
  path_provider: ^2.1.2  # Access to app directories
  crypto: ^3.0.3  # MD5 hashing for file names

  # Existing packages (verify versions)
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  provider: ^6.1.0

dev_dependencies:
  build_runner: ^2.4.0
  hive_generator: ^2.0.0
```

### Code Changes Required

**New Files:**
- `lib/models/token_artwork_preference.dart` (NEW)
- `lib/models/token_artwork_preference.g.dart` (GENERATED)
- `lib/utils/artwork_preference_manager.dart` (NEW)

**Modified Files:**
- `lib/utils/constants.dart` (add HiveTypeIds.artworkPreference = 4)
- `lib/database/hive_setup.dart` (register adapter, open box)
- `lib/screens/token_search_screen.dart` (load preference when creating tokens)
- `lib/widgets/new_token_sheet.dart` (load preference when creating custom tokens)
- `lib/screens/expanded_token_screen.dart` (save preference when selecting artwork, add upload UI)
- `lib/widgets/token_card.dart` (add gradient background for artless tokens)
- `lib/widgets/cropped_artwork_widget.dart` (handle file:// URLs)
- `lib/utils/artwork_manager.dart` (getCachedArtworkFile support for local files)

---

## Implementation Checklist for Autonomous Agent

### Phase 1: Artwork Preference Infrastructure

**Step 1.1: Create TokenArtworkPreference Model**
- [ ] Create `lib/models/token_artwork_preference.dart`
- [ ] Copy model code from "Architectural Foundation" section
- [ ] Verify `@HiveType(typeId: 4)` annotation present
- [ ] Run `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Verify `token_artwork_preference.g.dart` generated successfully

**Step 1.2: Update Hive Constants**
- [ ] Open `lib/utils/constants.dart`
- [ ] Add `static const int artworkPreference = 4;` to `HiveTypeIds` class
- [ ] Verify no conflicting type IDs

**Step 1.3: Update Hive Setup**
- [ ] Open `lib/database/hive_setup.dart`
- [ ] Import `TokenArtworkPreference` and adapter
- [ ] Add `Hive.registerAdapter(TokenArtworkPreferenceAdapter());` after existing adapters
- [ ] Update `Future.wait()` to include `Hive.openBox<TokenArtworkPreference>('artworkPreferences')`
- [ ] Test app startup (should not crash)

**Step 1.4: Create ArtworkPreferenceManager**
- [ ] Create `lib/utils/artwork_preference_manager.dart`
- [ ] Copy utility code from "Architectural Foundation" section
- [ ] Verify all methods implemented (get, set, remove, hasCustom)
- [ ] Add unit tests (optional but recommended)

**Step 1.5: Integrate Preference Loading**
- [ ] Open `lib/screens/token_search_screen.dart`
- [ ] Find token creation logic (where `Item.toItem()` is called)
- [ ] Add preference loading:
  ```dart
  final artworkPrefManager = ArtworkPreferenceManager();
  final tokenIdentity = definition.id;  // Composite ID
  final preferredArtwork = artworkPrefManager.getPreferredArtwork(tokenIdentity);

  newItem.artworkUrl = preferredArtwork ?? definition.artwork.first?.url;
  ```
- [ ] Repeat for `lib/widgets/new_token_sheet.dart` (custom token creation)
- [ ] Test: Create token, select artwork, create another token of same type → should use same artwork

**Step 1.6: Integrate Preference Saving**
- [ ] Open `lib/screens/expanded_token_screen.dart`
- [ ] Find Scryfall artwork selection logic
- [ ] After `item.artworkUrl = selectedUrl;`, add:
  ```dart
  final artworkPrefManager = ArtworkPreferenceManager();
  final tokenIdentity = "${item.name}|${item.pt}|${item.colors}|${item.type}|${item.abilities}";
  await artworkPrefManager.setPreferredArtwork(tokenIdentity, selectedUrl);
  ```
- [ ] Test: Select artwork, verify preference saved, create new token → uses preference

**Validation:**
- [ ] App starts without crashes
- [ ] Selecting artwork on one token applies to new tokens of same type
- [ ] Preference persists across app restarts
- [ ] No regressions in existing artwork functionality

---

### Phase 2: Gradient Backgrounds

**READY TO IMPLEMENT** - All design questions resolved

**Step 2.1: Implement Gradient Rendering**
- [ ] Open `lib/widgets/token_card.dart`
- [ ] In `Stack` children, add gradient layer BEFORE artwork layer:
  ```dart
  // Add gradient background for artless tokens
  if (widget.item.artworkUrl == null || widget.item.artworkUrl!.isEmpty)
    _buildGradientLayer(context),
  ```
- [ ] Implement `_buildGradientLayer()` method:
  ```dart
  Widget _buildGradientLayer(BuildContext context) {
    final gradient = ColorUtils.gradientForColors(widget.item.colors);
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12), // Match card border radius
        ),
      ),
    );
  }
  ```
- [ ] **IMPORTANT:** Add implementation note comment in code:
  ```dart
  // NOTE: Current gradient matches border exactly (same colors, same stops).
  // If visual appearance is unsatisfactory, explore alternatives:
  // - Modified opacity (e.g., gradient with 0.6 alpha for subtler effect)
  // - Radial gradient instead of linear
  // - Partial coverage (e.g., only bottom 50% of card)
  // - Color-shifted variants (lighter/darker hues)
  // - Different gradient direction (vertical, diagonal, etc.)
  ```
- [ ] Test with tokens of various colors:
  - [ ] Single color: W, U, B, R, G
  - [ ] Two colors: WU, UB, BR, RG, GW
  - [ ] Multi-color: WUG, WUBRG
  - [ ] Colorless (empty string)
- [ ] Verify text remains readable (semi-transparent backgrounds should work)
- [ ] Test removal of artwork (token with art → remove art → should show gradient)

**Validation:**
- [ ] Artless tokens show gradient backgrounds
- [ ] Tokens with artwork do NOT show gradient (no double background)
- [ ] Text remains readable over gradients
- [ ] Gradient style matches product decisions (Q1-Q5)
- [ ] No performance degradation with 50+ tokens on screen

---

### Phase 3: Custom Artwork Upload

**READY TO IMPLEMENT** - All design questions resolved, UI flow approved

**Step 3.1: Add Dependencies**
- [ ] Add `image_picker`, `path_provider`, `crypto` to `pubspec.yaml`
- [ ] Run `flutter pub get`
- [ ] Verify packages install successfully

**Step 3.3: Implement File Management Utilities**
- [ ] Extend `lib/utils/artwork_manager.dart` with custom artwork methods:
  - `saveCustomArtwork(String tokenIdentity, File imageFile)` → saves file, returns file:// path
  - `deleteCustomArtwork(String filePath)` → removes file from filesystem
  - `getCustomArtworkDirectory()` → returns `custom_artwork/` directory
- [ ] Implement file naming: `<MD5(tokenIdentity)>_<timestamp>.<extension>`
- [ ] Implement file size validation (5MB max)
- [ ] Implement format validation (PNG, JPEG, HEIC)

**Step 3.4: Update CroppedArtworkWidget**
- [ ] Open `lib/widgets/cropped_artwork_widget.dart`
- [ ] In `_loadImage()`, detect URL scheme:
  ```dart
  if (file.path.startsWith('file://')) {
    // Local file
    final localPath = file.path.replaceFirst('file://', '');
    final localFile = File(localPath);
    final bytes = await localFile.readAsBytes();
    // ... rest of loading logic
  } else {
    // Scryfall URL (existing logic)
  }
  ```
- [ ] For custom artwork, pass `cropLeft: 0, cropRight: 0, cropTop: 0, cropBottom: 0`

**Step 3.5: Implement Custom Artwork Tile in ArtworkSelectionSheet**
- [ ] Open `lib/widgets/artwork_selection_sheet.dart`
- [ ] Create `_CustomArtworkTile` stateful widget with two states:
  - State A: No custom art (camera icon + "Upload" label)
  - State B: Custom art exists (thumbnail + "Custom" label + checkmark if selected)
- [ ] Insert custom tile at index 0 in grid:
  ```dart
  GridView.builder(
    itemCount: artworkVariants.length + 1, // +1 for custom tile
    itemBuilder: (context, index) {
      if (index == 0) {
        return _CustomArtworkTile(
          tokenIdentity: tokenIdentity,
          isSelected: item.artworkUrl?.startsWith('file://') ?? false,
          onUploadComplete: (filePath) {
            setState(() {
              item.artworkUrl = filePath;
            });
          },
        );
      }
      // Existing Scryfall tile logic (index - 1)
      final variant = artworkVariants[index - 1];
      return _ArtworkOption(...);
    },
  );
  ```
- [ ] Implement `_CustomArtworkTile` tap handlers:
  - **State A (no custom):** Tap → show educational dialog → open picker
  - **State B (has custom):** Tap → show replacement dialog → open picker if confirmed
- [ ] Implement upload handler in `_CustomArtworkTile`:
  ```dart
  Future<void> _uploadCustomArtwork() async {
    // Show educational dialog
    final confirmed = await showDialog<bool>(...);
    if (!confirmed) return;

    // Open image picker
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    // Validate file
    final file = File(pickedFile.path);
    final size = await file.length();
    if (size > 5 * 1024 * 1024) {
      // Show error: file too large
      return;
    }

    // Save file
    final tokenIdentity = "${widget.item.name}|${widget.item.pt}|...";
    final artworkPath = await ArtworkManager.saveCustomArtwork(tokenIdentity, file);

    // Update item and preference
    widget.item.artworkUrl = artworkPath;
    final prefManager = ArtworkPreferenceManager();
    await prefManager.setCustomArtwork(tokenIdentity, artworkPath);

    setState(() {});  // Refresh UI
  }
  ```
- [ ] Add "Remove Custom Artwork" handler (deletes file, clears preference)
- [ ] Add "Use Custom Artwork" handler (switches from Scryfall to custom)

**Validation:**
- [ ] Upload custom artwork → file saved to custom_artwork/ directory
- [ ] Token displays custom artwork correctly
- [ ] Preference saved → new tokens of same type use custom artwork
- [ ] Switch to Scryfall → custom file persists (not deleted)
- [ ] Switch back to custom → uses preserved custom file
- [ ] Remove custom → file deleted, preference cleared
- [ ] Upload new custom → old file deleted, new file saved
- [ ] File size validation works (>5MB rejected)
- [ ] Format validation works (unsupported formats rejected)
- [ ] Educational dialog appears before picker opens
- [ ] Works on iOS, Android, Web (test all platforms)

**Edge Case Testing:**
- [ ] Missing file (simulate deletion) → gracefully shows no artwork
- [ ] Corrupted file → gracefully shows no artwork
- [ ] Deck with custom artwork loaded on different device → falls back gracefully
- [ ] 50+ custom artworks uploaded → app remains performant

---

## Success Metrics

**Engagement Metrics:**
- % of users who upload at least one custom artwork
- Average number of custom artworks per user
- Custom artwork upload frequency (uploads per week)

**Quality Metrics:**
- User satisfaction rating for gradient backgrounds (survey)
- Support tickets related to custom artwork (file issues, UI confusion)
- Crash rate related to custom artwork features (should be 0%)

**Adoption Metrics:**
- Custom token creation rate (with artwork) vs. database token creation rate
- Retention: % of users who continue using custom artwork after first upload

---

## Next Steps

**✅ ALL DESIGN DECISIONS RESOLVED - READY FOR IMPLEMENTATION**

1. **✅ COMPLETE:** Architectural foundation designed (TokenArtworkPreference system)
2. **✅ COMPLETE:** Gradient background questions (Q1-Q5) answered
3. **✅ COMPLETE:** Custom artwork upload UI flow approved (tile-based approach)
4. **✅ COMPLETE:** All 23 design questions resolved

**Implementation Phases (All Unblocked):**
- ✅ **Phase 1:** Artwork Preference Infrastructure - READY TO START
- ✅ **Phase 2:** Gradient Backgrounds - READY TO START (can run in parallel with Phase 1)
- ✅ **Phase 3:** Custom Artwork Upload - READY TO START (requires Phase 1 complete)

**Recommended Order:**
1. Start Phase 1 + Phase 2 in parallel (independent features)
2. Complete Phase 1, validate preference system works
3. Start Phase 3 (depends on Phase 1 infrastructure)
4. Ship Phase 1 + Phase 2 first (lower risk, immediate visual improvement)
5. Ship Phase 3 after validation (higher complexity, file management)

**Optional Next Steps:**
- Define success metric targets (e.g., "10% of users upload custom artwork within 30 days")
- Create visual mockups for marketing materials
- Plan beta testing strategy for custom artwork feature