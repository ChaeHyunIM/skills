---
name: comment-cleaner
description: Use right before committing changed code, when a diff adds comments that restate the code or narrate change history, patch rationale, or PR/issue references, or when asked to clean up comments (주석 정리).
---

# comment-cleaner

Clean up comments to match the project rules. Do not change behavior — **comments only**. Use it after finishing an implementation, especially **right before committing**, to leave only comments that fit the current code structure.

**Any comment kept or written must be in Korean.**

## Scope

- A path argument → that file/directory.
- No argument → code files (`.ts` / `.tsx`, etc.) in the current working changes (`git diff --name-only` + staged).

## Core principle: default to no comments

Well-named identifiers and the code itself already explain _what_ the code does. A comment exists only to preserve the **WHY** — a reason, constraint, or non-obvious intent that cannot be derived from reading the code.

## Delete (remove on sight)

### Top priority — history / patch-narrative comments (always remove)

Anything like "this was originally X, changed to Y, and patched this way because it used to be Z." Remove every comment that explains the code's **past**. What remains must describe **only the current code structure**.

- change-history / patch-rationale narration
- references to the current task, PR, or issue (`// #123 대응`, `// used by the X screen`) — these belong in the PR description / git log and rot as code changes
- "why it's missing" notes left next to removed/dead code

### Other deletions

- restating what the code already shows (`// 유저를 가져온다` above `getUser()`)
- JSDoc that paraphrases the signature/types in prose
- restating something already obvious from a variable/function name

## Keep (or tidy) — WHY only

Keep only when the code is ambiguous on a plain read:

- hidden constraints / invariants (external API rate limits, ordering dependencies)
- counter-intuitive behavior or a surprising decision
- a workaround for a specific bug/issue, with its background
- a non-obvious choice that would make a reader pause and ask "why this way?"

Tidy any kept comment to the **current code** (strip past narration).

## Litmus test

If deleting the comment would leave a future reader confused, keep it. Otherwise delete it.

## Rules

- Comments kept or written are in **Korean**.
- Applies to inline, block, JSDoc/TSDoc, and TODO/FIXME.
- **Never modify code logic** — add / remove / edit comments only.
- Add a new comment only, conservatively, when a genuinely necessary WHY is left undocumented.
