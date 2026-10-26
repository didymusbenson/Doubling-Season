# Focused modal correction — 2026-10-26

Status: approved correction plan; first commander render gate in progress. Supersedes the shared Player/Counters panel and global sibling-tab decisions in the earlier feedback plan, not its other validated features.

## Evidence and cause

User screenshots of published `bf444536` show the commander list scrolled past its grid while the fixed Commander damage heading remains above unrelated life/status/counters. Three distinct board actions currently dispatch the same `_playerPage`; tab state, content ordering and shared scroll position determine its contents. Reset/restore also combines unrelated destinations behind tabs, and global sibling chips build a navigation history as if tabs were routes. This is an architectural mismatch, not a request to change the fixed 75% shell.

## Approved correction

- Keep the centered 75vw × 75vh shell. Remove dedicated heading bands/dividers; integrate only useful context with content and unobtrusive, nonoverlapping 44px Close/Back controls.
- Separate direct Player customization, Counters and Commander damage destinations. No shared category switcher. Player retains appearance, commander identity/partners and existing player setup controls; Counters never contains commander trackers; Commander contains only its damage workflow.
- Commander grid is immediately visible and does not scroll for 2–4 players with 1–2 sources each. Preserve physical owner positions, self and partner identity, damage/life semantics, correction distinction and Undo. Size within bounded available space instead of fixed 140px cards. Keep all action targets at least 44px. Existing extra-source data is preserved and explicitly accessible, not silently omitted or capped.
- A separate Table hub presents Dice, History, New game, Archives, Board wipes and Settings choices once. Destination pages have no sibling tabs; Back returns to the hub only when entered from it. Existing direct Dice remains direct. Settings contains actual settings.
- New game controls use aligned, bounded-width sections inside the unchanged shell. Empty space is preferable to arbitrary stretching. Preserve existing archive/reset payloads, safety confirmations and Everyone wipe atomicity.
- Preserve keyboard, staged artwork, attribution, token rendering, native-diagnostic honesty, durable-save ordering, failed-save drafts and lifecycle safeguards. No release, schema, OTA data or original-app changes.

## Verification gates

1. Render the focused commander route with all eight normal sources, long identities and warning state at portrait/narrow and short-landscape targets, including 844×390 and 650×480, actual seat rotations and text scale 1.3. Assert action bounds, nonoverlap and no scrolling; parent reviews pixels before broad migration.
2. Replace tests encoding the superseded shared-tab architecture with independent route/title/content and hub navigation assertions. Preserve mutation, correction, undo, persistence failure and modal lifecycle coverage.
3. Verify integrated Player/Counters/hub/New game visuals and actual browser interactions, then freeze source for analyzer/full suite and CI. Independently review; checkpoint in a draft PR, then publish only after validated review under existing repository authorization.

Physical iPad upload root cause, life latency and native paste/keyboard acceptance remain unresolved from the preceding batch; this correction does not claim to fix them. Cloud only; no desktop actions or IPA installation.

## Partner clarification (approved)

Commander names are not required setup. Replace naming/Add/Remove controls with **Has partner**. Show compact generic Commander/Partner labels while preserving existing names as metadata and accessible detail. Each has a separate stable source ID and separate 21-damage threshold; never sum partner damage for that threshold.

Turning on creates/reactivates the same partner source atomically and preserves the implicit primary identity. Turning off is refused while any recipient has nonzero damage from that partner. At zero it marks the partner inactive, not deleted; reenabling restores the same ID/name. An optional source `active` field defaults true for older data. Existing archives/history survive and reset carries configuration. Older builds that ignore the new flag may display an inactive source; backward reading is lossless, not equivalent active-visibility behavior. Imported extra sources remain explicitly accessible rather than capped or silently hidden.
