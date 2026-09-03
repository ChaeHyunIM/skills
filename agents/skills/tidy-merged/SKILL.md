---
name: tidy-merged
description: Removes merged agent/issue-* worktrees and local branches only after proving the PR is merged, the local HEAD matches GitHub's recorded head SHA, and no local changes, untracked files, stashes, active Claude session, or active Codex task remain. Use only when the user explicitly invokes `$tidy-merged` in Codex or `/tidy-merged` in Claude Code.
---

# tidy-merged

Run the bundled cleanup script from anywhere inside the repository (it locates the main checkout
itself, even from within a worktree):

```bash
bash ~/.agents/skills/tidy-merged/scripts/tidy-merged-worktrees.sh
```

The script owns the deletion judgment. Do not reproduce or weaken its gates.

- List removed branches.
- Group skipped items by reason. An OPEN or missing PR is a normal skip and should not be emphasized.
- If the script lists orphaned Claude sessions, copy their names and pids exactly and explain that
  they can be removed in Claude Code with `ctrl+x` twice. The script never deletes sessions or
  Codex tasks.
- If nothing was removed, report that in one line without extra investigation or suggestions.

Use `--dry-run` for a preview. Use `--report` only when the user asks to inspect the cleanup
judgment. Pass `--repo <path>` only when running outside the target repository.
