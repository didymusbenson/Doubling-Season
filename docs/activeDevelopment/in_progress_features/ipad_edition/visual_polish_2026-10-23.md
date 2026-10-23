# Tablet visual polish — 2026-10-23

Review checkpoint on `codex/tablet-visual-polish`, based on published main `1a0d04c9f83975ea05498e624ddcf3d8e16474d1`. No original root-app source, storage schema, dependency, signing or deployment configuration changes. Publication waits for parent visual review of this checkpoint.

## Visual changes and evidence

The user’s screenshot `libfile_0aadcaae49c88191a1c989dfbf432350` was materialized into this consumer workspace, verified readable, and inspected as pixels. The reviewer’s historical checklist `libfile_b3102d225ed08191871803d67cb6bf77` was read with its revision and runtime limitations retained.

- Life changes from a 66px band with 48px text to an adaptive 104–148px colored surface with 64–80px text. Whole player-local halves still include the number/name and colored border-inset points. The surface only clips the hub’s circular corner clearance, replacing the old full-height horizontal gutter. Tools stay outside the colored shape. The 52px hub remains at the true table center; token-lane widths/heights are unchanged.
- Mana cells use bundled Mana font symbols beside their values, with distinct edge −/+ affordances. Cells retain 44px full-half targets, zero clamp, one-shot ten-step hold, locks/conversion/empty semantics, history and undo.
- Status badges use a smaller outlined visual within 40×44 targets. The commander ledger grows from 60px to an adaptive 68–80px width, retaining 44px height, source-owner colors/art and independent self/partner cells. Crown/Blessing adjacency, Edit-last order, presets in Edit and utility management in utilities remain.
- Add and Summary overlays both move to the opposite horizontal corner: local-left 12px and 68px. Local-bottom spacing and final expanded-token scroll clearance remain unchanged; facing rotation mirrors physical placement correctly.
- Fixed modal frames follow content rather than inheriting 1050×940. Focused player/counter/utility/rule/token editors omit redundant cross-feature navigation. Fields and actions group in columns/rows; standalone actions keep intrinsic widths.
- Life adjustment and deliberate total correction have distinct headings. Counter labels/values share compact cells with explicit Set retained. Storm uses a compact 760×330 frame; mana uses symbol-led cells. Utility search is pinned before the compact current-utility rows and variable catalog list.
- Settings keeps the central game-action navigation and groups game/theme, catalog, appearance reset and support into compact cards; every fixed action remains visible.
- Reset/restore separates New game, Archives and Board wipes. Fixed new-game choices and wipe actions fit, while archives retain their list viewport. Rules show preset sources in a grid; creating/editing a custom rule opens grouped trigger/outcome controls rather than a form appended beneath every modifier. Existing rule data/actions are retained.
- Token custom/detail fields and creation preview/quantity controls are grouped. Art preview and variable thumbnail choices sit side by side, with the latter in a bounded scrolling region. URL, display style, upload/removal and staged confirmation remain accessible. Art captures use an explicitly synthetic fixture, not downloaded user artwork.
- Expanded commander correction widens only its active source card, with legible “New damage” and “Set total” fields. Normal direct source chips remain compact. Each PlayerField now owns a PageStorage identity: this prevents an ancestor ExpansionTile’s saved boolean being restored as a text-field scroll offset. The populated correction scenario reproduced the original type failure and now passes.

## Verification and acceptance

- [x] `flutter analyze` and aggregate `flutter test`: 314 tests pass. The 113 populated real-font modal scenarios include mini landscape/portrait, larger landscape and top-facing player/mana/status/commander/dice examples.
- [x] Board capacity and geometry: 2/3/4 seats, 1133×744 / 744×1133 / 1366×1024, safe areas, one/eight commander sources, default mana/Storm controls, global hub center, clipped colored-path clearance, disjoint tools, local-left overlays and expanded last-token clearance.
- [x] Every utility catalog type’s fixed controls fit without scrolling in both mini orientations. Variable utility action targets/results keep their own content region.
- [x] All modal families rendered and inspected: life/status, appearance, commander setup/grid/expanded correction, counters, mana/Storm and utility selection, rules/custom rule, dice with results, reset/archive/wipes, presets, token search/create/custom/status/counters/split/art/detail/summary, settings and history.
- [x] Whole life colored-edge/name taps, holds/repeated taps, running delta grouping and undo, independent Edit/tool taps, Monarch transfer/undo and Blessing independence, partner/self damage-life coupling and undo, token parity and single-keyboard regressions retained.
- [x] Populated modal dismissal consumes tapaway without reopening or changing underlying game state. Explicit Set/Create/Apply/correction semantics and existing inline commit-on-exit remain distinct.
- [ ] Independent final visual/runtime review, then merge and combined Pages publication. No merge is authorized before this review checkpoint is accepted by the parent.

| Target | Validation in this pass | Remaining boundary |
| --- | --- | --- |
| Shared Flutter renderer | 314 regressions pass; real-font captures inspected | Widget renderer is not a running release browser or native device |
| Web release | Local release build with `/Doubling-Season/tablet/`; Mana font present in output | Supported live browser-control tool unavailable; HTTP/artifact checks do not close interaction acceptance |
| Android tablet | Shared Android-target widget behavior passes; CI APK build requested by PR | No native UI-control tool exposed; native hands-on validation not run |
| iPad/iOS | Shared iOS-target widget behavior passes; CI simulator build requested by PR | No native UI-control tool exposed; locked-host restriction preserved, no bypass |

No supported browser/native control is exposed in this executor. The old preview’s refused connection was a stopped server, not evidence of an app regression. A fresh loopback release server and evidence manifest are provided at handoff. No personal data, authentication settings or installs were changed. This checkpoint is reviewable renderer/build evidence; native acceptance remains open.

## Parent visual review refinements

The first checkpoint (`8ec983c`) passed CI web/Android/iOS builds, then parent pixel review requested five bounded improvements before merge. The original 8823 review artifact remains available unchanged.

- Every player counter now has the same 48px-high stepper and disjoint 44px correction affordance. No correction inputs are permanently reserved; one precise Set row reveals on demand. Cancel makes no mutation; Set and undo retain exact counter-only semantics. Tests compare all four geometries, including Radiation, and exercise cancel/set/undo for each counter. Default frame is 420px high; an active correction uses 470px.
- Local preset rules omit repeated owner text; Primal Vigor’s visible global note and foreign-source provenance remain. Create Custom Rule is hit-testable above the fold in mini landscape and portrait, including the rotated seat.
- New-game configuration groups player count, a 140px starting-life field and 20/40 quick choices. The frame is 420px in landscape, 460px at the narrow portrait width, and grows to 540px for explicit three-player empty-slot options. Archives/wipes retain their own list viewports.
- Artwork uses 360px for empty state, 520px for unselected options, 580px for current art and 640px for staged preview. Thumbnail choices scroll within a 200px cap beside a preview, or a 120px cap without one. All fixed controls remain reachable with a long art list; preview/cancel/apply behavior is retained.
- Token creation uses a 180px preview column and the remaining width for quantity, all five presets, tapped choice, creation breakdown and Create. Presets 1–5 stay in one row at supported mini sizes, and Create aligns with its own input column. The frame is 520px high.

Final local checks: 314 aggregate tests, 113 real-font populated modal scenarios, clean analysis and release web build. The new exact source/CI/run and Library version identities are recorded in the handoff manifest. Native hands-on and supported live-browser interaction remain not run; parent visual review still gates merge/deploy.
