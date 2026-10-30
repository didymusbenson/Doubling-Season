# Temporary feature-branch web preview and cutover cleanup

**Infrastructure: implementation in review. Phone UI: still deferred.**

The owner approved a custom Pages workflow so the phone experiment can remain on
a feature branch while the existing original and tablet code continue from main.
This does not merge the phone UI into main or change native app identities.

## Routes and source selection

- `/Doubling-Season/`: original app from main.
- `/Doubling-Season/tablet/`: stable tablet app from main.
- `/Doubling-Season/preview/phone/`: explicitly selected feature-branch commit.

Use **Deploy to GitHub Pages → Run workflow**, select the **main** workflow branch,
and set `phone_ref` to `feature/phone-mode` (or the exact desired commit SHA).
The phone ref must include the preview namespace implementation. The workflow
validates/builds that ref, then assembles it alongside stable main builds in one
Pages artifact. The exact source SHA and storage namespace appear in the
preview's `preview.json` and the site's `deployment.json`.

Do not run a feature-only Pages deployment over the whole site. Do not select the
feature branch as the workflow branch; the main publisher owns deployment.
Feature pushes are checkpoints, not automatic preview publication. Run the
main workflow deliberately when a branch checkpoint is ready for visual review.

Ordinary main pushes and manual runs with blank `phone_ref` retain the most
recent successful phone-preview artifact. They do not rebuild unstable feature
code, so a broken feature head does not block stable app development. Failed
requested preview validation never replaces the current site.

Preview artifacts are retained for 90 days. Refresh deliberately before expiry.
If a preview is already published but no successful unexpired artifact remains,
publishing fails closed rather than silently erasing that route. This is an
explicit maintenance dependency, not permanent hosting infrastructure.

## Storage and cache isolation

Phone web builds pass `TABLE_STORAGE_NAMESPACE=phone_preview_v1`. This prefixes
aggregate/previous/recovery Hive boxes, catalog/media boxes and supporter
preference keys. Empty define preserves production names byte-for-byte.
Different URL paths alone do **not** isolate browser storage. This is accidental
state isolation, not a security boundary against code on the same origin.

Keep serialized models and `tablet-art:` references unchanged. No automatic
import, deletion, copying of stable saves or preview-to-stable migration occurs.
Run the ordinary suite without the define, and namespace tests with the define.
Do not use the web preview define for normal signed tablet IPAs unless a separate
native-data policy is deliberately approved.

Preview and stable tablet builds use `--pwa-strategy=none`. Build the original
app before copying either descendant into its output so its worker resource map
does not claim the preview files. An existing original-app worker can still
control descendants; never clear all origin storage or unregister all workers
as a test shortcut. Same-browser state continuity requires explicit QA.

## Signed builds

Build/sign the selected feature checkpoint under the existing Tripling Table
identity. It replaces the installed Table test app; it is not a second concurrent
Table installation. Original Tripling Season remains separate. Record the exact
commit and keep native validation/building as the Mac-only handoff when needed.

## Mandatory cleanup at deliberate original-product cutover

Before calling the unified release complete:

1. Decide the fate of preview test data: explicit export/recovery if needed;
   never silently promote it into original TS or delete origin-wide data.
2. Retire the `/preview/phone/` route or replace it with a deliberate redirect or
   retirement notice. Remove it through the complete site publisher, not a
   partial overwrite that loses original/tablet assets.
3. Remove `phone_ref`, phone-preview build/retention selection logic, temporary
   artifact lookup and preview metadata fields when no longer needed. Handle
   the existing-preview fail-closed check as part of that planned removal.
4. Remove temporary namespace wiring only after its data-retention implications
   are resolved. Preserve production keys and migration compatibility.
5. Remove temporary preview branch/CI wiring and validation helpers only when
   their coverage is replaced or no longer relevant; preserve useful regression
   tests. Archive/delete feature branches and artifacts only as authorized.
6. Update repository docs, links and release workflow so no future main deploy
   accidentally restores an obsolete experimental route.
7. Separately validate the original-identity upgrade path, entitlements, one-time
   fresh-board migration and recovery. Preview success does not prove cutover.

These cleanup steps are future requirements, not permission to perform them now.
