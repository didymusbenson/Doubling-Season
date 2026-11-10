# Historical repository Hive fixtures, not shipped-device captures

These are **synthetic fixtures generated in November 2026**, using byte-exact
models, generated adapters and constants retrieved from the repository commits
below. No archived application binary or real user's installation is available
in this slice. This does not establish which schema shipped on any platform and
does not satisfy the release gate for genuine shipped-installation copies.

| Repository commit | Schema exercised |
| --- | --- |
| [371577867932fed1643f809e4645b3a59d948b96](https://github.com/didymusbenson/Doubling-Season/commit/371577867932fed1643f809e4645b3a59d948b96) | Item fields 0–10; TokenTemplate fields 0–3; Deck fields 0–1 |
| [d9e19b69b32d63b8e9b98af4d3cca991b66b131a](https://github.com/didymusbenson/Doubling-Season/commit/d9e19b69b32d63b8e9b98af4d3cca991b66b131a) | Adds Item order field 11 and TokenTemplate order field 4 |

Each `source/*.txt` is an unmodified `git show COMMIT:PATH` byte copy, archived
with `.txt` to keep old source outside today's analyzer/build inputs. Historical
lockfiles establish Hive 2.2.3 for both commits. `provenance.json` records exact
commit and SHA-256 digests for source and serialized fixture files.

`copy/` contains real Hive 2.2.3 frame bytes, including an overwritten integer-key
item and a deleted string-key item. A live Goblin has 11 total, 3 tapped, 2 sick,
and 4 charge counters. Its saved template has identity/appearance, not those live
counts. The later schema stores order 8.5. Preferences are synthetic Android XML;
other boxes are explicitly absent because these fixture schemas do not include
those models. This is not evidence that an unknown source box may be ignored.

## Reproduce

From `apps/tablet`, after restoring the existing locked dependencies:

```sh
python3 tool/generate_historical_hive_fixtures.py --dart /path/to/flutter/bin/dart
flutter test test/historical_hive_fixtures_test.dart
```

Generation materializes the exact archived source in a temporary directory,
registers **historical** adapters, writes and closes real Hive boxes, then copies
only the intended immutable fixture files. The driver uses Dart 3.11.0 with the
current locked Hive 2.2.3, not an asserted historical Flutter runtime. No current
root adapter writes these files. No production boxes or startup are used.
Regeneration should produce identical hashes; review any changes, never simply
accept new manifests to hide a failing provenance assertion.

The regression reads frozen bytes through `LegacySourceReader`, verifies raw
retention and no source changes, asserts defaults for fields absent in the old
schema, then exercises isolated coordinator promotion, reopen/retry and fresh
preset loading independently of the live player's state. Further coverage still
needs genuine shipped native copies, later utilities/artwork/rules schemas,
platform acquisition and startup cutover tests, and release/native acceptance.

## Ordering safety finding and fail-closed rule

The archived `3715778` screen sorts by `createdAt` (lines 122–123), before an
explicit order field existed. Missing order currently defaults to zero in the
modern adapter; applying the modern key tie-break would silently reorder a
multi-record historical board. `multi/` deliberately has integer-key records
whose chronology opposes key order, so this cannot hide behind a single-record
success or the existing mixed-key ambiguity blocker.

Copied-source acquisition now counts **surviving live frames across tokens,
trackers and toggles**. If more than one survives and any live record has an
absent/null serialized order field, acquisition refuses after exact raw-file
retention. It does not trust a caller's version label or invent historical
sorting. A sole surviving record remains supported; superseded frames and
tombstones do not count. Saved template ordering is not treated as live state.
The explicit-order `d9e19b6` multi-record fixture remains supported.

## Later artwork, utilities and initial rules

`fa577ac/` extends coverage using exact source from repository commit `fa577ac`
(full hash in provenance), before ArtworkVariant artist, tracker actionOnly and
TokenRule count fields existed. All 26 model/adapter files, constants and the
historical lockfile are archived unmodified. The fixture exercises all type IDs
0–12, including nested utility templates, artwork options and rule trigger/outcome.
The source commit is not asserted to have shipped.

Reproduce with `python3 tool/generate_later_historical_hive_fixtures.py --dart
/path/to/flutter/bin/dart`, then run
`flutter test test/later_historical_hive_fixtures_test.dart`. The separate frozen
writer is `tool/historical_later_fixture_writer.dart.txt`; its digest is recorded
alongside verified Dart 3.11.0 and Hive 2.2.3 runtime provenance. No current adapter
writes these bytes. Remote artwork URLs are inert example.invalid metadata, not
network resources or evidence of local media recovery.

The current reader preserves exact raw files and historical artwork, utility
values/state, rule trigger/outcome and disabled state, with empty artist, false
actionOnly and count 1 defaults. The isolated coordinator preserves live values
and local-only rules across reopen/retry; loading the saved preset into another
seat uses tracker default 4 instead of live 17, inactive toggle instead of active,
and zero token quantity instead of live 11. The source directory stays unchanged.
Genuine native installation copies, other historical schema transitions, actual
local media and release/platform acceptance remain separate outstanding gates.
