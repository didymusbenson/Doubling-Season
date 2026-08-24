---
name: "source-command-regen-tokens"
description: "Check MTGJSON for token updates, regenerate and validate the bundled database, then commit and push it to main"
---

# Regenerate and publish the token database

Use this skill when the user asks to check for new Magic tokens, refresh the token database, or run the migrated `regen-tokens` source command.

## Workflow

1. Read the repository `AGENTS.md` and preserve all unrelated user changes.
2. Fetch `origin` and run the refresh from current `origin/main`. If the active checkout is not a clean `main`, create a temporary worktree and a `codex/` branch based on `origin/main` rather than disturbing it.
3. Verify `docs/housekeeping/process_tokens_mtgjson.py` exists.
4. From `docs/housekeeping/`, run:

   ```bash
   python3 process_tokens_mtgjson.py
   ```

5. Review changes to both generated files:
   - `assets/token_database.json`
   - `assets/token_manifest.json`
6. Report whether token definitions were added or removed, and summarize material metadata/artwork/popularity changes. If nothing changed, stop without creating a commit.
7. Validate the generated artifacts:
   - Both files parse as JSON.
   - Token composite IDs (`name|pt|colors|type|abilities`) are unique.
   - The manifest `size` and `sha256` match `assets/token_database.json`.
   - The token count is plausible and no unexpected generated files are present.
8. Commit only the generated database, manifest, and this skill when it is being introduced or updated. Use a concise commit message without Codex attribution, such as `Update token database from MTGJSON`.
9. Push the commit to `origin/main`. Prefer a fast-forward push from an up-to-date `origin/main`; never force-push. If remote `main` moved, fetch, rebase the focused commit, revalidate, and retry normally.
10. Report token counts, validation results, commit hash, and push result. Remove a temporary worktree after success when safe.

## Generator behavior

The script downloads `AllPrintings.json.xz` from MTGJSON and caches the decompressed archive under `docs/housekeeping/mtgjson_cache/`. It extracts token, emblem, and double-faced-token layouts; merges `custom_tokens.json`; normalizes names, types, reminder text, and WUBRG color order; and deduplicates with the composite key `name|pt|colors|type|abilities`.

The cache and downloaded archive are not committed. The script also merges `reverseRelated` creator cards, calculates popularity, builds Scryfall artwork URLs, sorts tokens by name, and updates the manifest version/hash/date.

Run the script from `docs/housekeeping/` because its paths are relative. The Cockatrice fallback, `process_tokens_with_popularity.py`, should be used only if the MTGJSON workflow is unavailable and the user agrees to the fallback.

## Safety

- Do not include unrelated working-tree changes in the commit.
- Do not rewrite published history or force-push.
- Do not publish a surprising large deletion or token-count collapse without investigating first.
- Do not manually edit generated token records; fix the generator or custom-token source and rerun it.
