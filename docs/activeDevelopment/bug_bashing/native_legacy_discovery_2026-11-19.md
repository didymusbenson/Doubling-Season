# Native legacy discovery checkpoint (2026-11-19)

## Scope

Base: `7eab4883b7d2b72735d1426494ecafe0323efd14`.
Feature branch: `feat/native-legacy-discovery-20261119`.

Implemented a real, read-only Dart filesystem inventory of caller-supplied,
OS-verified native roots. It is a building block, **not production acquisition,
a migration, or a fresh-install decision**. Neither main entry point changed.
No Hive/SharedPreferences handles, adapters, repair, archive writes, or Table
initialization occur. No PR, merge, deployment, or device install is included.

`NativeLegacyDiscovery.inspectResolvedRoots` recognizes the expected iOS and
Android directory relationship, reads/hashes the entire Documents/app_flutter
subtree, Application Support/files artwork_cache subtree, and the exact native
preference domain with its sidecars. It inventories unknown files, backups,
compaction remnants, empty directories and unreferenced artwork rather than
silently excluding evidence. Limits: 4096 files and directories each, 64 MiB per
file, 256 MiB total. Streaming hashes avoid allocating entire artwork files.

Two inventories must match. Static symlinks, unexpected entity types, inaccessible
entries, missing roots, unsafe names and size limits fail closed. This is not a
race-proof filesystem API: a caller must keep roots stable; path-based Dart
stat/list/open cannot exclude a concurrent malicious link replacement.

## Result semantics (intentionally conservative)

- `noEvidence`: no files or legacy subdirectories observed in these exact roots.
  **Not permission to initialize blank state.** The native startup owner still
  must establish the correct app identity, authoritative preference domain and
  quiescence. Missing/unreadable root is an error, not this result.
- `candidate`: seven expected primary file paths and the preference domain
  exist, without the structural blockers below. **Not decoded or validated.**
  Corrupt bytes can be a candidate; retention and strict reader decoding remain
  mandatory before any migration. No API in this class activates anything.
- `blocked`: evidence exists but primary files/preferences are missing, an
  unknown Hive store exists, a compaction file exists, or preference recovery
  sidecars exist. Older installations with intentionally absent later boxes are
  conservatively blocked until an exact shipped schema policy establishes that
  absence, rather than inventing empty stores.

Hash inventory is not a raw backup. Originals remain untouched, but they must
still be durably retained before decoding/repair elsewhere. Pending contents of
boardorderoperations are not decoded here; the existing retained-source reader
blocks a pending order operation. A discovery candidate is not that reader's
approval.

## Verified storage/startup evidence

Evidence is current repo code and exact pinned plugin source, **not certification
of a shipped binary/container**:

- `lib/database/hive_setup.dart`: `Hive.initFlutter()` without subdirectory uses
  application Documents. Seven primary stores: items, decks, artworkPreferences,
  trackerWidgets, toggleWidgets, tokenRules, customTokens. Hive lowercases actual
  primary filenames. Keep raw backup filenames as found, including mixed-case
  names written by the app's backup helper.
- `lib/services/board_order_persistence.dart`: boardorderoperations journal,
  pendingV1, opened/replayed after providers initialize.
- `lib/utils/artwork_manager.dart`: Documents/custom_artwork and Application
  Support/artwork_cache. Documents/token_db, .pending and .previous evidence is
  also inventoried, not discarded as unrelated.
- Pinned Android plugin: app_flutter (Documents), files (support), and
  shared_prefs/FlutterSharedPreferences.xml plus .bak recovery evidence.
- Pinned iOS plugin: Documents, Library/Application Support, and expected standard
  domain Library/Preferences/LooseTie.Doubling-Season.plist. Verify actual shipped
  identity/domain on a backed-up native installation before relying on absence.
- Root main calls initHive before UI. initHive can restore, delete corrupt boxes,
  and start asynchronous backups. Providers, order replay and maintenance can
  subsequently write. TableController.initialize can create its independent
  store and initial state. Future acquisition must precede both startup paths.

## Why no automatic capture/startup wiring

1. path_provider directory getters can create directories (Android Context.getDir,
   and support-directory creation). An initially attempted automatic root wrapper
   was removed: it cannot honestly provide inert-source discovery. Supply roots
   via a noncreating OS lookup in a native startup integration.
2. Two matching file reads are not cross-store quiescence. Verify old process
   termination and any other writers; iOS cfprefsd/UserDefaults durability needs
   an actual native strategy. Android preference backup recovery must not be
   silently performed or ignored.
3. No live root map is promoted to a trusted *old container* artwork map. That
   requires independent verified relocation evidence, not arbitrary stale URLs.
4. Native capture must retain all originals with capacity/error handling before
   any schema decode, and a durable startup gate must prevent repair/blank Table
   fallback when capture, decode, migration, or recovery fails.

These are specific blockers to claiming production-capable quiescent capture,
not reasons to add a partial or permissive startup hook.

## Validation

Flutter 3.41.2 / Dart 3.11.0, pinned offline dependencies, no lockfile edits:

- `flutter analyze --no-pub`: no issues (2.6 seconds).
- Focused discovery + retained reader + media roots: 66 passed (3 seconds).
- Migration/native/startup/preset compatibility aggregate: 779 passed, 3 skips
  (42 seconds).
- Same aggregate under `TABLE_STORAGE_NAMESPACE=phone_preview_v1`: 725 passed,
  57 intentional isolation skips (43 seconds).
- 19 new Android/iOS-layout synthetic filesystem tests. They cover real empty
  Hive file encodings, raw preference XML/plist, both artwork paths, order journal,
  backups, token data, partial/corrupt evidence, sidecars, static links, mismatched
  roots, unexpected entity types and oversize input. Existing reader aggregate
  covers serialized adapter/corruption decoding; discovery does not decode.
- Independent review: initial path lookup/sidecar issues fixed; final review found
  no remaining must-fix. Full unrelated UI suite and native build/device tests
  were not rerun for this dormant filesystem-only change.
- No automatic CI expected from a feature-branch push: tablet workflow is PR or
  workflow_dispatch. No PR or manual deployment/build workflow was requested.
