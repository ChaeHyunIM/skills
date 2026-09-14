# Evidence behind the agent-loop rules

Where the rules in `CONTRACT.md` and the five skills came from. Read this **only when a rule is in
doubt** — a normal run does not need it.

Separate the observed result from the proposed cause. Dates and runtime/model versions absent below
were not recorded; do not infer them. Revisit environment-dependent workarounds when the relevant runtime,
repository setup or observed behavior changes. Preserve protections until an alternative is verified.

## Contents

- [Review rounds](#review-rounds)
- [Ticket slicing](#ticket-slicing)
- [Labels and blocking edges](#labels-and-blocking-edges)
- [Worktrees and environment](#worktrees-and-environment)
- [Verification](#verification)

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
This audit is why the body list was dropped on 2026-09-02: with two copies, the native one was the one
left out, and the body one went stale once blockers landed. The edge is now the only record and
`to-tickets` reads it back after publishing.

## Worktrees and environment

**A review run of `claude -p` removed its worktree on exit (runtime version not recorded)**
Observed via `/review-round`; this is not established for every CLI version. Commits survived; only the checkout disappeared. Hence pushing before the
review is mandatory. Recovery: `git worktree prune` → `worktree add` → `pnpm install` → copy routeTree
(for every app that has one).

**A hollow worktree makes git fall through to the main checkout**
The signal is a `git status` path starting with `../../../`.

**turbo excludes only gitignored files from its hash**
A generated file like routeTree that affects types while being gitignored produces false cache hits.
Currently resolved by folding route generation into the turbo task.

## Verification

**An implementation run reported unverified conditions without checking the environment**

- Observed: PR #375 (2026-09-09) reported every condition 미검증, saying simulator installation was uncertain. The environment check on the same machine reported argent 0.24.0 and one booted simulator. That check had not been run in the implementation session.
- Hypothesis at the time: the expensive verification route was reached after the coding context budget had been spent. The model, token budget and comparative runs were not recorded; the cause was not isolated.
- Current rule: implement performs the necessary checks and records actual evidence. Verify is an optional continuation for remaining conditions or independent rechecks. Missing evidence must not be filled with an invented environment explanation.
- Revisit: if implementation again stops without trying an available route, inspect the actual failing step and context before adding a universal stopping rule.

**A record with a SHA became stale because nobody compared it with the PR head**

Rework and review rounds added commits while the PR retained old 충족 lines. The comparison helper was introduced so land could expose the gap rather than treating old results as current.

**The merge-only exemption and range-count implementation disagreed (2026-09-14)**

- Observed in a temporary Git repository with the original helper and stubbed GitHub response: exact head returned current; a PR head rolled back to an ancestor also returned current; merging a new ordinary base commit returned stale despite the documented exemption.
- Cause: `rev-list --no-merges old..head` counts reachable base commits and does not prove equality or ancestry. A merge commit also does not prove unchanged runtime behavior.
- Current rule: current requires exact commit equality. Stale reports a symmetric commit count without implying chronological distance. Implement and verify evaluate condition-level evidence; land requires informed approval for any remaining gap.
- Revisit only with tests covering equality, rollback, divergence, base integration and conflict-resolution changes.
