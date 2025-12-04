✅ Removed the "Board Update" submenu - all actions now in main menu for fewer taps.

## Bug Fixes (2025-12-03)

### Drag-and-Drop Artwork Loading Crash
**Symptom:** App crash when dragging token from bottom to top of list with 5+ unloaded artworks visible. Crash occurred when dropping the token, as all unloaded artwork tried to load simultaneously.

**Root Cause:** During drag operations, widgets rebuild rapidly. Each rebuild created a new image decode operation. With multiple unloaded artworks, this resulted in 15-25+ concurrent decode operations overwhelming the system (O(rebuilds × widgets) complexity).

**Fixes Implemented:**
1. **Image Caching (CroppedArtworkWidget):** Converted to StatefulWidget that caches decoded ui.Image. Subsequent rebuilds reuse cached image instead of re-decoding. Reduces to O(widgets) decode operations.
2. **Mounted Checks:** Added mounted checks before setState to prevent crashes from disposed widgets during async image loading.
3. **Cleanup Protection (TokenCard):** Delayed artwork URL cleanup by 2 seconds to prevent Hive modifications during drag/scroll operations.

**Files Modified:**
- `lib/widgets/cropped_artwork_widget.dart` - Added image caching and lifecycle management
- `lib/widgets/token_card.dart` - Added cleanup delay and mounted checks

### Save Deck Dialog Crash
**Symptom:** TextEditingController disposed exception when saving deck.

**Root Cause:** Controller disposed immediately when dialog closed, but TextField still rebuilding during dismissal animation.

**Fix:** Delayed controller disposal using `WidgetsBinding.instance.addPostFrameCallback()` to wait until all frames processed.

**Files Modified:**
- `lib/screens/content_screen.dart:757-762` - Added postFrameCallback for controller disposal