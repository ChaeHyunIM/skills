# 작업 폴더와 실행 명령

worktree 설정은 저장소의 `.claude/agent-loop/config`에 둔다. `prepare-worktree.sh`가 source하는 파일이므로 스크립트에서 읽는 변수만 넣는다. config는 Git에 커밋하고, 비밀값은 같은 디렉터리의 `.env.local`에 둔다. 처음 만들 때는 [config.example](../templates/config.example)을 복사해 채운다.

| 키 | 뜻 |
|---|---|
| `INSTALL_CMD` | 새 worktree에서 한 번 실행하는 의존성 설치 명령. 비우면 건너뛴다. |
| `COPY_FROM_MAIN` | gitignore된 생성 파일의 glob. 메인 체크아웃에서 복사한다. |

config 파일이 없으면 스크립트는 exit code 78로 종료한다. 이때 설정값을 추측해 실행하지 말고 저장소 지침을 확인한다. 검사 명령은 저장소 지침(`AGENTS.md` 등), 앱 실행 방법은 프로젝트 검증 스킬을 참고한다.

## worktree 준비와 유지

- worktree는 `.claude/worktrees/issue-<N>-<slug>`, 브랜치는 `agent/issue-<N>-<slug>`를 쓴다. slug는 티켓 제목의 뜻을 옮긴 짧은 영어 이름이며 ASCII 소문자·숫자·하이픈으로 만든다.
- 새 작업의 base는 사용자가 지정한 `--base`, 메인 체크아웃의 현재 로컬 브랜치 순서로 정한다. detached HEAD 상태이거나 다른 `agent/issue-*` 브랜치 위에서 시작해야 하면 대상을 확인한다. 메인 체크아웃의 커밋하지 않은 변경은 새 worktree에 포함되지 않는다고 알린다.
- [prepare-worktree.sh](../../implement/scripts/prepare-worktree.sh)가 작업 폴더와 브랜치를 확인하고, `INSTALL_CMD`로 의존성을 설치한 뒤 `COPY_FROM_MAIN`에 지정한 파일을 복사한다. 기존 작업은 덮어쓰지 않는다. 빈 디렉터리에서 Git이 상위 저장소를 찾은 것은 아닌지 `--show-toplevel`로 확인한다.
- 기존 PR의 worktree를 원격 브랜치에 맞출 때는 fetch한 뒤 `git merge --ff-only`만 쓴다. 커밋하지 않은 변경이나 로컬에만 있는 커밋이 있거나, 다른 브랜치가 체크아웃돼 있으면 기존 상태를 보존하고 동기화를 중단한다. reset이나 자동 stash로 우회하지 않는다.
- PR이 머지될 때까지 worktree를 남긴다. 머지한 뒤에도 세션이 닫힐 때까지 보존하고, 정리는 `tidy-merged`로 한다.

## 커밋하기 전 검사

코드를 바꾸고 커밋할 때는 `comment-cleaner` → 필요한 검사 → `commit` 스킬 → push 순서로 진행한다. 코드, 의존성, 환경이 같고 이미 통과한 검사는 재사용한다. 주석 정리나 base 반영으로 검사할 내용이 달라졌으면 관련 검사를 다시 한다.

- 타입 체크, 테스트, 포맷, lint는 저장소 지침에 지정된 명령을 쓴다. 테스트 DB 준비 같은 사전 작업이 포함돼 있을 수 있으므로 `tsc`·`vitest`를 직접 호출하지 않는다.
- 새 테스트는 같은 문제가 다시 생길 위험과 반복 사용할 가치가 있을 때 추가한다.
- 커밋은 `commit` 스킬로 만들고 Codex의 `Co-Authored-By` trailer 규칙을 지킨다. merge 충돌을 해결한 경우도 같은 절차를 따른다. 기존 merge 상태와 메시지를 보존하고 필요한 검사를 마친 뒤 커밋한다.

## 실행 환경

- 앱 실행·종료 방법, 사용할 포트, 로그인 방법은 프로젝트 검증 스킬(`.agents/skills/verify-<app>/`)을 따른다.
- 자신이 시작한 프로세스만 종료한다. 포트를 쓰는 다른 프로세스나 사람의 개발 서버를 임의로 종료하지 않는다.
- 환경 파일이나 접속 문자열 원문을 출력하지 않는다. 다른 worktree로 옮길 때도 내용을 읽지 않고 복사만 한다.
- DB 테스트나 개발 환경을 고를 때는 프로젝트의 확인·쓰기 승인 규칙을 따른다. 검증 환경을 맞추려고 마이그레이션이나 스키마 반영을 임의로 실행하지 않는다.
