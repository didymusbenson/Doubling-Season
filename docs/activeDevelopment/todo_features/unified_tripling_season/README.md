# Unified Tripling Season — speculative future direction

**Status: DEFERRED / EXPLORATION / NOT IMPLEMENTED.** Updated 2026-10-30.
This records a future product direction, not the current development focus, a
release promise, or permission to migrate/reset anyone's installation now.

## Direction recorded from the owner

Explore shipping the Tripling Table experience as an update to the original
Tripling Season, retaining its existing installation and store identity instead
of requiring a separate app. Keep the new Table styles and aesthetic.

Phone view means **Seat 1 of an N-player game**, not a new one-player game type.
A four-player session remains four-player when only Seat 1 is visible. Its
life, counters and commander-damage relationships still belong to that session.
Screen size/posture changes presentation, never player count or game state.
The other seats remain intact and become visible in the full-table layout.

The owner requested three speculative documents:

1. [Safe installation and deck migration](migration.md): existing saved TS decks
   must become usable TT configurations without losing persistent content.
2. [One-time fresh-board transition](fresh_board.md): migrate persistent value,
   but deliberately start a clean game rather than carry the old active board.
3. [Focused Seat 1 phone experience](focused_seat.md): compact life above tokens,
   complete commander/counter controls, utilities and thumb-reachable actions.

## Feature-branch preview infrastructure

Phone implementation stays on a separate feature branch; main remains the stable
tablet delivery line. See [temporary Pages preview and mandatory cutover cleanup](preview_workflow.md)
for the custom publisher and isolated browser storage. Infrastructure setup does
not start the deferred phone UI.

## Existing implementation is not this proposal

As inspected at `3d3723ecbfbe4fb1c868e11433c5c359cd5e5877`, original and tablet
apps have separate entry points, identities, storage and purchase configuration.
The tablet engine supports 2–4 players; narrow windows currently receive a
more-room fallback. A focused Seat 1 presentation is not implemented. The
existing legacy deck importer is not a full-installation migration.

A true one-player engine is **not required by this proposal**. N means a
supported session size, not approval to expand beyond the existing 2–4 players.
The earlier [foldable concept](../../in_progress_features/ipad_edition/foldable_phone_future_version.md)
is consistent with preserving a full session while focusing one seat. Seat 1
is the specified phone target here; switching focused seats is not yet decided.

## Confirmed development identity and later cutover

Keep the separate **Tripling Table / tablet identity and storage** throughout
exploration, development and ordinary testing. Existing Tripling Season code and
installations must remain undisturbed; the apps continue to coexist. Do not
rebrand or repoint routine development builds to the original identifiers.

A distinct, deliberate cutover phase will later test this as a Tripling Season
release, using the original store identity and real upgrade/migration paths on
backed-up test installations. Success under the separate tablet identity does
not prove an in-place original-app update. The cutover is future work, not an
instruction to switch identifiers or migrate an installation now. See the
[migration cutover gates](migration.md#development-isolation-and-release-cutover).

## Boundaries and later decisions

- No runtime, schema, store, signing, OTA or release-version changes in this work.
- Do not automatically enable implementation because these documents exist.
- Verify the actual latest released versions on each store before designing the
  production migration. Repository version labels are not proof of shipment.
- Preserve original purchase ownership and restoration. This is not a request
  to charge existing supporters again or decide future pricing.
- Available window size, orientation and hinge/posture can select a presentation;
  hardware labels alone are insufficient. Tablet solo use and a user-selected
  compact view need consideration. No exact breakpoints are chosen yet.
- Compatibility with old devices, minimum OS versions, migration recovery,
  accessibility, rollout and feature parity are release gates, not solved facts.

## Working approach

Develop and checkpoint in the cloud by default. Commit and push meaningful
completed work and WIP before environment handoff. Use a Mac only when required
for native building/validation or explicitly requested; pull the verified remote
checkpoint there rather than treating the Mac as the default editing environment.
