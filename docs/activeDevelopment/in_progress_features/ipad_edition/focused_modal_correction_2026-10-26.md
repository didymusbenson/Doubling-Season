# Focused modal correction — 2026-10-26

Status: implemented and checkpointed in draft PR #54; final exact-head validation is in progress. Parent accepted the commander and integrated focused-dialog visual gates. Supersedes the shared Player/Counters panel and global sibling-tab decisions in the earlier feedback plan, not its other validated features.

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


## Validation checkpoint

The maximum-eight-source grid passed portrait and short-landscape render gates with 44px minimum action targets. Integrated Player, Counters, hub, New game and mixed-source layouts were reviewed; the hub uses consistent bounded button widths. Dedicated tests cover route isolation, hub-to-destination Back navigation, independent partner damage, guarded deactivation, persistence, archives, reset, Undo, pending-save dismissal and retained failure visibility. Final full-suite, analyzer and release-browser evidence will be recorded in PR #54 before publication.

The header-removal regression checks also cover utility and Ring top-row actions, which must reserve the actual Close corner without introducing a full header strip. Capture helpers follow Flutter's golden matcher ordering: start `toImage` in the test frame zone before awaiting it in `runAsync`; this avoids missing retained-layer glyphs in screenshots.

### Imported source edge cases

Normal setup supports a primary plus one partner. Existing active groups with more than two sources remain available through an explicit over-density correction list; the partner toggle refuses to deactivate such a group implicitly. Inactive sources retain their full data. An explicit imported inactive source with recorded damage is not normalized or deleted; the ordinary primary/partner pair can be reactivated with Has partner. Arbitrary inactive third-or-later imported sources are a preserved-data recovery limitation, not claimed as normal supported setup.

### Release-browser dismissal interception repair

Chrome interaction testing identified a real accessibility hit-order defect after a state update: a full-window actionable `Close workspace` semantics node sat above the visible modal controls. Twenty fresh DOM hit checks across three seconds identified the same 1133×744 dismissal target over the 44px Close button; an earlier Back click had therefore dismissed the route instead of returning to the commander grid. The outside-tap layer now excludes semantics while retaining its raw pointer dismissal behavior. Assistive technology retains the visible Close control and the keyboard's focused Close control. Regression coverage checks the semantics surface and pending-save/outside-tap behavior; actual browser target correspondence remains required before publication.
