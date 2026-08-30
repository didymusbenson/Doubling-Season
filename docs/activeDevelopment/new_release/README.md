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

### Token-Creation Pipeline Consolidation

**Status:** Implemented for 1.11; pending user acceptance testing

**Feature record:** [TokenProviderImprovement.md](TokenProviderImprovement.md)

Implemented a typed shared commit executor with explicit merge and creature-ETB
policies, awaited persistence, identity-safe artwork completion, typed partial-
success reporting, and one shared path for primary and additional rules results.
Token search, custom-token creation, and token-card rule additions now use the
shared boundary while specialized copy, restore, Scute, Krenko, Rhys, and
Brudiclad orchestration retains its intentional semantics.

Optional performance and architecture follow-ups are tracked separately in
`../todo_features/Optimizations.md` and are not part of 1.11 acceptance.

### Artist Credit

**Status:** Implemented for 1.11; pending user acceptance testing

**Feature record:** [ArtistCredit.md](ArtistCredit.md)

Artwork variants now retain their MTGJSON artist credit through the bundled
database, Hive, and JSON serialization. The shared artwork-selection sheet
shows the credit beneath the set code in **Currently Selected** and beneath the
image but above the set code in the confirmation preview. User uploads resolve
to `user uploaded`; unresolved legacy and uncredited images resolve visibly to
`Artist unknown`. Artwork grid tiles and all board-card surfaces remain
unchanged.

Legacy board items are enriched by artwork URL from the current token or
utility definitions before the sheet opens. The upgrade persists metadata only;
it does not redownload cached art or change the selected image.

### Undoable Board Wipes

**Status:** Implemented; pending user acceptance testing

**Feature record:**
[`UndoableBoardWipes.md`](../in_progress_features/UndoableBoardWipes.md)

All three board-wipe choices now capture the exact unified board and present a
non-dismissible **Board Wiped** completion dialog with **Undo / Accept**.
Delete/reset additionally restores every preset count and custom-rule enabled
state. Failed operations automatically attempt rollback, and restoration emits
no game events.

## Acceptance Testing Required

### Validation ownership

The objective acceptance backlog is Codex-owned unless a checklist item is
explicitly listed below as requiring the user. Codex may drive deterministic UI
flows with temporary Maestro scripts, inspect persisted simulator state, seed
upgrade fixtures, build supported targets, and perform fault-injection work.
Temporary Maestro flows remain outside the repository; this project does not
adopt a permanent automated-test suite.

User-required validation is limited to:

- final animation, layout, cropping, readability, and interaction-feel review;
- listening to VoiceOver/TalkBack output and judging practical accessibility;
- physical Android hardware coverage and Windows coverage unavailable in the
  current development environment;
- real-device custom-art heat, slowdown, memory-warning, and process-termination
  judgment; and
- supplying representative legacy/full-resolution custom images if they cannot
  be reconstructed from available simulator fixtures.

Physical iPhone checks can be driven by Codex when explicitly included in a
test pass. Everything else below should be completed by Codex before requesting
feature acceptance.

### Inline Token Details validation

Maestro smoke pass completed 2026-08-29 on iPhone 17 Pro Simulator, iOS 26.2:

- [x] Opened the existing Zombie board card through its accessibility label.
- [x] Confirmed the expanded card exposes the token name, base P/T, type, empty
      abilities state, artwork control, and counter control.
- [ ] Maestro reported its iOS Back command completed, but the card remained
      expanded. Retest through a direct simulator/system navigation path to
      distinguish an iOS Maestro limitation from an app regression.

Remaining deterministic inline workflows are Codex-owned. Final animation,
artwork-crop, dense-board spacing, keyboard feel, and overall discoverability
remain part of the user's feature review.

### Mana symbol validation

Maestro smoke pass completed 2026-08-29 on an Android 15 emulator:

- [x] Built and installed the current debug APK and launched from cleared app
      state with the bundled font available offline.
- [x] Confirmed token-search results render the tap glyph and generic `{2}` pip
      on Treasure, Clue, and Food definitions.
- [x] Confirmed accessibility semantics announce **tap** and **two generic mana**
      in complete token descriptions rather than reading raw braces or
      announcing the visual glyph twice.
- [x] Created a database Zombie through token search and confirmed the compact
      board card exposes the expected identity, quantity, ready/tapped status,
      type, and P/T semantics on Android.
- [x] Expanded that card with direct Android input and confirmed its editable
      name, P/T, type, abilities, color identity, artwork, and counter controls
      are present in the accessibility tree.
- [x] Recomputed the bundled Mana 1.18 font SHA-256 and matched the recorded
      `a23809f7c0af7f9866734216bdd73bce2cfedd67333f5cde86a9ee066fa69819`.
- [x] Confirmed `pubspec.yaml` bundles both the font and complete OFL text and
      the app registers that text through `LicenseRegistry`.
- [x] Completed the current web debug build; Flutter's WebAssembly dry run also
      succeeded.
- macOS runtime/font validation is intentionally out of scope because Tripling
  Season has no macOS version.

Remaining deterministic symbol mappings, fallback parsing, surfaces, license
registration, and platform builds are Codex-owned. Practical glyph appearance,
contrast, text scaling, and spoken screen-reader judgment remain part of the
user's feature review.

### Undoable board-wipe validation

Objective iPhone 17 Pro Simulator smoke pass completed 2026-08-30:

- [x] **Set to 0 → Undo** restored Zombie and Squirrel quantities.
- [x] **Delete All → Undo** restored both deleted stacks and quantities.
- [x] **Delete All & Reset Rules → Undo** restored the board and active
      Chatterfang preset, verified through the `1 Zombie + 1 Squirrel` preview.
- [x] **Delete All & Reset Rules → Accept** persisted both the empty board and
      disabled Chatterfang state through process termination and relaunch.
- [x] All three actions showed **Board Wiped** with Undo left and primary Accept
      right.
- [x] System Back could not dismiss the completion dialog; scrim dismissal is
      disabled.
- [x] Analyzer and iOS Simulator debug build completed successfully.
- [x] On Android 15, **Delete All** showed the non-dismissible completion
      actions, Undo restored the Zombie stack and quantity, and the restored
      state remained present after full process restart.

Remaining objective validation:

- [ ] Exercise Set to 0 with tapped/sick quantities and every counter type.
- [ ] Exercise Delete All with interleaved tracker/toggle utilities and a
      nonzero Cathar's Crusade value.
- [ ] Restore all nine preset counts and mixed enabled/disabled custom rules.
- [ ] Fault-inject wipe and restoration persistence failures.
- [ ] Confirm deck clear-and-load remains unchanged.
- [ ] Smoke-test physical Android hardware.

### Artist Credit validation

Purpose: confirm artist metadata survives selection and persistence while the
two locked credit placements remain readable and existing artwork surfaces do
not change.

Objective validation completed 2026-08-30 on iPhone 17 Pro Simulator, iOS 26.2:

- [x] Regenerated all 948 token definitions and 3,028 artwork variants; every
      variant has a nonempty artist value and all 2,992 distinct Scryfall URLs
      remain represented.
- [x] Confirmed the 10E Zombie renders **Carl Critchlow** beneath **10E** in
      **Currently Selected**.
- [x] Confirmed confirmation-preview semantics order artist credit before set
      code.
- [x] Maestro selected the alternate 2X2 Zombie printing, confirmed preview
      semantics exposed **Anna Steinbauer** before **2X2**, and verified the
      current-selection credit persisted after full process termination and
      relaunch.
- [x] Copied the selected Zombie into a distinct stack and confirmed the copied
      stack retained **2X2** and **Anna Steinbauer** in its artwork sheet.
- [x] On an Android 15 emulator, expanded a freshly created database Zombie,
      opened its artwork sheet, and confirmed **Carl Critchlow** appears beneath
      the selected **10E** printing.
- [x] Increased that stack to two, split it into two independent stacks, and
      confirmed the newly split stack retained **10E** and **Carl Critchlow**.
- [x] Booted existing Hive data created before the artist field without data
      loss; genuinely unmatched legacy art retains the safe fallback.
- [x] Confirmed the two source images without printed/source credit use
      **Artist unknown**, with no guessed attribution.
- [x] `flutter analyze` completed with no issues.
- [x] iOS Simulator debug build completed and installed successfully.
- [x] Android debug APK build completed successfully.

Remaining objective validation:

- [ ] Confirm changing and removing artwork immediately updates/removes the
      selected-summary credit.
- [ ] Confirm a user-uploaded image displays exactly `user uploaded` in both
      placements.
- [ ] Confirm a long or joint artist credit wraps without clipping.
- [ ] Confirm utility artwork selection, deck round trips, Rhys, and Brudiclad
      retain artist metadata. Copy and Split retention passed.
- [ ] Smoke-test the artwork sheet on physical Android hardware and web.

Final typography, spacing, readability, and interaction-feel judgment is
deferred to the feature review.

### Rhys validation

Objective Maestro/direct-input smoke pass completed 2026-08-29 on Android 15:

- [x] Added Rhys from Utilities and confirmed the board card exposes **Copy
      Tokens** without a tracker value or increment/decrement controls.
- [x] With two clean one-Zombie stacks, the preview listed each source
      independently and reported exactly **Total: 2 tokens**.
- [x] Committing produced four Zombies total; both compatible copies merged into
      the first clean stack, leaving deterministic 3+1 stack quantities.
- [x] A second activation preview saw the committed 3+1 state and reported
      exactly **Total: 4 tokens**.

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
- [ ] Place tracker/toggle utilities between token stacks and confirm new stacks are
      ordered beside their source without collisions.
- [ ] Save, load, duplicate, export, and import a deck containing Rhys; verify it
      remains action-only with its selected artwork.
- [ ] Upgrade from pre-Rhys Hive data and confirm existing utilities retain their
      normal value controls.
- [ ] Confirm quantity-cap messaging and behavior with large stacks and active rules.
- [ ] Smoke-test the complete flow on both iOS and Android.

### Brudiclad validation

Android 15 Maestro/direct-input pass completed 2026-08-29:

- [x] Added Brudiclad as an action-only utility with **Resolve Trigger** and no
      tracker controls.
- [x] With no rules active, the flow skipped creation preview and opened the
      picker with the new 2/1 Phyrexian Myr plus the existing four-Zombie
      definition.
- [x] Resolve began disabled, enabled after selecting the Myr, and Cancel left
      the exact 3+1 Zombie board unchanged.
- [x] Resolve produced **Tokens Modified** with Undo/Accept; Undo removed the
      Step 1 Myr and restored the exact 3+1 Zombie quantities.
- [x] Repeating and accepting transformed all five tokens into one clean 5×
      2/1 Phyrexian Myr stack, with every token ready and no Zombie ghost stack.
- [x] The accepted transformed state persisted through full process restart.

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

- [ ] Confirm the blue/red border and both Brudiclad artwork choices render,
      crop, select, and persist correctly.
- [ ] With no active rules, press Resolve Trigger; confirm the creation-preview
      dialog is skipped and the picker includes the newly evaluated 2/1 blue
      Phyrexian Myr with BRC token artwork.
- [ ] With Doubling Season, replacement, or companion rules active, confirm the
      creation preview, picker, and committed board show the exact same complete
      result set.
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
- [ ] Confirm resulting creature-token stacks have zero summoning sickness;
      transformed noncreature stacks retain their previous sickness counts.
- [ ] Confirm Cathar's Crusade increments for created/merged Step 1 creatures
      only and never for Step 2 transformations.
- [ ] Choose Undo; confirm exact restoration of identities, artwork, quantities,
      counters, tapped/sick counts, order, deleted stacks, Step 1 creations, and
      Cathar's Crusade values. Confirm the restore itself fires no game events.
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

### Custom-art crash-hardening validation

Purpose: verify that the shared cached artwork renderer prevents the previously
reported Android startup/memory failure on large custom-art boards, safely
downscales legacy full-resolution uploads during decoding, and preserves normal
artwork behavior across every board-item type.

- [ ] Launch the app with a board containing 30–40 custom-art tokens.
- [ ] Fully close and relaunch the app several times with that board loaded.
- [ ] Rapidly scroll through the entire board.
- [ ] Confirm artwork appears without blank cards, flickering, or crashes.
- [ ] Test multiple tokens using the same custom artwork.
- [ ] Test many tokens using different custom artwork.
- [ ] Include older, full-resolution custom images if available.
- [ ] Expand and collapse custom-art tokens repeatedly.
- [ ] Test both **Full View** and **Fadeout** artwork modes.
- [ ] Switch between light and dark themes.
- [ ] Reorder custom-art tokens rapidly.
- [ ] Add, replace, and remove custom artwork.
- [ ] Confirm replaced artwork updates everywhere without showing the old image.
- [ ] Confirm missing custom-art files do not erase saved artwork metadata.
- [ ] Background and reopen the app while custom artwork is visible.
- [ ] Watch for excessive slowdown, overheating, Android memory warnings, or
      process termination.
- [ ] Confirm normal Scryfall artwork still loads and crops correctly.
- [ ] Confirm artwork fade-in animations still behave normally.
- [ ] Test tokens, Tracker utilities, and Toggle utilities with artwork.
- [ ] Save the board as a deck, reload it, and confirm artwork remains intact.

### Token-creation consolidation validation

Purpose: verify that the shared typed commit executor preserves stack, artwork,
summoning-sickness, ordering, persistence, and creature-ETB behavior while
centralizing primary and additional rules-result creation.

Objective simulator smoke pass completed 2026-08-29 on iPhone 17 Pro,
iOS 26.2:

- [x] Full `flutter analyze` completed with no issues.
- [x] iOS Simulator debug build completed and installed successfully.
- [x] Android debug APK build completed successfully.
- [x] Creating one database Zombie produced one distinct stack and incremented
      Cathar's Crusade exactly once.
- [x] The new Zombie persisted one summoning-sick token after full process
      termination and relaunch.
- [x] Creating the same Zombie again through search produced a separate primary
      stack rather than merging it.
- [x] Creating a custom 3/3 creature produced one distinct stack, one
      summoning-sick token, and exactly one Cathar's Crusade increment.
- [x] With one Chatterfang rule active, creating one Zombie produced the Zombie
      and Squirrel companion and incremented Cathar's Crusade exactly twice
      (observed tracker transition 5 → 7 on the rebuilt app).

Remaining objective validation:

- [ ] Add through a clean token card with rules active; confirm the unchanged
      primary adds to that stack and ETB increments once per created creature.
- [ ] Repeat from a source with each built-in and custom counter; confirm creation
      uses a separate clean compatible stack.
- [ ] Exercise a primary replacement rule; confirm the replacement identity and
      its own artwork are created and the source stack is unchanged.
- [ ] Confirm identical-art clean stacks merge and different-art stacks remain
      separate for primary and companion results.
- [ ] Exercise Scute Swarm, both Krenko utilities, Hare Apparent, Academy
      Manufactor, Rhys, and Brudiclad against their feature acceptance lists.
- [ ] Confirm split, counter split, deck restore, undo, and Brudiclad
      transformation remain event-free.
- [ ] Delete a newly created token during artwork download; confirm no stale save
      or metadata change occurs.
- [ ] Change selected artwork during download; confirm the old completion cannot
      overwrite or refresh the new selection.
- [ ] Fault-inject a later-result persistence failure; confirm partial-success
      messaging reports committed work without claiming full success.
- [ ] Repeat the objective smoke pass on physical Android hardware.

Subjective animation, visual, and interaction-feel acceptance is deferred to
the feature review.

Deck JSON export advances to schema v3 for `actionOnly`. The importer remains
backward-compatible with schema v1/v2, where the field safely defaults to false.
