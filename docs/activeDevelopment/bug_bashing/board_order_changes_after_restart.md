# Board reordering is lost after restart

Status: implemented and persistence checks verified on 2026-09-26. Original
reproduction: iPhone 17 Pro Max simulator, iOS 26.2, 2026-09-25.
Build: current working tree, 1.11.0+19. No application changes during reproduction.

## Reproduction

1. Create Zombie (3), Brudiclad utility, Treasure (2 tapped), Monarch toggle.
2. Move Treasure to the start using the board's accessibility reorder action.
3. Confirm order: Treasure, Zombie, Brudiclad, Monarch.
4. Terminate and relaunch the app.
5. Actual order: Zombie, Treasure, Brudiclad, Monarch.

Before restart, token orders were Treasure=0 and Zombie=1; afterwards they
were Zombie=0 and Treasure=1. Read-only inspection of copied simulator Hive
files confirms the persisted rewrite. Names, quantities, counters, tapped/sick
counts and utility edits persisted; this is an order failure, not lost models.

## Root cause and next step

The providers' _ensureOrdersAssigned methods treat any order==0 as missing
migration data and rewrite each model collection in Hive insertion order.
Moving a card to the start can legitimately assign zero. Startup therefore
rewrites a valid user arrangement, independently for each board-item type.

This confirms the existing hygiene_audit.md ordering concern. Fix should replace
the zero-value heuristic with an explicit, idempotent unified-board migration,
preserving valid zero/negative/fractional positions and interleaved utilities.
No fix has been applied in this validation pass.

## Investigation — before fixing

- The same zero heuristic exists in TokenProvider, TrackerProvider, and
  ToggleProvider; this is shared-platform code, not an iOS-only issue.
- Token startup heuristic dates back to December 2025 and remains on main.
- Moving to the top calculates first.order - 1, so first.order == 1 creates 0.
- ContentScreen compaction also assigns 0 to the first item. Legacy insertion
  fallback can do the same. Changing only the reorder calculation is incomplete.
- Each migration writes 0 back to its first model, retaining its own trigger;
  it can rerun on subsequent launches and create collisions across item types.
- A prospective fix should preserve valid zero/negative/fractional positions,
  replace per-type startup heuristics with one explicit idempotent unified
  migration, and await persistence before marking migration complete. Existing
  Hive type IDs and box names need not change. Previously overwritten user
  intent cannot reliably be reconstructed from current order values alone.

No implementation changes made.

## Resolution and verification

Removed all three per-type zero-order startup heuristics. Shared comparison uses
finite position, then token/tracker/toggle type and Hive key for deterministic
legacy ties. Valid zero, negative, and fractional positions are preserved.
Counter-created stacks now explicitly request append placement. Reordering uses
the intended post-move sequence and normalizes only ambiguous/invalid positions
or exhausted gaps.

`BoardOrderPersistence` retains an order-only JSON plan in a primitive String
Hive box, `boardOrderOperations` (`pendingV1`). Existing board boxes, adapters,
fields, and type IDs are unchanged. Board writes are awaited and flushed before
the journal is removed; pending work completes before exposing the board.
Deleted keys are skipped, models are never recreated, and no gameplay events
are emitted. Input is absorbed while a reorder saves; failure blocks further
board interaction until restart recovery.

Simulator fixture checks: mixed negative/zero/fractional positions survived two
restarts unchanged. All-zero ties normalized deterministically across three
types. Gaps of 0.0001 normalized while preserving the sorted sequence. A journal
with only its first two rows already applied finished correctly. Each recovery
cleared its pending plan and remained identical after a second restart; every
non-order field compared equal before and after.

## Resumed checks — 2026-09-27

Current analysis, iOS simulator build and Android APK build pass. Android
Brudiclad drag reordered the live board and persisted through restart.
A temporary debug injection interrupted a Rhys reorder after the first save:
the recovery dialog resisted Back and background taps, the journal remained,
and the normal build completed the move on restart. All non-order fields
matched; the journal cleared; another restart was identical. Injection removed.
This simulates a failed write sequence, not actual disk exhaustion.

On iOS, saving/loading a mixed deck preserved the chosen sequence at positions
0–4 and all artwork metadata. Add-to-board appended the sequence at 5–9.
Both results survived restart unchanged. The full gesture matrix remains open.
