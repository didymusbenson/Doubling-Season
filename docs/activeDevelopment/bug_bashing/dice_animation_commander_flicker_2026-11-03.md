# Dice animation and commander counter flicker — 2026-11-03

Status: implementation and local acceptance complete; authorized feature-branch delivery and remote CI verification follow. Baseline is
`e52f35738d8bec6548e1642e07b93b68b94e97e9` on `feature/phone-mode` (build 12
runtime: `351fc405d461cf3ffd6c87f1352736d6e3274c07`). The latest user instruction authorizes committing and pushing these validated
fixes to the existing `feature/phone-mode` branch, leaving main unchanged. No
physical-device installation, OTA, signing/account changes, Firebase or store
actions are included. The separate drawing proposal remains unimplemented.

## Requested behavior

- Give dice rolls a brief indication of rolling, approximately 0.5–1 second.
- Investigate and fix counters flickering when tapping the commander damage
  modal; compare the earlier fixes and verify phone and tablet presentations.
- Preserve recent phone input, stepper-only player counters, validation,
  utility interactions, game state and history behavior.

## Proven flicker cause and fix

The earlier direct-control fix in `ff2526d` kept controls mounted and removed
per-save modal locking. It also used the global `_directPending` count to permit
an immediate minus after a plus while the committed value was still zero. That
same condition applied to *every* zero player counter. A commander damage or
status write therefore temporarily enabled unrelated decrement controls.
`HalfStepper` paints disabled minus icons at 0.38 alpha and enabled icons at full
alpha, explaining the visible brighten/dim cycle without a value or layout change.

The new regression failed on the old condition: an unrelated energy decrement
callback became non-null during a delayed commander write. Pending player-counter
commands are now counted by `(playerId, counterKey)`, preserving same-counter
queued reversal while leaving other controls unchanged. The global queue still
controls draining before navigation/close; durable state and failure behavior are
unchanged. Counts clear through the existing `finally` path on success, failure,
or invalid scope. Commander tracker keys and pressed feedback remain intact.

Independent review compared the earlier fix and checked lifecycle, queue cleanup,
rapid reversal, target identity, and the new regressions. No blocker was found.
A possible separate artwork decode behavior was inspected but not reproduced as
this report; no speculative artwork changes were made.

## Dice behavior

Each accepted roll generates one immutable result snapshot. For 750 ms, the
existing die outlines wobble slightly and cycle decorative faces; totals and
result semantics stay hidden behind a live “Rolling…” status until completion.
Reroll is disabled during that interval and the admission guard rejects repeated
callbacks. Reduced motion reveals the snapshot immediately, including when the
setting changes mid-roll. Back, Close and backgrounding safely settle/cancel the
presentation; returning cannot leave a stale rolling lock. No result, history,
archive or other game-state writes were added and the random generator is unchanged.

Independent review caught and corrected completion being gated by navigation:
clearing an animation-only lock now bypasses command admission, while still
checking mounted state and the roll serial to reject old callbacks.

Actual narrow-phone review found a pre-existing third group heading clipped by
the Back/Close corner. The standalone selector and results now reserve 56 px above the content,
clearing the 6+44 px corner controls with a small gap. The embedded drawer is
unchanged. Four new regressions check selector and every denomination heading
at 390 px and 440 px phone widths. Actual native review also confirmed the
selector D8 had shared the same pre-existing overlap.

The Flutter 3.41.2 web engine only maps high contrast into its accessibility
features; actual CSS reduced-motion checks (including before startup) initially
still animated. A small dice-only conditional JS interop adapter now reads
`prefers-reduced-motion` at roll admission and listens during the result surface.
Its listener is removed on disposal. Dice also reads the native engine
`AccessibilityFeatures.reduceMotion` flag alongside `MediaQuery.disableAnimations`.
Browser checks confirm immediate results when enabled at startup and
settling/unlocking within 100 ms when enabled mid-roll. No new dependency or
application-wide accessibility override was added.

## Validation

- Nine new commander stability tests pass across phone (390×844), tablet
  (1133×744), and 180-degree tablet orientation. They assert unchanged unrelated
  counter pixels, geometry, callbacks and icon alpha during delayed saves at
  several animation-frame offsets, as well as rapid same-counter reversal and
  failure cleanup.
- The existing commander direct-grid and modal numeric-persistence suites pass
  (26 tests), including durable coupled life/damage and queue draining before
  close. Scoped analyzer run passed.
- Final integrated analyzer passed; the final full suite passed **1,120 tests**
  with **seven existing opt-in skips**. Five
  new dice tests cover timing, stable result/unchanged state, repeated callbacks,
  reduced motion including mid-roll changes, Back/Close, lifecycle and zero dice.
- Release web and native simulator builds succeeded. The first native artifact
  contained a stale `objective_c` framework from the prior physical-device
  release build. `vtool` confirmed platform IOS. A clean rebuild regenerated both
  arm64/x86_64 slices as IOSSIMULATOR; startup then succeeded without touching
  saved simulator data. This was a generated-artifact issue, not a source change.
- Actual release-browser review captured 141 repeated commander/counter frames
  across phone and tablet: the untouched energy decrement region changed zero
  pixels and its bounds were identical. Repeated damage taps preserved the
  coupled life delta, and counter reversals returned to zero.
- Dice rolling produced 64 captured frames per form; final die pixels appeared
  around 817 ms after the first recorded frame (including pointer/navigation)
  and then stayed stable. Rapid reroll, Back/Close during motion, final totals,
  initial and mid-roll CSS reduced motion all passed. Final 390/440 px selector
  and mixed-result screenshots confirm all headings clear Back/Close.
- Both isolated native simulators passed eight repeated commander +/- cycles,
  energy +/- and three dice rerolls plus Back. Initial concurrent Maestro runs
  hit XCTest's global single-gesture limit; sequential continuation passed.
  Final phone/tablet builds also passed mixed D4/D6/D20 rolls, rerolls, Back and
  Close. Native screenshots confirm selector/result clearance and correct totals.
  The isolated iPhone's actual Reduce Motion switch was confirmed on for its
  final mixed-roll pass and then restored to its original off setting. Widget
  tests separately assert both Android/MediaQuery and iOS engine motion flags.
  Frame review exposed the distinct iOS flag issue described below; the corrected
  native recording verifies the absence of rolling. Temporary Maestro flows
  were discarded after validation.
- No physical device has been queried or changed.


## Supporting local evidence

Evidence is retained outside the repository in the Kista task workspace:

- `task-4/verification/dice-commander-2026-11-03/`: final analyzer/full-test/build
  logs, native screenshots, simulator preference on/off confirmations, native
  interaction logs and the final native reduced-motion recording. Initial
  build/automation attempts remain clearly marked or documented separately.
- `task-4/qa/dice-commander-browser-2026-11-03/`: `review-result.json`,
  `stability-pixel-results.json`, `dice-frame-analysis.json`, 29 screenshots and
  12 frame sequences. Reviewed browser artifact `main.dart.js` SHA-256
  (before the subsequent native-only flag correction):
  `8981e5c7de9de38353df07fef153de1a6fd6c43ca28e794c53b70af6a23963ca`.

Independent implementation and UX reviews found no remaining blocker. Remote CI
is separate from these local results; no physical-device acceptance is claimed.


## Existing browser smoke compatibility

The first remote run for `697a981` exposed one stale assumption in the existing
release-browser smoke: two calls collected result semantics 120 ms after a roll,
while the new animation deliberately hides those semantics for 750 ms. The
failure was `Wrong D4 count: 0 !== 2` at the mixed-roll check. The shared verifier
now waits for the visible final total before collecting its result snapshot;
all exact face-count, range and sum assertions remain intact. No app runtime
change was needed.

The complete corrected release-browser flow passed locally in about three
minutes, producing 159 screenshots and zero runtime exceptions. This includes
mixed/dense dice, rerolls, token/artwork operations, drawer transitions, archive
restoration and dark/light 2/3/4-seat portrait/landscape checks. The follow-up
commit contains only this browser-test wait and these notes; the 1,119-test
runtime and native/browser acceptance results above remain unchanged.


## Native Reduce Motion mapping

Actual frame inspection caught a gap missed by the initial functional pass:
iOS still animated with its system switch enabled. The platform exposes
`AccessibilityFeatures.reduceMotion` independently of `disableAnimations`, and
Flutter 3.41.2 MediaQuery only forwards the latter. This is confirmed by the
local SDK and [Flutter's API documentation](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html).

The dice-only preference check now combines the engine's iOS flag, the existing
Android/MediaQuery flag and browser CSS preference. The existing animation
observer handles accessibility-feature changes and settles the same immutable
result. No native Swift, project, dependency or signing changes were needed.
The new regression sets `reduceMotion=true` while `disableAnimations=false` and
`accessibleNavigation=false`, covering initial skip, mid-roll change, subsequent
unlock and unchanged game state. Final analyzer and all 1,120 tests passed, with
seven existing opt-in skips; independent review found no blocker.

The corrected iPhone simulator recording has **59 frames sampled every 50 ms**
across a roll and reroll: immediate final totals, **zero rolling frames**. The
normal-motion control recording shows Rolling from 14.45 s to 15.20 s (750 ms).
The actual iOS switch was visually confirmed on for the test and restored off
afterwards. Evidence: `native-ios-motion-fixed.mp4`,
`native-ios-motion-fixed-ocr.json`, `native-motion-off-ocr.json`, and the associated
switch screenshots under the verification directory above.
