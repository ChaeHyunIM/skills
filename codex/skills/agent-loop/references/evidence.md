# Evidence behind the agent-loop rules

Where the rules in `CONTRACT.md` and the three skills came from. Read this **only when a rule is in
doubt** — a normal run does not need it.

Everything here is measured. Do not re-investigate these conclusions.

## Contents

- [Review rounds](#review-rounds)
- [Ticket slicing](#ticket-slicing)
- [Labels and blocking edges](#labels-and-blocking-edges)
- [Worktrees and environment](#worktrees-and-environment)

## Review rounds

**`claude -p` really performs slash expansion**
`/code-review`'s `disable-model-invocation` blocks only *the model calling itself*, not the CLI. A nested
`-p` run produced real findings, exit 0, no permission prompt.

**Default text mode emits nothing mid-run**
A 40-second run left the output file at 0 bytes the whole way and filled it only at exit. Switched to
`stream-json`, the same run had 3 events on disk after 5 seconds and grew continuously. That is what makes
a progress monitor possible — and why the output is JSONL, requiring `jq` extraction.

**`CLAUDE_CODE_REPORT_FINDINGS=1` only takes effect under `stream-json`**
The contract is off for `text` and `json`. Setting the env var without structured extraction means the
final `result` body is a one-line count rather than the findings — so the round **looks like it passed
with zero findings**.

**A bare `#1` is rewritten by GitHub into a PR link**
In PR #111's round-1 comment, every 반영/기각/보류 item rendered as an unrelated old PR title. A local
markdown preview never catches this. Hence finding numbers go inside backticks.

**Commit SHAs in a round comment stop existing within days**
`dev` is rebase-merge only, so branch SHAs all change at merge time. PR #97's `커밋 05ccf1fac` became a
value absent from the PR's commit list. A 보류 item in the same PR cited `8fc1efa2` from a different PR,
forcing the reader through unrelated history.

**`--comment`, `--fix` and `ultra` were not adopted**
`ultra` is human-triggered and billed. The other two conflict with the rule that a round's deliverable is
exactly one PR comment.

## Ticket slicing

**A forward-pointing dependency cannot be sequenced away**
PR #142. `router.push('/reviews/place')` against a route the ticket above owned: `TS2345`, unmergeable.
Hence whoever builds the destination also wires the entry point, and the earlier ticket renders it inert.

## Labels and blocking edges

**`ready-for-agent` covers blocked tickets — settled 2026-08-01 after two reversals**
2026-07-28 kept the label on blocked tickets; 07-30 reversed it to "startable today" and stripped #50·#51;
08-01 reversed back for good. What decided it: the narrow reading needs someone to re-apply the label when
a blocker closes, and nothing does. #50 was re-labelled by hand on 07-31; #143 never was, so it sat invisible
after its blocker #151 closed. A `ticket-blocked` label was created on 07-30 for the same gap and deleted
soon after. Do not re-narrow the label without first building the promotion step that the narrow reading
requires.

**`-is:blocked` reads only native edges, so a body-only blocker reads as startable**
Audited every open issue 2026-08-01. #46 declared `#42` (open) in its body with no native edge and appeared
in the startable list; edges were missing on #42·#124·#125 and partial on #51·#126·#127, harmless only
because those blockers had already closed. Registering #46's edge moved it to `is:blocked` immediately.
Search indexing lags a write by seconds — re-query before concluding an edit did not take.

## Worktrees and environment

**Running `claude -p` inside a worktree deletes that worktree on exit**
Measured via `/review-round`. Commits survive; only the checkout disappears. Hence pushing before the
review is mandatory. Recovery: `git worktree prune` → `worktree add` → `pnpm install` → copy routeTree
(both admin and doko).

**A hollow worktree makes git fall through to the main checkout**
The signal is a `git status` path starting with `../../../`.

**turbo excludes only gitignored files from its hash**
A generated file like routeTree that affects types while being gitignored produces false cache hits.
Currently resolved by folding route generation into the turbo task.
