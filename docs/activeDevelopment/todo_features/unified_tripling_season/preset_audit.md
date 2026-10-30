# Saved configurations: migration-readiness audit

**Read-only source/test assessment, 2026-10-30; not a passed native acceptance run.**
Runtime baseline: PR61 / `3d3723ec`. The owner has not thoroughly tested Table
saved configurations and requested closer examination before relying on them.

## Existing implementation

`apps/tablet/lib/features/preset_service.dart` saves reusable token/utility
configurations, not a live-game snapshot. Tokens are deduplicated by definition
and artwork; live quantities/tap/sickness/counters are intentionally not saved.
Replace/Append create zero-state token entries and default utility state. Ring
progress/bearer is reset. Certain singleton utility kinds are not duplicated on
Append; existing singleton configuration wins. Loads are scoped history commands.
Optional cover application changes that player's saved life artwork.

Library UI supports save, rename, delete, legacy schemas 1–3 import, v4 import/
export, and decklist-derived tokens. There is no explicit overwrite-current-setup
operation. v4 can embed uploaded media; phone-v3 export deliberately omits uploaded
images, cover, mana utility and visibility. Conversion must not conceal those losses.

## Concrete gaps to resolve or explicitly account for

- Token template save omits `TokenState.extra`, including per-token full/fade art
  style. A saved/reloaded setup can lose that individual display choice.
- Legacy import does not preserve deck color identity, ordering or timestamps;
  mixed board ordering becomes separate token/utility order.
- Raw legacy utility metadata can survive without behavior parity: current Table
  does not read `onArtworkUrl`, `offArtworkUrl` or `longPressIncrement`.
- Counterpart matching uses action type/custom identity and then editable names;
  renamed built-ins without stable IDs require careful semantic identification.
- Import validation is shallower than full token/utility compatibility. Unsupported
  entries can enter the library and fail only when loaded; quarantine/reporting
  for migration is not implemented.
- Legacy local file URLs are retained but not rendered by Table; copy/remap bytes.
- Live legacy power-only/toughness-only counters need mapping to Table's +1/+0
  and +0/+1 counters without collisions. Never flatten distinct live stacks.
- Hidden legacy life/counter/status utilities must populate canonical fields,
  not merely survive as hidden payloads.

These findings are not fixes or a release-ready declaration. Preserve raw source
and explicitly report unsupported counterparts rather than substitute by name.

## Coverage versus missing evidence

Existing regressions cover UI save/append/replace, failed-save drafts, phone
schemas, explicit custom identity, v4 utility templates, Ring fresh-state,
singleton handling and undo. Relevant tests include
`workspace_silent_success_test.dart`, `utility_compatibility_regression_test.dart`,
`ring_utility_regression_test.dart`, `utility_singleton_compatibility_test.dart`
and `utility_removal_regression_test.dart`.

Most use `MemoryTableRepository`. Historical browser evidence at `dcac16b` covers
save/replace/undo preserving life and another seat; it is not current comprehensive
native or original-install migration acceptance.

Priority follow-up validation:
1. Separate live-board and saved-deck conversion fixtures, including duplicate
   stacks, all counters, uploads, enabled utilities and missing counterparts.
2. Save/Replace/Append/Undo on two seats, optional cover apply/undo, independent
   art/config objects and interrupted/failed durable writes.
3. Artwork-rich v4 roundtrip: bytes, credits, styles, corrupt/missing assets,
   size limits and offline reopening.
4. Malformed/future imports, unsupported utility kinds, renamed built-ins and
   honest export omissions; real file-picker/export save/cancel behavior.
5. Installed-app restart/upgrade and retry without duplication or overwriting
   subsequent play. Passing in-memory tests alone does not establish this.
