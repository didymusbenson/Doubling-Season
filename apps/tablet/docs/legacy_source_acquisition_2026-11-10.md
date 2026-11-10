# Copied legacy source acquisition (2026-11-10)

This feature-branch checkpoint implements the next isolated M1 acquisition
foundation. It is **not an original-install migration, live capture, shipped
version compatibility certification, production startup hook or release**.
The existing original identities, Hive adapters and stores are unchanged.

## Implemented boundary

`LegacySourceReader.acquireCopiedDirectory` accepts a caller-owned, quiescent
native installation copy and explicit `LegacySourceLayout`. The layout requires
source/version/copy evidence, a stable capture instant, all seven collection
paths (or explicit historical absence), a preference file/format and exact old
artwork-reference-to-copied-file mappings. Nothing discovers a sandbox, follows
old artwork paths, opens original Hive boxes, calls `initHive`, restores a backup
or performs automatic source cleanup.

1. Read the complete copied directory twice. Require identical path/length/SHA-256
   inventories. Reject symlinks, unsupported paths, missing declared files and
   unknown top-level Hive stores. Backup and unreferenced files are retained too.
   POSIX backslash names cannot alias slash-separated paths. The additional
   `boardOrderOperations` sidecar is retained and decoded separately: an empty
   journal is accepted, while any pending/unknown recovery record blocks capture
   without replaying writes. Unresolved compaction files also block capture.
2. Bound reads to 4,096 files, 64 MiB per file and 256 MiB total. No unlimited
   growing-file read is used. These are conservative implementation limits, not
   proof of device memory feasibility for the largest accepted copy.
3. Retain every raw file as a content-addressed record in an isolated
   `LegacyMigrationStorage`, flush and read back, then retain a complete versioned
   inventory. Refuse conflicting source identity/layout. Serialize acquisitions
   sharing the same storage lock identity. Interrupted partial records are kept
   and identical retries complete them; no automatic deletion occurs.
4. Audit complete Hive frame logs with checksum/truncation checking and known
   field bounds, then decode using the actual unchanged root adapters, type IDs
   0–12. Private registries and bounded frame readers are used; no Hive box is
   opened for source decoding. Unknown/duplicate fields, unknown types, cross-box
   references, invalid scalar encodings, oversized/deep collections and trailing
   data are refused rather
   than silently ignored. Current Hive key ordering and integer/string key types
   remain intact; updates and tombstones are interpreted while raw history stays
   in the retained files.
5. Capture detached model values using `LegacySnapshotCapture`. The snapshot
   includes the full acquisition inventory/digest. `LegacyAcquiredSource.prepare`
   verifies retained originals again before calling the existing migration
   journal with copied local media. Journal mappings, blockers, media hashing,
   commit and reopen behavior remain authoritative and unchanged by this slice.

The raw recovery store must be outside the source copy and retained alongside
the isolated journal destination. Current code does not choose production
storage locations or automatically export/restore an archive. Original files
remain untouched even when decode or retention fails. Decode errors never fall
back to an empty source or to a backup. A missing declared box is not equivalent
to an explicitly absent historical box.

## Preferences

`decodeLegacyPreferences` reads Android XML and Apple XML/binary v00 plists
without invoking SharedPreferences, platform channels, Java deserialization or
external entities. It strips only a leading `flutter.` namespace and rejects
normalized key collisions. Unknown keys remain available.

Android handling includes scalar/Set values and the actual plugin's `!JSON`
string-list, restricted Java ArrayList/string, double and BigInteger prefixes.
Apple handling includes dictionaries, arrays, strings, booleans, finite reals
and representable signed 64-bit integers. Apple data/date/UID/null/set and other
unsupported types are explicitly refused, with original bytes still retained.
Malformed encodings, truncated input, duplicate keys, non-finite numbers,
unsupported XML constructs, reference cycles, excessive depth and excessive
expanded binary-plist data are refused.

The direct `xml` dependency uses the existing locked/cached 7.0.1 version. The
new Hive decoder's internal `HiveImpl` and `BinaryReaderImpl` use is intentionally
localized because Hive 2.2.3 has no public isolated read-only frame decoder.
Dependency upgrades must rerun these exact-format fixtures.

## Evidence and limits

Fixtures are generated with the real current root adapters, including all 13
nested adapter types, updates/deletions, integer/string keys, artwork metadata,
custom definitions, rules and saved templates. A historical short Item field
layout verifies current generated adapter defaults. Android Java bytes come
from OpenJDK `ObjectOutputStream`; binary Apple bytes come from Python
`plistlib`. These are reproducible format fixtures, **not backups from actual
shipped app versions**. Missing Item creation timestamps that would otherwise
be replaced with `DateTime.now` are refused pending explicit historical policy.

Tests cover source hashes unchanged, exact raw retention, real Hive archive and
journal close/reopen, complete acquisition interruption boundaries, lost writes,
flush failure, retained corruption, unknown fields/types/stores, truncation,
mutation during acquisition, path/link rejection, size refusal, source conflicts,
parallel retries and deterministic snapshot/journal identity. Parser tests cover
both plist encodings and actual Android legacy encodings including every
truncated prefix of representative binary fixtures.

Remaining gates:

- Caller evidence must establish an offline consistent copy. Two equal reads are
  change detection, not a transaction or proof that a live multi-store source was
  quiescent. Live capture, hostile concurrent filesystem mutation, same-inode
  changes that are reverted, cross-process/isolate locking and device backup
  procedure are not implemented or certified here.
- Actual shipped-version binary/adapter fixtures, absent-store/version mapping,
  native file access, durability under process/device termination and a genuine
  no-uninstall update remain open. The source version string is caller evidence,
  not an automatically verified build identity.
- Raw unsupported records are retained but blocked; this is not functional
  support for unknown schemas/rules/preferences. Media file bytes are copied and
  hashed, but image decoding, offline production media authority and missing-file
  fallback acceptance belong to the next integration gates.
- Production journal authority, later-play protection, recovery UI, restore and
  retention policy, native/store acceptance, cutover and release remain open.

## Validation commands

From `apps/tablet`, using Flutter 3.41.2 / Dart 3.11.0:

```sh
flutter analyze --no-pub
flutter test --no-pub test/legacy_source_reader_test.dart \
  test/legacy_preferences_decode_test.dart test/legacy_snapshot_capture_test.dart \
  test/legacy_migration_test.dart test/update_foundations_integration_test.dart
flutter test --no-pub --dart-define=TABLE_STORAGE_NAMESPACE=phone_preview_v1 \
  test/legacy_source_reader_test.dart test/legacy_preferences_decode_test.dart \
  test/legacy_snapshot_capture_test.dart test/legacy_migration_test.dart \
  test/update_foundations_integration_test.dart
```

Component validation: analyzer clean; **113 focused tests passed**; the same
**113 passed** under `TABLE_STORAGE_NAMESPACE=phone_preview_v1`. This includes
19 source-reader and 60 preference-decoder regressions. `git diff --check` is
clean. Independent review identified path aliasing, excessive binary-plist
expansion and permissive Hive scalar decoding; all were fixed with regressions.

Integration-wide full-suite/web/native evidence must remain separate from this
focused component validation. No full-suite run, platform build, device update,
real shipped-version fixture, store restoration, merge or deployment is claimed
by this component checkpoint.

The later [combined integration record](migration_integration_2026-11-10.md)
verifies this reader together with revision-2 mappings, save/support/catalog
safeguards and real-Hive end-to-end fixtures.
