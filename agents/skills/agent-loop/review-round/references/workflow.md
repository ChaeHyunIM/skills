# 리뷰 라운드 공통 흐름

Codex·Claude 진입점이 공유한다. 엔진 실행·대기만 진입점의 런타임 reference를 따른다. 공통 `CONTRACT.md`, 트래커를 위한 `references/tracker.md`, 코드 변경을 위한 `references/workspace.md`를 적용한다.

## 준비

1. 티켓과 PR 바인딩, 최신 완료 조건·검증 기록을 읽는다. 다른 구현·리뷰가 실행 중이면 동시에 쓰지 않는다. 열린 PR이 없으면 보고한다.
2. `agent-loop/scripts/sync-worktree.sh <worktree> <branch>`로 clean 브랜치를 정렬한다. 로컬 작업은 보존한다. remote head와 worktree HEAD가 같은지 확인한다.
3. 이 HEAD를 `ROUND_BASE`, PR base의 fetch한 SHA를 `COMPARISON_REF`로 고정한다. 실제 base 이름도 기록한다. 이슈 조건과 PR 본문은 바깥 루프의 대조 입력이다.
4. [arguments.md](arguments.md)의 resolver를 실행해 이번 호출의 모델·effort를 확정하고 인증 preflight를 한다. 실패하면 엔진을 띄우지 않는다. 기존 정책·충돌 보류는 보존하며 실행 중 상태를 새로 남기지 않는다.
5. 가장 큰 기존 라운드 번호에 1을 더해 K를 잡고 `in-review`로 바꾼다. scratch는 매 실행 새로 만든다. 두 엔진을 해당 런타임의 실행 reference로 시작하고 완료까지 이어간다.

## 결과와 수정

두 엔진이 종료하고 worktree와 remote PR head/base가 고정한 대상 그대로인지 먼저 확인한다. `agent-loop/scripts/check-worktree.sh <worktree> <ROUND_BASE>`로 미커밋 수정도 확인한다.

```bash
bash ~/.agents/skills/agent-loop/review-round/scripts/extract-findings.sh <scratch>/review-<N>-r<K>.jsonl
bash ~/.agents/skills/agent-loop/review-round/scripts/codex-review.sh extract <scratch>/codex-review-<N>-r<K>.json "$ROUND_BASE" "$CODEX_MODEL" "$EFFORT"
```

- Claude exit 0은 구조화 결과, 2는 산문 폴백(degraded), 3은 쓸 결과 없음이다. Codex는 0만 유효하고 산문 폴백이 없다.
- 엔진 실패·timeout·무효 결과·대상 이동은 한쪽 결과만으로 처분하지 않는다. 원본·stderr를 보존하고 자동 재실행하지 않는다.
- 두 엔진이 모두 종료했고 정책·충돌이 없으면 실패도 `awaiting-review`로 돌리고 실패를 기록한다. 프로세스 생존이 불명확하면 먼저 종료 상태를 확인한다. `in-review`를 실패 기록용으로 남기지 않는다.
- 원본의 `short_summary`는 표, `failure_scenario`는 처분 근거다. Claude `verdict`는 해당 실행이 제공한 경우만 사용한다. Codex의 `test_gaps`·`residual_risks`·`overall_assessment`는 한계 설명에 쓰고 추가 finding으로 부풀리지 않는다.
- 같은 위치의 같은 실패 시나리오만 합쳐 `Claude+Codex` 출처로 표시한다. 다른 시나리오는 별개다. 결합 목록 순서로 번호를 부여한다.
- 원 조건마다 구현·기존 근거를 대조한다. 구체 구현 누락은 출처 `완료 조건`으로 포함하며 없는 코드의 file/line을 지어내지 않는다. 증거 부족은 검증 공백으로 기록하며 엔진 finding 수에 섞지 않는다.
- 결합 목록과 처분은 `<scratch>/review-<N>-r<K>.findings.json` 한 작업 사본에 남긴다. 엔진 원본은 보존한다.

| 처분 | 기준 |
|---|---|
| 반영 | 근거가 확인된 버그·타입 오류·프로젝트 규칙 위반. 범위 안에서 수정하고 필요한 검사를 수행 |
| 기각 | 사실이 아닌 지적. 확인한 반증과 위치 또는 실행 근거를 남김 |
| 보류 | 미결 제품 정책·비용·승인 범위 밖 구조·마이그레이션 판단. 코드로 선택하지 않고 선택지·추천을 제시 |

보류는 개발 결정과 팀 결정을 구분한다. 바뀐 코드는 공통 workspace의 cleaner·검사·commit 경로를 따르고 push한다. 테스트는 영향받은 범위에서 실행하며 같은 입력의 검사를 반복하지 않는다.

## base와 상태

- 최신 PR base를 fetch해 feature에 merge하고 변경된 입력의 타입 체크를 한다. 이미 통과한 검사도 base가 관련 입력을 바꿨으면 다시 한다.
- base 충돌은 abort하고 `blocked`로 남긴다. 충돌만 남으면 사용자가 지명한 `land`가 받는다. 정책·구현 문제가 섞이면 그 결정을 먼저 받는다.
- 마이그레이션 순서는 파일 단위로 검토하고 사람이 정해야 할 것이 있으면 보류에 넣는다. 프로젝트의 생성·적용 경계를 지킨다.
- `verified-head.sh`로 기록 상태를 읽는다. 변경된 head를 검증했다고 덮어쓰지 않는다. 이 라운드에서 수행한 검사는 라운드 코멘트에 남기고, 공식 PR 기록은 implement·verify가 실제 근거로 갱신한다.

## 게시와 종료

마지막 push 뒤 `ROUND_BASE..ROUND_HEAD` 범위를 계산하고 [round-comment.md](round-comment.md) 형식으로 PR 코멘트 하나를 남긴다. 본문은 파일로 작성해 `--body-file`로 게시한다. 재시작 시 같은 라운드가 이미 게시됐는지 읽어 중복을 피한다.

- 결정 보류·base 충돌·해결되지 않은 구현/검사 실패가 있으면 `blocked`, 없으면 `awaiting-review`다. 티켓에는 PR 코멘트 포인터를 남긴다.
- 팀 보류가 있으면 [team-comment.md](team-comment.md)로 그 항목의 짧은 초안을 만들고 승인받아 게시한다. 그 승인 대기 때문에 다른 라운드 작업을 남기지 않는다.
- 채팅에는 결과 링크와 반영·기각·보류 수, 실제 검증 상태, 필요한 결정만 보고한다. PR의 결정 내용과 다르게 재해석하지 않는다. 불필요한 다음 명령 목록을 매번 나열하지 않는다.

명시 호출은 한 라운드다. 리뷰 엔진을 추가 기동하거나 머지하지 않는다.
