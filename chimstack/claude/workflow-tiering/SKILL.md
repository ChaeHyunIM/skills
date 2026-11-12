---
name: workflow-tiering
description: Assign model and effort per agent() call in a Workflow script, rating each stage on two independent axes instead of letting every stage inherit the session model. Use before writing or editing any Workflow tool script, before fanning out several subagents with the Agent tool, before /code-review generates its review workflow, and whenever a request involves orchestration ("write a workflow", "ultracode", "fan out agents", "모델 배분", "에이전트 분배", "워크플로우 짜줘").
---

# Workflow tiering

Assign, do not inherit. Rate every `agent()` call on both axes before writing the script. Omit `model` only where the rating genuinely lands on "inherit".

## Process

1. List the stages before writing any script code.
2. Rate each stage's `model` on axis 1.
3. Rate the same stage's `effort` on axis 2, from scratch — never derive it from the model.
4. Write both into the `agent()` options.
5. Record both in each `meta.phases` entry so the user can see the allocation.
6. Audit: if the two axes move together on every stage, axis 2 was skipped. Re-rate.

## Axis 1 — model

Rates **how much the quality of judgment matters**.

| Test | model | Typical stages |
|---|---|---|
| Wrong here voids the whole run, and the call is subtle | `fable` | final judge, synthesis, architecture decisions, arbitrating conflicting findings |
| Wrong here hurts, but the criteria are explicit | omit (inherit) or `opus` | exploration, design, planning, review, bug hunting, evidence gathering |
| Transcribing an earlier stage's result | `sonnet` | writing code or docs, assembling reports, filling schemas |
| The rules are already fully specified | `haiku` | bulk substitution, enumeration, format conversion, labeling |

## Axis 2 — effort

Rates **how much reasoning it takes to reach the answer** — independent of axis 1.

| Test | effort |
|---|---|
| Apply a rule; nothing to reconsider | `low` |
| The answer comes out one way | `medium` |
| Several candidates to compare, or wide context | `high` |
| Candidates conflict; the answer needs backtracking | `xhigh` |
| A wrong answer here cannot be recovered downstream | `max` |

Mismatched pairs are the normal case:

- `sonnet` + `high` — narrow context, but real candidate comparison (picking a schema shape inside one known file).
- `fable` + `medium` — decisive call on already-distilled input (breaking a 2:1 verify tie).
- `opus` + `max` — tracing a root cause back through a wide codebase.

## Allocation rules

- **Cheap on fan-out, expensive on fan-in.** N parallel finders rarely need the top tier; the single synthesis that merges them does. Inverting this multiplies cost by N.
- **Effort compounds on fan-out too.** `high` across 12 parallel agents is 12×. Drop fan-out one grade and recover misses in the next round (loop-until-dry) instead.
- **Stage verification.** First-pass refuters sit on axis 1's inherit tier; escalate a single `fable` arbiter only when their votes split. Never start with everyone at `fable`/`max`.
- **Later ≠ costlier.** A final stage that serializes results to JSON is bottom tier. Rate by role, not by position in the pipeline.
- **Respect `agentType`.** A custom subagent may pin its own model; leave `model` unset unless there is a reason to override.

## Limits

- A workflow with only one model tier, or only one effort grade, is mis-rated — unless every stage truly shares one character (e.g. the same mechanical edit across five files). State that reason in one line when it happens.
- Do not raise cost past the user's approved scope (everyone at `fable`, everyone at `max`). Ask first.
- A user-specified model or effort for a stage overrides these tables.

## Script shape

```js
export const meta = {
  name: 'audit-and-fix',
  description: '...',
  phases: [
    { title: 'Scan',   detail: 'enumerate target files', model: 'haiku · low' },
    { title: 'Review', detail: 'find defects per axis',   model: 'inherit · max' },
    { title: 'Judge',  detail: 'rule on each defect',     model: 'fable · medium' },
    { title: 'Write',  detail: 'assemble the report',     model: 'sonnet · high' },
  ],
}

const files = await agent('List the files in scope.', {
  phase: 'Scan', model: 'haiku', effort: 'low', schema: FILES,
})

const found = await pipeline(
  DIMENSIONS,
  d => agent(d.prompt, { phase: 'Review', effort: 'max', schema: FINDINGS }),
  r => parallel(r.findings.map(f => () =>
    agent(`Refute this finding: ${f.title}`, {
      phase: 'Judge', model: 'fable', effort: 'medium', schema: VERDICT,
    }).then(v => ({ ...f, v })))),
)

return agent(`Write the report from these findings: ${JSON.stringify(found)}`, {
  phase: 'Write', model: 'sonnet', effort: 'high',
})
```

The axes diverge on three of the four stages:

- **Review** — model inherits (explicit criteria), effort is `max` (wide codebase, needs backtracking).
- **Judge** — `fable` (a wrong verdict voids the report), but `medium` (input is one distilled finding).
- **Write** — `sonnet` (transcription), but `high` (deciding what to keep is candidate comparison).

## /code-review

The `/code-review` skill builds a Workflow with five fixed phases and, by default, sets neither `model` nor `effort` on any `agent()` call — every stage inherits. Rate them:

| Phase | model | effort | Why |
|---|---|---|---|
| Scope | inherit | `medium` | criteria are explicit, input is one diff |
| Find | inherit | `high` | fan-out; one grade below Sweep, misses get caught later |
| Verify (1st) | inherit | `high` | one verifier per (file, line) group, as the script already does |
| Verify (2nd) | `fable` | `high` | escalation over `PLAUSIBLE` verdicts only — see below |
| Sweep | inherit | `max` | one agent, wide context, hunting for what everyone missed |
| Synthesize | `fable` | `medium` | fan-in; a bad merge or ranking voids the report, but the input is already distilled |

**The level the user passed (`high` / `xhigh` / `max`) is a ceiling, not a uniform setting.** At `max`, Sweep gets `max` and the rest stay below it. Never flatten every stage to the requested level.

### Escalating unresolved verdicts

Verify runs one agent per location, so there are no split votes to arbitrate. The uncertainty signal is the `PLAUSIBLE` verdict — `CONFIRMED` and `REFUTED` are settled. Add a second pass over that subset only:

```js
const verified = await verifyGroups(candidates)
const unresolved = verified.filter(c => c.verdict === "PLAUSIBLE")

const arbitrated = await parallel(unresolved.map(c => () =>
  agent(ARBITER_PROMPT(c), {
    label: "arbitrate:" + c.file.split("/").pop(),
    phase: "Verify", model: "fable", effort: "high", schema: VERDICT_SCHEMA,
  }).then(v => v ? { ...c, verdict: v.verdict, evidence: v.evidence } : c)))
```

`model: "fable"` overrides inheritance for that call alone — the rest of Verify stays on the session model. Cost scales with the `PLAUSIBLE` count, not the candidate count. Skip the pass entirely when that subset is empty.
