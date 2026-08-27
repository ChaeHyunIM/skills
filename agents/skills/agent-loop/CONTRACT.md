# agent-loop shared contract

The contract shared by `to-tickets`, `implement`, `review-round` and `land`. All four read this file
at the start of a run. The **evidence** behind these rules — measurements, incidents — is not here; it lives in
`references/evidence.md` and is read only when a rule is in doubt.

## Contents

- [Vocabulary](#vocabulary)
- [Loop map](#loop-map)
- [Tracker adapter](#tracker-adapter)
- [State machine](#state-machine)
- [Blocking edges](#blocking-edges)
- [Worktree convention](#worktree-convention)
- [Output convention](#output-convention)
- [Never](#never)

## Vocabulary

One name per thing. The four skills use only this vocabulary.

| Term | Meaning |
|---|---|
| **tracker** | The platform holding the loop's tickets (GitHub Issues, Linear, …), reached only through the adapter |
| **base** | The branch this PR directly targets (`gh pr view --json baseRefName`). Never assumed |
| **blocker** | Another ticket named in this ticket's `## Blocked by` section |
| **finding** | One item produced by the configured code-review skill |
| **round** | One run of the configured review-round skill |

## Loop map

```
    to-tickets             implement <N>             review-round <N>         human
──────────────▶ tickets ─────────────▶ PR opened ──────────────▶ round comment ──────▶ land <N...> ──▶ merged
       ready            in-progress            in-review           awaiting-review      (args = signature)
                        → awaiting-review      → awaiting-review
                                                or blocked
```

The merge judgment always terminates at the human — and the human expresses it by **invoking `land`
and naming (or picking) the tickets to merge**. `land` is human-fired only, so its arguments — or
its queue pick — *are* the merge signature; it asks one further question only when a PR diverged
from what the signer could have known (a refused ticket, a predicted conflict, a head that moved
after review). There is no signature state to attach beforehand — recording the same judgment twice
(a marker, then the command) was duplication, and the marker was the copy that went stale.

## Tracker adapter

The loop's concepts (states, edges, tickets) are platform-neutral; **how they are represented is the
adapter's business alone**. Skills never call the platform CLI/API for ticket state directly — they run
adapter verbs. PR-side operations (`gh pr view/comment/merge`) are **not** tracker verbs: PRs, review
rounds and the merge queue live on GitHub regardless of which tracker a project uses.

Every skill resolves the adapter once at start:

```bash
ROOT=$(git rev-parse --show-toplevel)
TRACKER="$ROOT/.claude/agent-loop/tracker.sh"                       # 1. project's own script
if [ ! -x "$TRACKER" ]; then
  NAME=$(sed -n 's/^TRACKER=//p' "$ROOT/.claude/agent-loop/config" 2>/dev/null)
  TRACKER=~/.agents/skills/agent-loop/adapters/${NAME:-github}/tracker.sh   # 2. named / 3. github
fi
```

Adapters live side by side in `adapters/<name>/tracker.sh`, all generic — anything project-specific
(team key, status names, credentials) comes from the repo's `.claude/agent-loop/config` and
`.env.local`, which the adapter reads itself. A project therefore switches tracker by committing one
`TRACKER=<name>` line; shipping a full `tracker.sh` is the escape hatch for a platform no shared
adapter covers. Adapter output is JSON on stdout unless a verb says otherwise.

| Verb | Contract |
|---|---|
| `list <state>` | open tickets in one loop state: `[{number,title,body,updatedAt}]` |
| `list-startable` | `ready` tickets with no open native blocker: `[numbers]`. **Ordering hint only** — the index lags writes and misses body-only edges; `implement`'s blocker gate is the verdict |
| `show <id>` | `{number,title,body,state,labels,url}` — `state` is the platform's open/closed |
| `blockers <id>` | native dependency edges with their open/closed state: `[{number,state}]` |
| `add-edge <id> <blocker>` | register a native blocked-by edge |
| `transition <id> <state>` | clear **every** loop state marker, then set `<state>` — a ticket is in exactly one state |
| `comment <id> <body-file>` | post a ticket comment |
| `pr-for <id> [--merged]` | the PR bound to this ticket: `[{number,url,headRefName,baseRefName}]`. Handles search-index lag and false full-text matches internally |
| `link-line <id>` | prints the text a PR body must carry to bind PR → ticket (GitHub: `Closes #<id>`) |
| `create <title> <body-file>` | create a ticket in `ready` state, print its reference |
| `landed <id>` | after the merge: verify the tracker recorded completion; close it only if the platform's own automation missed |

## State machine

Tracker state is the **single source of truth** for where a ticket sits in the loop. A PR's draft flag is
never used as a state signal — two signals saying the same thing will drift. Therefore **PRs are always
opened non-draft.**

| State | Meaning | Set by |
|---|---|---|
| `ready` | A complete spec an agent may pick up — **blocked tickets carry it too** | `to-tickets` |
| `in-progress` | Being implemented | `implement` |
| `awaiting-review` | Human can read it, or a round can be fired | `implement` · `review-round` |
| `in-review` | A round is running = the branch already has a writer | `review-round` |
| `blocked` | Cannot proceed without a human decision | `implement` · `review-round` · `land` |

How a state is stored (GitHub: `ready-for-agent` / `agent-*` labels) is the adapter's mapping; skills
use only the names above.

Mergeability is a judgment, and judgment is the human's — it is expressed by firing `land` with the
tickets to merge (see [Loop map]). `land` drains that signed set: it orders the queue, syncs each
base, assembles conflict resolutions from both sides' documented intents, and merges. A conflict with
no union of intents (the two sides change the same behaviour incompatibly) exceeds the signature's
delegation and bounces to `blocked` — the human signed both PRs without knowing they contradict.

## Blocking edges

Every blocker is recorded **twice, and both are mandatory** — the two copies have different readers:

| Where | Read by |
|---|---|
| `## Blocked by` in the ticket body | humans · `implement`'s blocker gate |
| the tracker's native dependency edge | `list-startable` · `blockers` |

Body prose is invisible to structured queries, so a ticket carrying the body edge alone reads as
*startable* in every listing. Whoever notices a missing edge registers it on the spot:

```bash
"$TRACKER" add-edge <N> <blocker>
```

Always read edges through `blockers <id>`, never the raw platform API.

**State never carries blocked-ness** — that would be a third copy of the same fact, and the third copy is
the one that drifts. Merging or splitting tickets moves the edges too, not just the prose.

## Worktree convention

Path is `.claude/worktrees/issue-<N>-<slug>`, branch is `agent/issue-<N>-<slug>`, where `slug` is the
kebab-case ticket title.

A fresh worktree needs two things before it is usable:

1. `pnpm install` — monorepo pnpm links are installed per worktree. Without it check-types breaks.
2. Copy `routeTree.gen.ts` from the main checkout — it is gitignored, so a new worktree lacks it.
   Never run `tsr generate`; it silently drops the `declare module` block. Applies to every app
   that carries a generated route tree.

`implement`'s `scripts/prepare-worktree.sh` does all of this in one call.

**Keep the worktree until the PR merges.** Rework and later rounds reuse the same one.

## Output convention

Everything a human reads is written in **Korean**: PR titles and bodies, ticket bodies and comments, round
comments, commit messages.

There is exactly one path to a commit:

```
comment-cleaner (no argument)  →  pnpm check-types:<app>  →  commit skill  →  git push
```

- `comment-cleaner` goes **before** `commit`. Comment edits are code changes, and the rounds that
  follow will read them.
- Typecheck through the app script only: `pnpm check-types:<app>`, one per app in the monorepo.
  Never call `tsc` or `turbo run` directly.
- Commit through the `commit` skill only. Never run `git commit` directly. The one exception is
  **completing a conflict resolution** in `land` (`git commit --no-edit`): a resolution authors
  nothing, so the authored-change pipeline does not apply.

## Never

- **Never merge** — except `land`, and only a PR the human named or confirmed **in that run**.
  The only path work takes to the base branch is the PR.
- **Never commit or push to the base branch**, whatever it is named.
- **Never force-push. No exceptions** — nothing in this loop rewrites a pushed branch.
- **Never bypass the adapter for ticket state** — a raw platform call is a second writer.
- **Never launch a paid human-triggered review mode from Bash.** The human starts it explicitly.
