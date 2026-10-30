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

In progress. The existing utility X invokes reversible `removeUtility`, not the
legacy visibility flag. Swipe will preserve that command and History undo;
management's hidden-item Show behavior remains distinct. A title disclosure
provides utility editing access. Phone continues its single utilities-then-tokens
scroll and fixed Player 1 life header.

Validation must distinguish analyzer/tests, actual rendered simulator/browser
interaction, and physical installation. Device backups and signing receipts are
kept outside Git; no private device data is committed. Existing signing profile
covers both approved devices and is reused without account/security changes.
