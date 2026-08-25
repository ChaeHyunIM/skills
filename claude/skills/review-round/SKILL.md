---
name: review-round
description: Runs one complete code-review round on the PR that /implement opened — fires Anthropic's /code-review in a nested background CLI session, applies or defers each finding, syncs the PR with its base, and posts a single Korean round-summary comment listing every finding as 반영·기각·보류. Use when the user invokes `/review-round <issue-number> [/code-review args...]`. Does not review by itself and never merges; /code-review is the engine and the human decides mergeability.
disable-model-invocation: true
argument-hint: <issue-number> [/code-review args...]
---

# review-round

Runs **one review round** end to end on the PR from `implement` — one human input, no handoff in the middle.

**Read `~/.claude/skills/agent-loop/CONTRACT.md` before starting** — labels, worktrees and the output
convention live there and are not repeated here.

| | |
|---|---|
| Label transition | `agent-awaiting-review` → `agent-in-review` → `agent-awaiting-review` or `agent-blocked` |
| Deliverable | **one** PR comment. The chat report is a pointer, plus the 보류 section verbatim |
| Never | review by itself (the engine is `/code-review`) · judge mergeability · run `ultra` |

## Progress checklist

Copy this into your response and check items off as you go.

```
Round progress:
- [ ] 1  Resolve PR and worktree, pin ROUND_BASE and REPO
- [ ] 2  Claim the label, fix the round number
- [ ] 3  Fire the nested review in the background, arm the monitor, end the turn
- [ ] 4  (on notification) Extract and sanity-check the findings
- [ ] 5  Disposition findings → comment-cleaner → typecheck → commit → push
- [ ] 6  Sync with the base, then typecheck against the merged tree
- [ ] 7  Compute the round range → write the PR comment
- [ ] 8  Land the label and stop
```

## Arguments

- **First argument = issue number `<N>`** (required).
- **Remaining arguments are forwarded to `/code-review`** verbatim, in order.
- **Effort defaults to `medium`.** If the first forwarded argument is not one of
  `low`/`medium`/`high`/`xhigh`/`max`, prepend `medium`. Left off, `/code-review` inherits whatever
  `/effort` is set to, and it reads an unrecognized first token as the **review target path**.
- **`ultra` stops the run.** Tell the user to type `/code-review ultra` themselves, then resume from [4].
- **`--fix` and `--comment` are refused.** Drop them from the forwarded string, say so, and continue —
  they duplicate or contradict work this skill already owns:
  - `--fix` applies findings inside [3], before [5] decides 반영·기각·보류. [5] fixes 반영 itself and
    has to stand behind every applied line anyway (comment-cleaner, typecheck, commit).
  - `--comment` posts inline PR comments. The round's deliverable is **one** comment ([7]).

## 1. Pin the PR, worktree and round range

```bash
gh pr list --search "Closes #<N>" --json number,url,headRefName
```

GitHub's search index lags for minutes after a PR is created. If it returns empty, fall back to
`gh pr list --json number,headRefName` and match `agent/issue-<N>-*`.

```bash
git -C <worktree> pull
ROUND_BASE=$(git -C <worktree> rev-parse HEAD)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

Pin `ROUND_BASE` **right after the pull, before the review runs**. Everything committed from here on is
this round's work and everything below it is not. It is the only thing that makes [7]'s compare link point
at this round alone.

## 2. Claim the label, fix the round number

```bash
gh issue edit <N> --remove-label agent-awaiting-review --add-label agent-in-review
```

Round number `<K>` = the highest existing "리뷰 라운드 K" in `gh pr view <PR> --json comments`, plus 1.
Default 1.

## 3. Fire the nested review — background, never inline

`/code-review` carries `disable-model-invocation`, so the `Skill` tool cannot call it. That flag blocks
only *the model calling itself*, not the CLI — `claude -p` takes the same slash-expansion path as a human
keystroke and really runs the review.

```bash
Bash(run_in_background: true):
  rm -f <scratchpad>/review-<N>-r<K>.done
  cd <worktree> && { CLAUDE_CODE_REPORT_FINDINGS=1 claude -p '/code-review <args>' \
    --output-format stream-json --verbose \
    > <scratchpad>/review-<N>-r<K>.jsonl 2> <scratchpad>/review-<N>-r<K>.err; \
    echo $? > <scratchpad>/review-<N>-r<K>.done; }
```

- `<args>` is the effort-defaulted string from [Arguments], not the caller's raw tail.
- **`run_in_background: true` is mandatory.** A real review can outlast the foreground Bash ceiling, and
  the completion notification is what wakes [4].
- **`--output-format stream-json --verbose` is mandatory too.** Default text mode writes nothing until
  exit, and `CLAUDE_CODE_REPORT_FINDINGS=1` only takes effect under this format.
- Run it **from the worktree** — `/code-review` reviews the working diff of whatever directory it starts in.
- `.done` holds the exit code and is the monitor's stop signal. `rm -f` it first, or a leftover from the
  previous round ends the monitor instantly.

### 3b. Arm the progress monitor

```
Monitor(description: "리뷰 #<N> 라운드 <K> 진행", timeout_ms: 3600000, persistent: false):
  bash ~/.claude/skills/review-round/scripts/monitor.sh <N> <K> \
    <scratchpad>/review-<N>-r<K>.jsonl <scratchpad>/review-<N>-r<K>.done
```

Then **end the turn and wait for the notification.** Do not poll, do not sleep-loop, do not start a
second review.

## 4. Extract and sanity-check the findings

Entered when the background command completes.

```bash
bash ~/.claude/skills/review-round/scripts/extract-findings.sh <scratchpad>/review-<N>-r<K>.jsonl
```

Exit `0` = structured · `2` = prose fallback (report the round as degraded) · `3` = nothing usable.

Structured shape:
`{level, findings:[{file, line, summary, short_summary, failure_scenario, category, verdict?}]}`

- **Array order is the finding number** — `#1` is `findings[0]`.
- `short_summary` (≤60 chars) is the table cell, `file:line` the location, `failure_scenario` the material
  for deciding 반영 vs 기각.
- `verdict` (CONFIRMED/PLAUSIBLE) exists only when a verify pass ran, i.e. `high` and above. At the
  default `medium` it is absent — do not hang the disposition on it.
- **Exit 3, or a non-zero `.done`** → do not guess at findings. Report the failure, leave the label at
  `agent-in-review`, and say what to retry. `.err` holds the stderr.

## 5. Disposition the findings

Every finding gets exactly one disposition, decided here and reported in [7]:

- **반영** — clear-cut: bugs, type errors, project-rule violations. Fix them.
- **기각** — the finding is wrong. Verify before rejecting and keep the counter-evidence as `path:line`;
  a rejection without it is just an assertion.
- **보류** — a judgment call, or a change the human owns (migrations, architecture, cost trade-offs).
  **Do not touch the code**, and work out the options *now* — [7] requires them.

Record dispositions as you go: the JSONL is the sole copy of the reasoning.

If anything changed, follow CONTRACT's commit path: `/comment-cleaner` → `pnpm check-types:<app>` →
`/commit` → `git push`.

## 6. Sync with the base, then typecheck against it

The branch was cut from an older base, so a green typecheck here only proves that *the old base plus these
changes* compiles. GitHub does not close that gap — it reports **text** conflicts, so a signature change on
the base and a new call site here both report "mergeable" and break only once merged.

```bash
git -C <worktree> fetch -p origin
BASE=$(gh pr view <PR> --json baseRefName -q .baseRefName)   # read fresh, never cached
git -C <worktree> merge origin/$BASE
pnpm check-types:<app>
```

### Stop conditions

- **Conflict** → resolve nothing; a wrong resolution is invisible to everyone downstream.
  `git merge --abort`, land at `agent-blocked`, and say what collides. Resolution belongs to
  `/land`, where both sides' intents are read before any hunk is touched.
- **Typecheck breaks** → fix, then follow CONTRACT's commit path again.
- **Migrations on both sides** → the numbers never conflict as text, but the apply order does. Name the
  colliding **files**, not the commits that introduced them.

## 7. The round comment — the round's only deliverable

After the round's last push, compute its range:

```bash
git -C <worktree> log --oneline $ROUND_BASE..HEAD          # empty → 반영 0건
git -C <worktree> diff --stat $ROUND_BASE..HEAD | tail -1  # file count
ROUND_HEAD=$(git -C <worktree> rev-parse HEAD)
```

The 반영 header links to one compare built from these:
`https://github.com/$REPO/compare/<ROUND_BASE first 7>..<ROUND_HEAD first 7>`

A base sync from [6] lands in this range too — that happened this round, which is fine. What must never
appear is anything *below* `ROUND_BASE`.

**Read `~/.claude/skills/review-round/references/round-comment.md` and follow its format and rules exactly.**

Write the body to a file and post with `--body-file` — tables, backticks and `|` do not survive `--body`
quoting reliably:

```bash
gh pr comment <PR> --body-file <scratchpad>/round-<N>-r<K>.md
```

## 8. Land the label and stop

- **Any 보류, or a base conflict from [6]** → `agent-blocked`. The issue comment is a **pointer only**
  (`리뷰 라운드 <K> 보류 <c>건 — <PR 코멘트 URL>`). Never restate the options there; two copies drift.
- **Neither** → `agent-awaiting-review`.

```bash
gh issue edit <N> --remove-label agent-in-review --add-label <agent-blocked|agent-awaiting-review>
```

The chat report is a **pointer, not a second write-up** — with one exception: **보류.** A 보류 item is a
question addressed to the human sitting in this session, and a bare link makes them open the PR just to
find out what is being asked.

So when `<c> > 0`, print the 보류 section **verbatim, copied out of the comment file that was just
posted** — never re-summarized, never re-ordered, or chat and comment become two drifting answers:

```bash
awk '/^### 보류/{f=1} f && /^### / && !/^### 보류/{exit} f' <scratchpad>/round-<N>-r<K>.md
```

보류 0건이면 아무것도 덧붙이지 않는다 — 코멘트의 `보류 없음` 한 줄로 충분하다.

Still **do not use `AskUserQuestion`** for them, and do not add analysis, extra options or a recommendation
that is not already in the comment. The decision comes back as the next `/implement <N>` instruction, not
as a blocking dialog.

Say this, then stop:

- 라운드 결과 → `<PR 코멘트 URL>` (지적 n · 반영 a · 기각 b · 보류 c)
- 보류 <c>건 (있을 때만) → 위 awk 로 뽑은 보류 섹션 그대로
- 더 리뷰 → `/review-round <N>`
- 더 수정 → `/implement <N>` with instructions
- 만족하면 → attach the merge signature; `/land` merges the queue:
  ```bash
  gh issue edit <N> --remove-label agent-awaiting-review --add-label agent-merge-ready
  ```
  The label is the merge decision (CONTRACT); `/land` drains every labelled issue in order,
  re-syncing each base and resolving conflicts on the way. Sign several rounds' worth and
  fire `/land` once — draining in batch is what keeps the queue's bases from going stale one by one.

## TODO — 다른 런타임 대응

이 스킬은 `claude -p '/code-review'` + `--output-format stream-json` 중첩 세션 트릭,
`CLAUDE_CODE_REPORT_FINDINGS=1` 이 만드는 `ReportFindings` 이벤트, 그리고 Monitor 툴에
의존해서 `~/.claude/skills/` 에 있다. codex 에는 `-p` 가 없고(`codex exec` · `codex review`)
동등한 구조체 출력 계약도 확인되지 않았다. 대체 방법 미정.
