# Hygiene Audit — Decisions Remaining After Stabilization

Status: decision backlog for the next release  
Created: 2026-08-29  
Source audit: `ai_docs/research/2026-08-29-inline-artwork-branch-code-audit.md`

## Purpose

The deterministic hygiene findings from the branch audit were addressed immediately. The findings below need an explicit persistence, recovery, or testing policy because several technically valid implementations have meaningfully different user-facing consequences.

They should be resolved before production cutover, but they are intentionally separated from the mechanical stabilization work so an incidental refactor does not silently choose product policy.

## 1. Unified board-order migration

### Problem

Tokens, trackers, and toggles currently migrate `order == 0` independently. Zero is also a legitimate first board position, so the heuristic can rerun and rewrite the cross-type ordering on later launches.

### Options

#### A. One-time migration version in preferences

- Add a unified-board migration version.
- On first launch for that version, read all three boxes, preserve the best available existing interleaving, assign unique orders once, and stamp completion only after every write succeeds.
- Future launches never infer migration state from item values.

Advantages: explicit, inexpensive, easy to reason about.  
Risks: SharedPreferences and Hive are separate stores, so the completion stamp must be written last and migration must be idempotent after interruption.

#### B. Persist a board-order index

- Introduce one authoritative ordered list of typed item references.
- Providers own item data; the board index owns cross-type position.

Advantages: eliminates floating-order collisions and makes reorder semantics explicit.  
Risks: new persisted schema, reference cleanup, more extensive migration, and a larger pre-release regression surface.

#### C. Normalize only when corruption is proven

- Detect duplicate/non-finite orders across the entire unified board.
- Normalize all item types together only when invalid.

Advantages: minimal schema change.  
Risks: cannot reliably distinguish a legacy board from a valid board with intentional zero; remains heuristic-based.

### Recommendation

Choose option A for the next release. Make the migration idempotent, back up the three collections first, assign stable unique positions in one unified pass, and record completion last. Consider option B only as a later architecture project.

## 2. Hive backup and recovery policy

### Problem

The current process copies live Hive files, overwrites the sole backup, and deletes live data before validating restoration. A torn backup or interrupted restore can amplify a recoverable problem into data loss.

### Options

#### A. Two-generation verified file backups

- Produce a consistent snapshot while writes are quiesced.
- Write to a temporary generation, validate that it can be opened/read, then atomically promote it.
- Retain current and previous verified generations.
- Restore into a staged location and validate before replacing live files.

Advantages: preserves the existing file-based approach and limits storage growth.  
Risks: requires careful coordination with open Hive boxes and platform rename behavior.

#### B. Logical export/import backups

- Serialize each supported model into an application-owned, versioned backup format.
- Validate the complete logical payload before applying it.

Advantages: independent of Hive file internals and easier to migrate across schema versions.  
Risks: more serialization code, larger validation surface, and potential drift from model adapters.

#### C. Append-only operation journal

- Record mutations and periodic checkpoints, replaying after failure.

Advantages: strongest recovery granularity.  
Risks: considerable complexity for the app’s current scale and persistence model.

### Recommendation

Choose option A now, with two verified generations and atomic promotion. Investigate option B for user-visible export/restore later; it complements rather than replaces operational backups.

## 3. Transaction policy for board-wide actions

### Problem

Board undo restores and Rhys-style multi-item actions currently perform sequential live mutations. A failure can leave a partially applied action or partially restored board.

### Options

#### A. Automatic all-or-rollback snapshot

- Capture a durable pre-action snapshot.
- Apply all writes.
- If any write fails, automatically restore the snapshot and report that the action was not applied.

Advantages: matches the confirmation preview and normal user expectations.  
Risks: rollback itself must use the safe recovery mechanism from section 2.

#### B. Stage a complete replacement and atomically promote it

- Build the resulting collections outside the live boxes.
- Validate them, then switch to the new generation.

Advantages: strongest transaction semantics.  
Risks: Hive does not provide a native multi-box transaction, so this becomes a broader persistence redesign.

#### C. Permit partial completion with recovery UI

- Track each applied mutation and present retry/repair controls when only part succeeds.

Advantages: may preserve useful work under intermittent failures.  
Risks: confusing in gameplay, contradicts immutable confirmation previews, and creates many complex intermediate states.

### Recommendation

Choose option A. Users perceive these actions as atomic, so failure should leave the board exactly as it was. Build it on top of the verified backup/restore mechanism rather than adding a second unsafe snapshot implementation.

## 4. Automated test policy

### Problem

The only checked-in test was Flutter’s obsolete counter template. It did not initialize app persistence, tested deleted UI, and failed. It has been removed during stabilization, restoring an honest manual-testing-only repository state.

### Options

#### A. Continue manual-only testing

- Keep the test directory empty.
- Document a repeatable acceptance checklist for board order, editing, artwork, utilities, recovery, and upgrades.

Advantages: matches the current project policy and has no harness-maintenance cost.  
Risks: persistence regressions and lifecycle races are difficult to catch consistently.

#### B. Add a narrow non-widget regression suite

- Test pure ordering/migration planning, version compatibility, manifest verification, token database parsing, and board-action result planning.
- Keep visual and device behavior manual.

Advantages: protects the highest-risk deterministic logic without requiring a full mocked Flutter application.  
Risks: changes the current testing convention and requires keeping domain logic separable from Hive/UI code.

#### C. Build a full provider/widget integration harness

- Initialize isolated Hive boxes and pump production provider trees.
- Test editing, collapse vetoes, and board actions end to end.

Advantages: broad regression coverage.  
Risks: highest maintenance cost and likely brittle while the board architecture is still evolving.

### Recommendation

Choose option B after this release stabilizes. The first targets should be unified-order migration, token database update validation, and all-or-rollback board-action planning. Until that policy changes, maintain a concrete manual acceptance checklist and do not check in placeholder tests.

## Completed deterministic hygiene work

The companion stabilization pass:

- Preserves artwork selections across offline/cache/download failures.
- Validates remote artwork before committing a selection and awaits persistence before dismissing the sheet.
- Enforces token database size, hash, parseability, and minimum app version.
- Stages token database and manifest updates with previous-generation rollback.
- Makes expanded-card collapse locking exception-safe.
- Resolves asynchronous `BuildContext` lifecycle findings.
- Serializes utility inline commits and cleanly reverts invalid empty names.
- Awaits status/counter persistence, guards concurrent mutations, and removes redundant saves.
- Adds artwork network timeouts, byte limits, bounded decode width, and codec disposal.
- Makes game-event subscriptions removable and disposes provider subscriptions.
- Adds early Android release-signing diagnostics.
- Moves store initialization after the first UI frame path.
- Removes the obsolete failing template test.
- Clears the full static-analysis baseline, including deprecated APIs and hygiene lints found by the audit.

