---
name: verify
description: 열린 PR의 남은 완료 조건이나 재검증 요청을 실행으로 확인하고 PR 본문에 근거를 기록한다.
---

# verify

남은 조건을 확인하거나 코드·환경이 달라진 결과를 다시 검증한다. `implement`가 이미 필요한 검증을 마쳤다면 이 스킬은 필수가 아니다. 유효한 기존 근거는 재사용한다.

시작할 때 `~/.agents/skills/agent-loop/CONTRACT.md`와 공통 `references/verification.md`를 읽는다. 이 스킬은 **제품 코드·티켓 상태·이슈 체크박스를 변경하지 않고**, PR 생성·commit·push·유료 리뷰·머지를 하지 않는다.

## 입력

| 호출 | 조건과 대상 |
|---|---|
| `verify <N>` | 트래커 티켓의 완료 조건과 연결된 열린 PR |
| `verify --pr <PR>` | 바인딩으로 연결된 티켓의 조건. 없으면 기존 PR 검증 항목 |
| `verify` | 현재 diff와 사용자 요청. 조건이 명확하면 진행하고 의미를 정해야 할 때만 확인 |

`--base <ref>`는 비교 대상을 지정한다. 기본은 PR의 base이며 `main`을 가정하지 않는다. `--no-before`는 비교 생략, `--app`은 표면 제한, `--no-publish`는 로컬 보고만 한다. PR이 없으면 실제 로컬 SHA로 보고하고 PR을 만들지 않는다.

## 실행

1. 최신 PR·이슈·기존 기록을 읽고 실제 worktree를 찾는다. 제품 소스가 dirty하거나 다른 작업이 실행 중이면 덮어쓰지 않는다. 원격 정렬은 `agent-loop/scripts/sync-worktree.sh`, 대상 확인은 `agent-loop/scripts/check-worktree.sh`를 사용한다.
2. `scripts/verified-head.sh`로 기존 기록 상태를 확인한다. 최신 조건·환경·요청을 대조해 다시 볼 항목을 정한다. 같은 head의 유효한 결과를 이유 없이 재실행하지 않는다. stale 결과의 재사용은 공통 `verification.md`의 입력·의존성 확인을 따른다.
3. 필요한 관찰과 통과 기준을 정하고 [references/routes.md](references/routes.md)의 관련 경로를 실행한다. 준비·실행 오류를 확인하고 독립 조건은 계속한다. 제품 버그는 재현과 실제 실패를 남기며 검증을 통과시키려고 소스를 고치지 않는다.
4. [references/quality-gates.md](references/quality-gates.md)로 사용할 근거가 조건·대상·환경을 설명하는지 확인한다. 직접 관찰도 재현 경로와 실제 결과가 있으면 사용할 수 있다. 스크린샷 하나로 저장·권한 같은 비가시 결과를 증명하지 않는다.
5. 실행 후 소스와 head를 다시 확인하고, [references/publishing.md](references/publishing.md)에 따라 기존 PR의 같은 검증 섹션을 갱신한다. 소스나 head가 바뀌었으면 그 변경을 포함한 증거로 표현하지 않는다.

## 필요한 환경만 준비

- 순수 함수·기존 테스트에는 브라우저·base 서버가 필요 없다. 같은 입력에서 이미 통과한 타입 체크도 재사용한다. 실행 경로를 막는 오류는 기록하고 영향 없는 경로는 계속한다.
- before는 회귀 수정·비교 요청·변경 귀속을 확인할 때 사용한다. head의 결과만으로 조건을 판단할 수 있으면 생략할 수 있다. 명시적으로 요청된 비교가 불가능하면 그 요청이 남았다고 적는다.
- UI의 일회성 확인은 사용 가능한 브라우저·기기 도구로 수행한다. 반복 회귀 위험이 크거나 사용자가 요청했을 때 재생 가능한 spec·flow를 만든다.
- 지속 검증 파일은 구현 작업에서 PR에 반영한다. 이 스킬의 새 파일·설정은 임시 디렉터리 또는 이미 gitignored인 산출물 경로에 둔다. 설정 설치·의존성·ignore 파일 변경을 이 스킬에 끼워 넣지 않는다.
- doko 서버·worktree가 필요하면 [references/environment.md](references/environment.md), web 재생은 [references/web-playwright.md](references/web-playwright.md), 앱 재생은 [references/app-argent.md](references/app-argent.md)를 읽는다.
- 알려진 실행 장애는 [references/errors.md](references/errors.md)에서 해당 증상만 확인한다.

DB 쓰기·마이그레이션·로그인·매체 게시 권한은 프로젝트와 도구의 실제 경계를 따른다. 환경 장애를 추측하지 않고 필요한 경로만 점검한다.

## 완료

모든 요청된 조건에 충족·미충족·미검증과 근거를 남기고, 사용한 코드·환경을 밝힌다. 자신이 시작한 서버·녹화·임시 worktree만 정리한다. 수정이 필요한 항목은 재현 정보와 함께 `implement`로 이어갈 수 있게 보고한다.
