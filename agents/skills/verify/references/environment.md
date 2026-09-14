# doko 검증 환경

먼저 공통 [작업 환경](../../agent-loop/references/workspace.md)의 doko 설명을 읽는다. 다른 저장소에서 아래 스크립트를 그대로 실행하지 않는다.

- 무엇이 설치됐는지 불명확하면 `scripts/check-env.sh`를 실행하고 필요한 항목을 확인한다. web 도구가 없다는 이유로 API나 앱 검증까지 중단하지 않는다.
- `check-env.sh --install-config`는 저장소 설정을 바꾸므로 `verify`에서는 실행하지 않는다. 설정이 필요하면 사용 가능한 브라우저·기기 도구나 임시 테스트 환경을 사용한다. 저장소에 계속 사용할 설정은 구현 작업에서 설치한다.
- head 서버는 `scripts/dev-servers.sh start head <worktree> <apps...>`로 시작한다. 확인할 web 앱이 같은 세트의 API에 연결됐는지 확인한다.
- 변경 전 비교가 필요할 때만 PR base를 fetch하고 정확한 ref/SHA로 `scripts/base-worktree.sh <ref>`를 실행한다. head의 메인 체크아웃을 stash·switch해서 비교하지 않는다. base에서도 필요한 앱과 API만 시작한다.
- 앱은 실제 dev client가 검사할 Metro 서버에 연결됐는지 확인한다. base 비교를 마치면 원래 head 서버로 되돌린다.
- 사용한 서버와 worktree 경로를 기록한다. 자신이 시작한 서버 세트만 `dev-servers.sh stop <set>`으로 종료한다. 이번에 만든 base worktree만 `base-worktree.sh --remove <path>`로 정리한다. 다른 작업에서 쓰는 서버나 폴더는 지우지 않는다.
- DB와 서비스에 연결하기 전에 프로젝트의 안전 규칙으로 실제 대상을 확인한다. 환경 파일을 복사했다고 dev/prod 확인까지 끝난 것은 아니다.
