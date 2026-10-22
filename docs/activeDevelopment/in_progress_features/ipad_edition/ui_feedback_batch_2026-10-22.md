# UI feedback batch — 2026-10-22

Status: implemented for independent design review, not native/browser acceptance or release. Feature branch `codex/tablet-ui-feedback-batch` starts at remote main `bbfdbd075e95af1a7bc0017a7f2f2542ac251288`. Checkout: `/Users/didymusbenson/Documents/Codex/2026-10-22/task-2/tablet-ui`.

These are **cross-platform requirements for iOS tablets, Android tablets and web**, although the user observed the issues on web. Shared Flutter source contains the changes; no web-only conditional styling was added. Browser checks never establish native acceptance.

## Addressed checklist

| Request | Implemented behavior | Current evidence |
|---|---|---|
| Name/totals and glyphs | Name and total/status share the first row, with bounded long content. No expansion arrow; established collapse-first/card tap remains. Empty P/T uses real Mana power/toughness icons. | Interaction/geometry tests; real-font glyph captures in both small orientations. |
| Token lane space | No permanent Add/Summary header. Local corner Add FAB and contextual Summary overlay. List fills the lane from `(0,0)` and has 88px end clearance. | All nine table matrices; maximum-scroll test on an expanded token taller than its lane checks every one of the seven action controls above the FAB. |
| Player borders | Solid 3px horizontal/vertical player dividers, distinct from game controls. Central divider continues through paired control groups. | Geometry and renderer captures. |
| Compact modals | Grouped fields/steppers/actions for all fifteen catalog utilities and custom tracker/toggle. Mana uses six compact color cards. Artwork, variable action previews and Brudiclad targets scroll separately. Player editor uses Life/status, Appearance and Commanders contexts; dice options use a 3/2-column grid. | All seventeen utility types have zero fixed-choice scroll extent at 1133×744 and 744×1133; mixed dice, artwork/tapaway, properties and 40-stack preview/list regressions. |
| Status badges | Enabled/disabled Monarch and City’s Blessing in fixed life shortcuts/player context. Board Monarch tap claims source seat, atomically replacing the previous holder. Blessing stays independent. | Claim/transfer, player attribution, independent blessings and chronological undo tests. |
| Commander damage | Attached individual mini-trackers with direct adjustment. Owner color/art retained independently of recipient. Horizontal source strip remains compact; overview retains arbitrary damage and ledger-only correction. | Distinct partners/self, owner color/art, direct source adjustments, coupled life/history and undo tests. |
| Game control placement | Shared strip lives entirely within life zones, below the hard horizontal border. Token lanes retain full region height. Two/three/four-seat layout and empty-seat controls retained. | Nine size/count combinations; no token-lane/control overlap; independent divider bounds. |
| Earlier token corrections | Compact direct controls, clean quick-add, partial tap, exact Set, Split & Add to One, sickness and scoped undo remain. | Existing corrective regressions plus new focused token checks pass. |

Implementation checkpoint: `859cb5dc1bc716d163175596f2a02397cd63febb`, pushed and remote SHA verified. Later documentation-only commits may update validation/Library evidence.

The original root app's code, assets, entry points, platform projects, dependency files and Pages deployment workflow remain unchanged. Documentation updates reflect the new accepted directions. No merge, deployment, installation, signing/store/account/security change or personal game-data reset was performed.

## Verification and platform matrix

Flutter 3.41.2 / Dart 3.11.0. `flutter analyze`: no issues. Aggregate `flutter test`: **103/103 passing** (normal test font); focused real-font capture suite **26/26 passing**. Tests use isolated memory/temporary stores. No person's active game or original phone Hive boxes were opened by the regressions.

| Target/evidence | Build | Visual/interaction result | Acceptance |
|---|---|---|---|
| Shared Flutter widget renderer | PASS | PASS: 1133×744, 744×1133 and 1366×1024, each with 2/3/4 seats; actual Mana font loaded, default mana controls bounded, long names/large totals, all fixed utility kinds, player/status/commander/dice captures. | Supports implementation review; not a browser or native run. |
| Web release | PASS: Pages-compatible build, 3.41.2 | NOT RUN in browser: supported Chrome and in-app browser surfaces unavailable. Known independent q→a replacement issue remains open. | Pending browser input/touch/modal acceptance on final build. |
| iOS tablet | PASS locally: unsigned simulator build, Mana font bundled; CI pending | NOT RUN: selecting Simulator reports the Mac locked. No unlock bypass or native mutation attempted. | Pending unlocked simulator/device checks, including actual small tablet, font rendering, touch, keyboard/modal orientation and tapaway. |
| Android tablet | PASS locally: release APK, Mana font bundled; CI pending | NOT RUN: native computer use blocked by the locked Mac; no Android UI session opened. | Pending emulator/device visual, font, touch and keyboard/modal checks. |

Release web command: `flutter build web --release --base-href /Doubling-Season/tablet/ --pwa-strategy=none`.

Local Android `flutter build apk --release` and unsigned iOS `flutter build ios --simulator --no-codesign` completed successfully without installation. Android APK contains `assets/flutter_assets/assets/fonts/mana.ttf` (6,544 bytes); iOS simulator app contains the local Mana font in `App.framework/flutter_assets/assets/fonts/mana.ttf`. These are bundle/build checks, not native UI acceptance.

The release font manifest includes the local `Mana` font at `assets/fonts/mana.ttf`; the tree-shaken font is present in build output. The tablet source font SHA-256 matches the original TS source font: `a23809f7c0af7f9866734216bdd73bce2cfedd67333f5cde86a9ee066fa69819`. Renderer images show the actual power/sword and toughness/shield glyphs, not merely text labels or icon code references. Platform-specific native bundling is additionally checked by CI compilation; final native pixel acceptance remains pending.

Final web `main.dart.js` SHA-256: `b690654e4ac290187fc9271d55386ef979fbf19762221d06e9746b3a0de9e745` (recheck after any source change).

## Evidence and rerun

The five supplied Library PNGs were materialized through the supported known-ID route to this consumer workspace, verified readable and visually inspected before layout decisions. IDs: `libfile_2961ba4c80948191bf373c781689fb86`, `libfile_aa85692afc2881918de29fefaf67f9a9`, `libfile_b85b8117a69c8191b14a7d1152f11a78`, `libfile_2110f219ce1881919b44f58030fb38c4`, `libfile_4208ce70f37c819190e2df901276899b`.

Twenty-seven final screenshot files are explicitly named `flutter-test-renderer-*`. They show the real widgets/fonts under the test renderer, including debug banners; they are not screenshots of the release web build or a native device. All 27 PNGs are saved to Library through the documented host-file create-only batches; local Library identities were persisted successfully. The prepared helper was unavailable before any operation, so it created no duplicate items. The [evidence manifest](validation/ui_feedback_2026-10-22_manifest.json) records every Library ID, filename, size/hash and implementation source hash. Local evidence is retained outside Git at `/Users/didymusbenson/Documents/Codex/2026-10-22/task-2/evidence`.

From `apps/tablet`, ordinary checks are `flutter analyze` and `flutter test`. To regenerate optional review captures, set `TABLET_CAPTURE_DIR` and run the three new modal/table test files; capture mode loads the real Mana asset and installed SDK text/icon fonts when available. CI does not require this machine-specific font cache because capture mode is optional.

## Remaining blockers and review gate

- **Pending native coverage:** attempted action `cua.getApp('com.apple.iphonesimulator')`, target Simulator; reason: Mac locked. Read could not proceed, no native action executed and no approval denial occurred. Complete native iOS/Android pixel, touch, keyboard, seated orientation and modal checks after manual unlock.
- **Pending browser coverage:** attempted supported Chrome selection and in-app-browser creation; both returned browser unavailable. No browser tab opened. Release build compiled and renderer checks completed; this does not resolve browser-specific keyboard behavior.
- **Known web input issue:** the separately tracked Name → Select all → q → a replacement remains unchanged and unaccepted. It did not block isolated widget/state/layout checks, and no browser fix is claimed.
- **Independent review required:** parent reviews the branch and evidence before any main merge or Pages redeployment. The original `/Doubling-Season/` and tablet `/Doubling-Season/tablet/` deployment remains unchanged.

## CI fallback-font correction

The first dispatched validation run (`39815612856`, implementation `859cb5d`) passed analysis and 101 tests, then found a 14px overflow in the narrow portrait large-total fixture under the test fallback font. The count renderer now bounds each numeric label with loose flex/scale-down while preserving its full semantic value. A new 1,000,000,000-total narrow-lane regression passes. Normal local tests pass 103/103; the real-font screenshot suite passes 26/26. Twenty-five deterministic captures are byte-identical after the correction; only random dice results differ. CI is rerun on the pushed correction rather than treating the earlier failure as acceptance.

A local-only review server serves the release build at `http://127.0.0.1:8784/Doubling-Season/tablet/` (HTTP 200 verified). No browser session was available here, so this is a handoff endpoint, not browser evidence.
