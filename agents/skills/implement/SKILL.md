---
name: implement
description: 지정한 트래커 티켓을 격리된 worktree에서 구현·검증하고 결과를 기록한 PR을 준비한다.
disable-model-invocation: true
---

# implement

티켓의 구현과 필요한 검증·수정을 마치고 PR을 준비한다. 확인한 결과와 남은 항목을 PR에 기록한다. 모든 필요한 검증이 끝났으면 별도 `verify` 호출 없이 사람이 리뷰·병합을 판단할 수 있다.

시작할 때 `~/.agents/skills/agent-loop/CONTRACT.md`를 읽는다. 티켓은 공통 `references/tracker.md`, 작업 위치·커밋은 `references/workspace.md`, 검증은 `references/verification.md`를 적용한다.

## 대상과 준비

- `implement <N> [--base <branch>]`: 지정한 티켓에서 진행한다. 나머지 인자는 이번 수정 지시다.
- 대상이 없으면 [references/candidates.md](references/candidates.md)에서 후보를 찾아 선택받는다. 세션에서 이미 지정한 티켓을 다시 묻지 않는다.
- 이슈와 완료 조건, 기존 PR과 브랜치를 읽어 fresh/rework를 구분한다. rework는 같은 PR·worktree에서 이어간다. 살아 있는 다른 구현·리뷰 작업과 동시에 브랜치를 쓰지 않는다.
- fresh는 네이티브 blocker가 실제로 종료되고 연결 PR이 머지됐는지 확인한다. 열려 있으면 시작하지 않는다. rework도 새 blocker가 추가됐는지 확인한다.
- 조건이 모호하면 공통 `references/ticket-criteria.md`로 의미를 확인한다. 제품 결정이 필요한 부분만 남겨 두고 독립적인 조사·준비는 계속한다.
- `in-progress`로 전환하고, fresh의 base는 사용자 인자 또는 메인 체크아웃의 로컬 브랜치에서 정한다. `main`을 가정하지 않는다.

```bash
bash ~/.agents/skills/implement/scripts/prepare-worktree.sh <N> <ascii-slug> [<base>]
```

rework는 base를 생략한다. 기존 로컬 변경·전용 커밋이 발견되면 보존하고 출처를 확인한다. PR이 있는 clean worktree의 원격 정렬은 `agent-loop/scripts/sync-worktree.sh`를 사용한다.

## 구현과 검증

- 이슈의 목표·완료 조건과 프로젝트 지침을 따른다. Figma 링크가 있는 UI는 관련 스킬과 도구로 노드를 읽고 배치·스타일을 따른다. 디자인과 승인 정책이 충돌하면 그 결정만 보류한다.
- 필요한 테스트·API 요청·브라우저·시뮬레이터·기기 확인을 실제로 수행한다. 구현 세션이라는 이유로 UI 실행을 금지하거나 검증을 다음 호출로 미루지 않는다.
- 자연스러운 경로는 `verify/references/routes.md`를 필요한 부분만 읽는다. UI 증거가 필요하면 관련 매체 reference를 읽는다. 이미 조건을 확인한 유효한 근거가 있으면 중복 실행하지 않는다.
- 범위 안의 구현 실패는 수정하고 영향받은 검사를 다시 수행한다. 회귀 테스트는 위험과 재사용 가치에 맞게 추가한다. 타입 체크 통과를 런타임 동작의 증거로 쓰지 않는다.
- 실행할 수 없는 조건은 실제 환경·권한 장애를 확인하고 미검증으로 남긴다. “설치 여부 미확정”처럼 조사하지 않은 추측을 이유로 쓰지 않는다. 다른 조건은 계속 확인한다.

## 최종 head와 PR

1. origin을 fetch하고 base를 양방향으로 확인한다. 로컬 base가 remote보다 앞서 있으면 사용자의 base를 대신 push하지 않고 알린다. remote base가 움직였으면 feature에 merge하고 영향받은 검사를 다시 한다. 충돌을 임의 해소하지 않고 기록한다.
2. 공통 worktree 문서의 `comment-cleaner` → 필요한 검사 → `commit` 경로를 따른다. 새 테스트도 함께 반영한다. 최종 커밋에서 검증하거나 실행 입력이 최종 커밋과 같음을 확인한다. 검사 후 소스가 바뀌면 해당 결과를 다시 판단한다.
3. feature branch를 push한다. PR head가 검증 대상과 같고 worktree가 clean인지 확인한다. 검증 결과를 공유 `verification.md` 형식으로 작성한다. 게시 절차가 필요하면 `verify/references/publishing.md`를 읽는다.
4. fresh는 non-draft PR을 연다. 본문에 트래커 바인딩 줄, 실제 base, 구현 설명, **실제 검증 결과**를 넣는다. rework는 최신 본문의 구현 설명과 같은 검증 섹션을 갱신하고 사람의 다른 글을 보존한다.
5. 게시된 본문·head·상태를 읽어 확인한다. 필요한 검증이 전부 충족이면 끝낸다. 남은 검증이 있을 때만 그 항목과 `verify <N>` 경로를 안내한다.

유료 리뷰나 머지는 이 스킬이 시작하지 않는다. PR을 진행 공유용으로 일찍 열지 않는다.

## 끝나는 상태

- 구현과 확인 결과가 준비됐으면 `awaiting-review`. 환경 때문에 남은 미검증 조건은 PR과 채팅에서 명시한다.
- 해결되지 않은 구현 오류·정책·base 충돌은 `blocked`. 결정 근거와 재개 경로를 남긴다. base 충돌만이면 이미 열린 PR을 `land`가 받을 수 있다. PR이 아직 없으면 구현을 재개해 PR부터 준비한다.
- 팀의 결정이 필요한 코멘트는 초안 승인을 기다리되 독립 작업은 끝낸다.

최종 보고는 PR 링크, 실제 검증 결과, 남은 항목과 필요한 결정이다. 이슈 체크박스는 바꾸지 않는다.
