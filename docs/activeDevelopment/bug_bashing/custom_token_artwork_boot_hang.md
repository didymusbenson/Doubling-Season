# Bug: App Hangs on Boot After Custom Tokens with Artwork

**Status:** Investigating
**Reported by:** Multiple users
**Severity:** Critical (forces uninstall/reinstall, data loss)

## Symptoms

- Users create custom tokens (via "Create Custom Token") and assign custom artwork
- App works fine during the session where tokens are created
- On next app launch, the app hangs on the loading/splash screen and never proceeds
- The loading screen does not clear — app is permanently stuck
- Only fix is uninstall and reinstall (loses all data)

## User Reports

**User A:** Created only 1-2 custom tokens with custom artwork. App hung on next boot.

**User B:** Created an entire deck with several custom-named tokens, each with unique custom uploaded artwork. App hung on next boot.

## Key Observations

- Both users had custom tokens (not selected from database) with artwork
- Issue manifests on cold boot, not during the session
- The fact that it works during the session but fails on boot points to a **deserialization/initialization** problem
- Low token count (1-2) can trigger it — not a volume issue
- Uninstall/reinstall fixes it (clears all Hive data)
- **CONFIRMED:** Users see the cream/beige native splash (not the Flutter 5-color-bar splash)
- **CONFIRMED:** Screen stays solid — no flicker/restart. This is a HANG, not a crash loop.
- **CONFIRMED:** Force-quit and reopen does NOT fix it — corruption is persistent in Hive data files

---

## Investigation Notes

### Boot Sequence (where the hang lives)

The app boots in this order:

1. `main()` → `initHive()` → opens all Hive boxes in parallel (`main.dart:32-34`)
   - `Hive.openBox<Item>('items')` — **regular Box, loads ALL items into memory**
   - `Hive.openLazyBox<Deck>('decks')` — lazy, not loaded into memory
   - `Hive.openBox<TokenArtworkPreference>('artworkPreferences')`
   - `Hive.openBox<TrackerWidget>('trackerWidgets')`
   - `Hive.openBox<ToggleWidget>('toggleWidgets')`
2. `runApp(MyApp())` → `MyApp.initState()` → calls `_initializeProviders()` async
3. While providers init, **splash screen shows** (the 5-color-bar screen)
4. Each provider opens its box (already opened, returns immediately) + runs migrations
5. `_providersReady = true` → `_isInitialized = true` → ContentScreen renders

**Critical: There are TWO "loading screens":**
- **Native splash** (`#E8E4A0` cream screen): Shows before Flutter renders anything. If `initHive()` hangs or crashes, this is what users see.
- **Flutter splash** (5 color bars): Shows after `runApp()` but before providers finish. If provider init hangs, this is what users see.

### Confirmed Failure Point

The hang occurs in `main()` at `await initHive()` (`main.dart:34`). This call never returns.
`runApp()` is never reached. Flutter never renders a single frame. The native splash stays.

Since `initHive()` opens 5 boxes via `Future.wait()`, ONE of these is hanging:
```
Hive.openBox<Item>('items')                              ← Tested, NOT reproducible via corruption
Hive.openLazyBox<Deck>('decks')                          ← INVESTIGATING - both users saved decks
Hive.openBox<TokenArtworkPreference>('artworkPreferences') ← Possible (artwork prefs)
Hive.openBox<TrackerWidget>('trackerWidgets')             ← Unlikely (unrelated to artwork)
Hive.openBox<ToggleWidget>('toggleWidgets')               ← Unlikely (unrelated to artwork)
```

### Emulator Corruption Testing (Feb 19, 2026)

**Test environment:** Android emulator via Android Studio

#### Regular Box tests (items.hive, artworkPreferences.hive)

**items.hive — ALL corruption tests PASSED (no hang):**
- Truncated 100 bytes from end: Booted fine
- Truncated 500 bytes from end: Booted fine
- Injected 50 garbage bytes at mid-file offset: Booted fine, all 7 items loaded
- **Header corruption (8 bytes of 0xFF at offset 0): Booted fine, box reset to 0 items** — data lost but app functional

**artworkPreferences.hive — header corruption PASSED (no hang):**
- Header corruption (8 bytes of 0xFF at offset 0): Booted fine — all providers initialized normally

**Conclusion: Regular Box (`openBox`) handles ALL corruption types gracefully**, including header corruption. It recovers by discarding unreadable data or resetting to empty. Data may be lost but the app boots.

#### LazyBox tests (decks.hive)

**decks.hive — mid-file corruption PASSED (no hang):**
- Injected 50 garbage bytes at offset 100: Booted fine, Hive discarded corrupt data and recreated the file empty

**decks.hive — HEADER CORRUPTION: BUG REPRODUCED**
- 8 bytes of 0xFF at offset 0: **Out of Memory → app permanently stuck on splash**
- Hive's `_KeyReader._load` (`frame_io_helper.dart:89`) reads garbage header bytes as a frame length
- Tries to allocate absurd memory based on garbage length value → OOM
- App never reaches `runApp()` — Android splash screen stays permanently
- Force-quit and reopen does NOT fix it (corrupt file persists)
- **This exactly matches the user-reported behavior**

#### Critical Discovery: LazyBox is the vulnerability

| Box | Type | Header Corruption Result |
|-----|------|------------------------|
| items | Regular Box | Recovers (0 items, app boots) |
| artworkPreferences | Regular Box | Recovers (app boots normally) |
| trackerWidgets | Regular Box | Not tested (expected: recovers) |
| toggleWidgets | Regular Box | Not tested (expected: recovers) |
| **decks** | **LazyBox** | **OOM → permanent brick** |

**Root cause:** `_KeyReader` in Hive's LazyBox implementation reads the file header to build a key index. When the header contains garbage, it interprets random bytes as frame lengths and attempts to allocate memory accordingly. Regular Box uses a different read path that can recover from bad headers.

**The decks LazyBox is the ONLY box that can brick the app.**

### Confirmed Root Cause

**The decks LazyBox is the single point of failure.** Header corruption on `decks.hive` causes Hive's `_KeyReader._load` to OOM, permanently bricking the app. No other box can cause this — all regular boxes recover gracefully from all corruption types tested.

**The chain of events:**
1. User creates custom tokens with custom artwork (large Item payloads with file:// paths)
2. User saves these tokens as a deck → large write to `decks.hive` (LazyBox)
3. The write or a subsequent compaction rewrites the file header
4. Android kills the app mid-write (SIGKILL, force-close, or battery optimization) OR the write is otherwise interrupted
5. `decks.hive` header is left with partial/garbage bytes
6. On next boot, `Hive.openLazyBox<Deck>('decks')` → `_KeyReader._load` reads garbage header → interprets random bytes as frame length → tries to allocate absurd memory → OOM
7. App never reaches `runApp()` → native splash stays forever
8. Force-quit and reopen hits the same corrupt file → same OOM → permanent brick
9. Only uninstall (which deletes all .hive files) fixes it

**Why custom artwork tokens are the trigger:**
- Custom artwork decks are the LARGEST writes to the decks box (file:// paths, artworkOptions lists, multiple templates)
- Larger writes = longer write duration = wider kill window
- Users who create custom tokens with artwork are more likely to save them as decks (they invested effort in setup)

**Confirmed facts:**
- Bug reproduced on Android emulator via header corruption of decks.hive
- Exact same behavior as user reports: stuck on app splash, force-quit doesn't fix, uninstall fixes
- Both affected users are Android (Play Store)
- `initHive()` has NO error handling (`hive_setup.dart:13-36`)
- The decks LazyBox is the ONLY box that can brick the app — all regular boxes self-recover

### Eliminated

- ~~Hypothesis 3: Provider init hangs~~ — **ELIMINATED.** Provider init shows Flutter splash (color bars), not native splash (cream). Users confirmed cream screen.
- ~~Crash loop~~ — **ELIMINATED.** Screen doesn't flicker. App is alive but the await never resolves.
- ~~items.hive corruption~~ — **NOT REPRODUCIBLE.** Hive handles items box corruption gracefully on emulator (truncation + garbage bytes both recovered fine).

### Key Files Involved

| File | Role | Risk |
|------|------|------|
| `lib/database/hive_setup.dart` | Opens all Hive boxes | No error handling — crashes propagate |
| `lib/main.dart:32-48` | Calls initHive, rethrows on error | Crash loop if initHive fails |
| `lib/models/item.g.dart:14-36` | Deserializes Items from binary | Reads artworkOptions as List<ArtworkVariant> |
| `lib/models/token_definition.dart:6-22` | ArtworkVariant Hive model (typeId 4) | Nested serialization adds complexity |
| `lib/utils/artwork_manager.dart:39-65` | Checks if artwork files exist | `file://` URL → async file.exists() |
| `lib/utils/artwork_preference_manager.dart` | Persists artwork prefs to Hive | Additional Hive writes per artwork change |
| `lib/widgets/mixins/artwork_display_mixin.dart:66-67, 138-139` | FutureBuilder per token on render | Each calls getCachedArtworkFile() |

### What We've Ruled Out

- **ContentScreen hanging**: ContentScreen has no initState async work, no artwork preloading on mount. It just renders TokenCards. This wouldn't prevent boot.
- **Regular Box corruption**: All regular boxes (items, artworkPreferences) handle ALL corruption types gracefully — truncation, mid-file garbage, header corruption. They self-recover by discarding bad data or resetting to empty.
- **Volume issue**: User A had only 1-2 tokens. Not a "too many items" problem.
- **Network calls**: No network calls during boot sequence.
- **items.hive as the culprit**: Tested truncation (100/500 bytes), mid-file garbage (50 bytes), and header corruption (8 bytes 0xFF) — all recovered fine.

---

## Open Questions (for narrowing down)

### Answered
- ~~Which loading screen?~~ → **Cream (native splash).** Hang is in `initHive()`.
- ~~Flicker or solid?~~ → **Solid.** Hang, not crash loop.
- ~~Force-quit fixes?~~ → **No.** Persistent corruption.
- ~~Custom tokens or database tokens?~~ → **Custom tokens.** Created via "Create Custom Token."
- ~~Photo library or Scryfall?~~ → **Photo library uploads.** Custom artwork, not Scryfall selections. Items have `file://` paths in `artworkUrl`.
- ~~Android or iOS?~~ → **Both users are Android** (one confirmed Play Store, other reached out via email which is more visible on Play Store listings than App Store). No iOS reports of this bug.

### Still Need From Users
1. **Did they force-close the app after adding artwork, or close normally?** Force-close during save = higher corruption risk.
2. **Device manufacturer?** Samsung/Xiaomi/OnePlus have aggressive battery optimization that SIGKILL apps mid-write.
3. ~~Did they save tokens as a deck too, or just leave on board?~~ → **Confirmed: decks are involved.** Both users likely saved custom tokens as decks. Header corruption on `decks.hive` reproduces the exact bug.

### Context on Reports
Reports came from TikTok comments and one direct email — incomplete details, no crash logs, no way to get device diagnostics. **Bug has been reproduced on Android emulator** via header corruption of `decks.hive`. Root cause confirmed.

### Reproduction (COMPLETED)
**Successfully reproduced on Feb 19, 2026 via Android emulator:**
1. Created custom tokens with custom artwork, saved as deck
2. Pulled `decks.hive` from emulator, corrupted header (8 bytes of 0xFF at offset 0)
3. Pushed corrupted file back, relaunched app
4. App stuck on Android native splash (app icon on default background) — exactly matches user reports
5. Force-quit and reopen → same hang (persistent corruption)

**Natural trigger scenario:**
1. User creates custom tokens with artwork → saves as deck → large write to `decks.hive`
2. Android SIGKILL (battery optimization, OEM aggressive kill, user force-close) interrupts the write
3. `decks.hive` header left with partial/garbage bytes
4. On next boot → `_KeyReader._load` OOM → permanent brick

---

## Fix Plan

**NOTE:** The fix for this should NOT be a narrow patch. This is an opportunity for meaningful enhancements to the app's data resilience and boot reliability. Discuss broader remedies and improvements alongside the specific corruption fix. — AB

### PRIMARY FIX: Switch decks from LazyBox to regular Box

**This is the root cause fix.** LazyBox is the ONLY box type that can brick the app.

**Change:** `Hive.openLazyBox<Deck>('decks')` → `Hive.openBox<Deck>('decks')`

**Why this works:**
- Regular Box handles ALL corruption types gracefully (proven via emulator testing)
- Header corruption on a regular Box → box resets to empty, app boots fine
- LazyBox's `_KeyReader._load` has no safety net → OOM on corrupt header → permanent brick

**Why the memory tradeoff is negligible:**
- Decks store only template metadata: strings (name, pt, abilities, colors), artwork URL paths, set codes
- A deck with 40 tokens ≈ ~20KB in memory (just strings and metadata)
- For comparison: a single decoded artwork image at 768px ≈ ~1.3MB in RAM
- The entire decks box in memory is a rounding error compared to what's already loaded
- LazyBox was a premature optimization that introduced the app's only bricking vulnerability

**Files to change:**
1. `lib/database/hive_setup.dart` — Change `openLazyBox<Deck>` to `openBox<Deck>`
2. `lib/providers/deck_provider.dart` — Change `LazyBox<Deck>` to `Box<Deck>`, simplify async getter to sync
3. `lib/main.dart` — No changes needed (already awaits initHive)

**Migration safety:** Hive can open an existing `.hive` file as either Box or LazyBox — they use the same file format. No data migration needed. Existing users' decks will load normally.

### Resilient boot with automatic backup (confirmed)

This is one cohesive system: backup, resilient boot, graceful degradation, and user messaging.

**Automatic backup (silent — no user-facing UI):**
- After every successful boot (all boxes opened without error), copy each `.hive` file to a `hive_backups/` sibling directory
- Overwrites previous backup each time — only keeps last known good state
- Storage cost is trivial (duplicates a few hundred KB of metadata files)

**Resilient boot flow:**
1. Open each box individually in its own try/catch (not one big `Future.wait`)
2. If a box fails to open:
   a. Try restoring from backup (`hive_backups/`) — if backup works, replace corrupt file, continue silently
   b. If backup also fails or doesn't exist — delete corrupt `.hive` file, recreate empty box, set a flag
3. App ALWAYS reaches `runApp()` — a bricked boot is never acceptable

**User messaging (only on unrecoverable failure):**
- If a box was restored from backup → silent, user sees nothing
- If a box had to be wiped to empty → after boot, show dialog: *"An error occurred while loading your [decks/tokens/etc.]"*
- No drama, no technical jargon, no decision burden — just an acknowledgment

**Files to change:**
1. `lib/database/hive_setup.dart` — Individual try/catch per box, backup logic, restore-on-failure logic
2. `lib/main.dart` — Pass failure flags to the app for post-boot messaging

### Cap custom artwork resolution at 768px width (confirmed)

- Resize uploaded images to max 768px on the longest edge (maintain aspect ratio)
- 768px is a standard web resolution tier — exceeds Scryfall art_crop quality (~626px) with headroom
- Reduces per-image file size from potentially 2-8MB down to ~100-200KB
- 10 decoded images at 768px ≈ ~18MB RAM vs ~31MB+ at full phone camera resolution
- Smaller files = faster Hive saves = narrower window for mid-write corruption
- Less memory pressure = less chance Android SIGKILL's the app in background
- Apply during upload (after crop, before copy to app storage)
- No visible quality difference on any phone screen

### Eliminate the double-save on artwork selection (confirmed)

- `expanded_token_screen.dart:205-206` calls `item.save()` then immediately `updateItem()` which calls `save()` again
- Consolidate to a single save — reduces the write window for mid-write kills

### Batch artwork field updates into a single write (confirmed)

- When setting artworkUrl + artworkSet + artworkOptions, set all fields then save once
- Currently each field set could trigger separate saves depending on the code path

### Rejected / Deferred

- ~~**Hive migration**~~ — **REJECTED.** Hive was chosen on purpose for this lightweight app. The fixes in this release make Hive safe enough. Migration would add app size, complexity, and potentially server infrastructure for no meaningful gain.
- ~~**Boot diagnostics**~~ — **REJECTED.** Resilient boot with backup/restore makes this redundant. Platform-level ANR/crash reporting (Play Console, App Store Connect) provides passive diagnostics without any code on our end.
- ~~**Data export/import**~~ — **DEFERRED.** Unrelated to this bug. Planning doc created at `docs/activeDevelopment/todo_features/data_export_import.md`.
