# Unified Tripling Season: current direction and source contracts

**Updated 2026-11-10: migration/update safety work is active; release is held.**
Start with the [current implementation and acceptance matrix](../../in_progress_features/tripling_season_update_plan.md).
This directory keeps its historical path so existing links work. It is no longer
an all-speculative or phone-not-implemented proposal.

## Current direction

Develop the Table experience toward a future update to the original Tripling
Season, preserving its installation identity and durable user value. Continue
using the separate Tripling Table identity and isolated storage for development.
Do not switch identifiers, replace original installations, merge or publish as
part of the present safety milestone. The owner will continue feature work before
release.

At baseline `0273043` (`fix/tripling-card-corners-20261109`), `apps/tablet`
already has 2–6-player sessions, adaptive player-local token/utility views, and
fixed-Player-1 phone presentation. Phone view does not change the session count.
Native phone posture/device acceptance remains open; stable web full-table and
explicit phone-preview routing remain distinct.

## Contracts and evidence

- [Migration](migration.md): preserve saved decks, custom definitions, preferences,
  media and supporters; build non-destructive, resumable migration foundations.
- [First migrated board continuity](fresh_board.md): retain the live token board
  and enabled supported utilities. The earlier clear-board proposal is superseded.
- [Focused Player 1](focused_seat.md): approved option C, one scrolling body,
  compact life and complete hidden-session continuity.
- [Saved-configuration audit](preset_audit.md): concrete partial mappings and
  missing acceptance; JSON import alone is not installation migration.
- [Phone decision/history record](implementation_summary.md): historical branch
  checkpoints and independent choices, not current release certification.
- [Temporary preview and cutover cleanup](preview_workflow.md): distinct storage,
  combined publisher and later retirement requirements. No deployment now.

## Unchanged boundaries

Keep original source/providers/identifiers and existing Table storage keys intact.
Preserve original purchases and restoration; do not charge supporters again or
assume Table flags prove original ownership. Verify actually shipped iOS/Android
versions rather than treating repository version labels as store evidence.

Copied-fixture migration work is authorized. Production startup migration,
original-identity cutover, irreversible cleanup, distribution and release remain
later work. Deferred authoring/cosmetic/parity decisions are explicit in the
[current matrix](../../in_progress_features/tripling_season_update_plan.md#explicit-parity-choices-and-deferred-feature-work),
not blanket permission to add features or silently remove them.

Continue cloud-first development with pushed feature-branch checkpoints. Use a
Mac when native building/validation is required or explicitly requested; keep
actual store/device acceptance separate from source, web and in-memory results.
