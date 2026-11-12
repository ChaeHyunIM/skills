---
name: reorg-commits
description: >
  Reorganize messy git commits into cohesive, well-grouped commits by concern or feature.
  Takes a start and end commit hash, analyzes all changes, groups files by concern,
  and re-commits in a clean order inside an isolated worktree.
  Use when asked to reorganize or restructure a linear range of commits by concern.
---

# Reorg Commits

Reorganize a range of commits into cohesive groups by concern.

**Input**: `<start-hash> <end-hash>` (arguments or from user prompt)

## Workflow

### 1. Validate

```bash
git cat-file -t <start> && git cat-file -t <end>
git merge-base --is-ancestor <start> <end>
git log --merges --oneline <start>^..<end>
```

- Confirm both hashes exist.
- Confirm `<start>` is an ancestor of `<end>`. If not → **abort**: "start가 end의 ancestor가 아닙니다. 해시 순서를 확인해주세요."
- If merge commits detected → **abort**: "커밋 범위에 merge commit이 포함되어 있습니다. 선형 이력만 지원합니다."

### 2. Create Worktree

Create a raw git worktree without switching or modifying the user's current checkout:

```bash
REORG_BRANCH="reorg/$(git branch --show-current)-$(date +%Y%m%d%H%M%S)"
WORKTREE_DIR=".claude/worktrees/${REORG_BRANCH//\//-}"
git worktree add "$WORKTREE_DIR" -b "$REORG_BRANCH" <start>^
```

All subsequent git operations use `-C "$WORKTREE_DIR"`.

### 3. Analyze (Parallel Subagents)

Spawn exactly two read-only subagents in parallel using the host runtime's native subagent mechanism, then wait for both results:

**Agent A — File Change Map**: Run `git diff --name-status <start>^..<end>` and `git log --oneline --name-only <start>^..<end>`. Build `{ file -> changeType, touchedInCommits[] }`.

**Agent B — Concern Grouping**: Read the file list from the diff, classify each file into a concern group following `references/algorithm.md`. Produce a proposed grouping:

```
Group 1: feat(db): <설명>
  - packages/db/src/schema/foo.ts (M)
  - packages/db/src/schema/bar.ts (A)

Group 2: feat(web): <설명>
  - apps/web/src/components/Foo.tsx (M)
  - apps/web/src/app/bar/page.tsx (A)
```

### 4. Present & Confirm

Show the proposed grouping to the user through the host runtime's normal user-interaction mechanism, ask for confirmation, and stop until they answer. Include:
- Group name (conventional commit style, Korean)
- Files in each group with change type
- Commit order (bottom-up by dependency)

User may approve or abort. To change grouping, abort and re-invoke with hints.

### 5. Re-commit

In the worktree, apply the end state and re-commit by group:

```bash
# Apply end state (handles additions, modifications, AND deletions correctly)
git -C "$WORKTREE_DIR" read-tree -m -u <start>^ <end>
git -C "$WORKTREE_DIR" reset HEAD
```

Then for each group in order:

```bash
# For added/modified files:
git -C "$WORKTREE_DIR" add <files-in-group>
# For deleted files:
git -C "$WORKTREE_DIR" rm <deleted-files-in-group>
# Commit:
git -C "$WORKTREE_DIR" commit -m "<conventional commit message in Korean>"
```

Follow the installed `commit` skill's message conventions when available. Otherwise use Korean Conventional Commits.

### 6. Verify (Hard Gate)

```bash
git diff <new-HEAD-in-worktree> <end>
```

**MUST be empty.** If any diff exists → abort, report the discrepancy, do NOT clean up the worktree (preserve for debugging).

### 7. Report

Output:
- Branch name
- Worktree path
- New commit log (`git log --oneline`)
- Instructions:

```bash
# 재정립된 브랜치 확인
git log --oneline $REORG_BRANCH

# 현재 작업 위로 올리기 (새 작업이 end commit 이후에 있는 경우)
git rebase --onto $REORG_BRANCH <end> HEAD

# worktree 정리
git worktree remove "$WORKTREE_DIR"
```

## Constraints

- **File-level grouping only** (v1). One file belongs to one group.
- **No merge commits** in range. Reject and inform.
- **Ancestry required**: start must be ancestor of end.
- **Tree integrity**: final tree MUST match original end commit exactly.
- **Keep the current checkout unchanged**: use raw `git worktree add` for the isolated rewrite.
- **Commit messages**: Korean, Conventional Commits format.

## Grouping Reference

See [references/algorithm.md](references/algorithm.md) for classification heuristics, merge rules, ordering, and edge cases.
