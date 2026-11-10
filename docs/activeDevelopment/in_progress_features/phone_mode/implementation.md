# Phone mode: current implementation and acceptance

**Source inspected 2026-11-10 at `0273043`. Implemented, not release accepted.**
The phone source is present in `apps/tablet`; `feature/phone-mode` and PR #66 are
historical implementation checkpoints, not evidence of current remote status.
Use the [current update matrix](../tripling_season_update_plan.md) for migration
and release gates and the [October record](../../todo_features/unified_tripling_season/implementation_summary.md)
for dated tests and independent design choices.

## Required behavior and source

- `ui/table_presentation.dart` selects fixed Player 1 using physical display size
  on native builds, with a provisional 600 logical-pixel shortest-side threshold.
  Stable tablet web remains full-table; explicit preview builds may select phone.
- `ui/phone_player_view.dart` and `ui/table_screen.dart` provide fixed compact life,
  utilities then tokens in one scrolling body, and option C: Add Token, Utilities
  jump, More. Use actual Table styling, not discarded generated concept images.
- The same 2–6-player session and command authority serve both presentations.
  View changes are not player-count changes, resets, migrations or new histories.
- Phone native keyboards, retained field drafts and input cancellation are in the
  source. Tablet input remains player-facing. Pending accepted commands must
  complete once, and stale drafts must not overwrite newer state.
- Development iOS family `1,2` retains `LooseTie.Tripling-Table`; original IDs and
  providers are not used. No original-installation migration is wired at baseline.

## Evidence and remaining acceptance

Tests include `phone_presentation_test.dart`, `phone_draft_retention_test.dart`
and `native_phone_keyboard_test.dart`. Later whole-app recorded validation is
linked from the [current plan](../tripling_season_update_plan.md#validation-record-and-commands).
The October SDK-blocked/authored-not-executed status is superseded by later
recorded executions; it must not be repeated as a present tool limitation.

Still required for final acceptance: physical phone/foldable classification,
landscape/large-text/native keyboard and picker coverage, fold transitions during
holds and pending saves, stale/deleted draft targets, hidden-seat/partner state,
performance and accessibility. Keep actual device evidence separate from widget,
browser, simulator and build results. Current main/preview/native-install status
must be checked rather than inferred from these source files.

Original-product cutover and release remain held. Phone readiness does not prove
safe migration, entitlement continuity or complete original feature parity.
