# Tablet domain implementation inventory

Implementation checkpoint: 2026-10-21 (America/Phoenix). This inventory records
source review and static analysis, not completed runtime acceptance testing.
The first tablet implementation lives independently in `apps/tablet`; no phone
Hive box, phone provider instance, global event bus, or artwork preference is
used by its game mutations.

## Boundaries and reuse

- `BoardService` captures game ID/generation and player ID/generation. Every
  mutation runs on the session writer's detached draft and publishes after the
  aggregate save succeeds. Definition/catalog reads remain shared and immutable.
- Root `TokenDefinition`, `ArtworkVariant`, utility definitions, composite IDs,
  `DecklistParser`, `RuleTrigger`, `RuleOutcome`, `TokenCreationResult`, constants,
  bundled token assets and update URLs are reused through the path dependency.
- `ScopedRulesCalculator` extracts the deterministic methods from the root rules
  provider, retaining its phases, per-event companion continuation, custom source
  suppression, Manufactor `max(preset, forced)` rule, and counter applicability.
  It substitutes stable modifier-source IDs for Hive keys. The repository's
  proprietary copyright/license also applies to this adapted code.
- Primal Vigor is a seat-owned global source. Other preset defaults are local;
  custom sources declare applicability. Each applicable source appears once.
  Foreign-source views are read-only. Changes affect future operations only.
- Each creation's journaled token mutation includes source identities,
  configurations, counts and revisions. Derived Cathars counts are committed in
  the same operation, without a global asynchronous event listener.
- Catalog updates use the phone's feed, required minimum shared-format version,
  SHA256, size and structural validation. One independent Hive catalog record
  stores the verified generation. Game saves, undo, archives and setup loads do
  not copy or rewrite the downloaded catalog. Invalid/unavailable cache falls
  back to bundled definitions; network failure preserves the current catalog.

## Token behavior

| Operation | Implemented semantics |
|---|---|
| Search/custom creation | Shared All/Recent/Favorites/Custom library, category filters; target seat captured; full calculator outputs; untapped/tapped creation, configured sickness; append distinct results; compatible merges stay in place |
| Increment | Applies current effective rules, increments an unchanged source including its existing counters; replacement/companion outputs remain local; causal creature entries accumulate locally |
| Decrement/delete | Separate removal command/history direction; amounts never negative; tapped/sick bounds follow the remaining amount; no inferred death trigger |
| Ordinary Copy | Audited phone behavior: **one** fresh untapped token, no copied counters or token multipliers, appropriate sickness, adjacent to source, exact selected art including an explicit absence |
| Split | Redistributes count/status into an adjacent deep copy, retains counters and artwork; offers tapped-first or untapped-first allocation (default untapped-first), clears sickness on both stacks per the explicit phone flow; emits no entry event |
| Merge | Same player, identity and artwork, with no effective counters; combines amount/tapped/sick and preserves one stack; never merges across seats |
| Counters | +1/+1 and -1/-1 cancel; arbitrary named counters; +1/+0 and +0/+1 are represented by those counter-map keys; positive additions use applicable counter rules; decrements are corrections |
| Artwork | Seat/game preference plus explicit instance choice; uploaded media is immutable `tablet-art:<sha256>`; download/render failure does not clear the choice; custom artist metadata retained |
| Bulk | Untap, clear sickness, +1/+1 and -1/-1 all, creature-token wipe and all-token wipe scoped to the chosen seat; wipes do not reset life, modifiers, player counters or shared statuses |
| Reorder | Independent lanes; visible utility reordering validates identities and preserves hidden utility positions |

Search creation, increments and utility outputs saturate each evaluated output
at the shared 999,999 creation limit. A merge that would exceed the supported
stack quantity rejects the entire command without partial writes. Saturating
arithmetic prevents native/web overflow. A custom-rule expansion beyond 10,000
separate creation events is rejected before commit with an actionable message.
These are safety limits, not a claim to implement every Magic replacement rule.

## Utility behavior

| Family | Implementation |
|---|---|
| Trackers/toggles | Named/description/step/configurable reusable utility kinds, reversible value/state updates, confirmed hide/restore retaining values; queued relative adjustments read authoritative draft values |
| Life/player counters/city's blessing | Projections of the authoritative seat values; no independent copy; imported monarch/day-night toggles project shared state |
| Storm/mana | Default utility identities are `storm_count` / `mana_pool`; no duplicate competing instances; mana controller owns manual six-color values, locks, Empty and conversion |
| Krenko, Mob Boss | Counts this seat's Goblin token quantities plus manually tracked nontoken Goblins, then evaluates rules |
| Krenko, Tin Street | Creates Goblins from manually tracked power, then evaluates rules; no inferred attack or counter event |
| Hare Apparent | `max(0, tracked count - 1)` Rabbits, then rules |
| Academy Manufactor | Food intent with forced utility copy count; uses the maximum of utility/preset count, preserving three peer outputs and companion events |
| Cathars' Crusade | Accumulates this seat's actual creature creations; Resolve applies modified pending counters to its creatures and clears pending; Quick adds modified one without clearing pending |
| Rhys | Snapshots each eligible positive creature-token stack separately; copies current identity using the audited Creature-type P/T heuristic; fresh copies omit counters, enter untapped, preserve source artwork if not replaced, and create companions locally |
| Brudiclad | Rules-evaluated Myr creation first; choice may be an existing local token or a virtual new result; transform preserves counters/status, merges clean stacks, clears all local sickness; Skip creates results and clears sickness without transformation; transformation emits no ETB |

The curated add menu excludes Initiative and commander-tax utilities because
those were not blanket-approved tablet features. Compatible phone presets can
retain generic tracker/toggle configuration; their presence does not add an
automatic game rule, tax calculation, phase engine or mana payment engine.

## Presets and interchange

- Save snapshots only one seat's ordered token templates and utility preferences,
  deduplicating matching token identity+art. It excludes live quantities,
  counters, mana, damage, commander selection, rules and game timeline.
- Replace/Append load new runtime IDs and zero-state token entries. They preserve
  life, player counters, damage, sources and history. Replace advances only that
  player's generation; Append keeps existing instances/art/values and does not
  merge templates. Singleton bound utility projections cannot duplicate values.
- Optional setup image applies the target permanent seat's life artwork in the
  same journaled operation; latest-action undo includes that image mutation.
- Phone schema 1–3 imports are adapted by stable partition into token and utility
  lanes. Decklist import uses the existing parser and reverse-related card index.
- Tablet schema 4 exports portable uploaded media with a SHA256-keyed manifest;
  import verifies all references and checks total 64 MB/import and per-image store
  limits before adding the setup. Native `file://` references cannot transfer;
  imports retain an explicit warning. Phone v3 subset export reports omitted
  tablet mana/visibility/cover/custom-media capabilities rather than inventing
  incompatible phone fields. Saving/exporting setups does not save a live game.

## Review findings addressed

Source review caught and corrected inherited-generation rollback on undo,
incidental Recent writes interrupting creation history groups, custom-rule copy
counts being lost on reset, absolute quick utility updates losing queued taps,
Rhys animated-source artwork changing, and ordinary Copy selecting fallback art
when the source explicitly had none. Session-engine fixes are documented by
that component; these observations do not replace runtime checks.

## Remaining validation and boundaries

Manual acceptance still needs the spec's two-identical-seat cases, source-owned
local/global combinations and ordering, capped/multi-companion plans, all utility
actions and retries, grouped latest-action undo after restart, v3 fixtures,
portable artwork round trips, updater hash/version/offline failures, and failed
writes. Static analysis alone cannot establish these behaviors on a device.

Uploaded media is deliberately retained without
reclamation so another seat, archive or setup cannot lose artwork. This first
pass does not implement token-control transfers, a general card rules engine,
cloud synchronization, restricted-mana buckets or automatic phase/payment rules.
