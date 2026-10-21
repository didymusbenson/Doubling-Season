---
name: "source-command-checkpoint"
description: "Stage and commit all changes with a descriptive message (no Codex attribution)"
---

# source-command-checkpoint

Use this skill when the user asks to run the migrated source command `checkpoint`.

## Command Template

Stage and commit all changes to git with a clean, descriptive commit message.

**CRITICAL REQUIREMENTS:**
- **NEVER** add "🤖 Generated with [Codex]" footer
- **NEVER** add "Co-Authored-By: Codex <noreply@anthropic.com>" trailer
- Write clean, descriptive commit messages focused on the "why" not the "what"
- Follow existing commit message style in the repository
- Commits belong to the user, not to Codex

**Process:**
1. Run `git status` to see all changes
2. Run `git diff` to review the changes
3. Review recent commits with `git log --oneline -5` to match the style
4. Analyze the changes and draft a concise commit message (1-2 sentences)
5. Stage all changes with `git add .`
6. Commit with the message (no attribution footers)
7. Run `git status` to verify success

The commit message should be descriptive and explain the purpose of the changes, not just list what files changed.
