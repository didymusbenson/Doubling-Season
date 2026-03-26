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
