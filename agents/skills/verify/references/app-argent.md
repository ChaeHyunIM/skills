# Argent로 앱 동작 확인하기

앱 캡처·녹화나 반복 실행 시 읽는다. 직접 조작도 [필수 기록물 기준](routes.md)을 따른다. 반복 실행할 flow는 재사용 가치가 있을 때 만들고, `verify`의 새 flow는 임시 프로젝트 폴더에 둔다.

`argent`(`@swmansion/argent`, PATH의 `/opt/homebrew/bin/argent`)는 iOS 시뮬레이터를 조작한다. 에이전트가 앱을 살펴보며 한 조작을 흐름으로 기록하고, 이후 모델 없이 재생할 수 있다.

화면은 H.264 mp4, 초당 30프레임으로 녹화한다. 도구 목록은 `argent tools`, 각 도구의 사용법은 `argent tools describe <name>`으로 확인한다.

## 조작을 확인하며 흐름 기록하기

1. `list-devices`로 기기를 확인하고 `boot-device`로 부팅하거나 이미 켜진 기기에 연결한다. dev client의 bundle id로 `launch-app`을 실행한다. head worktree의 Metro가 실행 중이어야 한다. `dev-servers.sh start head <root> doko-app`의 포트는 8081이다.
2. `flow-start-recording`에 `name: verify/<claim-slug>`와 `project_root: <repo root>`를 전달한다. 이 명령은 `.argent/flows/verify/<claim-slug>.yaml`을 새로 쓴다. `verify`에서 만든 새 흐름은 위 원칙대로 임시 프로젝트 폴더에 둔다.
3. 요소 탐색·조작은 `describe`, 배치·시각 상태 확인은 캡처를 사용한다. `gesture-tap`, `keyboard`, `gesture-swipe`, `open-url` 등 조작은 `flow-add-step`으로 추가해야 기록된다.
4. `await-ui-element`로 기대한 화면 요소가 나타나는지 확인한다. 이 단계가 assertion으로 기록돼 통과 여부를 판단한다. 캡처 전에는 `await-screen-idle`로 화면이 안정될 때까지 기다린다.
5. `flow-add-echo`로 조작 전·조작·결과 지점을 표시하고 각 지점에서 `screenshot`을 찍어 파일을 보관한다.
6. `flow-finish-recording`으로 기록을 마친다.

## 같은 흐름 재생하고 녹화하기

flow YAML은 조작 기록이다. 화면 영상은 `screen-recording-*`로 별도 확보하며, 직접 조작할 때도 진입 전에 녹화를 시작하고 결과 확인 후 종료한다.

```bash
argent run screen-recording-start --output .e2e/evidence/<run>/<claim>-head.mp4
argent flow run .argent/flows/verify/<claim-slug>.yaml --platform ios --json > .e2e/results/head/<claim>.json
argent run screen-recording-stop
```

종료 코드는 통과 여부를, JSON 보고서는 각 단계의 결과를 보여 준다. `await-ui-element`가 실패했다면 그 단계를 미충족 근거로 인용한다.

`argent flow run --update-baselines`는 비교 기준 스크린샷을 저장한다. 다음 실행에서 `screenshot-diff`로 비교할 수 있다. 화면이 같은 모습이어야 하는 조건에만 기준 이미지를 사용한다. 화면 전환 조건은 기다리는 요소가 나타났는지로 판단한다.

## 변경 전 앱과 비교하기

dev client는 한 번에 하나의 Metro 서버만 사용할 수 있다.

1. `dev-servers.sh start base <base-worktree> doko-app`으로 base worktree의 Metro를 8082 포트에서 시작한다.
2. dev 메뉴나 프로젝트 문서의 deep link로 `http://localhost:8082`에 연결한다. `restart-app` 후 같은 조건으로 base 캡처를 확보한다. base 영상도 필요한 경우 `<claim>-base.mp4`로 녹화한다.
3. 비교가 끝나면 8081로 다시 연결한다.

서버 전환이 막히면 head 기록물과 실제 오류를 남긴다. 필수 base 비교가 남은 항목은 미검증이며, `--no-before` 요청은 비교 생략 범위로 기록한다.

## 캡처와 영상 파일

`screen-recording-*`는 기기 해상도의 H.264 mp4를 만든다. `evidence-block.mjs`의 파일당 10 MB 제한을 확인한다. 스틸 이미지는 `screenshot`으로 확보한다.

## 파일을 두는 곳

이미 커밋된 흐름은 `.argent/flows/verify/`에 그대로 둔다. `verify`에서 새로 만든 흐름은 임시 프로젝트 폴더나 이미 gitignore로 제외된 폴더에 둔다. `implement`는 계속 사용할 회귀 테스트 흐름을 PR에 포함하고 최종 head에서 검증할 수 있다. 캡처, 영상, 보고서는 `.e2e/`가 이미 gitignore로 제외돼 있을 때만 그곳에 저장한다.
