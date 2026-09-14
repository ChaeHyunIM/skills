---
name: review-round
description: 요청한 PR에 Claude·Codex 리뷰 한 라운드를 실행하고 수정·기각·보류 결과를 기록한다.
---

# review-round

명시적인 `$review-round` 호출로 티켓에 연결된 PR을 한 라운드 리뷰한다. 같은 고정 head에 읽기 전용 엔진 둘을 실행하고, 이 바깥 루프가 수정과 PR 요약 코멘트 하나를 소유한다.

1. `~/.agents/skills/agent-loop/CONTRACT.md`를 읽는다.
2. `~/.agents/skills/agent-loop/review-round/references/workflow.md`의 준비를 진행한다.
3. 엔진 실행 시에만 같은 폴더의 `codex-runtime.md`를 읽고 실행·완료 대기를 한다.
4. 공통 workflow로 돌아와 결과 처리·수정·상태 정리·게시까지 마친다.

별도 지정이 없는 모델·effort는 호출한 현재 Codex 세션에서 매번 상속한다. 값의 우선순위와 세션 정보를 읽을 수 없는 경우는 `~/.agents/skills/agent-loop/review-round/references/arguments.md`를 따른다. 한 라운드에서 확정한 설정은 바꾸지 않고 자동 재시도하지 않는다. nested Codex는 `$review-agent`만 호출하며 이 스킬을 재귀 호출하지 않는다.
