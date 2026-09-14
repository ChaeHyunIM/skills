# agent-loop 공유 규약

`to-tickets` · `implement` · `verify` · `review-round` · `land` 다섯 스킬이 공유하는 규칙. 각 스킬은 시작할 때 이 파일을 읽는다.

이 문서는 «끝났을 때 참이어야 하는 것» 을 적는다. 그것을 어떤 도구로 이루는지는 스킬이 그 자리에서 고른다. 규칙이 왜 있는지는 `references/evidence.md` 에 사고·측정 기록으로 있다. 규칙이 의심스러울 때만 연다. 다시 조사하지 않는다.

## 도구

- 트래커(Linear·GitHub Issues), GitHub PR, 검증 도구는 세션에 붙어 있는 plugin · MCP · CLI 로 다룬다. 도구 이름을 추측하지 않고 실제로 있는 것을 쓴다.
- 필요한 도구가 없으면 무엇을 붙여야 하는지 말하고 멈춘다. 대신할 방법을 만들지 않는다. API 를 직접 치지 않고, 라벨 대신 본문에 상태를 적지 않고, 못 한 일을 한 것으로 치지 않는다.
- 프로젝트가 어느 트래커·팀을 쓰는지는 `<repo>/.claude/agent-loop/config` 에 있다 (`TRACKER=linear`, `LINEAR_TEAM_KEY=YOU`). 없으면 사용자에게 묻는다.
- 스크립트는 모델이 손으로 하면 틀리는 일에만 남아 있다. sha 대조(`verify/scripts/verified-head.sh`), 리뷰 엔진 실행과 findings 추출(`review-round/scripts/`), 워크트리 준비(`implement/scripts/prepare-worktree.sh`). 그 외에는 도구를 직접 쓴다.

## 어휘

이름은 하나씩. 다섯 스킬은 이 어휘만 쓴다.

| 용어 | 뜻 |
|---|---|
| **tracker** | 루프의 티켓이 사는 곳. Linear 또는 GitHub Issues |
| **base** | 이 PR 이 직접 겨누는 브랜치. `gh pr view --json baseRefName`. 짐작하지 않는다 |
| **blocker** | 이 티켓에 네이티브 blocked-by 엣지로 걸린 다른 티켓 |
| **finding** | 코드 리뷰 스킬이 낸 항목 하나 |
| **round** | review-round 한 번 실행 |
| **완료 조건** | 이슈가 약속한 관찰 가능한 결과. `Acceptance criteria`·`검수 기준` 은 옛 제목으로 읽기만 한다 |

## 루프 지도

```
    to-tickets             implement <N>              verify <N>  ·  review-round <N>                 human
──────────────▶ tickets ─────────────▶ PR opened ──────────────────────────────────────────▶ land <N...> ──▶ merged
       ready            in-progress          record (no state)   in-review → awaiting-review      (args = signature)
                        → awaiting-review                                    or blocked           asks about a stale record
```

- `verify` 와 `review-round` 는 사람이 열린 PR 에 대해 부른다. 순서는 없고 횟수 제한도 없고 둘 다 필수도 아니다.
- 머지 판단은 사람이 `land` 를 부르고 티켓을 지명하는 행위 그 자체다. 미리 붙이는 «머지 가능» 표식은 없다. 같은 판단을 두 번 기록하면 표식 쪽이 썩었다.
- `land` 는 지명된 PR 이 서명자가 알 수 없던 방향으로 달라졌을 때만 한 번 더 묻는다. 거부된 티켓, 예상 충돌, 리뷰 뒤 움직인 head, head 를 설명하지 않는 검증 기록, 남은 미충족·미검증 조건.

## 상태

| 상태 | 뜻 | 쓰는 스킬 |
|---|---|---|
| `ready` | 에이전트가 집어 갈 수 있는 완성된 스펙. **블로커가 열려 있어도 `ready`** | `to-tickets` |
| `in-progress` | 구현 중 | `implement` |
| `awaiting-review` | 사람이 읽을 수 있다. `verify` 와 round 를 부를 수 있다. 검증됐다는 뜻은 아니다 | `implement` · `review-round` |
| `in-review` | round 가 돌고 있다 = 브랜치에 이미 쓰는 이가 있다 | `review-round` |
| `blocked` | 사람의 결정 없이는 못 나간다 | `implement` · `review-round` · `land` |

끝났을 때 참이어야 하는 것.

- 티켓은 언제나 정확히 하나의 루프 상태에 있다. 상태를 바꿀 때 이전 표식을 지우고 새 것을 단다. 바꾼 뒤 읽어서 하나만 남았는지 본다.
- 트래커 상태가 유일한 진실이다. PR 의 draft 여부는 상태 신호가 아니다. 그래서 PR 은 항상 non-draft 로 연다.
- `ready` 는 «스펙이 끝났다» 이고 «오늘 시작할 수 있다» 가 아니다. 시작 가능 여부는 엣지에서 나온다. 좁게 읽으면 블로커가 닫힐 때 라벨을 다시 붙여 줄 사람이 없다. 두 번 뒤집은 끝에 정한 것이다(evidence.md).

### 트래커에서의 표현

| 개념 | Linear | GitHub Issues |
|---|---|---|
| 루프 상태 | `agent:<state>` 라벨 하나 (Agent 그룹) | `ready-for-agent` · `agent-in-progress` · `agent-awaiting-review` · `agent-in-review` · `agent-blocked` 라벨 하나 |
| 팀 상태 | 라벨과 함께 움직인다. ready → Todo, in-progress → In Progress, awaiting-review·in-review → In Review, 머지 → Done. blocked 는 그대로 둔다. 커스텀 "In Review / QA" 는 쓰지 않는다 | 없음 |
| 블로킹 엣지 | blocked-by 관계 | blocked-by 관계 |
| 부모 | parent (sub-issue). `to-tickets` 가 부모 티켓에서 출발했으면 반드시 건다 | 없다. 부모가 필요하면 멈추고 말한다 |
| PR 바인딩 | PR 본문의 `Fixes YOU-nn`. 머지되면 Linear 가 Done 으로 옮긴다 | PR 본문의 `Closes #nn` |

## 블로킹 엣지

- 네이티브 엣지가 블로커의 **유일한** 기록이다. 본문에 블로커 목록을 쓰지 않는다. 두 곳에 두면 본문 쪽이 블로커가 머지된 순간 썩는다.
- 본문에는 이유 한 문장만 허용한다. "YOU-70 의 schema 컬럼을 읽으므로 그 PR 이 merge 된 뒤 시작". 이유는 블로커가 닫혀도 참이고, 목록은 거짓이 된다.
- 엣지가 빠지면 티켓이 어디서나 «시작 가능» 으로 보인다. 소리 없는 결함이다. `to-tickets` 는 게시 뒤 엣지를 읽어서 승인된 것과 대조한다. 누구든 빠진 엣지를 보면 그 자리에서 등록한다.
- 블로커가 실제로 풀렸는지는 열림/닫힘과 PR 머지 여부로 본다. 루프 상태 라벨은 사람이 손대서 뒤처진다.

## 완료 조건

- 이슈가 조건을 소유한다. PR 본문 `## 완료 조건 검증` 이 현재 검증 기록이고, **`verify` 만 쓴다.** 기록은 커밋의 속성이다. `검증 대상` sha 가 PR head 이거나 머지 커밋만 다를 때만 현재다.
- 이슈 체크박스는 **`land` 만**, 머지 직전에 바꾼다. 새 티켓은 전부 빈칸이다.
- 체크박스를 바꿀 때 참이어야 하는 것.
  - 체크박스 문자 외에는 본문이 한 글자도 달라지지 않는다.
  - 저장 직전에 본문을 다시 읽고, 그 최신 본문 위에서만 고친다. 세션 초반에 읽어 둔 사본을 쓰지 않는다.
  - 도구에 부분 편집(정확히 한 번 일치하는 문자열 치환)이 있으면 본문 전체 교체 대신 그것을 쓴다.
  - 저장 뒤 다시 읽어 바뀐 것이 체크박스만인지 본다. 다르면 멈추고 보고한다. 되돌리거나 다시 시도하지 않는다.
- 체크는 검증된 충족이다. 사람이 머지를 승인해도 남은 조건이 체크되지 않는다.
- 나머지 규칙은 `references/acceptance-criteria.md`.

## 워크트리

- 경로 `.claude/worktrees/issue-<N>-<slug>`, 브랜치 `agent/issue-<N>-<slug>`. slug 는 티켓 제목의 kebab-case.
- 새 워크트리는 `pnpm install` 과 메인 체크아웃의 `routeTree.gen.ts` 복사가 있어야 쓸 수 있다. `tsr generate` 는 `declare module` 블록을 조용히 떨어뜨리니 돌리지 않는다. `implement/scripts/prepare-worktree.sh` 가 한 번에 한다.
- PR 이 머지될 때까지 워크트리를 남긴다. 재작업과 다음 round 가 같은 것을 쓴다.

## 사람이 읽는 글

전부 한국어다. PR 제목·본문, 티켓 본문·코멘트, round 코멘트, 커밋 메시지.

- 티켓 본문과 티켓 코멘트는 기획·디자인·운영도 읽는다. `korean-output` 스킬을 적용한다. 사용자가 무엇을 할 수 있게 되는지, 왜 그런지를 말한다. 피할 수 없는 기술 용어는 한 문장으로 푼다. 파일 단위 계획, 고른 API 형태, 스키마 스케치는 PR 에 둔다.
- PR 제목·본문, round 코멘트, 커밋 메시지는 개발자끼리 읽는다. 기술 문체와 정밀함이 맞다.

커밋으로 가는 길은 하나다.

```
comment-cleaner (인자 없이)  →  pnpm check-types:<app>  →  commit 스킬  →  git push
```

- `comment-cleaner` 가 `commit` 앞이다. 주석 수정도 코드 변경이고, 다음 round 가 읽는다.
- 타입 체크는 앱 스크립트로만. `tsc`·`turbo run` 을 직접 부르지 않는다.
- 커밋은 `commit` 스킬로만. 예외는 `land` 의 충돌 해소 완료(`git commit --no-edit`) 하나다. 해소는 새로 쓴 것이 없다.

## Never

- **머지하지 않는다.** `land` 만, 그 실행에서 사람이 지명하거나 확인한 PR 만.
- **base 브랜치에 커밋·푸시하지 않는다.** 이름이 무엇이든.
- **force-push 하지 않는다.** 예외 없다. 이 루프는 푸시된 브랜치를 다시 쓰지 않는다.
- **트래커 상태를 두 곳에 쓰지 않는다.** 본문·PR·별도 파일에 상태를 복사하면 그 사본이 두 번째 쓰는 이가 된다.
- **유료 리뷰 엔진은 사람이 부른 `review-round` 만 띄운다.** 한 번 호출이 각 엔진 한 번씩, 고정된 head 에 대해서다. `implement`·`land`·백그라운드 작업은 리뷰를 시작하지 않는다. 재시도도 사람이 다시 부르는 것이다.
- **`## 완료 조건 검증` 은 `verify` 만 쓴다.** `implement` 는 자리만 남기고, round 와 `land` 는 읽기만 한다. `implement` 안에서 쓰게 했을 때 검증 없이 이유를 지어냈다(evidence.md 「Verification」).

## 파일

- `references/acceptance-criteria.md` 완료 조건을 쓰고, 검증하고, 체크하는 규칙.
- `references/evidence.md` 위 규칙들이 나온 사고와 측정. 규칙이 의심스러울 때만.
- `review-round/` round 코멘트 형식, 팀 코멘트 형식, 리뷰 엔진 스크립트.
