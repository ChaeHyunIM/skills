# Worktree와 doko 프로필

현재 헬퍼는 doko의 pnpm 모노레포를 대상으로 한다. 다른 저장소에서는 그 저장소 지침과 실행 명령을 먼저 확인하고, doko 전용 헬퍼를 그대로 실행하지 않는다.

## 작업 위치

- 경로 `.claude/worktrees/issue-<N>-<slug>`, 브랜치 `agent/issue-<N>-<slug>`를 유지한다. slug는 한국어 제목의 의미를 옮긴 ASCII 영문 소문자·숫자·하이픈이다.
- 새 base 선택은 사용자 `--base` → 메인 체크아웃 현재 로컬 브랜치 순서다. detached HEAD나 다른 `agent/issue-*` 위에 쌓아야 하면 대상을 확인한다. 커밋 안 된 메인 변경은 따라오지 않는다고 알린다.
- `implement/scripts/prepare-worktree.sh`가 작업 위치·브랜치를 확인하고 설치·routeTree 복사를 한다. 기존 작업이 있으면 덮어쓰지 않는다. 빈 디렉터리에서 Git이 상위 저장소로 빠지지 않는지 `--show-toplevel`로 확인한다.
- 기존 PR worktree를 remote에 맞출 때는 `agent-loop/scripts/sync-worktree.sh <worktree> <branch>`를 쓴다. dirty·로컬 전용 커밋·다른 브랜치를 거부하고 fast-forward만 한다. reset이나 자동 stash로 우회하지 않는다.
- PR이 머지될 때까지 worktree를 남긴다. 머지 후 세션이 닫힌 뒤 정리는 `tidy-merged`에서 한다.

## 커밋과 검사

코드 변경을 커밋할 때는 `comment-cleaner` → 필요한 검사 → `commit` 스킬 → push 순서다. 동일한 코드·의존성·환경에서 이미 통과한 검사는 재사용한다. cleaner나 base sync가 검사 입력을 바꾸면 영향받은 검사를 다시 실행한다.

- 타입 체크: `pnpm check-types:<app>` (`doko`, `doko-app`, `admin`, `api`). `tsc`·`turbo run` 직접 호출 금지.
- 테스트: `pnpm test <path>`. `vitest` 직접 호출 금지. 새 테스트는 회귀 위험과 재사용 가치가 있을 때 추가한다.
- 포맷·lint는 프로젝트 명령을 쓴다. 런타임 조건을 타입 체크 통과만으로 충족 처리하지 않는다.
- 커밋은 `commit` 스킬을 통하고 Codex trailer를 지킨다. merge 해소도 이 경로에서 기존 merge 상태·메시지를 보존하며, 필요한 검사를 마친 뒤 커밋한다.

## doko 환경

- worktree별 `pnpm install`이 필요하다. routeTree가 누락되면 메인 체크아웃의 파일을 복사하는 기존 우회법을 사용한다. 직접 `tsr generate`를 실행하는 변경은 생성 결과의 타입 선언 보존을 먼저 확인해야 한다.
- 검증 헬퍼의 head 포트는 api 4000, doko 3000, admin 3001, Metro 8081이고 base는 4100, 3100, 3101, 8082다. 필요한 표면만 띄운다.
- web은 같은 세트의 API를 사용해야 한다. 설정·연결 대상이 실제로 맞는지 확인한다. 포트를 사용 중인 다른 프로세스를 임의로 종료하지 않는다.
- `packages/scripts`의 TS는 그 디렉터리에서 Bun으로 실행한다. 환경 파일·접속 문자열 원문을 출력하지 않는다.
- DB 테스트·개발 환경을 선택할 때 프로젝트의 branch_id 확인과 쓰기 승인 규칙을 지킨다. `db:push`·`db:migrate`로 검증 환경을 임의로 맞추지 않는다.
