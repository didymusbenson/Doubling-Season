# Tablet requirements and readiness audit

**Audited:** 2026-10-23 (America/Phoenix), source `a79a381` / PR #47.
**Verdict:** feature-category implementations are present; not all original
requirements are verified met or exceeded. **Do not consolidate the initial
dossier into an `MVP` directory yet.** No application code changed in this audit.

## Finding and the user's condition

The app has progressed beyond a prototype to a separate Android/iOS/web product
with scoped gameplay, persistent history, presets, artwork and an installed
physical-iPad Release build. No confirmed missing feature category was identified
in this source/document review.

That does not establish that every initial requirement is met. The original
dossier also requires small-tablet/device coverage, native parity/input,
accessibility and durable recovery acceptance. Those obligations remain partly
unverified. Implementation routes, 369 passing regressions, simulator builds
and one successful physical launch do not prove those remaining requirements.

The user's condition for moving the initial docs into `MVP` is therefore
**not established**. Keep the original dossier paths, requirements, decisions,
research and evidence in place. Prepare feedback collection now; revisit the
consolidation when the remaining requirements have objective acceptance
evidence or the user explicitly changes that gate. No existing requirement is
waived or reclassified as a later feature just to close this phase.

The original [R01–R17 traceability](01_product_and_scope.md#requirements-and-traceability),
[C01–C16 requirements](README.md#confirmed-direction), and accepted decisions
are the comparison set. Proposed architecture/numeric budgets and explicitly
deferred features are not silently promoted into new requirements. Later user
decisions supersede older contradictory recommendations.

## Requirements coverage

"Present" below means an implementation route was identified, not that all
manual scenarios for that route passed. Test references are the existing suite,
not new tests or a newly executed end-to-end acceptance campaign.

| ID | Implementation evidence | Acceptance disposition |
|---|---|---|
| R01 — life per player | [Controller life commands](../../../../apps/tablet/lib/state/table_controller.dart#L445), [table UI](../../../../apps/tablet/lib/ui/table_screen.dart), [half-stepper tests](../../../../apps/tablet/test/board_half_stepper_regression_test.dart) | Present; four-seat physical launch observed. Sustained seated use remains field testing. |
| R02 — separate token/utility lanes | [Table UI](../../../../apps/tablet/lib/ui/table_screen.dart), [layout tests](../../../../apps/tablet/test/table_layout_regression_test.dart) | Present for 2/3/4 seats; broad device/touch acceptance open. |
| R03 — originating-player context | [Captured board scope](../../../../apps/tablet/lib/features/board_service.dart#L14), [workspace scope](../../../../apps/tablet/lib/ui/workspace/table_workspace.dart#L163) | Present; stale-scope/failure regressions exist. Complete native concurrent-action matrix unrun. |
| R04 — independent persistent ordering | [Board reorder](../../../../apps/tablet/lib/features/board_service.dart#L919), [visible utility reorder](../../../../apps/tablet/lib/features/board_service.dart#L1168), serialized seat state | Present; native drag/restart and accessibility-reorder coverage remains open. |
| R05 — safe generated/replacement tokens | [Scoped board/rules calculation](../../../../apps/tablet/lib/features/board_service.dart#L102), [rules calculator](../../../../apps/tablet/lib/services/scoped_rules_calculator.dart), [board tests](../../../../apps/tablet/test/board_service_regression_test.dart) | Present; all-utility/companion/failure native matrix remains open. |
| R06 — intentional central game controls | [Game workspace](../../../../apps/tablet/lib/ui/workspace/game_pages.dart), central hub and scoped wipe/history/reset commands | Present; game origin and affected seats are separate, as clarified by D36. |
| R07 — reuse Flutter/domain behavior | Separate [app manifest](../../../../apps/tablet/pubspec.yaml) uses the root path dependency; [domain inventory](../../../../apps/tablet/docs/domain-parity.md); [50-row token inventory](corrective_iteration.md) | Present. The inventory records narrow partial/unverified artwork/accessibility evidence, not blanket parity acceptance. |
| R08 — usable tabletop life/lists | Adaptive layouts, compact controls, scrolling and mini/full-size widget fixtures | Implemented approach; **small physical tablet and full seated usability gate still open**. |
| R09 — undo safety | [Latest-action undo](../../../../apps/tablet/lib/state/table_controller.dart#L402), [history tests](../../../../apps/tablet/test/table_history_regression_test.dart) | The old local-undo proposal is superseded by accepted D16: latest action globally. Arbitrary older/per-seat undo is not a missing MVP feature. |
| R10 — phone data safety | [Separate entry point](../../../../apps/tablet/lib/main.dart), [isolated storage namespace](../../../../apps/tablet/lib/storage/table_repository.dart#L23), explicit copy-only setup import | Isolation present; no root app code changed in PR #47. Broader legacy fixture/device regression evidence remains open. |
| R11 — local play/offline resume | [Aggregate repository](../../../../apps/tablet/lib/storage/table_repository.dart), bundled catalog fallback, immutable local media | Present; real interruption, corrupt-container and offline cold-start matrices are not fully accepted. |
| R12 — mana/storm | Authoritative seat values, [mana commands](../../../../apps/tablet/lib/state/table_controller.dart#L579), curated show/hide/order; locks/Empty/conversion implemented | Present with focused tests and earlier browser observations. Complete native interaction/failure coverage remains open. |
| R13 — one player-facing keyboard | [Player keyboard](../../../../apps/tablet/lib/ui/workspace/player_keyboard.dart), rotated shared workspace, [keyboard](../../../../apps/tablet/test/player_keyboard_regression_test.dart)/[modal](../../../../apps/tablet/test/player_modal_regression_test.dart) regressions | Present; native selection/composition, assistive input and the full orientation matrix remain unaccepted. Full multilingual software IME is not implemented and is not silently claimed. |
| R14 — separate 2–4-player Android/iOS/web app | Separate product IDs/entry/storage; all three platform builds; count-specific layouts and 3-player empty slot | Implementation/build coverage present; one physical iPad model does not prove the complete platform/device support matrix. |
| R15 — full tracker fundamentals | Life, energy/poison/experience, blessing, monarch/day-night; [self/partner source ledgers and coupled/independent corrections](../../../../apps/tablet/lib/state/table_controller.dart#L457); commander UI/tests | Present. Extended optional inventory was not automatically approved; full native tracker/boundary scenarios remain open. |
| R16 — chronological persistent history | Serialized command writer, 1500ms compatible grouping, cross-player interruption, distinct add/remove, global latest undo and saved history | Present; fake-repository/focused restart tests do not establish every on-device crash/durability guarantee. |
| R17 — resets, persistent seats and archives | [Reset/restore](../../../../apps/tablet/lib/state/table_controller.dart#L631), two reset modes, hidden seat customization, rule disable/reset, save-current-before-restore, ten-archive retention | Present with scoped regressions. Fault injection during real archive persistence/eviction and complete native restore acceptance remain open. |

Other accepted requirements also have source implementations: TS deck import
and the shared hash-validated catalog feed; local/global source ownership;
Replace/Append zero-state setup loading; game-and-seat artwork preferences;
curated utility hide/restore; full-table modal blocking with consumed tapaway;
standard mixed dice with individual results and totals; and free gameplay with
optional supporter cosmetics. See the [domain inventory](../../../../apps/tablet/docs/domain-parity.md)
and [carryover clarifications](implementation_carryover_clarifications.md).
Live supporter purchases remain unconfigured and unvalidated.

## Verified checkpoint evidence

- [PR #47](https://github.com/didymusbenson/Doubling-Season/pull/47) merged as
  `a79a381`. Its source tree equals tested feature commit `728f950`.
- [CI run 40043565398](https://github.com/didymusbenson/Doubling-Season/actions/runs/40043565398)
  passed analysis, all 369 tablet regressions, web release, Android release APK
  and iPad simulator build. The local run also passed analysis and 369 tests.
- Signed physical **Release 0.1.0+1** installed and launched on iPad Air
  13-inch (M3), iPadOS 26.6.2; rendered four-player board and installed icon
  visually inspected. [Handoff evidence](physical_ipad_handoff_2026-10-23.md).
- [Combined Pages deployment](https://github.com/didymusbenson/Doubling-Season/actions/runs/40044269495)
  passed; public source marker and tablet icon matched `a79a381`.

These observations supersede stale "not yet installed" statements for this
specific checkpoint. Earlier 70-test/simulator records remain historical and
do not establish acceptance of later source changes or broader native flows.

## Remaining original acceptance work

| Area | What is still needed | Original reference |
|---|---|---|
| Device/layout/table use | Actual iPad mini/small-tablet and Android representatives, complete 2/3/4-seat views, portrait/landscape, long populated lists, large text, reach and concurrent nonmodal touch | D06/D30; V30–V35; required tablet size matrix |
| Recovery and isolation | Real process interruption/write failures, unreadable containers, save acknowledgement, stale callbacks, multi-window writers, safe archive save/restore/eviction with preserved media and unrelated state | P2/P5; V10–V29, V45–V50 |
| Native feature parity/input | Original token/utility/artwork workflows, real picker/crop/share/import/export, holds/reorder, keyboard selection/rotation and modal barrier across orientations | D08/D11/D41; V11–V20, V34, V54–V59; 50-row inventory |
| Accessibility | VoiceOver/traversal, assistive input, large text, contrast and usable accessible reorder on hardware | D12; V30–V35; token inventory row 48 |
| Performance/extended play | Representative populated normal/heavy sessions, resume/offline behavior, memory, battery and thermal observations | P5 and performance experiments; candidate budgets are not promises |

No new failure is asserted merely because a case lacks evidence. Preserve these
as open validation items, not an automatic implementation backlog. Existing
confirmed requirements remain active; no initial documents are moved.

## Deferred work and release preparation

[Six-player expansion](six_player_expansion.md),
[foldable/closed-seat focus](foldable_phone_future_version.md), and
[extra keyboard options](custom_keyboard_options.md) remain deferred.
Networking, a general Magic rules engine and automatic mana payment were never
added to MVP scope. Full multilingual software composition needs an explicit
scope decision as well as validation; do not claim it works today.

Final product/store naming, live IAP product configuration, production Android
signing and TestFlight/App Store distribution remain separate release work.
The current development certificate expires November 8, 2026; profile lifetime
does not extend that certificate. No credential renewal is authorized here.

## Next action

Collect [field-test observations](next_pass/field_test_feedback.md), including
what works well. When the user has enough feedback, group related observations,
separate reproducible defects from design choices/open validation, choose a
bounded batch and its acceptance checks, and obtain that batch's implementation
direction. Do not resume incremental app edits from this audit alone.
