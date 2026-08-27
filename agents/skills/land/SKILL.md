---
name: land
description: Merges the tickets the human names, treating the arguments or confirmed queue selection as the merge signature. Syncs, verifies, and merges each PR in order and reports in Korean. Use only when the user explicitly invokes `$land` in Codex or `/land` in Claude Code. Never merges an unconfirmed ticket or resolves an intent collision.
---

# land

Merge the tickets the human names, in one run: order, sync, resolve, verify, merge, report.

**Read `~/.agents/skills/agent-loop/CONTRACT.md` before starting** — states, the tracker adapter,
worktrees and the output convention live there and are not repeated here. Resolve `$TRACKER` per
CONTRACT's [Tracker adapter] before the first tracker call.

| | |
|---|---|
| Queue membership | the tickets the human named as arguments, or picked from the `awaiting-review` queue in [1] |
| State transition | `awaiting-review` → ticket completed by the merge · valve: → `blocked` |
| Deliverable | merged PRs, a resolution comment on each conflicted PR, tidied worktrees, one chat report |
| Never | merge a ticket the human did not name or confirm this run · resolve an intent collision · `--force` |

This skill is human-fired only, so **the invocation itself is the merge
signature**: the arguments — or the pick made in [3] — are the human's judgment, and this skill
only executes it. [3] asks a question only about information born after the signature — never to
re-collect the judgment itself. That is what makes `land` the sanctioned exception to CONTRACT's
"never merge": it merges nothing the human has not named or picked in this very run.

## Progress checklist

Copy this into your response and check items off as you go.

```
Drain progress:
- [ ] 1  Collect the queue, pin each PR and worktree
- [ ] 2  Order the queue
- [ ] 3  Present the plan, ask only on surprise
- [ ] 4  Drain item by item: align → sync → resolve → verify → merge
- [ ] 5  Tidy merged worktrees — `tidy-merged`
- [ ] 6  Report
```

## 1. Collect the queue

- **With arguments**: the argument tickets are the queue — the human just signed them by typing the
  command. Verify each sits at `awaiting-review` (`"$TRACKER" show <N>`); any other state is refused
  with its reason and dropped from the queue: `in-review` = a round is still writing the branch,
  `blocked` = a decision is pending (route it through `implement <N>` first), `in-progress` = not
  review-complete.
- **No arguments**: list the candidates with `"$TRACKER" list awaiting-review` and carry them into
  [3], where the human picks — that pick is the signature. Nothing is merged that the human does not
  name there.
- Resolve each ticket's PR with `"$TRACKER" pr-for <N>`.
- Pin `REPO` and each ticket's worktree. A missing worktree (e.g. eaten by a nested `claude -p`)
  is recreated with `prepare-worktree.sh <N> <slug>` (no base argument — rework mode).
- Empty queue → report that and **stop**.

## 2. Order the queue

Queue-listing order. Every merge invalidates the remaining queue's bases — that is not a defect
of the order, it is why [4] re-syncs per item.

## 3. Present the plan — ask only on surprise

Show a Korean table: 순서 · PR · 이슈 · base · `mergeStateStatus` · 예상 충돌 여부 · 리뷰 후
head 변동, plus any refused items with their reasons.

The arguments are already the signature, so a second "proceed?" would collect the same judgment
twice. What the signature cannot cover is information born after it — only that warrants a
question. A **surprise** is any of: an argument ticket refused in [1] · a predicted conflict ·
a PR head that moved after its newest round comment (compare the head commit's `committedDate`
with the newest round comment's `createdAt`, via `gh pr view <PR> --json commits,comments`).

- **Argument mode, no surprises**: print the table and proceed without asking.
- **Argument mode, surprises**: name only the surprising items and ask once whether to include
  them — the rest of the queue is not re-confirmed.
- **No-argument mode**: ask **which tickets to land** — the answer is the merge signature. Landing
  "all of them" is a valid answer, but it must be given, never assumed.

**At most one question per run, here.** After [3] there are no further questions — the valve in
[Resolve] does not ask, it bounces to `blocked` and moves on.

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

**f. Confirm the landing** before moving on:

```bash
"$TRACKER" landed <N>   # verifies the tracker recorded completion; closes only if automation missed
```

## Resolve — the conflict discipline

Both sides of every conflict here are **human-approved code**. Resolution is therefore
assembly, not judgment: the goal is the union of both intents.

**Primary sources first — you cannot preserve an intent you have not read.** Before touching a
hunk, read both sides' documentation: this PR's issue body (`## 목표`) and round comments, and
the same for the trunk side — its recent commits trace to queue items merged minutes ago, whose
tickets are one `"$TRACKER" show` away. Resolve between two intents, never between two blocks of
text.

- **Never `--ours` / `--theirs`.** A wholesale pick silently discards an approved intent, and
  the discard is invisible in the diff.
- **Never write a line that was on neither side.** Inventing behaviour to make a conflict go
  away is not assembly.
- **Migration journal collisions are mechanical**: renumber this side's migration to follow the
  landed journal, in both filename and journal entry.
- **Record every dropped line** — it goes in the resolution comment.
- **Completing a resolution bypasses the commit path** (CONTRACT sanctions exactly this):
  `git commit --no-edit`. `comment-cleaner` and `commit` are for authored changes; a
  resolution authors nothing.
- **Post a resolution comment on the PR** after [4d] passes: what was woven from each side and
  every dropped line, all as `path:line`, in Korean. The reasoning otherwise dies with this
  session.

### The valve — intent collisions

When the two sides change the **same behaviour incompatibly** — no union exists and any
resolution silently discards one approved intent — the choice exceeds the signature's delegation:
the human signed both PRs without knowing they contradict.

```bash
git -C <worktree> merge --abort    # leave the tree clean
"$TRACKER" transition <N> blocked
gh pr comment <PR> --body-file <scratchpad>/land-valve-<N>.md   # both intents, both sources
```

Skip everything queued above this PR, continue with independent items. The valve is a report,
not a question — the decision comes back as the human's next instruction.

## 5. Tidy merged worktrees

After the last item lands, invoke the `tidy-merged` skill. Its script deletes a worktree only
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

- **Never merge a ticket the human did not name or confirm in this run** — and never carry a
  signature over from a previous run: each run collects its own.
- **Never resolve an intent collision.** The valve is not optional.
- **Never reorder the queue after presenting the plan** without re-presenting it.
- **Never silently merge a surprise** — a refused ticket, a predicted conflict, or a head that
  moved after review always passes through [3]'s question first.
- The only push is [4b]'s sync push, on this item's own branch.
