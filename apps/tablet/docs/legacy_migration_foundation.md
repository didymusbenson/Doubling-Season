# Legacy migration foundation (fixture-only)

Updated 2026-11-10. This is an implementation checkpoint, **not a declaration
that an original-app update is safe**, a production migration, or a release.
The canonical acceptance plan is
[`tripling_season_update_plan.md`](../../../docs/activeDevelopment/in_progress_features/tripling_season_update_plan.md).

## Safety boundary

Nothing calls this code at app startup. Original Hive adapters, type IDs, box
names, preferences, app identities and release configuration are unchanged.
The fixture journal cannot promote data into `TableRepository` or
`TabletMediaStore`. Its `tablet-art:` references resolve through the journal's
own `readMedia` API; integrating production aggregate/media authority remains
future work. Do not copy the aggregate alone into the normal app.

`HiveLegacyMigrationStorage.openFixture(fixtureId)` creates only an explicitly
named `legacy_migration_fixture_<id>_v1` box, with the existing build namespace
prefix when applicable. It never opens original boxes, deletes data or attempts
corruption recovery by resetting a store. Hive initialization and the choice of
an isolated test directory are the caller's responsibility.

## Implemented sequence

1. `LegacySnapshotCapture.capture` serializes caller-supplied consistent,
   detached legacy models and complete preference data. It requires all seven
   source collections even when empty. It preserves typed Hive keys, deck covers,
   dates/order, artwork/credits, counters, utility configuration, rule data and
   unknown custom-token JSON fields. It does not read a live installation, copy
   raw Hive files, invoke model setters, or infer the actually shipped version.
2. `LegacyMigrationSnapshot` validates the versioned inventory. Canonical JSON
   hashing gives identical input a stable identity independent of map key order.
   Source IDs are explicit caller-provided installation identities, not names.
3. `LegacyMigrationConverter` separately stages Player 1's live tokens and saved
   zero-state presets. Deterministic IDs include the source collection and typed
   key. Duplicate deck names and integer/string keys remain distinct. Live
   quantities, tapped/sick counts, counters, token metadata and art are retained.
   Presets preserve ordering/covers and later load fresh on either seat. Saved
   token artwork styles now survive preset save/load too.
4. `LegacyMigrationJournal.prepare` first retains a checksum-protected source
   inventory and media manifest. Callers supply already-copied local bytes; no
   path or network URL is followed. Bytes are copied defensively, content-hashed,
   durably stored, read back and hash-verified before references are remapped.
   Known artwork fields are remapped; descriptions are not rewritten. Remote
   art/credits stay unchanged. Missing files keep their original selection and a
   recovery warning. The original source inventory remains unchanged.
5. The entire candidate, issues, identity map and media manifest are durably
   staged and verified. `commit(transactionId)` refuses unresolved conversion
   blockers, then writes the candidate and its migration receipt together as
   one current record. A checked mapping revision prevents an older staged
   verdict from bypassing newer safety rules; bump it when mappings/blockers
   change and use a new fixture ID. Reopen verifies source/receipt identity, aggregate
   invariants, checksums and every copied media record. Retries use existing
   records and reject changed snapshots/media rather than overwriting them.
   Concurrent callers serialize per physical fixture store. No automatic cleanup
   or recovery-retention expiry exists.

## Explicit mapping limits

- Only explicitly custom, non-action tracker/toggle utilities are mapped in this
  slice. Display names and random widget IDs are never treated as semantic
  identity. Built-in/action utility counterparts, canonical life/status mappings
  and rules block commit until their semantics have dedicated mappings/tests.
- Custom toggles with state-specific artwork and trackers whose long-press
  increment differs from their tap increment block activation pending parity.
- Nonzero independent power/toughness counters and duplicate custom counter
  names block activation rather than being silently collapsed. Source values
  remain in retained recovery data.
- Custom-token definitions, favorites/recents, theme and summoning-sickness
  preference are copied without consulting/replacing them with catalog entries.
  Global artwork defaults remain separately retained, not applied to every seat.
  Full preferences are retained, including supporter metadata, but cached flags
  are never interpreted as verified purchase ownership. Non-default legacy
  multipliers and active built-in `preset_*` modifier preferences require future
  explicit rule mapping and block activation.
- Four seats/40 starting life are explicit fixture defaults, not recovered match
  information or an approved production first-run policy.
- Old model getters can already normalize some invalid legacy values (for
  example a null token type to empty). This serializer cannot replace a raw
  source backup or certify unknown older adapters.

## Verification

Run from `apps/tablet` with Flutter 3.41.2:

```sh
flutter analyze
flutter test test/legacy_snapshot_capture_test.dart test/legacy_migration_test.dart
flutter test --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 \
  test/legacy_migration_test.dart test/storage_namespace_test.dart
flutter test
```

The focused suite covers complete model capture; malformed/unknown source;
unchanged original input; typed identities/duplicate names; live board versus
preset load; artwork styles/credits; source retention; missing files; changed
bytes/source refusal; unsupported mappings; checksums; concurrent retries;
and real Hive close/reopen while original/tablet sentinel boxes stay unchanged.
A fault-injection test interrupts **before and after every storage read, write
and flush** of the successful fixture flow, drops unflushed cache on simulated
crash, and proves retry reaches the exact same durable generation with no
additional records or identities.

Still required before migration-safe status: actual shipped-build support and
raw fixtures; quiescent/raw backup acquisition; source adapter validation;
remaining utility/rule/preference parity; image decoding and representative
large/full-disk fixtures; production aggregate/media commit integration and
later-game restart checks; same-identity signed no-uninstall device upgrades;
real purchase restoration; catalog compatibility; user-visible recovery;
minimum-OS/device support; explicit retention and cutover/rollout decisions.
Browser tests or isolated fixture tests cannot substitute for those gates.
