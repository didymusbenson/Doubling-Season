# Rhys the Redeemed Utility

**Status:** Implemented on `codex/rhys-utility`; pending acceptance testing

## Card Reference

**Rhys the Redeemed** — {G/W} Legendary Creature — Elf Warrior (1/1)

- {2}{G/W}, {T}: Create a 1/1 green and white Elf Warrior creature token.
- {4}{G/W}{G/W}, {T}: For each creature token you control, create a token that's a copy of that creature.

The utility implements the second ability as an action-only **Copy Tokens** card.
The first ability remains available through normal Elf Warrior token creation.

## Utility Definition

- ID/action type: `rhys_the_redeemed`
- Description: `Copy each creature token you control`
- Color identity: `GW`
- No value or +/- controls (`TrackerWidget.actionOnly`)
- Artwork:
  - TLE: `https://cards.scryfall.io/large/front/e/b/ebcf9ad6-5c1c-4b12-9778-2b9338bf49aa.jpg?1783904844`
  - 2XM: `https://cards.scryfall.io/large/front/b/9/b91dadcb-31e9-43b0-b425-c9311af3e9d7.jpg?1783930128`

`actionOnly` is Hive-backed with `defaultValue: false` and is preserved through
`TrackerWidgetTemplate` and deck JSON export/import.

## Eligibility and Copy Identity

- Snapshot every non-emblem `Item` with nonempty P/T when the action begins.
- P/T is the app-level signal that the token is currently a creature.
- Copy stored name, colors, type, abilities, and artwork exactly. Customized token
  characteristics are authoritative; Rhys does not look up a presumed base token.
- If the stored type line contains `Creature` (case-insensitive), preserve P/T.
- If it does not contain `Creature`, strip P/T from the copy. This allows an
  animated Clue to qualify while producing a normal noncreature Clue copy.
- Do not copy tapped state, summoning-sickness state, +1/+1, -1/-1, power-only,
  toughness-only, or custom counters.
- Later activations include copies created by earlier activations.

Known approximation: a Vehicle stored with printed P/T is treated as currently
animated and eligible. The copy has P/T stripped because its type line does not
contain `Creature`.

## Rules Evaluation and Preview

Each eligible source stack is independently passed to
`RulesProvider.evaluateRules()` with its full amount. The removed legacy global
multiplier is not used. Active doublers, triplers, replacement rules, and companion
effects therefore apply to each copied identity correctly.

The handler retains a source-to-results group for each stack. The exact evaluated
groups shown in the confirmation dialog are reused for execution; rules are not
recalculated after confirmation. The preview aggregates identical display results,
includes companions, and reports quantity caps.

The action is never disabled. With no eligible tokens, the dialog previews no
tokens and confirmation performs a successful no-op.

## Artwork Rules

- An unchanged primary copy preserves the source's exact artwork URL, set, and
  artwork options.
- If a replacement rule changes the token identity, discard the source artwork and
  resolve normal artwork for the resulting token (preference, then database/default).
- Companion tokens resolve artwork from their own identity.
- A result may merge only when `artworkUrl` matches exactly, including both null.
  This prevents selected or customized artwork from being silently lost.

Example: Food replaced by Treasure creates a normal Treasure with Treasure artwork,
never a Treasure displaying the copied Food artwork.

## Stack Merging, State, and Ordering

- Merge into an existing stack only when name, P/T, colors, type, abilities, and
  artwork URL match and the destination has no counters of any kind.
- A source with counters can therefore copy into a separate compatible clean stack,
  but never into the modified source.
- Preserve all preexisting tapped and summoning-sickness counts on a merged stack.
- Newly created creatures enter untapped and add only their new quantity to the
  summoning-sickness count when the setting is enabled and they do not have haste.
- When no compatible stack exists, insert the result fractionally beside its source.

## Trigger Integration

Every actually created result with P/T emits the existing creature-ETB event using
the post-rules quantity, whether it was merged or inserted as a new stack. This
includes creature companion tokens and ensures Cathar's Crusade receives the full
trigger count. Results whose P/T was stripped (such as a normal copied Clue) do not
emit creature ETB events.

## Rules Basis

Verified against French Vanilla's Comprehensive Rules corpus:

- CR 111.3: token-defined characteristics establish copiable values.
- CR 613.1 and 613.2a-c: copy effects/copiable values are layer 1; later type,
  ability, and P/T effects are not normally copied.
- CR 707.2 and 707.9: copy effects exclude status, counters, and ordinary later
  continuous effects, while copy-effect modifications can be copiable.

Rhys has no separate official card-specific ruling for this interaction.

## Acceptance Checklist

- [ ] Card renders name, description, artwork, and Copy Tokens without value controls.
- [ ] Action-only state survives save/load, export/import, and an upgrade from old data.
- [ ] Empty board previews no tokens and confirming is a no-op.
- [ ] Multiple source identities are evaluated independently and preview matches output.
- [ ] Animated noncreature token qualifies but its copy has P/T stripped.
- [ ] Counters and tapped state never copy.
- [ ] Matching clean stacks merge only when artwork also matches.
- [ ] New merged quantities receive sickness without changing old quantities.
- [ ] Replacement and companion identities receive their own normal artwork.
- [ ] New and merged creatures increment Cathar's Crusade by final created quantity.
- [ ] Repeated activation includes copies from the previous activation.
