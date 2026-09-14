# 완료 조건

Read this when authoring, implementing, reviewing or landing a ticket. This is the shared rule;
the four skills place its checkpoints in their own workflows.

## Write the outcome, not the patch

The issue describes **what must be true**; the PR describes **how the code makes it true**.
Codebase exploration establishes feasibility, current behaviour and dependencies. Do not turn that
exploration into a file-by-file implementation plan in the issue. Required external contracts belong
under 정책과 제약; chosen functions, components, cache mechanisms and test commands belong in the PR.

Use `## 완료 조건` in new tickets. `Acceptance criteria` and `검수 기준` are read-only legacy aliases,
not additional sections or new vocabulary. Conditions are the `-`, `*`, `+` bullets under that heading,
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

Read the conditions from the issue's `## 완료 조건` section as published. At implementation start, read each condition the way `verify` will — is there an observable result one of
its routes can check? Missing or ambiguous conditions go through `implement`'s existing When stuck path
before coding; do not synthesize pass criteria on the fly.

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
| App screen | `argent` on a simulator or authorized device; use a real device if the condition requires it |
| Web screen | Available browser automation against the app |
| Human-applied migration | Verify after the human applies it; until then record 미검증 and the dependency |

Do not use typecheck as proof of runtime behaviour. Try the applicable verification route before declaring
미검증 unless a known missing environment, permission or human action prevents it. State that reason.

The **current verification record lives only in the PR body**, in `## 완료 조건 검증`, and **only `verify`
writes it**. `implement` opens the PR at its end-of-implementation step (non-draft, never earlier for
progress reporting) with a placeholder under that heading and no results; rework and review rounds move
the head and leave the section alone. Preserve the PR binding line and other human-authored content when
editing; re-read first and read back.

A record is **current** when its `검증 대상` sha is the PR head, or differs from it only by merge commits —
a base sync changes no PR-side line. Anything else — no record, no sha, non-merge commits after the sha —
is **stale**: the evidence describes code that is no longer what would merge.
`~/.agents/skills/verify/scripts/verified-head.sh <PR> [<worktree>]` prints `current <sha>`,
`stale <sha> <n>` or `missing` (exit 0 / 1 / 2). Every reader uses it; nobody re-derives currency from
dates, comments or a look at the diff.

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

Neither `implement` nor `review-round` reverifies. A push that changes code makes the record stale by the
sha rule above, and the next `verify` run re-establishes it — once, on the final head, instead of once per
round at the point of least context. A round records only its checks and changes in its comment; the
comment is a historical result, not another table to keep current. Missing implementation is a fix;
unresolved policy remains 보류.

## Land: approval is not satisfaction

Only `land` updates existing issue checkboxes. New tickets are created unchecked. At land's queue step,
`verified-head.sh` reads every ticket's record. Anything but `current` goes into land's existing single
confirmation as one more thing the signer could not have known, with `verify <N>` named as the fix — it is
a question, not a refusal. At land's plan step, read the record and fresh issue conditions; a round comment
is optional. A changed condition, or an item the record lacks, is 미검증. Show remaining conditions and
their reasons across the whole queue in that same confirmation. Naming the PR authorizes normal landing,
but remaining conditions and a non-`current` record require the informed confirmation here unless that
exact exception was already explicitly approved.

Approving a merge over a `stale` record accepts the merge, never the evidence: its 충족 items describe
earlier code, so they are written to the issue as unchecked, like an accepted 미검증.

`land` does not verify and does not judge staleness by hand. Its own base sync adds merge commits, which
keep the record current; a conflict *resolution* that changes code is assessed through `land`'s conflict
discipline and typecheck, and overlapping files are a signal to name affected conditions, not proof of
failure. Expose anticipated uncertainty in the plan before approval. Keep the existing typecheck and
intent-collision rules. A newly discovered remaining condition outside the approved
exception scope must not be silently included: leave that item unmerged, report it, and continue independent
items without opening a second confirmation. Missing verification alone is not an intent-collision valve.

After sync and typecheck, immediately **before merge**, update the issue checkboxes per the rules in
[Checkbox update](#checkbox-update), true only for 충족. Approval never changes a result to 충족. A failed
checkbox write stops that item's merge; report the error, do not bypass it. A subsequent merge failure does not invalidate genuine checks.

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

## Checkbox update

`land` is the only writer of issue checkboxes, and the write has one legitimate shape: the checkbox
characters change, nothing else does. CONTRACT's [완료 조건] states the postconditions; this is how to meet
them with whatever tracker tool the session has.

1. Re-read the issue body immediately before writing. A copy read earlier in the session is stale by
   definition; someone may have edited the body since.
2. Locate each condition by its exact text. If a condition's text is not found exactly once, or the
   section is missing or duplicated, stop and report. Do not guess which bullet was meant.
3. Prefer the tool's partial edit (an exact-match replace of `- [ ] <text>` with `- [x] <text>`) over
   replacing the whole description. A legacy plain bullet becomes a checkbox in place.
4. Read the body back. The only difference from the re-read body must be the checkbox characters. Any
   other difference (wording, ordering, headings, whitespace the platform normalized) is reported as-is;
   do not revert, do not retry a stale batch, do not define a normalization allowance on the spot.
5. A batch that changes nothing does not write.

This narrows the concurrent-edit window; it is **not atomic**. An edit landing between the re-read and
the write can still be overwritten, so do not promise full concurrency protection.
