# Visual table feedback and immediate life response — 2026-10-27

## Scope and composition

This checkpoint combines the existing draft dice implementation `67e78d9`
(PR #55) with the user's immediate visual fixes. It is a fresh commit directly
on verified main `82069d6`, retaining that base's `AGENTS.md` unchanged.
It does not change release versions, store builds, OTA data, root-phone behavior,
or the existing 75%-viewport modal shell. Merge/deployment remains held for parent
review; no merge/deployment is implied by a pushed checkpoint.

The three supplied Lifetap screenshots were viewed before implementation. They
informed the visual hierarchy, not copied navigation or invented partner rules.
Commander, Counters and Player remain separate routes.

## Changes

- Commander damage uses one artwork-led tile per physical owner, filling the
  available grid rather than leaving a small form at the top. Partner A/B totals
  remain independent inside their owner's tile. Each +/- region and explicit
  correction pencil retains a >=44px target; no commander names are required.
- Player names are subdued overlays above the large life total, without an
  additional name-height band. Commander mini-ledger and active counter/status
  summary occupy the life chip footer. All active status icons remain visible;
  unusually dense counter sets use a quantified overflow with full values in the
  focused Counters route and accessibility value.
- Monarch and City's Blessing actions moved into the visual Counters status
  tiles; Monarch hold-to-clear is preserved. Rules, utilities and player settings
  retain a compact separate tool row, with an accessible narrow-width fallback.
- Initiative previously had no activation path for a new tablet game. A narrow
  claim/transfer/clear action now uses existing `UtilityState` storage, with no
  schema change and no dungeon/venture mechanics. It reuses existing IDs and
  preserves art, values, configuration and visibility. Claim/clear is atomic,
  undoable and durable; archived/hidden legacy data is not silently rewritten.
  Existing Initiative payloads are projected as a life status instead of a
  duplicate utility row. Treasure remains in the token lane.
- Storm and other inline numeric utility controls have a clearly contrasting,
  bordered control surface. Day is warm amber, Night cool blue, Neither subdued;
  taps cycle Neither→Day then Day/Night, and a hold clears without a release tap.
- Player-counter, utility and mana stepper taps use the existing direct numeric
  queue instead of modal-wide save disabling/progress flashes. Pending boundary
  reversals, correction editors, navigation and Close respect queued saves;
  failures remain visible and do not discard successful newer commands.

## Life tap latency

Source inspection found no double-tap wait in `HalfStepper`: an ordinary tap is
recognized on release. The previous life display waited for repository save.
With synthetic blocked storage it stayed at 40 through 16/80/300ms test frames.
The new UI-only `LifeTapFeedback` shows 41 on the first 16ms frame while canonical
and durable life remain 40 until storage succeeds.

Each pending receipt carries the exact controller command ID. Display computation
excludes acknowledged IDs immediately, avoiding a publication-before-Future
completion double count. A failed receipt removes only its own delta; newer taps
remain. Scope matches existing life command semantics: session ID/generation
and player identity, with same-player Undo/preset changes rebasing remaining
deltas in serialized order. New game/archive replacement invalidates old scope.
Accepted saves continue after widget disposal/backgrounding. History, Undo and
storage are not optimistic or debounced. The signed delta combines committed and
unacknowledged changes exactly once. Failure reconciliation uses the existing
error area, with an explicit >=44px acknowledgement action.

These measurements are deterministic delayed-storage Flutter tests, **not**
physical iPad latency measurements or native acceptance.

## Verification

- Official Flutter 3.41.2 / Dart 3.11.0 installed from the official distribution;
  archive checksum verified. CI/BOT environment avoids Flutter's unnecessary
  cloud-metadata detection. HOME/XDG/pub cache are task-local.
- Focused combined commander/modal/Initiative/legacy suites: 113 passed.
- Expanded commander art/geometry suite: 59 passed, all four rotations,
  portrait/landscape, 2–4 players, max partners and long names.
- Initial life/status visual suite: 15 passed; art-backed captures use a verified
  Scute Swarm crop (Alex Konstad) and decoded current image providers.
- All 19 life-feedback tests pass, covering next-frame display, exact acknowledgements, rapid
  and opposite multi-seat taps, first/middle failure, Undo orderings, preset
  rebase, session/archive replacement, durable reload, disposal and hold cancel.
- Initial cloud full tablet suite: **829 passed, 5 intentional skips**, in 3m06s,
  before the three native accessibility regressions described below.
  `flutter analyze --no-pub` is clean. All 22 changed/new Dart files pass format
  checks; `git diff --check` and browser-script syntax checks pass.
- Initial cloud release web build passed (51.8s), with the existing Pages base path.
  `main.dart.js` SHA-256:
  `161ef3e5a037041abf69a9606dc392d46689d35999bfc98a59cac2cb24ebdeb1`.
- Browser smoke now also covers relocated status controls, life tap persistence,
  and art-backed max-partner grids from all four seats in portrait/landscape.
  JavaScript syntax validation passes; the final local release-browser run is
  recorded below, with remote CI identity available in the draft PR.

Initial cloud Chromium execution could not start: the shell sandbox denied its Unix
socket, and the approved escalation failed in runtime setup at a protected
session path. No security-disabling browser flags, path changes, or retries
around that restriction were used. Subsequent Mac release-browser validation
used its supported local environment. Widget-render captures do not substitute
for that check or for native-device acceptance.

### Mac validation and follow-up corrections

The preserved source `040150a77c1fd306f42629ae3e3731cd599057f0` plus the
five-file correction patch (SHA-256
`3e4d21e82a848795fb4cca285b1b4b10c7131eb03a57b73d1b6a9afa8bff8c37`)
passed the following checks on Flutter 3.41.2 / Dart 3.11.0:

- Full tablet suite: **832 passed, 5 intentional skips, 0 failures**; analysis
  clean. The three added iOS semantics regressions failed before the fix and
  pass after it, exercising enabled state and Off/On accessibility actions.
- iOS 26.2 simulator build passed. Original-source simulator interactions
  covered life changes across all four seats, status controls, eight energy
  increments, Day/Night hold-clear and independent commander/partner targets
  in portrait and landscape. In the unlocked simulator, the corrected Monarch,
  City's Blessing and Initiative switches appear enabled; each passed On→Off→On
  and restored the original simulated life (41) and energy (8). Physical
  responsiveness remains unmeasured.
- Exact combined-source release web build passed in 16.728s; canonical Chrome
  smoke passed in **79.553s**, with zero runtime exceptions or network failures.
  All 16 actual life-control centers (four seats, two orientations, minus/plus)
  were checked with semantics enabled, with Day/Night unchanged after each.
  Mouse and touch Day/Night holds cleared while held and remained clear after
  release. The dedicated browser profile and server were cleaned up.

The native correction explicitly enables Monarch, City's Blessing and
Initiative semantics: Flutter's iOS switch bridge otherwise exposes these
toggled controls as disabled despite working pointer callbacks. The web
correction scopes `overflow: hidden` to the Day/Night semantic identifier;
its invisible long label had intercepted the portrait Player 4 minus center.
The full accessible label and actions remain intact. The browser persistence
barrier matches the canonical `qa · 41 life` header prefix, allowing its merged
accessible child text without replacing the durable-state check with a delay.

The publication checkout's product files are compared byte-for-byte against
that validated source. Only documentation evidence and the explicit unchanged
base `AGENTS.md` differ. Local browser and simulator evidence do not establish
physical iPad latency, native picker/Paste acceptance or complete device QA.

## Reviewed render evidence

These are Flutter widget-render screenshots with real loaded fonts and decoded
art, not browser or native-device screenshots. The test fixture deliberately uses
long names and dense statuses. Artwork: Scute Swarm (DSC), Alex Konstad;
source crop SHA-256 `39931b6a7567d7ee87f63a12e886edc6886ea2e230d1dc82389512d8b7897004`.

- [Board, landscape](visual_feedback_2026-10-27/board-landscape.png)
- [Board, portrait](visual_feedback_2026-10-27/board-portrait.png)
- [Commander, landscape](visual_feedback_2026-10-27/commander-landscape.png)
- [Commander, portrait](visual_feedback_2026-10-27/commander-portrait.png)

## Data and review boundaries

Hiding ordinary utilities still changes only visibility; Restore retains the
same identity and state. No user data was deleted, reset or migrated. No unrelated
local work was incorporated. All source/test changes are confined to the tablet
and this guidance, plus the already-existing dice checkpoint in the composition.
