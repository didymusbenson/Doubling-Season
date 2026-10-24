# Six-player expansion

**Status:** deferred feature, requested 2026-10-21. Initial scope remains customizable **2–4 players**; five/six-player implementation and release support are not promised now.
**Related:** [D04](../MVP/09_decision_register.md), [layout](../MVP/02_layout_and_interaction.md), [validation](../MVP/08_delivery_validation_and_risks.md).

The D36 scope distinction also applies to future seats: central controls remain app/game-level regardless of position; affected-seat sets are not human actor identities. Expansion must not introduce strict seat permissions; D41 explicitly requires whole-table blocking whenever any modal is open.

Future capacity reviews must preserve dedicated life plus attached damage/counter shortcuts, separate curated utility lists and shared-control space. Include dismissible default-visible storm/mana and discoverable hidden nonzero values. This is design leeway only, not six-player implementation or one-player scope.

**Accepted D41:** any open modal blocks interaction with the entire underlying table. Tapaway dismisses through an app-level overlay and consumes that gesture: no click-through, background mutation, queued second editor, takeover or “busy” notification. One player finishes/dismisses before another opens an editor. This applies to search, editing, confirmations and other modals, not only game-level actions. It does not imply blocking ordinary nonmodal quick controls when no modal is open. No toasts/snackbars for routine feedback, waiting or errors; use in-context status and explicit controls. An exceptional transient notification requires a demonstrated unavoidable need, not convenience.

## User direction

“The flexibility of 2-6 players will make a difference I think. Initial scope should be customizable 2-4 players with a deferred feature doc to expand to 6. The designs should have room and leeway to make 6 players possible.”

## Leeway to preserve now

- Separate stable player identity and collection-based state from physical seat position; do not make four quadrants a permanent domain invariant.
- Keep life, lane order, rules, drafts and mutations scoped to a player independently of layout. Do not create hidden fifth/sixth live players in the first version.
- Keep seat geometry/orientation composable rather than baking four offsets into every control. This does not require a speculative six-seat UI or general layout editor now.
- Treat four-player acceptance fixtures as examples, not proof that more players will fit or perform adequately.

## Full tracker capacity carried forward

D26’s required life/counter/status/shared-state and self/partner damage model also constrains expansion. Six players with two commander sources each means twelve selectable sources per recipient, including self, and up to 72 recipient/source ledger pairs. This is a future stress/layout fixture, not approval to implement six-player support now. Preserve one monarch holder, independent player blessing/counters and one game-level day/night; never clone shared state per seat or omit self sources to save room.

## Persistent seats at a larger table

The accepted first-release roster preserves inactive seats’ name/color/art instead of deleting them when the active count drops. Future five/six-seat design should extend that identity/visibility separation without implementing extra seats now. Removed seats lose game-specific tokens/utilities; only remaining seats retain reusable setup when keep-board is explicitly selected. Historical archive restore can recover the old game’s setup separately. Both full-reset modes preserve customization; settings hard reset is separate.

## History at a larger table

Preserve the accepted single chronological game history, player attribution, latest-global-action undo and durable current session. More players do not imply per-player undo stacks; any player’s different action interrupts the active group. Future capacity review must include frequent interleaving and history persistence without weakening token add/remove separation. Past-game archive policy remains separate.

## Decisions deferred until expansion review

Compare five/six-seat arrangements, central life geometry, lane space, touch targets, reach and player-facing keyboards at each orientation. Decide future six-player screen/window floors; do not import a focused-seat fallback into the accepted 2–4-player tablet MVP. Any future fallback is a separate scope choice. Validate the accepted one-keyboard-at-a-time policy and chosen handoff, accessibility traversal, sustained performance and recovery fixtures at the larger count; current 2–4-player evidence cannot substitute.

No team modes, networking, extra mana/rules automation or new distribution target is implied. Reopen this feature when the initial 2–4-player design is validated and the user is ready to choose the expansion scope. Record measured cloud visual/interactive and physical tabletop evidence before promoting it into release scope.

## Old-design inference checkpoint

The [granular baseline map](../MVP/outstanding_behavior_baselines.md) supplies concrete starting points for remaining behavior questions, including what current design cannot settle. These are explicitly inferred defaults, not additional accepted requirements; D41 and all earlier explicit decisions take precedence.

## Modifier scope checkpoint — D25

Future seats derive applicable global contributions from stable source identities. Expansion must not clone modifiers per seat or multiply an effect by recipient count; source ownership remains separate from applicability. See [modifier ownership and applicability](../MVP/modifier_ownership_and_applicability.md).

## Tablet-first MVP boundary — D06/D30

MVP supports tablets from iPad mini through full-size iPads and Android variants, retaining the complete active 2–4-seat view. Android/iOS/web targets remain; web support uses tablet-suitable viewports. Exact minimum dimensions, model generations, OS/browser floors, aspect ratios and orientations require validation, not guesses. Small-tablet fit is mandatory; no MVP phone or focused-seat mode. The [closed-focus/unfolded-multiplayer foldable concept](foldable_phone_future_version.md) is deferred to another major version and does not add a standalone one-player game.
