# Playwright로 web 동작 확인하기

web 캡처·녹화나 반복 실행 시 읽는다. 직접 조작도 [필수 기록물 기준](routes.md)을 따른다. 아래 spec 작성은 반복 실행할 가치가 있을 때 사용한다.

바로가기: [설정](#기존-테스트-설정-확인) · [로그인](#로그인-상태-저장) · [조작 기록](#브라우저-조작을-테스트로-옮기기) · [테스트](#테스트-작성-기준) · [전후 실행](#변경-후-코드와-변경-전-코드에서-실행) · [첨부](#pr에-캡처와-영상-첨부) · [결과](#결과-판단과-기록)

설정된 브라우저 도구와 기존 Playwright 환경을 사용한다. `verify`에서는 저장소에 계속 남을 설정을 설치하지 않는다. 새 테스트 환경이 필요하면 이미 gitignore로 제외된 폴더나 임시 작업 폴더에 만든다. 승인된 회귀 테스트는 나중에 `implement`에서 PR에 반영할 수 있다.

## 기존 테스트 설정 확인

설정 설치는 구현 작업에서 한다. 기존 파일은 다음 위치에 있다.

```
playwright.config.ts          저장소 루트. testDir은 apps/, 대상은 apps/*/e2e/*.spec.ts
apps/<app>/e2e/<claim>.spec.ts
.e2e/                          gitignore로 제외: storage-state/, results/, evidence/, servers/
```

설정에서 읽는 환경 변수는 다음과 같다.

| 변수 | 용도와 기본값 |
|---|---|
| `E2E_BASE_URL` | 검사할 서버. 기본은 `http://localhost:3000` |
| `E2E_STORAGE_STATE` | 저장한 로그인 상태. 필요한 경우 지정 |
| `E2E_OUT` | 실행 결과 폴더. 기본은 `.e2e/results` |
| `E2E_TEST_DIR` | 임시 테스트 폴더를 사용할 때 지정 |
| `E2E_VIDEO` | 새 화면·사용자 흐름 검증 시 `1`로 지정해 성공한 실행도 녹화 |

실패한 실행의 trace를 보관하고, JSON 보고서는 `$E2E_OUT/report.json`에 저장한다.

## 로그인 상태 저장

doko와 admin은 소셜 로그인을 사용하므로 테스트에서 직접 로그인할 수 없다. 사람이 Playwright MCP 브라우저에 한 번 로그인하고 에이전트가 그 상태를 저장한다. 브라우저는 프로필을 유지하므로 로그인 상태가 세션 사이에도 이어진다.

1. 사용자에게 “Playwright MCP 브라우저에서 <app>에 로그인해 주세요. 끝나면 알려 주세요.”라고 요청한다.
2. `browser_storage_state`로 쿠키와 localStorage를 `.e2e/storage-state/<app>.json`에 저장한다.
3. 테스트에 `E2E_STORAGE_STATE=.e2e/storage-state/<app>.json`을 전달한다.

이 파일은 gitignore로 제외하고 첨부하거나 내용을 인용·붙여넣지 않는다. 테스트가 확인할 화면 대신 로그인 화면으로 이동하면 로그인 상태가 만료된 것이므로 1단계부터 다시 진행한다. 로그인 제공자의 화면을 자동화하려고 시도하지 않는다.

## 브라우저 조작을 테스트로 옮기기

Playwright MCP의 영구 설정이 필요하면 사람이 실행하거나 승인한 뒤 설치한다.

```bash
claude mcp add playwright -- npx @playwright/mcp@latest --caps testing          # Claude Code
# Codex: ~/.codex/config.toml
# [mcp_servers.playwright]
# command = "npx"
# args = ["@playwright/mcp@latest", "--caps", "testing"]
```

1. `browser_navigate`로 head의 사용자 진입점에 접속한다. 요소 탐색·조작은 `browser_snapshot`, 배치·시각 상태 확인은 캡처를 사용한다.
2. `browser_start_recording`을 시작하고 `browser_click`·`browser_type` 등으로 조작한다. `browser_verify_text_visible`·`browser_verify_element_visible`·`browser_verify_value`로 결과를 확인한다.
3. `browser_stop_recording`이 조작을 Playwright 코드로 반환한다. 요소를 잘못 선택한 부분은 `browser_generate_locator`로 다시 찾는다.
4. 아래 기준으로 테스트를 작성한다. 기록된 코드에는 확인할 조건, 이름 붙인 캡처, assertion의 시간 제한이 빠져 있으므로 그대로 붙여넣지 않는다.

`browser_start_recording`은 조작 코드를 기록한다. 화면 영상은 별도 녹화 도구나 `E2E_VIDEO=1` 실행으로 확보한다.

Claude Code에서 Playwright MCP가 없으면 1단계는 Chrome MCP로 대신할 수 있다. 이 도구는 코드를 생성하지 않으므로 화면 정보를 보고 테스트를 작성한다. 직접 확인한 결과라면 그렇게 표시하고, 반복 실행할 가치가 있을 때만 테스트로 만든다.

## 테스트 작성 기준

각 assertion이 어느 완료 조건을 확인하는지 알 수 있게 작성한다. 관련 있는 조건은 짧은 흐름 하나에서 함께 확인할 수 있다. 아래는 기본 예시이며 전체 예시는 `templates/example.spec.ts`에 있다.

```ts
import { test, expect } from "@playwright/test";

test("이미 참여한 미션을 다시 누르면 '이미 참여 중' 안내가 표시된다", async ({ page }, info) => {
  info.annotations.push({ type: "claim", description: "YOU-123 완료 조건 2" });
  await page.goto("/missions/42");
  await page.screenshot({ path: info.outputPath("before-action.png") });
  await page.getByRole("button", { name: "참여하기" }).click();
  await page.screenshot({ path: info.outputPath("action.png") });
  await expect(page.getByText("이미 참여 중")).toBeVisible({ timeout: 3_000 });
  await page.screenshot({ path: info.outputPath("result.png") });
});
```

- 요소는 role·text, `data-testid`, CSS 순서로 찾는다. `page.waitForTimeout`은 쓰지 않고 assertion이 결과를 기다리게 한다.
- assertion의 시간 제한은 완료 조건에서 약속한 시간과 맞춘다.
- 조작 전·조작·결과 지점의 캡처에는 이름을 붙여 보관한다. PR에 넣을 스틸 이미지로 사용한다.
- 화면 상태는 assertion과 캡처로 확인한다. 새 화면은 흐름 영상도, 기존 화면 변경은 base/head 캡처도 확보한다.
- 테스트에 필요한 데이터는 개발 DB에서 찾거나 만들고, 직접 만든 데이터는 정리한다. 다른 사람이 지울 수 있는 데이터에 의존하면 결과가 불안정해질 수 있으므로 피할 수 없다면 그 점을 밝힌다.

## 변경 후 코드와 변경 전 코드에서 실행

```bash
# head — 새 화면·사용자 흐름 녹화
E2E_VIDEO=1 E2E_BASE_URL=http://localhost:3000 E2E_STORAGE_STATE=.e2e/storage-state/doko.json E2E_OUT=.e2e/results/head \
  pnpm exec playwright test apps/doko/e2e/<claim>.spec.ts --project=chromium
# base — 기존 화면 변경 등 routes.md의 비교 대상
E2E_BASE_URL=http://localhost:3100 E2E_STORAGE_STATE=.e2e/storage-state/doko.json E2E_OUT=.e2e/results/base \
  pnpm exec playwright test apps/doko/e2e/<claim>.spec.ts --project=chromium
```

`$E2E_OUT/report.json`의 `suites[].specs[].tests[].results[].status`에서 `passed`·`failed`·`timedOut`을 확인한다.

이전 코드 확인에서는 admin 클라이언트가 `VITE_API_BASE_URL`을 읽는 부분을 찾지 못했다. base의 admin 서버가 head API를 사용할 수도 있으므로 admin을 비교하기 전에 현재 `apps/admin` 코드를 확인한다.

약속한 동작 시간을 넘겼으면 미충족, 테스트 실행기나 환경 문제로 시간을 넘겼으면 미검증이다. 확인한 원인상 다시 실행할 이유가 있을 때만 재시도하고 그 사실을 보고한다.

base에 없는 새 화면·기능은 비교 대상 없음으로 적는다. 기존 기능의 진입 실패는 실제 단계·원인을 기록하고 제품 실패와 환경 문제를 구분한다.

## PR에 캡처와 영상 첨부

설정에 따라 Playwright가 `$E2E_OUT/<test-dir>/`에 영상, trace, 캡처를 남긴다. 기록에 필요한 파일만 `.e2e/evidence/<run>/`으로 복사한다. `claim-2-head.mp4`, `claim-2-before-action.png`처럼 짧고 공백 없는 이름을 쓴다.

GitHub는 `.webm`을 표시하지만 여러 환경에서 재생하려면 H.264를 권장한다. 변환할 때는 다음 명령을 쓴다.

```bash
ffmpeg -y -i video.webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart claim-2-head.mp4
```

`evidence-block.mjs`는 파일당 10 MB를 허용한다. 게시 도구의 한도도 확인하고, 초과하면 진입·조작·결과와 가독성을 유지하며 구간·해상도를 조정한다.

변경 전후 영상을 나란히 보여 줄 필요가 있을 때만 다음 절차를 쓴다.

1. `gh pr comment <PR> --body-file own-lines.md --attach before.mp4 --attach after.mp4`로 임시 코멘트를 올린다.
2. `gh api repos/{owner}/{repo}/issues/comments/<id> --jq .body`로 `https://github.com/user-attachments/assets/...` URL을 가져온다.
3. `results.json`의 해당 `video-pair` 항목에 `beforeUrl`·`afterUrl`을 넣고 본문을 다시 만든다. `evidence-block.mjs`가 영상을 별도 줄 대신 HTML 표의 `<video>` 셀에 넣는다.
4. 게시된 PR 본문을 다시 읽어 확인한 뒤에만 임시 코멘트를 지운다.

head 영상은 별도 줄에 넣는다. base 영상 범위는 [조건별 기준](routes.md), 첨부가 막힌 경우는 [게시 방법](publishing.md)을 따른다.

## 결과 판단과 기록

실제 실행 결과와 [필수 기록물](routes.md)로 `results.json`을 채운다. 파일 형식은 `scripts/evidence-block.mjs` 첫 주석에 있다.

`detail`에는 충족이면 테스트와 assertion을, 미충족이면 기대한 결과와 실제 결과를, 미검증이면 확인하지 못한 원인을 적는다.
