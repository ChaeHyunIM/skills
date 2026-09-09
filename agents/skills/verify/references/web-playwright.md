# Web flows with Playwright

Two layers, one engine. **Exploration** is model-driven through the Playwright MCP (accessibility snapshots,
recorded actions come back as Playwright code). **Evidence** is a `@playwright/test` spec replayed without a
model, against the head set and the base set. Same engine, so what you saw while exploring is what the spec does.

## Repo layout (installed by `check-env.sh --install-config`)

```
playwright.config.ts          root; testDir apps/, matches apps/*/e2e/*.spec.ts
apps/<app>/e2e/<claim>.spec.ts
.e2e/                          gitignored: storage-state/, results/, evidence/, servers/
```

Env read by the config: `E2E_BASE_URL` (default `http://localhost:3000`), `E2E_STORAGE_STATE` (optional),
`E2E_OUT` (results dir, default `.e2e/results`). Video and trace are always on; JSON report at
`$E2E_OUT/report.json`.

## Login: storage state saved by a human

doko and admin sit behind social login, so a spec cannot log in by itself. The human logs in **once** in the
Playwright MCP browser (it keeps a persistent profile, so the login survives sessions), then the agent saves the
state:

1. Ask the human: «Playwright MCP 브라우저에서 <app> 에 로그인해 주세요. 끝나면 알려 주세요.»
2. Call the MCP tool `browser_storage_state` to save cookies + localStorage to
   `.e2e/storage-state/<app>.json`.
3. Specs run with `E2E_STORAGE_STATE=.e2e/storage-state/<app>.json`.

The file is gitignored and must never be attached, quoted or pasted. When a run lands on the login page instead
of the target route, the state expired: go back to step 1, do not try to automate the provider login.

## Exploration with the Playwright MCP

Install (persistent config — the human runs or approves this):

```bash
claude mcp add playwright -- npx @playwright/mcp@latest --caps testing          # Claude Code
# Codex: ~/.codex/config.toml
# [mcp_servers.playwright]
# command = "npx"
# args = ["@playwright/mcp@latest", "--caps", "testing"]
```

Flow:

1. `browser_navigate` to the head URL. `browser_snapshot` — read the accessibility tree, not screenshots.
2. `browser_start_recording`, perform the action(s) with `browser_click` / `browser_type` / …, confirm the
   result with `browser_verify_text_visible` / `browser_verify_element_visible` / `browser_verify_value`.
3. `browser_stop_recording` returns the actions as Playwright code. `browser_generate_locator` gives a stable
   locator for anything the recorder picked poorly.
4. Author the spec from that code (below). Do not paste the recorder output unedited — it lacks the claim,
   the named screenshots and the assertion timeout.

Chrome MCP (Claude Code only) can substitute for step 1 when the Playwright MCP is not installed, but it emits no
code, so the spec is written from the snapshot by hand. Its GIF is never evidence.

## Authoring the spec

One `test` per claim. Skeleton (`templates/example.spec.ts` is the full version):

```ts
import { test, expect } from "@playwright/test";

test("이미 참여한 미션을 다시 누르면 '이미 참여 중' 안내가 표시된다", async ({ page }, info) => {
  info.annotations.push({ type: "claim", description: "YOU-123 완료 조건 2" });
  await page.goto("/missions/42");
  await page.screenshot({ path: info.outputPath("before-action.png") });
  await page.getByRole("button", { name: "참여하기" }).click();
  await page.screenshot({ path: info.outputPath("action.png") });
  await expect(page.getByText("이미 참여 중")).toBeVisible({ timeout: 3_000 });
  await page.screenshot({ path: info.outputPath("result.png") });
});
```

- Locators by role/text first, `data-testid` second, CSS last. Never `page.waitForTimeout` — assertions wait.
- The assertion timeout is the pass criterion's timeout.
- Named screenshots at 조작 전 · 조작 · 결과. They are the stills for the PR; keep them.
- State claims: a single `expect(...).toBeVisible()` and one screenshot named `state.png`.
- Test data: the flow must find or create what it needs on the dev database and clean up what it created.
  A flow that depends on a row someone else may delete is flaky by design — say so if unavoidable.

## Running against head and base

```bash
# head
E2E_BASE_URL=http://localhost:3000 E2E_STORAGE_STATE=.e2e/storage-state/doko.json E2E_OUT=.e2e/results/head \
  pnpm exec playwright test apps/doko/e2e/<claim>.spec.ts --project=chromium
# base — same spec file from the main checkout, only the URL changes
E2E_BASE_URL=http://localhost:3100 E2E_STORAGE_STATE=.e2e/storage-state/doko.json E2E_OUT=.e2e/results/base \
  pnpm exec playwright test apps/doko/e2e/<claim>.spec.ts --project=chromium
```

Read `$E2E_OUT/report.json`: `suites[].specs[].tests[].results[].status` is `passed` / `failed` / `timedOut`.
`admin` has no `VITE_API_BASE_URL` (its client code was not found reading one), so a base `admin` server may
still talk to the head API — check `apps/admin` before trusting an admin before/after. A `timedOut` on head is retried once; a second timeout is 미검증 with «assertion 타임아웃 (<n> ms)», not 미충족.

A base run that **fails to reach the action** (button absent, route 404) is «unreachable» in the matrix and
counts as before-fails. Quote the failing step.

## Media for the PR

Per test, Playwright writes `video.webm`, `trace.zip` and the named screenshots into
`$E2E_OUT/<test-dir>/`. Copy what the record needs into `.e2e/evidence/<run>/` with short, whitespace-free
names (`claim-2-head.mp4`, `claim-2-before-action.png`, …).

GitHub renders `.webm`, but recommends H.264 for playback everywhere. Convert:

```bash
ffmpeg -y -i video.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart claim-2-head.mp4
```

Attachment caps: **10 MB** for images and for videos on a free plan (100 MB on paid). Check the file size before
attaching; over the cap → shorten the flow or reduce the viewport, never re-encode into mush. A clip longer than
about 60 s is a sign the flow covers more than one claim — split it.

Two-step video table (only when a before/after **video** pair is worth a side-by-side):

1. `gh pr comment <PR> --body-file own-lines.md --attach before.mp4 --attach after.mp4` — a temporary comment.
2. `gh api repos/{owner}/{repo}/issues/comments/<id> --jq .body` → collect the
   `https://github.com/user-attachments/assets/...` URLs.
3. Put them into the item's `video-pair` media as `beforeUrl` / `afterUrl` in `results.json` and re-render;
   `evidence-block.mjs` then emits a `<table>` of `<video>` cells instead of own-line videos.
4. Re-read the published PR body; only then delete the temporary comment.

Default is simpler: head video on its own line, base video omitted or on its own line below it.

## Verdict, then write results.json

Fill `results.json` (schema in `scripts/evidence-block.mjs`) from the two reports and the pass criterion.
`detail` for 충족 names the spec and the assertion; for 미충족 the expected vs actual; for 미검증 the cause.
