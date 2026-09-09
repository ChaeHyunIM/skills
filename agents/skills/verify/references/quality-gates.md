# Quality gates: when an artifact does not count

Apply to every screenshot, video, report and response before it enters `results.json`. A rejected artifact is
re-captured with the named fix; the rejection stays in the session log (count and reasons in the report).

## Reject the artifact

| Sign | Why it fails | Fix |
|---|---|---|
| Login page, landing page or a route different from the claim's | wrong state | storage state expired → human re-login; or the route/base URL is wrong |
| Blank frame, loading skeleton, spinner in the «결과» still | captured too early | assert the result element first, screenshot after |
| Vite error overlay, wrangler error page, React error boundary | the app crashed, not the claim | fix or record 미검증 with the error |
| before and after pixel-identical while the claim says something changed | no evidence of change | wrong route/state, or the change is not on this surface — investigate, do not attach |
| Pair captured at different viewport, zoom, scroll or theme | not comparable | same `--project`, same `goto`, same scroll, both sets |
| Screenshot or video shows a token, cookie, auth query string, storage-state path or `.env` value | leak | recapture with the value hidden; never crop a leak out after upload |
| Video over the attachment cap or longer than ~60 s | will not upload / covers too much | split the flow per claim, shorten, reduce viewport |
| Video where nothing moves (a static page recorded) | should be a still | change the evidence type to `image` |
| Report from a commit other than the PR head | stale | rerun after `git rev-parse HEAD` matches the PR head |

## Question the verdict

| Sign | What it means | Do |
|---|---|---|
| Flow passes on base too | the claim does not depend on this change | 충족 with «base 에서도 성립»; tell the user the claim may be misattributed |
| Flow passes on head only after a retry | flaky assertion or timing | if the second run passes, record it and note «1회 재시도»; a third failure is 미검증 |
| Assertion had to be loosened to pass | you are fitting the claim to the code | revert the loosening; report 미충족 or ask |
| Test data created by the flow was not cleaned up | pollutes later runs | add cleanup to the spec before publishing |
| Every claim is 충족 on the first try with no rejection | possible, but check the pass criteria were written before the run | re-read [2]; if any criterion was written after, rerun that claim |

## Never publish

- Storage-state files, `.env*`, cookies, bearer tokens, signed URLs.
- Media of production data that identifies a real user, unless the claim is about that surface and the
  user approved.
- A block that replaces PR prose outside the `verify` markers.
