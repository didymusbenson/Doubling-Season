# Table save compatibility and recovery — 2026-11-10

Status: implemented on a feature branch. No production release, default-branch
merge, deployment, original-app cutover, or device installation is authorized by
this checkpoint. This is Table aggregate compatibility, not a change to the
original application's Hive type IDs, adapters, boxes, or signing identities.

## Confirmed risk

The 2–4-player repository at `fa9ed9c` and the 2–6-player writer introduced at
`038b432` both wrote envelope version 1 / state schema 1. The older validator
rejects a five/six-player active game or archive as ordinary corruption. Its
recovery path can therefore offer an older game and overwrite newer play on the
next save. An unchanged schema number was not a valid compatibility guarantee.

The historical reader already stopped for an unknown envelope or schema before
recovery. The new boundary uses that behavior rather than trying to downgrade or
truncate players, archives, or history.

## Implemented behavior

- Keep every physical storage name, including the `_v1` suffix. That suffix is
  the existing container identity, not a promise about all future payloads.
- New Table saves use envelope version 2 and state schema 2. The envelope change
  makes historical readers stop **before** checksumming/validating the payload,
  including when a recognizable version-2 envelope contains a damaged payload.
- Read known version-1/schema-1 saves with 2–6 players, including six-player
  archives inside a smaller active game. Preserve IDs, seats, tokens, utility
  metadata, history/inverses, archives, presets, extension maps and artwork
  references. Existing optional-field defaults still apply.
- Before allowing gameplay on a legacy save, preserve its exact encoded bytes
  in `before_format_2_<sha256-of-encoded-bytes>` in the existing previous box, or
  the writable aggregate when the previous box is unavailable. Flush and verify
  this checkpoint before promoting a version-2 generation. A failure stops
  startup; it is never reclassified as corruption or permission to load an older
  game. Retry inspects the retained checkpoint and resumes without duplication.
- Retained checkpoints are immutable/content-addressed. Normal saves still use
  the rolling previous generation, but never rotate/delete checkpoints. These
  checkpoints are **not** automatic fallback candidates: opening an old
  checkpoint silently after later gameplay would itself lose progress. If only
  retained records remain, startup stops for explicit recovery instead of
  initializing a blank table.
- Screen every live current/previous/recovery record before any retention or
  promotion writes. Unknown envelope/schema/typed fields, uninterpretable
  integrity-checked field shapes/semantics, and more than six players stop
  startup, even
  when the unsupported record has a lower sequence number. Arbitrary supported
  extension maps remain intact. Do not silently drop an unknown model field.
- Integrity failures and unreadable envelopes are retained byte-for-byte under a stable
  `quarantine_<sha256>` key before recovery can proceed. If retention fails,
  startup stops and the damaged record remains untouched. Unreadable containers
  are never deleted/recreated. Recovery can use another writable container.
- A failed open/reopen revokes the repository writer so callers cannot save a
  fresh/default/stale game after an unsupported-version error.

## Recovery and rollback policy

A supported rollback build must retain the format-2/schema-2 reader and the
2–6-player model. **Do not reinstall a historical 2–4-player binary as a recovery
procedure.** It will normally stop safely on the new format, but this code cannot
retrofit historical binaries if the primary envelope/container is missing or
wholly unreadable. Platform app downgrades may also be unavailable.

Before a deliberate recovery, preserve the entire Table storage directory (or
browser origin data) plus media/catalog/preferences, the current app version and
all retained records. Diagnose unsupported-version failures using a matching or
newer reader; do not clear storage, modify version numbers or try a fresh game.
Normal damaged-current recovery uses a validated complete generation and tells
the user that recovery occurred.

The immutable pre-upgrade checkpoint is a last-resort recovery input, not a
promise that later gameplay exists in the checkpoint. Restoring it must be an
explicit, reviewable choice identifying the loss of later changes. It should be
opened in an isolated copy with a compatibility-aware reader first. No automatic
checkpoint restore, export/restore UI, retention cleanup, or destructive repair
is added here. Those release/operator workflows remain acceptance gates.

If startup is interrupted before format-2 promotion, the original version-1
record remains readable by this branch, and the upgrade can resume. Continue
with this compatibility-aware build; no promise is made that a historical
2–4-player binary can safely consume a still-version-1 six-player record.

## Evidence and remaining gates

`test/table_repository_compatibility_test.dart` uses real isolated Hive files,
closes/reopens them, and injects loss at every upgrade write/flush boundary and
every ordinary save write/flush boundary. It reproduces the historical validator
hazard and covers all seat counts, archives/history/extension metadata, missing
legacy optional fields, old same-container backups, unavailable containers,
checkpoint retention through repeated saves, quarantine failure, unknown formats
in every live location, and failed-open writer revocation.

- Focused repository suite: 52 tests passed.
- Analyzer: passed with no issues. The initial aggregate run was stopped after
  stalling during concurrent compilation. The first release web compile was
  killed with exit -9 during that concurrent validation. Serial retries are
  pending. These results are not a release-readiness claim.
- Native upgrade/downgrade installs, actual hardware power loss, browser storage
  eviction/quota and IndexedDB restart behavior, old shipped binary fixtures,
  recovery tooling, media-file backup completeness, concurrent multiple app
  writers, and store release/rollback policy are not established by these tests.
  In-process failures followed by real Hive reopen are useful evidence, not an
  OS/filesystem durability guarantee or approval to release.
