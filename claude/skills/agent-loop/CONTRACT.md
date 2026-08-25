# agent-loop shared contract

The contract shared by `to-tickets`, `implement`, `review-round` and `land`. All four read this file
at the start of a run. The **evidence** behind these rules — measurements, incidents — is not here; it lives in
`references/evidence.md` and is read only when a rule is in doubt.

## Contents

- [Vocabulary](#vocabulary)
- [Loop map](#loop-map)
- [Label state machine](#label-state-machine)
- [Blocking edges](#blocking-edges)
- [Worktree convention](#worktree-convention)
- [Output convention](#output-convention)
- [Never](#never)

## Vocabulary

One name per thing. The four skills use only this vocabulary.

| Term | Meaning |
|---|---|
| **base** | The branch this PR directly targets (`gh pr view --json baseRefName`). Never assumed |
| **blocker** | Another issue named in this issue's `## Blocked by` section |
| **finding** | One item produced by `/code-review` |
| **round** | One run of `/review-round` |

## Loop map

```
   /to-tickets            /implement <N>            /review-round <N>          human           /land
──────────────▶ issues ─────────────▶ PR opened ──────────────▶ round comment ──────▶ signs ─────────▶ merged
  ready-for-agent      agent-in-progress        agent-in-review        agent-merge-ready
                       → agent-awaiting-review  → agent-awaiting-review
                                                 or agent-blocked
```

The merge judgment always terminates at the human — but the human expresses it by attaching
`agent-merge-ready`, and `/land` executes it. The label is a merge **signature**, not a status note.

## Label state machine

Labels are the **single source of truth** for state in this loop. A PR's draft flag is never used as a
state signal — two signals saying the same thing will drift. Therefore **PRs are always opened non-draft.**

| Label | Meaning | Set by |
|---|---|---|
| `ready-for-agent` | A complete spec an agent may pick up — **blocked tickets carry it too** | `to-tickets` |
| `agent-in-progress` | Being implemented | `implement` |
| `agent-awaiting-review` | Human can read it, or a round can be fired | `implement` · `review-round` |
| `agent-in-review` | A round is running = the branch already has a writer | `review-round` |
| `agent-blocked` | Cannot proceed without a human decision | `implement` · `review-round` |
| `agent-merge-ready` | The human's merge signature — the only thing `/land` will merge | **human only** |

No skill ever sets `agent-merge-ready`. Mergeability is a judgment, and judgment is the human's —
setting the label **is** that judgment. `/land` drains the labelled set: it orders the queue, syncs
each base, assembles conflict resolutions from both sides' documented intents, and merges. A conflict
with no union of intents (the two sides change the same behaviour incompatibly) exceeds the label's
delegation and bounces to `agent-blocked` — the human signed both PRs without knowing they contradict.

## Blocking edges

Every blocker is recorded **twice, and both are mandatory** — the two copies have different readers:

| Where | Read by |
|---|---|
| `## Blocked by` in the issue body | humans · `implement`'s blocker gate |
| GitHub's native dependency edge | `is:blocked` / `-is:blocked` queries |

Body prose is invisible to search, so a ticket carrying the body edge alone reads as *startable* in every
listing. Whoever notices a missing edge registers it on the spot:

```bash
BLOCKER_ID=$(gh api repos/<owner>/<repo>/issues/<blocker> --jq '.id')
gh api -X POST repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by -F issue_id=$BLOCKER_ID
```

`-F`, not `-f` — a quoted id is rejected with 422. `issue_id` is the database id, not the issue number.
Always read edges back through `--jq`; the raw response carries a full issue object per edge.

**Labels never carry blocked-ness** — that would be a third copy of the same fact, and the third copy is
the one that drifts. Merging or splitting tickets moves the edges too, not just the prose.

## Worktree convention

Path is `.claude/worktrees/issue-<N>-<slug>`, branch is `agent/issue-<N>-<slug>`, where `slug` is the
kebab-case issue title.

A fresh worktree needs two things before it is usable:

1. `pnpm install` — monorepo pnpm links are installed per worktree. Without it check-types breaks.
2. Copy `routeTree.gen.ts` from the main checkout — it is gitignored, so a new worktree lacks it.
   Never run `tsr generate`; it silently drops the `declare module` block. Applies to every app
   that carries a generated route tree.

`implement`'s `scripts/prepare-worktree.sh` does all of this in one call.

**Keep the worktree until the PR merges.** Rework and later rounds reuse the same one.

## Output convention

Everything a human reads is written in **Korean**: PR titles and bodies, issue bodies and comments, round
comments, commit messages.

There is exactly one path to a commit:

```
/comment-cleaner (no argument)  →  pnpm check-types:<app>  →  /commit skill  →  git push
```

- `/comment-cleaner` goes **before** `/commit`. Comment edits are code changes, and the rounds that
  follow will read them.
- Typecheck through the app script only: `pnpm check-types:<app>`, one per app in the monorepo.
  Never call `tsc` or `turbo run` directly.
- Commit through the `/commit` skill only. Never run `git commit` directly. The one exception is
  **completing a conflict resolution** in `/land` (`git commit --no-edit`): a resolution authors
  nothing, so the authored-change pipeline does not apply.

## Never

- **Never merge** — except `/land`, and only a PR whose issue carries `agent-merge-ready`.
  The only path work takes to the base branch is the PR.
- **Never commit or push to the base branch**, whatever it is named.
- **Never force-push. No exceptions** — nothing in this loop rewrites a pushed branch.
- **Never set `agent-merge-ready`.**
- **Never launch `/code-review ultra` from Bash.** It is human-triggered and billed.
