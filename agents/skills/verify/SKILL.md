---
name: verify
description: Verifies that a change compiles, passes tests and behaves as intended, and produces evidence a reviewer can check — test output, API request/response, before/after screenshots for state claims, and assertion-backed interaction videos for behaviour claims (Playwright for web, argent for the Expo app). Replays the same flow against the base branch so "before" is real, then writes the `## 완료 조건 검증` record into the PR. Use when the user invokes `$verify` (Codex) or `/verify` (Claude Code), asks "검증해줘", "동작 확인해줘", "제대로 되는지 확인해줘", "before/after 찍어줘", "테스트 돌려서 증명해줘", or after `implement` opened a PR and before `land` merges it. It is the loop's only writer of that record — `implement` leaves a placeholder, `review-round` leaves the record alone, and `land` asks before merging a PR whose record no longer describes its head. Never merges, never pushes, never applies migrations, never writes to production.
---

# verify

Prove that a change does what it claims. The output is a verdict per claim (충족 / 미충족 / 미검증)
**backed by evidence a reviewer can replay**, not a narrative that the code looks right.

One principle drives every decision below: **the verdict comes from a replayable check; media is a
by-product.** A screenshot proves a state. A video shows a transition but cannot be diffed, so a video
is never the verdict — the flow's assertion is, run against the base branch (must fail or be absent)
and against the change (must pass). The video of that run is what the reviewer watches.

Shared vocabulary and the result template live in
`~/.agents/skills/agent-loop/references/acceptance-criteria.md`. Read it once; this skill is its
execution engine and does not restate it.

## Rules

**DO NOT**

- Treat typecheck, lint or a successful build as evidence of runtime behaviour. They are gates in [3].
- Mark 충족 without evidence from the route in `references/routes.md`. No evidence → 미검증 with the reason.
- Assume what "before" is. Before is the base branch in its own worktree from `scripts/base-worktree.sh`.
  Never `git stash`, `git checkout` or `git switch` in the main checkout.
- Use a model-driven recording (Chrome MCP GIF, hand-clicked screenshots) as evidence. Model-driven
  browsing is for **exploring** a flow; evidence comes from replaying the authored flow.
- Weaken, drop or reinterpret a claim so the code passes. Ambiguity goes back to the user; a wrong
  condition is fixed on the ticket, then through `implement`.
- Write 미검증 with a guessed reason. An environment reason quotes the `MISS`/`INFO` line from
  `scripts/check-env.sh` or the failed run's error verbatim; «설치 여부 미확정» is a reason to run the check,
  not a verdict (PR #375: every condition 미검증 for a simulator that was booted).
- Run `db:push` / `db:migrate`, write to a production database, or call production endpoints. A claim that
  needs a human-applied migration is 미검증 with that dependency named.
- Upload media anywhere but the PR through `gh --attach`. No third-party image hosts.
- Let secrets, tokens, auth query parameters or storage-state files into screenshots, videos, specs or PR text.

**DO**

- Decide the evidence type from the **form of the claim** ([2]) before running anything.
- Write the pass criterion for each claim before running its route, and judge against that text.
- Try the route before declaring 미검증. A missing environment is a reason; "it looked fine" is not.
- Keep one flow per claim, short, and name it after the claim.
- Report in Korean with the shared template; developer register is fine in the PR, but each result must be
  readable without opening the code.

## Inputs

| Invocation | Where the claims come from |
|---|---|
| `verify <N>` | `"$TRACKER" criteria <N>` — resolve `$TRACKER` per agent-loop `CONTRACT.md` [Tracker adapter]. The PR is `"$TRACKER" pr-for <N>`, the code is its worktree (`.claude/worktrees/issue-<N>-<slug>`, CONTRACT [Worktree convention]): `git -C <worktree> pull` first and run everything there. No open PR → session report only, and say so |
| `verify --pr <PR>` | the ticket bound to the PR (`gh pr view <PR> --json body` → binding line → `criteria`), else the PR body's own `## 완료 조건 검증` items |
| `verify` (no argument) | derived from `git diff <base>...HEAD` plus what the user said. **Present the derived list and get confirmation before running anything.** |

Options: `--base <branch>` (default: the PR's `baseRefName`, else ask — never assume `main`),
`--no-before` (skip the base comparison; record why), `--app <doko|admin|doko-app|api>` (restrict surfaces),
`--no-publish` (session report only, no PR edit).

## Where this run sits in the loop

`verify` is a human-fired step on an open PR, on the same axis as `review-round` and `land` — not a
sub-step of `implement`. It runs in a fresh context on purpose: the routes below want a simulator, a base
worktree and the quality gates, and an implementation session that has just finished coding has none of
that budget left (agent-loop `references/evidence.md`, «Verification»).

The record it writes is **a property of a commit, not a loop state**: its `검증 대상` sha is what `land`
compares with the PR head before merging and what `review-round` reports against after pushing fixes.
`scripts/verified-head.sh <PR> [<worktree>]` is that comparison — `current <sha>` / `stale <sha> <n>` /
`missing`. Run it first: a `current` record is replaced only for the items you re-check this run; a
`stale` or `missing` one is replaced whole. `results.target.commit` is the worktree HEAD you ran against,
and it must be the PR's `headRefOid` — pull before running, and never push from here.

## Progress checklist

Copy this into your response and check items off as you go.

```
Verification progress:
- [ ] 1  Resolve PR and worktree, run verified-head.sh, collect claims and confirm the list
- [ ] 2  Classify each claim → evidence type, route, written pass criterion
- [ ] 3  Gates: pnpm check-types:<app> (and lint when the diff touches lint-relevant code)
- [ ] 4  Environment: scripts/check-env.sh, base worktree, dev servers for the changed surfaces
- [ ] 5  Run every route; apply references/quality-gates.md to each artifact
- [ ] 6  Session report; render the PR block with scripts/evidence-block.mjs; publish; read back
```

## 1. Collect claims

A claim is one sentence whose truth can be observed. Keep the ticket's wording verbatim, qualifiers included.
When deriving from a diff, write claims the way the shared reference wants conditions written: an observable
result, with the precondition or action only when needed. Do not write "구현 완료" or "타입 체크 통과".

For each claim record the **surface**: `api`, `doko` (web, port 3000), `admin` (web, port 3001), `doko-app`
(Expo), `db`, or `none` (pure function). Surfaces decide which servers [4] starts.

## 2. Classify: the form of the claim decides the evidence

| Form of the claim | Example | Evidence | Verdict comes from |
|---|---|---|---|
| **State** — describes what is shown, no action verb | 상세 화면 상단에 만료일이 표시된다 | before/after screenshot pair (after-only for a new screen) at the same viewport and scroll | assertion that the element/text exists on head; visual pair for the reviewer |
| **Transition** — «~하면 / ~누르면 / ~다시 열어도» | 이미 참여한 미션을 다시 누르면 '이미 참여 중' 안내가 표시된다 | interaction video of the head run + stills at 조작 전 · 조작 · 결과 | flow assertion: passes on head; on base it fails or the flow cannot reach the state |
| **Invisible** — no rendered surface | 같은 식별자로 두 번 저장하면 두 번째 저장이 거절된다 | test output, or request + response + the persisted row | `pnpm test <path>` result, or an API call against the dev service |

Then write the pass criterion as one line: `PASS when <observable> within <timeout>`. If you cannot write it,
the claim is ambiguous — stop and ask.

The verdict matrix for transitions and states, once both runs exist:

| head | base | Record |
|---|---|---|
| pass | fail / unreachable | 충족 — 이 변경이 만든 동작 |
| pass | pass | 충족, plus a note «base 에서도 성립» — the claim may not depend on this change; say so |
| fail | any | 미충족 — name the actual result |
| runner error, timeout, environment missing | — | 미검증 — name the cause; retry once for a timeout |

## 3. Gates

`pnpm check-types:<app>` for every app the diff touches. Never call `tsc` or `turbo run` directly. A failing
gate stops the run: fix if the failure is clearly within scope, otherwise report and stop. Passing gates are
not recorded as evidence for any claim.

## 4. Environment

```bash
bash ~/.agents/skills/verify/scripts/check-env.sh              # what is installed, what is missing, the fix
bash ~/.agents/skills/verify/scripts/base-worktree.sh <base>    # detached worktree at the base commit
bash ~/.agents/skills/verify/scripts/dev-servers.sh start head "$ROOT" <apps…>
bash ~/.agents/skills/verify/scripts/dev-servers.sh start base "<base-worktree>" <apps…>
```

Port sets are fixed so the same spec runs against either: **head** api 4000 · doko 3000 · admin 3001 · metro 8081,
**base** api 4100 · doko 3100 · admin 3101 · metro 8082. Start only the surfaces the claims name; a web surface always
brings its own API of the same set, because the web reads `VITE_API_BASE_URL` at start.

Skip the base set with `--no-before`, and for `db`/`none` surfaces. Stop both sets in [6].

## 5. Run the routes

Per claim, follow the route in `references/routes.md`. Web flows are detailed in
`references/web-playwright.md`, app flows in `references/app-argent.md`. Before an artifact counts, pass it
through `references/quality-gates.md`; a rejected artifact is re-captured with the stated fix, and the
rejection reason stays in the session log.

Order: tests → API → web → app. Earlier, cheaper evidence often settles a claim; do not capture a video for a
claim a test already proves.

## 6. Report and publish

**Session report** (Korean), in this shape:

```
검증 대상: <short sha> · base: <branch>@<short sha> · 환경: <sets started, devices used>

- 충족  <claim>  — <one-line evidence pointer>
- 미충족 <claim> — 기대: … / 실제: …
- 미검증 <claim> — 이유: …

거부한 증거: <n>건 (<reasons>)   ← omit when zero
```

**PR block.** Write `results.json` (schema in `scripts/evidence-block.mjs` header) and render:

```bash
node ~/.agents/skills/verify/scripts/evidence-block.mjs --results .e2e/evidence/<run>/results.json \
  --body-file .e2e/evidence/<run>/pr-body.md > pr-body-next.md
node ~/.agents/skills/verify/scripts/evidence-block.mjs --results … --attach-list   # media paths for gh
gh pr edit <PR> --body-file pr-body-next.md --attach <file>…                        # gh ≥ 2.99
```

The block sits between `<!-- verify:start -->` and `<!-- verify:end -->` and contains the whole
`## 완료 조건 검증` section. Everything outside the markers is preserved byte for byte: re-read the PR body
first, never hand-edit around the markers, and read the published body back to confirm no `./.e2e/...`
path survived. Videos go on their own line so GitHub renders a player; a before/after video table is a
second pass with the uploaded `user-attachments` URLs (`--video-url`), as in `web-playwright.md`.

`gh` below 2.99 has no `--attach`. Then publish the text block only, keep media under `.e2e/evidence/<run>/`
and say so in the report — do not fall back to a public image host.

Finally `dev-servers.sh stop head`, `dev-servers.sh stop base`, and `base-worktree.sh --remove`.

## Where the flows live

Web specs are real e2e tests: `apps/<app>/e2e/<claim-slug>.spec.ts`, run by the root `playwright.config.ts`
(installed from `templates/` by `check-env.sh --install-config`). They ship in the same PR so the flow that
proved the claim becomes its regression test. App flows live under `.argent/flows/verify/`. Storage state,
results, videos and traces live under `.e2e/` (gitignored) and never enter a commit.

## Boundaries

This skill owns claim classification, the base/head comparison, the verdict and the PR record. It delegates:
browser exploration to the Playwright MCP (Chrome MCP in Claude Code only as a fallback for looking),
replay and assertions to `@playwright/test`, device flows and recording to `argent`, uploads to `gh`.
It never opens a PR, never pushes, never transitions ticket state, never edits issue checkboxes (`land`
does), and never launches a paid review engine.

Errors and their fixes: `references/errors.md`.
