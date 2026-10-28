# Dice visual feedback — 2026-10-26

Status: implemented; parent accepted selector and concise results visual gates. Independent production review found no blockers. The combined visual/life checkpoint passed 832 tests with 5 intentional skips, clean analysis, an iOS simulator build and release-browser smoke on the validated product source. PR CI and final parent review remain separate gates. Based on merged `82069d6`.

## Approved design

- Keep the fixed 75vw × 75vh workspace and focused navigation, without a header band or sibling tabs.
- Six native vector outlines distinguish D4, D6, D8, D10, D12 and D20. The central number is selected quantity; denomination stays visible outside the outline. Use a restrained neutral/selected palette, not the reference's rainbow fills.
- Require at least 4.5:1 text contrast and 3:1 outline/control contrast, including the visible zero state. Preserve disabled boundary semantics without reducing icons to a low-opacity tint.
- Six selector columns when natural-size tiles and the Close corner fit; otherwise three columns at tablet portrait widths. Preserve at least 44px controls and scrolling at constrained sizes. Roll stays below the entire selector, with a selected-count label.
- Results are a focused destination within the existing modal, not a stacked dialog. Matching outlines enclose individual rolled values, grouped by denomination. Subtotals and total follow the results. Back restores selection; Roll again replaces results without adding navigation depth.

## Preserved behavior

Current dice controls have no direct quantity editor; none is removed. Preserve default one D6, counts from zero through twenty per denomination, existing numeric tap/hold/release/cancel behavior, and explicit zero-selection feedback. The existing numeric hold recognizer repeats and accelerates even when the legacy repeat interval is null; tests preserve the actual behavior rather than assuming one-shot holds.

Use one `Random.secure()` per roll invocation, in existing insertion order, with exactly one `nextInt(sides) + 1` per selected die. A small immutable result model retains individual faces and derives totals. No randomness changes, game-state/history/archive writes, new persistence, release changes or device installation.

## Validation

- Contrast, distinct vector geometry, contextual quantity/result accessibility, field/control bounds and facing orientation.
- Deterministic RNG injection in tests verifies call order, face count/range, immutable results and totals, including all 120 selected dice and zero selection.
- Selector/results captures at portrait, landscape and narrow geometry, text scale 1.3, and mixed/maximum rolls. Parent reviews pixels.
- Back, reroll, Close, scrolling, count clamps, hold/release/cancel, unchanged table/history, and existing direct Dice entry.
- Update superseded string-list/layout tests while preserving their behavioral assertions; run full suite/analyzer and actual release-browser interactions before normal publication.

## Review notes

The initial full-width vertical results groups were rejected during self-review as unnecessarily sparse; results now wrap natural-size groups. Parent accepted selector contrast and Roll-below structure, requesting a more distinct octahedral D8 outline rather than a D20-like hexagonal silhouette.

Parent's concise-results refinement keeps denomination in the group heading and accessibility labels, without repeating it under each result die. Only multi-die groups show a subtotal; the grand total and total dice count remain below all groups. Selector labels are unchanged.
