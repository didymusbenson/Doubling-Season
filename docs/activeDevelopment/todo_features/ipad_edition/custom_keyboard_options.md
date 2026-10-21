# Custom keyboard options

**Status:** deferred design exploration, requested 2026-10-21; no options below are first-release commitments or implemented features.
**Related:** [input requirement](02_layout_and_interaction.md), [D09/D11](09_decision_register.md), [V34 validation](08_delivery_validation_and_risks.md).

Seat-facing keyboard/draft context does not confer ownership of central history/wipes/resets. Game-level input must preserve app/game origin separately from the interaction orientation; exact central-input orientation/handoff UI needs design without weakening the accepted player-facing requirement (D36).

Accepted default-visible mana/storm utilities and fixed life shortcuts do not settle extra keyboard modes or symbol keys. Numeric edits still use the single initiating-player-facing input surface; dismissing a utility must not silently clear its value or discard a draft. Exact pending-draft handling stays open.

**D40 accepted:** detailed seat-specific search/editing uses the larger shared central workspace. The custom keyboard and field/results face the acting player while a label identifies the target seat. Spatial sharing does not change target scope. One keyboard remains the rule; rotation affordance, switching/handoff and background blocking are open. The generated C image is conceptual, especially its keyboard lettering; it does not approve new symbol keys or alter IME/accessibility requirements.

## Fixed boundary versus later choices

Any keyboard input must face the initiating player. The chosen Flutter direction is a custom in-app input panel that can rotate with its player-facing entry surface. This covers numeric as well as text input, not just search or rename. System keyboards do not expose arbitrary per-seat rotation. Prototype validation is still required.

This document collects useful options for later review, prompted by the user's suggestion that a custom keyboard could include mana symbols. The subsequent explicit answer “No simultaneous keyboards.” settles one keyboard at a time (D09); request/handoff details remain open (D11). It also does not commit to a complete replacement for every native language-input service.

## Required tracker inputs versus deferred keyboard extras

D26 now requires typed player counters and per-source commander damage including self, alongside life. Their numeric fields use the same one-at-a-time, initiating-player-facing keyboard contract. Selecting source CommanderId and recipient PlayerId must remain distinct; focus/handoff cannot redirect a ledger edit. Monarch, day/night and blessing may use non-keyboard controls, whose exact UI remains open. New commander damage/life coupling with independent correction is now accepted, but this does not approve symbol palettes, extra keyboard modes or automatic rules enforcement. Keyboard submission/cancel/handoff must integrate with history grouping without silently settling an unrelated player’s draft; any player’s different action closes the current game-wide group, while draft/keyboard lifecycle details still need design.

## Candidate options to discuss

- **Mana symbols:** an optional palette for W/U/B/R/G/C and generic costs; later discussion may consider X, hybrid, Phyrexian or snow notation. Choose the actual subset and supported fields deliberately. A symbol in a name/description is not mana-pool accounting or automatic payment.
- **Numeric mode:** compact digits, minus where valid, clear/backspace and explicit accept/cancel for life, quantities and counters. Each field still owns validation and permitted bounds.
- **Text mode:** letters, case, punctuation, cursor/selection and space, with optional symbol access. Consider whether common Magic notation such as tap/untap or +1/+1 merits shortcuts; these are candidates, not requirements.
- **Context-specific layout:** show only useful keys for the current field while keeping ownership, orientation and draft handling consistent. Do not accidentally insert symbol markup into a numeric value or search that cannot understand it.

## Representation and editing questions

| Open consideration | Decision/evidence needed before implementation |
|---|---|
| Symbol tokens versus literal Unicode | Compare plain canonical tokens such as `{W}` rendered with approved assets against Unicode where an appropriate character exists. Do not assume every Magic symbol has a standard Unicode glyph or universal font support. Define stored text separately from its visual rendering. |
| Plain-text search, export and fallback | Decide token normalization, searchable spelling/aliases, clipboard behavior and export/import round trips. Provide readable fallback text when icons/fonts are unavailable; preserve unknown tokens rather than silently deleting them. |
| Cursor, selection and backspace | Decide whether a rendered symbol is an atomic token; define selection across mixed text/symbols, copy/paste and deletion. Handle grapheme clusters, combining marks and emoji without splitting visible characters. |
| Localization and IME | Explore translated key layouts, diacritics, right-to-left text, composition/candidate selection and hardware keyboards. A custom Latin keypad is not proof of general multilingual input. Identify a usable fallback without silently abandoning player-facing input. |
| Accessibility | Evaluate semantic key/symbol labels, focus order, screen readers, switch/hardware navigation, contrast and text scaling. Rotated pixels alone do not establish accessible input. |
| Numeric/text modes | Decide field-to-mode mapping, signed/decimal constraints where applicable, mode switching and validation error placement. Retain drafts on cancellation/failure according to the field's policy. |
| Single keyboard / handoff | D09 requires one keyboard at a time, facing its initiating player. Preserve drafts and player/item identity; one player’s editing cannot mutate another’s state. D11 must choose request/handoff details without assuming automatic takeover, cancel or submit. Non-typing quick controls remaining usable is the recommendation. |

## Later review outcome

Select a small useful option set and permitted fields only after the core player-facing input prototype is usable. Record each selection as accepted, deferred or rejected, then add appropriate V34 and round-trip cases. Actual cloud interaction review precedes user installation; physical iPad and Android/web behavior require separate evidence. No new dependencies, symbol assets, licensing assumptions, data format or implementation work is authorized by this options list.
