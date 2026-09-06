---
name: to-tickets
description: Breaks a plan, spec, or the current conversation into flow-unit tracer-bullet tracker tickets written in Korean — each owning one complete user-facing flow end to end, safe to implement in parallel with its siblings, declaring its blocking edges, and published in the ready state. Binds designed UI work to its Figma node as the design source of truth and spells out only what the design does not answer. Use whenever the user asks to turn a plan, spec, discussion, decision, or parent issue into tickets or issues, or to split/break down work into implementable units. Triggers on English phrasings like "turn this into tickets", "file issues for this", "break this down into issues", "create GitHub issues", "split this plan into tasks", "make tickets from this discussion", and on Korean phrasings like "티켓으로 쪼개줘", "티켓 만들어줘", "이슈 발행해줘", "이슈로 끊어줘", "이슈 만들어줘", "작업 단위로 나눠줘", "티켓 발행", "이 계획 티켓화해줘".
---

# to-tickets

Break a plan, spec or conversation into a set of **tickets** — tracer-bullet vertical slices, each
declaring the tickets that block it. Published tickets land in the `ready` state and are picked up
by the `implement` skill.

**Read `~/.agents/skills/agent-loop/CONTRACT.md` before starting** — the states, the tracker adapter and
the output convention of the loop these tickets enter live there. Resolve `$TRACKER` per CONTRACT's
[Tracker adapter] before publishing.

**Read `~/.agents/skills/agent-loop/references/acceptance-criteria.md`** for 완료 조건 authoring,
verification, PR evidence and land-only issue checkboxes.

## A ticket binds its truths, it does not restate them

**Each ticket defines the outcomes, boundaries and constraints of its unit of work.** Explore the
codebase deeply enough to establish feasibility and dependencies, but write the issue as natural-language
What. The implementer chooses How and explains it in the PR. Bind supporting truths instead of copying
a code investigation into the issue:

- **Design/UX truth = the Figma node** (when the surface has a separate design, e.g. a mobile app). The node
  doubles as the PRD: its frames and flows say what the feature is.
- **Domain and current-behaviour truth = the code and docs** (CONTEXT.md, ADRs).
- **The ticket body = the goal, pointers to both truths, and the delta** — everything neither truth
  expresses: required behaviour, states, data rules and scope boundaries. Carry a technical contract only
  when it is already required by a consumer or an external integration, not merely an implementation idea.

Never copy design content into the ticket as prose or screenshots — it breaks the single source of truth
and goes stale on the first design edit. Link the node; the implementer fetches it live.

## Progress checklist

```
Ticket breakdown progress:
- [ ] 1  Gather context
- [ ] 2  Explore the codebase (optional)
- [ ] 3  Gather design truth (only if designed UI is involved)
- [ ] 4  Draft vertical slices and edges; write 완료 조건 and compare goal ↔ conditions
- [ ] 5  Pull the policy gaps out of every slice
- [ ] 6  Quiz the user — iterate until approved
- [ ] 7  Publish to the tracker in dependency order
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
2. **Read the design as the PRD.** Walk the frames and flows through the Figma MCP — its metadata
   tool (structure) and screenshot tool (visuals); use the connected MCP's actual tools, never guess
   at tool names:
   screen inventory, navigation, the states and interactions the design *does* show. Let slice boundaries
   align with frames or flows where that is the natural cut.
3. **Gap analysis.** For each slice, list the questions the design does not answer: loading/empty/error
   states, interaction edge cases, data rules (sorting, paging, limits), copy for undrawn states. Resolve
   each from code or docs where possible, recording the source; carry the unresolved ones to [6].
4. **Reverse check.** Where the design contradicts code reality — data that doesn't exist, domain
   vocabulary that differs from the glossary, flows that conflict with an ADR — surface it to the user.
   Design and codebase complement each other in both directions; neither silently wins.

## 4. Draft vertical slices

**Read `~/.agents/skills/to-tickets/references/slicing-rules.md` and cut according to it.** It defines the
vertical slice, hard vs soft blocking edges, the ban on forward-pointing dependencies, migration hoisting,
and the expand–contract exception for wide refactors.

Draft each ticket's 완료 조건 using the shared reference: observable results, goal ↔ conditions
comparison, and a pre-merge verification route. Fold genuinely post-release observations into owned
follow-up tickets and their native edges in the proposed breakdown; do not lose the original scope.

Give each ticket its **blocking edges** — the other tickets that must complete before it can start. A
ticket with no blockers can start immediately.

## 5. Pull the policy gaps out of every slice

This step runs for **every** slice — backend and infra included, where [3] never ran. A design gap is a
question about what the screen looks like; a **policy gap** is a question about what the product does, and
it is the one an implementing agent silently answers in code.

Judge it yourself. Whenever you would settle a question by picking a reasonable answer rather than reading
one out of the spec, the code, CONTEXT.md or an ADR, that is a 미결 정책 — and it does not get an answer
invented here. Where you do find the answer, record its source.

**Never resolve a 미결 정책 in chat alone.** A chat answer binds nobody and is gone next session; the
decision belongs to the team, on the tracker, where it can be read months later. Post every one as a single
tracker comment before publishing:

```bash
"$TRACKER" comment <parent-id> <body-file>
```

Post it on the **parent ticket** when the run came from one. With no parent, ask the user which ticket to
hang it on — never skip the record because there is no obvious home for it.

```markdown
## 미결 정책 — <티켓 제목 또는 기능 영역>

### 1. <질문 한 줄>
- 걸리는 지점: 어떤 케이스에서 답이 필요한지
- 선택지: A — <사용자에게 무엇이 달라지는가> / B — <같은 형식>
- 추천: <A 또는 B, 한 줄 근거>
```

## 6. Quiz the user

Before presenting the breakdown, call the adapter once:

```bash
"$TRACKER" planning-context
```

Treat its `properties` array as a capability response, not as a fixed tracker schema. When it is non-empty,
**read `~/.agents/skills/to-tickets/references/planning-properties.md`** and build the proposals from it. When it
is empty, skip property work entirely. The skill never branches on a platform name.

Present the breakdown as a numbered list. For each ticket:

- **Title**
- **Blocked by**: which other tickets must complete first, if any, and in one clause why (this becomes the
  native edge plus a sentence of background in the body — never a body list; CONTRACT's [Blocking edges])
- **What it delivers**: the end-to-end behaviour this ticket makes work
- **완료 조건**: show the actual checkbox text, including backend-only outcomes where applicable
- **Open design gaps**: the questions from [3] that code and docs could not resolve, if any
- **미결 정책**: the policy gaps from [5], if any, each with its recommended answer
- **Tracker properties**: each proposed native value (or `unset`) with one short reason; omit when the adapter
  advertises no properties

Ask:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct — does each ticket depend only on tickets that genuinely gate it, and is
  **every edge soft** (each side merge-consistent alone)? A hard edge surfacing here means two tickets
  should be fused, not sequenced.
- Should any tickets be merged or split further?
- Every unresolved design gap and every 미결 정책, as a concrete question with your recommended answer.
- Accept all proposed tracker properties, or name only the overrides. Ask once for the whole set rather than
  interrogating the user property by property.
- **What is out of scope this time?** Name the adjacent behaviour a reader could reasonably assume is
  included but isn't — the neighbouring surface, the follow-up state, the case the design shows but this
  round won't build. Propose the list; the user confirms or corrects it.

Each confirmed out-of-scope item goes into the `## 목표` of the ticket it borders, as one closing line
("여기까지 — ○○ 는 이번 범위 아님"). Tickets describe only what to build, so an unstated boundary is
invisible to the implementing agent; putting it in the ticket the agent actually reads beats a separate
scope document it never opens.

Iterate until the user approves. **Never publish a ticket with an open design question or an unanswered
미결 정책** — the answer goes into the ticket's gap list with its source recorded as the user's decision. A
ticket is always a complete spec; the implementing agent should never hit `blocked` on a question this step
could have settled.

When the user cannot settle a 미결 정책 here — it needs the team, or a decision nobody has made yet —
**do not publish that ticket.** Leave the tracker comment from [5] standing as the open question, publish
the slices that do not depend on it, and tell the user which ticket is waiting on which comment. Guessing
so the ticket can ship is the exact failure this step exists to prevent.

Answers the user does settle here go back on the [5] comment as a reply, not only into the ticket body —
the ticket gets closed and buried, the decision thread stays findable.

## 7. Publish

Publish one ticket per slice **in dependency order (blockers first)** so each ticket's blocking
edges can reference real ids:

```bash
TRACKER_PARENT=<parent-id> "$TRACKER" create "<제목>" <body-file> '<approved-properties-json>'  # lands in 'ready'
"$TRACKER" add-edge <id> <blocker-id>        # once per blocking edge
```

When the run came from a parent ticket, **always** pass `TRACKER_PARENT` — it is the only record of the
parent, because the body has no `## Parent` section (CONTRACT's [Tracker adapter]). Omit the variable only
for a run with no parent. An adapter that cannot register a native parent refuses instead of publishing an
orphan; stop and tell the user rather than retrying without it.

Build one compact JSON object per ticket from the approved property keys. Omit keys approved as `unset` or
left at the adapter default, and omit the third argument when the object is empty. The adapter validates the
whole object before creation; if a value became stale, return to the proposal instead of dropping the property
and publishing a different ticket.

The native edge is the **only** record of a blocker (CONTRACT's [Blocking edges]) — the body carries no
blocker list, only the reason as a sentence where it matters. Because there is no second copy to fall back
on, **verify the edges after publishing**: for every ticket, read them back and compare against the
approved breakdown.

```bash
"$TRACKER" blockers <id>     # must list exactly the approved blockers for <id>
```

A mismatch — a missing edge, or one pointing at the wrong ticket — is fixed on the spot with `add-edge`
and re-read; never report the run done while a ticket's edges differ from the breakdown the user approved.

`create` puts every published ticket in `ready`, **blocked ones included** — the state says the spec is
complete, not that work can start today. Startability comes from the edges.

**Ticket bodies are written in Korean, for non-developers too** — per CONTRACT's [Output convention],
apply the `korean-output` skill and avoid developer-translationese: a 기획자·디자이너 reading only `## 목표`
and `## 완료 조건` must understand what ships and how to check it. Backend-only tickets may state
developer-observable outcomes. Do not close or modify the parent ticket.

Avoid file-by-file changes, function/component assignments, chosen endpoint/type shapes and code snippets
in the issue. If an existing consumer, external integration or approved decision requires an exact contract,
link its source under 정책과 제약 and quote only what the implementer must preserve. Put implementation
choices, code structure and verification commands in the PR.

<issue-template>

## 목표

이 티켓이 동작하게 만드는 종단 간 동작 — 사용자 관점에서, 랜딩하면 무엇이 데모 가능해지는가.
레이어별 구현 목록이 아니다. 확정한 범위 밖 항목과 맞닿으면 그 경계 한 줄로 닫는다.

## 제공할 동작

사용자나 시스템이 할 수 있어야 하는 일. 주요 흐름과 필요한 예외 동작을 자연어로 적는다.
어떤 파일·함수·컴포넌트를 고칠지는 구현자가 판단한다.

## 정책과 제약

구현 방식과 관계없이 지켜야 하는 제품 규칙과 이미 정해진 외부 계약. 규칙 하나에 불릿 하나,
각각 답의 출처(코드·문서·트래커 코멘트 링크). 별도 규칙이 없으면 생략.

## 디자인·참고

디자인이나 참고 문서가 있을 때만. 없으면 생략.

- **Figma node**: 링크. 디자인/UX 의 단일 진실 — 구현자가 구현 시점에 MCP 로 노드를 가져오고,
  배치·스타일은 노드를 따른다. 동작·정책이 완료 조건과 충돌하면 먼저 결정받는다.
  스크린샷을 붙이거나 디자인을 산문으로 옮기지 않는다.
- **Figma가 답하지 않는 것**: 갭 목록 — 상태(로딩/빈/에러), 인터랙션 엣지 케이스, 데이터 규칙,
  그려지지 않은 카피. 갭 하나에 불릿 하나, 각각 답과 그 답의 출처(코드·문서·사용자 결정).

## 완료 조건

- [ ] 합의된 목표·정책을 충족했는지 판단할 수 있는 관찰 결과.

관찰 결과는 필수이고 전제·행동은 필요할 때만 적는다. 사용자 표면이 있으면 사용자가 겪는 결과를,
백엔드·스키마 전용 티켓이면 개발자가 확인할 결과를 적는다. 공유 reference의 예시를 따르며,
타입 체크나 파일 수정 목록으로 대체하지 않는다.

</issue-template>

블로커 목록은 본문에 쓰지 않는다 — 네이티브 엣지가 유일한 기록이다. 막히는 이유가 자명하지 않으면 그 이유만
관련 절에 한 문장으로 남긴다("YOU-70 의 schema 컬럼을 읽으므로 그 PR 이 merge 된 뒤 시작").
