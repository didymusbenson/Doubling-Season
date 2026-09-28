# 1.11 release fixes

Status: implementation approved by the user on 2026-09-26. All three fixes are
implemented; September 26–27 targeted simulator validation and delivery results are recorded in
`../new_release/README.md`. The plan below preserves the approved scope; its
validation list is a target, not a claim that every check has passed.

## 1. Restore published artist metadata

Port the existing artist-preserving generator changes and the corresponding
custom_tokens.json credits from the development branch into a focused checkout
of current main. These custom-source changes contain only artist metadata
(26 artwork variants across 24 definitions). Do not merge unrelated app work.

Generate a candidate database, then compare all composite identities, artwork
URLs, counts and creator links with v8. With unchanged upstream input, only
artist metadata should differ; review any new upstream changes separately.
Validate uniqueness, JSON, manifest size/hash, and authoritative artist coverage.
Unknown upstream credits remain explicitly unknown, never guessed.

Choose a manifest version higher than both the live version and every known
shipped/release-candidate bundled version (currently v9). Keep the existing
minimum supported app version. Publish database+manifest together after checks;
verify the exact app URL after cache propagation. Repeat the in-app download and
10E Zombie credit check. Update the regeneration workflow to verify metadata
schema/coverage and version uniqueness before publishing future updates.

## 2. Stop destructive ordering rewrites

Refinement to the initial investigation: a blanket startup renumbering is not
needed to fix this defect and introduces unnecessary writes to valid boards.

- Remove all three per-type order==0 startup migration heuristics.
- Treat zero, negative and fractional finite positions as valid. Distinguish
  unspecified insertion placement explicitly at the API boundary, rather than
  inferring it from the numeric value; audit existing callers before changing
  their creation/event behavior.
- Use one deterministic unified ordering policy for tokens, trackers and toggles.
  Equal/legacy positions require a documented stable type/key fallback; do not
  claim to reconstruct ordering already overwritten by the old app.
- Route reorder/normalization through the existing BoardOrderService. Calculate
  from the intended post-move sequence: ContentScreen currently passes immutable
  pre-move _BoardItem.order snapshots to compaction.
- Normalize only when needed for collisions/exhausted gaps or invalid values,
  preserving the selected unified sequence. Persist with awaited writes. For
  multi-item normalization, retain a small durable order-only plan and resume it
  idempotently before showing the board after interrupted writes. Do not rebuild
  models or fire game events just to repair positions.
- Preserve existing Hive boxes/type IDs/model fields. No new persisted board
  hierarchy or unrelated backup-system overhaul.

Likely touchpoints: the three providers, BoardOrderService, ContentScreen,
startup pending-plan recovery, and callers that currently use zero as an
unspecified position. Deck clear-load currently legitimately starts at zero;
its saved sequence must survive restart.

## 3. Preserve artwork on renamed/customized board items

Start with saved artwork variants unconditionally. An unmatched definition must
never make an existing picker empty or replace known credits with unknown.
Share metadata enrichment across token/tracker/toggle cards using existing
ArtworkMetadataEnricher rather than duplicating the repair.

Widget model widgetId is an instance UUID, not WidgetDefinition.id; do not use it
as a definition key or add a Hive field just for this repair. For enrichment use
existing artwork URLs and, when unambiguous, a special utility's actionType.
Use exact name/identity only as a legacy fallback, not a prerequisite. If a
utility cannot be identified uniquely, retain its saved choices and enrich
matching individual images without guessing a full alternate-artwork list.

Build metadata lookup from authoritative token/utility variants. Exact URL first;
if needed, canonicalize only known Scryfall image identities (including face) for
lookup to tolerate cache-busting query strings. Do not change stored URLs or
image-cache keys. Preserve custom file:// art and existing nonempty credits.
A renamed token's existing images should receive missing credits by URL even
when name/PT/type/abilities no longer match a database definition. Metadata-only
repair must not download images. Unknown images keep an honest unknown credit.

## Validation and delivery

Use manual simulator flows or temporary Maestro flows only; no permanent test
suite. Read-only copies of Hive state provide objective before/after evidence.

Ordering: reorder each board type to top/middle/bottom; restart twice; exercise
zero/negative/fractional positions, tied legacy fixtures, dense-gap normalization,
deck clear/add/load, copy/split, Rhys/Brudiclad and Undo. Interrupt normalization
and inject a failed write; verify deterministic recovery and unchanged non-order
fields.

Artwork: renamed Brudiclad retains 2XM/C18 and Daarken; renamed Monarch retains
its saved choices/credits; renamed token with missing credits is enriched after
remote update. Check custom uploads, no-definition fallback, offline cached art,
selection persistence, deck round trip and restart. Verify no metadata-only
image downloads.

Run analysis and iOS simulator build, then repeat a targeted Android smoke pass
because these fixes are shared-platform. Record results in new_release/README.md
and the bug records. Prepare separate focused changes for publishing metadata,
ordering, and artwork lookup so each is reviewable. iOS signed archive/TestFlight
upgrade remains a subsequent release gate, not satisfied by simulator checks.

## Delivery checkpoint — 2026-09-27

- `ae90c64`: credited database v9 and publication safeguards in this branch.
- `7501faf`: recoverable unified board ordering.
- `656599d`: renamed/customized artwork lookup.
- `ec02318`: Brudiclad noncreature and Skip sickness correction.

Targeted acceptance and remaining release gates are reconciled in the release
README. This checkpoint does not approve a production app upload or claim the
full acceptance matrix is complete. The pre-existing Android billing/SDK/CI
changes remain separate from these fixes.
