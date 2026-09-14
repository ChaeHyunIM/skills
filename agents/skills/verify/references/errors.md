# Errors and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `check-env.sh` reports `@playwright/test: MISS` | no repo installation detected | use an available browser or temporary harness; persistent dependency installation belongs to implementation |
| `Executable doesn't exist at …/ms-playwright/…` | browsers not downloaded | `pnpm exec playwright install chromium` |
| Spec lands on the login page | storage state missing or expired | human logs in via the Playwright MCP browser → `browser_storage_state` → `.e2e/storage-state/<app>.json` |
| `browser_*` tools not found | this runtime has no such tool | discover the available browser capabilities; use an equivalent route or report the missing capability |
| `gh pr edit: unknown flag --attach` | this CLI has no attachment option | publish text without local media links and keep media local; handle CLI upgrades separately |
| `ECONNREFUSED localhost:4000` from the web app | API set not started | `dev-servers.sh start head <root> api doko` (the web needs its set's API) |
| Web set starts but calls the wrong API port | `VITE_API_BASE_URL` from `.env.local` won | `dev-servers.sh` exports it per set; check `.e2e/servers/<set>/doko.log` for the URL vite printed |
| `port … is taken by another process` | a previous set still running, or the user's own dev server | `dev-servers.sh stop head` / `stop base`, or `lsof -i :<port>`; never kill a server you did not start without asking |
| `pnpm install` in the base worktree fails on a lockfile | base has a different lockfile | expected; the worktree runs its own install — never copy `node_modules` |
| Base worktree lacks `routeTree.gen.ts` | gitignored generated file | `base-worktree.sh` copies it from the main checkout; if the base predates the app, that surface has no before |
| `argent` says no device | simulator not booted | `argent run boot-device` or Xcode → Simulator |
| `argent flow run` fails at step 1 `launch` | Metro not running or wrong bundle id | start Metro for the set, check `launch-app` bundle id |
| `ffmpeg: command not found` | not installed | `brew install ffmpeg` (only needed for webm → mp4 and frame extraction) |
| Test DB connection refused | runner or database setup failed | use `pnpm test <path>` and inspect its actual error; do not infer the cause without checking |
| PR body contains two `verify` marker pairs | ambiguous current record | preserve the body and identify the intended record before changing it; do not delete a block by guesswork |
| Worktree is dirty or has local-only commits | another change would be overwritten or misidentified | preserve it and identify the owning task before verification or synchronization |
