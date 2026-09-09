# Routes: claim → how to check it → what counts as evidence

Read this at step [5]. Each route says what to run, what the artifact is, and what goes into the PR record.
The verdict wording (충족 / 미충족 / 미검증) and template come from
`~/.agents/skills/agent-loop/references/acceptance-criteria.md`.

## Existing or new tests (surface `none`, `api`, `db` — invisible claims)

```bash
pnpm test <path>            # never vitest / npx vitest directly: the runner boots the test DB
```

- Use an existing test when it already asserts the claim; quote the test name and its assertion line.
- Writing a new test is a separate decision from verifying. Write one when the claim is cheap to express as a
  test and would otherwise need a manual API call every round. Put it next to the code under test, following
  the project's existing test layout.
- Evidence: the runner's summary line plus the named test's status. Keep the excerpt under ten lines.
- A DB-behaviour claim (constraint, uniqueness, cascade) is proven by a test against the test database, not by
  reading the schema file.

## API request (surface `api`)

Start the set's API (`dev-servers.sh`), then call it with the exact input the claim describes:

```bash
curl -sS -X POST http://localhost:4000/<route> -H 'content-type: application/json' -d @input.json | tee response.json
```

- Evidence: the request (method, path, body with secrets removed), the response status and body, and when the
  claim is about persistence, the row read back. Read rows through an existing read-only script in
  `packages/scripts` or a `SELECT` against the **local** database only.
- Auth-required routes: reuse the session cookie from the storage-state file (`web-playwright.md`), sent as
  `-H 'cookie: …'`. Never paste the cookie into the PR record.
- Base comparison for API claims: run the same request against the base set (port 4100) when the claim says
  the behaviour is new or changed. Two identical responses mean the claim does not depend on this change —
  record it, do not hide it.

## Web state claim (surface `doko`, `admin`)

One spec with one `test` per claim. The assertion is `expect(locator).toBeVisible()` /
`toHaveText()` / `toHaveCount()` on head. Take `page.screenshot()` at the same route, viewport and scroll
position on both sets; the pair goes into the record as `kind: "pair"`.

A new screen has no before: after-only, `kind: "image"`, and say «신규 화면» in the item.

## Web transition claim (surface `doko`, `admin`)

One spec, one `test`. The flow performs the action; the assertion waits for the result state with a timeout
matching the pass criterion. Screenshots at named points (`before-action`, `action`, `result`) come from the
spec itself — they are deterministic; extracting frames from the video is the fallback. The run's video is
attached as `kind: "video"`. Run on head and on base; apply the verdict matrix in SKILL.md [2].

Details, config and commands: `web-playwright.md`.

## App claim (surface `doko-app`)

Record the flow once with argent's flow tools while exploring, then replay it with `argent flow run`.
Screen recording wraps the replay and produces the mp4. Details: `app-argent.md`.

The base comparison for app flows needs the dev client pointed at the base worktree's Metro (port 8082).
When that is not practical, record head-only and write «before 비교 생략: <이유>» on the item; the flow's
assertion still carries the verdict on head.

## Human-applied migration (surface `db`)

The agent never applies it. Until the human has, every claim depending on the migration is 미검증 with
`이유: 마이그레이션 <file> 적용 대기`. After the human applies it, rerun only the affected claims.

## When a route is unavailable

State the missing piece (`check-env.sh` names it), record 미검증 with that reason, and continue with the other
claims. Do not substitute a weaker route silently — a typecheck is not a fallback for a flow.
