# Temporary feature-branch web preview and cutover cleanup

**Infrastructure: automatic publisher implementation in review. Phone UI: feature-branch work.**

The owner approved a custom Pages workflow so the phone experiment can remain on
a feature branch while the existing original and tablet code continue from main.
This does not merge the phone UI into main or change native app identities.

## Routes and source selection

- `/Doubling-Season/`: original app from main.
- `/Doubling-Season/tablet/`: stable tablet app from main.
- `/Doubling-Season/preview/phone/`: validated `feature/phone-mode` SHA (or manual selection).

The main-owned publisher listens for completed **Tablet app validation** runs
on exactly `feature/phone-mode`. A completion publishes only when the API confirms
successful completion, the expected validation workflow, same-repository source,
the latest run/attempt, and branch HEAD still equal to the validated SHA. It
checks again immediately before deployment. Failed, cancelled, unrelated, fork,
and stale completions skip publishing; API errors fail closed. Validation runs
on the feature PR (or by manual validation dispatch); a push without a qualifying
validation completion is not itself a publishing trigger. This trigger takes
effect only after this infrastructure reaches main.

The publisher checks out that **exact SHA**, revalidates/analyzes/tests it, builds
with isolated storage and verifies browser persistence. It never checks out a
moving feature ref for automatic publication. Root and tablet always build main.
The shared Pages concurrency group serializes complete-site publishers; the
late freshness check prevents queued obsolete completions from rolling back the
preview. There remains the normal small interval between that final API check
and Pages deployment; a subsequently validated current head supersedes it.
No source-write permission, new credential, feature artifact execution in the
Pages deployment job, or feature merge is introduced.

Manual publication remains available: use **Deploy to GitHub Pages → Run workflow**, select the **main** workflow branch,
and set `phone_ref` to `feature/phone-mode` (or the exact desired commit SHA).
The phone ref must include the preview namespace implementation. The workflow
validates/builds that ref, then assembles it alongside stable main builds in one
Pages artifact. The exact source SHA and storage namespace appear in the
preview's `preview.json` and the site's `deployment.json`.

Do not run a feature-only Pages deployment over the whole site. Do not select the
feature branch as the workflow branch; the main publisher owns deployment.
Use the manual main workflow when a deliberate checkpoint needs publication
outside the automatic validation path.

Ordinary main pushes and manual runs with blank `phone_ref` retain the most
recent successful phone-preview artifact from a main-owned manual or automatic
publisher. They do not rebuild unstable feature
code, so a broken feature head does not block stable app development. Failed
requested preview validation never replaces the current site.

Preview artifacts are retained for 90 days. Refresh deliberately before expiry.
If a preview is already published but no successful unexpired artifact remains,
publishing fails closed rather than silently erasing that route. This is an
explicit maintenance dependency, not permanent hosting infrastructure.

## Guard regression checks

Run `node --test tool/pages/test_phone_preview_guard.cjs` and
`python3 -m unittest discover -s tool/pages -p 'test_*.py'`. Mocked API cases cover
accepted exact-SHA publication, failures/cancellation, forks, wrong branch and
workflow, superseded runs/attempts, moved HEAD (including during build), API
failure, and retained manual/automatic publisher provenance. Actual CI/Pages
completion is separate evidence from these local guard tests.

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
3. Remove the `workflow_run` automatic trigger and its exact-branch/latest-run/
   freshness guard, `phone_ref`, phone-preview build/retention selection logic, temporary
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
