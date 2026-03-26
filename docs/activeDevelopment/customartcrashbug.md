This document records a bug we found in the early releases of Tripling Season. A mitigation has been implemented, this document reflects the historical details so that we can keep troubleshooting if it comes up again. 

---

## INVESTIGATION: Mass Custom Artwork Loading Crash

**Status:** Partially mitigated (resize on upload implemented), crash not replicated

**Last Updated:** March 22, 2026

### User Report (Android 16, Pixel 9)

- Built deck with 34 custom tokens, each with uploaded artwork
- App crashes on reload/restart
- Won't recover until cache is cleared
- Clearing cache removes artwork URLs → no crash (but loses all custom artwork)

### Root Cause Hypothesis (UNVERIFIED)

#### The Loading Chain (App Startup)

1. **ContentScreen builds** → ListenableBuilder triggers on Hive box
2. **ReorderableListView.builder** creates 34+ TokenCards simultaneously
3. **Each TokenCard** builds its artwork layer:
   - Calls `ArtworkManager.getCachedArtworkFile(artworkUrl)`
   - For `file://` URLs (custom artwork), this **immediately returns File** (local file check is synchronous)
4. **FutureBuilder completes instantly** for all 34 cards (file exists)
5. **34 CroppedArtworkWidget instances created** nearly simultaneously
6. **Each CroppedArtworkWidget.initState()** calls `_loadImageIfNeeded()`:
   - `await file.readAsBytes()` - 34 concurrent file reads
   - `await ui.instantiateImageCodec(bytes)` - **34 concurrent image codec instantiations**
   - `await codec.getNextFrame()` - 34 concurrent frame extractions

#### Critical Bottlenecks (THEORETICAL)

**Primary Issue: Image Codec Overload**
- `ui.instantiateImageCodec()` is CPU/memory intensive
- 34 concurrent calls overwhelm the system (especially Android)
- Each image is full-resolution (cropped to 4:3 aspect ratio, 85% quality)
- Android's image decoder has limited capacity for concurrent operations

**Secondary Issues:**
- **Memory pressure**: 34 full-res images in memory simultaneously
- **File I/O bottleneck**: 34 concurrent file reads on mobile storage
- **No throttling**: All loads fire at once when list builds

#### Why Scryfall Artwork Might Not Crash (THEORETICAL)

- Scryfall URLs require **network download** before codec instantiation
- Downloads happen asynchronously over time (network latency provides natural throttling)
- Not all 34 images arrive simultaneously
- Custom artwork is **instant local file access** → all 34 hit codec simultaneously

#### Why Original Drag-Drop Bug Was Related

Original bug: "Dragging token causes multiple cards to rebuild, if artwork doesn't lazy load fast enough → crash"

- Same root cause: **simultaneous artwork rebuilds**
- Drag-drop triggered ~5-10 rebuilds simultaneously
- Custom artwork (instant local access) hit codec all at once
- Fixed by adding 2-second stability delay before cleanup (reduced rebuilds)
- But didn't address the **startup scenario** with 34+ saved custom artworks

### Technical Discovery: CroppedArtworkWidget Bypasses Flutter's Image Cache

**Key Finding:** CroppedArtworkWidget (cropped_artwork_widget.dart:82-87) directly calls `ui.instantiateImageCodec()`, completely bypassing Flutter's image caching system.

#### Standard Flutter Image Loading (NOT used here):
```
Image.file()
  → FileImage (ImageProvider)
  → PaintingBinding.instance.imageCache
    → Throttled loading
    → Memory limits enforced
    → Automatic eviction
    → Shared cache across widgets
```

#### CroppedArtworkWidget Path (CURRENTLY used):
```
CroppedArtworkWidget
  → Direct file.readAsBytes()
  → Direct ui.instantiateImageCodec(bytes)
    → NO throttling
    → NO memory management
    → NO cache sharing
    → Each widget holds its own ui.Image in memory
```

**Implication:** 34 widgets = 34 independent codec instantiations + 34 separate ui.Image objects in memory, all simultaneously.

### Image Size Comparison (Critical Difference)

#### Scryfall "Large" Images:
- Resolution: 672×936 pixels (Scryfall's `/large/` endpoint)
- Format: Pre-optimized JPEG for web
- Typical file size: 100-300KB per image
- **34 images ≈ 10MB total file size**
- Decoded to ui.Image: ~2.4MB per image (672×936×4 bytes RGBA)
- **34 decoded ≈ 82MB in memory**

#### Custom Uploaded Images:
- Source: Modern phone cameras (12MP+, typically 4000×3000 pixels)
- Processing: Cropped to 4:3 aspect via ImageCropper, `imageQuality: 85`
- ImageCropper **does NOT resize** - only crops region of interest
- Typical file size: **1-3MB per image** (depends on image content)
- **34 images ≈ 68-100MB total file size**
- Decoded to ui.Image: Varies by camera, but could be **~46MB per image** (4000×3000×4 bytes RGBA)
- **34 decoded ≈ 1.5GB in memory**

**Memory explosion hypothesis:** Custom artwork could require **18x more memory** than Scryfall images when decoded.

### Why User Hasn't Reported Scryfall Crashes (SPECULATION)

1. **They might not have 34+ cached Scryfall tokens** - Database tokens may not all have artwork selected, or user primarily uses custom tokens
2. **Scryfall images are smaller** - Even if they have 34 cached, it's 82MB vs 1.5GB
3. **Android memory limits** - Pixel 9 might handle 82MB but not 1.5GB of simultaneous image decoding

---

### Mitigation Applied

**Option 1 (Resize on Upload) is implemented** as of v1.8.0:
- `ArtworkManager.resizeImageFile()` caps custom uploads at 768px max dimension
- Called in `artwork_selection_sheet.dart` after ImageCropper returns
- Reduces new uploads from 2-8MB to ~100-200KB
- Does NOT fix pre-existing oversized artwork already on user devices

**Remaining unimplemented options:**
- Option 2: Throttled loading queue (no concurrency limit on codec calls)
- Option 4: Switch to Flutter's Image.file() (still bypasses Flutter image cache)
- Option 5: Lazy/visibility-based loading

---

## Investigation Next Steps

1. **Attempt to replicate crash:**
   - Create test deck with 34+ custom tokens
   - Use full-resolution phone camera images (4000×3000+)
   - Test on Android device (preferably Pixel 9 or similar)
   - Monitor memory usage during startup

2. **Gather more user data:**
   - Image file sizes from user's device
   - Actual crash logs/stack traces
   - Device specifications and available memory
   - Android version details

3. **Instrumentation:**
   - Add debug logging to CroppedArtworkWidget.initState()
   - Track concurrent codec instantiations
   - Monitor memory usage during image loading
   - Time how long startup takes with 34+ images

4. **If crash is confirmed:**
   - Decide on solution (probably Option 2 throttle queue)
   - Implement fix
   - Test with user's exact scenario
   - Consider migration path for existing custom artwork

---

## Questions to Resolve

1. **Can we replicate the crash?** If not, what's different about the user's environment?
2. **Which solution fits the app's UX best?** Gradual appearance vs instant appearance?
3. **What's acceptable startup time?** How long can users wait for artwork?
4. **Memory constraints?** How many full-res images can we safely hold in memory?
5. **Edge cases?** What if user has 100+ custom artworks? (future-proofing)
6. **Is this Android-specific?** Does iOS handle this scenario better?
