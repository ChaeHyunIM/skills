# Errors and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `check-env.sh` reports `@playwright/test: MISS` | not installed in this repo | `pnpm add -Dw @playwright/test && pnpm exec playwright install chromium` (ask before adding a dependency to a repo that has none) |
| `Executable doesn't exist at …/ms-playwright/…` | browsers not downloaded | `pnpm exec playwright install chromium` |
| Spec lands on the login page | storage state missing or expired | human logs in via the Playwright MCP browser → `browser_storage_state` → `.e2e/storage-state/<app>.json` |
| `browser_*` tools not found | Playwright MCP not registered in this runtime | `claude mcp add playwright -- npx @playwright/mcp@latest --caps testing` or the Codex `config.toml` block in `web-playwright.md` |
| `gh pr edit: unknown flag --attach` | gh < 2.99 | `brew upgrade gh`; until then publish text only and keep media local |
| `ECONNREFUSED localhost:4000` from the web app | API set not started | `dev-servers.sh start head <root> api doko` (the web needs its set's API) |
| Web set starts but calls the wrong API port | `VITE_API_BASE_URL` from `.env.local` won | `dev-servers.sh` exports it per set; check `.e2e/servers/<set>/doko.log` for the URL vite printed |
| `port … is taken by another process` | a previous set still running, or the user's own dev server | `dev-servers.sh stop head` / `stop base`, or `lsof -i :<port>`; never kill a server you did not start without asking |
| `pnpm install` in the base worktree fails on a lockfile | base has a different lockfile | expected; the worktree runs its own install — never copy `node_modules` |
| Base worktree lacks `routeTree.gen.ts` | gitignored generated file | `base-worktree.sh` copies it from the main checkout; if the base predates the app, that surface has no before |
| `argent` says no device | simulator not booted | `argent run boot-device` or Xcode → Simulator |
| `argent flow run` fails at step 1 `launch` | Metro not running or wrong bundle id | start Metro for the set, check `launch-app` bundle id |
| `ffmpeg: command not found` | not installed | `brew install ffmpeg` (only needed for webm → mp4 and frame extraction) |
| Test DB connection refused under `pnpm test` | called vitest directly | always `pnpm test <path>` — the script boots the container |
| PR body contains two `verify` marker pairs | a hand edit duplicated the block | remove one pair manually, then re-render; the script refuses ambiguous bodies on purpose |
