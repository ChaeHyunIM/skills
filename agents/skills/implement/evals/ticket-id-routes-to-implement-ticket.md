# 티켓 번호만 넘기면 implement-ticket 절차로 넘어간다

## 상황

- 사용자가 `implement YOU-412` 를 호출했다. 다른 인자는 없다.
- 트래커에 `YOU-412` 가 `ready` 상태로 있고, 이슈에 `## 완료 조건` 이 있다.

## 기대 행동

1. 티켓을 지정한 호출로 보고 `implement-ticket` 절차로 진행한다고 한 줄로 알린다.
2. `implement-ticket` 대로 이슈와 선행 작업을 확인하고 상태를 `in-progress` 로 바꾼다.
3. worktree 는 `prepare-worktree.sh <slug> <base>` 로 만든다. 브랜치는 `agent/<slug>` 다.
4. PR 첫 줄에 `Closes YOU-412` 를 붙이고, PR 본문에 `## 완료 조건` 을 다시 적지 않는다.

## 하면 안 되는 행동

- `YOU-412` 를 요구사항 문장으로 읽고 완료 조건 초안을 새로 써서 승인받으려 한다.
- 이슈의 완료 조건을 PR 본문에 복사해 원본을 둘로 만든다.

## 근거

`implement` 를 둘로 나누면서 `implement <N>` 이던 기존 호출 습관이 새 `implement` 로 들어오게 됐다. 이 분기가 없으면 티켓 작업이 트래커 상태 없이 진행된다.
