---
name: to-tickets
description: Breaks a plan, spec, or the current conversation into flow-unit tracer-bullet GitHub issues written in Korean — each owning one complete user-facing flow end to end, safe to implement in parallel with its siblings, declaring its blocking edges, and labelled ready-for-agent. Binds designed UI work to its Figma node as the design source of truth and spells out only what the design does not answer. Use whenever the user asks to turn a plan, spec, discussion, decision, or parent issue into tickets or issues, or to split/break down work into implementable units. Triggers on English phrasings like "turn this into tickets", "file issues for this", "break this down into issues", "create GitHub issues", "split this plan into tasks", "make tickets from this discussion", and on Korean phrasings like "티켓으로 쪼개줘", "티켓 만들어줘", "이슈 발행해줘", "이슈로 끊어줘", "이슈 만들어줘", "작업 단위로 나눠줘", "티켓 발행", "이 계획 티켓화해줘".
---

# to-tickets

Break a plan, spec or conversation into a set of **tickets** — tracer-bullet vertical slices, each
declaring the tickets that block it. Published tickets carry the `ready-for-agent` label and are picked up
by `/implement`.

**Read `~/.claude/skills/agent-loop/CONTRACT.md` before starting** — the labels and output convention of
the loop these tickets enter live there.

## A ticket binds its truths, it does not restate them

**Each ticket is a complete spec for its unit of work.** The implementing agent reads only the issue body,
and that body's information density is the ceiling on implementation quality. The way to raise density is
binding, not copying:

- **Design/UX truth = the Figma node** (when the surface has a separate design, e.g. a mobile app). The node
  doubles as the PRD: its frames and flows say what the feature is.
- **Domain and current-behaviour truth = the code and docs** (CONTEXT.md, ADRs).
- **The ticket body = the goal, pointers to both truths, and the delta** — everything neither truth
  expresses: what the design doesn't answer (states, edge cases, data rules) and what the code doesn't yet
  contain (new API contracts, schema impact, domain rules).

Never copy design content into the ticket as prose or screenshots — it breaks the single source of truth
and goes stale on the first design edit. Link the node; the implementer fetches it live.

## Progress checklist

```
Ticket breakdown progress:
- [ ] 1  Gather context
- [ ] 2  Explore the codebase (optional)
- [ ] 3  Gather design truth (only if designed UI is involved)
- [ ] 4  Draft vertical slices and their blocking edges
- [ ] 5  Quiz the user — iterate until approved
- [ ] 6  Publish as GitHub issues in dependency order
```

## 1. Gather context

Work from whatever is already in the conversation. If the user passes a reference (a spec path, an issue
number or URL) as an argument, fetch it and read its full body and comments.

## 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state. Ticket titles and
descriptions should use the project's domain glossary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor. "Make the change easy, then make the easy change."

## 3. Gather design truth

Skip for pure backend/infra work. When a slice touches a UI surface that has a separate design:

1. **Collect the Figma node links** covering the work — from the conversation, or ask the user. For
   designed UI a missing link is a blocker, not a nice-to-have: without it the ticket has no design truth
   to bind to.
2. **Read the design as the PRD.** Walk the frames and flows with
   `mcp__claude_ai_Figma__get_metadata` (structure) and `mcp__claude_ai_Figma__get_screenshot` (visuals):
   screen inventory, navigation, the states and interactions the design *does* show. Let slice boundaries
   align with frames or flows where that is the natural cut.
3. **Gap analysis.** For each slice, list the questions the design does not answer: loading/empty/error
   states, interaction edge cases, data rules (sorting, paging, limits), copy for undrawn states. Resolve
   each from code or docs where possible, recording the source; carry the unresolved ones to [5].
4. **Reverse check.** Where the design contradicts code reality — data that doesn't exist, domain
   vocabulary that differs from the glossary, flows that conflict with an ADR — surface it to the user.
   Design and codebase complement each other in both directions; neither silently wins.

## 4. Draft vertical slices

**Read `~/.claude/skills/to-tickets/references/slicing-rules.md` and cut according to it.** It defines the
vertical slice, hard vs soft blocking edges, the ban on forward-pointing dependencies, migration hoisting,
and the expand–contract exception for wide refactors.

Give each ticket its **blocking edges** — the other tickets that must complete before it can start. A
ticket with no blockers can start immediately.

## 5. Quiz the user

Present the breakdown as a numbered list. For each ticket:

- **Title**
- **Blocked by**: which other tickets must complete first, if any
- **What it delivers**: the end-to-end behaviour this ticket makes work
- **Open design gaps**: the questions from [3] that code and docs could not resolve, if any

Ask:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct — does each ticket depend only on tickets that genuinely gate it, and is
  **every edge soft** (each side merge-consistent alone)? A hard edge surfacing here means two tickets
  should be fused, not sequenced.
- Should any tickets be merged or split further?
- Every unresolved design gap, as a concrete question with your recommended answer.
- **What is out of scope this time?** Name the adjacent behaviour a reader could reasonably assume is
  included but isn't — the neighbouring surface, the follow-up state, the case the design shows but this
  round won't build. Propose the list; the user confirms or corrects it.

Each confirmed out-of-scope item goes into the `## 목표` of the ticket it borders, as one closing line
("여기까지 — ○○ 는 이번 범위 아님"). Tickets describe only what to build, so an unstated boundary is
invisible to the implementing agent; putting it in the ticket the agent actually reads beats a separate
scope document it never opens.

Iterate until the user approves. **Never publish a ticket with an open design question** — the answer goes
into the ticket's gap list with its source recorded as the user's decision. A ticket is always a complete
spec; the implementing agent should never hit `agent-blocked` on a question this step could have settled.

## 6. Publish

Publish one GitHub issue per ticket **in dependency order (blockers first)** so each ticket's blocking
edges can reference real numbers.

Write each blocking edge into the body's `## Blocked by` **and** GitHub's native dependency — both are
mandatory, per CONTRACT's [Blocking edges]. A ticket with the prose alone reads as startable in every
listing.

Apply the `ready-for-agent` label to every published ticket, **blocked ones included** — the label says
the spec is complete, not that work can start today. Startability comes from the edges.

**Issue bodies are written in Korean.** Do not close or modify the parent issue.

Avoid specific file paths and code snippets — they go stale fast. Two exceptions, both decision-rich by
nature: API contracts in 서버 구현사항, and a snippet a prototype produced that encodes a decision more
precisely than prose can (state machine, reducer, schema, type shape) — inline it trimmed to the
decision-rich parts and note briefly that it came from a prototype.

<issue-template>

## Parent

트래커의 부모 이슈 참조(원본이 기존 이슈였을 때만, 아니면 이 섹션 생략).

## 목표

이 티켓이 동작하게 만드는 종단 간 동작 — 사용자 관점에서, 랜딩하면 무엇이 데모 가능해지는가.
레이어별 구현 목록이 아니다. 확정한 범위 밖 항목과 맞닿으면 그 경계 한 줄로 닫는다.

## 디자인

디자인된 UI 가 있을 때만. 없으면 생략.

- **Figma node**: 링크. 디자인/UX 의 단일 진실 — 구현자가 구현 시점에 MCP 로 노드를 가져오고,
  시각·UX 질문에서는 노드가 이 이슈 텍스트를 이긴다. 스크린샷을 붙이거나 디자인을 산문으로 옮기지 않는다.
- **Figma가 답하지 않는 것**: 갭 목록 — 상태(로딩/빈/에러), 인터랙션 엣지 케이스, 데이터 규칙,
  그려지지 않은 카피. 갭 하나에 불릿 하나, 각각 답과 그 답의 출처(코드·문서·사용자 결정).

## 서버 구현사항

이 슬라이스를 위해 백엔드가 제공해야 하는 것: API 계약(엔드포인트, 요청/응답 형태), 도메인 규칙,
스키마 영향. 계약은 결정이 밀집한 영역이므로 정확하게 적는다 — 요청/응답의 타입 수준 스케치 환영.

## UI 구현

프론트가 디자인을 어떻게 실현하는가: UI 가 사는 라우트/화면, 재사용할 기존 컴포넌트(파일 경로가 아니라
도메인 용어 이름), 상태별 렌더링, Figma 컴포넌트 → 코드 컴포넌트 매핑 힌트.

## Acceptance criteria

- [ ] 사람이 눈과 손으로 확인 가능한 기준만.

## Blocked by

- 이 티켓을 막는 티켓 각각의 참조, 또는 "None — can start immediately".

</issue-template>

## TODO — 다른 런타임 대응

이 스킬은 `~/.claude/skills/agent-loop/CONTRACT.md` 를 읽고 Claude 전용 루프(`/implement` ·
`/review-round` · `/land`)로 티켓을 넘기며, 디자인 진실을 Claude 쪽 Figma MCP
(`mcp__claude_ai_Figma__*`)로 가져와서 `~/.claude/skills/` 에 있다.
Codex 등에서 어떻게 대체할지 미정.
