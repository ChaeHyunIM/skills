---
name: land
description: 사용자가 지정하거나 확인한 티켓의 PR을 동기화하고 병합한다.
disable-model-invocation: true
---

# land

사용자가 이번 실행에서 지명한 PR을 준비·동기화·검사한 뒤 머지한다. 정상 병합은 호출로 승인된 것이다. 새 의도나 남은 검증의 예외 승인은 구체적인 결과를 보여 주고 받는다.

시작할 때 `~/.agents/skills/agent-loop/CONTRACT.md`를 읽는다. 트래커·작업 위치에는 공통 `references/tracker.md`·`references/workspace.md`, 증거와 체크박스에는 `references/landing-criteria.md`를 적용한다.

## 큐

- `land <N...>`은 지정 순서로 처리한다. 인자가 없으면 `awaiting-review` 후보를 모아 선택받는다. 과거 실행의 지명을 새로운 머지 승인으로 이월하지 않는다.
- `blocked`라도 **최신 기록상 base 충돌만 남은 PR**은 명시 지명으로 받는다. 미결 정책·구현 실패가 섞였거나 이유가 모호하면 먼저 해결하도록 남긴다.
- 살아 있는 `in-progress`·`in-review`는 받지 않는다. 라벨만 오래 남은 경우 실제 실행 종료와 실패 기록을 확인한 뒤 상태를 바로잡는다.
- 바인딩으로 PR·티켓·브랜치를 확인한다. 최신 완료 조건·PR 검증 기록·있다면 라운드 코멘트를 읽는다. 리뷰 실행 자체나 별도 `verify` 호출을 필수로 만들지 않는다.
- 라운드의 리뷰 대상과 수정 후 head를 구분한다. 기록된 수정은 알려진 변경이지만 두 엔진이 수정 후 코드를 다시 리뷰했다는 뜻은 아니다. 이후 추가 커밋은 별도로 드러낸다.

## 구체적인 병합 후보 준비

1. 실제 worktree와 branch를 확인한다. 없으면 `prepare-worktree.sh`로 기존 브랜치에 복구한다. `agent-loop/scripts/sync-worktree.sh <worktree> <branch>`로 clean·로컬 전용 커밋 부재를 확인하고 fast-forward한다. 실패하면 작업을 보존하고 해당 PR만 남긴다. `reset --hard`, 자동 stash, force-push는 쓰지 않는다.
2. 현재 PR base를 다시 읽고 fetch한 base를 feature에 merge한다. 충돌은 [references/conflicts.md](references/conflicts.md)로 처리한다. 사람의 정책·의도 선택이 필요한 충돌은 abort하고 그 PR만 blocked로 남긴다.
3. 동기화된 코드의 필요한 타입 체크를 수행한다. 동일 입력에서 통과한 결과는 재사용한다. 범위를 벗어나는 동작 변경은 추가하지 않는다. 해소·수정은 공통 커밋 경로를 따르고 feature를 push한다.
4. 최종 PR head, base SHA, 최신 조건과 `verify/scripts/verified-head.sh` 결과를 확보한다. sync나 해소로 바뀐 SHA는 stale이다. 기능 검증을 했다고 꾸미거나 검증 기록을 변경하지 않는다.

## 승인과 실행

준비된 순서·PR·base·head·충돌 해소·검증 결과와 남은 조건을 짧게 제시한다. 아직 승인되지 않은 예외만 모아서 묻는다. 모든 조건을 implement가 확인했고 최종 head에 근거가 유효하면 verify를 요구하지 않는다.

- 명시 인자와 예상 밖 변경·남은 조건이 없으면 추가 질문 없이 진행한다.
- stale·missing·미충족·미검증 상태를 그대로 병합하려면 그 구체적인 공백의 승인이 필요하다. 재검증은 implement 또는 verify로 할 수 있다.
- 큐 앞 PR의 병합이 뒤 PR의 base를 바꿀 예정이면 계획에 그 변경과 예상되는 검증 공백을 포함한다. 그 예외까지 승인받지 않았다면 뒤 PR의 근거를 자동 승격하지 않는다.
- 각 머지 직전 remote head·base와 이슈 조건을 다시 읽는다. 큐 진행 중 base가 움직이면 해당 PR을 다시 sync·검사하고 증거를 다시 평가한다. 승인 범위를 벗어난 변경은 그 항목만 보류하고 독립 항목을 계속한다.
- `landing-criteria.md`대로 체크박스를 갱신하고 읽어서 확인한다. current 기록의 근거 있는 충족만 체크한다. 쓰기 확인이 실패하면 그 PR을 머지하지 않는다.
- 최종 head를 고정해 `gh pr merge <PR> --rebase --match-head-commit <final-head>`를 실행한다. 도구가 그 옵션을 지원하지 않으면 같은 원자적 head 조건을 지원하는 도구를 사용하고, 지원이 없으면 해당 머지를 보류한다. head가 바뀌면 다시 평가한다.

## 마무리

실제 머지와 트래커 완료를 확인한다. `Fixes` 연동이 상태를 옮기지 않았으면 직접 완료 처리한다. 승인된 남은 조건은 공통 landing 문서대로 PR·이슈에 기록한다. 쓰기 실패는 누락된 기록만 복구하고 머지는 반복하지 않는다.

보고는 남은 미충족·미검증, 보류·실패, 이어서 머지 결과와 기록 링크 순서다. worktree는 세션이 끝난 뒤 `tidy-merged`로 정리하도록 남긴다.
