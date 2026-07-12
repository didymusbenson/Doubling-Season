# Remote Token Database Updates

## Problem

Every token database update requires a full app release cycle (build, TestFlight, App Store review). Users stay on stale data until they update the app. New Magic sets release tokens that users can't search for until the next app version ships.

## Solution

Publish the token database to a static remote URL. The app checks for newer versions and downloads updates on demand — no app update required.

## Architecture

### What stays the same

- `assets/token_database.json` remains bundled as the offline fallback
- `TokenDefinition` model, composite ID format, JSON schema — all unchanged
- Custom tokens in Hive `customTokens` box — completely independent, unaffected
- Favorites and recents stored by composite ID — still resolve correctly after DB update

### Remote hosting

Host two files at a stable URL (GitHub raw, GitHub Pages, or a CDN):

1. **`manifest.json`** (~100 bytes) — checked frequently, cheap to fetch
```json
{
  "version": 14,
  "sha256": "a1b2c3...",
  "size": 920000,
  "updated": "2026-03-25",
  "min_app_version": "1.9.0"
}
```

2. **`token_database.json`** (~900KB) — only downloaded when version changes

`version` is a monotonically increasing integer. Simple to compare, no semver complexity for a data file.

`min_app_version` is optional future-proofing: if a schema change ever requires a newer app version, older apps can skip that update and show a message.

`sha256` validates download integrity using the existing `crypto` package.

### Local storage

```
<app documents dir>/
  token_db/
    token_database.json    ← downloaded override
    manifest.json          ← cached manifest (version + sha)
```

Use `path_provider` (already a dependency) to get the documents directory.

### Loading priority in TokenDatabase

```
1. Local override file (downloaded from remote)  →  if exists and valid
2. Bundled asset (assets/token_database.json)     →  always available fallback
```

### SharedPreferences keys

| Key | Type | Purpose |
|-----|------|---------|
| `tokenDbVersion` | int | Version of the currently active database (bundled = 0) |
| `tokenDbLastCheck` | String (ISO8601) | When we last checked the manifest |

## Changes by file

### `lib/database/token_database.dart`

**Modify `loadTokens()`** to check for a local override file before falling back to bundled asset:

```dart
Future<void> loadTokens() async {
  _isLoading = true;
  _loadError = null;
  notifyListeners();

  try {
    String jsonString;

    // Try local override first
    final overrideFile = await _getOverrideFile();
    if (overrideFile != null && await overrideFile.exists()) {
      jsonString = await overrideFile.readAsString();
    } else {
      // Fallback to bundled asset
      jsonString = await rootBundle.loadString(AssetPaths.tokenDatabase);
    }

    _allTokens = await compute(_parseTokens, jsonString);
    _buildReverseLookup();
    _isLoading = false;
    notifyListeners();
  } catch (e) {
    // If override file is corrupt, delete it and retry with bundled
    await _deleteOverrideFile();
    // ... load from bundled asset as recovery
  }
}
```

This is the critical change. Everything downstream (search, filtering, favorites, recents) works identically — it all operates on `_allTokens` regardless of source.

### New: `lib/services/token_update_service.dart`

Standalone service, no provider needed. Stateless check-and-download logic.

```dart
class TokenUpdateService {
  /// Check remote manifest, return true if update available.
  static Future<TokenUpdateResult> checkForUpdate() async { ... }

  /// Download new database, validate sha256, write to local storage.
  static Future<bool> downloadUpdate(String url, String expectedSha) async { ... }

  /// Delete local override (revert to bundled).
  static Future<void> revertToBundled() async { ... }
}
```

**checkForUpdate():**
1. HTTP GET the manifest URL
2. Compare `manifest.version` vs `SharedPreferences.tokenDbVersion`
3. Return result object: `{available: bool, remoteVersion: int, currentVersion: int, size: int}`

**downloadUpdate():**
1. HTTP GET the database URL
2. Compute SHA256 of response body (using `crypto` package)
3. Compare against manifest's `sha256` — reject on mismatch
4. Write to local `token_db/token_database.json`
5. Write manifest to local `token_db/manifest.json`
6. Update `SharedPreferences.tokenDbVersion`
7. Return success/failure

### `lib/screens/about_screen.dart`

Add a "Token Database" card to the Storage section:

```
┌─────────────────────────────────────┐
│  Token Database                     │
│                                     │
│  Version: 14 (Updated Mar 2026)     │
│  Tokens: 913                        │
│                                     │
│  [  Check for Updates  ]            │
│                                     │
│  States:                            │
│  - "Up to date" (green check)       │
│  - "Update available (v15)" → tap   │
│  - "Checking..." (spinner)          │
│  - "Downloading..." (progress)      │
│  - "No internet" (grey, retry)      │
│                                     │
│  [Reset to Built-in Database]       │
│  (only shown if override exists)    │
└─────────────────────────────────────┘
```

### `lib/providers/settings_provider.dart`

Add two new SharedPreferences keys:
- `tokenDbVersion` (int, default 0 for bundled)
- `tokenDbLastCheck` (String, ISO8601 datetime)

### `lib/utils/constants.dart`

Add remote URL constants:
```dart
static const String tokenDbManifestUrl = 'https://...manifest.json';
static const String tokenDbBaseUrl = 'https://...';
```

## Update triggers

### Manual (v1 — implement first)
- "Check for Updates" button on About screen
- User taps → fetch manifest → show result → download if available

### Auto-check on launch (v2 — add later)
- On app start, if last check was >24h ago, silently fetch manifest in background
- If update available, show subtle indicator (badge on About, or snackbar)
- Never auto-download — always let user confirm (data usage respect)

## Publishing workflow (developer side)

1. Run `python3 docs/housekeeping/process_tokens_mtgjson.py` to regenerate `assets/token_database.json`
2. Compute SHA256: `shasum -a 256 assets/token_database.json`
3. Bump version in `manifest.json`
4. Upload both files to hosting location
5. (Future: script this into a `/publish-tokens` slash command)

## Error handling

| Scenario | Behavior |
|----------|----------|
| No internet | Show "Unable to check" message, app works fine with current data |
| Manifest fetch fails | Same as no internet — silent failure, current data unaffected |
| Download fails mid-transfer | Don't write partial file. Keep current data. Show retry option |
| SHA256 mismatch | Reject download, show error, keep current data |
| Downloaded file is corrupt JSON | Delete override file, fall back to bundled, show error |
| `min_app_version` too new | Show "Update the app to get the latest tokens" message |

## Hosting decision

**Recommendation: GitHub Pages from a dedicated branch or repo.**

Pros:
- Free, reliable, global CDN via GitHub's infrastructure
- Version history via git commits
- No server to maintain
- Easy to update (just push files)
- Raw URLs are stable

Alternative: GitHub Release assets on the main repo. Also free, slightly more ceremony per update.

## What this does NOT change

- Token JSON schema — identical format
- `TokenDefinition` model — no changes
- Composite ID format — unchanged (favorites/recents keep working)
- Custom tokens — stored in Hive, completely independent
- Python generation script — still runs locally, just also publishes output
- Bundled asset — still ships with app, still the fallback
- Artwork caching — separate system, unrelated

## Estimated scope

- `token_database.dart` — ~30 lines modified (load priority logic)
- `token_update_service.dart` — ~100 lines new (check + download + validate)
- `about_screen.dart` — ~80 lines new (update UI card)
- `settings_provider.dart` — ~10 lines new (two SharedPreferences keys)
- `constants.dart` — ~3 lines new (URL constants)
- Hosting setup — one-time, outside the app

No model changes. No Hive migrations. No breaking changes. Fully backwards compatible — if the remote never existed, the app behaves exactly as it does today.

---

## Implementation Summary (2026-06-13)

### Hosting decision: skipped CDN, point at the main branch

Every commit to `main` becomes the published snapshot. No separate hosting infra, no GitHub Pages branch, no manual upload step — the regen-tokens commit IS the publish event. URLs:

- Manifest: `https://raw.githubusercontent.com/didymusbenson/Doubling-Season/main/assets/token_manifest.json`
- Database: `https://raw.githubusercontent.com/didymusbenson/Doubling-Season/main/assets/token_database.json`

Constants defined in a new `RemoteUrls` class in `lib/utils/constants.dart`. **If the branch needs to walk back to a different ref (e.g., a dedicated `tokens-stable` branch), `RemoteUrls._rawBase` is the single line to edit.**

### Files changed

**New files:**
- `assets/token_manifest.json` — bundled manifest, version 1, sha256 of the v940-token DB, `min_app_version: "1.9.0"`. Registered in `pubspec.yaml` alongside the database asset.
- `lib/services/token_update_service.dart` — stateless `checkForUpdate()` / `downloadUpdate()` / `revertToBundled()` / `hasOverride()`. Uses `http`, `crypto`, `path_provider`, `shared_preferences` (all pre-existing deps). All methods catch their own failures; never throw. `TokenUpdateResult` carries `available`, `currentVersion`, `remoteVersion`, `remoteSha256`, `remoteSize`, `remoteUpdatedDate`, `minAppVersion`, `error`.

**Modified:**
- `lib/database/token_database.dart` — `loadTokens()` now calls a new `_resolveActiveSource()` that reads the bundled manifest, checks for an override manifest in `<app-docs>/token_db/manifest.json`, and uses whichever version is higher. Corrupt overrides self-heal (deleted, falls back to bundled). After load, writes the active version to `prefs.tokenDbVersion` so the update service can compare cheaply.
- `lib/screens/about_screen.dart` — new "Token Database" Card placed just above Storage. Shows active version, updated date, token count. Single primary button toggles between **Check for Updates** → **Download Update** → **Up to date** / **No internet** / error. Spinner during in-flight network. Secondary **Reset to Built-in Database** button appears only when an override is present, behind a confirm dialog.
- `lib/providers/settings_provider.dart` — added `tokenDbVersion` (int, default 0) and `tokenDbLastCheck` (DateTime? from ISO8601 string) getter/setter pairs.
- `lib/utils/constants.dart` — added `PreferenceKeys.tokenDbVersion` and `tokenDbLastCheck`; added `AssetPaths.tokenManifest`; added the new `RemoteUrls` class.
- `pubspec.yaml` — registered `assets/token_manifest.json` as a bundled asset.
- `docs/housekeeping/process_tokens_mtgjson.py` — new `update_manifest()` step in `main()`. Reads the existing manifest (preserves `min_app_version`), increments `version` by 1, recomputes `sha256` / `size` from the freshly-written DB, sets `updated` to today's UTC date. Auto-runs on every regen. **Publishing workflow is now: `python3 docs/housekeeping/process_tokens_mtgjson.py` → commit → push to `main`. That's it.**

### Behavior differences from the original spec

- **No separate hosting / GitHub Pages.** Branch-pointer simplification per product owner.
- **Override-vs-bundled priority is version-aware**, not "override always wins." If the user installs an app update whose bundled DB is newer than their downloaded override, the bundled wins and the now-stale override is deleted on next load. Prevents the case where a user is stuck on an obsolete remote snapshot after upgrading the app.
- **No in-process broadcast after download.** Each call site that needs the token DB instantiates a fresh `TokenDatabase()` and calls `loadTokens()` (existing pattern across the codebase — there's no singleton). Snackbar after a successful download tells the user to restart the token search screen so the new data is parsed. If a singleton or notifier broadcast is later desired, that's a separate refactor not gated on this feature.
- **Auto-check on launch (spec v2)** intentionally not implemented in this pass — keeping to v1 manual-trigger scope.

### Edge cases handled

| Scenario | Behavior | Tested via |
|----------|----------|------------|
| No internet | "No internet connection" status banner; current data unchanged | `SocketException` catch in `checkForUpdate` |
| Manifest fetch returns non-200 | "Server returned NNN" status banner; current data unchanged | status-code check |
| Download fails / interrupts | Returns false from `downloadUpdate`; no partial files written (DB written with `flush: true` BEFORE manifest is written; if DB write fails, manifest is never touched) | exception bubbles into `catch`, snackbar shows generic "Update failed" |
| SHA256 mismatch | `downloadUpdate` returns false BEFORE writing anything; current data unchanged | `if (actualSha != expectedSha256) return false` |
| Override JSON corrupt at load | `_resolveActiveSource` catches the decode error, deletes both override files, falls back to bundled | corrupt-fallback path in `loadTokens` |
| Override exists but DB file missing | Detected in `_resolveActiveSource`; both override files deleted, bundled used | `await overrideDbFile.exists()` check |
| `min_app_version` from manifest exceeds running app | **Not yet gated** — TODO note: `TokenUpdateResult.minAppVersion` is parsed and surfaced but `available` is currently true regardless. If a schema bump ever requires this gate, add an `AppVersionCheck.satisfies(minAppVersion)` comparison in `checkForUpdate`. |
| App downgrade puts stored `tokenDbVersion` higher than bundled version | Bundled loses to override; override stays in use. No harm — when next remote update lands, comparison still works. |

### Walk-back instructions

If you need to disable the remote feature entirely:

1. In `about_screen.dart`'s `build()`, comment out the `_buildTokenDatabaseCard()` line.
2. In `token_database.dart`'s `loadTokens()`, replace the `_resolveActiveSource()` call with `final jsonString = await rootBundle.loadString(AssetPaths.tokenDatabase);` and the prefs write with nothing. The override-file path becomes dead code but harmless.
3. Existing overrides on user devices stay on disk until manually cleared (low priority — they're small).

If you need a different branch / mirror:
- Edit `RemoteUrls._rawBase` in `lib/utils/constants.dart`.

### Open items to validate before ship

- [ ] Tap "Check for Updates" with no override and current bundle → "Up to date" banner.
- [ ] Simulate a remote bump (e.g., temporarily edit `assets/token_manifest.json` to `version: 2`, push to a test branch, point `_rawBase` at it) → "Update available (v2)" banner → "Download Update" → "Restart token search" snackbar → next token search shows new tokens.
- [ ] SHA mismatch path: deliberately wrong-sha the test manifest → "Update failed" snackbar, no override written.
- [ ] Reset to Built-in: confirms, deletes override, snackbar, card re-renders without the secondary button.
- [ ] Airplane mode: "No internet connection" banner; no crash; subsequent online check works.

---

## ⚠️ Version watermark: the next real release must bump past the last staging test

**Detection is one-directional: it only fires when the remote `version` is strictly greater than the version a device has already stored** (`tokenDbVersion` in SharedPreferences). Reverting the manifest to a *lower* number does NOT re-arm those devices.

This bites when staging tests bump the manifest and then revert it:

- During launch-modal testing (July 2026) the manifest on `main` was bumped to **v3**, then **v4**, each time reverted back to **v2**.
- Any device that checked during those windows stored `tokenDbVersion = 3` or `4`.
- `main` is now back at **v2**. The Python regen (`process_tokens_mtgjson.py`) auto-increments from the committed manifest, so the next real refresh produces **v3** — which those test devices will silently ignore (`3 > 4` is false).

**Before the next real token-database release, set the manifest `version` higher than the highest number ever pushed during testing (currently 4).** Practically:

1. Run `python3 docs/housekeeping/process_tokens_mtgjson.py` as usual (it bumps v2 → v3).
2. **Manually edit `assets/token_manifest.json` to set `version` to `5`** (or higher) before committing — leave `sha256`/`size`/`updated` as the script wrote them.
3. Commit + push to `main`.

Alternatively, reinstall the app on any device used for staging tests (a fresh install resets `tokenDbVersion` to the bundled value).

> Rule of thumb: whenever you push a staging version bump to `main` for testing, note the highest number you used, and make sure the next production manifest clears it.
