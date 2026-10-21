# Six-player expansion

**Status:** deferred feature, requested 2026-10-21. Initial scope remains customizable **2–4 players**; five/six-player implementation and release support are not promised now.
**Related:** [D04](09_decision_register.md), [layout](02_layout_and_interaction.md), [validation](08_delivery_validation_and_risks.md).

## User direction

“The flexibility of 2-6 players will make a difference I think. Initial scope should be customizable 2-4 players with a deferred feature doc to expand to 6. The designs should have room and leeway to make 6 players possible.”

## Leeway to preserve now

- Separate stable player identity and collection-based state from physical seat position; do not make four quadrants a permanent domain invariant.
- Keep life, lane order, rules, drafts and mutations scoped to a player independently of layout. Do not create hidden fifth/sixth live players in the first version.
- Keep seat geometry/orientation composable rather than baking four offsets into every control. This does not require a speculative six-seat UI or general layout editor now.
- Treat four-player acceptance fixtures as examples, not proof that more players will fit or perform adequately.

## Decisions deferred until expansion review

Compare five/six-seat arrangements, central life geometry, lane space, touch targets, reach and player-facing keyboards at each orientation. Decide supported screen/window floors and whether any focused-seat fallback is acceptable. Validate the accepted one-keyboard-at-a-time policy and chosen handoff, accessibility traversal, sustained performance and recovery fixtures at the larger count; current 2–4-player evidence cannot substitute.

No team modes, networking, extra mana/rules automation or new distribution target is implied. Reopen this feature when the initial 2–4-player design is validated and the user is ready to choose the expansion scope. Record measured cloud visual/interactive and physical tabletop evidence before promoting it into release scope.
