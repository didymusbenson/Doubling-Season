# Next Release

This directory is the staging area for work implemented and proposed for the next
production release. Feature records move here after implementation, remain here
through acceptance testing, and move to `docs/releases/vX.Y/` when that release
ships.

## Release Log

### Rhys the Redeemed Utility

**Status:** Implemented in PR #33; pending acceptance testing
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

## Acceptance Testing Required

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

## Outstanding Review Item

- [ ] Decide whether deck JSON export should advance from schema v2 to v3 for
      `actionOnly`. The implementation preserves the field in current-version deck
      workflows, but an older schema-v2 app would accept the file and ignore it.
