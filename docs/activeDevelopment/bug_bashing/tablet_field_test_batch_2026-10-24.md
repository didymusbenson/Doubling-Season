# Tablet field-test correction batch — 2026-10-24

## Authorization and baseline

The user authorized this batch after a clean before-state commit on October 24:
“Get a clean before state commit made and then go ahead and work on this batch of fixes.”

- Before-state checkpoint: `f9f702202ffc2d2a21ad6f66cc2c98876c833d66`.
- Baseline source: `a79a38154366b873a4f93874433c86597ace09f5` (installed iPad release).
- Both commits have identical source tree `6519a34671044cd330af3fa6f192e8a576ed1d6e`.
- Working branch: `codex/tablet-field-test-fixes-20261024`.
- Original phone app remains unchanged. Pending documentation PR #48 is separate.

## Agreed scope and acceptance

All rows below are initially pending implementation and verification, not completed claims.

| Area | Required behavior | Important regression checks |
| --- | --- | --- |
| Per-seat Start Turn | One direct seat control untaps its tokens and clears their summoning sickness in one transaction. | Other seats, life, mana, storm, counters and quantities unchanged; one undo restores prior state. |
| Life artwork | Search existing token art as primary entry; upload is secondary. In-app selection, preview and keyboard face the initiating player. | No token creation or global token-art mutation; save/reload and seat isolation; native file-picker orientation is not falsely claimed to follow Flutter rotation. |
| Numeric holds | After a couple of seconds, increase both increment size beyond five and repetition speed. | Exact single taps, min/max bounds, release/cancel/lifecycle cancellation, no queued late repeats; do not accelerate semantic actions. |
| Commander damage | Stable owner-colored/art miniature within life chip, expanding directly to usable source controls including self and partners. | Atomic life/damage updates and undo; no source-setup prerequisite; rapid taps preserved; partial save failures visible even when closing; reset and seat-count stability. |
| Modal flicker | Remove routine interaction geometry/dimming pulses while retaining meaningful persistence error handling. | Inspect frames during pending writes, not only settled screenshots; test commander and other numeric modal controls. |
| Swipe token removal | Swipe deletes without confirmation, with chronological undo recovery. | Capture seat/session scope; failed persistence retains row; no fall-through or routine toast. |
| Action utilities | Direct component controls for Rhys and other action utilities, rather than opening a generic utility modal. | Both Krenkos, Hare, Manufactor, Crusade quick/resolve, Brudiclad target/skip; collapsed/expanded views; no double execution; one atomic action/undo. |
| Complete reset | Restore the fresh default Storm and Mana utilities while clearing custom game-specific setup. | Keep-board behavior stays distinct; presets/profile data preserved; reset commander miniature remains coherent. This supersedes the older empty-utility-lane expectation. |
| Plus vs Copy | Plus increments the selected stack with its counters retained; Copy creates the fresh counter-free token. | Preserve source identity/art, existing creation modifiers and companions, eligible sickness and atomic history. Do not weaken unrelated stack merge compatibility. |
| Token artwork contrast | Localized backing/shadow behind text and controls, not a blanket dark overlay over token art. | Full/fade styles, zero quantities, compact/expanded, loading/error and readability; shared life/commander surfaces are not changed accidentally. |

## Deferred

Space Beleren Alpha/Beta/Gamma sector tracking remains a low-priority future idea, not part of this implementation batch.

## Validation record

Pending. Record analyzer, full tablet test suite, release web build, visual interaction evidence, exact final commit, CI and combined Pages deployment separately. Web/widget evidence is not iPad or Android native acceptance. Do not call the batch complete while a known persistence/data-loss defect remains.
