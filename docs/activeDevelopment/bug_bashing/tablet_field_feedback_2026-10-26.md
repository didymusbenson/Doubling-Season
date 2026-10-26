# Tripling Table field feedback — October 26, 2026

Implementation is in progress on the feature branch. The complete reviewed scope
and dependency order are in [the batch plan](../in_progress_features/ipad_edition/feedback_batch_2026-10-26_plan.md).
This document distinguishes source findings from native acceptance. No data
migration, release-version change or physical-device installation is authorized
by this document.

## Source-backed defects

- Collapsed token abilities requested three lines and ellipsis inside a fixed
  48-pixel crop (42 pixels after padding). Restore text-driven line height.
- Expanded token artwork explicitly bypassed the saved fadeout style. Scope the
  correction to tokens while reviewing shared utility surfaces.
- Player keyboard suppressed the editing toolbar. Shift remained active across
  fields and doubled as a selection modifier even in numeric fields. Separate
  capitalization, selection and clipboard feedback.
- Artwork URL input, progress/errors, candidate and Apply were separated in a
  scrolling form without revealing the result. Consolidate the staged flow.
- Custom authoring was exposed alongside preset modifiers. Hide authoring while
  retaining existing definitions and visible management of active effects.
- Board wipes only accepted one player. Everyone must be one transaction and
  one chronological Undo, preserving all non-target state.

## Native diagnosis still required

- All image uploads fail on iPad with a PlatformException. Shared file_picker
  image selection is the common boundary. Permission text and registration
  exist. Exact exception code/message/details and before/after-selection timing
  are not yet available. Do not claim a speculative plugin change fixes this.
- Life taps reportedly lag token interactions. Both quantity paths publish after
  durable storage; token expansion is different. Capture comparable timing before
  altering durability. Memory-fixture timing is not Hive or physical-iPad timing.

## Acceptance ledger

| Area | Status | Evidence |
| --- | --- | --- |
| Reviewed complete plan | Passed | Parent and independent review before implementation |
| Populated 75% shell geometry gate | Pending | Must pass before broad modal migration |
| Exact-head analysis/tests/builds | Pending | Not yet run |
| Integrated visual and interaction review | Pending | Cloud browser/rendered checks required |
| Combined Pages publication | Pending | Original and tablet artifact verification required |
| Physical iPad picker | Pending | Real selection/cancel/retry/preservation |
| Physical iPad editing | Pending | Selection toolbar, Paste, keyboard accuracy |
| Physical iPad life latency | Pending | Comparable input/save/frame timings |

## Explicit deferred design

- **Mana pool steppers:** mana pool by default, optional user-enabled additional
  steppers and possible Storm integration. No architecture adopted in this batch.
- **Custom Rules:** complete event/ordering/ownership/validation/editing semantics,
  preview, undo/persistence and recovery of saved definitions. Preset modifiers
  stay available; hiding authoring is not permission to delete or suspend effects.

Existing utility editor, Squirrel Girl and Ring design deferrals remain in their
own documents. Do not silently incorporate them into this cleanup.
