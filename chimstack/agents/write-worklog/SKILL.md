---
name: write-worklog
description: Use when the user asks to write a worklog or record the dev session in a log file (워크로그, 세션 정리, 작업 기록). Not for a session summary answered in chat.
---

# Write Worklog

Analyze the session in progress and write a Korean engineering work log to
`~/Desktop/worklog/YYYY-MM-DD.md`. The skeleton, per-section how-to, quality
bar, and commit format all live in **`references/worklog-structure.md` — read
it before writing.**

**Output language:** these SKILL instructions are in English, but the work log
you produce is written in **Korean**. Technical terms, library/framework names,
and concepts that read naturally in English stay in English (hydration, stale
closure, idempotency, optimistic, `onMutate`, thundering herd, etc.) — do not
force-translate them. The Korean section headers shown in the structure
reference's templates are literal output strings: emit them as-is.

**Input:** the session in progress. Analyze your **own context directly** — no
parsing step.

**Paths:** `<skill-dir>` below is the directory that holds this SKILL.md.
Substitute its real path — the script is not in the working directory.

## Workflow

### 1. Gather runtime context
Run from the repo root (current working dir):
```bash
bash <skill-dir>/scripts/worklog_context.sh
```
Read `DATE`, `TARGET` (file path), `MODE` (create/append), `SESSION_ID`, and the
recent-commit list (`hash|date|author|subject`) from the output. `SESSION_ID`
comes from the runtime's session variable and is `unknown` when the runtime
does not expose one (then omit the session-id segment). If this is not a git
repo, the commit section comes back empty — proceed without commit refs.

### 2. Load the structure & quality bar
**Read `references/worklog-structure.md`.** The output-location rules, document
skeleton, commit-reference format, and per-section how-to + quality bar
(decision / implementation / concept / debugging / narrative) all live there.

### 3. Analyze the session — extract 5 elements
Sweep the session and keep only what carries meaning (not every line is
material):
- **Decisions**: branches where options were actually weighed, or where the user
  changed or locked a direction. Drop side comments and throwaway guesses.
- **Implementations**: code/config/queries/architecture that actually changed —
  what, why, and any concept embedded in it.
- **Concepts**: non-trivial concepts that appeared (a library, pattern, protocol,
  algorithm) — candidates to explain for recall. **The section to invest the
  most in.**
- **Debugging**: if there was a bug — symptom → hypothesis → investigation
  (including ruled-out paths) → root cause → fix.
- **Narrative**: how the above causally connected across the session.

Match the session type (implementation-focused / debugging-focused / mixed /
pure exploration) and drop sections that don't apply.

### 4. Map commits
From step 1's commit list, pick only the commits **this session actually
produced** (match by subject/topic and time) and cite them under the relevant
section (implementation/decision/debugging) headers with a `📌 커밋 참조:` line.
Format is structure doc §3. Do not cite unrelated or pre-session commits.

### 5. Write / append
- **MODE=create**: create the `TARGET` directory if missing, then write the H1
  day title + the session block.
- **MODE=append**: do **not** read the whole existing file and write it back —
  on a file that has grown to hundreds of lines, re-emitting all of it inside
  one file-write call takes minutes with no visible progress, reads as a
  hung/broken skill, and invites the user to interrupt before it ever finishes.
  Instead, do a **true append that never touches existing bytes**:
  1. Write the new session block ONLY, starting at its `##` heading, to a
     scratch file outside the repo — the session scratchpad if the runtime
     gives one, otherwise a `mktemp -d` directory.
  2. Run:
     ```bash
     { printf '\n\n---\n\n'; cat <scratch-file>; } >> <TARGET>
     ```
  This is O(new content) regardless of how large the day's file already is.
  Do not re-emit the existing H1 (`#`); do not alter a single character of the
  existing sessions — the scratch file must contain only the new block.

### 6. Report
Tell the user the saved path and, in a line or two, which session/sections it
captured.

## Core principles
- The quality bar is owned by `references/worklog-structure.md`. Read it before writing.
- **Invest the most in concept explanations** — lean detailed over terse, so they
  re-onboard with zero warm-up weeks later.
- Do not state speculation as fact. If the session never confirmed it, omit it or
  mark it "추정" (presumed).
- Write the work log in Korean; keep technical terms, library names, and
  English-natural concepts in English.
