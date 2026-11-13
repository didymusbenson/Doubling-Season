# Saved deck parity and safety — 2026-11-13

Status: in progress on `feat/preset-parity-safety-20261113`, branched from
`e54b634`. This is an isolated saved-deck fidelity and regression-test slice.
No new deck editor, overwrite workflow, root-app change, original-identity
activation, default-branch merge, deployment or release is included.

The owner asked to examine saved-deck parity and advance it while they continue
other tablet feature work. This record separates confirmed existing-flow defects
from deliberate product choices and work still needing product or native evidence.

## Comparison boundary

The original Season implementation under root `lib/` is the behavioral source
available in the repository. It is **not** a verified copy of the latest shipped
binary. The repository labels `1.11.0+19` as a release candidate; shipped-version
fixtures and a no-uninstall upgrade remain separate acceptance gates. The Table
comparison starts at the integrated migration-recovery checkpoint `e54b634`.

## Confirmed defects and bounded fixes

1. **Legacy JSON import discarded deck metadata.** Root `DeckProvider` exports
   `colorIdentity`, but Table constructed a smaller mapped preset without keeping
   the source deck. Phone-compatible export then always emitted an empty color
   identity, including for copied-installation presets whose original metadata
   was already retained. Preserve the raw source under the existing `legacy`
   representation and export its supported color identity. Do not reinterpret
   unknown metadata as gameplay or create new editing controls.
2. **Hidden ordinary utilities could lose visibility without a warning.** Phone
   v3 does not carry Table's visibility field; Table re-import defaults it to
   visible. The warning previously appeared only when a mana-pool utility was
   also present. Report visibility loss independently of the mana-pool omission.
3. **Per-token artwork display style is not a phone-v3 feature.** Root's token
   importer does not restore it and uses its own display preference. Report that
   limitation, while retaining the style in Table v4. This is an honest export
   warning, not a change to phone rendering or its format.

4. **An existing corrupt content-addressed artwork entry could be masked by the
   cache.** `TabletMediaStore.save` formerly skipped an existing hash key without
   verifying its bytes, then cached the incoming correct bytes as if import were
   durable. Regression reproduced before the fix. A conflicting/corrupt existing
   entry now fails closed and remains untouched; successful reuse still requires
   a flush. Owned input and stable read-only cached bytes prevent callers from
   mutating content underneath its hash while preserving drag-image identity.

### Existing behavior, not outstanding bugs

- Both original deck load and Table setup load create zero-state tokens. Current
  live amount, tapped/sick counts and counters are not saved-game snapshots.
- Table's separate token/utility lanes are intentional. Stable within-kind order
  and retained original source order are not permission to recreate a mixed lane.
- Current Table already preserves migrated deck metadata/cover/raw records,
  per-token artwork style, original utility hold amounts and toggle on/off art.
  The older October audit must not be treated as a list of current defects.
- Replace/Append are scoped, undoable gameplay commands. Library save/rename/
  delete are separate from game history. The existing delete UI says it cannot
  be undone through game history.
- Imported unknown/custom records must remain recoverable. Retention is not proof
  that every arbitrary utility/rule behavior has a supported Table counterpart.

## Actual feature differences, not authorized additions

Root `DecksListScreen`, `DeckDetailScreen` and `DeckProvider` support creating a
blank deck, duplicate, library reorder, editing color identity/cover, adding or
removing templates, bulk removal and mixed-template reorder. Table exposes save
current player, rename, delete, import/export, preview, Replace and Append.
Table does not expose an equivalent independent deck-editing workflow.

The audit records those differences; it does not add editors, overwrite-current-
setup, custom utility/rule authoring, or revised lane/zero-state semantics. Those
remain product decisions under P1/P2/P4 of the current plan. Original code's
unawaited writes are not behavior to reproduce.

## Ordered safety coverage

1. **Metadata and honest omissions:** actual schema 1–3 payloads, copied-install
   presets, v4 and phone round-trips; color, raw metadata, source immutability;
   hidden-only utility, mana, cover, upload and style warning combinations; invalid
   versions refuse without mutating the library. Confirm the UI warns before the
   file picker and Cancel leaves state unchanged.
2. **Portable artwork:** content-addressed bytes in token options, cover and toggle
   configuration; credits/style; fresh destination storage and reopen; missing
   bytes, checksum mismatch, malformed base64, size limits and failed library save.
   Immutable orphan media may remain after a later library failure; no active
   board or library entry should be partially applied.
3. **Cover and scope:** Save, Replace/Append with cover on a second seat, Undo and
   reopen at two/six seats; preserve other players, life/counters, history and
   saved definitions. A later permanent appearance choice must win over older
   preset appearance undo.
4. **Durability:** actual isolated repository/Hive writes with injected backup/
   current put/flush failures, in-memory publication, close/reopen and retry.
   These are filesystem/API fault tests, not physical-device or power-loss proof.
5. **Native acceptance later:** file picker/save/cancel, offline media rendering,
   installed restart, old-to-new upgrade and real-device accessibility. No
   shipped-installation, physical-device, store or release acceptance is implied.

## Source and evidence map

- [Current update plan](../in_progress_features/tripling_season_update_plan.md),
  M5/P4 and the held M9 gate.
- [Historical preset audit](../todo_features/unified_tripling_season/preset_audit.md).
- [Original provider](../../../lib/providers/deck_provider.dart), JSON import/
  export, duplicate, library order and zero-state loading.
- [Original deck editor](../../../lib/screens/deck_detail_screen.dart) and
  [list](../../../lib/screens/decks_list_screen.dart).
- [Table preset service](../../../apps/tablet/lib/features/preset_service.dart),
  [existing UI](../../../apps/tablet/lib/ui/workspace/library_pages.dart), and
  [copied-source mapping](../../../apps/tablet/lib/migration/legacy_migration.dart).

## Validation checkpoint

Before the aggregate pass:
- 17 new metadata/omission regressions plus existing utility compatibility and
  legacy migration tests: **46 passed**.
- Real isolated Hive cover/scope/failure tests: **37 passed**.
- Portable-media tests: **15 passed**, including the corrupt-existing-key
  reproduction, stable immutable byte identity, explicit verified export and
  malformed/oversized/empty asset rejection.
- Existing saved-setup UI tests plus hidden-only export warning/Cancel: **4 passed**.
- Independent review found no remaining blocker after preserving the rendering
  cache fast path and strengthening the warm-cache corruption assertion.
- Targeted analyzers and formatter passed. Complete analysis, full suite,
  namespace suite and unpublished release web build are running against the
  frozen final code; their results are not yet claimed here.

The corruption regression was observed failing before the media fix. Two initial
new-test fixture expectations incorrectly assumed the default board had no mana
utility; fixtures were corrected to represent their explicit hidden-only/empty
cases and selected suites rerun. A first aggregate launch was stopped when a
final defensive media check landed, then restarted against frozen source.

Media persistence checks close and reopen real isolated Hive files. The media
suite's aggregate/library-failure fixture is in memory; the separate durability
suite uses the real aggregate repository. No injected media-flush failure,
persistent full disk, physical power loss or native image-rendering pass is
claimed. Actual I/O/library failures may retain harmless immutable orphan media;
no recovery cleanup is added.

