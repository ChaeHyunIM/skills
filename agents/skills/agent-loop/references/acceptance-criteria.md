# 완료 조건의 소유권과 경로

이슈는 관찰 가능한 조건을 소유하고, PR 본문은 그 조건의 검증 결과를 소유한다. `implement`가 필요한 검증과 기록을 끝냈으면 별도 `verify` 실행은 필요 없다.

- 조건을 쓰거나 의미를 확인할 때: [ticket-criteria.md](ticket-criteria.md).
- 실행 근거를 기록·재사용하거나 현재 head와 대조할 때: [verification.md](verification.md). `implement`와 `verify`가 같은 규칙을 쓴다.
- 머지 예외를 판단하거나 이슈 체크박스를 바꿀 때: [landing-criteria.md](landing-criteria.md).

조건의 의미 변경은 사람의 결정을 이슈에 남긴 뒤 한다. 검증 결과에 맞춰 조건을 약화하거나 삭제하지 않는다.
