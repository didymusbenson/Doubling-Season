# Tablet corrective iteration — original token parity

**Status:** the complete follow-up passes 70 automated tests, tablet/root analysis, formatting, web release and iOS simulator builds. Eight native captures predate the newly-active-seat default-utility follow-up. Initial checkpoint CI passed; final follow-up commit/push/CI verification remains with integration. No full release acceptance is claimed.
**Branch:** `codex/tablet-token-parity-correction`.
**Reviewed baseline:** `dcac16bf6a988283f135d1a3a2fd5bf663c4ac08`.
**Corrected planning authority:** `012d9f321108353f40feeaaa5fc2f4560c29bc0e`
(full token parity/reuse) and `c986e53bcbfdb59fefdd191369e26525a255724a`
(compact controls/seat labels).

The original implementation plan at `0eea598` incorrectly encouraged a new
compact token composition. The corrected planning diff was inspected and applied
with `git apply --check` to the dossier's new `in_progress_features` location.
Existing first-pass implementation additions were retained. These corrections
are requirements, not evidence that all work below is complete.

## Review provenance

The following are immutable review identifiers supplied by the task; local
artifacts were read directly, not fetched from guessed cloud storage URLs.

| Artifact | Library ID | Local source at review time |
|---|---|---|
| Editable v4 report | `libfile_497a756d03a8819199b55f5fa9c183f0` | `tripling-season-tablet-scorecard.txt` |
| Illustrated v4 report | `libfile_0441d6cfedcc8191b5ae1981742059a2` | `tripling-season-tablet-scorecard.html` |
| Evidence manifest | `libfile_be45c054dd588191b60c90049007bffb` | `qa-evidence-manifest.json` |

Local source directory: `/Users/didymusbenson/Documents/Codex/2026-10-21/task`.
It contains the 50-row `token-parity-matrix.txt`, original/source audits, and 48
screenshots in `qa-evidence`. Screenshot numbers below refer to that manifest.
Original compact quick-add screenshots 47/48 were visually inspected for this
correction; the other UI tracks record their own inspected views.

The [full original-token inventory](token_functional_parity.md) and
[existing-behavior audit](existing_behavior_audit.md) identify the original
source and deliberate operation semantics. Dormant/commented features do not
become parity obligations; known old bugs/global writes are not replicated.
Source-only observations remain distinct from exercised runtime findings.

## Boundaries and ownership

The original checkout was clean at the reviewed SHA. Work is isolated in a new
worktree; no user edits were reset or overwritten. Integration owns the final
branch/checkpoint and final checks. Parallel implementation ownership is:

- Token object and `board_service.dart`: compact original actions, token
  semantics and state mutation APIs; no independent controller edits.
- Main board/layout: `table_screen.dart` and theme, life/utility fit and compact
  mana spending; uses the token component API rather than recreating it.
- Detailed editors: token workspace/catalog/custom keyboard and completion APIs.
- Behavioral regressions: history/controller, reset/restore completion and tests.
- Documentation: mapped planning corrections and this explicit inventory.

The user explicitly authorized automated tablet regression tests. This overrides
the older manual-only instruction for `apps/tablet`; it does not alter phone-app
test policy. Manual and native validation remain separate requirements.

Preserve life/counters/self and partner commander damage; chronological global
undo/coalescing; separate token add/remove history; current persistence plus ten
archives; safe restore; source-owned global effects with read-only recipients;
seat-specific preset Replace/Append without changing unrelated gameplay;
keep-board versus complete reset; same TS database/feed and import. No six-seat,
foldable, store, signing or entitlement expansion is part of this correction.

Two-player mirrored player-local-left is settled. Four-player token-lane side is
an **open consistency question**, not a confirmed defect: retain the current
composition until that question is settled. Preserve the accepted three-player
empty-seat control region. No focused-seat fallback is introduced.

## Status discipline

Every token row below is a required parity item. `Pending` means the integration
track has not yet recorded a final disposition. `Source implemented` describes
code presence only. Use `Verified` only with the exact test/runtime evidence;
state narrow evidence limits. `Open` names unfinished work and is not an approved
scope exclusion. Do not promote a first-pass source-only observation to a pass.
Parent review is independent; this checkpoint does not self-certify perfection.

## Fifty-row token inventory

Original source anchors below are the review's pinned anchors at `dcac16b`.
`OCard` = `lib/widgets/token_card.dart`; `OItem` = `lib/models/item.dart`;
`OProvider` = `lib/providers/token_provider.dart`; `OBoard` =
`lib/screens/content_screen.dart`; `OEdit` =
`lib/controllers/token_edit_session.dart`; `OInline` =
`lib/widgets/inline_token_edit_field.dart`; `OStatus` =
`lib/widgets/token_status_sheet.dart`; `OCounters` =
`lib/widgets/token_counter_management_sheet.dart`; `OCounterSearch` =
`lib/screens/counter_search_screen.dart`; `OSplit` =
`lib/widgets/split_stack_sheet.dart`; `OSearch` =
`lib/screens/token_search_screen.dart`; `OCustom` =
`lib/widgets/new_token_sheet.dart`; `OCreate` =
`lib/services/token_creation_service.dart`; `OMerge` =
`lib/services/token_merge_compatibility.dart`; `OArt` =
`lib/widgets/artwork_selection_sheet.dart`; `OArtDisplay` =
`lib/widgets/mixins/artwork_display_mixin.dart`; `OCrop` =
`lib/widgets/cropped_artwork_widget.dart`; `OSummary` =
`lib/widgets/status_sheet.dart`.

| ID | Original behavior / acceptance obligation | Original source | Corrective disposition and evidence |
|---|---|---|---|
| 01 | Identity, amount, tapped/sick, counters, art and order persist as one token object. | OItem:10–175 | Source retained: `TokenState.toJson/fromJson` includes identity/status/counters/art/options/extra; seat token-list order persists. Full serialization/failure matrix remains unverified. |
| 02 | Nonnegative quantity; tapped/sick bounded by total; zero entries remain dimmed. | OItem:34–74; OCard:281–282 | Source implemented/retained: quantity bounds, tap/sick clamps and zero dimming; regressions added in `board_service_regression_test.dart`. Included in passing 70-test integrated suite; broad native boundary matrix remains unverified. |
| 03 | Full-width square joined rows, left7px identity rail, art behind readable content. | OBoard:348–365; OCard:288–325,383–400 | Source implemented: joined `TabletTokenCard` surfaces, 7px identity rail and shared `TableArtworkSurface`; final visual/contrast review pending. |
| 04 | Name, type and P/T form a compact hierarchy; long P/T gets stacked layout. | OCard:344–370,433–466,1639–1768 | Source implemented: expanded name/type wrap; P/T constrained to 88px and wraps. Long-text and text-scale acceptance pending. |
| 05 | Prominent ready/tapped/sick icon counts; expanded status target opens focused controls. | OCard:481–531 | Source implemented: amount/ready/tapped/sick icon strip opens focused token status editor (`tablet_token_card.dart`, `token_pages.dart`). |
| 06 | Direct quantity plus/minus on compact and expanded object. | OCard:1172–1227 | Source implemented: direct quantity minus/plus in compact and expanded object; original zero-row retention remains. |
| 07 | Quick-add creates/merges a clean result instead of inheriting source counters. | OCard:1468–1496; OMerge:7–12; OCreate:84–131 | Source implemented: clean unchanged source grows in place; modified source remains and clean exact/art-compatible result merges or inserts adjacent. Rules/identity/undo regressions added. |
| 08 | Hold plus adds base 10; hold minus removes current amount; counter hold adds base 10. | OCard:1177–1178,1215–1223,1279–1285 | Source implemented: hold plus adds base 10, hold minus removes current amount, hold counter adds base 10. Actual native hold behavior pending. |
| 09 | Separate tap-one and untap-one, with hold-all counterparts. | OCard:1230–1249 | Source implemented: separate tap-one/untap-one and hold-all callbacks through clamped `tapTokens`; regression added. |
| 10 | Creation/quick-add sickness follows enabled setting, creature/PT and no haste. | OProvider:166–181; OCard:1252–1265 | Source retained: creation/increment sickness eligibility and setting; haste/disabled condition regressions added. Final original-comparison run pending. |
| 11 | Increasing Total in focused status adds eligible newly created quantity to sickness. | OStatus:26–59 | Source implemented: positive absolute total adds only eligible new sickness without token multipliers; regression added. |
| 12 | Total/Tapped/Sick steppers and tap-number-to-Set in one focused status sheet. | OStatus:64–118,142–198 | Source implemented: dedicated Total/Tapped/Sick page with steppers and exact numeric Set (`_tokenStatus`). |
| 13 | Copy creates one untapped, counter-free token, art retained, adjacent insertion; sickness recomputed. | OProvider:302–365 | Source retained: `copyToken` creates one untapped counter-free token, keeps identity/art/options and recomputes sickness; regression added. |
| 14 | Copy is directly available on compact object and bypasses token multiplication. | OCard:1291–1313 | Source implemented: direct compact Copy; detail text no longer claims multiplication. One-token policy unchanged. |
| 15 | Split inherits identity/art/counters, allocates tapped first or untapped first, clears both sickness counts, inserts adjacent. | OSplit:314–389 | Source retained/refactored: `_splitOne` deep-copies identity/counters/art, allocates taps in either order, clears both sickness counts and inserts adjacent; regressions added. |
| 16 | Split has direct card button, bounded quantity controls and before/after amount/tapped preview. | OCard:1315–1335; OSplit:143–280 | Source implemented: compact Split opens focused bounded quantity/tapped-first form with original/result totals and tap preview. |
| 17 | Auto-merge only compatible clean identity/art; no generic manual-merge card action. | OMerge:7–48; OCreate:84–146 | Source corrected by route: search primary creates fresh stack; eligible companions/quick-add retain exact clean identity/art merge policy. Earlier manual-merge UI is extra, not an original parity requirement. |
| 18 | +/-1 PT counters cancel; independent +1/+0,+0/+1 and arbitrary counters remain distinct. | OItem:125–142,193–267 | Source retained: opposite PT cancellation and independent/custom counters. Counter/split/copy regressions added; broad modifier matrix pending. |
| 19 | Visible counter pills; expanded pill opens management, Add target and overflow sizing. | OCard:634–820 | Source implemented: original `CounterPillView` reused in bounded horizontal strip; pills and add target open counter management. |
| 20 | Every counter supports direct numeric Set, including zero. | OCounters:56–90,128–204,249–263 | Source implemented: exact Set including 0 through `setCounter`, bypassing placement multipliers; counter-number workspace regression added. |
| 21 | Searchable predefined counters plus custom-name creation. | OCounterSearch:39–42,58–99,356–381 | Source implemented: original `CounterDatabase` definitions searched by name, plus custom-name creation. |
| 22 | Counter quantity plus Add to All within stack or integrated Split & Add to One. | OCounterSearch:110–352 | Source implemented after exact original recheck: counter-search quantities apply raw; `addSelectedCounter` adds to stack; one-command `splitAndAddCounter` appends inherited-counter/art token untapped/nonsick and retains source bounded status. Distinct from normal Split. Regression added. |
| 23 | Custom counter reaching zero is removed from object's counter list. | OItem:282–291; OCounters:196–203 | Source implemented: custom counter definitions removed when decremented or Set to 0. Keep-board zero token entries remain a separate policy. |
| 24 | Numeric P/T includes counter bonuses; variable P/T uses signed suffix. | OItem:200–225 | Source retained: numerical P/T adds PT/independent bonuses; symbolic P/T preserves signed suffix. Symbolic/native rendering acceptance pending. |
| 25 | Modified P/T highlighted orange; change pop animation signals update. | OCard:40–87,1773–1794 | Source implemented: orange modified P/T and 500 ms pop on value changes. Reduced-motion/animation measurement pending. |
| 26 | Compact abilities show up to 3 lines; expanded abilities scroll locally. | OCard:864–904,1674–1686 | Source implemented: compact ability text up to 3 lines; expanded ability area locally scrolls within 102px. |
| 27 | ManaText renders ability mana/tap symbols. | OCard:901,1677,1745 | Source reused: original `ManaText`/mana icons render abilities and status instead of raw symbol braces. |
| 28 | Name/type/basePT/abilities edit directly where displayed. | OCard:452–465,839–982; OEdit:15–23,51–129 | Source implemented: actual displayed `TextField` owns the same controller/selection as the player-facing keyboard. Component regression passes shared ownership, scoped commit and OS-keyboard suppression. Native capture 08 shows matching in-row/keyboard text and caret after cursor movement. The modal keyboard retains focus/caret and can cover lower fields; broad native reach/selection acceptance remains open. |
| 29 | Inline WUBRG toggle bar with selected states and color semantics. | OCard:534–556; lib/widgets/inline_color_identity_bar.dart:16–85 | Source reused: original `InlineColorIdentityBar` with WUBRG selected-state toggles; scoped edit command. |
| 30 | Edit session preserves raw empty values and unrelated token state. | OEdit:72–73,91–149 | Source implemented: `editToken` preserves raw empty text and changes only supplied properties. Custom-definition name validation remains a distinct creation rule. |
| 31 | Focus loss/submit/action commits; failed save retains text and vetoes collapse. | OEdit:15–23,91–129; OCard:414–430,1559–1571 | Source implemented: single keyboard commits on exit, retains failed token draft and supports close/retry under D41. Keyboard/failure widget regressions added; process-death draft persistence not promised. |
| 32 | Whole blank surface expands/collapses, one expanded object; tapping another collapses first; animated reveal. | OCard:202–223,264–280; OBoard:61–107 | Source implemented: whole-surface animated expansion; layout retains deliberate collapse-first/fresh-tap behavior. Native expansion/transfer acceptance pending. |
| 33 | Long-press drag reorders; active expansion/editing guards reorder; durable order. | OBoard:369–380,734–788 | Source retained: per-lane delayed drag with reorder disabled while an item is expanded; active modal input blocks table. Actual native drag/ordering acceptance pending. |
| 34 | End-to-start swipe deletes, with red feedback; inline editing blocks gesture. | OBoard:384–412 | Source implemented: end-to-start Dismissible with red feedback, explicit confirmation and persisted deletion/global undo; inline input disables gesture. Native swipe acceptance pending. |
| 35 | All/Recent/Favorites/Custom tabs, favorite toggle, temporary search. | OSearch:20,75–85,213–303,368–378 | Source retained: All/Recent/Favorites/Custom tabs, favorite toggle and temporary search; full catalog lifecycle acceptance pending. |
| 36 | Color and category filtering plus explicit clear/search discovery. | OSearch:185–211,246–280,1114–1119 | Source implemented: original exact WUBRG/colorless filter with categories/text and clear control (`TabletCatalog.search`, token search page). |
| 37 | Selection resets quantity 1; +/- and quick 1–5 plus direct integer entry. | OSearch:635–640,783–846,889–914 | Source implemented: result selection resets quantity 1; direct numeric field, +/- and quick 1–5 controls. Regression coverage added. |
| 38 | Create-tapped toggle, final rules/companion preview, bounded quantity and busy guard. | OSearch:878–968,1040–1061 | Source retained: create-tapped, bounded quantity, final rule/companion preview and busy guard; primary fresh-stack merge rule corrected. Broad cap/companion/multitap runtime matrix pending. |
| 39 | Explicit Create completes quantity/search journey and returns to board. | OSearch:1068–1071 | Source implemented: successful Create invokes workspace completion after save; failed save retains editor. Widget regression added. |
| 40 | Custom identity authoring, reusable definition, colors and optional staged native art. | OCustom:70–185,377–419 | Source implemented: reusable custom identity/colors and optional staged native image/crop before saving definition. Native picker/cancel/staging acceptance pending. |
| 41 | Attached artwork entry; saved preferred art identity and copies/options. | OCard:591–605,1006–1117 | Source implemented: attached expanded artwork icon opens dedicated selection; seat/game preferences retained. Copy/split source metadata retained; preset/art lifetime acceptance pending. |
| 42 | Current selection/credit, variants, large confirm preview, download-all/loading states. | OArt:67–117,218–355,390–427,533–690 | Source implemented: current-selection marker, credits, candidate preview/confirm and download-all count. Workspace scroll wrapping, eager scope capture/mounted checks and catalog credit enrichment by URL now present; 24-option scroll and invalid-art selection preservation pass in widget tests; native selection/download verification pending. |
| 43 | Native upload/crop/reselect/replace/remove; original web intentionally lacks upload. | OArt:340–387,743–1159 | Source implemented: native picker, crop/rotation/replace/remove and immutable media; saved uploads remain selectable through artwork options. Original web upload exclusion retained. Crop error/retry/cleanup and retained-image lifetime guards are present; 90/180/270-degree encoded pixels and 4:3 bounds pass regression tests. Native picker/cancel/crop execution remains unverified. |
| 44 | Full/fadeout art modes; stable crop/reveal, cached immediate/new-art fade, protected text. | OArtDisplay:90–135,256–466; OCrop:246–310 | Partial source: full/fadeout selector and shared surface exist. Original right-half horizontal fade restored after source review; full art uses stable width fitting during animated expansion; synchronous cached frames appear immediately and asynchronous frames fade 160 ms. Detailed native crop/reveal comparison remains unverified. |
| 45 | Offline/cache failures preserve art selection; async selection awaits validation; stale work guarded. | OCard:1009–1114; OArtDisplay:38–205 | Partial source: validate image decode before selection; selected metadata retained on failures and scope passed. Eager scope capture before async validation, mounted guard and corrupt-download cache eviction added after source review; runtime failure/retry verification pending. |
| 46 | Emblem centering/no tap/PT/copy/split normal group; plus bypasses token rules. | OItem:178–181; OCard:443–450,1208–1210,1229–1337 | Source implemented: emblem increment bypasses token rules; card omits normal tap/PT/copy/split group and service rejects inapplicable actions; regression added. |
| 47 | Scute-specific compact operation counts stacks, evaluates rules and resolves companions/art. | OCard:1339–1419; OProvider:515–667 | Source implemented: dedicated Scute action counts local Scute stacks, applies rules/companions/art as one command; regression added. Native control exercise pending. |
| 48 | Expanded-state/status/editor/color/art semantics, visible-cursor scrolling, scaling-aware pills. | OCard:264–272,486–492,592–618,705–799; OInline:39–69 | Partial source: expanded/status/editor/color/art named semantics and viewport-aware keyboard; original pills reused. VoiceOver, text scaling and rotated native traversal remain unverified. |
| 49 | Aggregate token status/power summary and bulk/utility integrations. | OSummary:64–215,274–353; OProvider:390–513,852–1030 | Source implemented: seat token summary path reports total/type/status and known/variable power, including independent +1/+0 bonus. Existing bulk/utility integrations retained; summary arithmetic/exclusions and 24-variable-row scrolling pass in added widget tests; native and broad utility integration acceptance pending. |
| 50 | Autosave, stale-object resolution, ordered creation/events, recoverable mutations. | OProvider:31–39,70–163; OEdit:91–129; OCreate:72–184 | Source retained: scoped JSON/session command writer and acknowledgement/history publication; regressions added for failed save/stale scope/persistence/archives. Full interruption/concurrency matrix pending. |

Key interpretation safeguards: quick-add must create/merge clean results without
moving the source's counters onto new tokens; do not change all merge routes to
fix that one bug. Search primary creation retains its original fresh-stack
policy. Fresh Copy remains one counter-free untapped token with recomputed
sickness; basic Split inherits counters/art, allocates tap state and clears both
sickness counts. Counter search's integrated Split & Add to One instead appends
one untapped/nonsick token, preserves source bounded remaining status and uses
the raw selected counter quantity. Add to All also applies that raw quantity;
quick/management counter increments retain rule modifiers. Independent P/T
counters already existed and must stay intact.
Original expansion is collapse-first: another row's first tap closes the open
row, then a fresh tap opens it. Required new modal/draft rules supersede old
nondismissible error dialogs and snackbars.

## Other report findings

| Review ID | Required correction or disposition | Evidence at first-pass review | Corrective status |
|---|---|---|---|
| F01 | Default Storm and Mana usable in full small-tablet landscape; no inaccessible utility body | 01, 07, 09 | Source implemented: compact life-attached tools, single-row Storm and two/three-column Mana. Component layout tests pass; native captures 01/05/07 show default utilities fitting the observed mini/larger states. |
| F02 | True inline quick token edits; reserve central workspace for detailed work | 04–06; token rows 28–31 | Source implemented: displayed token field owns the shared editing controller; single player-facing keyboard operates it directly. Component regression passes, and native capture 08 plus the reported tapaway exercise verify one rotated name-edit flow. Modal focus/caret stays in the keyboard preview, which can cover lower fields; broad reach/selection acceptance remains open. |
| F03 | Successful Create completes search/quantity journey and returns to board | 02; token row 39 | Source implemented; widget regression passes. Integration reports repeated native Create success/exit, including opposite-facing Player 2. Full catalog/multitap matrix remains unverified. |
| F04 | Successful reset/restore returns to a usable board, no stale-game blocker | 18 | Source implemented; widget regression passes. Native captures 03/04/07 show usable boards after reset/restore; integration reports automatic workspace completion. Full restore failure matrix remains unverified. |
| F05 | History/undo labels describe actual clamped/rule-adjusted change | 10–13 | Source implemented: serialized effective delta and separate affected-seat history labels; meaningful regression coverage added. Included in passing 70-test integrated suite; broad native boundary matrix remains unverified. |
| F06 | Wipe history identifies affected seats and meaningful action names | 16 | Source implemented: serialized effective delta and separate affected-seat history labels; meaningful regression coverage added. Included in passing 70-test integrated suite; broad native boundary matrix remains unverified. |
| F07 | Compact mana supports spending without compulsory full-table form | 09, 07 | Source implemented; widget regression passes. On the captured native checkpoint, integration exercised Player 1 plus/plus/minus: final mana 1 and the board remained visible. |
| F08 | Reconcile extra custom utility authoring with curated D37 scope | 27 | Source corrected: custom tracker/toggle authoring entry removed from utility UI; curated utility discovery/visibility retained. |
| C01 | Fresh token selection starts quantity at one | Source only; row 37 | Source implemented with result-selection reset and direct quantity controls; automated subset passes; final native flow evidence pending. |
| C02 | Long expanded utility names remain readable | Source only | Source implemented: expanded utility name has no max-line truncation. Native long-name/text-scale review pending. |
| C03 | Multiline input has usable Return/newline through custom keyboard | Source only | Source implemented: multiline Return/newline distinct from Done; widget regressions added. Native composition remains unverified. |
| C04 | Copy text accurately describes existing one-fresh-token behavior | Source only; rows 13–14 | Source corrected: Copy wording now describes one fresh token; no multiplier behavior change. |
| D01 | Four-seat token side remains open; preserve two-seat local-left and three-seat empty controls | 01, 19, 20, 22 | Preserved decision boundary; no new four-seat geometry mandated. |
| Compact chrome | Familiar actions icon-led with semantics; seat name only in life counter; meaningful text/shared target context retained | 01, 05, 14, 19, 22, 46, 48 | Source implemented: compact life-attached tools, single-row Storm and two/three-column Mana. Component layout tests and the linked native views support the observed fit; VoiceOver and physical touch acceptance remain unverified. |

D22/D37 default provisioning is now explicitly reconciled: under keep-board,
a newly active seat absent from the prior game receives fresh visible Mana and
Storm utilities with new IDs and zeroed values. Remaining seats keep their
chosen reusable utility setup; complete reset still clears utilities, removed
setup is not resurrected, and archive restoration remains exact. The
[reset/utility contract](07_utilities_tokens_and_decks.md#accepted-curated-utility-customization)
and scoped controller branch implement this narrow rule. A new 4 → 2 → 3
regression checks removed custom/hidden setup does not return, fresh defaults
are zeroed, and a subsequent complete reset stays empty; the targeted history
suite passes 9 tests and the final combined rerun passes 70 tests.
Captures 04/06 show the preceding empty-lane behavior, which is now corrected;
they are before evidence for this follow-up, not acceptance of the new defaults.
No new native test is claimed after the Mac locked.

## Final validation record

The following results were read from integration logs or reported by the
integrating owner. Automated/widget checks and native runtime observations are
separate. Commit/remote-CI evidence remains for the integrating owner to fill
in before claiming remote checkpoint readiness.

| Check | Result / evidence |
|---|---|
| Corrected planning diff mapped safely | Passed: read diff; current files compared to pre-correction baseline; mapped `git apply --check` passed before application; implementation additions retained. |
| Complete 50-row inventory | Present: source implementations/partials/open concerns recorded for all 50; no full runtime parity claim. |
| Source lint/analysis and meaningful regressions | Passed final combined run including the reset-default correction: 70 tests; tablet/root `flutter analyze` and formatting checks pass, confirmed by integration. Logs: `/tmp/tablet-correction-tests-final.log`, `/tmp/tablet-correction-analyze-final.log`, `/tmp/tripling-root-analyze-final.log`, `/tmp/tablet-correction-format-final.log`. |
| Web build/runtime | Passed final build: `flutter build web --release` produced `build/web`; `/tmp/tablet-correction-web-build-final.log`. Browser runtime on latest build pending in this record. |
| Native simulator build/runtime | Passed final simulator build: `flutter build ios --simulator` produced `Runner.app`; `/tmp/tablet-correction-ios-build-final.log`. Integration reports mini clean quick-add, partial tap, absolute-total sickness, repeated Create including opposite-facing Player 2, reset and archive-restore completion. Captures 01–07 show intermediate-build states; 08 shows rotated input at the 69-test native checkpoint. The rebuilt `Runner.app` includes the reset-default correction but was not installed after the Mac locked; no native rerun is claimed. Picker/crop remains unverified. |
| Small tablet 1133×744 and 744×1133 | Passing layout widget checks for 2/3/4 seats, safe-area and large-number stress. Native mini landscape/portrait captures show 2/3/4-seat states; not every seat-count/orientation/input combination was exercised natively. |
| Larger tablet; 2/3/4 seats | Passing layout widget checks at 1366×1024 for 2/3/4 seats. Capture 05 shows the larger iPad Pro simulator in four-player landscape; larger native 2/3-seat checks are not claimed. |
| Rotated input, dismissal/no click-through, repeated flows | Passing keyboard/workspace widget cases. At the captured native checkpoint, Player 2 Name sequence select-all → q → a → cursor-left → s produced `qsa` in both token/keyboard (08). Integration then tapped away on Player 4 life: editor committed/dismissed, all life stayed 40, no new workspace opened. This is one exercised rotated path, not full IME/accessibility acceptance. |
| Before/after screenshot mapping | Before: source manifest 01–48. After: seven intermediate captures plus the 69-test checkpoint capture 08; all predate the later newly-active-seat defaults correction, with exact file metadata and scope in the [evidence manifest](correction_evidence/evidence_manifest.json). |
| Remote branch SHA and relevant CI | Initial code checkpoint `dafa5623777b4c402e57c2a45cd3000dfe9346ee`: both CI jobs succeeded ([run 39728578863](https://github.com/didymusbenson/Doubling-Season/actions/runs/39728578863)), verified by integration. The subsequent reset-default correction and documentation require their own final commit/push/remote-CI verification; that follow-up is pending. |

## Native screenshot evidence

These screenshots were opened and visually inspected. Captures 01–07 come from
the integrated simulator run before the final inline-controller/crop-rotation
follow-ups; capture 08 uses the build after the 69-test run. All eight precede
the later newly-active-seat utility-default correction. They establish
the narrow visible states below. The simulator files preserve their capture
orientation; landscape content may appear sideways in a generic image viewer.
The [manifest](correction_evidence/evidence_manifest.json) records raw PNG
dimensions, UTC file timestamps, SHA-256, related findings and per-image limits.
Mini files are 1488×2266 pixels; the larger iPad Pro file is 2064×2752 pixels.
These are capture pixels, not a claim that the large simulator equals the
1366×1024 logical widget-test fixture.

| Capture | Related review rows | Visible evidence and limit |
|---|---|---|
| [01 — mini landscape clean add](correction_evidence/01-native-mini-landscape-clean-add.png) | 07, 09; F01, F07; compact chrome | Four seats remain on the board. The modified Saproling source retains its counter and a separate clean Saproling exists; source shows partially tapped status. Default Mana/Storm are visible. The image alone does not prove the preceding command or undo. |
| [02 — focused status](correction_evidence/02-native-status-set-sickness.png) | 11, 12 | Player 1's focused token status shows Total 10, Tapped 1 and Summoning sick 10, with explicit target context. The preceding total edit is reported by the integrating owner; full boundary coverage is automated, not inferred from the image. |
| [03 — two-seat keep-board reset](correction_evidence/03-native-two-seat-reset.png) | F04; D01 | Usable two-seat board, mirrored player-local-left lanes, retained zero-count token entries and life 40; no stale-game workspace blocker is visible. |
| [04 — three-seat reset](correction_evidence/04-native-three-seat-reset.png) | F04; D01 | Usable three-seat board and the empty-slot shared-control region. Player 1/2 retain utilities; newly active Player 3 shows utility discovery. This is before evidence for the subsequently corrected fresh-default provisioning, not the final reset behavior. |
| [05 — larger four-seat board](correction_evidence/05-native-large-four-seat.png) | F01, F07; compact chrome | Four empty token lanes, life 40 and all four default Mana/Storm sections fit in the isolated larger-tablet simulator. This is a separate empty synthetic state, not populated-token acceptance. |
| [06 — mini three-seat portrait](correction_evidence/06-native-mini-three-seat-portrait.png) | F01, F07, F04; D01 | Three seats plus empty-slot controls fit portrait. Player 1 retains two zero-count token entries; Player 1/2 Mana/Storm remain visible. Player 3 still shows utility discovery; this predates the fresh-default correction and is not evidence of its final behavior. |
| [07 — mini four-seat restored portrait](correction_evidence/07-native-mini-portrait-restored.png) | 07, 09, 11; F01, F04 | Restored synthetic board shows life 40, Player 1's modified ten-count stack plus a separate clean one-count stack, and visible default utilities. Integration reports successful archive restore with automatic workspace dismissal; image alone does not establish complete archive/timeline equality. |
| [08 — rotated inline keyboard checkpoint](correction_evidence/08-native-rotated-inline-keyboard.png) | 28, 31, 48; F02 | Player 2 Name shows `qsa` in both actual token field and custom-keyboard value, with the caret between `s` and `a`. Integration reports 180-degree player-facing input. The subsequent tapaway and direct-mana checks are reported flow evidence, not states captured in this image. |

## Passing automated subset

The final combined run passed 70 tests in nine files under `apps/tablet/test`:
`board_service_regression_test.dart`, `table_history_regression_test.dart`,
`workspace_regression_test.dart`, `player_keyboard_regression_test.dart`,
`token_workspace_regression_test.dart`, `table_layout_regression_test.dart`,
`artwork_summary_regression_test.dart`, `tablet_token_card_regression_test.dart`
and `artwork_crop_regression_test.dart`.

It checks clean quick-add/source identity/rules/companions and undo; fresh Copy;
normal Split and distinct counter-search Split & Add to One; exact counter Set,
zero removal and placement modifiers; sickness and partial tap; emblem/Scute
paths; actual clamped history deltas and affected-seat labels; failed-save
rollback; reset/restore/archive limits and stale scope; fresh default utilities
for newly active seats under keep-board without resurrecting removed setup;
Create completion;
keyboard newline/tapaway/retry and rotated overlay; actual shared-controller
inline token editing; summary arithmetic/exclusions and long artwork/summary
scrolling; invalid-image selection preservation; 90/180/270-degree crop pixels
and output bounds; color filters; and default
mana hit-testing/spending across three sizes and 2/3/4 seats. This is a tested
subset of the full inventory, not native accessibility, picker, crash-recovery,
physical touch or complete feature acceptance.

## Source-review findings sent to integration

Read-only review of the new artwork/summary paths found the following before
final verification. Root applied the listed source fixes; these are not reproduced
native-failure claims or runtime acceptance.

- Resolved in source: artwork/summary are now wrapped in workspace `_list`
  scrolling, keeping lower controls reachable in the bounded keyboard host.
- Resolved in source: artwork captures game scope eagerly in `initState` and
  checks `mounted` after asynchronous validation before commit. The old lazy
  capture could bind to a later keep-board reset.
- Resolved in source: crop encoding catches errors, shows in-context retry
  information, disposes render resources and clears busy state.
- Resolved in source: fadeout now uses original right-half art with a horizontal
  transparency fade. Full rendering keeps width scale stable; cached frames
  render immediately, newly decoded frames fade 160 ms. Detailed native crop/reveal
  comparison still needs evidence.
- Resolved in source: failed decode invalidates only redownloadable cached
  bytes, retaining selected metadata and immutable media. Runtime retry remains
  unverified. Stored option lists now enrich missing artist credits from the
  current catalog by URL without changing persisted selection identity.
- Resolved in source: original native crop rotation now has clockwise and
  counterclockwise controls, matching preview/export transforms and 4:3 bounds.
  Three pixel-based encoding regressions pass. Upload replacement/reselect
  remain available through immutable options; actual native picker/crop use
  remains unverified.

## Remaining risk and handoff

Additional native counter-management exercise stopped when Computer Use reported
that the Mac was locked and could not be unlocked automatically. The attempted
action was a read of the isolated mini simulator's controls before opening
Player 1's token counter manager; no counter mutation was issued. This coverage
is pending a manual unlock, not denied by approval review. The earlier native
flows and eight screenshots were already completed. A preceding automated drag
attempt did not trigger swipe deletion, so it does not establish native gesture
acceptance. Source and automated counter coverage are recorded above.

The later newly-active-seat default-utility correction has source/regression
evidence only. No additional native UI run was attempted after the lock; this
coverage limit is carried into the independent parent review.

Beyond the exercised native flows above, untested input/picker paths,
accessibility/scaling, original art workflows, concurrent failure recovery and
full parity remain unaccepted. Do not turn a difficult unimplemented feature
into an approved omission. Any actual access/approval blocker must identify the
action, target, reason, completed work, and whether it was denied, pending, or
uncertain. No new software installation, signing/account/security change,
store upload, personal game-data mutation, force-push or main merge is authorized.
