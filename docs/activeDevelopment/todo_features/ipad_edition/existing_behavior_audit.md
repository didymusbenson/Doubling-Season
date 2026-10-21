# Existing design baseline and remaining tablet decisions

**Status:** read-only source audit and documentation reconciliation, 2026-10-21. No implementation or runtime acceptance is claimed. Remote `main` was freshly verified as `d30050bd7a1067058fcdf7e707d3a223124a79fb`. All code links below are pinned to that baseline. The user's explicit tablet decisions override existing behavior; an incidental bug, platform limitation or implementation shortcut is not a design philosophy.

## Precedence and modal contract

1. **D41 explicit direction:** every modal blocks the entire table, whether seat-targeted or app/game-level. Tapaway dismisses it through an overlay that consumes the gesture. No click-through, queued second editor, automatic takeover or busy notification. A later editor requires a fresh interaction after dismissal. The single player-facing keyboard rule remains.
2. **No routine toasts or snackbars.** Inline errors/status, changed values, selection states and explicit controls provide feedback. Existing snackbar calls are replacement work, not precedent. Only a genuinely unavoidable exception could justify transient notification; none is approved by this audit.
3. Carry forward existing operation-specific semantics, not a universal “save every draft” or “discard everything.” Dismissing a view does not undo committed changes. Tapaway remains available even where legacy code blocks dismissal; failure must retain recoverable draft/error state rather than trap the user or claim a failed save succeeded.
4. Preserve accepted separate product, 2–4 players, seat/command context, game history, reset/preset/art lifetimes and shared C workspace. Current single-board globals, global custom-art paths and immediate whole-board undo are not multiplayer-ready implementations.

## Source-backed interaction dispositions

### Search and new-object forms: resolved baseline, adapted presentation

- Search query/filter/tab state belongs to the search journey, not a durable game draft. Closing search abandons unsubmitted creation; reopening starts the normal initial search state. A quantity sub-sheet can close back to its existing parent search without erasing that parent's query. [State, disposal and close](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/token_search_screen.dart#L35-L96), [selection and quantity reset](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/token_search_screen.dart#L635-L678).
- Creation requires explicit Create; successfully committed tokens remain even after the workspace closes. Selecting a result may already update Recents or prefetch art: cancellation means **no unsubmitted board creation**, not zero cache/library side effects. Successful creation currently closes quantity and search; preserve that completion concept without a fixed double-pop in the new host. [Create path](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/token_search_screen.dart#L962-L1071).
- A new custom token or new deck naming form uses explicit submission; Cancel/close before submission does not create it. Do not save incomplete forms simply because the user taps away. [Custom close](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/new_token_sheet.dart#L62-L79), [new-deck Save/Cancel](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/deck_save_sheet.dart#L115-L139).
- Adaptation: show the captured target seat in the C workspace; all background controls are blocked. Dismissal is not a hidden request to launch the seat underneath. In-flight async creation still needs exactly-once/recovery handling; UI dismissal alone cannot cancel an already committed operation.

### Rename, inline editing and counters: different existing commit models

- **Existing token inline fields:** stage text, commit when switching fields, losing focus, pressing Done or collapsing. Empty text is deliberately supported by the edit session; do not invent a universal required-name validation. A failed commit restores the old model and retains the draft/error. [TokenEditSession](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/controllers/token_edit_session.dart#L15-L159), [Done](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/inline_token_edit_field.dart#L75-L89), [collapse commit](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/token_card.dart#L414-L430).
- **Existing deck rename:** valid nonempty trimmed edits save as the text changes; it is not a Save/Cancel form. Closing does not roll back those saved edits. [Live rename](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/deck_detail_screen.dart#L219-L232), [persistence](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/deck_detail_screen.dart#L143-L145). Use the existing rename concept for existing-object naming rather than asking a blanket “what if rename closes?” question; new seat fields still need their own validation mapping, not copied deck constraints by accident.
- **Counters:** ± controls apply live; a typed Set dialog stages its value until Set/Done. Cancel/null means no typed-set mutation, not reversal of earlier ± taps. [Typed Set](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/token_counter_management_sheet.dart#L59-L90), [live mutation](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/token_counter_management_sheet.dart#L128-L150).
- Carry forward inline token editing rather than a compulsory separate full-screen token-detail route. C supplies room for complex search/editor work, not a reason to turn every quick value edit into a giant modal. Failed-save presentation must adapt to universal tapaway: preserve the draft for recovery and expose an inline error when editing resumes; exact recovery presentation needs implementation design. Do not preserve legacy snackbar or nondismissible-save-veto behavior against D41.

### Token shape, artwork hierarchy and utility parity: resolved baseline with new dimensions

- Board entries are content-driven full-width rows, square outer surfaces with no exterior vertical gaps and a full-height **7 px left identity rail**, not literal fixed-aspect playing cards or the generated C illustration's decorative tiles. Preserve this visual hierarchy conceptually; measure tablet sizes rather than scale phone pixels blindly. The rail explicitly replaced the older full perimeter border. Artwork sits behind content, and missing art has a gradient/placeholder. Zero-count entries remain useful reusable setup and are visually dimmed, not deleted. [TokenCard layout](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/token_card.dart#L257-L400).
- Longer type/ability/P/T content wraps or stacks. Compact counter pills retain all counter kinds; expanded overflow keeps the rest reachable. Preserve calculated P/T display, nonnumeric modifiers, and intentional +1/+1 versus −1/−1 cancellation rather than simplifying to a single unlabeled number. [Counter presentation](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/token_card.dart#L639-L705), [Item semantics](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/models/item.dart#L193-L266).
- TokenCard is the existing canonical board-item presentation baseline; trackers/toggles and specialized utilities must be checked for matching artwork, identity, edit and collapse semantics. Dedicated life/shortcuts remain outside the reorderable utility lane. This does not mandate copying phone geometry or adding all legacy utilities to the first release. [Repository conventions](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/AGENTS.md).

### Artwork serving, selection and saved references: resolved baseline, scoped adaptation

- Preserve selected metadata on offline/CDN/cache failure. Retry remote art or render a placeholder; failure to access a custom file is not proof the user removed the choice. Preserve canonical selection while trying derived crop variants. [Failure handling](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/mixins/artwork_display_mixin.dart#L70-L87), [URL/cache handling](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/utils/artwork_manager.dart#L94-L211).
- Existing native caching is URL-hashed and cache-first; web uses network/browser behavior. Carry forward efficient serving and honest placeholders, not a claim of identical offline guarantees on web. Artwork selection awaits its callback, including native download, before closing; cancellation before selection does not silently replace stored art. However, current [Item.updateArtwork](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/models/item.dart#L297-L303) calls save() without awaiting it, so this is not proof of durable-save success. The new design must honor its persistence acknowledgement contract rather than reproduce that limitation. Artist credits and custom-upload labeling remain part of the presentation. [Selection callback](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/token_card.dart#L1037-L1113).
- Preferred selection then catalog default is a reusable resolver concept, but the existing globally keyed preference store is superseded by D39 game-and-seat scope. Do not establish a permanent seat token-art preference. [Resolver](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/services/token_result_artwork_resolver.dart#L14-L54).
- Decks really snapshot artwork URL/set/options and restore them, distinct from a cover image. Custom files remain references, not immutable embedded deck assets; token-identity filename reuse can overwrite what an old deck references. Preserve the accepted saved-selection outcome, not that unsafe storage coupling. Full audit and source links are in [presets/art lifetime](07_utilities_tokens_and_decks.md). Asset retention/portable packaging still needs technical design.

### Ordering, merges, utilities, resets and history

- New ordinary entries append; copy/split results go immediately after their source. Preserve this behavior inside the new per-seat/per-lane domain; no need to reopen generic insertion placement. [Append](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/providers/token_provider.dart#L70-L80), [copy](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/providers/token_provider.dart#L302-L335), [split](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/split_stack_sheet.dart#L354-L389). Preserve dismiss-before-async-split intent, but replace captured mutable references/delays with scoped, recoverable commands.
- Search primary creation deliberately makes a fresh stack; other eligible merges require exact token identity **including art URL** and clean counters. Same display name is insufficient. Preserve route-specific semantics, not “always merge” or “never merge” globally. [Search merge policy](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/token_search_screen.dart#L1003-L1020), [compatibility](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/services/token_merge_compatibility.dart#L7-L48).
- Preserve utility-specific calculations and copy/split/counter distinctions described in the existing inventory, with explicit seat targets. No automatic table-wide rule engine follows. D37's curated visibility, default storm/mana and confirmation-before-hide override any old utility deletion semantics.
- Existing deck clear/add variants do not resolve the new product's midgame preset policy or commander inclusion. Existing whole-board wipe snapshots establish reversible-operation intent, **not** the accepted durable chronological history. D22/D33 reset/archive semantics and latest-global-action undo override old single-board snapshots. The phone's non-dismissible Undo/Accept must become dismissible under D41; dismissal after commit is not automatic undo. [Snapshot audit](game_history_and_undo.md).
- Existing counter `_persistMutation` changes state then catches a save failure without a rollback guarantee. Existing creation can report partial outcomes. These are technical limitations to address under coherent history/recovery, not desired semantics. [Counter failure](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/token_counter_management_sheet.dart#L38-L48). Existing snackbars (for example TokenCard save errors) and non-dismissible artwork/progress dialogs must be replaced/adapted, not grandfathered in.

### Expansion and gesture discipline

The current board has one expanded item; tapping another first requests collapse and returns, rather than opening the new item in the same gesture. [Expand/collapse routing](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/content_screen.dart#L52-L109). Carry forward deliberate collapse-first/no-accidental-second-action behavior. Multi-seat nonmodal expansion scope is an adaptation to validate, not proof that four detailed editors must coexist. D41 independently settles all modal use as sequential.

## Complete open-decision disposition

**R = resolved by existing deliberate behavior or explicit user decision. A = adapt baseline to new multi-seat/session design. U = genuinely unresolved product choice. T = technical/prototype validation, not a preference question.** Multiple labels mark distinct portions, not a reopened accepted decision.

| Decision | Disposition after audit |
|---|---|
| D01 | R separate product, same repo allowed; T isolated packaging/IDs/shared boundaries, not decided by old app layout |
| D02 | U public product name/branding; existing app cannot choose a new product's name |
| D03 | R Android/iOS/web; U release order; T device/browser capability matrix |
| D04 | R customizable 2–4, six deferred; A layouts within accepted regions, no one-player inference |
| D05 | R opposite-facing two-player template; U four-seat orientation options beyond accepted concepts; T rotated hit/semantics |
| D06 | U minimum-window/focused fallback product promise; T measured usable dimensions; phone behavior cannot prove tablet floor |
| D07 | R dedicated life/attached shortcuts/separate lanes/shared controls; T exact geometry and reach |
| D08 | R conceptual existing workflow baseline; A utility/token parity inventory; U intentional release omissions, not assumed whole feature parity |
| D09 | R one keyboard, all-modal whole-table blocking, no queued second editor; T nonmodal multi-touch |
| D10 | R C for detailed work and inline editing for quick fields; A compact expansion state; T capacity/interaction, not four simultaneous modal editors |
| D11 | R finish/dismiss then fresh interaction; search/form/inline resolution above; T rotation/native/IME/accessibility and safe async dismissal |
| D12 | R meaningful labels and accessible alternatives as baseline; T multi-orientation traversal/large text; U fallback view if measurements require a product tradeoff |
| D13 | R append ordinary entries, source-adjacent copy/split, merge retains destination; A independent seat/lane order and companion routes |
| D14 | T aggregate versus records/journal schema; old Hive layout is evidence, not a mandated tablet store |
| D15 | T command ordering/revisions/async recovery; R modal UI excludes second-user gestures, but not in-flight async work |
| D16 | R game-wide chronological latest-action undo and grouping; T durable grouped commands; U exact timeout tuning/undone-row presentation remains, old immediate undo cannot answer it |
| D17 | R durable current-game/history recovery; T acknowledgement/failure protocol, not a reason to ask whether to save |
| D18 | U legacy live-phone-board import inclusion; R preserve source/no silent assignment; T adapter if included |
| D19 | R persistent seat name/life appearance, game-local token-art; A exact preference domains, existing live rename versus inline commit semantics |
| D20 | R serving/placeholder/selection baseline; A immutable cache versus scoped choices; T custom-asset references; U optional library/profile sharing beyond accepted presets |
| D21 | R persistent hidden-seat customization, removed game setup clears; A stable identities; U elimination/replacement not inferred from warnings |
| D22 | R two reset modes/retention and modal dismissal; U wipe target selection, exact utility/rule reset mappings; T atomic checkpoint |
| D23 | R current v3 is reusable setup, art metadata not packaged bytes; A lane conversion; U export subset/new format and inclusion; T validation/migration |
| D24 | T reuse boundaries; R reuse domain/rendering semantics, not current global providers unchanged |
| D25 | R seat-owned modifiers with differentiated local/global applicability; global sources affect table and cannot be removed from recipient panels; A source-scoped calculator reuse; U presentation choice, reset activation mapping and token transfers; T stacking/deduplication |
| D26 | R accepted tracker fundamentals/coupling/manual bookkeeping; A quick-edit conventions; U remaining counter additions/detail visibility; T capacity/source identity |
| D27 | R dismissible default mana pool; U exact mana mechanics/restrictions; existing token UI does not choose these |
| D28 | R shared control locations/dice example; U extra tools/dice options; no old/reference icon commits new functionality |
| D29 | R separate product and safe explicit interchange direction; U shared live-data policy; T storage boundaries |
| D30 | T actual hardware/workload measurements; U supported floor after evidence; no legacy performance guarantee |
| D31 | R preserve offline selections and local state; T web/native cache/resume differences; U formal offline/update release guarantee |
| D32 | U commercial entitlement/pricing; existing app cannot choose new-product business policy |
| D33 | R pre-reset archive restore; U retention/browse/current-game-preservation policy; T historical media and restore coherence |
| D34 | U export/privacy/retention contents beyond accepted local saved data; T safe format/media handling |
| D35 | T manual/device evidence and format compatibility; R no documentation-only implementation/QA claims |
| D36 | R seat versus game context, not permissions; modal blocking now D41; U wipe targeting only, not whether neighbors can keep tapping |
| D37 | R curated utilities, hold-drag, confirmed hide/restore and hidden-value preservation; U exact inventory/reset/default/history mapping; A existing utility presentation parity |
| D38 | R preset contents/targeted zero-state load/optional life art; U midgame merge/replace, commander inclusion and history/life impacts; T schema/assets |
| D39 | R current-game seat token-art lifetime, preset snapshots and explicit keep/archive retention; T asset isolation; U exact missing-asset fallback presentation |
| D40 | R shared C workspace, target label/player-facing input, D41 blocking/dismissal; T dimensions/editor mapping/rotation affordance |

## Remaining work, not repeated preference questions

Implementers should use the resolved baseline above without reasking whether to retain search drafts forever, stage all rename fields, show a busy toast, queue another seat's editor, or force all editing into a new screen. Still review real multi-seat/new-feature decisions (for example midgame preset replacement and shared-effect targeting) separately. Prototype/test technical questions instead of presenting them as user preferences. Every carryover needs manual validation in the new component; no current-source audit proves tablet behavior passes.

See the [second-pass granular baseline map](outstanding_behavior_baselines.md) for concrete old-design starting points across the remaining questions and the ranked next genuinely new decision.

## Modifier scope checkpoint — D25

D25 subsequently settled local/global source applicability. The old local-only calculator is reuse evidence, not the accepted tablet scope; see the updated contract. See [modifier ownership and applicability](modifier_ownership_and_applicability.md).
