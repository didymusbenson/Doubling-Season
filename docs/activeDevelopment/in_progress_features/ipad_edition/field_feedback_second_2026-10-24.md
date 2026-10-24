# Second iPad field-feedback batch — 2026-10-24

## Authorization and isolation

The user lifted the feedback-collection hold and authorized research and best-effort
implementation, explicitly deferring complete design where more feedback is needed.
Remote main was verified at `15e9d4ecc46d910c607df037064013c042740f51` before edits.
The clean before-state checkpoint is that same commit, pushed as
`checkpoint/tablet-field-feedback-2-before-20261024`; no empty source commit was needed.
Implementation uses an isolated clone on Kista's Mac, branch
`codex/tablet-field-feedback-2`. Existing worktrees and PR #48 are preserved.
The later user request explicitly authorizes the final iPad in-place Release update
after validation, merge and publication; iPhone installation remains out of scope.
Use existing valid provisioning, no new credentials/certificates or store upload.

## Implemented feedback

- Token name, type, rules and P/T backplates have 5px additional horizontal
  content insets; status backplates have 3px. No exterior card whitespace added.
  Type and abilities are separated by 3px.
- Counter-add sits immediately after the chips in their shared horizontal scroll.
- Start Turn retains its corner target and uses the existing Mana untap glyph.
  City's Blessing uses the bundled Mana Ascend U+E94A. Tablet-only icon constant
  avoids changing the original app. `tool/verify_mana_glyphs.py` verifies the
  source and release-subset font cmap for both glyphs.
- Commander miniature and expanded grid share physical seat mapping, rotations,
  the empty three-player slot and partner subdivisions. See
  [commander notes](../../../../../apps/tablet/docs/commander_spatial_layout_2026-10-24.md).
- Hold the owned Monarch crown to clear ownership. Tap still claims/transfers;
  the gesture recognizer consumes hold release. One chronological undo restores it.
- Token lane clipping contains the transformed Dismissible during motion, in
  both lane orders. Intermediate renderer tests compare the entire adjacent
  life surface before/during actual displacement; screenshots are pixel evidence.
- Utility Edit uses a pencil. Edit/Hide share the action wrap instead of a whole
  management row. Non-Storm numeric controls use 88px with 44px halves; narrow
  lanes place the number below the full-width name. Portrait Storm retains its
  established full-width direct stepper. Generic modal numeric choices are bounded
  widths in a compact wrap; action editors use a shorter 460px frame while variable
  Brudiclad target lists keep scrolling.
- Player names are horizontally centered in the life surface and remain under
  the life halves. Edit is separate. Name tests exercise both sides of the seam.
- Canonical generated-token identity/art/merge fixes and Squirrel Girl are in
  [the engine notes](../../../../../apps/tablet/docs/generated_tokens_and_squirrel_girl_2026-10-24.md).
- The Ring is a seat utility with atomic manual bearer/temptation choices;
  existing Ring tokens remain intact. See [Ring design and rules](ring_utility_2026-10-24.md).

## Deliberately deferred complete design

These are provisional implementation choices for later user review, not settled
requirements. The user explicitly deferred complete design/feedback for this batch.

1. **Utility editors:** bounded numeric controls and shorter action forms are a
   practical first pass. Revisit property grouping, card-specific quantity labels,
   correction affordances, dense fixed-choice layouts and narrow-tablet ergonomics.
2. **Squirrel Girl:** activated 1GGG action counts owned token Squirrels plus the
   manual nontoken count (default one, including Squirrel Girl). Payment is manual.
   The independent enters/attacks create-one trigger is deliberately deferred;
   catalog creation can represent it meanwhile. No inferred trigger automation.
3. **The Ring:** free-text physical bearer identification, optional board-token
   linking/stack splitting, automatic clearing on loss/control changes, legacy
   conversion, correction controls and tablet ergonomics need later feedback.
   No automated combat/draw/discard/sacrifice/life-loss rules enforcement.

## Validation and publication record

Local verification: clean analyzer, full suite **494 passed / one web-only test
skipped** before review. Independent review then caught Changeling tribal counting;
that was corrected for Squirrel Girl and Krenko, with all five actual bundled
Changeling definitions, owner/other-seat isolation, modifiers once and atomic undo.
64 focused engine/board/inline tests pass. Final full-suite/release/CI are being
rerun after this correction. No original-app source/assets/configuration changed.

Native iPad mini A17 Pro, iOS26.2 isolated simulator: inspected portrait/landscape
2/3/4-player layouts, all four initiating commander seats, matching empty-three
slot and opposing two-player grid; direct self-damage + one undo restored both
life and damage. Native catalog Goblin1 + Krenko made one art-bearing stack3;
Squirrel Girl generated a canonical art-bearing green1/1. Native Ring bearer
`goblin` was entered using actual custom keyboard keys, then committed atomically
with stage1. Native complete resets restored Storm/Mana and archived QA games.

Active swipe displacement and owned Monarch hold/release have real-font Flutter
renderer pixel/interaction evidence in portrait/landscape; the moving token was
verified displaced before comparing the whole life-zone pixels (no changes).
These intermediate frames are renderer evidence, not claimed native recordings.
Native scroll/gesture exhaustiveness remains distinct from those tests. No
configured Android tablet emulator exists; the existing AVD is a phone.

The paired physical iPad was read-only checked: app0.1.0 build2 and hardware UDID
matched the existing Tripling Table iPad Development profile. Its Documents were
copied to a task-local backup before any update. Final Release uses0.1.0 build3;
compare stored gameplay and media after installation before claiming preservation.
Exact final source CI, deployment and installation outcomes are recorded in the
final task handoff.

Already verified: three original Library reference images materialized and viewed
on this Mac; canonical engine focused tests (58), commander spatial tests (37),
existing commander tests (43), Ring focused tests (7), compact modal/inline tests
(24), release web build and required source/subset Mana codepoints. Native iPad mini
simulator launches; actual catalog Goblin followed by Krenko merges into one
art-bearing stack. Android configured AVD is a phone; no configured tablet AVD found.
