---
name: review-round
description: "`/review-round <N>`. implement PR 에 Claude·Codex 이중 리뷰 라운드 한 번을 돌리고 결과를 PR 코멘트 하나로 남긴다. 유료 엔진을 띄우므로 사람이 부른다."
disable-model-invocation: true
---

# review-round

`implement` 가 연 PR 에 **리뷰 라운드 하나** 를 끝까지 돈다. 사람 입력 한 번, 같은 고정 head 에 대한 독립 리뷰 엔진 둘, 중간 핸드오프 없음. 명시적 `$review-round` 호출이 nested Claude 리뷰 한 번과 nested Codex 리뷰 한 번을 허가한다. 둘은 읽기 전용으로 돌고, finding 을 적용하고 GitHub 에 쓰는 것은 이 바깥 루프만이다.

시작할 때 읽는다.

- `~/.agents/skills/agent-loop/CONTRACT.md`. 도구 원칙, 상태, 커밋 경로, 유료 엔진 규칙.
- `~/.agents/skills/agent-loop/references/acceptance-criteria.md`. 완료 조건 대조와 기록의 소유권.

| | |
|---|---|
| 상태 | `awaiting-review` → `in-review` → `awaiting-review` 또는 `blocked` |
| 산출물 | 루프가 쓴 PR 요약 코멘트 하나. 엔진의 원본 산출물은 scratchpad 에 남는다. PR 본문의 `## 완료 조건 검증` 은 `verify` 의 기록이라 여기서 고치지 않는다 |
| Never | 머지 가능성 판단 · `ultra` 실행 · 사람이 부른 라운드 밖에서 엔진 기동 |

## 인자

- 첫 인자는 이슈 번호 `<N>`. 필수.
- 나머지 인자는 Claude 의 `/code-review` 에 순서대로 그대로 넘긴다. 정규화된 effort 는 Codex 에도 넘긴다. Claude 전용 인자는 Codex 에 넘기지 않는다.
- effort 기본은 `medium`. 첫 전달 인자가 `low` / `medium` / `high` / `xhigh` / `max` 가 아니면 `medium` 을 앞에 붙인다. 빼면 `/code-review` 가 `/effort` 설정을 물려받고, 모르는 첫 토큰을 **리뷰 대상 경로** 로 읽는다.
- **`ultra` 는 실행을 멈춘다.** `ultra` 는 Claude Code 의 클라우드 리뷰 모드다. 이 Codex 진입점은 띄울 수도 결과를 받을 수도 없다. 어느 엔진도 띄우지 않고, Claude Code 세션에서 `/code-review ultra` 를 돌리라고 말한다. 그 흐름은 Claude 진입점이 소유한다.
- **`--fix` 와 `--comment` 는 거부한다.** 전달 문자열에서 빼고 그렇다고 말하고 계속 간다. 이 스킬이 이미 소유한 일과 겹치거나 어긋난다. `--fix` 는 [5] 가 반영·기각·보류를 정하기 전에 [3] 안에서 finding 을 적용해 버린다. `--comment` 는 Claude 가 쓴 인라인 PR 코멘트를 올리는데 이 스킬은 [7] 의 요약 코멘트 하나만 쓴다.
- Codex 는 항상 `gpt-5.6-sol` 에 정규화된 effort 로 `$review-agent` 를 부른다. 헬퍼는 ChatGPT 로그인을 요구하고 `CODEX_API_KEY` 나 `OPENAI_API_KEY` 가 있으면 거부한다. 리뷰를 API 과금이 아니라 개인 Codex 구독으로 묶기 위해서다. 저장소별 영구 검사 항목은 `AGENTS.md` 에 둔다.

## 작업 순서

```
Round progress:
- [ ] 1  PR·worktree 잡기, 이슈 완료 조건과 PR 증거 읽기, ROUND_BASE · BASE · REPO 고정
- [ ] 2  상태 잡기, 라운드 번호 정하기
- [ ] 3  ROUND_BASE 에 Claude·Codex 를 한 exec 세션으로 띄우고 끝까지 폴링
- [ ] 4  두 finding 목록 추출·점검·중복 제거
- [ ] 4a 완료 조건 하나하나를 구현·증거와 대조, 누락 포함
- [ ] 5  finding 처분 → comment-cleaner → 타입 체크 → commit → push
- [ ] 6  base sync, 타입 체크. 검증 기록이 head 를 여전히 설명하는지 기록
- [ ] 7  라운드 범위 계산 → PR 코멘트
- [ ] 8  상태 내리고 멈춤
```

### 1. PR, worktree, 라운드 범위 고정

- 트래커에서 티켓 N 에 묶인 열린 PR 을 찾는다. 검색 인덱스 지연과 본문 전문 검색의 오탐을 감안해 PR 본문의 바인딩 줄로 확인한다. 열린 PR 이 정말 없으면 멈추고 그렇다고 말한다.

```bash
git -C <worktree> pull
ROUND_BASE=$(git -C <worktree> rev-parse HEAD)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BASE=$(gh pr view <PR> --json baseRefName -q .baseRefName)
COMPARISON_REF="origin/$BASE"
```

- `ROUND_BASE` 는 **pull 직후, 리뷰가 돌기 전에** 고정한다. 여기서부터 커밋되는 것이 이 라운드의 작업이고 그 아래는 아니다. [7] 의 compare 링크가 이 라운드만 가리키게 하는 유일한 장치다.
- 엔진이 돌기 전에 이슈의 `## 완료 조건` 과 PR 본문을 읽는다. 그 조건 스냅샷을 바깥 루프의 대조용으로 들고 간다. 엔진의 결함 목록은 조건 커버리지를 말해 주지 않는다.

### 2. 상태 잡기, 라운드 번호

- 루프 상태를 `in-review` 로.
- 라운드 번호 `<K>` 는 `gh pr view <PR> --json comments` 의 "리뷰 라운드 K" 중 가장 큰 K 에 1 을 더한 것. 기본 1.

### 3. 두 리뷰 엔진을 `ROUND_BASE` 에 띄운다

어느 엔진도 리뷰 중에 브랜치를 쓰지 않는다. 둘 다 `ROUND_BASE` 고정 뒤, [5] 가 파일을 바꾸기 전에 시작한다.

**3a. Codex 인증 preflight.** 둘 중 어느 것도 띄우기 전에 돌린다. 고정 모델/effort 쌍, ChatGPT 로그인, API 키 환경 변수 부재, 출력 스키마를 확인한다.

```bash
CODEX_MODEL=gpt-5.6-sol
bash ~/.agents/skills/agent-loop/review-round/scripts/codex-review.sh \
  preflight "$CODEX_MODEL" <normalized-effort>
```

실패하면 어느 엔진도 띄우지 않는다. 상태를 `in-review` 에 두고 에러를 보고하고 멈춘다.

**3b. scratchpad 하나를 만들고 공동 러너를 띄운다.** `/code-review` 는 `disable-model-invocation` 이라 `Skill` 도구로는 못 부르지만, 그 플래그는 *모델이 자기를 부르는 것* 만 막는다. `claude -p` 는 사람이 친 것과 같은 슬래시 확장 경로를 타서 진짜로 리뷰한다 (evidence.md).

러너가 `claude -p` 와 `codex exec` 를 자식 프로세스 둘로 띄우고, 각각의 JSONL · 결과 · stderr · `.done` 을 쓰고, 둘을 기다린다. `$review-agent` 가 nested Codex 의 읽기 전용 결함 우선 계약을 준다.

```bash
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/review-round-<N>-r<K>.XXXXXX")
bash ~/.agents/skills/agent-loop/review-round/scripts/run-reviewers.sh \
  <worktree> <N> <K> "$COMPARISON_REF" "$ROUND_BASE" \
  "$CODEX_MODEL" <normalized-effort> "$SCRATCH" <normalized-Claude-args...> <PR>
```

- `<normalized-Claude-args...>` 는 「인자」 에서 effort 를 기본값 처리한 배열이다. 호출자의 원문 꼬리가 아니다.
- **러너는 상승된 권한으로, 샌드박스 밖에서 돌린다.** nested `claude` 와 `codex exec` 는 모델에 닿을 네트워크와 `$HOME` 아래 CLI 상태 쓰기가 필요한데 기본 workspace-write 샌드박스가 둘 다 막는다. 헬퍼의 `--sandbox read-only` 는 nested 리뷰어 자신의 셸 명령만 제한하고 리뷰어 프로세스의 네트워크를 열지 않는다.
- 러너는 리뷰가 `REVIEW_MAX_SECONDS` (기본 3600초) 를 넘기면 둘을 종료하고 `124` 로 끝난다. 다른 리뷰어 실패처럼 다룬다. 보고하고 상태를 `in-review` 에 둔다.
- `exec_command` 로 짧은 초기 yield 와 함께 돌린다. `session_id` 가 돌아오면 그 세션을 유지하고 빈 입력으로 `write_stdin` 을 `yield_time_ms: 30000` 으로 끝날 때까지 반복한다. 폴링 사이에 짧은 진행 코멘트를 낸다. **첫 세션이 있는 동안 러너를 두 번 띄우지 않는다.** 러너는 30초마다 공동 digest 를 찍는다. 세션이 끝나면 같은 턴에서 [4] 로.

- `<PR>` 은 [1] 의 PR 번호이고 **항상 마지막에 붙여 Claude 의 리뷰 대상이 되게 한다.** 대상 없이 두면 `/code-review` 가 자기 비교 base 를 고르는데 실제로는 `main` 이라, PR 의 base 가 `main` 보다 앞서 있으면 base 자체의 커밋까지 훑는다 (YOU-49 라운드 1: finding 11개 중 7개가 PR 밖 dev 전용 백엔드 코드). PR 대상은 diff 를 PR 이 선언한 base 에 묶는다. head 는 이미 push 됐고 [1] 이 pull 했으니 PR diff 는 고정된 worktree head 와 같다.
- `--output-format stream-json --verbose` 는 필수다. 기본 text 모드는 종료 전까지 아무것도 쓰지 않고, `CLAUDE_CODE_REPORT_FINDINGS=1` 은 이 형식에서만 효력이 있다 (evidence.md).
- 둘 다 같은 worktree, 같은 고정 head 에서 돈다. Codex 헬퍼는 리뷰 전후로 `HEAD` 를 확인하고, 움직였으면 실패한다.

### 4. finding 추출, 점검, 결합

```bash
CLAUDE_FINDINGS=$(bash ~/.agents/skills/agent-loop/review-round/scripts/extract-findings.sh \
  <scratchpad>/review-<N>-r<K>.jsonl)
CODEX_FINDINGS=$(bash ~/.agents/skills/agent-loop/review-round/scripts/codex-review.sh \
  extract <scratchpad>/codex-review-<N>-r<K>.json \
  "$ROUND_BASE" "$CODEX_MODEL" <normalized-effort>)
```

- Claude 추출기 exit `0` = 구조화 · `2` = 산문 폴백 (라운드를 degraded 로 보고) · `3` = 쓸 것 없음. Codex 추출기는 산문 폴백이 없다. `0` = 스키마 유효 · `3` = 무효.
- 구조화 형태: `{level, findings:[{file, line, summary, short_summary, failure_scenario, category, verdict?}]}`.
- Claude finding 에 `source: "Claude"` 를 붙인다. Codex finding 은 이미 `source: "Codex"` 를 가진다.
- 두 엔진이 같은 위치의 같은 결함을 말할 때만 합친다. `source: "Claude+Codex"` 하나로. 주제가 비슷해도 실패 시나리오가 다르면 따로 둔다.
- **결합 배열의 순서가 finding 번호다.** `#1` 이 첫 결합 finding.
- `short_summary` (60자 이하) 가 표 셀, `file:line` 이 위치, `failure_scenario` 가 반영/기각 판단 재료.
- Claude 의 `verdict` (CONFIRMED/PLAUSIBLE) 는 verify 패스가 돈 `high` 이상에만 있다. 기본 `medium` 에는 없으니 처분을 거기 걸지 않는다. Codex 는 대신 `overall_assessment`, `test_gaps`, `residual_risks` 를 준다. 패스 요약과 검증 맥락에 쓰고 추가 finding 으로 삼지 않는다.
- **exit 3, 어느 쪽이든 0 아닌 `.done`, Codex 추출 실패, 움직인 worktree head** → finding 을 짐작하지 않고 한 엔진만으로 처분하지 않는다. 실패를 보고하고 상태를 `in-review` 에 두고 무엇을 재시도할지 말한다. 각 엔진의 `.err` 에 stderr 가 있다.

### 4a. 완료 조건 대조

- 바깥 루프가 원 조건 하나하나를 구현과 PR 증거와 대조한다. 공유 reference 기준. 두 엔진이 finding 0 을 내도 누락을 본다.
- 빠진 구체 동작은 `source: 완료 조건` 으로 결합 목록에 넣는다. 없는 코드에 file/line 을 지어내지 않는다.
- 검증만 빠진 빈틈은 라운드 코멘트의 검증 줄로 간다. PR 본문에는 절대 아니다. 그 기록은 `verify` 의 것이다. 엔진 finding 으로 꾸미지도 않는다.
- 미결 정책은 기존 보류 경로. 이슈 체크박스는 여기서 바꾸지 않는다.

### 5. finding 처분

finding 마다 처분 정확히 하나. 여기서 정하고 [7] 에서 보고한다.

- **반영**. 명백한 것. 버그, 타입 에러, 프로젝트 규칙 위반. 고친다.
- **기각**. finding 이 틀렸다. 기각 전에 확인하고 반증을 `path:line` 으로 남긴다. 반증 없는 기각은 주장일 뿐이다.
- **보류**. 판단이 필요하거나 사람이 소유하는 변경. 마이그레이션, 아키텍처, 비용, **제품 정책**. **코드를 건드리지 않고**, 선택지를 *지금* 정리한다. [7] 과 [8] 이 둘 다 필요로 한다. 보류마다 **개발** (개발자가 정한다) 또는 **팀** (기획·운영도 결정에 참여한다) 태그. [8] 은 팀 것만 비개발자용으로 번역한다.
- 정책은 수정으로 위장한다. finding 을 해소하는 것이 «코드가 틀린 걸 바로잡는 것» 이 아니라 «제품이 뭘 하는지 정하는 것» 이면 보류다. 답이 뻔해 보여도, 티켓이 그 얘기를 안 했어도. 침묵은 팀이 채우는 빈틈이지 이 라운드가 채우는 것이 아니다.
- 처분 전에 결합 목록을 `<scratchpad>/review-<N>-r<K>.findings.json` 에 쓰고 처분을 거기 기록해 간다. 엔진 산출물은 증거이고 이 파일이 라운드의 유일한 작업 사본이자 [7] 의 입력이다.
- 바뀐 것이 있으면 CONTRACT 의 커밋 경로. `$comment-cleaner` → `pnpm check-types:<app>` → `$commit` → `git push`.

### 6. base 와 sync, 그 위에서 타입 체크

브랜치는 옛 base 에서 잘렸다. 여기서 초록 타입 체크는 *옛 base 더하기 이 변경* 이 컴파일된다는 뜻만이다. GitHub 은 **텍스트** 충돌만 보고하니, base 의 시그니처 변경과 여기의 새 호출부는 둘 다 "mergeable" 이고 머지된 뒤에야 깨진다.

```bash
git -C <worktree> fetch -p origin
BASE=$(gh pr view <PR> --json baseRefName -q .baseRefName)   # 새로 읽는다. 캐시 금지
git -C <worktree> merge origin/$BASE
pnpm check-types:<app>
```

멈추는 조건.

- **충돌** → 아무것도 해소하지 않는다. 틀린 해소는 하류 누구에게도 안 보인다. `git merge --abort`, `blocked` 로 착지, 무엇이 충돌하는지 말한다. 해소는 `$land` 의 일이다. 거기서 양쪽 의도를 읽은 뒤 hunk 를 건드린다.
- **타입 체크 깨짐** → 고치고 커밋 경로 다시.
- **양쪽에 마이그레이션** → 번호는 텍스트로 충돌하지 않지만 적용 순서가 충돌한다. 도입한 커밋이 아니라 충돌하는 **파일** 을 이름 짓는다.

[7] 전에 `bash ~/.agents/skills/verify/scripts/verified-head.sh <PR> <worktree>` 를 돌려 그 줄을 코멘트용으로 들고 간다. `## 완료 조건 검증` 을 고치지 않는다. 커밋을 push 한 라운드는 정의상 기록을 `stale` 로 만들었고, `land` 가 머지 전에 물을 것이다. [7] 과 [8] 에서 그렇게 말하고 손으로 결과를 다시 쓰지 않는다. 라운드마다 여기서 재검증하는 것이 검증이 건너뛰어지던 방식이다.

### 7. 라운드 코멘트. 이 라운드의 유일한 새 PR 코멘트

라운드의 마지막 push 뒤 범위를 계산한다.

```bash
git -C <worktree> log --oneline $ROUND_BASE..HEAD          # 비면 반영 0건
git -C <worktree> diff --stat $ROUND_BASE..HEAD | tail -1  # 파일 수
ROUND_HEAD=$(git -C <worktree> rev-parse HEAD)
```

- 반영 헤더는 compare 하나를 링크한다. `https://github.com/$REPO/compare/<ROUND_BASE 앞 7자>..<ROUND_HEAD 앞 7자>`.
- [6] 의 base sync 도 이 범위에 들어간다. 이 라운드에 일어났으니 맞다. `ROUND_BASE` *아래* 것은 절대 들어가면 안 된다.
- **`~/.agents/skills/agent-loop/review-round/references/round-comment.md` 를 읽고 형식과 규칙을 정확히 따른다.**
- 본문을 파일에 쓰고 `gh pr comment <PR> --body-file <scratchpad>/round-<N>-r<K>.md`. 표·백틱·`|` 는 `--body` 인용에서 안전하지 않다.

### 8. 상태 내리고 멈춤

- **보류가 하나라도, 또는 [6] 의 base 충돌** → `blocked`. 티켓 코멘트는 **포인터만** (`리뷰 라운드 <K> 보류 <c>건 — <PR 코멘트 URL>`). 선택지를 거기 다시 적지 않는다. 두 사본은 어긋난다.
- **둘 다 아니면** → `awaiting-review`.

**팀이 정해야 하는 보류는 따로 번역해 올린다.** 라운드 코멘트는 개발자끼리 읽고 그냥 게시된다. 그런데 보류 중에는 개발자의 결정이 아닌 것이 있다. 제품 정책, 운영 규칙, 비용, 사용자에게 보이는 동작. 기획·디자인·운영은 PR 을 열지 않는다.

- 그런 보류가 하나라도 있으면 **그 항목만** 비개발자가 읽을 수 있는 두 번째 티켓 코멘트로 다시 쓴다. **`~/.agents/skills/agent-loop/review-round/references/team-comment.md` 를 읽고 정확히 따른다.**
- 그 문서의 다른 모든 것을 이기는 규칙. 초안은 채팅에 전문으로 내고, **사람이 승인한 뒤에만** 게시한다. 승인 없이 티켓에 올리지 않는다. 순수 개발 보류는 PR 코멘트에 남고 번역하지 않는다.

채팅 보고는 **포인터이지 두 번째 글이 아니다.** 예외는 **보류** 하나. 보류는 이 세션에 앉은 사람에게 던지는 질문이라, 링크만 주면 무엇을 묻는지 보려고 PR 을 열어야 한다.

- `<c> > 0` 이면 방금 게시한 코멘트 파일에서 보류 절을 **그대로 복사해** 찍는다. 요약도 재정렬도 하지 않는다. 채팅과 코멘트가 두 갈래 답이 되면 안 된다.

  ```bash
  awk '/^### 보류/{f=1} f && /^### / && !/^### 보류/{exit} f' <scratchpad>/round-<N>-r<K>.md
  ```

- 보류 0건이면 아무것도 덧붙이지 않는다. 코멘트의 `보류 없음` 한 줄로 충분하다.
- 차단형 사용자 입력 대화를 열지 않는다. 코멘트에 없는 분석·추가 선택지·추천을 덧붙이지 않는다. 결정은 다음 `$implement <N>` 지시로 돌아온다.

이렇게 말하고 멈춘다.

- 라운드 결과 → `<PR 코멘트 URL>` (지적 n · 반영 a · 기각 b · 보류 c)
- 검증 기록 → `verified-head.sh` 의 한 줄 그대로. `current` 가 아니면 `$land` 가 병합 전에 한 번 묻는다. 증거를 새로 만들려면 `$verify <N>`
- 보류 <c>건 (있을 때만) → 위 awk 로 뽑은 보류 절 그대로
- 더 리뷰 → `$review-round <N>`
- 더 수정 → `$implement <N>` 에 지시를 붙여서
- 만족하면 → `$land <N>`. 인자가 머지 서명이고 `$land` 가 순서대로 머지하며 base 를 다시 sync 하고 충돌을 해소한다. 여러 라운드 분량을 모아 `$land <N> <M> ...` 한 번으로. 한 번에 드레인하는 것이 큐의 base 가 하나씩 낡는 걸 막는다.

## 런타임 경계

이것은 Codex 바깥 진입점이다. 상태 전이, finding 처분, 브랜치 쓰기, 단 하나의 새 PR 코멘트를 소유한다. 자식 `codex exec` 는 `$review-agent` 를 부르고 읽기 전용이며 `$review-round` 를 재귀 호출하지 않는다. Claude 진입점 `~/.claude/skills/review-round/SKILL.md` 가 사람이 Claude 에서 시작할 때 같은 워크플로를 소유한다. 두 진입점은 `~/.agents/skills/agent-loop/review-round/` 의 스크립트와 reference 를 공유한다.

## 끝나기 전 검사

1. 두 엔진이 같은 `ROUND_BASE` 에서 돌았고, 리뷰 중 head 가 움직이지 않았다.
2. 결합 finding 마다 처분이 정확히 하나이고, 기각에는 `path:line` 반증이 있다.
3. 라운드 코멘트가 이 라운드의 유일한 새 PR 코멘트이고 compare 링크가 `ROUND_BASE..ROUND_HEAD` 다.
4. `## 완료 조건 검증` 은 건드리지 않았다.
5. 루프 상태가 `blocked` 또는 `awaiting-review` 하나다. 보류나 충돌이 있으면 `blocked`.
6. 팀 보류 코멘트는 승인 뒤에만 올라갔다. 개발 보류는 PR 코멘트에만 있다.

## 금지 패턴

- 사람이 부르지 않은 라운드에서 엔진 기동, 자동 재시도
- 첫 실행이 살아 있는데 두 번째 러너 기동
- 한 엔진 결과만으로 처분
- `ROUND_BASE` 아래를 포함한 compare 링크
- 라운드 코멘트의 bare `#1` (GitHub 이 PR 링크로 바꾼다. 백틱 안에)
- 라운드 코멘트의 커밋 SHA 인용 (rebase-merge 로 며칠 안에 사라진다)
- 정책 finding 을 «뻔한 답» 으로 반영
- 승인 없이 올린 팀 보류 코멘트
- 보류 절을 채팅에서 재요약
- 여기서 충돌 해소, 여기서 재검증
