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

All scoped items below are implemented. Local validation is recorded below; native-device acceptance remains separate.

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

Record analyzer, full tablet test suite, release web build, visual interaction evidence, exact final commit, CI and combined Pages deployment separately. Web/widget evidence is not iPad or Android native acceptance. Do not call the batch complete while a known persistence/data-loss defect remains.

### Implementation checkpoint and focused verification

- WIP checkpoint `dbbd679444736a9f43f2761a302ecb7f5dd4d48f`, draft PR #49. Not a completion/deployment claim.
- Engine/turn/reset/Plus/hold focused tests: 38 passed.
- Inline action utility focused tests: 15 passed.
- Artwork/import/swipe/token focused tests: 33 passed.
- New commander domain/persistence/interaction tests: 14 passed.
- Existing four-file commander/UI regression run: 207 passed after correcting a real partner-label overflow and narrow life-tool grouping. Utilities and Edit remain paired; Monarch and Blessing remain paired.
- Numeric ramp: base 5 every 300 ms (mana base 10), at least 10 every 150 ms after 2 seconds, at least 25 every 80 ms after 5 seconds. Each async repeat is awaited; released/canceled gestures do not enqueue a backlog.
- Commander direct-write failures survive later successful writes and correction navigation; closing drains accepted writes and exposes pending failures before dismissal.
- Flutter renderer captures of commander before-save and delayed-save-pending are byte-identical (SHA-256 `9fdfe23e008443fceaeddc56f0e83a3157fb8903499c8036beadc9cdeefec62e`). This validates that captured path, not all possible modal/native behavior.
- Native OS file import still follows OS orientation. The primary in-app art search/variant/preview flow faces the seat. Web import uses the existing file-picker bytes/crop path rather than silently returning no result.
- Final local analyzer: no issues. Full tablet suite: 420 passed. Release web build: passed on Flutter 3.41.2.
- A final wording-only Brudiclad adjustment (“Create Myr only,” full explanation in tooltip) passed its 17-test focused suite and was included in the final release web build.
- Additional cluster/capacity run: 36 passed without loosening baseline visibility contracts. Start Turn now occupies a compact token-lane corner control alongside Add and Summary; six life tools are retained. This avoids stealing utility height or overlapping the life-stepper surface.
- Reset action clipping corrected; 12 workspace/hold tests and 8 real-font reset layout cases passed, including rotated three-player landscape. No scrolling required for those fixed choices.
- Independent real-font Flutter renderer review passed: 2/3/4-seat boards in portrait/landscape, commander before/pending/acknowledged frames, reset modes, inline Rhys/Crusade/Brudiclad controls including scrolled target selection, all four artwork-picker rotations and token shading states. Artwork fixtures were synthetic and were not represented as live catalog imagery.
- Local cloud-browser serving was attempted through the ordinary supported route and returned connection refused. No alternate exposure/bypass was attempted. Hosted Pages smoke testing follows authorized deployment.
- Native iPad/Android hands-on testing has NOT been performed for this batch. CI compilation is not native interaction acceptance.
- Exact final remote commit, CI and Pages verification remain pending publication.
