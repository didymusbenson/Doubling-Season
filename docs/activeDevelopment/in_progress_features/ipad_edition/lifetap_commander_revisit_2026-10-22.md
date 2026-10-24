# Lifetap commander revisit — evidence and adaptation

Targeted read-only research returned 2026-10-22 at 20:54 UTC. Its original handoff was read at `/Users/didymusbenson/Documents/Codex/2026-10-20/task-3/commander-revisit/lifetap_commander_revisit.md`; this integration preserves its evidence limits, not a new runtime test claim.

| Evidence | Observed / previously tested | Limits |
| --- | --- | --- |
| User Mike crop `libfile_f9127156ef988191845975fc404706a9` | Materialized locally and pixels viewed. 237×129 PNG: life 17, compact 2×2 source ledger 6/0/me/12, counter tools beside it. | Static collapsed state; source names, platform/version and gestures are not established. SHA-256 `373b34eab31a64a5e0e321540666744bcbc46fcdd5ccf02e05d079fd6caf64a1`. |
| User four-player image `libfile_60e6719e3ddc8191bea106766a1321ed` | Materialized and viewed. 494×254: each seat has a compact source grid; Mike's self cell is lower-left and David's lower-right. | Spatial mapping is a pixel inference, not a controlled attribution test. SHA-256 `f27ebae4ebe8c103f0eac5ba53ae2b959e4b560f6fc75439b834f671ce980910`. |
| Prior Android interaction notes | A board mini-grid tap opened Counters. One source-cell tap changed damage to 1 and life 20→19. Two cells were incremented independently. Partner artwork produced two cells for that player. | Source labels/mapping, independent partner adjustments, corrections and precise dismissal paths were untested. No verified intermediate source-picker→amount-editor sequence. |
| [Prior expanded Counters screenshot](reference/lifetap/COUNTER-01-edited-state.png) | The research task re-viewed the actual emulator PNG: seat-oriented modal, Player/Counters tabs, larger 2×2 source grid of zeros and me, close X, dimmed table behind. | Shows expanded presentation, not the initiating tap, correction gesture or successful close result. |

The prior runtime was Lifetap 1.3.10 (162), package `com.lifetap`, Android 16/API36/arm64, emulator `Medium_Phone_API_36.1`, 1080×2400, observed 2026-10-21. Do not assign that version/platform to the user's two screenshots. The fresh revisit found an empty native app inventory and a locked-Mac message before any UI action. No install, Lifetap tap, setting change, reset or lock bypass executed.

Observed pattern: a useful compact per-seat source ledger opens a larger source-shaped grid. All-zero damage cells remain visible with opponents configured; this does **not** prove a zero-configured-source workflow. Self is visibly labeled me, but self-damage behavior was not tested. The generic hint “Tap to increment. Hold for additional options.” does not establish commander-specific correction/hold semantics.

## Chosen Tripling Table adaptation

Keep an always-visible source mini ledger attached to life tools, outside the colored life halves. Tap the ledger to open a compact, seat-facing grid whose source cards expose direct decrement/increment and explicit source-owner names, color and artwork. Separate partner IDs and self sources remain distinct. There is no added source-picker step or prerequisite amount form. Direct owner setup is available when no sources exist; opening/closing never changes life. Existing coupled damage/life commands, ledger-only correction and chronological undo remain authoritative.

Whole-table blocking, tapaway dismissal without click-through, explicit close/reopen, empty-source placeholders/setup, self damage, partner identity and correction behavior are our required and regression-tested choices. They must not be described as newly verified Lifetap behavior. Preserve stable IDs independently of spatial seating; use the reference to inform overview/attribution/editing space, not to clone its visual composition.

Still unavailable: fresh native replay and hands-on iPad/Android acceptance. A future bounded replay can test distinct named sources, partner/self corrections, X/tapaway/Back and empty-source setup after the host is manually unlocked. Current shared Flutter renderer/browser evidence is separate from that native evidence.
