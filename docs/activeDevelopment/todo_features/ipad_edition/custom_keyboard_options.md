# Custom keyboard options

**Status:** deferred design exploration, requested 2026-10-21; no options below are first-release commitments or implemented features.
**Related:** [input requirement](02_layout_and_interaction.md), [D09/D11](09_decision_register.md), [V34 validation](08_delivery_validation_and_risks.md).

## Fixed boundary versus later choices

Any keyboard input must face the initiating player. The chosen Flutter direction is a custom in-app input panel that can rotate with its player-facing entry surface. This covers numeric as well as text input, not just search or rename. System keyboards do not expose arbitrary per-seat rotation. Prototype validation is still required.

This document collects useful options for later review, prompted by the user's suggestion that a custom keyboard could include mana symbols. The subsequent explicit answer “No simultaneous keyboards.” settles one keyboard at a time (D09); request/handoff details remain open (D11). It also does not commit to a complete replacement for every native language-input service.

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
