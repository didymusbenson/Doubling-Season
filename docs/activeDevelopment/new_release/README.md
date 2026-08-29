# Next Release

This directory is the staging area for work implemented and proposed for the next
production release. Feature records move here after implementation, remain here
through acceptance testing, and move to `docs/releases/vX.Y/` when that release
ships.

## Release Log

### Rhys the Redeemed Utility

**Status:** Implemented on `codex/rhys-update-1-11`; pending acceptance testing
**Feature record:** [RhysUtility.md](RhysUtility.md)

Implemented an action-only Rhys utility whose **Copy Tokens** action:

- snapshots every positive, non-emblem token stack with power/toughness;
- evaluates each source independently through the rules engine;
- previews the exact primary, replacement, and companion tokens it will create;
- copies customized token identity and unchanged-source artwork;
- strips P/T from animated noncreature copies such as Clues;
- excludes all counters and existing tapped/summoning-sickness state;
- merges only into compatible counter-free stacks with matching artwork;
- applies summoning sickness only to newly created non-Haste creatures; and
- emits creature-ETB events for Cathar's Crusade and other listeners.

The release also introduces the reusable persisted `actionOnly` utility layout,
including Hive and deck-template support.

### Brudiclad, Telchor Engineer Utility

**Status:** Implemented on `codex/rhys-update-1-11`; pending acceptance testing

**Feature record:** [BrudicladUtility.md](BrudicladUtility.md)

Implemented an action-only Brudiclad utility whose **Resolve Trigger** action:

- evaluates the 2/1 blue Phyrexian Myr creation through the rules engine;
- previews replacement and companion results before changing the board;
- presents a full-width artwork definition picker with explicit selection and a
  separate **Resolve** button;
- transforms every positive non-emblem token stack using copiable base values;
- preserves counters, tapped counts, quantities, and board position;
- merges compatible clean stacks at the lowest existing clean-stack order;
- clears summoning sickness from resulting creature tokens because resolving
  the ability establishes that Brudiclad is present;
- fires ETB events for Step 1 creations only, never for transformed tokens; and
- offers an exact **Tokens Modified** completion dialog with **Undo / Accept**.

This work also introduces reusable token-copy semantics, rules-result artwork
resolution, clean-stack compatibility, artwork-backed definition cards, and a
typed unified-board snapshot/restore facility. The token-creation merge paths
now correctly fire creature-ETB events and reject countered or artwork-mismatched
merge targets.

## Acceptance Testing Required

### Rhys validation

- [ ] Add Rhys from Utilities and confirm the card shows no value or +/- controls.
- [ ] Confirm both supplied artwork choices load, crop, and persist correctly.
- [ ] Press Copy Tokens with no eligible tokens; preview shows none and confirm is a no-op.
- [ ] Copy a normal creature stack; verify quantity, identity, artwork, untapped state,
      and summoning sickness.
- [ ] Copy a stack with +1/+1, -1/-1, power-only, toughness-only, and custom
      counters; verify the created quantity has no counters.
- [ ] Give a noncreature token such as Clue P/T; verify it qualifies but the copied
      Clue has no P/T and does not trigger Cathar's Crusade.
- [ ] Copy matching clean stacks; verify they merge and preserve old tapped/sick
      counts while adding sickness only to the new quantity.
- [ ] Copy otherwise-identical stacks with different artwork; verify they remain
      separate.
- [ ] Exercise active doubler, replacement, and companion-token rules; verify the
      preview exactly matches creation and replaced identities use their own artwork.
- [ ] Verify every created creature quantity, including companions and merged
      quantities, increments Cathar's Crusade correctly.
- [ ] Activate Rhys twice and confirm the second activation includes prior copies.
- [ ] Place tracker/toggle utilities between token stacks and confirm new stacks are
      ordered beside their source without collisions.
- [ ] Save, load, duplicate, export, and import a deck containing Rhys; verify it
      remains action-only with its selected artwork.
- [ ] Upgrade from pre-Rhys Hive data and confirm existing utilities retain their
      normal value controls.
- [ ] Confirm quantity-cap messaging and behavior with large stacks and active rules.
- [ ] Smoke-test the complete flow on both iOS and Android.

### Brudiclad validation

Smoke pass completed 2026-08-27:

- [x] Several unmodified token definitions transformed successfully.
- [x] Skip committed Step 1 without transforming existing tokens.
- [x] Undo restored the smoke-test board.
- [x] Counter-bearing stacks stayed separate after transformation.
- [x] Otherwise-related tokens with different abilities remained distinct
      definition rows and produced separate countered piles.
- [x] Feedback polish landed: singular/plural grammar, compact-summary wording,
      and Undo/Accept action order.
- [x] Picker Cancel smoke test left the board unchanged.
- [x] An animated Clue copied the board into basic Clues with no copied P/T.
- [x] A companion-token rule produced the expected additional Squirrels.
- [x] Creature-token summoning sickness cleared after resolution.

Remaining validation:

- [ ] Add Brudiclad from Utilities; confirm its card has an intrinsic-width
      **Resolve Trigger** button and no value or +/- controls.
- [ ] Confirm the blue/red border and both Brudiclad artwork choices render,
      crop, select, and persist correctly.
- [ ] With no active rules, press Resolve Trigger; confirm the creation-preview
      dialog is skipped and the picker includes the newly evaluated 2/1 blue
      Phyrexian Myr with BRC token artwork.
- [ ] With Doubling Season, replacement, or companion rules active, confirm the
      creation preview, picker, and committed board show the exact same complete
      result set.
- [ ] Confirm the picker opens with no active selection and Resolve disabled;
      selecting a row highlights it, enables Resolve, and does not yet change
      the board.
- [ ] Confirm Cancel at the preview or picker leaves the complete board and all
      utilities unchanged.
- [ ] Confirm Skip creates only the evaluated Step 1 results, performs no copy
      transformation, clears sickness from creature-token stacks, and shows no
      Tokens Modified dialog.
- [ ] Choose the Myr; confirm every positive non-emblem token—including Food,
      Clue, and Treasure—becomes a 2/1 blue Phyrexian Myr.
- [ ] Choose a non-Myr definition; confirm the newly created Myr is transformed
      too, and trackers, toggles, emblems, and zero-amount stacks are untouched.
- [ ] Use a countered source whose displayed P/T differs from its base P/T;
      confirm the picker and copied definition use base P/T.
- [ ] Choose an animated noncreature such as a Clue with temporary P/T; confirm
      the copied definition has no P/T.
- [ ] Confirm transformed stacks preserve every built-in/custom counter and
      preserve tapped counts. Countered stacks must remain separate.
- [ ] Transform several clean stacks; confirm amounts and tapped counts sum into
      the lowest-order clean stack with no zero-amount ghost stacks.
- [ ] Confirm resulting creature-token stacks have zero summoning sickness;
      transformed noncreature stacks retain their previous sickness counts.
- [ ] Confirm Cathar's Crusade increments for created/merged Step 1 creatures
      only and never for Step 2 transformations.
- [ ] Confirm the completion dialog says exactly **Tokens Modified** and presents
      **Undo** on the left and primary **Accept** on the right, with no complete
      before/after board preview.
- [ ] Choose Undo; confirm exact restoration of identities, artwork, quantities,
      counters, tapped/sick counts, order, deleted stacks, Step 1 creations, and
      Cathar's Crusade values. Confirm the restore itself fires no game events.
- [ ] Choose Accept; confirm the transformed state remains persisted.
- [ ] Resolve twice in succession; confirm the second activation sees the first
      activation's transformed state.
- [ ] Save, load, duplicate, export, and import a deck containing Brudiclad;
      confirm it remains action-only with selected artwork.

### Shared regression validation

- [ ] Re-run Rhys with normal, countered, custom-artwork, animated-noncreature,
      replacement, and companion sources; confirm shared copy/artwork extraction
      did not change its preview or creation behavior.
- [ ] Create a companion creature that merges into an existing clean stack;
      confirm Cathar's Crusade now increments by the merged quantity.
- [ ] Repeat with a countered or different-artwork destination; confirm creation
      makes a separate stack rather than merging.
- [ ] Open deck details containing tokens, trackers, and toggles; confirm the
      extracted definition preview card preserves existing artwork, crop, text,
      P/T, icons, selection controls, and swipe/reorder behavior.
- [ ] Smoke-test Brudiclad and the shared merge changes on both iOS and Android.

Deck JSON export advances to schema v3 for `actionOnly`. The importer remains
backward-compatible with schema v1/v2, where the field safely defaults to false.
