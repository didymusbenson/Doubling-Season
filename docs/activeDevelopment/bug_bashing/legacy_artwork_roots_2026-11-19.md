# Legacy artwork relocation in copied-source acquisition

Scope: feature-branch update-safety prerequisite only. No production startup
cutover, migration release, device installation, default-branch merge or OTA
publication. Based on saved-deck parity checkpoint `4e0c0a4`.

## Confirmed source behavior

- `ArtworkManager.getCustomUploadsDirectory` uses Documents/custom_artwork.
- `ArtworkManager.getArtworkCacheDirectory` uses Application Support/artwork_cache.
- `DeckProvider.duplicateDeck` copies user cover art to `deck_box_<key>.png` in
  that support cache and persists its absolute `file://` URL.
- Existing `LegacySourceReader` acquired an already quiescent copy and required
  callers to enumerate every exact reference in `mediaPaths`. It never followed
  original paths, which must remain true after a native container move.

## Narrow addition

`LegacySourceLayout.mediaRoots` optionally declares caller-verified old artwork
root directories and their corresponding relative directories in the retained
copy. It is immutable and recorded in the capture inventory. Empty roots keep
existing inventory serialization unchanged. No guessed container prefixes,
basename search, filesystem probing or old path reads are introduced.

The reader resolves only known artwork-reference fields from the decoded
snapshot, after durable retention and verification. Candidate files must already
exist in that retained inventory. Missing/untrusted paths remain unresolved so
the journal reports them. Explicit reference/root mapping conflicts fail closed.
Existing source-copy symlink rejection and inventory bounds remain in force.

## Validation and limits

Tests cover token and duplicate-cover relocation, encoded spaces, retained-source
reopen and journal preparation/commit, unchanged source hashes, and unsafe or
missing references. This is a synthetic fixture serialized with current adapters,
not a claim of compatibility with a verified store-shipped build.

Production still needs verified shipped schema/build fixtures, platform discovery
of both storage roots and preferences, quiescent capture before any Hive repair
or blank Table initialization, startup gate integration, and backed-up native
upgrade/restore acceptance. This change deliberately does not enable cutover.

Test results and push status are recorded in the task handoff.

The existing journal rejects zero-byte or over-12 MiB artwork before staging.
Discovery of such an upload is deliberately not converted into silent loss:
its source bytes are retained and the rehearsal fails closed. A release needs
an explicit user-facing recovery policy for these existing media limits.

## Checkpoint validation

- Official Flutter 3.41.2 / Dart 3.11.0, SDK SHA256 verified.
- Offline dependency resolution with unchanged lockfiles and verified official
  pub.dev archive hashes.
- Focused reader/media-root suite: 47 passed.
- Full tablet analysis: no issues.
- Aggregate tablet and preview-namespace validation pending at this checkpoint.
- Independent review found no path escape or source overwrite; redundant
  indexing was removed and the existing oversized-media limit documented.
