---
name: land
description: Merges the tickets the human names, treating the arguments or confirmed queue selection as the merge signature. Syncs, verifies, and merges each PR in order and reports in Korean. Use only when the user explicitly invokes `$land` in Codex or `/land` in Claude Code. Never merges an unconfirmed ticket or resolves an intent collision.
---

# land

Merge the tickets the human names, in one run: order, sync, resolve, verify, merge, report.

**Read `~/.agents/skills/agent-loop/CONTRACT.md` before starting** — states, the tracker adapter,
worktrees and the output convention live there and are not repeated here. Resolve `$TRACKER` per
CONTRACT's [Tracker adapter] before the first tracker call.

**Read `~/.agents/skills/agent-loop/references/acceptance-criteria.md`** for the shared PR evidence,
remaining-condition approval, checkbox-write and post-merge comment rules.

| | |
|---|---|
| Queue membership | the tickets the human named as arguments, or picked from the `awaiting-review` queue in [1] |
| State transition | `awaiting-review` → ticket completed by the merge · valve: → `blocked` |
| Deliverable | merged PRs, issue checkboxes, resolution comments where needed, PR + issue records for accepted remaining conditions, one chat report |
| Never | merge a ticket the human did not name or confirm this run · resolve an intent collision · `--force` |

This skill is human-fired only, so **the invocation itself is the merge
signature**: the arguments — or the pick made in [3] — are the human's judgment, and this skill
only executes it. [3] asks once about surprises and remaining 완료 조건 not already explicitly accepted — never to
re-collect the judgment for unaffected items. That is what makes `land` the sanctioned exception to CONTRACT's
"never merge": it merges nothing the human has not named or picked in this very run.

## Progress checklist

Copy this into your response and check items off as you go.

```
Drain progress:
- [ ] 1  Collect queue, PR/worktree, fresh 완료 조건 and the verification record's state
- [ ] 2  Order the queue
- [ ] 3  Present plan + remaining conditions; confirm exceptions once for the whole queue
- [ ] 4  Drain: align → sync → resolve → typecheck → write issue checks → merge → record accepted gaps
- [ ] 5  Report remaining conditions first, with PR and issue record links
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
- Read `"$TRACKER" criteria <N>` and the PR body's `## 완료 조건 검증`. Read round comments when
  present; a review round is not a prerequisite. A changed condition, or an item the record lacks, is
  미검증, not an inferred pass. Prepare the per-item results for [3] using the shared reference.
- Pin `REVIEWED_HEAD` from the newest round comment — the sha after `..` in its 반영 compare link
  (`.../compare/<ROUND_BASE>..<ROUND_HEAD>`). `### 반영 — 커밋 없음` means the round applied nothing, so
  its `ROUND_BASE` — the sha on the 검증 줄 (`리뷰 기준: Claude <ROUND_BASE>`) — is the reviewed head. No
  round comment, or a sha that does not resolve in the worktree, leaves `REVIEWED_HEAD` unset.
- Pin `REPO` and each ticket's worktree. A missing worktree (e.g. eaten by a nested `claude -p`)
  is recreated with `prepare-worktree.sh <N> <slug>` (no base argument — rework mode).
- **Verification record.** `bash ~/.agents/skills/verify/scripts/verified-head.sh <PR> <worktree>` —
  `current <sha>` (exit 0), `stale <sha> <n>` (1) or `missing` (2). Keep the line for [3]; anything but
  `current` is a surprise there, not a refusal — the human reads «3 커밋 전 증거» and decides, the same
  judgment they already make about a remaining 미검증 condition. Merge commits alone (a base sync) keep a
  record current; the script counts them that way.
- Empty queue → report that and **stop**.

## 2. Order the queue

Queue-listing order. Every merge invalidates the remaining queue's bases — that is not a defect
of the order, it is why [4] re-syncs per item.

## 3. Present the plan — ask only on surprise

Show a Korean table: 순서 · PR · 이슈 · base · `mergeStateStatus` · 예상 충돌 여부 · 리뷰 후
head 변동 · 검증 기록(`검증 대상` sha) · 완료 조건(충족/미충족/미검증 counts), plus any refused items with
their reasons.
List each remaining condition with its actual result or verification obstacle. Include anticipated
uncertainty from base sync/conflict resolution so it is visible before the one confirmation.

The arguments are already the signature for normal landing. A **surprise** is any of: an argument
ticket refused in [1] · a predicted conflict · **unreviewed** work on the PR head · a verification record
that is not `current` · remaining 미충족/미검증 conditions not already explicitly accepted. Without a round,
use the PR verification record as the baseline; do not manufacture a missing-review blocker.

**A `stale` or `missing` record joins [3]'s single question, with `verify <N>` named as the fix.** Say
what it means in one line — a `stale` record's 충족 items describe code from `<n>` commits ago, a `missing`
one means nothing was verified — and let the answer decide. It is not a separate question and never a
second one.

**A review round's own commits are reviewed work, never a surprise.** The round applied the findings,
ran `comment-cleaner`, typechecked, committed and pushed them itself, and its comment reports every one
of them — asking the human to review them again asks for a signature they already gave by reading that
comment. They land with the rest of the queue, silently. The same holds for the base-sync merge the
round makes before posting. So measure the head against `REVIEWED_HEAD`, not against comment dates:

```bash
git -C <worktree> fetch -p origin
git -C <worktree> log --oneline --no-merges $REVIEWED_HEAD..origin/<branch>
```

Empty → the head carries nothing beyond the round; 리뷰 후 head 변동 is 없음. Non-empty → those commits
are the surprise, and the table names them. A merge commit alone (a base sync someone ran by hand) is
not a surprise. `REVIEWED_HEAD` unset → fall back to comparing commit and comment dates through
`gh pr view <PR> --json commits,comments`.

- **Argument mode, no surprises**: print the table and proceed without asking.
- **Argument mode, surprises**: name only the surprising items and ask once whether to include
  them — the rest of the queue is not re-confirmed. Combine all remaining conditions into this same
  question ("이 항목들이 남아 있는데도 병합할까요?"). Record which exceptions the answer accepts.
  Accepting a merge never means accepting a checkbox as 충족.
- **No-argument mode**: show the same remaining conditions with the queue and ask **which tickets to
  land despite those listed gaps**. The answer is the merge signature and the informed exception approval.
  Landing "all of them" is valid only when given, never assumed.

**At most one question per run, here.** After [3], the intent-collision valve still bounces to `blocked`.
A new remaining condition outside the approved exception scope leaves the item unmerged and is reported
without a second question; missing verification alone does not invoke the intent-collision valve.
Continue independent items. The human can decide about that newly reported scope in the next run.

## 4. Drain — per item, in order

**a. Align.** The worktree holds no unpushed work by loop invariant — hard-align it to the
remote before anything else:

```bash
git -C <worktree> fetch -p origin
git -C <worktree> reset --hard origin/<branch>
BASE=$(gh pr view <PR> --json baseRefName -q .baseRefName)   # read fresh: an earlier merge may have moved it
```

**b. Sync with the base.** `git merge origin/$BASE`, then a plain `git push` — an unpushed
sync commit leaves the merged remote SHA behind the local HEAD, so what GitHub merges is not
what the worktree holds.

**c. Conflicts →** [Resolve] below.

**d. Verify.** `pnpm check-types:<app>` must be green **before** the merge, on the synced tree.
A break caused by the resolution is fixed within union-of-intents bounds; a break that needs
new behaviour to fix is an intent collision — pull the valve.

**e. Synchronize issue checkboxes, then merge.**

Do not rerun the feature checks and do not edit the record. [4b]'s sync adds merge commits only, so a
record that was `current` in [1] still is; one the human accepted as `stale` stays exactly as stale as it
was when they accepted it. A conflict resolution from [Resolve] is the one thing that changes code here —
name the conditions its files touch in the resolution comment, and declare no overlapping file a failure
by itself.

Re-read conditions via `criteria` and build a complete checks file: `checked` is true only for an evidenced
충족 **on a `current` record**, false for 미충족, 미검증, and every item on a record the human accepted as
`stale` — that 충족 describes earlier code, and approving the merge never turned it into a pass. A changed
issue must be reassessed, not blindly mapped by old indices. Immediately before merging:

```bash
"$TRACKER" criteria <N> > <scratchpad>/criteria-<N>.json
"$TRACKER" check <N> <scratchpad>/criteria-<N>.json <scratchpad>/checks-<N>.json
```

Read the verified result before merging. Write/read-back failure → leave this PR unmerged and report it;
do not bypass the adapter. If an explicitly accepted legacy ticket has no conditions, report that gap
and skip the empty write; never invent checks. Checks remain facts if the following merge fails.

```bash
gh pr merge <PR> --rebase   # the trunk is rebase-merge only
```

**f. Confirm the landing** before moving on:

```bash
"$TRACKER" landed <N>   # verifies the tracker recorded completion; closes only if automation missed
```

If remaining conditions were explicitly accepted and the merge succeeded, post the records required by
the shared reference: technical condition/status/evidence/approval on the PR and brief natural Korean
on the issue. Use body files and no teammate mentions:

```bash
gh pr comment <PR> --body-file <scratchpad>/land-remaining-<N>-pr.md
"$TRACKER" comment <N> <scratchpad>/land-remaining-<N>-issue.md
```

Keep the existing resolution comment when applicable. Do not auto-create follow-up tickets. A comment
failure is a missing record to report/retry, not a failed merge to repeat.

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

## 5. Report

Lead with any conditions left 미충족/미검증 in approved merges, their reasons, and both PR and issue
comment links. Include failed checkbox writes or missing post-merge records prominently. Then report
in drain order — one line per item: 머지됨 / 보류(사유) / 반송(밸브, PR 코멘트 링크). Conflicted items
link their resolution comment. Close with the queue's end state; a
non-empty remainder is the headline, not a footnote.

Worktrees are left in place. This run's sessions are still open on them, so cleanup belongs to
a separate `tidy-merged` after the human closes those sessions — not to the tail of this run.

## Guardrails

In addition to CONTRACT's [Never]:

- **Never merge a ticket the human did not name or confirm in this run** — and never carry a
  signature over from a previous run: each run collects its own.
- **Never resolve an intent collision.** The valve is not optional.
- **Never merge past a non-`current` verification record without [3]'s question**, and never rewrite a
  record to make it look current — `verify <N>` is its only writer.
- **Never reorder the queue after presenting the plan** without re-presenting it.
- **Never silently merge a surprise** — a refused ticket, a predicted conflict, or an unreviewed
  commit on the head always passes through [3]'s question first. A review round's own commits are
  reviewed, so they are not that: never hold the queue for them.
- The only push is [4b]'s sync push, on this item's own branch.
