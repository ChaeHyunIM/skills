# 작업 폴더와 doko 실행 명령

여기에 연결된 스크립트는 doko의 pnpm 모노레포를 기준으로 한다. 다른 저장소에서는 해당 저장소의 지침과 실행 명령부터 확인하고, doko 전용 스크립트를 그대로 실행하지 않는다.

## worktree 준비와 유지

- worktree는 `.claude/worktrees/issue-<N>-<slug>`, 브랜치는 `agent/issue-<N>-<slug>`를 쓴다. slug는 티켓 제목의 뜻을 옮긴 짧은 영어 이름이며 ASCII 소문자·숫자·하이픈으로 만든다.
- 새 작업의 base는 사용자가 지정한 `--base`, 메인 체크아웃의 현재 로컬 브랜치 순서로 정한다. detached HEAD 상태이거나 다른 `agent/issue-*` 브랜치 위에서 시작해야 하면 대상을 확인한다. 메인 체크아웃의 커밋하지 않은 변경은 새 worktree에 포함되지 않는다고 알린다.
- [prepare-worktree.sh](../../implement/scripts/prepare-worktree.sh)가 작업 폴더와 브랜치를 확인하고 의존성 설치와 routeTree 복사를 한다. 기존 작업은 덮어쓰지 않는다. 빈 디렉터리에서 Git이 상위 저장소를 찾은 것은 아닌지 `--show-toplevel`로 확인한다.
- 기존 PR의 worktree를 원격 브랜치에 맞출 때는 `agent-loop/scripts/sync-worktree.sh <worktree> <branch>`를 쓴다. 커밋하지 않은 변경, 로컬에만 있는 커밋, 다른 브랜치가 있으면 진행하지 않고 fast-forward만 허용한다. reset이나 자동 stash로 우회하지 않는다.
- PR이 머지될 때까지 worktree를 남긴다. 머지한 뒤에도 세션이 닫힐 때까지 보존하고, 정리는 `tidy-merged`로 한다.

## 커밋하기 전 검사

코드를 바꾸고 커밋할 때는 `comment-cleaner` → 필요한 검사 → `commit` 스킬 → push 순서로 진행한다. 코드, 의존성, 환경이 같고 이미 통과한 검사는 재사용한다. 주석 정리나 base 반영으로 검사할 내용이 달라졌으면 관련 검사를 다시 한다.

- 타입 체크는 `pnpm check-types:<app>`을 쓴다. 앱 이름은 `doko`, `doko-app`, `admin`, `api`다. `tsc`·`turbo run`을 직접 호출하지 않는다.
- 테스트는 `pnpm test <path>`를 쓴다. `vitest`를 직접 호출하지 않는다. 새 테스트는 같은 문제가 다시 생길 위험과 반복 사용할 가치가 있을 때 추가한다.
- 포맷과 lint는 프로젝트 명령을 쓴다. 타입 체크만 통과했다고 실제 동작까지 확인된 것으로 처리하지 않는다.
- 커밋은 `commit` 스킬로 만들고 Codex의 `Co-Authored-By` trailer 규칙을 지킨다. merge 충돌을 해결한 경우도 같은 절차를 따른다. 기존 merge 상태와 메시지를 보존하고 필요한 검사를 마친 뒤 커밋한다.

## doko 실행 환경

- worktree마다 `pnpm install`이 필요하다. routeTree가 없으면 메인 체크아웃의 파일을 복사한다. `tsr generate`를 직접 실행하는 방식으로 바꾸려면 생성 결과의 타입 선언이 유지되는지 먼저 확인해야 한다.
- 검증 서버의 head 포트는 API 4000, doko 3000, admin 3001, Metro 8081이다. base 포트는 같은 순서로 4100, 3100, 3101, 8082다. 검증할 앱과 API만 시작한다.
- web은 같은 head/base 세트의 API를 사용해야 한다. 설정과 실제 연결 대상이 맞는지 확인한다. 포트를 쓰는 다른 프로세스를 임의로 종료하지 않는다.
- `packages/scripts`의 TypeScript 파일은 그 디렉터리에서 Bun으로 실행한다. 환경 파일이나 접속 문자열 원문을 출력하지 않는다.
- DB 테스트나 개발 환경을 고를 때는 프로젝트의 branch_id 확인과 쓰기 승인 규칙을 따른다. 검증 환경을 맞추려고 `db:push`·`db:migrate`를 임의로 실행하지 않는다.
