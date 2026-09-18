---
name: code-quality
description: 변경 코드에 맞는 전문 스킬을 골라 적용한다. implement·verify의 코드 품질 검증에 사용한다.
---

# code-quality

프로젝트의 의존성·설정과 변경 코드를 확인하고, 아래 조건에 해당하는 스킬을 모두 읽어 검토 기준으로 적용한다. 스킬의 참고 문서는 변경에 필요한 부분만 읽는다.

## 공통

| 검토할 코드 | 적용할 스킬 |
|---|---|
| PostgreSQL 스키마·쿼리·트랜잭션 | [postgres](../postgres/SKILL.md) |
| React 19 컴포넌트·훅 | [react19](../react19/SKILL.md) |
| useEffect가 포함된 컴포넌트·훅, 파생 상태·상태 동기화 | [react-useeffect](../react-useeffect/SKILL.md) |
| TanStack Query의 조회·캐시·mutation·낙관적 갱신 | [tanstack-query-best-practices](../tanstack-query-best-practices/SKILL.md) |
| HTML·CSS·브라우저 API | [modern-web-guidance](../modern-web-guidance/SKILL.md) |
| 웹 UI의 폼·키보드 조작·접근성·인터랙션 | [web-design-guidelines](../web-design-guidelines/SKILL.md) |
| Turborepo 태스크·캐시·환경변수·패키지 경계 | [turborepo](../turborepo/SKILL.md) |

useEffect가 있으면 react-useeffect를 반드시 함께 적용한다.
React Compiler 관련 기준은 프로젝트에서 Compiler를 사용하는지 확인하고 적용한다.

## 기술별 추가 적용

현재 세션에서 사용 가능한 스킬의 이름과 description을 살펴, 프로젝트의 기술스택·설정과 변경 내용에 해당하는 전문 스킬을 추가로 선택한다. 라이브러리뿐 아니라 코드에 사용된 패턴도 선택 근거로 삼는다.

선택한 스킬을 공통 스킬과 함께 읽고 검토 기준으로 적용한다. 스킬이 요구하는 선행 스킬도 읽으며, 참고 문서는 변경에 필요한 부분만 읽는다. 설치·배포 등 별도 작업 절차는 시작하지 않는다.
