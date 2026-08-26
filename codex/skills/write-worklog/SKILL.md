---
name: write-worklog
description: Analyzes a Codex development task (the current in-context conversation, or a Codex transcript file the user points to) and writes a structured Korean engineering work log to ~/Desktop/worklog/YYYY-MM-DD.md — capturing decisions and trade-offs, implementations with rationale, recall-optimized concept explanations, debugging narratives (symptom→hypothesis→investigation→root cause→fix), and the causal flow between them, with inline git commit references. Use when the user asks to document, summarize, or log a development task or session.
---

# Write Worklog

Analyze a session and write a Korean engineering work log to
`~/Desktop/worklog/YYYY-MM-DD.md`. The skeleton, per-section how-to, quality
bar, and commit format all live in **`references/worklog-structure.md` — read
it before writing.**

**Output language:** these SKILL instructions are in English, but the work log
you produce is written in **Korean**. Technical terms, library/framework names,
and concepts that read naturally in English stay in English (hydration, stale
closure, idempotency, optimistic, `onMutate`, thundering herd, etc.) — do not
force-translate them. The Korean section headers shown in the structure
reference's templates are literal output strings: emit them as-is.

## Input modes (determine first)

- **Default — document the current conversation**: if the user does not point
  to a separate file, the target is the session in progress. Analyze your **own
  context directly** — no parsing step. (Most invocations are this mode.)
- **Explicit — transcript file**: if the user gives a `.jsonl` path or names a
  past session, document that file. Do not read the whole file; build a digest
  with the extractor:
  ```bash
  python3 ~/.codex/skills/write-worklog/scripts/extract_transcript.py <path.jsonl> --results [--thinking]
  ```
  `--results` surfaces tool output (useful for debugging sessions); `--thinking`
  includes recorded Codex reasoning summaries when present, never encrypted
  reasoning. Turn both on when debugging is central. Transcripts usually live at
  `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`. The digest header's
  **`Session date (KST)`** value is the worklog filename / H1 date — a past
  session files under **the day the work happened, not today**. Pass that date
  as the 3rd argument (date_override) to the context script in step 1.

## Workflow

### 1. Gather runtime context
Run from the repo root (current working dir):
```bash
bash ~/.codex/skills/write-worklog/scripts/worklog_context.sh
# Documenting a past transcript? Pass that session's date as the 3rd arg:
# bash ~/.codex/skills/write-worklog/scripts/worklog_context.sh ~/Desktop/worklog 25 2026-06-08
```
Read `DATE`, `TARGET` (file path), `MODE` (create/append), `SESSION_ID`, and the
recent-commit list (`hash|date|author|subject`) from the output. In
current-session mode, run with no args (today's date). Codex does not expose a
stable task-id shell variable on every surface, so omit the task-id segment when
`SESSION_ID` is `unknown`. In explicit-file mode, pass the digest's
`Session date (KST)` as the 3rd arg so it files under that date, and use the
digest header's own `Session ID` line instead (the transcript's `<uuid>.jsonl`
filename) — the two are unrelated sessions, don't mix them up. If this is not
a git repo, the commit section comes back empty — proceed without commit refs.

### 2. Load the structure & quality bar
**Read `references/worklog-structure.md`.** The output-location rules, document
skeleton, commit-reference format, and per-section how-to + quality bar
(decision / implementation / concept / debugging / narrative) all live there.
Skipping it means missing the quality bar.

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
  one Write call takes minutes with no visible progress, reads as a hung/broken
  skill, and invites the user to interrupt before it ever finishes (observed:
  a 500+ line file caused a multi-minute stall and the append was lost after
  repeated interrupts). Instead, do a **true append that never touches existing
  bytes**:
  1. Create a scratch file with `apply_patch`. It must contain only the new
     session block, starting with the `##` heading.
  2. Run:
     ```bash
     bash ~/.codex/skills/write-worklog/scripts/append_worklog.sh <TARGET> <scratch-file>
     ```
     The helper appends the divider and the new block without rewriting existing bytes.
  This is O(new content) regardless of how large the day's file already is.
  Do not re-emit the existing H1 (`#`); do not alter a single character of the
  existing sessions.

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
