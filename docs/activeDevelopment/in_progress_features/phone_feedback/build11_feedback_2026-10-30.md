# Build 11 phone and tablet feedback

Work remains on `feature/phone-mode` / draft PR #66. No main merge, Firebase
upload or store publication is part of this batch.

## Explicit requirements

- Use native keyboards in phone presentation; keep player-facing tablet input.
- Audit numeric fields broadly. Invalid input must not expose exception text or
  silently overwrite good state. Restore clean pre-edit values where appropriate.
- Custom token validation uses inline guidance and a shake; center color identity.
- Search color filters use symbols with accessible names. Exclude unsupported
  Dungeon and Counter choices without deleting catalog or custom-token data.
- Phone Utilities always opens management with a recognizable icon.
- Utilities swipe away in phone and tablet lanes. Keep editing discoverable and
  retain existing state/history semantics. Essential descriptions stay visible.
- Follow-up: remove manual setting/edit buttons for player counters; retain
  steppers. This does not remove token or utility editors.
- After validation, install locally to the verified reachable iPhone and iPad.

## Implementation decisions and validation

Implemented; final validation and local installation in progress. The existing utility X invokes reversible `removeUtility`, not the
legacy visibility flag. Swipe will preserve that command and History undo;
management's hidden-item Show behavior remains distinct. A title disclosure
provides utility editing access. Phone continues its single utilities-then-tokens
scroll and fixed Player 1 life header.

Validation must distinguish analyzer/tests, actual rendered simulator/browser
interaction, and physical installation. Device backups and signing receipts are
kept outside Git; no private device data is committed. Existing signing profile
covers both approved devices and is reused without account/security changes.

## Input audit and review corrections

The shared parser accepts trimmed decimal whole numbers and explicit field
ranges. Invalid explicit actions restore clean source/default text and abort
before writing; invalid inline edits restore their saved value without history.
The manual-entry cap does not redefine the range of existing stored values.
Legacy values above that cap remain intact under repeated invalid submissions.
Token Total steppers now apply exact live transactional deltas rather than
clamping large saved stacks down to the manual-entry cap. Modifier gestures no
longer clamp imported values down to 20: out-of-range results are rejected
atomically; valid exact corrections and Undo preserve original metadata.

Covered fields: creation and token-counter quantity (1–999999), absolute token
counts/counters (0–999999), tapped/sick (0–stack total), split (1–total minus 1),
utility values (0–999999; signed life ±1e9), Ring count (0–1e9), multiplier
(1–1024), companion quantity (1–999999), starting life (1–1e6). Stored legacy
values retain the persistence range. Symbolic P/T remains supported, with BigInt
rendering/summary arithmetic for numeric expressions. No schema, storage-key,
seat identity, archive or history migration occurs.

Custom token missing-name and malformed stat/color feedback is inline, scrolls
to the first error and shakes unless Reduce Motion is enabled. Search removes
only selectable Dungeon/Counter choices; existing custom records remain
searchable. Both current bundled corpus counts were zero. Color names remain in
accessibility semantics. Generic artwork input failures also use readable
feedback; startup/catalog recovery diagnostics are outside this numeric audit.

Independent code review caught legacy-original parsing and restoration errors,
plus a pre-existing large-total clamp; all were corrected with regressions.
Native-focused review reproduced and fixed a short-landscape multiline/error
panel overflow. P/T selects a text IME on phones so symbolic values remain
enterable. Tablet custom keyboard and player orientation remain intentional.

## Validation checkpoint

- Flutter 3.41.2 analyzer: no issues.
- Full suite: 1101 passed, 7 opt-in tests skipped, 2026-10-31 UTC.
- Independent release-browser interaction review: phone native-field route,
  invalid custom name/quantity, centered symbols, accessible color filters,
  populated Utilities management, Krenko/Squirrel Girl labels, swipe and exact
  History restore, four-player scroll/rotated modal and counter-only steppers.
- Native iPhone 17 Pro Max simulator: real iOS text/numeric keyboards and
  keyboard-dismissal viewport inspected. Tablet orientation is also covered by
  focused tests; physical installation and final native checks follow.
- Source checkpoint is pushed to the existing feature branch; PR remains draft.

## Build 12 and local delivery

Runtime source: `351fc405d461cf3ffd6c87f1352736d6e3274c07`.
Release `0.1.0 (12)` was built and exported with the unchanged existing
provisioning profile and certificate. IPA checks passed: ZIP integrity, native
strict/deep signature verification, exact bundle `LooseTie.Tripling-Table`,
`UIDeviceFamily [1,2]`, version/build, and embedded profile matching the verified
build 11 profile that includes both approved devices.

IPA SHA-256: `d6b6bdecdf3fc2d3bbd03add49ff49b1042aa81bec9212145b4b6b5550e801f6`.
Size: 12,441,231 bytes. Signed IPA saved in the user's Library.

Both physical devices were backed up (Documents and Preferences) and updated
in place with `devicectl`; neither app was uninstalled or reset. Installed app
queries confirm build 12 on iPhone 17 Pro Max and iPad Air 13-inch (M3). Each
post-install aggregate matches its pre-install backup byte for byte, including
all seats and History. Backups, device identifiers, and private receipts remain
outside the repository at the task's `verification/` directory on Kista.

Native simulator visual evidence confirms iOS text and signed-numeric
keyboards, readable invalid-number restoration, portrait/landscape keyboard
insets, multiline Return and Done transitions, and the intentionally rotated
player-facing tablet keyboard. The independent browser review captured 33
screenshots with zero runtime exceptions or console errors. Its build preceded
minor final preservation/landscape fixes; those passed focused tests, the full
suite, and final native simulator checks. Browser checks are not physical-device
hands-on acceptance.

Physical launch verification is still blocked by device locking. The iPhone
launch returned explicit `Locked` denial. The iPad launch timed out after 30
seconds; a subsequent process query found no Tripling Table process and its
lock state still required a passcode. Both installations are confirmed; unlock
each device and launch Tripling Table to finish physical acceptance. An unlock
request was sent while verification continued. No pairing, trust, security,
signing, Firebase, Play, App Store, preview publication, or main merge changes
were made. PR #68 remains outside this work.
