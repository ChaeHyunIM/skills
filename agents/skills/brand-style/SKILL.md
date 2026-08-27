---
name: brand-style
description: 사용자의 브랜드 시각 규칙 — 게시용 단일 HTML 페이지(Claude Code 의 Artifact, Codex 의 site)를 만들 때 쓰는 타이포그래피와 아이콘 규칙. 페이지·문서·슬라이드·포스터 등 사람이 보게 될 HTML 산출물을 새로 쓰거나 고칠 때 먼저 불러온다. Artifact / site / 아티팩트 / 사이트 / 랜딩 / 리포트 페이지 / 대시보드 / 목업 요청에 걸린다.
---

# brand-style

게시용 HTML 산출물의 시각 기본값. 런타임마다 이 기능을 부르는 이름이 다르다 — **Claude Code 는 Artifact, Codex 는 site** — 규칙은 같다.

사용자가 이 페이지의 룩을 따로 지정했다면 그쪽이 이긴다. 지정이 없을 때의 기본값이 아래다.

## Typography

- 헤더(`h1`/`h2`/`h3`) — **Gowun Dodum**
- 본문 — **IBM Plex Sans KR**
- 둘 다 로드 실패 시 **Noto Sans KR** 로 폴백

폰트 스택에 폴백을 실제로 적어 둘 것. 웹폰트 호스트를 쓸 수 있는 환경인지는 런타임마다 다르므로, 막히면 시스템 한글 폰트로 내려가도 레이아웃이 깨지지 않게 한다.

## Icon

아이콘이 필요하면 **Phosphor**(https://phosphoricons.com/)를 쓴다.

아이콘 폰트나 CDN 스크립트를 붙이지 않는다. 공식 패키지 `@phosphor-icons/core` 의 SVG 원본(`assets/<weight>/<name>.svg`)을 받아 HTML 안에 `<svg>` 로 인라인한다 — 게시된 페이지는 외부 호스트 요청이 CSP 로 막히기 때문이다.

```bash
curl -s https://unpkg.com/@phosphor-icons/core/assets/regular/map-pin.svg
```

인라인할 때 `width`/`height` 는 지우고 `viewBox` 만 남긴 뒤 `fill="currentColor"` 로 바꿔 글자색을 따라가게 한다.

**이모지를 아이콘 대용으로 쓰지 않는다.** favicon 은 예외다.
