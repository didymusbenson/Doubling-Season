# Tripling Table: October 26 feedback batch

Status: implementation plan, not implemented. Prepared from user feedback and read-only source audits at `729f8402bc45df46917c3dc3a7b10e71c8a16129`. Installed iPad build 3 is based on `1f93a39a4101d8cd1e85bf8f42cc350d74167f89`; inspected tablet code is unchanged between these points. Verify current head again before execution.

## 1. Outcome and scope

Deliver one coherent tablet interaction cleanup: predictable fixed-size dialogs, understandable seat settings, accurate player-facing text entry, trustworthy artwork selection, and direct gameplay controls. Fix reported token presentation regressions without simplifying away original functionality. Diagnose iPad upload failure and life-tap latency with evidence rather than disguising them with visual changes.

The user authorized execution only after the full plan is assembled and reviewed. This document is that prerequisite; parent review must resolve any contradictions before implementation starts. No further general plan approval from the user is required. Device installation and any new permission/security changes remain separately gated.

Explicit exclusions:
- Do not implement the proposed mana-pool/optional-stepper/Storm consolidation. Record it as deferred design.
- Do not complete the custom-rules engine. Hide custom authoring and record proper implementation as deferred.
- Do not complete prior deferred utility-editor, Squirrel Girl or Ring designs.
- Do not change release versions, upload store builds, change signing/account settings, or install over the physical iPad without specific approval.
- Do not merge unrelated branches or pending docs-only PR 48. Do not alter today's OTA v13 data.
- Do not refactor original phone behavior merely to make the tablet implementation easier.

## 2. Non-negotiable contracts

Preserve the tablet's 60/40 token/life layout, global-center hub, solid player borders, corner overlays, original token functionality, collapse-first item behavior, seat-facing interactions and exactly one keyboard. All modal routes block the entire table; a dismissal tap is consumed. Preserve drafts on save failure, chronological Undo, stable IDs, archives, inactive profiles, settings and artwork files. No routine toast/snackbar feedback. Errors and pending/saved state must be visible in the relevant surface.

Use existing shared commands and storage rather than parallel gameplay state. No deletion or normalization of saved custom/legacy objects. No loss of preset modifiers while hiding custom authoring. Do not switch to the system keyboard merely to obtain its editing menu.

## 3. Unified UX architecture

### 3.1 A single fixed modal shell

Define viewport as the application's full layout bounds before safe-area subtraction and before player-facing rotation. App-owned conventional dialogs occupy exactly 75% of viewport width and height, centered. A 12.5% exterior margin normally accommodates device safe areas; test this explicitly rather than silently applying page-specific clamps. Keep unsafe content insets inside the shell where needed. Quarter-turn content uses swapped player-local constraints so its physical footprint still matches the same 75% rectangle.

Use one shell for workspace pages, artwork selection, crop, support, confirmations and secondary editors. Keep the shell's outer rectangle stable across tab changes, keyboard opening, loading, validation errors and candidate previews. Header and primary actions remain accessible through a deliberate scroll/reveal model; the body normally scrolls. Keyboard-open feasibility is a prerequisite, specified below, not an assumed fit. Do not shrink font sizes or touch targets to avoid scrolling. Small confirmations intentionally retain the standard shell instead of reverting to content-sized dialogs.

The standalone player-facing keyboard overlay is not a conventional modal: it must leave the edited board object visible, while still blocking other inputs. Native photo/file pickers are OS-owned. Document these two category exclusions; they are not arbitrary per-page size exceptions. If actual safe areas or accessibility settings make the literal 75% shell unusable, report that concrete conflict before inventing an exception.

Remove page/tab-specific width and height overrides. Replace obsolete tests asserting small/content-sized dialogs with the new contract, while retaining their interaction assertions.

### 3.2 Seat workspace and navigation

Replace the fragmented player-settings journey with one seat-facing workspace containing two clearly named sections: Player and Counters. Player contains compact, visible groups for name, color/art and appearance, owned commander/partner setup, and saved setup operations. Counters contains live statuses/counters and the expanded spatial commander-source grid. Preserve clear recipient identity and source-owner appearance.

Board entry points open their intended section directly: Edit opens Player; counters opens Counters; commander mini-grid opens the commander region of Counters without requiring a source-picker. Preserve direct source adjustment. A focused secondary correction editor distinguishes Record damage (coupled life reduction) from Set damage total (ledger-only correction). Do not turn all commander actions into nested configuration pages.

Use one navigation stack. Back returns to the exact originating section/scroll/selection; Close dismisses the workspace. Remove duplicate local and generic Back controls. Keep destructive resets and unusual corrections out of the routine first screen, but reachable via concise secondary actions. Avoid new accordions merely to hide clutter; use organized sections and modest scrolling.

Verified Lifetap precedent supports Player/Counters and compact-grid-to-expanded-grid navigation, not unverified partner/correction/self-damage gestures. Preserve Tripling's own tested semantics where Lifetap evidence is incomplete.

### 3.3 Shared gameplay controls

Keep the existing hub at the true table center. Add direct compact dice and Day/Night status controls within its shared life-zone control cluster, not in token lanes or a control-bearing divider. Dice opens the existing dice workspace directly. Day/Night visibly communicates neither/day/night and invokes the existing shared undoable state command. Place a compact sun/moon state control adjacent to the central hub in the life-zone cluster, with Dice on the opposite side and explicit reserved clearance. Tap transitions Neither → Day, then Day ↔ Night. A deliberate hold clears to Neither; expose that operation in a discoverable tooltip and accessible Clear Day/Night action. Each actual change is one undoable command. A hold must not produce a trailing tap. In the Neither state, the inactive sun/moon treatment must remain distinguishable from Day and Night. Capture and verify the exact glyph, state indication and target bounds in the early layout review. Configuration, support, catalog maintenance and appearance do not belong beside live gameplay controls.

Validate all 2/3/4-seat layouts before accepting this placement. Additional controls must not collide with life totals, signed deltas, commander targets, token clearance or opposite-corner overlays. Do not enlarge the cluster into an unlabeled obstruction or reintroduce permanently labeled rows.

## 4. Implementation workstreams and dependencies

### A. Baselines and instrumentation (before UI changes)

1. Create an isolated feature worktree/branch from verified current main; preserve existing work. Read AGENTS.md, apps/tablet/README.md and relevant local skills.
2. Capture baseline analyzer/tests/build results and populated layouts with real fonts/art. Record current source and environment versions.
3. Instrument life and token quantity interactions in development-only tracing: pointer-up, callback, command enqueue, validation/serialization, storage flush, state publication and rendered frame. Compare equivalent quantity taps, not token expansion (which is local state). Test small and history-heavy saves, rapid alternating-seat taps and held input.
4. Attempt read-only diagnosis of the already installed iPad picker failure if device/log access is available. Record exact exception code/message/details and whether failure occurs before picker presentation or after image selection. Do not mutate user's saved game to obtain evidence.

The current life pipeline waits for durable save before notifying. There is no explicit life-number animation delay. Do not remove durability, weaken history, or introduce an optimistic parallel numeric state merely to hide latency. Prefer measured duplicate-work/rebuild/serialization optimization and immediate pressed-state acknowledgement. If no equivalent-device timing is available, keep the latency root cause and acceptance explicitly unverified rather than calling a cosmetic change a fix. Any optimistic-state redesign requires a separate reviewed transaction/failure design within this task before adoption.

### B. Modal shell and player navigation foundation

**Early layout feasibility gate, before broad migration:** create a populated prototype of the shared 75% shell using real fonts and representative content, including the longest keyboard command row, an active text field, inline error and primary actions. Render it in every seat rotation and portrait/landscape on the supported tablet viewport matrix. Record actual logical dimensions, safe-area insets, text scale and hit regions. Do not claim any exact fit from arithmetic alone.

Budget the shell height explicitly for header/navigation, active field and feedback, keyboard, and actions. The normal arrangement scrolls the form body while keeping editing context and actions reachable. If these regions cannot fit with touch targets at least 44 logical pixels, use coordinated scrolling **inside the unchanged shell**, including the keyboard region when needed. Maintain a visible or automatically revealed active-input context; focusing a field, changing input mode, showing an error or producing an artwork candidate must reveal the relevant region. Keyboard Done and the primary action must remain reachable without losing draft or selection. Do not solve the budget by shrinking targets, clipping controls, silently enlarging/clamping the shell, or introducing conflicting nested-scroll traps.

List the supported tablet sizes tested and any narrow or accessibility configuration that cannot yet meet this contract. An unresolved layout case blocks broad migration and must be resolved or explicitly reported, not marked covered by a different viewport. Review this populated prototype before continuing.

After the feasibility gate passes, implement the shell once, then migrate workspace and outliers. Integrate the Player/Counters navigation above in the same pass so the new fixed area is designed around coherent grouping rather than old clutter. Keep a table of migrated routes and genuine overlay/OS exclusions.

Likely files: `ui/workspace/table_workspace.dart`, `game_pages.dart`, `life_artwork_picker.dart`, artwork crop/support/confirmation routes, and shared modal helpers. Keep compact routine content; remove repetitive instructions and assurances. Preserve explanations of destructive-reset scope, irreversible appearance resets, commander record/correction semantics, split-status changes, failures and purchase details.

### C. Keyboard and native editing actions

Build keyboard improvements against the final shell constraints, not against sizes that will be replaced later.
- Make ordinary Shift one-shot, resetting after a letter. If Caps Lock remains supported, give it an explicit distinct state and gesture; no invisible sticky mode.
- Separate capitalization from selection extension. Reset inappropriate state when changing fields, especially text to numeric; numeric inputs must never inherit a hidden selection modifier.
- Use a common letter-key width and familiar staggered rows rather than independently stretching 10/9/7-letter rows. Retain useful gutters and visible pressed state.
- Add touch Backspace hold-repeat with release, route dismissal, input-lock and lifecycle cancellation. Preserve grapheme-aware deletion and selection deletion.
- Keep current field/value, Done, cursor and selection actions understandable and reachable. Do not crowd the narrow modal command row below accessible target sizes.
- Restore familiar selection handles and an adaptive editing toolbar with Select All/Copy/Cut/Paste while retaining the player-facing keyboard. Current readOnly/TextInputType.none plus an empty context-menu builder is intentional suppression; simply deleting the builder is insufficient. Use the shared controller/selection and appropriately enabled custom toolbar actions.
- Clipboard unavailable, denied and exceptions receive inline contextual feedback instead of silent failure. Do not add generic toasts.

Preserve the prior web focus regression fix, one keyboard, draft retention and save-before-close behavior. Test rotated toolbar placement: an unrotated native-looking menu floating in the wrong player's direction is not success.

Likely file: `ui/workspace/player_keyboard.dart`, shared PlayerField/standalone draft host and their tests.

### D. Artwork workflow, imports and attribution

Treat modal sizing, text editing, URL confirmation and native import as one artwork flow, with source-specific acquisition followed by a common candidate/Apply state.

1. Keep URL input, validation progress, error, candidate preview and Apply together and visible. Use an explicit pending candidate distinct from saved artwork. Keyboard Done ends text entry; it must not masquerade as saving. After Preview succeeds, focus/scroll the candidate and Apply affordance into view without discarding the draft.
2. Concisely explain that HTTP(S) must resolve to decodable image bytes, not an ordinary webpage. Preserve the existing 12MB URL validation unless evidence requires a scoped change. Error messages should tell the user how to proceed.
3. Reuse `ArtworkCreditCaption` and `ManaIcons.artistNib` U+E924, matching theme/style/accessibility instead of recreating it. Cover token/life/utility current selection, confirmation and artwork choices as requested. Preserve authoritative credits and URL metadata enrichment; recognize `tablet-art:` as user-uploaded. “Custom URL” is provenance, not an artist name.
4. Diagnose and fix the shared `pickTabletArtwork` native failure, covering every upload surface. file_picker 8.3.7 uses image/withData, and permission text/registration already exist. Photo-provider processing and SceneDelegate presentation are different hypotheses. Choose the narrow proven repair; do not blanket-upgrade across major plugin APIs without compatibility review.
5. Cancellation, validation, download/decode or storage failure must never erase the previous selection. Batch artwork metadata updates in one transaction and await validation/persistence before dismissing.

Likely files: `ui/artwork_selection.dart`, `ui/life_artwork_picker.dart`, `ui/workspace/library_pages.dart`, original shared caption import, and only proven-required iOS/plugin configuration. Record dependency changes and test implications if any. Native photo authorization remains OS/user-controlled; do not reset permissions to make a test pass.

### E. Life surface and rapid controls

- Move signed delta into the central total region: negative left, positive right in player-local coordinates. Keep the big total fixed at its existing center; reserve symmetric space or overlay deltas without letting total-plus-delta width shift it.
- Keep the delta non-interactive and out of the commander target; avoid hub-notch clipping across all seats.
- Preserve current grouped-history meaning. Another seat currently changes the globally latest action; test and document this rather than silently adding a new per-seat transient-history feature.
- Set life-only hold start to ±10. Retain current faster ±10 phase after 2 seconds and ±25 phase after 5 seconds; single tap remains ±1. No global stepper default change. Verify cancellation and absence of a trailing tap.
- Apply only evidence-supported responsiveness repair from A; separately report measurement results and remaining native limits.

Likely files: `ui/table_screen.dart`, life invocation of `half_stepper.dart`, and scoped controller/storage optimization only if justified.

### F. Everyone wipes and unfinished custom rules

Add an explicit scope choice: the selected active player or Everyone. Everyone applies the chosen existing creature/all-token filter to all active session boards within one controller transaction and one chronological Undo. Do not loop independent player commits. Preserve non-target state and invalidate editors for every affected seat only when needed.

Preserve current filtering semantics in this batch: creature means tracked token with P/T; all tokens includes all objects currently in the token list. The app does not track or remove physical nontoken creatures. Include emblem/special-entry fixtures and record their established behavior; do not silently change classification during scope work.

Hide custom-rule creation/editing/duplication/reordering authoring entry points while keeping preset modifiers available. Preserve serialized custom definitions and current enabled effects. If a saved custom effect exists, retain a conditional, clearly labeled “Existing custom effects” management surface so it is not invisible; do not advertise it as a ready-to-use custom-rules feature, and do not offer new authoring from that surface; do not silently disable gameplay effects or delete definitions. Avoid using the original experimental-off toggle, which deletes rules. If user expects complete feature suppression including evaluation, obtain that specific decision before changing it. Proper engine implementation remains deferred.

Likely files: `features/board_service.dart`, `ui/workspace/game_pages.dart`, `library_pages.dart`, controller history tests. Verify no migration/schema change is needed.

### G. Token presentation parity

- Collapsed abilities: three complete lines with ellipsis, sized from text layout rather than a hard 48px viewport. Preserve normal/long-P/T behavior and ManaText. Expanded abilities remain fully scrollable, not collapsed truncation.
- Honor Full View/Fadeout in both collapsed and expanded token editing. Remove or scope the explicit `fadeout && !expanded` override. Shared utility surfaces require review; preserve intentional differences and document them rather than changing them accidentally.

Likely files: `ui/tablet_token_card.dart`, `ui/table_artwork.dart`. Use original token implementation as behavioral reference. No phone regression and no reduction of expanded editing controls.

## 5. Review and execution order

1. Parent full-plan review: confirm every user item, dependency, exception, acceptance gate and preservation requirement. Amend plan before implementation.
2. Baselines and evidence capture, including timing/picker diagnostics where available.
3. Early populated 75% shell/keyboard layout feasibility review, then shared shell and navigation foundation only after that gate passes.
4. Keyboard/editing actions and integrated artwork flow; in parallel only isolated non-overlapping service/token work with clear file ownership.
5. Life/shared gameplay controls and Everyone/custom-authoring scope.
6. Integrated populated visual review. Review the whole experience, not one screenshot per isolated fix.
7. Full regression/build matrix on the final exact commit, independent code/UX review, fixes and rerun.
8. Publish verified work under existing repository authorization, verify deployment and preserve original root app.
9. Physical-device acceptance after separately authorized data-preserving installation. Until then label native fixes pending device verification rather than fully accepted.

No implementation may begin merely because an individual workstream is understood; the complete plan must pass step 1.

## 6. Acceptance matrix

### Geometry and interaction
- 2/3/4 active seats; all four orientations; landscape and portrait, including small-tablet and short-landscape cases; real Mana fonts and populated artwork.
- Every app-owned conventional modal has the same 75% outer footprint through tabs, secondary editors, keyboard open/close, loading/error and confirmation states.
- All content/actions reachable by scrolling, no clipped text or targets, no shrinking to evade failures. Large text and safe areas included.
- Whole-table blocking and consumed tap-away; failed saves retain draft and route. Navigation returns to original section/scroll/selection. Standalone keyboard retains board visibility.
- Direct Dice/DayNight, central cluster, life delta and commander grid do not overlap or step life accidentally.

### Keyboard
- Exact and near-edge taps, rapid/repeated typing; one-shot Shift and explicit caps state if present; Shift→letter→cursor correction; text→numeric→text field changes; clipboard denied/empty/error/success; select-all/range/cut/paste; emoji/graphemes; backspace holds and cancellation; web focus regression; all rotations.
- Physical iPad toolbar/selection handles/Paste behavior; custom keyboard orientation and field visibility within 75% dialogs.

### State and history
- Wipe selected player and Everyone, creatures versus all token objects, empty/mixed boards, exact one-Undo restoration, save failure atomicity, active versus inactive seats, stale-editor handling.
- Record commander damage versus set recorded total, partners/same names/self sources, stable IDs, owner/recipient clarity and chronological Undo.
- Custom definitions survive reload/archive/Undo; presets remain usable; no invisible existing custom contributions.
- Life repeated/concurrent/held input has correct totals/history and no loss, duplication or rollback surprise.

### Artwork and token parity
- Token/life/utility/Storm uploads on physical iPad, local JPEG/PNG and photo-library selection; iCloud-only source if relevant; before-open/after-selection errors; cancel/retry/repeated taps/crop cancellation and persistence.
- URL direct-image success, webpage rejection, malformed/oversize/decode/network failure, visible pending versus Apply/saved, keyboard Done distinction, reload persistence.
- Artist glyph and accessible label, long names, unknown and uploaded fallbacks; no fake artist attribution.
- Full/fadeout × collapsed/expanded, preference changes while expanded, local/remote artwork, keyboard editing and reload.
- Scute Swarm complete third line/ellipsis, narrow lanes, text scaling, mana symbols, long P/T; expanded full description reachable.

### Engineering gates
Run `flutter analyze` and full tablet `flutter test`, required web/Android/iOS simulator CI/builds and relevant original-app checks against exact final head. Keep temporary native UI flows outside repo unless separately authorized. Do not remove meaningful tests to pass new sizing; replace only explicitly superseded size contracts. Record passes, failures, skips and unrun stages separately. Flutter browser or screenshot success is not native acceptance.

### Acceptance ledger and completion language

Maintain one explicit ledger with separate statuses for:
- **Code and automated regression:** exact tested commit, analyzer, tests, builds and independent review.
- **Web publication:** exact remote/merged commit, combined Pages run and actual original/tablet served artifacts.
- **Physical iPad artwork picker:** real upload, cancellation/retry and preservation checks on the corrected build.
- **Physical iPad editing:** selection handles, editing toolbar/Paste, keyboard layout and typing corrections on the corrected build.
- **Physical iPad life latency:** equivalent-input timing evidence and functional rapid/held/concurrent-input checks on the corrected build.

Use Pending, Passed, Failed or Blocked with dated evidence; mark never-run stages explicitly. Successful code review, simulator compilation or Pages publication does not close a physical-iPad row. Do not describe the whole batch as complete until every relevant physical-iPad acceptance row passes. If installation approval or device access is absent, report the independently completed code/web work and the exact remaining native gate. Existing-build diagnosis establishes a baseline, not corrected-build acceptance. Physical installation requires its separate authorization and data-preserving procedure.

## 7. Publication and documentation

Repository AGENTS.md at the audited head explicitly records standing authorization (October 22) to publish completed verified work through PR and existing combined Pages without another publication confirmation. Create a draft PR while work is incomplete, checkpoint and push meaningful progress, then use normal validated merge workflow without force-push. Respect any later restriction. Verify exact remote SHA, required CI and both original root/tablet Pages payloads; do not publish a tablet-only artifact or clear shared origin storage.

Create the batch plan/checklist in the repository's existing tablet development documentation and bug entries for diagnosed failures. Keep unresolved native acceptance open instead of moving everything to completed prematurely. Add deferred mana-steppers and full custom-rules implementation with user-deferred design clearly marked. Record rule/navigation changes and propose applicable AGENTS.md updates under its maintenance convention; do not silently preserve contradictory old modal-size guidance.

Do not install a new physical-iPad build, change signing, bump versions or upload a store build merely because Pages publication is permitted. A final handoff must distinguish published web/code, native compile/simulator evidence and physical-device verification.

## 8. Risks and decisions already bounded

- Literal 75% size is user-directed; scroll rather than invent per-page clamps. Overlay and OS picker exclusions are structural categories, not hidden exceptions.
- Existing custom-effect evaluation is preserved and visible; authoring hidden. Disabling effects is not assumed from “hide.”
- Life durability is preserved; timing diagnosis precedes behavioral optimization.
- Native upload root cause is unconfirmed; error evidence determines repair.
- All-token/emblem and creature classification remain existing behavior, explicitly tested.
- New URL feature is improved, not removed; user asked about provenance and failures, not removal.
- Modal wording cleanup retains consequential instructions and warnings.
- Physical-device installation is a separate gate; an offline Mac does not justify claiming tests or silently changing executors.

## 9. Source index

All paths below refer to audited commit `729f8402bc45df46917c3dc3a7b10e71c8a16129` unless noted.
- `AGENTS.md`: preservation, tablet QA and combined Pages publication policy.
- `apps/tablet/lib/ui/workspace/table_workspace.dart` 777–1070: sizing/shell.
- `apps/tablet/lib/ui/workspace/player_keyboard.dart` 230–299, 387–412, 493–700, 736–834: modifier persistence, clipboard, geometry and menu suppression.
- `apps/tablet/lib/ui/workspace/game_pages.dart` 4–157, 567–814, 893–937, 1158–1200: player/commander navigation, wipe UI and settings.
- `apps/tablet/lib/ui/table_screen.dart` 310–390, 826–977: hub shortcuts and life layout.
- `apps/tablet/lib/state/table_controller.dart` 64–155 and `storage/table_repository.dart` 152–195 at installed build commit `1f93a39a4101d8cd1e85bf8f42cc350d74167f89`: durable commit ordering.
- `apps/tablet/lib/features/board_service.dart` 101–110, 909–967: custom sources and single-player bulk actions.
- `apps/tablet/lib/ui/artwork_selection.dart` 14–58, 99–233, 374–383: importer and URL flow.
- `lib/widgets/artwork_credit_caption.dart`: exact caption/nib treatment.
- `lib/widgets/token_card.dart` 1676–1686, 1740–1753: original three-line ellipsis.
- `apps/tablet/lib/ui/tablet_token_card.dart` 560–581, 721–759 and `table_artwork.dart` 255–288: art override and fixed ability viewport.
- `docs/activeDevelopment/in_progress_features/ipad_edition/lifetap_research.md`: verified precedent and limitations.
- Flutter `TextField.contextMenuBuilder` and `TextField.readOnly` documentation: toolbar/read-only semantics. file_picker official changelog/native locked implementation: upload hypotheses, not a proven diagnosis.

Review status: initial parent and independent review completed; their three requested amendments are incorporated: explicit native acceptance ledger, defined direct Day/Night interaction, and keyboard-open feasibility gate before migration. Author self-review of amendments complete. Parent reread of the full revised plan passed; ready for cloud implementation under the user's subsequent direction; physical-iPad validation remains separately gated. All reported feedback is mapped; dependencies and exclusions are explicit. No application code changed and no runtime results claimed by this plan.
