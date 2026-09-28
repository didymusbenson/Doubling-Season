# Brudiclad Leaves Summoning Sickness on Noncreature Results

**Reported:** 2026-09-05  
**Status:** Fix implemented; static analysis and targeted iOS simulator validation passed

## Symptom

When Brudiclad transforms every token into a noncreature definition such as a
Treasure, the merged result can retain summoning-sickness counts inherited from
the creature stacks that were folded into it.

Summoning sickness is not applicable to the resulting noncreature token. The
resolution also establishes that Brudiclad is present, so no token stack should
retain a stored sickness count after the trigger finishes resolving.

The same invariant applies when the user chooses **Skip**: Step 1 still resolves
with Brudiclad present, and every token stack should finish with
`summoningSick == 0`.

## Root Cause

Both Brudiclad completion paths gated their final sickness clear on
`Item.hasPowerToughness`. A stack transformed into Treasure therefore skipped
the clear after its pre-transform sickness count had been preserved or summed
during merging.

## Fix

- Clear stored summoning sickness from every token stack after a successful
  Brudiclad transformation, regardless of the resulting identity.
- Route the Skip path through the same all-token invariant.
- Keep preservation and summing during the intermediate copy/merge work so
  rollback and Undo can still restore the exact pre-trigger state.
- Batch the shared global clear through `Item.clearSummoningSicknessBatched()`
  to avoid redundant autosave plus explicit-save writes.

## Validation

- [x] `flutter analyze`
- [ ] Transform sick creature stacks into Treasure; the surviving merged stack
      has `summoningSick == 0`.
- [ ] Transform a mixture of sick/ready creatures and noncreatures into a
      noncreature; every resulting stack has `summoningSick == 0`.
- [ ] Choose **Skip**; Step 1 commits and every token stack has
      `summoningSick == 0`.
- [ ] Choose **Undo** after a transformation; all original sickness counts are
      restored exactly.

## iOS simulator results — 2026-09-25

Current 1.11.0+19 working tree on iPhone 17 Pro Max / iOS 26.2:
3 sick Zombies + 2 tapped Treasures resolved to 6 Treasures, 2 tapped,
0 sick, verified from persisted Hive. Undo restored the original Zombie sickness
and tapped Treasures. Skip subsequently created only one Myr and left every
stack with sickness 0, preserving an existing +1/+1 counter and tapped counts.
Broader rule/counter combinations and physical-device review remain open.
