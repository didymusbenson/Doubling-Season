# Remember last rolled dice / Clear (2026-11-20)

Based on build 20 `3ed1fde8f2daa49bb3f75c4204914e78a0aa6059`.

Dice remembers the last actually rolled mix and quantities in the existing local
Table aggregate settings (`lastRolledDice`). Uses the acknowledged `updateState`
writer, not game history or a second preference store. Random faces remain
transient. Fresh/invalid settings fall back to 1d6. Opening Dice reloads this
preference; abandoned edits and Clear never save a selection. Clear empties all
six types and disables Roll, while preserving the last-used preference. A failed
preference write reports an error without replacing the acknowledged selection.

Validation on Kista's Mac, isolated feature worktree and synthetic repository:
- 40 Dice widget/unit/animation/accessibility tests passed.
- Includes fresh default, multi-type quantities, close/reopen, serialized-state
  relaunch, canceled edits, Clear, failed persistence and a subsequent new roll.
- Analyze clean; diff whitespace check clean.
- Rendered widget captures visually checked at 390x844 and 1133x744: Clear sits
  next to Roll with no overlap. Additional existing layout cases cover small
  landscape and text scaling through 1.3. These are rendered test fixtures,
  not native iPad acceptance.
- Full integration suite belongs to the integrating branch; not rerun here.

No device installation, deployment, merge, storage schema change or dependency
change. Other worktrees and active device data were not touched.
