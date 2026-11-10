# Dormant startup routing foundation

Branch: `feat/migration-startup-gate-20261110`, based on `633cb92`.
Release remains held. Neither application entrypoint is changed.

## Why the boundary is read-only

`TableController.initialize()` currently calls `TableRepository.open()`. That
repository may initialize empty storage, retain damaged generations, recover a
previous generation, or promote an older format. The original app's bootstrap
has its own recovery behavior. Neither is an inspection API. Calling either
before deciding how to handle original data could destroy the evidence needed
to make that decision. This slice calls neither and does not alter them.

`lib/startup/table_startup_gate.dart` introduces a dormant inventory policy and
notification controller. It accepts only read interfaces, with no initializer,
writer, migration retry, legacy bootstrap, fallback, reset or force callback.
No `TabletState` or authorization token escapes inspection. All reports have
`canActivate == false`, including successful candidates. Do not connect a
candidate to `TableController.initialize()` or `TableRepository.open()`.

## Inventory contract and routes

Every adapter set must cover seven separate named domains: original app data
(including preferences, boxes, backups and source media), migration retention,
current Table aggregate, previous generations, recovery records, Table media,
and all other/unknown destination records. Missing or aliased adapters, duplicate
names/keys, unavailable values and read exceptions fail closed. Adapters must
not discover emptiness by opening Hive containers, initializing preferences,
repairing storage, invoking original startup or omitting unfamiliar files.
There is **no production platform adapter in this slice**: completeness depends
on the supplied adapter contract and is not proven for a live installation.

The full inventory is read twice. Observed changes fail closed, including an
earlier domain changing while a later domain is read. Double reads do not
exclude ABA changes, cached reads, concurrent writers or changes after return.
They are not a live snapshot, lease or permission for a later write.

- Original or migration evidence always routes to recovery, even alongside a
  valid later Table save. A completed promotion receipt also routes to recovery.
- Previous/recovery/media records conservatively route to recovery. This slice
  does not select between authorities, validate media, or silently repair them.
- Unknown keys and corrupt, unsupported or incomplete aggregate envelopes route
  to recovery. Format upgrades, invalid sequences and local references (also in
  extension metadata) require review.
- Only a completely empty declared inventory is a `freshCandidate`.
- Only a single strictly decoded current-format generation with no conflicting
  evidence, receipt or unresolved local reference is an `existingCandidate`.
  Existing gameplay revision is not reset or required to equal the initial one.
- Candidates describe diagnostic routing only. No route activates gameplay.
  Error categories contain no raw exception, private path or saved content.

The controller coalesces overlapping and listener-reentrant checks. Starting a
new check clears the old report; retry always inventories again after an
ambiguous error. Disposal suppresses late publication and further checks.
In-flight read-only inspection may finish after disposal; it has no write or
activation capability. This is not cancellation of an operating-system read.

## Validation and limits

Focused tests cover empty and valid-existing candidates, every missing/evidence/
failed domain, progressed destination preservation, promotion receipt, missing
local media references, malformed envelopes, duplicate and changing inventories,
whole-inventory rechecks, overlapping/reentrant calls, ambiguous error retry,
and disposal/stale completion. Read adapters are deterministic test doubles;
real `TableRepository` envelope decoding is exercised. No mock result is proof
of a native production snapshot, crash durability, filesystem permissions,
physical upgrade, or user acceptance.

Validation with Flutter 3.41.2 / Dart 3.11.0:

- `flutter test --no-pub test/table_startup_gate_test.dart`: **35 passed**.
- Full suite and native/device checks are not part of this component checkpoint;
  combined-branch validation is owned by the integration task.
- Formatting and `git diff --check` passed; dependency lockfiles unchanged.
- `flutter analyze --no-pub`: **no issues found** (24.8s).

Tooling uses `CI=true BOT=true` to avoid Flutter's optional cloud metadata bot
probe, and writable temporary HOME/XDG directories for analysis/config caches.
An initial analyzer invocation could not create its default cache; it is not
counted as a successful analysis.

## Still required before production cutover

- A production non-destructive inventory adapter covering original and Table
  directories, SharedPreferences, all retained generations and local media.
- All-writer quiescence and a production-safe leased snapshot/activation boundary
  spanning inspection, any migration, destination validation and gameplay writer
  handoff. Check again under that lease rather than trusting these reports.
- Validated original-source discovery and shipped-version coverage, durable
  archive/export location and retention policies, full-disk/interruption handling,
  and a real recovery route/save destination. Existing rehearsal recovery is not
  automatically invoked or represented as production recovery.
- Atomic activation of an existing valid authority without repository fallback
  or accidental fresh initialization, with disposal/overlap behavior verified at
  that actual write boundary.
- Native no-uninstall upgrades, process-kill/power-loss tests, purchase restore,
  and phone/tablet hands-on acceptance.

No original adapters, app identities, store/signing/version configuration,
production startup, default branch, PR or deployment is changed here.
