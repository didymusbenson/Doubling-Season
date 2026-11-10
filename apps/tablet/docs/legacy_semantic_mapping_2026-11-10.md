# Legacy utility, counter and rule mapping checkpoint

This extends the isolated migration fixture converter to mapping revision **2**.
It is not a production migration, source-version certification or permission to
release. No startup path, original Hive adapter/type ID/box, app identity,
production aggregate or deployment configuration changes.

## Supported mapping

- Real `WidgetDatabase` tracker/toggle models and their real deck-template
  constructors are exercised through `LegacySnapshotCapture`.
- Passive built-ins become `legacy_tracker` / `legacy_toggle`. They retain their
  original independent values, active states, metadata and controls. A mutable
  name or random instance UUID never binds a source utility to canonical life,
  player counters, Monarch, Day/Night or City's Blessing. Explicit custom
  identity remains `custom_tracker` / `custom_toggle` even with a built-in name.
  This deliberately keeps the original utility alongside the Table's own
  player/game controls instead of guessing whether those pools are equivalent.
- Persisted `actionType` maps Krenko Mob Boss, Krenko Tin Street, Cathars' Crusade,
  Academy Manufactor, Hare Apparent, Rhys and Brudiclad to their existing Table
  implementations. Action/action-only flags must agree with supported behavior.
  Source labels are preserved; unrelated actions are never invented from names.
- Imported utilities carry `configuration.legacyInteractionVersion = 1`.
  Their original tap and **single-shot** long-press amounts are respected on
  board and in management. Existing Table utilities retain accelerating holds.
  Toggle descriptions/artwork follow the active state with the same fallback as
  `ToggleWidget.currentDescription/currentArtworkUrl`. Configuration survives
  aggregate serialization, undo and fresh preset save/load.
- Dedicated power/toughness counter fields become the Table's existing
  `+1/+0` / `+0/+1` counters. Base P/T, both +/- counter pools, other counters
  and the untouched raw legacy payload are retained.
- All nine built-in `preset_*` rule counts map to existing modifier kinds.
  They remain local to Player 1, including Primal Vigor: importing one player's
  source rules does not authorize altering other seats. The old Academy bool
  overrides the count exactly as `RulesProvider._loadPresetState` does, even
  when false; conflicting retained values produce an explanatory warning.
- Recognized custom trigger/outcome shapes preserve enabled state, copy count,
  ordering, trigger targets, outcome order and the original payload. Stable
  IDs retain typed source-record identity. Tests compare per-event outputs
  and counter arithmetic directly with the original `RulesProvider`, including
  disabled and mixed also-create/replace/multiply rules.

## Fail-closed cases

Unknown action/trigger/outcome identities, invalid flags/counts/quantities,
unknown active `preset_*` keys, non-default obsolete multiplier preferences,
and unsupported utility values/steps block activation. Disabled unknown custom
rules also block; retaining a rule that would change meaning when re-enabled is
not sufficient. Custom rule copy counts are currently certified only for 1–20.

Custom counters using reserved labels `+1/+1`, `-1/-1`, `+1/+0` or `+0/+1`
block conversion, even if a dedicated axis count is absent. The original app's
custom counter and dedicated field are separate identities; neither summing nor
choosing one preserves both. Duplicate custom counter names remain blockers.

Tied custom rule ordering blocks until source evaluation order is established.
The source calculator uses an unstable order-only sort. Distinct typed keys
with the same string form (for example integer `1` and string `"1"`) also block:
the original engine groups companion effects by stringified Hive key, while
stable imported entity identities must remain distinct. These are retained
recovery cases, not silently renamed or reordered rules.

Live board positions retain the original kind/key tie-break. Mixed integer/string
keys at an identical position block conversion because the original comparator
can be non-transitive. A pending original board-order recovery journal must be
resolved or refused by acquisition; this converter does not replay it.

The complete source inventory and mapping blockers remain in the existing
journal. Revision 1 verdicts cannot activate under revision 2. Use a new fixture
ID after changing the mapping revision.

## Verification and remaining gates

Focused tests exercise real model capture; every repository built-in; action
execution and exact content undo; rule arithmetic; counter collisions; old
Academy precedence; fresh preset loading; and phone/tablet board plus management
holds and toggle descriptions. Existing Table action/hold tests verify that
newly created Table utilities keep their existing behavior.

These fixtures describe repository models at `17af6ef`, not actual shipped
installation evidence. Native update validation, production authority/media
integration, historical source-version support, broader preference behavior,
same-identity no-uninstall upgrades and recovery UX remain separate gates.
The release remains held. See the integration record for aggregate validation.

Validation for this isolated branch with Flutter 3.41.2:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub test/legacy_*test.dart test/utility_*test.dart test/half_stepper_regression_test.dart test/update_foundations_integration_test.dart`: 154 passed.
- `flutter test --no-pub --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 test/legacy_migration_test.dart test/legacy_semantic_mapping_test.dart`: 30 passed.

Full-suite and release-build validation belong to the combined integration
checkpoint. Neither has been claimed from these focused runs.
