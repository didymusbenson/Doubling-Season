# Next pass — collect before implementing

**Status:** feedback collection only, started 2026-10-23 (America/Phoenix).
The user is field testing the [MVP baseline](../mvp_readiness_audit.md) on iPad
and wants a substantial batch of observations before implementation resumes.

## Collection

Add observations to [field_test_feedback.md](field_test_feedback.md). Preserve
the user's wording and distinguish an observed problem, preference, question,
positive result and unrun acceptance case. Record device/build, player count,
orientation, the workflow, expected/actual behavior, frequency and available
screenshots. "Unknown" is better than inventing context or reproducibility.

An observation is not an approved fix. Do not preselect a solution from one
example, bundle unrelated preferences into a bug, or promote the old
[future directions](../future/README.md) into this batch automatically.
Data loss or unsafe cross-player changes should be recorded and surfaced
promptly; they still do not authorize unsolicited app edits.

## Batch review, when the user is ready

1. Group observations by workflow/root cause and retain their original IDs.
2. Separate confirmed defects, usability refinements, scope additions and open
   validation; preserve behavior users report working well.
3. Agree priorities, tradeoffs, exclusions and a bounded implementation batch.
4. Write one batch specification with observable acceptance checks, including
   relevant [MVP validation obligations](../MVP/08_delivery_validation_and_risks.md).
5. Implement only that agreed batch, validate the affected paths, then follow
   the repository's normal PR/publication workflow.

No implementation batch, release date or expanded feature scope is selected yet.
