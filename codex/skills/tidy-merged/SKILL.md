---
name: tidy-merged
description: Removes merged agent/issue-* worktrees and local branches only after proving the PR is merged, the local HEAD matches GitHub's recorded head SHA, and no local changes, untracked files, stashes, or active shared-worktree session remain. Use only when the user explicitly invokes `$tidy-merged` or when `$land` reaches its cleanup step.
---

# tidy-merged

Run the bundled cleanup script from the repository root:

```bash
bash ~/.codex/skills/tidy-merged/scripts/tidy-merged-worktrees.sh --repo "$(git rev-parse --show-toplevel)"
```

The script owns the deletion judgment. Do not reproduce or weaken its gates.

- List removed branches.
- Group skipped items by reason. An OPEN or missing PR is a normal skip and should not be emphasized.
- If the script lists orphaned Claude sessions, copy their names and pids exactly and explain that they can be removed in Claude Code with `ctrl+x` twice. The script never deletes sessions or Codex tasks.
- If nothing was removed, report that in one line without extra investigation or suggestions.

Use `--dry-run` for a preview. Use `--report` only when the user asks to inspect the cleanup judgment.
