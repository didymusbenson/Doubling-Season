# Phone feature: decision and implementation summary

**Status: option C implemented in WIP feature branch; lifecycle and visual validation in progress.**
This is the end-to-end implementation record for the approved phone direction. The custom Pages preview infrastructure is a separately authorized task,
not permission to start the phone interface.

## Explicit owner feedback

- Fixed Player 1 of an N-player session; no player hot-swap.
- Fixed compact life at top, one scrolling utilities-then-tokens body, fixed
  thumb-accessible controls, newer Table aesthetic.
- No compact tablet mode or full-table layout on phones in this scope.
- Fold/unfold closes menus/modals, preserves gameplay, reveals full table open.
- Preserve migrated live token board and enabled utilities with Table counterparts;
  saved decks must separately import/convert safely. Earlier clear-board idea is
  superseded, not a fallback to apply without permission.
- Separate tablet identity during development; deliberate original-identity
  release cutover later. Phone work stays on a feature branch; stable tablet main
  remains deliverable. Signed feature builds are allowed after implementation.
- Cloud-first editing and commit/push checkpoints; Mac only when necessary for
  native validation/building or explicitly requested.
- Show alternatives before implementation. Once approved, implement end to end,
  perform design/UX reviews and record independent decisions versus user feedback.

## Assistant recommendations / judgment calls (not mockup approval)

- The initial recommendation was B; the owner selected C instead. Implement
  direct Token, Utilities jump and More; do not reinterpret the generated image.
- Return to the actual utility section rather than duplicate pinned mana controls.
- Preserve unfinished drafts when dismissing UI on a fold; do not silently commit
  text or replay accepted commands. Exact durable-draft policy needs validation.
- Preserve/report unsupported migration entries, not silently delete or substitute.
- Separate live board conversion from preset conversion because their semantics
  intentionally differ. Audit source: [saved configurations](preset_audit.md).

## Required record once implementation starts

For each material decision, record: user requirement or assistant judgment,
chosen behavior, reason/alternatives, changed files, regression/visual evidence,
remaining risk and whether owner confirmation changed the choice.

Record source branch/commits, test and design-review outcomes, preview deployment
SHA, signed-build source equivalence, and actual installation/physical testing
separately. Never describe unrun validation as passed. Keep WIP pushed and avoid
merging the phone implementation into main before deliberate integration approval.

## Design approval (2026-10-30)

The owner approved option C **as behavior**: direct Add Token, Utilities jump,
and More. The generated images must not be used or retained as design context.
No generated image is committed here; its shapes, token layout, typography and
artwork are not implementation requirements. Use the actual Table UI and written
owner requirements as the design authority.

Phone implementation is authorized on its feature branch, including design/UX
passes and a summary of independent decisions. Stable tablet main stays separate.

## Implementation checkpoint (2026-10-30)

Branch: `feature/phone-mode`, draft PR #66. Do not merge the phone feature into
main during this experimental phase. The latest published checkpoint before this
review is `993df46bdcdbcfd9be4e1dc782ed5a252ecb9d83`.

### Owner requirements implemented

- Fixed Player 1 life header with the existing commander/counter presentation.
- Utilities then tokens in one scroll view; direct Add Token, Utilities and More.
- Existing Table token/utility artwork, controls and styling reused rather than
  deriving UI from the generated concept image.
- Session player count and all players' board state remain unchanged by layout.
- Phone and tablet presentations retain their editing trees when switching.
- Table identity remains separate; iOS device family now admits phone and tablet.

### Independent implementation decisions

- Native layout uses physical display size, with a provisional 600 logical-pixel
  shortest-side boundary. A narrow tablet window does not select compact mode.
  Hardware foldable classification still needs physical validation.
- Web compact mode requires the isolated preview build flag/storage namespace;
  stable tablet web does not become compact when its window narrows.
- More is a local action panel. Opening it cancels held input; its tap-away layer
  consumes the dismissal tap rather than applying an unintended life change.
- Layout changes cancel pointers and close transient routes without implicitly
  saving keyboard drafts. Pending life feedback is shared between presentations.
- Retained token drafts check for conflicting newer edits before automatic flush.
- Artwork query/URL drafts are retained; temporary crop geometry is not committed
  merely because presentation changed.

### Evidence and remaining work

The cloud Flutter 3.41.2 SDK is operational. Focused presentation tests pass (9),
and analyzer is clean at the first local lifecycle checkpoint. Full suite and
actual rendered-layout review are running. Review identified stale clean-field snapshots and delayed picker completion risks.
Dirty-only snapshots, retained original baselines, and atomic transaction guards
now cover token text/numeric/counter edits and player names. Dedicated regressions
cover conflicting queued writes and pending accepted saves; 48 scoped tests pass.
Layout captures now keep rasterization inside real async execution to avoid the
widget test fake-clock hang; they are explicitly not production-font evidence.
Remote 993 CI passed simulator and browser jobs but failed one formatting lint;
the lint is corrected locally and will be revalidated in the next checkpoint.

No phone preview publication, signed feature IPA, physical phone/foldable testing,
or original Tripling Season migration is claimed complete. Preset conversion and
live-board migration remain separate cutover work, governed by the migration docs.

### Verified checkpoint 7820706

- Full cloud tablet suite: **1,061 passed, 7 skipped**, no failures.
- Analyzer clean; focused phone/draft suite: **17 passed**, including captures.
- Release web build succeeds. Runner Chrome rendered real phone UI; inspected
  board, More, and Add Token at 320×568. Board and action pod fit; the Add Token
  header compressed search excessively and is being corrected before acceptance.
- Browser smoke incorrectly sought the absent zero-counter summary instead of
  the commander-damage entry point; selector corrected to the actual UI contract.
- Local Chromium startup is unavailable in the cloud sandbox and the separate
  browser cannot reach workspace localhost. Browser validation runs in GitHub CI,
  retaining screenshots and accessibility evidence; this is not a Mac dependency.
- The feature remains draft PR #66. No main integration or native release claimed.
