# doko 검증 환경

공통 `agent-loop/references/workspace.md`의 doko 프로필을 읽는다. 다른 저장소에는 아래 헬퍼를 그대로 실행하지 않는다.

- 설치 상태가 불명확하면 `scripts/check-env.sh`를 실행해 필요한 경로의 항목만 읽는다. web 도구가 빠졌다는 이유로 API·앱 검증까지 중단하지 않는다.
- `check-env.sh --install-config`는 저장소 설정을 변경한다. `verify`에서는 실행하지 않는다. 설정이 필요하면 기존 브라우저·기기 경로 또는 임시 하네스를 사용하고, 영구 설치는 구현 작업으로 남긴다.
- head 서버: `scripts/dev-servers.sh start head <worktree> <apps...>`. 필요한 web 표면은 같은 세트 API와 연결됐는지 확인한다.
- before가 필요할 때만 PR의 base를 fetch하고 정확한 ref/SHA로 `scripts/base-worktree.sh <ref>`를 실행한다. head의 메인 체크아웃을 stash·switch하지 않는다. base 서버도 필요한 표면만 시작한다.
- 앱은 실제 dev client가 검사 대상 Metro를 사용하는지 확인한다. base 비교 뒤에는 원래 head로 돌린다.
- 사용한 서버·worktree 경로를 기록한다. 자신의 서버 세트만 `dev-servers.sh stop <set>`으로 내리고, 이번에 만든 base worktree만 `base-worktree.sh --remove <path>`로 정리한다. 다른 실행의 자원을 삭제하지 않는다.
- DB·서비스 연결 대상은 실행 전에 프로젝트 안전 규칙대로 확인한다. 환경 파일 복사는 dev/prod 검증을 대신하지 않는다.
