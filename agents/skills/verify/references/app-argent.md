# App flows with argent

Read this for repeatable device flows or requested recordings. One-off device observations may use the available device tools directly with a reproducible path and actual result. Recording is optional when it adds no evidence. In a verify-only run, use a temporary project root for new flows; do not overwrite committed flows.

`argent` (`@swmansion/argent`, on PATH at `/opt/homebrew/bin/argent`) drives the iOS simulator, records a
flow while the model explores, replays it without a model, and records the screen as H.264 mp4 at 30 fps.
List tools with `argent tools`, details with `argent tools describe <name>`.

## Explore and record in one pass

1. `list-devices` → `boot-device` (or attach to the booted one) → `launch-app` with the dev client bundle id.
   Metro must be running for the head worktree (`dev-servers.sh start head <root> doko-app`, port 8081).
2. `flow-start-recording` with `name: verify/<claim-slug>` and `project_root: <repo root>`. This resets
   `.argent/flows/verify/<claim-slug>.yaml`.
3. Explore with `describe` (accessibility tree) rather than screenshots. Every interaction goes through
   `flow-add-step` so it is recorded: `gesture-tap`, `keyboard`, `gesture-swipe`, `open-url`.
4. Wait for the result state with `await-ui-element` (recorded as the assertion) — this is the step that
   carries the verdict. `await-screen-idle` before screenshots.
5. `flow-add-echo` to label 조작 전 · 조작 · 결과 points; `screenshot` at each and keep the files.
6. `flow-finish-recording`.

## Replay with recording

```bash
argent run screen-recording-start --output .e2e/evidence/<run>/<claim>-head.mp4
argent flow run .argent/flows/verify/<claim-slug>.yaml --platform ios --json > .e2e/results/head/<claim>.json
argent run screen-recording-stop
```

Exit status reflects pass/fail; the JSON report lists each step. A failed `await-ui-element` is the
미충족 evidence — quote the step.

`argent flow run --update-baselines` writes screenshot baselines; on a later run, `screenshot-diff` compares.
Use baselines only for state claims where the screen must look the same; transitions use the await step.

## Before on the app

The dev client can only point at one Metro at a time. To get a real before:

1. `dev-servers.sh start base <base-worktree> doko-app` starts Metro for the base worktree on **8082**.
2. Switch the dev client to `http://localhost:8082` from its dev menu (or the deep link the project documents),
   `restart-app`, and replay the same flow with a recording to `<claim>-base.mp4`.
3. Switch back to 8081 afterwards.

If the switch is not available on the current device, record head-only and write «before 비교 생략: <이유>» on
the item. The verdict still comes from the head replay's await step.

## Media

`screen-recording-*` already produces H.264 mp4 at the device resolution; no conversion. Check the size against
the 10 MB cap (free plan) — a 30 s simulator clip is usually well under it. Stills come from `screenshot`
at the echo points.

## Where flows live

Existing committed flows stay in `.argent/flows/verify/`. New flows from `verify` stay in a temporary project root or an already ignored artifact directory. `implement` may include a regression flow in the PR and then verify the final head. Screenshots, recordings and reports stay in `.e2e/` only when it is already gitignored.
