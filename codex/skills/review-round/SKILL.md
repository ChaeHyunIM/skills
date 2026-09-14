---
name: review-round
description: 요청한 PR을 Claude와 Codex가 각각 한 번 리뷰하고, 수정한 내용과 남은 결정을 기록한다.
---

# review-round

사용자가 `$review-round`를 호출하면 티켓에 연결된 PR을 한 차례 리뷰한다. Claude와 Codex가 같은 커밋을 각각 한 번 확인한다. 두 리뷰어는 코드를 고치지 않는다. 결과를 받은 에이전트가 필요한 수정을 하고, 반영하지 않은 이유와 사람이 결정할 항목을 PR 코멘트 하나에 정리한다.

시작할 때 [공유 규칙](../../../agents/skills/agent-loop/CONTRACT.md)을 읽는다. 아래 순서로 진행하며 자세한 판단 기준은 [리뷰 진행 방법](../../../agents/skills/agent-loop/review-round/references/workflow.md)을 따른다.

## 리뷰 진행 순서

1. 티켓과 PR, 완료 조건, 기존 검증 결과를 확인한다. 다른 구현이나 리뷰가 같은 브랜치를 고치고 있지 않은지 확인하고 원격의 최신 커밋을 가져온다.
2. 리뷰할 커밋과 비교할 base 커밋을 정한다. 이번 호출의 모델과 effort를 확인하고 로그인 등 실행 준비를 점검한다. 새 라운드 번호를 정하고 상태를 `in-review`로 바꾼다.
3. [Codex에서 리뷰 실행하기](../../../agents/skills/agent-loop/review-round/references/codex-runtime.md)에 따라 두 리뷰어를 실행하고 모두 끝날 때까지 기다린다. 같은 실행을 두 번 시작하지 않는다.
4. 결과를 모아 반영·기각·보류로 나눈다. 작업 범위 안의 오류는 고치고 필요한 검사를 한다. 제품 정책은 대신 정하지 않고 선택지와 추천을 남긴다. 수정했다면 정해진 절차로 커밋하고 push한다.
5. 최신 base를 반영하고 검증 기록이 현재 커밋에도 맞는지 확인한다. 결과는 PR 코멘트 하나에 적고 티켓에 링크를 남긴다. 해결할 오류나 결정이 남았으면 `blocked`, 아니면 `awaiting-review`로 바꾼다. 팀의 결정이 필요한 글은 초안을 승인받아 별도로 올린다.

채팅에는 결과 링크, 반영·기각·보류 수, 실제 검증 상태, 필요한 결정을 보고한다. 오류가 나면 [실패 처리 방법](../../../agents/skills/agent-loop/review-round/references/workflow.md)을 따르고 리뷰를 자동 재시도하지 않는다. 이 스킬은 머지하지 않는다.

## 모델과 effort

별도로 지정하지 않은 값은 이 스킬을 호출한 Codex 세션에서 매번 가져온다. 값을 정하는 순서와 Codex 세션 정보를 읽을 수 없는 경우는 [리뷰 실행 옵션](../../../agents/skills/agent-loop/review-round/references/arguments.md)을 따른다. 한 라운드에서 정한 설정은 실행 중 바꾸지 않는다.

별도로 실행하는 Codex는 `$review-agent`만 사용한다. 이 `review-round` 스킬을 다시 호출하지 않는다.
