# 완료 조건 작성

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
