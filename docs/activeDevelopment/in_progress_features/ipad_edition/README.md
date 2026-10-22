# IPAD EDITION

**Status:** corrective implementation in progress in `apps/tablet`; see [the corrective review tracker](corrective_iteration.md) and [first-pass implementation evidence](implementation.md).
**Created:** 2026-10-20 (America/Phoenix). **Decisions updated:** 2026-10-22.
**Product relationship:** a separate app / new product reusing Tripling Season infrastructure; the same repository is acceptable with properly isolated directories.
**Technical direction:** Flutter with custom, player-facing in-app keyboards; validate in prototypes before treating the solution as proven. **Product targets:** Android, iOS and web.
**Code baseline:** `8894640543833eaf37bd62b971a0955c26bafa49` on `update-1-11`.

IPAD EDITION turns one shared tablet into a tabletop dashboard: a central life tracker, customizable two-to-four-player spaces, and separate token and utility columns for each player. Each seat has its own actions menu. Central controls use app/game context, not a fabricated player actor. Seat-context actions retain their target identity through rules, generated companions, persistence, undo and delayed work; game-level actions retain explicit affected scope. Context is not a strict touch-permission boundary.

This is a planning dossier, not a shipped feature specification. **Confirmed** means directly requested by the user. **Proposed** means a recommendation for discussion. **Open** means a decision is still needed. File names, class names, numeric layout budgets, release scope, and storage designs below are proposals unless described as existing code. The decision register is the authority for approval status; an implementation phase or acceptance scenario does not itself approve a proposal.

**Control-scope clarification:** token search and seat customization are seat-context actions; history, wipes and resets are central app/game actions. Keep meaningful player attribution separate from affected seats; never infer a human actor from control location. Wipe targeting UI and global-input pause policy remain open (D36).

**Layout/utility update:** dedicated life regions with tools outside the entire colored life stepper; separate curated per-seat utilities with hold-drag order and confirmed hiding/restoration. Storm and mana are default-visible, not mandatory. Shared controls are a compact standalone central component in every layout, not a control-bearing middle divider. Thin player-space borders remain separate. Initial scope is 2–4 players; three-player empty-slot controls remain. Latest explicit feedback supersedes the earlier strip suggestions.

**Deck/preset update (D38):** evolve Decks into reusable token lists plus utility preferences. Seat loading initializes selected token entries at zero and configures utilities; optional deck art can supply that seat’s saved life image. Art selections are per-seat, player name stays separate, and commander selection is not approved. Midgame Replace/Append are now accepted: only the loading seat’s preset-managed fields change, each as one undoable action; life values, damage, player counters and the existing timeline remain intact.

**Token-art lifetime (D39):** preferences are game-and-seat scoped, saved into deck presets and applied only to the loading seat. Fresh games do not inherit them. Keep-board and archive restoration retain explicit board/historical choices, not permanent seat defaults. Persistent player name and life appearance remain unchanged.

**Detailed-editor choice (D40):** C, the larger shared central workspace, is accepted for detailed seat-specific editing/search. Identify the target seat and orient editor/results/one keyboard toward the acting player. D41 now settles all-modal blocking and tapaway dismissal without click-through or queued switching; per-editor sizing remains open; quick controls need not become large modals. See the labeled [concept reference](02_layout_and_interaction.md).

**Accepted D41:** any open modal blocks interaction with the entire underlying table. Tapaway dismisses through an app-level overlay and consumes that gesture: no click-through, background mutation, queued second editor, takeover or “busy” notification. One player finishes/dismisses before another opens an editor. This applies to search, editing, confirmations and other modals, not only game-level actions. It does not imply blocking ordinary nonmodal quick controls when no modal is open. No toasts/snackbars for routine feedback, waiting or errors; use in-context status and explicit controls. An exceptional transient notification requires a demonstrated unavoidable need, not convenience.

[Existing-design audit and all-decision disposition](existing_behavior_audit.md) distinguishes carryover behavior, multi-seat adaptation, genuine product choices and technical validation.

**Commander capacity follow-up:** [source-enabled layout repair and cross-platform validation](commander_capacity_fix_2026-10-22.md).

**Current correction:** [compact central component, inline token quantity and whole-surface life/tools](compact_hub_life_tools_2026-10-22.md). PR #40’s earlier centered-strip correction is deployed at `71c1aee`; the latest user feedback supersedes that geometry.

## Start here

| Document | Purpose |
|---|---|
| [Corrective review tracker](corrective_iteration.md) | All 50 original-token inventory rows, review findings, source mapping, test evidence and remaining gaps |
| [Full token functional parity](token_functional_parity.md) | Accepted reuse-first correction and original source inventory; no token feature is silently omitted |
| [Product and scope](01_product_and_scope.md) | Confirmed requirements, intended experience, boundaries, candidate first release |
| [Layout and interaction](02_layout_and_interaction.md) | Interpret the sketch, quadrant geometry, orientation, independent lists, menus and simultaneous use |
| [Game history and undo](game_history_and_undo.md) | Chronological game history, action grouping, latest-action undo, persistence and existing-undo audit |
| [Life and game controls](03_life_and_game_controls.md) | Life, commander damage, counters, reset semantics, game lifecycle |
| [Player isolation and rules](04_player_isolation_and_rules.md) | Command ownership, event routing, generated tokens, explicit cross-player operations |
| [Architecture and reuse](05_architecture_and_reuse.md) | Flutter recommendation, current reuse map, project structure and frontend boundary |
| [Data and migration](06_data_persistence_and_migration.md) | Proposed session model, storage, settings scopes, recovery, compatibility |
| [Utilities, tokens and decks](07_utilities_tokens_and_decks.md) | Mana pool, existing utilities, token workflows, deck loading and export |
| [Delivery and validation](08_delivery_validation_and_risks.md) | Dependency-ordered phases, manual acceptance matrix, performance experiments, risks |
| [Decision register](09_decision_register.md) | Stable question IDs, defaults, alternatives, dependencies and review batches |
| [Six-player expansion](six_player_expansion.md) | Deferred expansion to six; preserve design leeway without promising release support |
| [Custom keyboard options](custom_keyboard_options.md) | Deferred mana-symbol and input-option exploration; not a release commitment |
| [Research and sources](10_research_sources.md) | Official Flutter / Magic references, conclusions and unanswered research questions |
| [Current-code audit](../../../../ai_docs/research/2026-10-20-ipad-edition-current-architecture.md) | Evidence of what exists today, separate from the proposed edition |

For a fast design session: read this page, the layout document, and the decision register. For implementation planning: also read the isolation, architecture, data, and acceptance documents before touching providers or models.

## Confirmed direction

- **C01:** This is a separate app and new product. It may live in this repository if isolated properly in its own directories; exact package structure is not selected.
- **C02:** Flutter with a custom player-facing keyboard is the chosen direction, subject to prototype validation rather than a claim of implemented behavior.
- **C03:** Make the life tracker the centerpiece of the app.
- **C04:** Give each player their own token list and utility list, including room for new utilities such as a mana pool.
- **C05:** Give each player an actions menu for creation, board actions, and utilities.
- **C06:** Put universal game-level controls, including resets, in the center.
- **C07:** Reuse existing infrastructure heavily while adapting the board container to separate surfaces instead of the current unified board-item list. Preserve the original token object's full functionality and deliberate compact design; this container change is not a token-rewrite mandate.
- **C08:** Preserve reordering separately within each player's token and utility lists.
- **C09:** Carry player context through all actions and prevent unintended changes in another player's space, including generated companion tokens.
- **C10:** Preserve enough detail, research, options, and outstanding questions to iterate quickly later.

- **C11:** Initial scope is customizable 2–4 players; expansion to six is deferred, with room in the design for it.
- **C12:** Product targets are Android, iOS and web. Device/browser floors and release sequencing remain open.
- **C13:** **Any keyboard input** must face the initiating player, including numeric entry as well as text/search/rename. **One keyboard at a time; no simultaneous keyboards** (D09). D41 requires finish/dismiss before the next editor, with no queued interaction; preserve each field’s existing commit/cancel model.
- **C14:** Full life-tracker fundamentals: life totals, relevant player counters including energy/poison/experience, city’s blessing, monarch ownership, game-level day/night, and source-specific commander damage **including self and distinct partner sources**. Use [Lifetap’s functional inventory](lifetap_research.md) as research, not a UI to copy. New commander damage subtracts life as one undoable action with independent corrections; thresholds warn without automatic elimination; monarch/day-night changes are manual. Inventory extensions, detailed correction UI and remaining runtime/rule mappings and archive presentation/transaction details remain open; see [life-tracker scope](03_life_and_game_controls.md).

- **C15:** Persistent game-wide chronological history with player attribution, undo walking back the latest action globally, repeated-like-action grouping and separate token add/remove lines. Life taps settle to a net adjustment after roughly 1–2 seconds of inactivity; immediate display is still a recommendation. Any player’s different action closes the active group; exact timeout tuning and pre-reset archive restore is accepted; ten archived states and safe restore are accepted; transaction/UI details remain. See [history and undo](game_history_and_undo.md).
- **C16:** Two full resets restart with the specified player count/configuration: Reset with board keeps token entries at zero with no counters and keeps enabled utilities; Complete reset clears tokens/utilities. Both reset life and temporary/game statuses. Persistent seats retain player name/color/art across games; unused seats are hidden, not deleted. Keep-board preserves reusable custom properties for remaining seats; removed seats lose game-specific tokens/utilities. Restorable full-state/timeline pre-reset archives are accepted; save-current-before-restore is required, with ten archived states; saved decks/permanent customization are not overwritten. See [reset and seat contract](03_life_and_game_controls.md).

The supplied image establishes a four-player reference, not a fixed participant count. Exact seating orientations, package layout, application identifiers, purchase model, release date and remaining feature inventory are open. See the accepted decisions in the register.

## Original concept

![User-supplied IPAD EDITION starting sketch](reference/original-concept.png)

The original, unedited 2508 × 1410 image is preserved in [reference/original-concept.png](reference/original-concept.png). It was supplied by the user on 2026-10-20. The embedded app imagery is a visual reference; its artwork, icons, small controls, player names, and life totals are not automatically new product requirements. Only the lower-left player has fully illustrated lists. The other three spaces require design, not literal empty replicas.

## Additional seating mockups — 2026-10-21

- [Two-player concept](reference/two-player-concept.png): accepted opposite-facing matched layouts; each player sees tokens left, life top right and utilities below life.
- [Three-player concept](reference/three-player-concept.png): accepted three-player arrangement uses a four-seat base with any selectable empty slot for expanded game controls (including quicker dice/reset access). The user clarified that the initial “In 4 player” wording meant three-player. Reset safeguards remain unchanged.

Both original images are retained unedited as user concept evidence, not implementation screenshots or measured acceptance. See [layout details](02_layout_and_interaction.md).

## Foundational recommendations to review

1. Build a **local, offline, shared-device prototype**, using four seats as one fixture and checking two/three-seat layouts; leave network play outside the initial scope.
2. Treat the user’s seat as persistent identity/customization, with separate game-local values and visual slot/orientation. Changing player count hides unused seats rather than deleting their customization; moving presentation must not reassign contents.
3. Enforce player scope at the command and repository boundaries, not only in list filtering.
4. Keep life separate from board items. Give tokens and utilities independent ordering domains.
5. Preserve explicit action scope, but block the entire table whenever any modal is open; absorb tapaway dismissal so underlying controls never receive it.
6. Inspect the actual running UI and interactions in the cloud before asking the user to install anything; then prove physical touch, seated usability, native behavior and recovery on actual iPad hardware before release acceptance or large package extraction.

The offline boundary and detailed implementation choices remain proposals. Separate product, 2–4-player initial scope and Android/iOS/web targets are accepted; six-player support is deferred. Resolve remaining choices through [D01–D35](09_decision_register.md).

## Resume and maintenance rules

- Keep this entire directory under `todo_features` while planning. Move it together to `in_progress_features` when implementation actually begins, and repair relative links.
- Update decision status with date, rationale, and affected documents; preserve IDs so discussions remain traceable.
- Record prototype results as measured outcomes, including device, viewport, text scaling, build mode, and failures. All validation in this initial dossier is **planned / not run**.
- Move to `new_release` only after the agreed acceptance work passes and implementation is committed. This dossier does not alter the current 1.11 queue.
- Keep current-code evidence distinct from product proposals. Re-audit source references when the baseline changes.
- Preserve the existing app's Hive IDs, boxes, user data, and accepted phone behavior. A new project is not authorization to migrate or overwrite the phone app.

## Documentation review checkpoint — 2026-10-20

The dossier received separate frontend, isolation/event, and persistence reviews. Review corrections aligned command-writer proposals, player/session invalidation, immutable event-time data, numeric utility fixtures, format-import coverage, and phase dependencies. Relative file targets, decision/validation IDs and Markdown fence balance were checked; the source audit's baseline paths/line ranges were verified against Git objects. These are documentation checks only. No IPAD EDITION app build, device experiment or acceptance scenario has run, and all product decisions were open at that checkpoint. The 2026-10-21 accepted decisions below supersede that historical status.

## Decision update — 2026-10-21

Recorded separate-product, cross-platform and 2–4-player decisions; retained six-player expansion and custom keyboard options as deferred documents. All keyboard input must face its initiating player. The subsequent explicit answer “No simultaneous keyboards.” settles one keyboard at a time; D41 later settles modal sequential use and tapaway consumption; native/IME details still need validation. No app code, build configuration or acceptance result is changed by this documentation update.

## Terminology

| Term | Meaning |
|---|---|
| Table / game session | One shared game containing participants and table-level settings |
| Player | Stable participant identity within that session; not an authenticated account |
| Persistent seat | User-facing player identity/customization retained between games, including name and color/art presets |
| Seat slot / quadrant | Screen placement and orientation; distinct from persistent seat and game-local state |
| Token lane | One player's independently ordered token stacks |
| Utility lane | One player's independently ordered utilities; existing internal `Widget` names may remain |
| Life panel | One player's view into central life state; never a draggable token/utility entry |
| Actor | Player initiating a command; does not imply the UI can identify the human touching glass |
| Target | Player or object explicitly affected by a command |
| Owner / controller | Magic concepts reserved for future explicit control-transfer support; do not conflate with a screen coordinate |
| Companion token | Informal name for an additional generated token, such as a Squirrel; not the Magic companion mechanic |

See the [second-pass granular baseline map](outstanding_behavior_baselines.md) for concrete old-design starting points across the remaining questions and the ranked next genuinely new decision.

## Modifier scope checkpoint — D25

D25 now accepts seat-owned local/global modifiers; global sources affect the table, recipient panels cannot independently remove them, and independent copies remain independent. Exact inherited-effect representation is still a UI choice. See [modifier ownership and applicability](modifier_ownership_and_applicability.md).

## Tablet-first MVP boundary — D06/D30

MVP supports tablets from iPad mini through full-size iPads and Android variants, retaining the complete active 2–4-seat view. Android/iOS/web targets remain; web support uses tablet-suitable viewports. Exact minimum dimensions, model generations, OS/browser floors, aspect ratios and orientations require validation, not guesses. Small-tablet fit is mandatory; no MVP phone or focused-seat mode. The [closed-focus/unfolded-multiplayer foldable concept](foldable_phone_future_version.md) is deferred to another major version and does not add a standalone one-player game.

## Accepted archive safety and retention — D33

Save the current game before archive restore; keep the latest ten archived game-state snapshots, oldest evicted on new saves. Active working state is separate and each retained snapshot keeps its full timeline/undo information. Restore game-specific state without overwriting saved decks or permanent seat customization. Protect the selected archive from eviction during restoration and preserve the old active state on failure. See [transaction contract](game_history_and_undo.md).

## Explicit carryover clarification — 2026-10-22

Follow TS deliberate design principles unless concrete incompatibility requires adaptation. Wipes are token-level; resets clear rule activation per TS. TS decklist import/shared catalog feed, standard dice, iterative Lifetap-informed life UI and per-seat Rules-equivalent applied-effects menu are accepted. Free/no ads with optional FV/TS-style support IAP cosmetics. Working names are listed in the clarification record. See [source-backed decisions and limitations](implementation_carryover_clarifications.md).

## Full token parity correction — 2026-10-22

The entire original TS token functionality, deliberate density and direct controls must carry over. Reuse the existing token implementation where practical and adapt lane constraints/seat-session integration; a new board container is not a mandate to rebuild or simplify tokens. Any parity-reducing exception requires explicit justification and approval. Review [the source-backed token inventory and acceptance method](token_functional_parity.md), not just row aesthetics or generated mockup styling. No specific runtime mismatch is claimed without implementation evidence.

**Accepted compact-control direction (2026-10-22):** familiar controls are compact and icon-led, not large labeled toolbar rows; TS FAB patterns are precedent, not mandatory. Seat name appears in its life counter without redundant board “Seat N” labels. Preserve meaningful text, accessible semantic names and necessary shared-editor target identification. See [layout guidance](02_layout_and_interaction.md#compact-controls-and-restrained-chrome--accepted-2026-10-22).

## UI feedback batch — 2026-10-22

The completed user feedback batch is implemented on a review branch; see [the addressed checklist, measured verification and remaining blockers](ui_feedback_batch_2026-10-22.md). It supersedes older header/strip/modal presentation suggestions while retaining the original token behavior baseline. Native/browser acceptance remains distinct from renderer and automated evidence.
