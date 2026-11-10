# Copied-source and semantic migration integration

Feature branch: `feat/table-migration-integration-20261110`.
This integrates source acquisition `7dc28a8` and semantic mappings `b62852a`
onto the validated save/support/catalog checkpoint `60ff248`.

This is a copied-fixture development checkpoint. **Release remains held.**
There is no startup migration, original-install replacement, automatic source
repair, production data promotion, main merge or deployment. No original adapter,
Hive field number, store name, identity, signing configuration or store product
was changed.

## Contracts reconciled

- The copied-source reader retains raw files and source evidence before decoding
  through the existing root adapters. Android/Apple preferences are decoded as
  data without initializing the original app or its preferences. All seven
  collections remain mandatory unless explicitly absent in the declared copy.
- `LegacySnapshotCapture` supplies detached types expected by mapping revision 2.
  Typed keys, root model defaults, action dispatch identities, axis counters,
  utility interaction metadata, toggle-state art and rules survive the handoff.
- The mapping keeps passive legacy utilities independent instead of guessing
  bindings from mutable names. Known actions and recognized rules remain local
  to Player 1. Existing raw preference precedence is respected, including the
  older Academy boolean overriding the newer count even when false.
- Raw archive and fixture journal remain separate retained authorities. The
  acquired source re-verifies the raw archive before staging. The journal refuses
  unresolved blockers and mapping revision 1 verdicts. Neither archive is the
  production game/media store; no later-game integration is implied.
- One old source-reader happy-path fixture used integer/string keys at an equal
  board position. Revision 2 correctly rejects that ambiguous source comparator.
  Its successful example now gives the records distinct positions. A new actual
  Hive integration case explicitly retains and blocks the original tied case.
  The fail-closed mapping was not weakened to satisfy the old test.

## Cross-component evidence

`test/legacy_acquisition_mapping_integration_test.dart` adds eight cases using
real Hive files from all 13 current root adapters in a private writer registry,
then closes all source writers before acquisition. Raw recovery and candidate
stores are real separate Hive fixtures. These are generated repository fixtures,
not backups from actually shipped installations.

The successful flow proves source capture → preference decode → semantic map →
media remap → journal commit → close/reopen → exact retry, followed by fresh
preset loading on another seat. It verifies:

- Updated/tombstoned Hive records, distinct typed identities, duplicate deck
  names, live quantity/tap/sickness and dedicated/custom counters.
- Independent passive values, known action identity, original hold increments,
  active/inactive toggle descriptions/art and artwork credits/readback.
- Built-in and custom rule counts, disabled Academy precedence and seat locality.
  Executing captured Krenko with 11 Goblins plus its source value of 3 creates
  448 tokens under the retained 2 Doubling Seasons, 1 Primal Vigor and two custom
  doubling effects, then Undo restores the exact player contents. Other seats
  remain unchanged.
- Fresh presets reset token gameplay state, use utility defaults and inactive
  toggle appearance, and do not import the live player's rules or life.
- Raw file bytes and source hashes remain unchanged; original-global and Table
  aggregate sentinels remain untouched. Unsupported custom-definition fields,
  unknown preferences and cached supporter evidence remain retained only.

Five actual-Hive failure cases preserve recovery material and refuse commit:
reserved custom counters, unknown action identity, disabled unknown rule outcome,
ambiguous tied mixed-type keys, and an unknown active preset preference. Another
case refuses a pending original board-order journal before conversion. The last
case corrupts retained evidence after acquisition and verifies staging refuses,
then restores the deliberate test fault and proves exact retry is possible.

Independent static review found no correctness issue across reader/capture/map/
journal interfaces. See [source limits](legacy_source_acquisition_2026-11-10.md)
and [semantic limits](legacy_semantic_mapping_2026-11-10.md).

## Validation

Combined analyzer and focused suite: **307 passed, one expected namespace-only
skip**, including the eight new integration cases. Full regression, explicit
namespace and release-web validation are in progress; final evidence will be
recorded for the exact source tree. Component-only counts in the two linked
records remain historical evidence, not a substitute for these combined checks.

## Remaining gates

Actual shipped-version copies/adapters and quiescent device acquisition remain
uncertified. Raw archive placement/retention, production aggregate/media commit
coordination, later-play protection, image decoding, missing-file recovery UX,
unsupported semantic cases and broader preferences still need work. Native
no-uninstall upgrades, platform/device floors, real purchase restoration,
accessibility and hands-on phone/tablet acceptance remain separate. No collective
migration-safe or release-ready claim follows from this fixture integration.
