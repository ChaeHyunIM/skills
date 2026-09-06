# 완료 조건

Read this when authoring, implementing, reviewing or landing a ticket. This is the shared rule;
the four skills place its checkpoints in their own workflows.

## Write the outcome, not the patch

The issue describes **what must be true**; the PR describes **how the code makes it true**.
Codebase exploration establishes feasibility, current behaviour and dependencies. Do not turn that
exploration into a file-by-file implementation plan in the issue. Required external contracts belong
under 정책과 제약; chosen functions, components, cache mechanisms and test commands belong in the PR.

Use `## 완료 조건` in new tickets. `Acceptance criteria` and `검수 기준` are read-only legacy aliases,
not additional sections or new vocabulary. The adapter reads these headers and `-`, `*`, `+` bullets,
with or without checkboxes. Do not rewrite old tickets wholesale to migrate the heading.

- Derive each condition from the goal, approved policy or linked design. Do not invent policy.
- Require an observable result. Add a precondition or action when needed to make that result unambiguous;
  do not force a three-part sentence on every item. Split results that can pass independently.
- Check both directions: can all conditions pass while the goal remains unmet? Does any condition add
  work outside the agreed scope? Cover the main flow and material failure cases without a generic quota.
- For user-facing work, describe what the user experiences. Backend-only, schema and infrastructure
  tickets may use developer-observable results such as persisted data or a constraint rejecting input.
- Establish how each result can be verified **before merge**. A dev build, simulator or dev service can
  verify many device and integration conditions; do not label them post-release merely because they use
  a device or an external service. Verification never authorizes a prohibited migration or production write.
- A condition that truly needs release-time observation belongs to an explicitly owned follow-up ticket
  created through `to-tickets`, with a native blocked-by edge to the implementation ticket. Include this
  split in the approved breakdown; do not hide it in a 배포 후 확인 section or silently drop it from scope.
- Present the actual conditions in the normal ticket approval, not a separate approval per checkbox.
  Resolve ambiguous conditions and contradictory sources before publishing the affected ticket.

Examples (the illustrated behaviour must already be agreed):

```markdown
좋은 예 — 사용자 동작
- [ ] 설정에서 이름을 바꾼 뒤 앱을 다시 열어도 변경한 이름이 표시된다.
- [ ] 이미 참여한 미션을 다시 누르면 '이미 참여 중' 안내가 표시된다.

좋은 예 — 스키마 전용 티켓
- [ ] 개발 DB에서 같은 제출 식별자로 내역을 두 번 저장하면 두 번째 저장이 거절된다.

나쁜 예
- [ ] 타입 체크 통과, API와 컴포넌트 구현 완료.
```

The last example names work and a general code check, not the promised result. If a schema example
requires a human-applied migration, record that dependency; the agent must not apply it to get a check.

## Verify and keep one current PR record

Read conditions via `"$TRACKER" criteria <N>`. Do not duplicate the Markdown parser in skills.
At implementation start, select a verification method for each condition. Missing or ambiguous conditions
go through `implement`'s existing When stuck path before coding; do not synthesize pass criteria on the fly.

| Status | Meaning | Checkbox |
|---|---|---|
| 충족 | Evidence establishes the whole condition on the identified implementation | `[x]` |
| 미충족 | Evidence shows the condition fails; name the actual result | `[ ]` |
| 미검증 | Evidence is absent, insufficient or stale; state why | `[ ]` |

Writing new tests and verifying conditions are separate decisions. Use existing evidence when it actually
covers the condition; do not require another tool run just to follow a table. These are default routes:

| Condition | Default verification route |
|---|---|
| Domain/server behaviour | Existing tests through the project runner, e.g. `pnpm test <path>` |
| API response | Request to the local/dev service; inspect response and relevant persistence |
| App screen | `agent-device` on a simulator or authorized device; use a real device if the condition requires it |
| Web screen | Available browser automation against the app |
| Human-applied migration | Verify after the human applies it; until then record 미검증 and the dependency |

Do not use typecheck as proof of runtime behaviour. Try the applicable verification route before declaring
미검증 unless a known missing environment, permission or human action prevents it. State that reason.

The **current verification record lives only in the PR body**, in `## 완료 조건 검증`. Open the PR at
the existing end-of-implementation step, non-draft; do not open an early PR for progress reporting.
Before that, keep working results in the session. Rework and review update the same PR section.
Preserve the PR binding line and other human-authored content when editing; re-read first and read back.

```markdown
## 완료 조건 검증

검증 대상: <검증한 PR 커밋 링크> · 환경: <실제로 사용한 환경>

- [x] <이슈의 완료 조건 원문> — 충족
  - 근거: <재현 방법과 관찰 결과, 테스트 결과나 기록 링크>
- [ ] <이슈의 완료 조건 원문> — 미충족
  - 결과: <기대한 결과와 실제 결과>
- [ ] <이슈의 완료 조건 원문> — 미검증
  - 이유: <실행하지 못했거나 기존 근거가 유효하지 않은 이유>
```

Keep every condition identifiable by its original text, including qualifiers. Each result identifies the
tested code and environment; if these differ from the section's default, record them on that item.
Do not advance a tested commit merely because a new commit exists. An existing checked issue box is not
evidence. Neither is a clean review. Confirm that the goal and agreed constraints still hold even when
all boxes pass. Do not weaken or remove a condition to fit the implementation; changes in meaning need
the human's decision recorded on the issue and affected results reverified.

`implement` and `review-round` reverify conditions affected by their fixes or base sync. Unrelated edits
do not invalidate every result. A round records only its checks and changes in its comment; the comment
is a historical result, not another table to keep current. The outer round owns this work without starting
an additional paid review engine. Missing implementation is a fix; unresolved policy remains 보류.

## Land: approval is not satisfaction

Only `land` updates existing issue checkboxes. New tickets are created unchecked. At land's plan step,
read the current PR record and fresh issue conditions; a round comment is optional. Missing evidence or
a changed condition is 미검증. Show remaining conditions and their reasons across the whole queue in
the existing single confirmation. Naming the PR authorizes normal landing, but remaining conditions
require the informed confirmation here unless that exact exception was already explicitly approved.

Do not rerun the full feature verification in `land`. Compare the evidence's code version with the PR
head and inspect anticipated sync/conflict changes. Overlapping files are a signal to assess affected
conditions, not proof of failure. Expose anticipated uncertainty in the plan before approval. Keep the
existing typecheck and intent-collision rules. A newly discovered remaining condition outside the approved
exception scope must not be silently included: leave that item unmerged, report it, and continue independent
items without opening a second confirmation. Missing verification alone is not an intent-collision valve.

After sync and typecheck, immediately **before merge**, update the issue through the adapter with true
only for 충족. Approval never changes a result to 충족. A failed checkbox write stops that item's merge;
report the adapter error, do not bypass it. A subsequent merge failure does not invalidate genuine checks.

After a confirmed merge with any remaining conditions, post a factual comment on **both** the PR and
issue. PR: condition, 미충족/미검증, reason/evidence and explicit approval. Issue: short natural Korean,
what remains and that the human accepted it for this merge. Mention no teammates. No additional content
approval is needed for these record-only comments. Never invent a verification obstacle, acceptance reason,
follow-up owner or deadline. Missing conditions can remain unchecked on a Done issue by design.

Example for an explicitly accepted device-verification gap:

```markdown
PR:
완료 조건 '실제 아이폰에서 정상 동작'은 미검증입니다. 미검증 상태를 확인받고 사용자 승인으로
병합했습니다. 해당 조건은 체크하지 않았습니다.

이슈:
실제 아이폰에서의 동작 확인은 남아 있습니다. 이 점을 확인하고 병합했으며,
완료 조건은 빈칸으로 남겼습니다.
```

Put remaining conditions at the front of the land report and link both comments. `land` never creates
follow-up tickets automatically. If either comment fails, report the missing record and retry only that
comment after checking for an existing copy; do not repeat the merge or invent a successful post.

## Adapter contract

`criteria <id>` returns `{issue,updatedAt,bodyHash,section,items:[{index,text,checked}]}`. Indices are
one-based and local to that snapshot, not permanent identifiers. `section: null` or empty items means
no usable conditions; never treat that as all conditions passing. Multiple matching sections or nested
checkboxes are refused as ambiguous. Continuation text stays part of its condition.

`check <id> <criteria-snapshot.json> <checks.json>` accepts a full batch of `{index,text,checked}` results,
one for every item from the snapshot. Preserve the exact text; `checked` is boolean. A legacy plain bullet
is converted to a checkbox in place. No headings, wording, ordering or other sections are rewritten.

```bash
"$TRACKER" criteria <N> > <scratchpad>/criteria-<N>.json
# PR 검증 결과로 checks-<N>.json을 작성한다. 모든 항목을 일괄 통과시키지 않는다.
"$TRACKER" check <N> <scratchpad>/criteria-<N>.json <scratchpad>/checks-<N>.json
```

Both adapters share one Python 3 parser and the read/prepare/re-read/write/read-back sequence. The writer
compares issue identity, timestamp, full body hash and condition text before writing, then checks the full
saved body. No-op batches do not write. This narrows a concurrent-edit window; it is **not atomic CAS**.
A concurrent edit after the last read may still be overwritten. Do not promise full concurrency protection.
If the platform normalizes Markdown and verification fails, inspect that real response before defining a
normalization allowance. Never discard a mismatch, relax preservation speculatively or auto-retry a stale
batch. No credentials or live issues are needed to run the adapter tests.

Offline validation: `python3 ~/.agents/skills/agent-loop/adapters/tests/test_criteria.py`.
The suite mocks both backends, including stale reads, failed writes and preservation mismatches.
