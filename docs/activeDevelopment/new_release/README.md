# Next Release

This directory is the staging area for work implemented and proposed for the next
production release. Feature records move here after implementation, remain here
through acceptance testing, and move to `docs/releases/vX.Y/` when that release
ships.

## Release Log

### Separate tablet app validation (not part of phone 1.11)

2026-10-21: the independent `apps/tablet` first implementation builds for web,
Android and iPad simulator, and passes static analysis. Temporary external
Maestro flows on iPad mini A17 Pro / iOS 26.2 verified launch, token selection,
Treasure creation, and modal dismissal back to that player's board. Browser
interaction covered 2/3/4-seat layouts, life/history undo, archive restoration,
scoped rules, commander damage/correction and zero-state setup loading. See the
[measured results and remaining gates](../in_progress_features/ipad_edition/implementation.md).
Physical acceptance remains pending; the tablet dossier is not release staged.

2026-10-23 update: the tablet's signed Release 0.1.0+1 (`a79a381`, PR #47)
was installed and launched on a physical iPad Air 13-inch (M3), with the rendered
four-player board and installed icon inspected. This completes that narrow
handoff, not full gameplay/device-matrix acceptance. The
[readiness audit](../in_progress_features/ipad_edition/mvp_readiness_audit.md)
records coverage and remaining gates; implementation is paused while the user
collects field-test feedback for one deliberate next batch.

### Billing update included in 1.11

The pricing/billing fix ships with 1.11.0+19. `in_app_purchase` is locked to
3.3.1 and its Android implementation to 0.5.0, which declares Google Play
Billing 8.0.0. The app requires Dart 3.10 or later and the web CI uses Flutter
3.38.x to satisfy the plugins' minimum supported toolchain. This updates the
purchase integration; it does not change store product prices or identifiers.

See [BillingUpdate.md](BillingUpdate.md) for combined-release validation.

### Release Smoothing: Expanded Token Removal

**Status:** Implemented for 1.11; iOS/Android simulator swipe checks pass; pending physical-device acceptance

Expanded token cards now retain the board's swipe-to-remove gesture whenever no
inline text field is active. Active editing still disables dismissal to protect
text selection and unsaved changes. Removing an expanded token also clears the
shared expansion controller so the next board interaction is not consumed by a
stale expanded-item state. Expanded utilities retain their existing behavior.

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
- clears summoning sickness from every token stack because resolving the ability
  establishes that Brudiclad is present and sickness is inapplicable to
  noncreature results;
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

## 1.11 recovery and validation follow-up — 2026-09-27

The interrupted September 26 task implemented the three approved fixes. Its
individual bug records contain the completed checks; the September 25 findings
below are historical and do not describe the current code/database.

Implemented and verified:

- Published database v9 in main commit `e4867f4` restores artist metadata.
  The release bundle matches that payload byte-for-byte: 962 definitions,
  3,079 artwork entries, no empty artist fields, 889,530 bytes, and SHA-256
  `202cb0492099790a8c7b7181b2ce576e4ba408c4df3075d8a947029896286db8`.
- Removed per-type startup ordering rewrites. September 26 iOS fixtures verified
  valid negative/zero/fractional positions, deterministic legacy ties, dense-gap
  normalization, and partially applied journal recovery across two restarts,
  with all non-order fields unchanged.
- Renamed Brudiclad retains 2XM/C18 with Daarken; C18 survives restart. Renamed
  Monarch retains all four choices. Renamed Zombie recovers Carl Critchlow's
  10E credit without changing artwork-cache files (September 26 iOS checks).
- September 27: current source passed `flutter analyze`, iOS Simulator debug
  build, and Android debug APK build. Both builds installed and launched over
  existing simulator/emulator data.
- Android direct-input dragging moved Brudiclad from below Rhys to between the
  Myr and Rhys; persisted position changed from 4 to 2 and survived restart.
- Android manual fault injection threw after the first board-row save while
  moving Rhys. The non-dismissible recovery dialog blocked system Back and
  background taps; `pendingV1` retained the intended complete move. Reinstalling
  the normal build recovered Rhys to 1.5, cleared the journal, and preserved
  every non-order field. A second restart produced identical saved board data.
  This exercises an interrupted write sequence, not a real disk-full condition.
  The temporary injection was removed from source and the normal APK restored.
- iOS Save Board → Clear board and load preserved the interleaved sequence
  Monarch, Myr, Brudiclad, Zombie, Treasure at positions 0–4, and all artwork
  URLs/sets/variants/credits. The whole loaded board survived restart unchanged.
  Add to current board appended the same sequence at positions 5–9; another
  restart preserved all ten records unchanged. Token amounts reset to zero on
  deck load as designed; this is not an exact game-state restore.

- September 27: swiping an expanded token with no active editor removed it on
  both iOS and Android. The next tap immediately
  expanded Myr on iOS and Rhys on Android, confirming stale expansion state
  did not consume either interaction.

Remaining acceptance is explicit: the complete top/middle/bottom gesture matrix
for every board type, custom-upload/offline/unmatched-artwork cases, every
copy/split/Rhys/Brudiclad/rules combination, real storage failures, full legacy
upgrade coverage, custom-art memory pressure, signed IPA/TestFlight upgrade,
physical-device and subjective accessibility/visual review are not implied by
these targeted passes. Existing detailed checklists remain the source for those
release gates. No production app release was uploaded by this follow-up.

## iOS 1.11 simulator follow-up — 2026-09-25

Environment: iPhone 17 Pro Max, iOS 26.2; current working tree `1.11.0+19`
(including the uncommitted Brudiclad sickness fix). Built using
`flutter build ios --simulator --debug --no-pub`, installed and launched.
Native Simulator UI was driven directly. Persisted results were inspected from
read-only copies of simulator Hive files; no automated test suite was added.

Confirmed passes:

- Accepted the in-app v8 token database update on a fresh simulator install.
- Brudiclad picker included 3 Zombies, 2 tapped Treasures, and the new Myr.
  Resolving to Treasure saved one 6-token stack, 2 tapped, 0 summoning sick.
- Brudiclad Undo restored the 3 Zombies (including 3 sickness counts), the
  original 2 tapped Treasures, and removed the generated Myr.
- Edited the restored token name successfully; persisted data confirms the edit.
- Delete All → Undo on a token/tracker/toggle board restored every persisted
  field exactly, including a +1/+1 counter, artwork, identities, quantities,
  tapped/sick counts, and ordering.
- Tracker and toggle name edits after that restore saved successfully and
  survived termination/relaunch, alongside the token edit.
- Brudiclad Skip created one Myr, retained the existing identities, quantities,
  counter and tapped counts, and saved 0 sickness for all three token stacks.
- Set to 0 cleared token quantities/tapped counts; Undo restored an exact
  all-field snapshot of the mixed board.

Reproduced failures:

1. **User board order changes after restart.** Move Treasure to the start;
   restart puts Zombie back first. The valid order 0 triggers per-type startup
   migration and rewrites token order. See
   [reproduction](../bug_bashing/board_order_changes_after_restart.md).
2. **Remote v8 loses artist attribution.** New 10E Zombie shows `Artist unknown`.
   Published DB has 3,079 artwork entries and zero artist values; 1.11 bundled
   data has credits on all 3,028 entries. The main-branch generator used for the
   refresh predates artist-credit support. See
   [reproduction](../bug_bashing/remote_database_missing_artist_credits.md).

Limits: compact and expanded swipe gestures did not take effect through native
simulator automation, so expanded swipe removal remains unverified (not an
established app regression). No physical-device, signed IPA/TestFlight,
old-install upgrade, memory-pressure, fault-injection, or full rules-matrix
acceptance is implied. The two reproduced defects were documented, not fixed,
in this validation pass. Existing broader checklists below remain applicable.

## Acceptance Testing Required

### Physical-device release checklist — 1.11

Physical-device handoff, 2026-09-27: the signed release-mode build 1.11.0+19
was installed in place on didym's iPhone 17 Pro Max (iOS 26.6.2) over the
wireless connection. Apple device tooling confirmed installed version/build
and successfully launched the app. No uninstall was performed. This is direct
development-signed installation for hands-on testing, not a TestFlight/store
upgrade or purchase-acceptance pass; the checks below remain pending.

Run this against the actual release candidate through TestFlight on iPhone and
Google Play's internal/closed testing track on Android. Record the installed
version/build; repeat affected checks if the candidate changes. Simulator
results above do not check these boxes. Complete each applicable check on both
platforms, recording platform-specific failures in the table below.

| Device / OS | Version / build | Install path / previous version | Tester / date | Result / issue links |
|---|---|---|---|---|
| Physical iPhone | | TestFlight upgrade | | |
| Physical Android | | Play testing-track upgrade | | |
| Additional older/smaller or lower-memory device, if available | | | | |

#### Installation, upgrades, and saved data

- [ ] Upgrade an existing production install **without uninstalling first**.
      Confirm the store offers and installs the candidate, particularly on the
      Android device previously stuck on 1.8. Record the starting version.
- [ ] Before/after comparison preserves saved decks, mixed token/utility board,
      quantities, counters, tapped/sick states, chosen artwork, ordering,
      favorites, settings, and previously purchased supporter tier.
- [ ] On a separate clean install, launch successfully, dismiss onboarding or
      What's New, create a board, and close/reopen without errors or data loss.
- [ ] Background, lock/unlock, force-close, and relaunch during normal play;
      repeat after a device reboot. The last completed edits remain saved.

#### Pricing and purchases

Use store sandbox/license-test accounts and test purchases.

- [ ] All three supporter tiers load with the correct localized store price
      and currency; the store purchase sheet agrees with the displayed price.
- [ ] Complete test purchases for each tier across suitable test accounts.
      The correct highest-owned tier/badge appears and survives relaunch.
- [ ] Cancel a purchase and exercise pending/failed purchase states where the
      store supports them. No false success, wrong tier, or stuck loading state;
      a later retry works.
- [ ] Restore previously owned non-consumable tiers on a fresh test install;
      no repurchase is needed. Existing ownership survives the 1.11 upgrade.
- [ ] With the store/network unavailable, gameplay remains usable, cached
      ownership remains visible, and reconnecting restores product loading.

#### Normal gameplay and utilities

- [ ] Play a representative game: search/add database and custom tokens, change
      quantities, tap/untap, clear sickness, and edit built-in/custom counters.
      Check displayed totals and persistence after relaunch.
- [ ] Copy and split stacks with counters, artwork, and tapped/sick quantities;
      verify the intended copied/reset fields, totals, and source-adjacent order.
- [ ] Exercise Rhys and Brudiclad with creature/noncreature stacks and active
      doubling/replacement/companion rules. Preview and result agree; Brudiclad
      Resolve/Skip/Undo handle sickness, counters, and tapped counts correctly.
- [ ] Smoke-test existing Krenko, Scute Swarm, Academy Manufactor, Cathars'
      Crusade, and ordinary tracker/toggle utilities alongside the new features.

#### Editing, ordering, and Undo

- [ ] Expand/collapse tokens and both utility types, switch between cards, edit
      inline, and dismiss the keyboard. Android Back and iOS navigation behave
      predictably; edits save and failed/canceled actions do not lose data.
- [ ] Drag each board type to the top, middle, and bottom of a mixed board;
      force-close/relaunch twice and confirm the exact sequence persists.
- [ ] Swipe away compact and expanded tokens; expanded tokens remain protected
      while editing. Expanded utilities remain protected. The next card opens
      on its first tap after deletion.
- [ ] Exercise all three board-wipe choices with tokens, utilities, counters,
      and rules. Undo restores the exact board/rules; Accept persists the result.
      Back/outside taps do not dismiss the completion dialog.
- [ ] After Brudiclad Undo and board-wipe Undo, edit a restored token, tracker,
      and toggle, then change artwork. No detached-object errors or lost edits.

#### Artwork, database updates, and decks

- [ ] Check token search, Recent/Favorites, and database update status; where an
      older database is available, download v9 or later and verify new tokens
      and artist credits. Cancel/retry a download without losing usable data.
- [ ] Rename/customize a token, Brudiclad, and Monarch. Their saved artwork
      choices and credits remain available; a new selection survives relaunch.
- [ ] Add, replace, and remove uploaded artwork through the device photo/file
      picker. Cancel or deny access gracefully; uploads show `user uploaded`.
      Previously cached artwork works offline in Full View and Fadeout modes.
- [ ] Save a mixed board as a deck; clear/load, add to board, duplicate, and
      export/import it. Preserve intended order, identity, artwork/credits, and
      action-only utilities. Loaded token quantities start at zero by design.

#### Performance, readability, and accessibility

- [ ] Use a board of 30–40 custom-art tokens, including repeated images and
      different large/legacy images. Scroll, reorder, expand/collapse, and
      background/reopen repeatedly without crashes, blank art, severe slowdown,
      excessive heat, or OS termination. Record device and session duration.
- [ ] Check light/dark themes, both artwork styles, larger system text, a small
      screen, keyboard visibility, safe areas, and long names/artist credits.
      Controls, mana symbols, counters, and text remain readable and reachable.
- [ ] Listen with VoiceOver/TalkBack: board status, mana symbols, editing,
      artwork, purchases, and Undo/Accept are labeled and navigable; focus stays
      usable as cards expand, dialogs close, and items are removed.
- [ ] Complete a normal-length gameplay session with interruptions and screen
      locking. Judge touch targets, animations, accidental gestures, battery/heat,
      and whether the keep-awake behavior matches expectations.

#### Release sign-off

- [ ] Every check has a recorded iOS/Android result or an explicit, explained
      exception. Link reproduced failures to bug records and retest fixes on
      the final candidate; do not silently count unavailable coverage as passed.
- [ ] Confirm no unresolved release-blocking data-loss, crash, upgrade, purchase,
      or core-gameplay defects. Record any accepted remaining limitations.
- [ ] Record final device approval and the exact candidate build approved for
      submission. This checklist supplements the detailed feature checks below.

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
      transformation, clears sickness from every token stack, and shows no
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
- [ ] Confirm every resulting token stack has zero summoning sickness,
      including when the chosen definition is Treasure or another noncreature.
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

## Repository integration checkpoint — 2026-10-21

Integrated the current 1.11 implementation, IPAD EDITION dossier and subsequent
Lifetap research with published `main` at `2799be4`. The integration tree is
`af51026`; this checkpoint records validation without marking outstanding
device acceptance or the unimplemented iPad project complete.

- Preserved the exact published token database/manifest v12 pair from
  2026-10-19: 965 unique definitions and 3,092 artwork entries with artist
  metadata. Verified manifest size (892,451 bytes) and SHA-256; no regeneration
  or version bump was needed. Both conflicted asset files use this matched pair.
- Confirmed the latest 1.11 commit `8894640`, dossier refinements `3ddb425`,
  Lifetap research `6bb9a20` and published `main` are ancestors of the integration.
- `flutter analyze`: passed with no issues on Flutter 3.41.2 / Dart 3.11.0.
- `flutter build web --release --base-href /Doubling-Season/`: passed. The build
  reported a non-fatal CupertinoIcons font-family warning.
- Retained the incoming Flutter 3.38.x Pages workflow required by the current
  dependency floor. The local build above uses the installed SDK; GitHub's
  workflow validates its configured SDK separately after merging.
- No new automated test code was added. Physical-device and manual interaction
  acceptance statuses elsewhere in this document remain as previously recorded.
