# Inline Counter Workflow V2

**Status:** Deferred follow-up — do not include in the first inline-token-details implementation

**Depends on:** `../in_progress_features/inline_token_details.md`

**Last updated:** 2026-08-28

## Premise

The first inline-token-details implementation opens a counter-management bottom
sheet for existing counters. Choosing **Add Counter** dismisses that sheet and
opens the existing full-screen `CounterSearchScreen`.

V2 removes that extra transition. Existing-counter management, predefined
counter search, and custom-counter creation should live in one continuous
counter workspace.

## Proposed Experience

- Tapping an expanded token's counter region opens one counter workspace.
- Existing built-in and custom counters remain editable at the top.
- An **Add Counter** mode expands or swaps content within the same surface.
- Search, predefined results, and custom-counter creation appear without
  dismissing and opening another sheet or full-screen route.
- Selecting a result returns to the existing-counter view within the same
  surface and visibly confirms the newly added counter.
- Closing the workspace returns to the still-expanded token.

## Implementation Direction

- Extract shared counter search, filtering, custom-counter creation, and
  mutation behavior from `CounterSearchScreen`; do not duplicate it.
- Preserve every current counter validation, cap, rules-engine interaction, and
  custom-counter removal rule.
- Decide whether the unified workspace remains a bottom sheet on phones and
  adapts to a larger presentation on wider screens.
- Preserve the expanded token while the workspace is open and after it closes.

## Non-Goal

This work must not broaden or delay the first inline-token-details
implementation. V1 intentionally retains the proven full-screen counter search.
