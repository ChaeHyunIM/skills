---
name: implement
description: "`/implement <N>`. 트래커 티켓 하나를 격리된 worktree 에서 구현해 리뷰 준비된 PR 을 열고 멈춘다. 검증·리뷰·머지는 하지 않는다."
disable-model-invocation: true
---

# implement

티켓 하나를 격리된 worktree 에서 구현하고, 리뷰 준비된 PR 을 열고, `awaiting-review` 에서 멈춘다. 검증(`verify <N>`)과 리뷰(`review-round <N>`)는 사람이 그 PR 에 대해 따로 부른다. 이 스킬은 둘 다 하지 않는다.

시작할 때 읽는다.

- `~/.agents/skills/agent-loop/CONTRACT.md`. 도구 원칙, 상태, 엣지, worktree, 커밋 경로.
- `~/.agents/skills/agent-loop/references/acceptance-criteria.md` 의 「Write the outcome, not the patch」 와 「Verify and keep one current PR record」.

| | |
|---|---|
| 상태 | `ready` → `in-progress` → `awaiting-review`. 막히면 `blocked` |
| 산출물 | non-draft PR 하나. `## 완료 조건 검증` 은 `verify` 가 채울 자리만 있다 |
| Never | 완료 조건 검증 · 리뷰 · 머지 · base 브랜치에 push |

## 부르는 방식

- `implement <N>`: 바로 「작업 순서」.
- `implement` (인자 없음): 「후보 고르기」 를 하고 사용자에게 묻고 멈춘다. 확인 전에는 아무것도 바꾸지 않는다. 라벨도, worktree 도.
- `--base <branch>` 로 base 를 지정할 수 있다. 그 외 인자는 이번 턴의 추가 지시다.

## 후보 고르기 (인자 없음)

- 트래커에서 `ready` 티켓을 모은다. 되돌아온 `blocked`, 진행 중인 `in-progress` · `awaiting-review` 도 같이 보여 준다.
- 후보마다 블로커의 실제 상태를 [2] 방식으로 본다. 보여 주는 것은 번호와 제목, 목표 요약, `apps/` 아래 어느 앱인지, 블로커 상태, 구현 계획 한 줄.
- 블로커가 열린 후보는 «아직 못 시작» 으로 표시하고 추천에서 뺀다. 목록에서 지우지는 않는다. 블로커가 land 되면 몇 분 뒤 시작할 수 있다.
- 의존이나 우선순위가 보이면 추천 하나를 표시한다.
- 후보가 없으면 그렇다고 보고하고 멈춘다.
- "어느 이슈를, 어느 방향으로?" 를 묻고 멈춘다. 확인되면 그 `<N>` 으로 「작업 순서」.

## 작업 순서

진행 체크리스트를 응답에 복사해 두고 지우며 간다.

```
Implementation progress:
- [ ] 1  티켓과 완료 조건 읽기, fresh / rework 판별
- [ ] 2  블로커 게이트 (fresh 만)
- [ ] 3  상태 잡기
- [ ] 4  base 정하기 (fresh 만)
- [ ] 5  worktree 준비
- [ ] 6  구현 (디자인이 있으면 Figma 노드 먼저)
- [ ] 7  타입 체크, 이 변경이 만들거나 건드린 테스트
- [ ] 8  comment-cleaner → commit → base 양방향 확인 → push → PR
- [ ] 9  상태 내리고 verify <N> 을 가리키고 멈춤
```

### 1. 티켓 읽기, 모드 판별

- 트래커에서 티켓 N 의 본문과 `## 완료 조건` 을 읽는다.
- `git branch --list "agent/issue-<N>-*"`. 없으면 **fresh**, 있으면 **rework**. rework 는 그 브랜치에서 이어 가며 이번 턴의 지시를 적용한다.
- 완료 조건을 `verify` 가 볼 방식으로 읽는다. `~/.agents/skills/verify/references/routes.md` 의 경로 하나로 확인할 관찰 결과가 있는가. 빠졌거나 모호하면 코딩이나 `in-progress` 전에 「막혔을 때」 로 간다.
- 조건 진행은 세션에만 둔다. 이슈 체크박스에 쓰지 않는다.

### 2. 블로커 게이트 (fresh 만)

- 블로커는 네이티브 blocked-by 엣지에서 읽는다. 옛 티켓 본문의 블로커 목록은 낡은 산문이지 입력이 아니다.
- 블로커마다 **실제 상태** 를 본다. 열림/닫힘과 그 PR 의 머지 여부. 루프 상태 라벨은 사람이 손대서 뒤처지니 근거로 쓰지 않는다.
- 전부 닫혔고 PR 이 머지됐다 → 진행.
- 하나라도 열려 있다 → [3] 전에 멈춘다. 어느 블로커가 열렸는지 보고하고 아무것도 바꾸지 않는다. 블로커가 `awaiting-review` 이고 사람이 만족한다면 `land <blocker>` 뒤 `implement <N>` 재실행이 몇 분짜리 빠른 길이다.
- 블로커 작업이 없는 base 에서 타입 체크가 초록이어도 아무것도 증명하지 않는다 (evidence.md).

### 3. 상태 잡기

루프 상태를 `in-progress` 로 바꾼다. 이전 표식을 지우고 하나만 남긴다 (CONTRACT 「상태」). fresh 와 rework 가 같다.

### 4. base 정하기 (fresh 만)

- base 는 **사용자가 지금 작업 중인 브랜치** 다. 고정 이름이 아니다. 기능 라인(v2.2.0 같은)의 이슈는 서로 쌓이므로 `main` 에서 따면 앞 이슈 작업이 빠진 트리에서 시작한다.
- 순서: `--base <branch>` 인자 → 메인 체크아웃의 현재 브랜치 (`git rev-parse --abbrev-ref HEAD`).
- **로컬** 브랜치를 쓴다. `origin/<branch>` 가 아니다. 사용자의 안 푸시된 커밋이 보통 이 이슈의 전제다.
- 멈추고 묻는 경우: HEAD 가 detached 다. base 가 `agent/issue-*` 브랜치다 (에이전트 브랜치 위에 에이전트 브랜치를 쌓지 않는다. 블로커가 land 되길 기다린다).
- 경고만 하는 경우: 메인 체크아웃에 커밋 안 된 변경이 있다. worktree 는 HEAD 커밋에서 갈라지니 그 변경은 따라오지 않는다.
- 정한 base 를 [8] 까지 들고 가 PR 본문에 적는다.

### 5. worktree 준비

```bash
bash ~/.agents/skills/implement/scripts/prepare-worktree.sh <N> <slug> [<base>]   # rework 는 base 생략
```

`slug` 는 티켓 제목의 kebab-case. 스크립트가 worktree 생성, `pnpm install`, routeTree 복사를 한다.

### 6. 구현

- 이슈 본문이 목표다. 별도 목표 명령은 없다.
- 이슈에 Figma 노드 링크가 있으면 **UI 코드를 쓰기 전에** Figma MCP 로 노드를 가져온다. 배치와 스타일은 노드를 따른다. 노드의 동작이 승인된 정책이나 완료 조건과 충돌하면 조용히 한쪽을 고르지 말고 「막혔을 때」. 이슈의 "Figma가 답하지 않는 것" 은 노드가 안 보여 주는 것만 다룬다. Figma MCP 가 없거나 노드를 못 가져오면 산문으로 UI 를 지어내지 말고 「막혔을 때」.
- 프로젝트 지침(`AGENTS.md`, `CLAUDE.md`)을 따른다.
- 조건의 자연스러운 증명이 테스트인 곳(도메인·서버 동작, 순수 함수)은 테스트를 쓴다. `verify` 가 증거로 재사용한다. 스크린샷이나 기기 실행은 여기서 하지 않는다. 그건 `verify` 의 일이고, 이 세션에 남은 컨텍스트로는 못 한다.

### 7. 타입 체크와 테스트

- `pnpm check-types:<app>` 이 통과할 때까지 고친다. `tsc` 를 직접 부르지 않는다.
- 이 변경이 만들거나 건드린 테스트를 `pnpm test <path>` 로 돌리고 고친다.
- **이 단계는 완료 조건 검증이 아니다.** 여기서 검증하게 했을 때 건너뛰어졌다. 세션 예산을 티켓과 코드에 다 쓴 뒤라 가장 비싼 경로가 가장 컨텍스트 없는 지점에 앉았고, 전부 미검증에 지어낸 이유가 붙어 돌아왔다 (evidence.md, PR #375). 초록 타입 체크는 게이트지 어떤 조건의 증거도 아니다.

### 8. 커밋과 PR

- CONTRACT 의 커밋 경로. `comment-cleaner` (인자 없이) → `commit` → push.
- push 전에 base 를 **양방향** 으로 본다.
  - base 가 remote 보다 앞서 있나. `git rev-list --count origin/<base>..<base>` 가 0 이 아니면 멈추고 사용자에게 base 를 먼저 push 하라고 한다. GitHub 은 remote base 와 diff 하니 안 푸시된 base 커밋이 이 PR 에 섞인다. 남의 작업 브랜치를 대신 push 하는 건 이 스킬의 일이 아니다.
  - base 가 그새 움직였나. `git fetch origin` 뒤 `git merge-base --is-ancestor origin/<base> HEAD`. 움직였으면 push 전에 `git merge origin/<base>` 하고 [7] 을 다시 돈다.
- `git push -u origin agent/issue-<N>-<slug>`.
- PR 본문 파일을 먼저 만든다. 트래커 바인딩 줄(CONTRACT 「트래커에서의 표현」: Linear `Fixes YOU-nn`, GitHub `Closes #nn`), base, 구현 설명, 그리고 맨 끝에 검증 자리. `## 완료 조건 검증` 제목은 정확히 하나다.

  ```markdown
  ## 완료 조건 검증

  검증 미실행 — `verify <N>` 이 이 섹션을 채운다. 타입 체크·테스트 통과는 완료 조건의 근거가 아니다.
  ```

  그 아래 조건별 줄을 쓰지 않는다. 미검증 줄도. `검증 대상` sha 가 없는 섹션이 `land` 에게 «검증 안 됨» 이고, 지금은 그게 사실이다.
- `gh pr create --base <base> --title "<제목>" --body-file <file>`. non-draft. 게시된 본문을 다시 읽어 확인한다. PR 은 구현이 끝난 여기서 연다. 진행 공유용으로 먼저 열지 않는다.
- **rework**: push 하고, 기존 PR 본문을 다시 읽고, 구현 요약만 고쳐 `gh pr edit <PR> --body-file`. `## 완료 조건 검증` 은 손대지 않는다. push 가 head 를 옮겨 기록이 stale 이 됐고, `land` 가 새 `verify <N>` 을 물을 것이다. 손으로 고치면 그 사실을 숨긴다. 바인딩 줄과 사람이 쓴 내용은 보존한다. draft 로 되돌리지 않는다.

### 9. 상태 내리고 멈춤

- 루프 상태를 `awaiting-review` 로.
- PR 링크와 다음 수를 한 줄씩 말하고 **멈춘다.**
  - `verify <N>`: 이 head 의 증거로 검증 섹션을 채운다. 없으면 `land` 가 검증 없이 머지할지 묻는다.
  - `review-round <N>`: 리뷰 라운드. `verify` 가 먼저일 필요는 없다. UI 가 많은 티켓은 스크린샷이 먼저 있으면 읽기 좋다.
  - `implement <N>` 에 지시를 붙여서: 더 수정.

## 막혔을 때

- 요구가 모호하거나, 타입이 안 풀리거나, 환경 문제로 못 나갈 때다. 검증 장애물은 아니다. 그건 `verify` 가 자기 실행에서 기록한다.
- 루프 상태를 `blocked` 로 바꾸고, 티켓에 코멘트를 단다. 막힌 지점과 필요한 결정.
- 사람에게 넘기고 멈춘다.

## 끝나기 전 검사

1. 티켓의 루프 상태 표식이 `awaiting-review` 하나다.
2. PR 이 non-draft 이고, base 가 [4] 에서 정한 브랜치이고, 본문에 바인딩 줄이 있다.
3. `## 완료 조건 검증` 이 정확히 하나이고 자리표시 문구뿐이다.
4. 브랜치 head 가 origin 과 같다. 로컬에만 있는 커밋이 없다.
5. base 브랜치는 건드리지 않았다.

## 금지 패턴

- 인자 없는 모드에서 확인 전에 바꾼 라벨·worktree
- 블로커가 열린 티켓 시작
- `main` 을 base 로 가정
- 에이전트 브랜치 위에 에이전트 브랜치
- 검증 결과 줄 (충족 · 미충족 · 미검증, `검증 대상`)
- 이슈 체크박스 수정
- 진행 공유용 조기 PR, draft PR
- 사용자 대신 base push
- 검증 장애물로 `blocked`
