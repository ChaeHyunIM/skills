---
name: implement
description: Implements a GitHub issue in an isolated git worktree and opens a review-ready PR in Korean, then stops so the human can fire /review-round or continue with another review process. Handles a fresh start and rework on an existing agent/issue-* branch. Use when the user invokes `/implement <issue-number>`, or bare `/implement` to scan ready-for-agent issues and propose one before starting. Never reviews and never merges.
disable-model-invocation: true
argument-hint: [issue-number] (omit to scan ready-for-agent issues and propose)
---

# implement

Implement one issue in an isolated worktree, open a **review-ready PR**, and stop at
`agent-awaiting-review`. Review is fired separately by the human via `/review-round <N>` or another review process.

**Read `~/.claude/skills/agent-loop/CONTRACT.md` before starting** — labels, worktrees and the output
convention live there and are not repeated here.

| | |
|---|---|
| Label transition | `ready-for-agent` → `agent-in-progress` → `agent-awaiting-review` |
| Deliverable | one non-draft PR |
| Never | review · merge · push to the base branch · set `agent-merge-ready` |

## Entry modes

- **`/implement <N>`** → run [Execution] directly.
- **`/implement` (no argument)** → run [Discover & propose] first, then **ask the user and stop**.
  Change nothing before the user confirms — no labels, no worktree.

## Progress checklist

Copy this into your response and check items off as you go.

```
Implementation progress:
- [ ] 1  Load issue, detect fresh vs rework
- [ ] 2  Blocker gate (fresh only)
- [ ] 3  Claim the label
- [ ] 4  Resolve the base
- [ ] 5  Prepare the worktree
- [ ] 6  Implement (fetch the Figma node first if the issue has a design)
- [ ] 7  Typecheck gate — repeat until green
- [ ] 8  comment-cleaner → commit → verify base both ways → push → PR
- [ ] 9  Land the label and stop
```

## Discover & propose (no-argument mode)

1. Collect candidates, and separately the subset GitHub considers startable:
   ```bash
   gh issue list --label ready-for-agent --state open --json number,title,body,labels,updatedAt
   gh issue list --label ready-for-agent --state open --search "-is:blocked" --json number
   ```
   Also surface resumable ones: `agent-blocked` (bounced back), `agent-awaiting-review` /
   `agent-in-progress` (in flight).

   `-is:blocked` reads only the native edges, never the body prose, so a ticket missing an edge shows up
   as startable when it is not. Treat that list as an ordering hint, not a verdict — [3] checks for real.
2. No candidates → report that and **stop**.
3. For each candidate, check its blockers' real state as in [2] and present briefly: number and title,
   a summary of the body (the goal), which app under `apps/` it targets, blocker status, and a
   one-line implementation plan. Candidates with an open blocker are listed as **not fireable yet** and
   excluded from the recommendation — list them, never drop them: they become fireable minutes after
   their blocker is signed and landed.
   If dependencies or priority are visible, mark **one recommendation**.

   A candidate whose body names a blocker its native edges lack has a broken listing: register the missing
   edge before moving on — CONTRACT's [Blocking edges].
4. **Ask "which issue, and in what direction?" and wait. Stop here.**
5. Once confirmed, run [Execution] for that `<N>`.

## 1. Load the issue, detect the mode

```bash
gh issue view <N> --json number,title,body,labels,state
git branch --list "agent/issue-<N>-*"
```

No branch → **fresh start**. Branch exists → **rework** (continue on it, applying this turn's extra
instructions).

## 2. Blocker gate (fresh only)

If the issue body's `## Blocked by` names other tickets, check each blocker's **actual state — never its
labels**. Labels are human-edited and lag. The truth is the issue's state plus its PR:

```bash
gh issue view <blocker> --json state
gh pr list --search "Closes #<blocker>" --state merged
```

A green typecheck against a base that lacks the blocker's work proves nothing (see evidence.md).

- **Every blocker closed with its PR merged** → proceed.
- **Any blocker still open** → **stop before [3]**. Report which blockers are open and change nothing
  (no labels, no worktree). If a blocker sits at `agent-awaiting-review` and the human is satisfied with
  it, the fast path is minutes long: sign it (`agent-merge-ready`), `/land` it, then re-run
  `/implement <N>`.

## 3. Claim the label (immediately)

```bash
gh issue edit <N> --remove-label ready-for-agent --remove-label agent-awaiting-review --add-label agent-in-progress
```

Removing a non-existent label is harmless, so this one line covers both fresh and rework.

## 4. Resolve the base (fresh only)

The base is **whatever branch the user is working on**, not a fixed name. Issues in a feature line (e.g.
v2.2.0) build on each other, so branching off `main` would start from a tree missing the previous issue's
work.

Resolution order: an explicit `--base <branch>` argument → the current branch.

```bash
git rev-parse --abbrev-ref HEAD      # in the main checkout
```

Use the **local** branch, not `origin/<branch>` — the user's unpushed commits are usually exactly the
prerequisite this issue builds on.

Stop and ask when:

- HEAD is detached (the command returns `HEAD`),
- the resolved base is an `agent/issue-*` branch — the loop never builds one agent branch on top of
  another. Wait for the blocker to land instead.

Warn but do not stop when the main checkout has uncommitted changes: the worktree branches from the HEAD
commit, so those changes will not come along.

Carry the resolved base through to [8] and record it in the PR body.

## 5. Prepare the worktree

```bash
bash ~/.claude/skills/implement/scripts/prepare-worktree.sh <N> <slug> [<base>]   # omit base for rework
```

`slug` is the kebab-case issue title. The script handles worktree creation, `pnpm install` and the
routeTree copy.

## 6. Implement

- **The issue body is the goal.** There is no separate goal command.
- **Design-backed UI**: if the issue has a design section with Figma node links, fetch the node with
  `mcp__claude_ai_Figma__get_design_context` (and `mcp__claude_ai_Figma__get_screenshot` for visuals)
  **before writing any UI code**. The node is the design source of truth — on any visual or UX question
  **the node beats the issue text**; the issue's "Figma가 답하지 않는 것" list covers only what the node
  does not show. If the Figma MCP is unavailable or the node cannot be fetched, treat it as stuck
  ([When stuck]) rather than improvising the UI from the issue prose.
- Follow the project rules in CLAUDE.md (absolute-path imports, file naming, minimal Korean comments).
- **Skip tests by default.** Write them only when the issue explicitly asks.

## 7. Typecheck gate

Fix and repeat until `pnpm check-types:<app>` passes. Never call `tsc` directly.

## 8. Commit and PR

Follow CONTRACT's commit path: `/comment-cleaner` (no argument) → `/commit` → push.

Before pushing, verify the base in **both directions**.

**Is the base ahead of its remote?** GitHub diffs the PR against the *remote* base, so if `origin/<base>`
is missing or the count is non-zero, the user's unpushed base commits appear inside this PR's diff:

```bash
git rev-list --count origin/<base>..<base>
```

Non-zero → stop and ask the user to push the base first. Pushing someone else's working branch is not
this skill's call.

**Did the base move while you were implementing?** The user may have kept committing to it:

```bash
git fetch origin
git merge-base --is-ancestor origin/<base> HEAD || echo "base moved — needs catching up"
```

If it moved, catch up with `git merge origin/<base>` **before pushing**, then **re-run the typecheck
gate**.

```bash
git push -u origin agent/issue-<N>-<slug>
gh pr create --base <base> --title "<제목>" \
  --body "$(printf 'Closes #%s\n\nbase: %s\n\n<한 줄 요약>' <N> <base>)"
```

**Rework**: the PR already exists, so just push. Do not flip it back to draft — `agent-in-progress`
already says the code is moving.

## 9. Land the label and stop

```bash
gh issue edit <N> --remove-label agent-in-progress --add-label agent-awaiting-review
```

Report the PR link and **stop**. Tell the user: review with `/review-round <N>` or another review process;
for more changes, re-run `/implement <N>` with instructions.

## When stuck

If you cannot proceed on your own (ambiguous requirements, unresolved types, environment issues):

```bash
gh issue edit <N> --remove-label agent-in-progress --add-label agent-blocked
gh issue comment <N> --body "<막힌 지점과 필요한 결정>"
```

Stop and hand off to the human.

## Guardrails

In addition to CONTRACT's [Never]:

- This skill is the sanctioned exception for push + PR, but **only up to opening the PR**.
- The base is dynamic — the user's current branch unless `--base` says otherwise. Never assume `main`.

## TODO — 다른 런타임 대응

이 스킬은 `/comment-cleaner` · `/commit` 스킬 호출과 Claude 쪽 Figma MCP
(`mcp__claude_ai_Figma__*`)에 의존해서 `~/.claude/skills/` 에 있다.
Codex 등에서 어떻게 대체할지 미정.
