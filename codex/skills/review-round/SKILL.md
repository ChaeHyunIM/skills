---
name: review-round
description: Runs one human-fired dual-engine code-review round from Codex on an implement PR, using Claude /code-review and a subscription-backed nested Codex `$review-agent` against the same pinned head. Applies or defers findings once and posts one Korean summary. Use only when the user explicitly invokes `$review-round ISSUE_NUMBER [Claude review args...]`. Never merges.
---

# review-round

Runs **one review round** end to end on the PR from `implement` — one human input, two independent
local review engines on the same pinned head, no handoff in the middle. The explicit `$review-round`
invocation authorizes exactly one nested Claude review and one nested Codex review. Both run read-only;
only this outer loop applies findings and writes to GitHub.

**Read `~/.agents/skills/agent-loop/CONTRACT.md` before starting** — states, the tracker adapter,
worktrees and the output convention live there and are not repeated here. Resolve `$TRACKER` per
CONTRACT's [Tracker adapter] before the first tracker call.

| | |
|---|---|
| State transition | `awaiting-review` → `in-review` → `awaiting-review` or `blocked` |
| Deliverable | **one loop-authored** PR summary comment. Raw engine artifacts remain in the scratchpad |
| Never | judge mergeability · run `ultra` · trigger either engine outside a human-fired round |

## Progress checklist

Copy this into your response and check items off as you go.

```
Round progress:
- [ ] 1  Resolve PR and worktree, pin ROUND_BASE, BASE and REPO
- [ ] 2  Claim the state, fix the round number
- [ ] 3  Fire Claude and Codex on ROUND_BASE in one exec session, poll it to completion
- [ ] 4  Extract, sanity-check and deduplicate both finding lists
- [ ] 5  Disposition findings → comment-cleaner → typecheck → commit → push
- [ ] 6  Sync with the base, then typecheck against the merged tree
- [ ] 7  Compute the round range → write the PR comment
- [ ] 8  Land the label and stop
```

## Arguments

- **First argument = issue number `<N>`** (required).
- **Remaining arguments are forwarded to Claude's `/code-review`** verbatim, in order. The normalized
  effort is also passed to Codex. Other Claude-specific arguments are not forwarded to Codex.
- **Effort defaults to `medium`.** If the first forwarded argument is not one of
  `low`/`medium`/`high`/`xhigh`/`max`, prepend `medium`. Left off, `/code-review` inherits whatever
  `/effort` is set to, and it reads an unrecognized first token as the **review target path**.
- **`ultra` stops the run.** `ultra` is Claude Code's cloud review mode; this Codex entrypoint can
  neither fire it nor ingest its result. Start neither reviewer and tell the user to run
  `/code-review ultra` from a Claude Code session — the Claude entrypoint owns that flow.
- **`--fix` and `--comment` are refused.** Drop them from the forwarded string, say so, and continue —
  they duplicate or contradict work this skill already owns:
  - `--fix` applies findings inside [3], before [5] decides 반영·기각·보류. [5] fixes 반영 itself and
    has to stand behind every applied line anyway (comment-cleaner, typecheck, commit).
  - `--comment` posts Claude-authored inline PR comments. This skill authors only the single summary
    comment in [7].

Codex always uses `gpt-5.6-sol` with the normalized effort and invokes `$review-agent`. The helper
requires ChatGPT login and refuses to run when `CODEX_API_KEY` or `OPENAI_API_KEY` is set. This keeps
the review on the personal Codex subscription rather than the API billing path. Durable
repository-specific checks belong in `AGENTS.md`.

## 1. Pin the PR, worktree and round range

```bash
"$TRACKER" pr-for <N>
```

The adapter absorbs search-index lag and false full-text matches; an empty array means there really is
no open PR — stop and say so.

```bash
git -C <worktree> pull
ROUND_BASE=$(git -C <worktree> rev-parse HEAD)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BASE=$(gh pr view <PR> --json baseRefName -q .baseRefName)
COMPARISON_REF="origin/$BASE"
```

Pin `ROUND_BASE` **right after the pull, before the review runs**. Everything committed from here on is
this round's work and everything below it is not. It is the only thing that makes [7]'s compare link point
at this round alone.

## 2. Claim the state, fix the round number

```bash
"$TRACKER" transition <N> in-review
```

Round number `<K>` = the highest existing "리뷰 라운드 K" in `gh pr view <PR> --json comments`, plus 1.
Default 1.

## 3. Fire both review engines on `ROUND_BASE` in one Codex exec session

Neither engine may write the branch while reviewing. Both must start after `ROUND_BASE` is pinned and
before [5] changes any file.

### 3a. Preflight Codex authentication

Run this before starting either reviewer. It validates the fixed model/effort pair, confirms that the
CLI is logged in with ChatGPT, rejects API key environment variables, and checks the output schema.

```bash
CODEX_MODEL=gpt-5.6-sol
bash ~/.agents/skills/agent-loop/review-round/scripts/codex-review.sh \
  preflight "$CODEX_MODEL" <normalized-effort>
```

If preflight fails, start neither reviewer. Leave the state at `in-review`, report the error and stop.

### 3b. Create one scratchpad and start the joint runner

`/code-review` carries `disable-model-invocation`, so the `Skill` tool cannot call it. That flag blocks
only *the model calling itself*, not the CLI — `claude -p` takes the same slash-expansion path as a human
keystroke and really runs the review.

The runner starts `claude -p` and `codex exec` as two child processes, writes their separate JSONL,
result, stderr and `.done` artifacts, and waits for both. `$review-agent` supplies the nested Codex
process's read-only defect-first contract.

```bash
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/review-round-<N>-r<K>.XXXXXX")
bash ~/.agents/skills/agent-loop/review-round/scripts/run-reviewers.sh \
  <worktree> <N> <K> "$COMPARISON_REF" "$ROUND_BASE" \
  "$CODEX_MODEL" <normalized-effort> "$SCRATCH" <normalized-Claude-args...> <PR>
```

- `<normalized-Claude-args...>` is the effort-defaulted argument array from [Arguments], not the caller's
  raw tail.
- **`<PR>` is the PR number from [1], always appended last so it becomes Claude's review target.** Left
  targetless, `/code-review` picks its own comparison base — in practice `main` — so when the PR's base
  branch is ahead of `main`, the review sweeps the base's own commits too (YOU-49 round 1: 7 of 11
  findings were dev-only backend code outside the PR). The PR target pins the diff to the PR's declared
  base; the head is already pushed and [1] pulls, so the PR diff equals the pinned worktree head.
- **Run the runner with escalated permissions, outside the sandbox.** The nested `claude` and
  `codex exec` processes need network access to reach their models and write CLI state under `$HOME`;
  the default workspace-write sandbox blocks both. The helper's `--sandbox read-only` only constrains
  the nested reviewer's own shell commands — it does not open the network for the reviewer process.
- **`--output-format stream-json --verbose` is mandatory too.** Default text mode writes nothing until
  exit, and `CLAUDE_CODE_REPORT_FINDINGS=1` only takes effect under this format.
- Run both from the same worktree and pinned head. The Codex helper checks `HEAD` before and after its
  review; the joint runner checks it once more after both finish.
- The runner exits `124` when the reviewers outrun `REVIEW_MAX_SECONDS` (default 3600s), after
  terminating both. Treat that like any reviewer failure: report it and leave the state at `in-review`.

Run the command with `exec_command` and a short initial yield. If it returns a `session_id`, keep that
exact session and call `write_stdin` with empty input and `yield_time_ms: 30000` until it exits. Send a
brief commentary update between polls so the user is not left without progress. **Never launch the
runner a second time while the first session exists.** The runner prints a joint digest every 30 seconds.
Continue to [4] in the same turn when the session completes.

## 4. Extract, sanity-check and combine the findings

Entered when the joint runner completes.

```bash
CLAUDE_FINDINGS=$(bash ~/.agents/skills/agent-loop/review-round/scripts/extract-findings.sh \
  <scratchpad>/review-<N>-r<K>.jsonl)
CODEX_FINDINGS=$(bash ~/.agents/skills/agent-loop/review-round/scripts/codex-review.sh \
  extract <scratchpad>/codex-review-<N>-r<K>.json \
  "$ROUND_BASE" "$CODEX_MODEL" <normalized-effort>)
```

Claude extractor: exit `0` = structured · `2` = prose fallback (report the round as degraded) · `3`
= nothing usable. Codex extractor has no prose fallback: exit `0` = schema-valid · `3` = invalid result.

Structured shape:
`{level, findings:[{file, line, summary, short_summary, failure_scenario, category, verdict?}]}`

- Add `source: "Claude"` to every Claude finding. Codex findings already carry `source: "Codex"`.
- Deduplicate only when both engines name the same defect at the same or overlapping location. Keep
  one finding with `source: "Claude+Codex"`. Similar topics with different failure scenarios remain
  separate findings.
- **Combined array order is the finding number** — `#1` is the first combined finding.
- `short_summary` (≤60 chars) is the table cell, `file:line` the location, `failure_scenario` the material
  for deciding 반영 vs 기각.
- Claude's `verdict` (CONFIRMED/PLAUSIBLE) exists only when its verify pass ran, i.e. `high` and above.
  At the default `medium` it is absent — do not hang the disposition on it. Codex instead returns
  `overall_assessment`, `test_gaps` and `residual_risks`; use them for the pass summary and verification
  context, not as extra findings.
- **Exit 3, either non-zero `.done`, Codex extraction failure, or a moved worktree head** → do not guess
  at findings or disposition only one engine. Report the failure, leave the state at `in-review`, and
  say what to retry. Each engine's `.err` file holds its stderr.

## 5. Disposition the findings

Every finding gets exactly one disposition, decided here and reported in [7]:

- **반영** — clear-cut: bugs, type errors, project-rule violations. Fix them.
- **기각** — the finding is wrong. Verify before rejecting and keep the counter-evidence as `path:line`;
  a rejection without it is just an assertion.
- **보류** — a judgment call, or a change the human owns (migrations, architecture, cost trade-offs,
  **product policy**). **Do not touch the code**, and work out the options *now* — [7] and [8] both
  require them. Tag each 보류 **개발** (a developer decides) or **팀** (기획·운영도 결정에 참여한다);
  [8] translates only the 팀 ones for a non-developer audience.

  Policy is the one that disguises itself as a fix. Judge it yourself: whenever resolving a finding means
  deciding what the product does rather than correcting what the code got wrong, it is 보류 — even when the
  "right" answer looks obvious, and even when the ticket says nothing about it. Silence is a gap the team
  fills, not one this round fills.

Write the combined list to `<scratchpad>/review-<N>-r<K>.findings.json` before disposition and record
each disposition there as you go. The Claude and Codex scratchpad outputs are engine evidence; the
combined file is the round's sole working copy and [7]'s input.

If anything changed, follow CONTRACT's commit path: `$comment-cleaner` → `pnpm check-types:<app>` →
`$commit` → `git push`.

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
  `git merge --abort`, land at `blocked`, and say what collides. Resolution belongs to
  `$land`, where both sides' intents are read before any hunk is touched.
- **Typecheck breaks** → fix, then follow CONTRACT's commit path again.
- **Migrations on both sides** → the numbers never conflict as text, but the apply order does. Name the
  colliding **files**, not the commits that introduced them.

## 7. The round comment — the round's only loop-authored deliverable

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

**Read `~/.agents/skills/agent-loop/review-round/references/round-comment.md` and follow its format and rules exactly.**

Write the body to a file and post with `--body-file` — tables, backticks and `|` do not survive `--body`
quoting reliably:

```bash
gh pr comment <PR> --body-file <scratchpad>/round-<N>-r<K>.md
```

## 8. Land the state and stop

- **Any 보류, or a base conflict from [6]** → `blocked`. The ticket comment (`"$TRACKER" comment`) is a
  **pointer only** (`리뷰 라운드 <K> 보류 <c>건 — <PR 코멘트 URL>`). Never restate the options there;
  two copies drift.
- **Neither** → `awaiting-review`.

### 팀이 정해야 하는 보류는 따로 번역해 올린다

The round comment is developer-to-developer and posts itself. Some 보류 items are not a developer's
call at all — product policy, operating rules, cost, user-visible behaviour — and 기획·디자인·운영
never open the PR to read them.

When at least one 보류 is that kind, rewrite **those items only** into a second ticket comment a
non-developer can read. **Read `~/.agents/skills/agent-loop/review-round/references/team-comment.md`
and follow it exactly.** Its rule that outranks everything else here: the draft goes to the chat in
full and is posted **only after the human approves it**. Never call `"$TRACKER" comment` with it
unapproved. Pure-development 보류 stays in the PR comment and is not translated.

```bash
"$TRACKER" transition <N> <blocked|awaiting-review>
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

Still **do not open a blocking user-input dialog** for them, and do not add analysis, extra options or a
recommendation that is not already in the comment. The decision comes back as the next `$implement <N>` instruction, not
as a blocking dialog.

Say this, then stop:

- 라운드 결과 → `<PR 코멘트 URL>` (지적 n · 반영 a · 기각 b · 보류 c)
- 보류 <c>건 (있을 때만) → 위 awk 로 뽑은 보류 섹션 그대로
- 더 리뷰 → `$review-round <N>`
- 더 수정 → `$implement <N>` with instructions
- 만족하면 → `$land <N>` — the arguments are the merge signature (CONTRACT), and `$land` merges
  them in order, re-syncing each base and resolving conflicts on the way. Collect several rounds'
  worth and fire `$land <N> <M> ...` once — draining in batch is what keeps the queue's bases from
  going stale one by one.

## Runtime boundary

This is the Codex outer entrypoint. It owns state transitions, finding disposition, branch writes and
the single PR comment. The child `codex exec` invokes `$review-agent` and remains read-only; it never
recursively invokes `$review-round`. The Claude entrypoint at `~/.claude/skills/review-round/SKILL.md`
owns the same workflow when the human starts it from Claude. Both entrypoints share scripts and
references from `~/.agents/skills/agent-loop/review-round/`.
