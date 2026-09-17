# 오류와 해결 방법

| 증상 | 원인 | 확인하거나 할 일 |
|---|---|---|
| `check-env.sh`가 `@playwright/test: MISS`를 표시함 | 저장소에서 설치를 확인하지 못함 | 사용 가능한 브라우저나 임시 테스트 환경을 쓴다. 의존성을 저장소에 설치하는 일은 구현 작업에서 한다. |
| `Executable doesn't exist at …/ms-playwright/…` | 브라우저가 다운로드되지 않음 | `pnpm exec playwright install chromium`을 실행한다. |
| 테스트가 로그인 화면으로 이동함 | 저장한 로그인 상태가 없거나 만료됨 | 사람이 Playwright MCP 브라우저에 로그인한 뒤 `browser_storage_state`로 `.e2e/storage-state/<app>.json`에 저장한다. |
| `browser_*` 도구를 찾을 수 없음 | 현재 환경에 해당 도구가 없음 | 사용할 수 있는 브라우저 도구를 확인하고 같은 일을 할 수 있는 방법을 쓰거나 필요한 기능이 없다고 보고한다. |
| `gh pr edit: unknown flag --attach` | CLI가 첨부 옵션을 지원하지 않음 | [게시 방법](publishing.md)에 따라 다른 첨부 수단을 확인한다. 막히면 PR 첨부 미완료를 적고 로컬 기록물을 사용자에게 제공한다. |
| web에서 `ECONNREFUSED localhost:4000`이 발생함 | API 서버가 시작되지 않음 | `dev-servers.sh start head <root> api doko`를 실행한다. web은 같은 세트의 API가 필요하다. |
| web 서버가 다른 API 포트로 요청함 | `.env.local`의 `VITE_API_BASE_URL`이 적용됨 | `dev-servers.sh`는 세트별 값을 지정한다. `.e2e/servers/<set>/doko.log`에서 Vite가 출력한 URL을 확인한다. |
| `port … is taken by another process` | 이전 서버 세트나 사용자의 개발 서버가 포트를 사용 중 | 자신이 시작한 서버는 `dev-servers.sh stop head`·`stop base`로 종료한다. `lsof -i :<port>`로 확인할 수 있으며 다른 사람의 서버는 승인 없이 종료하지 않는다. |
| base worktree에서 lockfile 문제로 `pnpm install`이 실패함 | base의 lockfile이 다름 | base는 자기 lockfile로 설치해야 한다. 이런 차이가 생길 수 있음을 감안하고 `node_modules`를 복사하지 않는다. |
| base worktree에 `routeTree.gen.ts`가 없음 | gitignore로 제외된 생성 파일 | `base-worktree.sh`가 메인 체크아웃에서 복사한다. base에 아직 해당 앱이 없으면 그 앱의 변경 전 화면도 없다. |
| `argent`가 기기를 찾지 못함 | 시뮬레이터가 부팅되지 않음 | `argent run boot-device`나 Xcode → Simulator로 부팅한다. |
| `argent flow run`의 첫 `launch` 단계가 실패함 | Metro가 꺼져 있거나 bundle id가 다름 | 해당 세트의 Metro를 시작하고 `launch-app`의 bundle id를 확인한다. |
| `ffmpeg: command not found` | ffmpeg가 설치되지 않음 | `brew install ffmpeg`를 실행한다. webm을 mp4로 변환하거나 프레임을 추출할 때만 필요하다. |
| 테스트 DB 연결이 거부됨 | 테스트 실행이나 DB 준비가 실패함 | `pnpm test <path>`로 실행하고 실제 오류를 확인한다. 원인을 확인하지 않은 채 단정하지 않는다. |
| PR 본문에 `verify` 마커 쌍이 두 개 있음 | 어떤 검증 기록을 쓸지 불명확함 | 본문을 보존하고 갱신할 기록을 먼저 확인한다. 추측해서 한쪽을 지우지 않는다. |
| worktree에 미커밋 변경이나 로컬 전용 커밋이 있음 | 다른 변경을 덮어쓰거나 잘못된 코드를 검증할 수 있음 | 작업을 보존하고 어느 작업에서 만든 변경인지 확인한 뒤 검증이나 원격 변경 반영을 진행한다. |
