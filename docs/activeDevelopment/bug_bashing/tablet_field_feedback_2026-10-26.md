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
| Populated 75% shell geometry gate | Passed | Parent-reviewed supported tablet matrix; explicit narrow-case limits below |
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

## Cloud implementation evidence (2026-10-26, ongoing)

- Official Flutter 3.41.2 source tag `90673a4eef` installed in the cloud workspace,
  Dart 3.11.0. Dependency resolution preserved both lockfiles.
- First source checkpoint `d6dda17a7f9e103c93e9a812f1a73a6bd31c0937`, draft PR 53:
  token presentation parity and atomic Everyone service. 21 new token tests plus
  28 existing token regressions passed; 11 Everyone tests passed; scoped analysis
  clean. The service is not yet connected to the UI at that checkpoint.
- Four opt-in memory-fixture latency diagnostics passed (20 commands per case).
  Median total/save milliseconds: empty-history life 5.983/1.263, token 2.776/0.637;
  150-entry-history life 9.602/3.280, token 9.644/2.995. These sequential samples
  include cold/JIT effects and exclude pointer dispatch, Hive I/O, frames and
  physical iPad behavior. They do not establish the reported latency root cause.
  Durable save-before-publish is unchanged.
- Initial integrated suite: 546 passed, 5 skipped, 8 failed due to an ambiguous
  nested ManaText paragraph finder in the new test, subsequently fixed and all
  21 focused cases rerun successfully. This is not a final full-suite pass.
- Geometry prototype initially passed overflow assertions but failed visual UX
  review: narrow keys were undersized, and short-landscape scrolling hid most
  of the keyboard. Gate remains open while a keyboard-focused mode replaces
  form/header duplication inside the unchanged shell. Do not mistake structural
  no-overflow checks for usable rendered interaction.

### Native importer source evidence

Locked file_picker 8.3.7's PHPicker path can emit `file_picker_error` / “Failed to
process any images” after item-provider representation processing. Its presenter
already searches scene windows; the tablet Podfile does not exclude media picker
support. The user has not supplied the exact exception details, so neither the
provider-processing hypothesis nor a presentation hypothesis is established.
The original phone app uses ImagePicker gallery selection, but swapping the
plugin without diagnosing this failure is not treated as a proven repair. Keep
errors actionable and retryable without changing permissions or plugin majors.

### Geometry gate outcome and migrated routes

Parent reviewed the populated focused-keyboard rendering before broad migration.
Supported tablet cases 1133×744, 744×1133, 1024×600 and 600×1024 pass all four
rotations with player-local modal width at least450px; short844×480/844×390
landscape cases pass actual table seat rotations0/2. Text scale1.5,44px key
bounds, active text/Close/Done, typing and restored-form Apply are covered.
Short-view odd quarter turns produce360/292.5px local widths and require
horizontal keyboard scrolling; those narrow cases are explicitly **unsupported
and not ergonomically accepted**, not universal all-rotation passes. The table
itself currently uses seat rotations0/2.

The shared shell now covers workspace pages/secondary corrections/confirmations,
life artwork, crop, support and hide-utility confirmation. Standalone board
keyboard and native OS pickers remain the documented structural exclusions.
No page-specific geometry caps remain. Quarter turns swap local dimensions while
retaining the physical75% viewport rectangle. Root dialogs disable external
SafeArea sizing so safe-area fixtures do not silently shrink the contract.

The two-player direct-control geometry adaptation is recorded in the plan:
Dice/DayNight occupy opposite life-zone inner corners while the existing hub
stays at exact table center. Three/four-player controls remain adjacent.
Life numbers retain their prior centers; names move below totals to reserve
shared-control clearance. Utility lanes may scroll modestly further rather than
shrinking controls.

Current focused evidence before integrated CI:120 modal/utility tests,53 player/
commander navigation tests,27 keyboard tests,20 artwork tests,20 shared-control
matrix tests,58 existing life/layout tests,2 custom-effect visibility/state tests
and1 utility artwork staging/failure/retry test pass. These overlapping focused
runs are not summed into a claimed unique test count. Full exact-head suite,
release browser interaction, combined publication and native gates remain open.

Local browser execution was blocked by cloud sandbox socket isolation; no sandbox
workaround was adopted. The feature-branch CI harness uses the runner's installed
Chrome and Node built-ins to serve the exact release output locally, exercise
real UI input, and preserve screenshot/accessibility/network/commit evidence.
This does not deploy a new site or validate physical iPad behavior.
