---
name: land
description: Drains the merge queue — every issue labelled agent-merge-ready — by merging its PRs in queue order, resolving conflicts as an assembly of both sides' documented intents, verifying each item with the app typecheck before it lands, and posting one Korean drain report. The label is the human's merge signature and /land is the loop's only sanctioned merge path. Use when the user invokes `/land` (whole queue) or `/land <issue-numbers...>` (a subset). Never merges an unlabelled PR and never resolves an intent collision.
disable-model-invocation: true
argument-hint: [issue-numbers...] (omit to drain every agent-merge-ready issue)
---

# land

Drain the **merge queue** — the set of open issues carrying `agent-merge-ready` — in one run:
order, sync, resolve, verify, merge, report.

**Read `~/.claude/skills/agent-loop/CONTRACT.md` before starting** — labels, worktrees and the output
convention live there and are not repeated here.

| | |
|---|---|
| Queue membership | an open issue labelled `agent-merge-ready` — the human's merge signature |
| Label transition | `agent-merge-ready` → issue closed by the merge · valve: → `agent-blocked` |
| Deliverable | merged PRs, a resolution comment on each conflicted PR, tidied worktrees, one chat report |
| Never | merge without the label · resolve an intent collision · `--force` |

The judgment is the human's and it has already happened — attaching the label **is** the merge
decision. This skill only executes it. That is what makes `/land` the sanctioned exception to
CONTRACT's "never merge": it merges nothing the human has not individually signed.

## Progress checklist

Copy this into your response and check items off as you go.

```
Drain progress:
- [ ] 1  Collect the queue, pin each PR and worktree
- [ ] 2  Order the queue
- [ ] 3  Present the plan, get one confirmation
- [ ] 4  Drain item by item: align → sync → resolve → verify → merge
- [ ] 5  Tidy merged worktrees — /tidy-merged
- [ ] 6  Report
```

## 1. Collect the queue

```bash
gh issue list --label agent-merge-ready --state open --json number,title
```

- **With arguments**: the queue is the intersection. An argument issue **without** the label is
  refused and reported — arguments narrow the queue, they never override the signature.
- Resolve each issue's PR as `review-round` [1] does (`--search "Closes #<N>"`, with the
  search-lag fallback of matching `agent/issue-<N>-*` in the full PR list).
- Pin `REPO` and each issue's worktree. A missing worktree (e.g. eaten by a nested `claude -p`)
  is recreated with `prepare-worktree.sh <N> <slug>` (no base argument — rework mode).
- Empty queue → report that and **stop**.

## 2. Order the queue

Queue-listing order. Every merge invalidates the remaining queue's bases — that is not a defect
of the order, it is why [4] re-syncs per item.

## 3. Present the plan — one confirmation

Show a Korean table: 순서 · PR · 이슈 · base · `mergeStateStatus` · 예상 충돌 여부, plus any
refused (unlabelled-argument) items. Ask once whether to proceed.

**This is the run's single human input.** After confirmation there are no further questions —
the valve in [Resolve] does not ask, it bounces to `agent-blocked` and moves on.

## 4. Drain — per item, in order

**a. Align.** The worktree holds no unpushed work by loop invariant — hard-align it to the
remote before anything else:

```bash
git -C <worktree> fetch -p origin
git -C <worktree> reset --hard origin/<branch>
BASE=$(gh pr view <PR> --json baseRefName -q .baseRefName)   # read fresh: an earlier merge may have moved it
```

**b. Sync with the base.** `git merge origin/$BASE`, then a plain `git push` — an unpushed
sync commit leaves the merged remote SHA behind the local HEAD, and [5]'s tidy pass then
cannot prove the worktree is safe to delete.

**c. Conflicts →** [Resolve] below.

**d. Verify.** `pnpm check-types:<app>` must be green **before** the merge, on the synced tree.
A break caused by the resolution is fixed within union-of-intents bounds; a break that needs
new behaviour to fix is an intent collision — pull the valve.

**e. Merge.**

```bash
gh pr merge <PR> --rebase   # the trunk is rebase-merge only
```

**f. Confirm the landing** (PR merged, issue closed by `Closes #N`) before moving on.

## Resolve — the conflict discipline

Both sides of every conflict here are **human-approved code**. Resolution is therefore
assembly, not judgment: the goal is the union of both intents.

**Primary sources first — you cannot preserve an intent you have not read.** Before touching a
hunk, read both sides' documentation: this PR's issue body (`## 목표`) and round comments, and
the same for the trunk side — its recent commits trace to queue items merged minutes ago, whose
issues are one `gh issue view` away. Resolve between two intents, never between two blocks of
text.

- **Never `--ours` / `--theirs`.** A wholesale pick silently discards an approved intent, and
  the discard is invisible in the diff.
- **Never write a line that was on neither side.** Inventing behaviour to make a conflict go
  away is not assembly.
- **Migration journal collisions are mechanical**: renumber this side's migration to follow the
  landed journal, in both filename and journal entry.
- **Record every dropped line** — it goes in the resolution comment.
- **Completing a resolution bypasses the commit path** (CONTRACT sanctions exactly this):
  `git commit --no-edit`. `/comment-cleaner` and `/commit` are for authored changes; a
  resolution authors nothing.
- **Post a resolution comment on the PR** after [4d] passes: what was woven from each side and
  every dropped line, all as `path:line`, in Korean. The reasoning otherwise dies with this
  session.

### The valve — intent collisions

When the two sides change the **same behaviour incompatibly** — no union exists and any
resolution silently discards one approved intent — the choice exceeds the label's delegation:
the human signed both PRs without knowing they contradict.

```bash
git -C <worktree> merge --abort    # leave the tree clean
gh issue edit <N> --remove-label agent-merge-ready --add-label agent-blocked
gh pr comment <PR> --body-file <scratchpad>/land-valve-<N>.md   # both intents, both sources
```

Skip everything queued above this PR, continue with independent items. The valve is a report,
not a question — the decision comes back as the human's next instruction.

## 5. Tidy merged worktrees

After the last item lands, invoke the `/tidy-merged` skill. Its script deletes a worktree only
when the PR is `MERGED` **and** the local HEAD equals the SHA GitHub recorded at merge — so
bounced (valve) and held items, whose PRs are still OPEN, survive untouched, and nothing needs
guarding here. Sessions are never deleted; the script only names the orphaned ones.

This is why CONTRACT's "keep the worktree until the PR merges" ends here: the merge just
happened, and the tidy pass is its cleanup.

## 6. Report

Chat, Korean, in drain order — one line per item: 머지됨 / 보류(사유) / 반송(밸브, PR 코멘트
링크). Conflicted items link their resolution comment. Then the tidy summary (정리된 브랜치,
남은 세션). Close with the queue's end state; a non-empty remainder is the headline, not a
footnote.

## Guardrails

In addition to CONTRACT's [Never]:

- **Never merge a PR whose issue lacks `agent-merge-ready`** — arguments never override the
  signature.
- **Never resolve an intent collision.** The valve is not optional.
- **Never reorder the plan after confirmation** without re-presenting it.
- The only push is [4b]'s sync push, on this item's own branch.

## TODO — 다른 런타임 대응

이 스킬은 `/tidy-merged` 스킬 호출과 `.claude/worktrees/` 워크트리 규약에 의존해서
`~/.claude/skills/` 에 있다. Codex 등에서 어떻게 대체할지 미정.
