# Foldable-phone edition — future major version

**Status:** accepted future direction, explicitly deferred beyond tablet MVP. No foldable implementation, release date, model support or posture handling is committed now.

The future concept uses a focused single-seat view when the foldable phone is closed and a multiplayer view when unfolded. “Single-seat focused” describes which seat is presented, not an approved standalone one-player game mode or a change to the current 2–4-player game scope. Seat/game identity and gameplay state must not be inferred from screen posture.

MVP remains tablets, including iPad mini through full-size iPads and Android tablet variants, with complete active 2–4-seat layouts. Android/iOS/web targets remain; web is evaluated at tablet-suitable viewports. Neither a narrow phone browser nor a closed foldable view is an MVP workaround for small-tablet layout failures.

Before the future major version, design and validate focus selection, continuity between postures, hardware/hinge/window constraints, orientation, accessibility and custom player-facing input. Preserve stable seat/source identities, timeline and latest-global undo through presentation changes. Whether an open modal continues, adapts or dismisses during posture changes is future technical design; do not invent those rules now. Existing one-keyboard, target-label, whole-table modal barrier and source-applicability semantics are the baseline unless deliberately revised.

This deferred direction is independent of [six-player expansion](six_player_expansion.md). It does not approve six players, one-player standalone games, multi-device synchronization or automatic transfer of control. Revisit this document only when the next major version is scoped.
