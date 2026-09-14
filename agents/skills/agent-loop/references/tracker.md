# 트래커와 관계

프로젝트 선택은 `<repo>/.claude/agent-loop/config`의 `TRACKER`, `LINEAR_TEAM_KEY`를 읽는다. 없으면 현재 세션의 명시된 저장소·티켓 정보로 확정할 수 있는지 확인하고, 쓰기 대상이 여전히 모호할 때만 묻는다.

| 개념 | Linear | GitHub Issues |
|---|---|---|
| 루프 상태 | Agent 그룹의 `agent:<state>` 하나 | `ready-for-agent` · `agent-in-progress` · `agent-awaiting-review` · `agent-in-review` · `agent-blocked` 하나 |
| 팀 상태 | ready → Todo, in-progress → In Progress, awaiting-review·in-review → In Review, 머지 → Done. blocked는 유지 | 없음 |
| 블로커 | 네이티브 blocked-by | 네이티브 blocked-by |
| 부모 | parent/sub-issue | 세션 도구의 네이티브 sub-issue 기능이 있는지 확인 |
| PR 바인딩 | `Fixes YOU-nn` | `Closes #nn` |

- 커스텀 `In Review / QA` 상태를 만들지 않는다. 상태를 바꾸면 이전 표식을 제거하고 하나만 남았는지 읽는다.
- `ready`는 스펙 준비 여부다. 시작 가능 여부는 블로커의 실제 종료 상태와 연결 PR의 머지 여부에서 나온다.
- 블로커의 유일한 기록은 네이티브 엣지다. 본문에 목록을 복제하지 않는다. 의존 이유 한 문장은 허용한다.
- 부모에서 출발한 발행은 네이티브 부모 관계를 건다. 필요한 관계를 도구가 지원하지 않으면 해당 발행만 보류한다.
- 승인된 엣지 누락은 보완하고 다시 읽는다. 새 의존이나 정책을 추측해서 추가하지 않는다. 검색 인덱스가 늦으면 직접 관계를 읽어 확인한다.
- 티켓 제목·본문·코멘트는 한국어다. 비개발자도 읽는 본문은 `korean-output`을 적용하고 목표와 사용자에게 달라지는 동작을 쓴다. 기술 구현은 PR에 둔다.
- doko 티켓·PR 제목은 프로젝트의 제품 접두어와 한국어 제목 규칙을 따른다. 대응 티켓이 있으면 PR 제목은 그 제목을 쓴다.
