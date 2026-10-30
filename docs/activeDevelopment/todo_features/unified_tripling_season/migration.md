# Safe migration from original TS to the unified product

**Status: DEFERRED / SPECULATIVE / NOT IMPLEMENTED.** See [scope](README.md).

## Outcome

An existing user installs an ordinary update to Tripling Season. Their saved
Deck configurations become TT presets/configurations; custom tokens, artwork,
credits and other durable value remain available. Their old active game is
replaced only through the [one-time fresh-board transition](fresh_board.md).
This is an installation migration, not a requirement to export/import manually.

## Source inventory and release gate

Before implementation, identify the latest *actually shipped* iOS and Android
versions and every older source version the update must support. Record adapters,
box names/type IDs, preference keys, file locations and representative fixtures.
Do not infer store releases from `pubspec.yaml`, a local development IPA or a
release-candidate document. Store/account/signing state has not been audited here.

Current code evidence (baseline `3d3723ec`):

| Area | Existing evidence | Implication |
|---|---|---|
| App identity | Root `ios/Runner.xcodeproj/project.pbxproj`, `android/app/build.gradle.kts` use `LooseTie.Doubling-Season` / `com.loosetie.doublingseason` | Preserve original identity and valid signing continuity; tablet IDs are a different installation. |
| Device support | Root iOS family 1 / target 13; tablet family 2 / target 15 | Universal support and minimum OS need explicit compatibility review. Tablet Android release currently uses debug signing, not a production-update configuration. |
| Legacy persistence | `lib/database/hive_setup.dart` can delete/recreate boxes after recovery failures | Schema mismatch must not enter this destructive fallback during migration. |
| Deck interchange | `lib/providers/deck_provider.dart` exports schema 3; tablet `PresetService` accepts legacy 1–3 | Useful mapping evidence, but not a complete migration pipeline. |
| Local art | Legacy `custom_artwork` and `artwork_cache/deck_box_*`; tablet content-addressed media | Copy bytes and remap ownership/references; a legacy file URL alone is not portable. |
| Supporter ownership | Root `lib/services/iap_service.dart` versus tablet `table_support_service.dart` | Preserve original product IDs, restore behavior and cosmetics, not just new tablet flags. |
| Catalog | Separate original and tablet stores, including tablet compatibility assumption `1.11.0` | Design one version/compatibility contract and preserve compatible data and credits. |

Original and tablet bootstraps initialize different storage arrangements. Do not
mount both whole applications and assume they share a coherent mutable store.
The destination needs one canonical authority with presentation-specific views.

## Required mapping inventory

For each category, record source fields, destination fields, ownership/scope,
identity strategy, validation and unsupported-field policy before coding.

- **Every saved deck:** name, ordering, token templates and custom identities,
  token art selections/options/credits, deck cover, utility configuration,
  style settings and other stored fields. Preserve duplicate names as separate
  decks; do not merge by display name or silently replace a custom definition
  with a catalog token. Retain source identifiers in a migration map.
- **Custom-token library:** definitions, colors, P/T including supported variable
  values, abilities, artwork and credits, with all deck references remapped.
- **Artwork:** copy local image bytes into destination-owned storage, verify
  hashes/readability, then remap references. Preserve full-art/fade selections.
  Missing local files or unreachable remote URLs must not delete the deck or
  erase its saved selection metadata. Define recoverable fallback presentation.
- **Legacy artworkPreferences:** inventory the durable global per-token art
  defaults separately from TT game/seat art preferences. Preserve them in the
  migrated library or recovery data pending a deliberate destination decision;
  do not silently apply them to every seat or every new game.
- **Preferences and reusable utility configurations:** map supported settings;
  distinguish a utility's configuration from its old live counter value.
- **Favorites/recents and durable identity:** retain where meaningful, documenting
  any intentional conversion instead of silently resetting them.
- **Supporters:** retain original `com.loosetie.doublingseason` product IDs and
  verified restoration/ownership semantics. Cached `purchased_*` and new
  `tablet_support_*` keys are not interchangeable proof of ownership.
- **Unsupported custom rules/features:** preserve recoverable source data and
  document unsupported status. Do not imply unfinished custom rules now work.
- **Active board:** snapshot for recovery, then use the deliberate fresh-game
  policy rather than accidentally importing or deleting it during deck mapping.

The existing deck JSON export omits the deck's `customArtworkUrl` cover and image
bytes. It also is not an export of all libraries/preferences/purchases. Exporting
all decks and feeding them to the current importer therefore does not meet this
specification. Tablet `TableArtwork` handles `tablet-art:`, image data and HTTP(S),
not arbitrary legacy `file://` rendering.

## Proposed migration transaction

1. Detect a supported source version without opening it through destructive
   recovery. Take a consistent, private copy of the legacy data and required art.
2. Check free space and snapshot integrity. If unavailable, retain the source and
   provide a recoverable path; never clear the board to make migration appear done.
3. Convert into an isolated destination generation using a versioned, resumable
   migration journal and stable ID mappings. Retrying must not duplicate decks.
4. Validate deck counts, references, definitions, image hashes, ownership and
   supported fields. Account explicitly for missing/unsupported inputs.
5. Reopen and validate the destination. Stage its fresh game and one-time reset
   marker as described in [fresh-board safety](fresh_board.md).
6. Commit the new generation atomically, or use an equivalent recoverable commit
   protocol across stores. Mark success only after the durable commit is verified.
7. Keep legacy recovery material according to an explicitly chosen retention
   policy. No automatic irreversible cleanup is specified here.

Tablet repository checksums, prior generations, quarantine and unknown-schema
refusal are useful patterns, not proof a migration framework already exists.
A failed conversion must not overwrite the good source or force an empty app.

## Acceptance scenarios before any release

- Real supported installed-version fixtures with many decks, duplicate names,
  custom tokens, uploaded art, covers, remote art and supporter entitlements.
- Upgrade without uninstall, then load each migrated preset on Seat 1 and another
  seat; verify configuration scope, art and credits, not merely JSON parse success.
- Interruption at every snapshot/convert/copy/commit/marker boundary; resume
  without duplicates, lost assets, repeated board clearing or partial authority.
- Unknown/newer schema, corrupt source, missing image, full disk, offline catalog
  and purchase restoration unavailable. Preserve recoverable data in each case.
- Launch again after a new game has progressed: migration must not rerun/reset it.
- Old OTA clients and new clients retain compatible manifests/payloads. This is
  a store-binary migration proposal, not executable-code delivery through data OTA.

Open: exact shipped-version support matrix, unsupported utility/rule conversions,
recovery retention, rollout/cohort strategy, minimum OS and consolidated catalog
contract. Rollback is a designed data strategy, not an assumed app-store downgrade.

## Development isolation and release cutover

**Owner clarification, 2026-10-30:** retain the separate Tripling Table/tablet
identity while building this direction. Preserve the existing original TS code
and installed application; separate identity is an intentional safety boundary.

- Ordinary prototypes and test builds retain tablet bundle/application IDs,
  storage namespaces and build configuration. Never change them merely because
  the planned destination is the original product.
- Migration experiments use copied/exported fixtures and isolated destination
  stores. A separate app cannot be assumed to read the original app's private
  sandbox; use explicit test-fixture acquisition rather than bypassing isolation.
- Keep original phone code and release behavior intact. Shared changes require
  regression evidence; focused-view work must not silently replace its startup.
- Later, create a controlled cutover candidate under the original TS identity,
  with original signing/entitlement continuity and an explicitly selected test
  installation. Test upgrade from the actual shipped binary without uninstalling,
  using verified recovery copies and the migration/fresh-board acceptance cases.
- Record the identity, source build, source data version and destination build for
  every test. Distinguish a fresh install, tablet-identity fixture conversion and
  a genuine original-identity update; only the latter proves the cutover path.
- Release remains gated on migration, purchase restoration, recovery, device
  support and tablet regression results. Store submission/public rollout and any
  original-install replacement are separate future actions, not authorized now.

The exact cutover branch/flavor arrangement, test cohort and rollback process
remain open. Do not let a development flag accidentally target production data.
