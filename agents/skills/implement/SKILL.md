---
name: implement
description: Implements a tracker ticket in an isolated git worktree and opens a review-ready PR in Korean, then stops so the human can fire verification and review separately. Handles a fresh start and rework on an existing agent/issue-* branch. Use when the user explicitly invokes `$implement` in Codex or `/implement` in Claude Code. Never verifies 완료 조건 (that is `verify`, fired by the human on the open PR), never reviews and never merges.
---

# implement

Implement one ticket in an isolated worktree, open a **review-ready PR**, and stop at
`awaiting-review`. Verification (`verify <N>`) and review (`review-round <N>`) are fired separately by the
human on that PR — this skill does neither.

**Read `~/.agents/skills/agent-loop/CONTRACT.md` before starting** — states, the tracker adapter,
worktrees and the output convention live there and are not repeated here. Resolve `$TRACKER` per
CONTRACT's [Tracker adapter] before the first tracker call.

**Read `~/.agents/skills/agent-loop/references/acceptance-criteria.md`** for 완료 조건 authoring,
verification, PR evidence and land-only issue checkboxes.

| | |
|---|---|
| State transition | `ready` → `in-progress` → `awaiting-review` |
| Deliverable | one non-draft PR whose `## 완료 조건 검증` section is the placeholder `verify` fills |
| Never | verify 완료 조건 · review · merge · push to the base branch |

## Entry modes

- **`implement <N>`** → run [Execution] directly.
- **`implement` (no argument)** → run [Discover & propose] first, then **ask the user and stop**.
  Change nothing before the user confirms — no labels, no worktree.

## Progress checklist

Copy this into your response and check items off as you go.

```
Implementation progress:
- [ ] 1  Load ticket and 완료 조건, confirm each is verifiable, detect fresh vs rework
- [ ] 2  Blocker gate (fresh only)
- [ ] 3  Claim the state
- [ ] 4  Resolve the base
- [ ] 5  Prepare the worktree
- [ ] 6  Implement (fetch the Figma node first if the issue has a design)
- [ ] 7  Typecheck; run the tests this change added or touched
- [ ] 8  comment-cleaner → commit → check base both ways → push → PR with the verification placeholder
- [ ] 9  Land the state, point at `verify <N>`, stop
```

## Discover & propose (no-argument mode)

1. Collect candidates, and separately the subset the tracker considers startable:
   ```bash
   "$TRACKER" list ready
   "$TRACKER" list-startable
   ```
   Also surface resumable ones: `"$TRACKER" list blocked` (bounced back), `list awaiting-review` /
   `list in-progress` (in flight).

   `list-startable` reads only the native edges, never the body prose, so a ticket missing an edge shows
   up as startable when it is not. Treat that list as an ordering hint, not a verdict — [3] checks for real.
2. No candidates → report that and **stop**.
3. For each candidate, check its blockers' real state as in [2] and present briefly: number and title,
   a summary of the body (the goal), which app under `apps/` it targets, blocker status, and a
   one-line implementation plan. Candidates with an open blocker are listed as **not fireable yet** and
   excluded from the recommendation — list them, never drop them: they become fireable minutes after
   their blocker is signed and landed.
   If dependencies or priority are visible, mark **one recommendation**.
4. **Ask "which issue, and in what direction?" and wait. Stop here.**
5. Once confirmed, run [Execution] for that `<N>`.

## 1. Load the ticket, detect the mode

```bash
"$TRACKER" show <N>
"$TRACKER" criteria <N>
git branch --list "agent/issue-<N>-*"
```

No branch → **fresh start**. Branch exists → **rework** (continue on it, applying this turn's extra
instructions). Read each condition once the way `verify` will: is there an observable result one of its
routes (`~/.agents/skills/verify/references/routes.md`) can check? Missing or ambiguous conditions
go through [When stuck] before coding or claiming `in-progress`; its `blocked` transition is the explicit
exception to the normal claim sequence. Keep condition progress in the session, not in issue checkboxes.

## 2. Blocker gate (fresh only)

Read the ticket's blockers from the native edges — the only record of them (CONTRACT's [Blocking edges]);
a blocker list in an older ticket's body is stale prose, not an input. Then check each blocker's **actual
state — never its loop state**. Loop states are human-edited and lag. The truth is the ticket's open/closed
plus its PR:

```bash
"$TRACKER" blockers <N>                # [{number,state}] — the blockers
"$TRACKER" show <blocker>              # .state — open or closed
"$TRACKER" pr-for <blocker> --merged
```

A green typecheck against a base that lacks the blocker's work proves nothing (see evidence.md).

- **Every blocker closed with its PR merged** → proceed.
- **Any blocker still open** → **stop before [3]**. Report which blockers are open and change nothing
  (no state writes, no worktree). If a blocker sits at `awaiting-review` and the human is satisfied with
  it, the fast path is minutes long: invoke `land <blocker>` (the arguments are the merge signature),
  then re-run `implement <N>`.

## 3. Claim the state (immediately)

```bash
"$TRACKER" transition <N> in-progress
```

`transition` clears every other loop state first, so this one line covers both fresh and rework.

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
bash ~/.agents/skills/implement/scripts/prepare-worktree.sh <N> <slug> [<base>]   # omit base for rework
```

`slug` is the kebab-case issue title. The script handles worktree creation, `pnpm install` and the
routeTree copy.

## 6. Implement

- **The issue body is the goal.** There is no separate goal command.
- **Design-backed UI**: if the issue has a design section with Figma node links, fetch the node
  through the Figma MCP — its design-context tool, plus its screenshot tool for visuals — **before
  writing any UI code**. Use the connected Figma MCP's actual tools; never guess at tool names. The
  node is the source for layout and styling. If its behaviour conflicts with approved policy or
  완료 조건, use [When stuck] rather than silently picking a winner. The issue's "Figma가 답하지 않는 것"
  list covers only what the node does not show. If no Figma MCP
  is connected or the node cannot be fetched, treat it as stuck ([When stuck]) rather than
  improvising the UI from the issue prose.
- Follow the active project instructions (`AGENTS.md`, `CLAUDE.md`, or the host equivalent).
- Write tests where they are the natural proof of a condition (domain/server behaviour, pure functions);
  `verify` reuses them as evidence. Do not stage screenshots or device runs here — that is `verify`'s
  work, and it needs a context this session no longer has.

## 7. Typecheck and the tests this change owns

Fix and repeat until `pnpm check-types:<app>` passes. Never call `tsc` directly. Then run the tests the
change added or touched through the project runner (`pnpm test <path>`) and fix what they show.

**This step does not verify 완료 조건.** That is `verify`'s run, fired by the human on the open PR
(`verify <N>`) in a fresh context — with the environment check, the simulator, the base worktree and the
evidence gates it needs. It used to be called from here, and that is exactly where it got skipped: by this
point the session has spent its budget on the ticket and the code, so the most expensive route sat at the
point of least context and came back all 미검증 with a guessed reason (agent-loop `references/evidence.md`,
PR #375). A green typecheck or test run is a gate, not evidence for any condition.

## 8. Commit and PR

Follow CONTRACT's commit path: `comment-cleaner` (no argument) → `commit` → push.

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
gate and the tests from [7]**.

```bash
git push -u origin agent/issue-<N>-<slug>
LINK=$("$TRACKER" link-line <N>)   # the line that binds PR → ticket; never hand-write it
gh pr create --base <base> --title "<제목>" --body-file <scratchpad>/pr-<N>.md
```

Create the body file before `gh pr create`: preserve the adapter-produced `LINK`, record the base, explain
the implementation, and end with the verification placeholder — exactly one `## 완료 조건 검증` heading,
which `verify` later takes over in place:

```markdown
## 완료 조건 검증

검증 미실행 — `verify <N>` 이 이 섹션을 채운다. 타입 체크·테스트 통과는 완료 조건의 근거가 아니다.
```

Write no per-condition lines under it, not even 미검증 ones: a section without a `검증 대상` sha is what
`land` reads as "not verified", and that is the truth at this point. Read the published body back. The PR
still opens here, after implementation, always non-draft — never earlier for progress tracking.

**Rework**: push, re-read the existing PR body, update its implementation summary, and use
`gh pr edit <PR> --body-file <file>`. Leave `## 완료 조건 검증` alone — the push moved the head, so the
record's `검증 대상` no longer matches it and `land` will ask for a new `verify <N>` run; rewriting the
section by hand would only hide that. Preserve its binding and human-authored content. Do not flip it
back to draft — `in-progress` already says the code is moving.

## 9. Land the state and stop

```bash
"$TRACKER" transition <N> awaiting-review
```

Report the PR link and **stop**, with the next moves one line each:

- `verify <N>` — fills `## 완료 조건 검증` with evidence on this head; without it `land` asks whether to
  merge unverified
- `review-round <N>` — a review round; it does not need `verify` first, though UI-heavy tickets read
  better with the screenshots already there
- `implement <N>` with instructions — more changes

## When stuck

This path is for work that cannot proceed, especially missing or ambiguous requirements. A verification
obstacle is not one — `verify` records those on its own run.

If you cannot proceed on your own (ambiguous requirements, unresolved types, environment issues):

```bash
"$TRACKER" transition <N> blocked
"$TRACKER" comment <N> <막힌 지점과 필요한 결정을 적은 파일>
```

Stop and hand off to the human.

## Guardrails

In addition to CONTRACT's [Never]:

- This skill is the sanctioned exception for push + PR, but **only up to opening the PR**.
- The base is dynamic — the user's current branch unless `--base` says otherwise. Never assume `main`.
- **Never write a verification result** — no 충족/미충족/미검증 lines, no `검증 대상`. The placeholder in
  [8] is the whole section; `verify` is its only writer (CONTRACT [Never]).
