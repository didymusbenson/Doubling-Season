# Artwork Persistence and Loading Watchlist

**Status:** Artwork persistence monitoring; custom-art loading hardened

**Last updated:** 2026-08-29

This file retains only the artwork risks that are still actionable. Historical
startup-crash theory and obsolete pre-resize calculations were removed after
custom uploads gained a 768 px resize cap.

## Observation A: Possible Artwork-Definition Loss

### Report

During Mana symbol acceptance testing, a Squirrel token received a large amount
of abilities text. At some point afterward—possibly while editing, saving, or
reloading—the token appeared to lose its artwork definitions.

This was a single observation and may have been a transient blip. Do not treat
it as a confirmed regression until reproduced.

### Fields at risk

When investigating, distinguish between loss of:

- `Item.artworkUrl` — currently selected artwork;
- `Item.artworkSet` — selected printing/set label;
- `Item.artworkOptions` — available artwork definitions/variants;
- the cached artwork file only, while metadata remains intact.

### Reproduction watch

1. Create a database-backed token with multiple artwork variants.
2. Select a non-default variant and confirm URL, set, and options are present.
3. Add a long abilities string containing plain text, supported Mana wildcards,
   and unsupported brace codes.
4. Save and return to the board.
5. Reopen token detail immediately.
6. Fully terminate and relaunch the app, then reopen the token.
7. Save/load the board through a deck and inspect the token again.
8. Record which field disappeared and at which transition.

### Guardrails for related work

- Ability edits must not reconstruct an `Item` without copying artwork fields.
- Artwork updates must continue using `Item.updateArtwork()` as one batched save.
- Token duplication, transformation, split, deck serialization, and restore must
  preserve `artworkUrl`, `artworkSet`, and `artworkOptions` independently of
  abilities length or Mana rendering.
- Mana rendering is display-only and must never rewrite persisted abilities or
  artwork metadata.

## Observation B: High-Volume Custom-Art Loading Crash

### Original report

An Android user previously reported startup failure with roughly 34 custom-art
tokens. The failure was never reproduced locally.

### Mitigations

- New custom uploads are resized to a maximum 768 px dimension before storage.
- This substantially reduces file size and decoded image memory.
- `CroppedArtworkWidget` resolves `FileImage`/`NetworkImage` through Flutter's
  shared `ImageCache`, so repeated artwork shares pending and completed decodes.
- Decodes are capped at 768 px wide through `ResizeImage`, including
  pre-existing full-resolution custom uploads. Source files are not rewritten.

### Remaining risk

Many distinct custom images can still consume substantial memory at once, but
the known direct-decode amplification has been removed. Visibility-based
loading remains an option only if device evidence shows this is insufficient.

### Next action only if reproduced again

Capture device/crash logs and the number and dimensions of loaded files before
adding decode throttling or visibility-based loading.

## Acceptance Notes to Collect

- [ ] Artwork metadata survives a long abilities edit without leaving the screen.
- [ ] Artwork metadata survives closing and reopening token detail.
- [ ] Artwork metadata survives a full app restart.
- [ ] Artwork metadata survives deck save/load and export/import.
- [ ] Missing cache files are not mistaken for missing artwork definitions.
- [ ] A high-volume custom-art crash is reproduced or explicitly remains unconfirmed.
