# Generated tokens and Squirrel Girl — second field-feedback batch

## Canonical identity repair

Krenko and Hare Apparent previously synthesized `Creature Token — Goblin` and
`Creature Token — Rabbit`. The bundled catalog instead identifies these as
`Creature — Goblin` and `Creature — Rabbit`. The mismatch prevented exact
definition/artwork/preference lookup and clean-stack merging. Both Krenkos and
Hare now resolve the canonical definition **before** rule evaluation. A custom
rule targeting that canonical ID therefore applies correctly too.

Squirrel Girl uses the existing canonical Squirrel ID. The analogous Academy
Manufactor Food/Clue/Treasure, Brudiclad Myr and Chatterfang Squirrel paths already
use the correct IDs; regressions exercise these against the actual bundled
catalog. New tokens retain the complete available artwork variants and artist
credits. When an artwork preference selects a non-default printing, its set now
follows the actual selected URL rather than the first printing's set.

Exact merge compatibility is retained: identity, artwork and clean counters must
match. Existing tapped and sick subcounts remain recorded as subcounts when
fresh tokens join a compatible clean stack; generated tokens themselves enter
untapped and get the seat's normal sickness behavior. Modified-counter, other-art
and old artless/noncanonical saved stacks are not rewritten, erased or merged
by an automatic migration. The change fixes future creation; a person may keep
or manually consolidate old stacks as desired. Existing chronological undo
restores the action atomically.

## The Unbeatable Squirrel Girl

The tablet-only utility defaults its manual **nontoken Squirrels** count to one,
including Squirrel Girl herself. `Make Squirrels · 1GGG` reads that manual count
plus every owned token whose subtype includes Squirrel at resolution. It creates
that many fresh canonical green 1/1 Squirrel creature tokens, applying creation
rules once through the existing calculator. Counters, abilities or artwork on
the counted token stacks do not get copied into the new tokens. Other seats are
not counted. The supplied MSH193 Kim Dingwall scan is first; the credited MSH371
Swayart variant remains available, using canonical large URLs and existing
display-time crop behavior.

This is deliberately provisional design, as authorized by the user. Later review
should settle a dedicated shortcut for the separate **enters or attacks: create
one Squirrel** trigger and whether a richer non-token creature list is useful.
That trigger is not silently fired by adding the utility or activating 1GGG;
ordinary catalog creation can record it manually. Cost/payment, available mana,
tap eligibility and the presence of the physical Squirrel Girl card remain manual.
The utility does not create or track Squirrel Girl herself as a token.

## Evidence

`generated_token_canonical_regression_test.dart` loads the actual bundled catalog
and tests first creation, canonical metadata and credited art, non-default art
preferences, expected clean-stack merges, counter/art/legacy separation,
status-subcount preservation, owner scope, one-action undo, canonical-ID custom
rules, and Squirrel Girl plus doubler/Chatterfang arithmetic. The existing inline
utility interaction suite also exercises the added Squirrel action. Native and
visual acceptance belongs to the integrated batch validation record.
