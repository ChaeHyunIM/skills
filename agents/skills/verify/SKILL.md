---
name: verify
description: 열린 PR 의 완료 조건을 실제로 돌려 증명하고 `## 완료 조건 검증` 기록을 PR 에 쓸 때. "검증해줘", "동작 확인해줘", "before/after 찍어줘", "테스트 돌려서 증명해줘". implement 가 PR 을 연 뒤, land 전에.
---

# verify

변경이 주장하는 대로 동작하는지 증명한다. 산출물은 주장마다의 판정(충족 / 미충족 / 미검증)과 **리뷰어가 재현할 수 있는 근거** 다. «코드가 맞아 보인다» 는 서술이 아니다.

원칙 하나가 아래 모든 결정을 정한다. **판정은 재현 가능한 검사에서 나오고, 미디어는 부산물이다.** 스크린샷은 상태를 증명한다. 영상은 전환을 보여 주지만 diff 할 수 없으니 판정이 아니다. 판정은 흐름의 assertion 이다. base 에서는 실패하거나 도달 불가, 변경에서는 통과. 그 실행의 영상이 리뷰어가 보는 것이다.

시작할 때 읽는다.

- `~/.agents/skills/agent-loop/CONTRACT.md`. 도구 원칙, worktree, 완료 조건 기록의 소유권.
- `~/.agents/skills/agent-loop/references/acceptance-criteria.md`. 어휘와 기록 템플릿. 이 스킬은 그 실행 엔진이고 다시 적지 않는다.

| | |
|---|---|
| 상태 | 바꾸지 않는다. 기록은 루프 상태가 아니라 커밋의 속성이다 |
| 산출물 | PR 본문의 `## 완료 조건 검증` 블록과 한국어 세션 보고 |
| Never | PR 열기 · push · 티켓 상태 전이 · 이슈 체크박스 · 유료 리뷰 엔진 · `db:push` / `db:migrate` · 프로덕션 쓰기 |

## 루프에서의 자리

- 사람이 열린 PR 에 부른다. `review-round` · `land` 와 같은 축이고 `implement` 의 하위 단계가 아니다. 일부러 새 컨텍스트에서 돈다. 시뮬레이터, base worktree, 게이트가 필요한데 코딩을 막 끝낸 세션에는 그 예산이 없다 (evidence.md 「Verification」).
- 기록의 `검증 대상` sha 를 `land` 가 머지 전에 head 와 대조하고, `review-round` 가 push 뒤 보고한다. `scripts/verified-head.sh <PR> [<worktree>]` 가 그 대조다. `current <sha>` / `stale <sha> <n>` / `missing`. **먼저 돌린다.** `current` 면 이번에 다시 본 항목만 바꾸고, `stale` · `missing` 이면 통째로 바꾼다.
- `results.target.commit` 은 실행한 worktree 의 HEAD 이고 PR 의 `headRefOid` 와 같아야 한다. 먼저 pull 하고, 여기서 push 하지 않는다.

## 입력

| 호출 | 주장의 출처 |
|---|---|
| `verify <N>` | 트래커 티켓 N 의 `## 완료 조건`. PR 은 티켓에 묶인 열린 PR, 코드는 그 worktree (`.claude/worktrees/issue-<N>-<slug>`). `git -C <worktree> pull` 먼저, 전부 거기서 돌린다. 열린 PR 이 없으면 세션 보고만 하고 그렇다고 말한다 |
| `verify --pr <PR>` | PR 본문의 바인딩 줄로 티켓을 찾아 그 완료 조건. 없으면 PR 본문 `## 완료 조건 검증` 의 항목 |
| `verify` (인자 없음) | `git diff <base>...HEAD` 와 사용자의 말에서 도출. **도출한 목록을 보여 주고 확인받은 뒤에 돌린다** |

옵션. `--base <branch>` (기본은 PR 의 `baseRefName`, 없으면 묻는다. `main` 을 가정하지 않는다) · `--no-before` (base 비교 생략, 이유를 적는다) · `--app <doko|admin|doko-app|api>` (표면 제한) · `--no-publish` (세션 보고만, PR 편집 없음).

## 작업 순서

```
Verification progress:
- [ ] 1  PR·worktree 잡기, verified-head.sh, 주장 모으고 확인
- [ ] 2  주장마다 증거 유형·경로·통과 기준 쓰기
- [ ] 3  게이트: pnpm check-types:<app> (lint 관련 diff 면 lint 도)
- [ ] 4  환경: check-env.sh, base worktree, 바뀐 표면의 dev 서버
- [ ] 5  경로 실행, 산출물마다 quality-gates.md
- [ ] 6  세션 보고, evidence-block.mjs 로 PR 블록 렌더, 게시, 읽어서 확인
```

### 1. 주장 모으기

- 주장은 참인지 관찰할 수 있는 문장 하나다. 티켓 문장을 한정어까지 그대로 쓴다.
- diff 에서 도출할 때는 공유 reference 가 조건을 쓰라는 방식대로. 관찰 결과, 필요할 때만 전제나 행동. "구현 완료" · "타입 체크 통과" 는 쓰지 않는다.
- 주장마다 **표면** 을 적는다. `api`, `doko` (web, 3000), `admin` (web, 3001), `doko-app` (Expo), `db`, `none` (순수 함수). 표면이 [4] 에서 띄울 서버를 정한다.

### 2. 분류: 주장의 형태가 증거를 정한다

| 형태 | 예 | 증거 | 판정의 출처 |
|---|---|---|---|
| **상태**. 보이는 것을 말하고 동작 동사가 없다 | 상세 화면 상단에 만료일이 표시된다 | 같은 뷰포트·스크롤의 before/after 스크린샷 쌍 (신규 화면은 after 만) | head 에서 요소·텍스트 존재 assertion. 쌍은 리뷰어용 |
| **전환**. «~하면 / ~누르면 / ~다시 열어도» | 이미 참여한 미션을 다시 누르면 '이미 참여 중' 안내가 표시된다 | head 실행 영상 + 조작 전 · 조작 · 결과 스틸 | 흐름 assertion. head 통과, base 는 실패거나 도달 불가 |
| **비가시**. 렌더 표면이 없다 | 같은 식별자로 두 번 저장하면 두 번째 저장이 거절된다 | 테스트 출력, 또는 요청 + 응답 + 저장된 행 | `pnpm test <path>` 결과, 또는 dev 서비스에 대한 API 호출 |

- 통과 기준을 한 줄로 쓴다. `PASS when <관찰> within <timeout>`. 못 쓰면 주장이 모호한 것이다. 멈추고 묻는다.
- 상태·전환의 판정 행렬. head 통과 + base 실패/도달 불가 → 충족 (이 변경이 만든 동작). head 통과 + base 통과 → 충족에 «base 에서도 성립» 를 붙인다. 주장이 이 변경에 안 걸릴 수 있으니 말한다. head 실패 → 미충족, 실제 결과를 적는다. 러너 에러·타임아웃·환경 없음 → 미검증, 원인을 적는다. 타임아웃은 한 번 재시도.

### 3. 게이트

- diff 가 건드린 앱마다 `pnpm check-types:<app>`. `tsc` · `turbo run` 직접 호출 금지.
- 실패하면 멈춘다. 명백히 범위 안이면 고치고, 아니면 보고하고 멈춘다.
- 통과한 게이트는 어떤 주장의 증거로도 기록하지 않는다.

### 4. 환경

```bash
bash ~/.agents/skills/verify/scripts/check-env.sh              # 설치된 것, 빠진 것, 그 해법
bash ~/.agents/skills/verify/scripts/base-worktree.sh <base>    # base 커밋의 detached worktree
bash ~/.agents/skills/verify/scripts/dev-servers.sh start head "$ROOT" <apps…>
bash ~/.agents/skills/verify/scripts/dev-servers.sh start base "<base-worktree>" <apps…>
```

- 포트 세트는 고정이라 같은 spec 이 양쪽에서 돈다. **head** api 4000 · doko 3000 · admin 3001 · metro 8081. **base** api 4100 · doko 3100 · admin 3101 · metro 8082.
- 주장이 말한 표면만 띄운다. web 표면은 같은 세트의 API 를 함께 띄운다. web 이 시작 시 `VITE_API_BASE_URL` 을 읽기 때문이다.
- `--no-before`, 그리고 `db` · `none` 표면이면 base 세트를 건너뛴다. 둘 다 [6] 에서 내린다.

### 5. 경로 실행

- 주장마다 `references/routes.md` 의 경로를 따른다. web 흐름은 `references/web-playwright.md`, 앱 흐름은 `references/app-argent.md`.
- 산출물이 세기 전에 `references/quality-gates.md` 를 통과시킨다. 거부된 산출물은 명시된 수정으로 다시 찍고, 거부 사유는 세션 로그에 남긴다.
- 순서는 테스트 → API → web → 앱. 싼 증거가 먼저 주장을 끝내는 일이 많다. 테스트가 이미 증명한 주장에 영상을 찍지 않는다.

### 6. 보고와 게시

세션 보고 (한국어).

```
검증 대상: <short sha> · base: <branch>@<short sha> · 환경: <띄운 세트, 쓴 기기>

- 충족  <주장>  — <근거 한 줄>
- 미충족 <주장> — 기대: … / 실제: …
- 미검증 <주장> — 이유: …

거부한 증거: <n>건 (<사유>)   ← 0 이면 생략
```

PR 블록. `results.json` (스키마는 `scripts/evidence-block.mjs` 머리말) 을 쓰고 렌더한다.

```bash
node ~/.agents/skills/verify/scripts/evidence-block.mjs --results .e2e/evidence/<run>/results.json \
  --body-file .e2e/evidence/<run>/pr-body.md > pr-body-next.md
node ~/.agents/skills/verify/scripts/evidence-block.mjs --results … --attach-list   # gh 에 붙일 미디어 경로
gh pr edit <PR> --body-file pr-body-next.md --attach <file>…                        # gh ≥ 2.99
```

- 블록은 `<!-- verify:start -->` 와 `<!-- verify:end -->` 사이에 있고 `## 완료 조건 검증` 섹션 전체를 담는다. 마커 밖은 바이트 단위로 보존한다. PR 본문을 먼저 다시 읽고, 마커 주변을 손으로 고치지 않고, 게시된 본문을 읽어 `./.e2e/...` 경로가 안 남았는지 본다.
- 영상은 자기 줄에 둔다. GitHub 이 플레이어를 그린다. before/after 영상 표는 업로드된 `user-attachments` URL 로 두 번째 패스 (`--video-url`, `web-playwright.md`).
- `gh` 가 2.99 미만이면 `--attach` 가 없다. 텍스트 블록만 게시하고 미디어는 `.e2e/evidence/<run>/` 에 두고 보고에 적는다. 공개 이미지 호스트로 가지 않는다.
- 마지막에 `dev-servers.sh stop head`, `dev-servers.sh stop base`, `base-worktree.sh --remove`.

## 흐름이 사는 곳

- web spec 은 진짜 e2e 테스트다. `apps/<app>/e2e/<claim-slug>.spec.ts`, 루트 `playwright.config.ts` 가 돌린다 (`check-env.sh --install-config` 가 `templates/` 에서 설치). 같은 PR 에 실린다. 주장을 증명한 흐름이 그 회귀 테스트가 된다.
- 앱 흐름은 `.argent/flows/verify/`.
- storage state, 결과, 영상, trace 는 `.e2e/` (gitignored). 커밋에 들어가지 않는다.

## 경계

이 스킬이 소유하는 것은 주장 분류, base/head 비교, 판정, PR 기록이다. 위임하는 것.

- 브라우저 탐색 → Playwright MCP. Claude Code 의 Chrome MCP 는 보는 용도의 폴백.
- 재생과 assertion → `@playwright/test`.
- 기기 흐름과 녹화 → `argent`.
- 업로드 → `gh`.

에러와 해법은 `references/errors.md`.

## 끝나기 전 검사

1. 모든 주장에 판정이 있고, 충족은 경로의 증거를 가리킨다.
2. 통과 기준이 실행 **전에** 쓰여 있었다. 뒤에 썼으면 그 주장을 다시 돌린다.
3. `검증 대상` 이 PR 의 `headRefOid` 와 같다.
4. PR 본문에 마커 쌍이 하나이고, 마커 밖은 그대로다.
5. 스크린샷·영상·spec·PR 텍스트에 토큰, 쿠키, 인증 쿼리, storage-state 경로가 없다.
6. dev 서버 두 세트와 base worktree 를 내렸다.

## 금지 패턴

- 타입 체크·lint·빌드 성공을 런타임 동작의 증거로
- 경로의 증거 없이 충족
- 지어낸 이유의 미검증. 환경 사유는 `check-env.sh` 의 `MISS` / `INFO` 줄이나 실패한 실행의 에러를 그대로 인용한다. «설치 여부 미확정» 은 검사를 돌릴 이유지 판정이 아니다 (PR #375: 부팅된 시뮬레이터를 두고 전부 미검증)
- «before» 짐작. before 는 `base-worktree.sh` 가 만든 base 의 worktree 다. 메인 체크아웃에서 `git stash` · `checkout` · `switch` 금지
- 모델이 직접 조작한 녹화(Chrome MCP GIF, 손으로 찍은 스크린샷)를 증거로. 모델 조작은 탐색용이고, 증거는 작성한 흐름의 재생에서 나온다
- 코드가 통과하도록 주장을 약화·삭제·재해석. 모호함은 사용자에게, 틀린 조건은 티켓에서 고치고 `implement` 로
- 통과시키려고 assertion 을 느슨하게
- `gh --attach` 외의 곳에 미디어 업로드
- 주장 하나에 긴 흐름 여러 개. 흐름은 주장당 하나, 짧게, 주장 이름으로
