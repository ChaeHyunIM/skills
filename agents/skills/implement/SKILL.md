---
name: implement
description: 요구사항으로 완료 조건을 정해 승인받고, 별도 worktree에서 구현하고 검증한 뒤 결과를 적은 PR을 준비한다.
disable-model-invocation: true
---

# implement

요구사항에서 완료 조건을 정해 승인받고, 구현과 실제 동작·코드 품질 검증을 마친 뒤 PR을 준비한다. 확인한 결과와 남은 항목을 PR에 적는다. 티켓으로 관리하는 작업은 이 절차에 티켓 단계를 더한 `implement-ticket`을 쓴다.

시작할 때는 [공유 규칙](../agent-loop/CONTRACT.md)만 읽고, 다음 문서는 해당 작업을 할 때 읽는다.

- 완료 조건 초안을 쓸 때: [완료 조건 작성 기준](../agent-loop/references/ticket-criteria.md)
- worktree를 준비하거나 커밋할 때: [작업 환경](../agent-loop/references/workspace.md)
- 구현·검증하고 PR을 준비할 때: [구현하고 PR 준비하기](../agent-loop/references/implementation.md)
- 코드 품질을 확인할 때: [code-quality](../code-quality/SKILL.md)
- 검증하고 PR에 기록할 때: [검증과 기록 방법](../agent-loop/references/verification.md)
- PR 본문을 쓸 때: [PR 본문 양식](../agent-loop/references/pr-body.md)

## 요구사항 확인

- `implement <요구사항> [--base <branch>]`로 호출한다. 요구사항이 없으면 무엇을 만들지 묻는다.
- 인자가 티켓 식별자(`YOU-123`, `#12`, 숫자만)뿐이면 티켓을 지정한 것으로 보고 [implement-ticket](../implement-ticket/SKILL.md)을 따른다. 그렇게 진행한다고 한 줄로 알린다.
- 요구사항과 관련 코드, 프로젝트 지침을 읽는다. 지금 어떻게 동작하는지, 먼저 끝나야 할 일이 있는지 확인한다.
- PR 하나로 끝나지 않는 크기이거나 먼저 머지해야 할 작업이 따로 있으면 멈추고 `to-tickets`로 나누자고 제안한다. 티켓을 대신 만들지 않는다.
- 이미 같은 작업의 `agent/<slug>` 브랜치나 열린 PR이 있으면 같은 PR과 worktree에서 이어간다. 다른 구현이나 리뷰가 진행 중이면 동시에 브랜치를 고치지 않는다.

## 완료 조건 승인받기

구현하기 전에 아래를 한 번에 보여 주고 승인받는다. 같은 세션에서 이미 승인받은 내용은 다시 묻지 않는다.

- 완료 조건: 작성 기준을 따른다. 요구사항과 승인된 정책에서 가져오고, 새 정책을 만들지 않는다. 배포 후에만 확인할 수 있는 항목은 `범위 밖`에 적을 후보로 따로 표시한다.
- 제품 결정이 필요한 갈림길: 선택지와 추천. 사용자가 정하지 않으면 PR의 `정해야 할 것`으로 남긴다.
- PR 제목과 slug: 제목은 프로젝트의 제목 규칙을 따른다. slug는 짧은 영어 이름으로 ASCII 소문자·숫자·하이픈만 쓴다.
- base: 사용자가 지정한 브랜치나 메인 체크아웃의 현재 로컬 브랜치. `main`이라고 가정하지 않는다.

승인을 기다리는 동안 영향받지 않는 조사는 계속한다. 승인받은 완료 조건은 그대로 PR 본문의 `## 완료 조건`에 옮긴다. 구현하다가 뜻을 바꿔야 하면 사용자에게 다시 확인받는다.

```bash
bash ~/.agents/skills/agent-loop/scripts/prepare-worktree.sh <ascii-slug> [<base>]
```

기존 작업을 이어갈 때는 PR head 브랜치에서 `agent/` 뒤를 slug로 넘기고 base를 생략한다. 로컬 변경이나 아직 원격에 올리지 않은 커밋이 있으면 보존하고 어느 작업에서 만든 것인지 확인한다.

## 구현하고 PR 준비하기

[구현하고 PR 준비하기](../agent-loop/references/implementation.md)를 따른다. 승인받은 완료 조건은 [PR 본문 양식](../agent-loop/references/pr-body.md)의 `## 완료 조건`에 둔다.

팀이 정해야 하는 보류 항목은 PR의 `정해야 할 것`에 적고, 비개발자에게 그대로 보낼 수 있는 초안을 채팅에 함께 준다.

## 남은 일

- 해결하지 못한 구현 오류, 제품 결정, base 충돌이 있으면 PR과 채팅에 이유와 다시 시작하는 방법을 적는다. PR이 아직 없으면 구현을 이어가 PR부터 준비한다.
- 남은 검증은 `verify --pr <PR>`, 병합은 `land --pr <PR>`로 이어갈 수 있다고 안내한다.
