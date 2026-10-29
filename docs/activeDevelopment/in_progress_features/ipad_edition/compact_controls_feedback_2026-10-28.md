# Compact tablet controls — 2026-10-28

Local follow-up to the merged visual/input-feedback work in PR56. This round is
held for review: no new physical-device installation or public deployment.

## Requested behavior

- Commander damage and player counters share one content-sized popup. Partner
  damage remains separate; all seat rotations retain table-relative ownership.
- The life chip shows only active counters/statuses beside its damage ledger.
  Empty counters reserve no strip; the ledger always opens the combined popup.
  Add counter exposes absent standard/custom counters inside the popup.
- Life uses its normal tap/hold controls. The in-game life correction form and
  Commander direct numeric correction are removed. Starting-life setup remains.
  Undo is available only inside History.
- Custom tokens use selectable mana colors, explicit Colorless, and separate
  sword/shield power/toughness fields. Symbolic values remain supported. Drafts,
  artwork staging, validation and failed-save recovery remain intact.
- Utilities have a direct Remove action. History restores the exact prior
  instance, including values, artwork, settings and order. Add creates a fresh
  instance instead of reviving a hidden legacy one. For a hidden Storm/Mana
  singleton, Add replaces it atomically at the same position and retains its
  complete prior state in History. Canonical mana is preserved.
- Ring progress works without an in-app creature or required bearer name.
  Existing optional bearer labels remain supported. The stored bearer was a
  label, not a token-ID relationship; no new association schema was introduced.
- Routine success acknowledgements are removed, including the shared inline
  banner that displayed “The Ring added for Player 1.” Actual save/picker/store
  failures, pending work, ownership state and recovered-draft warnings remain.

## Implementation and compatibility

The shared modal frame now uses safe-area bounds and seat-local dimensions,
with a maximum 720×640 viewport and 16px outside margin. The combined popup is
at most 620px wide and estimates its actual rows; overflow scrolls. Status tile
height grows with text scale, covering narrow sideways windows at 1.3× text.
Explicitly enabled zero counters remain visible for the current popup session;
stored zero values are preserved without forcing empty controls on reopening.

No model schema, dependency, release version, signing configuration or keyboard
architecture changes. Native keyboards cannot be independently rotated per
seat through a documented public API; that question remains research only.

The original Storm/Mana singleton invariant is preserved across visible and
hidden instances. The storage validator, state model and History representation
remain identical to the prior published version. Add fresh Storm/Mana replaces
only the same-kind hidden instance; History restores its exact payload and
position after reload. Unrelated hidden utilities and saved preset definitions
remain unchanged. Existing preset singleton deduplication is retained for these
two types; optional Ring instances retain their existing valid representation.
Thirteen compatibility regressions cover persisted recovery, both singleton
types, every duplicate-visibility combination, preset preservation, failed-save
rollback and two queued Adds awaiting durability. The latter retains the old
live/saved state until acknowledgement and produces one replacement History
entry, then restores the exact old state through Undo.

## Validation

Five supplied feedback screenshots were materialized privately and visually
inspected. Synthetic local renders cover the combined popup, custom form and
preserved new-game setup. Logs and private screenshots remain outside the repo.

Focused checks cover rapid and held inputs, delayed/failed saves, all seat
rotations, partner layouts, accessibility enabled/toggled semantics, 44px
targets, safe-area containment, utility removal and exact undo, legacy/preset
roundtrips, optional Ring bearers, and custom-token draft preservation.

Final full suite: 910 passed, five intentional skips. Full `flutter analyze`
passes. The release web build and iOS simulator build pass. The simulator build
is a compilation check only; it was not installed and does not exercise device
input latency.

Actual-font widget renders cover portrait/landscape, all four rotations, partner
layouts with and without counters, and text scaling. Visual review caught and
fixed a status-label overflow and a missing 12px height budget. A regression now
requires no unnecessary scrolling when uncapped content fits. Utility/setup
success tests verify state changes without routine notices; failed saves retain
their contextual error and recoverable draft.

A separate read-only reviewer checked the corrected code and tests, all five
original screenshots and 17 new renders. No remaining code/layout findings were
identified. The review also independently confirmed the unchanged published
state model, controller and storage validator.

Final release Chrome smoke passes in 74.170 seconds with no runtime exceptions,
including rapid/held life input, History undo, counter activation, persisted
reload, keyboard entry, artwork, and all four seat-facing partner grids in
portrait and landscape. Exact build hashes and screenshots are recorded in the
private handoff receipt. Physical responsiveness, native picker and native Paste
acceptance are not established by these local checks.
