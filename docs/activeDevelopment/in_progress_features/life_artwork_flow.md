# Life artwork search and preview refinement

## Scope and source
The tablet seat's Player Tools customization action and phone's Player 1
settings action both open the same seat-scoped Player workspace. Its Life
artwork panel opens a separate chooser using the same orientation, modal
surface, text input host, and per-seat draft fields. The board continues to
render the stored profile artwork with its existing life foreground and
contrast handling. No board presentation, keyboard internals, storage
format, or catalog sources changed.

## Diagnosis
The original search field and import shortcut scrolled with the catalog in
a single list. Result rows were flatter than the established token search,
with no printing count or affordance for another step. The preview stacked
a second copy of the printing gallery underneath the confirmation and its
Back arrow discarded the selection and returned straight to search. A
fixed-width current-art thumbnail left the no-art case empty and looked
unrelated to the adjacent customization panel.

Baseline and revised Flutter test-renderer captures used the catalog test
fixture, no network, at 1133×744 (opposite seat), 744×1133, and 320×640.
A simulated 288px native keyboard inset confirmed that an always-visible
import footer crowded the first result; hiding it only for that inset
leaves search and a full first result visible.

## Changes
- Current art/default seat-color strip in the existing appearance panel;
  remove remains a scoped durable action, and the saved seat color remains.
- Pinned, inset search field with a magnifier; scrollable and lazily built
  token-search-style rows with thumbnails, printings counts and chevrons.
- Clearly separated printings and preview, with responsive printing cards;
  Back is a one-stage action and Close still does not apply artwork.
- The current saved artwork is labeled within its printing card; preview
  uses the selected printing and shows its credit, not a repeat gallery.
- Custom import remains separately visible in search, except while the
  native keyboard occupies the phone. It leads to its own preview.
- Retained query and any still-staged candidate restore through existing
  caller-owned drafts. The validated selected URL is returned unchanged,
  and only the existing caller commits it. No native/device changes.

## Validation
- Focused coverage: seat rotations, keyboard geometry, narrow native inset,
  3 viewport captures, exact selected printing, staged Back, import,
  validation/error, phone draft retention, and seat-scoped durable removal.
- Visual evidence is Flutter test rendering with distinguishable offline
  image fixtures, not native-device acceptance.
- Flutter 3.41.2: 2,192 passed and 25 skipped in the full tablet run
  (canonical macOS TMPDIR). Final fallback-thumbnail polish and the extra
  custom-import regression were validated in the final 36-test focused run.
- Final `flutter analyze`, `flutter build web --release`, and
  `git diff --check` all passed. Nothing installed or deployed.
