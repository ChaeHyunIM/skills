---
name: implement-ticket
description: 지정한 티켓을 별도 worktree에서 구현하고 검증한 뒤, 결과를 적은 PR을 준비한다.
disable-model-invocation: true
---

# implement-ticket

티켓의 구현과 실제 동작·코드 품질 검증을 마치고 PR을 준비한다. 확인한 결과와 남은 항목을 PR에 적는다. 필요한 검증이 모두 끝났으면 사람이 병합을 판단할 수 있다. [implement](../implement/SKILL.md)에 티켓 단계(완료 조건을 이슈에서 읽기, 선행 작업 확인, 트래커 상태 관리)를 더한 스킬이다.

시작할 때는 [공유 규칙](../agent-loop/CONTRACT.md)만 읽고, 다음 문서는 해당 작업을 할 때 읽는다.

- 티켓 상태를 바꿀 때: [트래커 규칙](../agent-loop/references/tracker.md)
- worktree를 준비하거나 커밋할 때: [작업 환경](../agent-loop/references/workspace.md)
- 완료 조건의 뜻을 확인할 때: [완료 조건 작성 기준](../agent-loop/references/ticket-criteria.md)
- 구현·검증하고 PR을 준비할 때: [구현하고 PR 준비하기](../agent-loop/references/implementation.md)
- 코드 품질을 확인할 때: [code-quality](../code-quality/SKILL.md)
- 검증하고 PR에 기록할 때: [검증과 기록 방법](../agent-loop/references/verification.md)
- PR 본문을 쓸 때: [PR 본문 양식](../agent-loop/references/pr-body.md)

## 구현할 티켓과 작업 폴더 확인

- `implement-ticket <N> [--base <branch>]`는 지정한 티켓을 구현한다. 나머지 인자는 이번 작업에 대한 추가 지시다.
- 티켓을 지정하지 않았으면 [후보 고르기](references/candidates.md)에 따라 목록을 보여 주고 선택받는다. 이번 세션에서 이미 지정한 티켓을 다시 묻지 않는다.
- 이슈와 완료 조건, 기존 PR과 브랜치를 읽는다. 처음 구현하는 티켓인지, 기존 작업을 이어가는지 확인한다. 기존 작업은 같은 PR과 worktree에서 이어간다. 다른 구현이나 리뷰가 진행 중이면 동시에 브랜치를 고치지 않는다.
- 처음 구현할 때는 선행 티켓이 실제로 끝났고 연결된 PR도 머지됐는지 확인한다. 아직 열려 있으면 시작하지 않는다. 기존 작업을 이어갈 때도 새 선행 작업이 추가됐는지 확인한다.
- 완료 조건이 모호하면 [완료 조건 작성 기준](../agent-loop/references/ticket-criteria.md)으로 뜻을 확인한다. 제품 결정이 필요한 부분은 남겨 두고, 영향받지 않는 조사와 준비는 계속한다.
- 상태를 `in-progress`로 바꾼다. 새 작업의 base는 사용자가 지정한 브랜치나 메인 체크아웃의 현재 로컬 브랜치로 정한다. `main`이라고 가정하지 않는다.

```bash
bash ~/.agents/skills/agent-loop/scripts/prepare-worktree.sh <ascii-slug> [<base>]
```

기존 작업을 이어갈 때는 PR head 브랜치에서 `agent/` 뒤를 slug로 넘기고 base를 생략한다. 로컬 변경이나 아직 원격에 올리지 않은 커밋이 있으면 보존하고 어느 작업에서 만든 것인지 확인한다. 기존 PR의 worktree를 원격 브랜치에 맞출 때는 작업 환경 문서의 fast-forward 규칙을 따른다.

## 구현하고 PR 준비하기

[구현하고 PR 준비하기](../agent-loop/references/implementation.md)를 따른다. 완료 조건은 이슈의 `## 완료 조건`이라 PR에 다시 적지 않고, PR 첫 줄에 `Closes`로 티켓을 연결한다. PR을 게시한 뒤에는 티켓 상태도 다시 확인한다.

## 티켓 상태와 남은 일

- 구현과 검증 결과가 준비됐으면 `awaiting-review`로 바꾼다.
- 해결하지 못한 구현 오류, 제품 결정, base 충돌이 있으면 `blocked`로 남긴다. 이유와 다시 시작하는 방법을 적는다. 열린 PR에 base 충돌만 남았다면 `land`로 이어갈 수 있다. PR이 아직 없으면 구현을 이어가 PR부터 준비한다.
- 남은 검증은 `verify <N>`으로 이어갈 수 있다고 안내한다.

이슈의 완료 조건 체크박스는 바꾸지 않는다.
