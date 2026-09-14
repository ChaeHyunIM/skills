---
name: html-style
description: 사람이 보게 될 단독 HTML 페이지(Claude Code 의 Artifact, Codex 의 site)의 판단 규칙과 시각 시스템. 독자의 결정을 먼저 잡는 판단 규칙, 첫 뷰포트 구성, 표·차트·색 규칙, 이름 붙인 금지 패턴, 게시 전 검사 순서, 그리고 CSS 와 폰트를 읽지 않고 이어 붙이는 조립 스크립트를 담는다. Vercel design.md 와 공개 CSS 를 프리텐다드 단일 폰트로 가져온 것이다. 사용자가 `/html-style`(Claude Code) 또는 `$html-style`(Codex) 로 직접 부를 때만 적용한다. Artifact·site 를 만든다는 이유만으로 에이전트가 알아서 불러오지 않는다.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/*)
disable-model-invocation: true
---

# html-style

게시용 HTML 페이지의 판단 기준과 시각 시스템. 런타임마다 부르는 이름이 다르다. Claude Code 는 Artifact, Codex 는 site. 규칙은 같다.

이 스킬의 규칙 대부분은 Vercel 의 `design.md` (vercel.com/design.md, 2026-09 시점) 와 그 공개 CSS 에서 가져왔다. 우리 페이지 리뷰에서 나온 규칙은 맨 아래 「우리 규칙」 절에만 쌓는다. 두 출처를 섞지 않는다.

사용자가 룩을 따로 지정하면 그쪽이 이긴다. 지정이 없을 때의 기본값이 아래다.

## 작업 순서

1. 독자의 job 을 정한다 (「독자의 job 부터」). 코드보다 먼저다.
2. 본문 HTML 만 쓴다. 골격은 「골격」 절. CSS 는 쓰지 않는다. 페이지 고유 레이아웃이 꼭 필요하면 `vbg-custom-*` 클래스에 공개 토큰만 써서 본문 파일 안 `<style>` 로 둔다.
3. 조립한다. CSS 와 폰트 파일은 스크립트가 이어 붙인다. **`assets/` 의 CSS 를 Read 하지 않는다.** 클래스 이름은 「공개 API」 와 `references/vbg-api.md` 에 있다.

   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/build.sh "<페이지 제목>" body.html out.html
   ```

4. 한 번 본다. 라이트·다크·모바일 세 장. 고치는 것도 한 번. 반복 루프를 돌리지 않는다.

   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/preview.sh out.html
   ```

5. 게시한다. 이미 있는 페이지를 고치는 것이면 같은 URL 에 새 버전으로 올리고 버전 라벨을 단다. 새 URL 을 만들지 않는다.

Codex 나 다른 런타임에서는 `${CLAUDE_SKILL_DIR}` 를 이 스킬 폴더 경로(`~/.agents/skills/html-style`)로 읽는다.

## 독자의 job 부터

문서 종류가 아니라 독자가 뭘 결정하러 오는지에서 시작한다. 코드 전에 다섯 가지를 속으로 답한다.

- 누가, 어떤 상황에서, 무엇을 결정하거나 이해하러 여는가.
- 가장 강하게 뒷받침되는 답은 무엇인가.
- 그 답을 믿게 하는 근거는 무엇인가.
- 해석을 바꾸는 한계·불확실성은 무엇인가.
- 첫 읽기를 지배하지 않되 확인용으로 남겨야 할 것은 무엇인가.

두 읽기 속도를 지원한다. **빠른 경로** 는 제목·헤딩·결정적 값·캡션·결론만으로 논증이 전달된다. **확인 경로** 는 정확한 표·가정·방법·단서·출처를 보존한다. 빠른 경로는 가장 비전문인 독자가 따라 말할 수 있는 말로 쓰고, 정확한 용어와 수치는 확인 경로에 둔다.

우선순위가 충돌하면 이 순서로 지킨다.

1. 공급된 사실·수치·단위·한정어·기간을 보존한다. 언어는 단순화하되 주장은 단순화하지 않는다.
2. 독자의 질문과 답, 근거를 즉시 명확하게.
3. 이 재료에 맞는 구성. 카테고리의 뻔한 레이아웃도, 고정 템플릿도 아니다.
4. 반응형·인터랙션·디테일.

지어내지 않는다. 의도·긴급성·확실성·마감·승인·고객 이름·가격·수치. 자료에 없으면 빼거나 "미정" 으로 표시한다. 자료가 서로 다르면 어느 쪽을 따를지 사용자에게 묻는다. 페이지 안에 "이 페이지를 어떻게 구성했는지" 같은 저작 과정 서술을 넣지 않는다.

## 첫 뷰포트와 구성

첫 뷰포트가 논증이다. 마스트헤드 뒤에 설명이 오는 게 아니다. 독자가 첫 화면만 봐도 중심 관계·결정·도구를 기억해야 한다. 재료에 따라 넷 중 하나로 연다.

| 재료 | 여는 방식 |
|---|---|
| 결정적 추천·결론 | 답과 그 근거를 나란히 (claim-led). `.vbg-opening[data-layout="split"]` 왼쪽 주장, 오른쪽 근거 |
| 비교 | 대안을 같은 시각 기준에 놓아 차이가 보이게 (comparison-led) |
| 추세·벤치마크 | 관계나 예외가 리드, 정확 기록은 아래 (evidence-led) |
| 계산기·도구 | 도구 자체가 첫 화면의 주인공 (tool-led). 앞에 정적 설명을 두지 않는다 |
| 결정이 없는 브리프 | 가장 강한 상태·함의·미해결 질문. CTA 를 지어내지 않는다 |

컴포넌트보다 geometry 를 먼저 정한다.

| 재료 | 시각 변수 |
|---|---|
| 크기·순위 | 공통 척도 위의 길이·위치 |
| 시간 변화 | 수평 순서 |
| 구성비 | 비율 |
| 임계·범위 | 경계와의 거리 |
| 절차·의존 | 연결과 순서 → `.vbg-custom-process` |
| 정성 대안 | 정렬된 행 또는 대비되는 열 → 표 |

표는 정확한 조회, 산문은 결론 하나, 차트는 시각화가 더 빠른 관계에만. 값이 있다고 바 차트를 그리지 않는다.

- 섹션마다 새 독자 질문 하나에 답한다. 헤딩은 장르명이 아니라 그 답이다. 문체는 「글」 절을 따른다.
- 주장마다 근거의 집은 하나. 같은 답을 요약·차트·카드·결론으로 반복하지 않는다.
- 페이지마다 다른 리포트에 그대로 옮길 수 없는 구성 하나를 둔다. 비교 geometry, 임계값, 시퀀스, 인터랙션.
- 눈을 가늘게 뜨고 봐도 지배적 주장이 보여야 한다. 모든 블록 무게가 같으면 코딩 전에 다시 짠다.
- 재료가 빈약하면 선택·위계·설명을 고친다. 패널·보더·아이콘·색·장식 차트로 메우지 않는다.
- 끝은 결정·다음 행동·열린 질문. 표나 단서에서 페이지가 그냥 멈추지 않는다.

## 골격

본문 파일은 이 골격으로 시작한다. 게시 런타임이 `<html>`·`<head>`·`<body>` 를 붙이므로 그 태그는 쓰지 않는다. `.vbg-report` 는 `body` 대신 `div` 에 둔다.

```html
<div class="vbg-report">
<div class="vbg-shell">
<a class="vbg-skip-link" href="#main">본문으로 건너뛰기</a>
<header class="vbg-header">
  <div class="vbg-masthead">
    <span class="vbg-identity"><span>브랜드명</span></span>
    <div class="vbg-document-meta">
      <span class="vbg-recipient">받는 사람·용도</span>
      <span class="vbg-state">상태·날짜</span>
    </div>
  </div>
</header>
<main id="main">
  <section class="vbg-opening" data-layout="split" aria-labelledby="page-title">
    <div class="vbg-opening-claim">
      <h1 id="page-title" class="vbg-title">주장을 문장으로</h1>
      <p class="vbg-lede">한 문단 오리엔테이션</p>
      <p class="vbg-context">출처·한계 한 줄</p>
    </div>
    <div class="vbg-opening-proof">…근거 (시퀀스·표·stat strip)…</div>
  </section>
  <section class="vbg-section" aria-labelledby="h-1">
    <h2 id="h-1" class="vbg-heading-24">…</h2>
    <p>…</p>
    <div class="vbg-table-wrap" data-mobile="stack"><table>…</table></div>
  </section>
</main>
<footer class="vbg-footer">
  <span class="vbg-identity"><span>브랜드명</span></span>
  <span class="vbg-sources">출처</span>
</footer>
</div>
</div>
```

헤더 오른쪽 메타는 출처 있는 항목 최대 2개. 지어내지 않는다. 마지막 섹션은 `.vbg-next-step` (label 과 문단 쌍) 으로 닫는 것이 기본이다.

## 시각 시스템

CSS 가 정하는 것과 모델이 정하는 것을 나눈다. 타이포 크기·굵기·행간·간격·색·표 정렬은 CSS 가 정한다. 모델은 클래스와 구조만 고른다. 임의 font-size, 숫자 weight, 일회성 margin 을 쓰지 않는다.

**폰트.** Pretendard Variable 단일. 제목은 굵기(500~600)와 크기 role 로, 본문은 400 으로 위계를 만든다. 폰트 파일은 `assets/font.css` 에 내장돼 있어 외부 링크가 필요 없다. 다른 폰트를 추가하지 않는다. 한국어라 페이지 전체에 `word-break: keep-all` 이 걸려 있다. 어절 중간에서 끊기지 않는다.

**색.** 흑백으로 설계한다. 색은 상태·행동·데이터에 의미가 있을 때만, 비색 단서와 함께. 유리한 값이라고 초록으로 칠하지 않는다. 라이트·다크는 CSS 가 처리하고 스위처를 두지 않는다.

**면과 경계.** 페이지는 연속된 캔버스 하나. 카드·보더·배경은 선택·경고·대비·간격으로 표현 못 하는 그룹일 때만 쓴다. 섹션·지표·비교를 카드로 감싸지 않는다. 대비 면이 필요하면 `.vbg-band[data-tone="contrast"]` 하나만.

**표.** 근거는 표다.
- `caption` 을 쓰고 섹션 소개는 표 위에 둔다. 표는 섹션 폭 전부를 쓴다.
- 숫자 열은 `th` 와 `td` 양쪽에 `class="vbg-numeric"`. 텍스트 열은 왼쪽 정렬.
- 두세 열이 동등한 비교면 `<table class="vbg-custom-peer-cols">`. 자동 열 폭은 긴 셀에 폭을 몰아주어 짧은 열이 오른쪽 끝에 붙는다.
- 넓은 표는 `data-mobile="stack"`. 열이 5개를 넘거나 헤더가 접히면 열을 줄이거나 표를 나눈다.
- `colspan` 으로 행을 합치지 않는다. 열 폭이 깨진다. 그 내용은 표 아래 문장으로.
- 반복되는 카테고리로 열을 낭비하지 않는다. 같은 단위·정밀도.

**절차·시퀀스.** `.vbg-custom-process` 안에 `.vbg-custom-step` 을 세로로 쌓는다. 각 step 은 `-label` (단계명), `-title` (한 문장), `-gate` (조건·설명) 세 문단. 첫 뷰포트의 근거 자리에 잘 맞는다.

**아이콘.** 장식으로 쓰지 않는다. 확립된 아이콘이 행동 인식을 눈에 띄게 빠르게 할 때만 (닫기, 검색, 외부 링크). 그때는 Phosphor SVG 를 인라인한다. 이모지는 favicon 외에 쓰지 않는다.

```bash
curl -s https://unpkg.com/@phosphor-icons/core/assets/regular/<name>.svg
```

`width`/`height` 를 지우고 `viewBox` 만 남긴 뒤 `fill="currentColor"`.

**브랜드 자산.** 로고·워드마크는 원본 파일을 그대로 data URI 로 심는다. 재색칠·마스크·필터를 걸지 않는다. 폭은 원본 페이지가 쓰던 값을 따른다. 다크 테마에서 대비가 약하면 사용자에게 알리고 다크용 판이 있는지 묻는다.

**링크.** 본문 링크는 `<a class="vbg-link">`. 원문 문서가 있으면 섹션 끝에 "원문: <링크>" 한 줄. 버튼 모양 CTA 를 만들지 않는다.

**모션.** 정지가 기본. 스크롤 등장, 펄스, 마키, 타이핑 커서, 호버 이동을 넣지 않는다.

**공개 API.** 자주 쓰는 클래스는 아래다. 전체 목록과 `data-*` 변형, 페이지 CSS 가 읽어도 되는 토큰은 `references/vbg-api.md`. 목록에 없는 이름을 추측하거나 동의어를 만들지 않는다. 맞는 것이 없으면 semantic HTML 에 `vbg-custom-*` 훅.

컴포넌트를 쓰기 전에 그 CSS 계약을 확인한다. 자식 수 조건이 있는 것(`.vbg-next-step` 은 라벨과 문단 정확히 둘), grid 를 소유하는 클래스 둘을 한 요소에 겹치지 않는 것(`vbg-section` 과 `vbg-next-step`), 동등한 근거 stat 에 `data-priority` 를 섞지 않는 것. 계약을 모르면 `references/vbg-api.md` 를 보고, 거기 없으면 `brand.css` 에서 그 클래스만 grep 한다. 파일 전체를 읽지 않는다.

- 골격: `vbg-report` `vbg-shell` `vbg-skip-link` `vbg-header` `vbg-masthead` `vbg-identity` `vbg-document-meta` `vbg-recipient` `vbg-state` `vbg-footer` `vbg-sources`
- 구성: `vbg-opening[data-layout=split]` `vbg-opening-claim/proof/context` `vbg-section` `vbg-split` `vbg-grid` `vbg-span-N` `vbg-stack[data-gap]` `vbg-band[data-tone=contrast]`
- 타입: `vbg-title` `vbg-heading-24/20/16` `vbg-lede` `vbg-context` `vbg-label` `vbg-caption` `vbg-link` `vbg-numeric` `vbg-formula` `vbg-list`
- 근거: `vbg-table-wrap[data-mobile=stack][data-variant=comparison]` `vbg-stat-strip` `vbg-stat` `vbg-stat-label/value/detail` `vbg-comparison[data-align=rows]` `vbg-note[data-tone]` `vbg-next-step`
- 우리 훅: `vbg-custom-process` `vbg-custom-step` `vbg-custom-step-label/title/gate` `vbg-custom-peer-cols` `vbg-custom-logo`

## 금지 패턴

이름이 있어야 피할 수 있다. 아래는 생성 디자인이 반사적으로 내놓는 것들이고, 하나라도 있으면 게시 전에 뺀다.

- 대문자·자간 넓힌 eyebrow, kicker, overline, 장식 번호 섹션 라벨
- em dash (—). 쉼표·마침표·괄호로 바꾼다
- 장식 그라디언트, 그라디언트 텍스트, glow, blob, stripe, texture, glass, 장식 그림자, 가짜 깊이
- 가운데 정렬 generic hero 뒤에 카드 그리드
- 관계 하나로 구성하면 더 명확할 것을 지표 박스 반복
- 일반 메타데이터·차트 주석·편집 라벨에 badge, pill, capsule
- 카드 안의 카드, 약한 위계를 보더로 수리, 색 세로 rail
- 모든 차트·계산기를 어두운 둥근 사각형으로 감싸기
- 임의 아이콘 타일, 과대 아이콘, 혼합 아이콘 스타일
- tiny muted 산문, 임의 font size, 불일치한 peer 값, 어긋난 baseline
- 넓은 섹션 안에 떠 있는 좁은 표, 단어가 깨지도록 압축된 넓은 표
- 장식 차트, 중복 시각화, 직접 라벨을 대체한 범례, 의미 없는 색
- 스케일을 공유하지 않거나 차이가 안 보이는 full-width 바 반복
- 무관한 독자 질문에 같은 섹션 실루엣
- 같은 말을 하는 추천·요약·근거·결론 섹션 반복
- 저작 과정 서술 (어떻게 구성했는지, 왜 이 표현을 골랐는지)
- 보이는 테마 컨트롤, 스톡 이미지, 가짜 스크린샷, 장식 브랜드 마크

특히 아래 넷은 사용자가 명시적으로 거부한 것이다. 예외 없다.

1. 배경에 번지는 radial gradient glow
2. 점 깜빡이는 "Live" 류 status pill
3. 대문자 자간 넓힌 tracked eyebrow
4. 카드 왼쪽의 색 세로선 (colored side rail)

이걸 피한다고 흑백·얇은 선·큰 여백만 남기는 것도 실패다. 절제는 정밀한 위계, 명확한 근거, 강한 정렬, 의도적 긴장이다. 앵커 하나는 남긴다.

## 게시 전 검사

`preview.sh` 결과 세 장을 이 순서로 본다. 가장 영향 큰 것 하나를 고치고 게시한다.

1. 첫 읽기. 첫 화면만 보고 중심 관계·결정이 기억되나. 제목만 남나.
2. 언어. 비전문 독자가 헤딩과 캡션만으로 답을 설명할 수 있나. 한정어가 보존됐나.
3. 구성. 지배적 객체가 하나인가. 우연한 빈 사각형이 있나 (underfilled split, 고아가 된 세 번째 항목). 빈 사각형은 대개 컴포넌트 계약 위반이다.
4. 타이포. 헤딩이 어절 중간에서 끊기나. peer 값의 크기·굵기가 같나.
5. 근거. 표가 섹션 폭 전부를 쓰나. 짧은 열이 오른쪽 끝에 붙어 있나. 헤더 정렬이 셀과 맞나.
6. 절제. 빼도 의미·리듬을 안 잃는 면·보더·라벨·문단이 있나. 있으면 뺀다.
7. 테마·리플로우. 다크에서 위계가 같나. 모바일에서 가로 스크롤이 없나.
8. 접근성. `h1` 하나, 순서 있는 헤딩, `caption`·`scope`, 링크 텍스트.

검사 결과나 자기비평을 페이지나 답변에 늘어놓지 않는다. 고친 것만 한 줄.

## 환경 제약

- 외부 스타일시트는 Google Fonts 만, 스크립트는 몇몇 CDN 만 허용된다. 이미지·폰트·CSS 는 전부 페이지 안에 data URI 로 심는다. 그래서 `build.sh` 가 CSS 와 폰트를 인라인한다.
- 게시 런타임이 루트 요소에 `data-theme="dark|light"` 를 찍거나(사용자 선택) 아무것도 안 찍는다(시스템). `assets/page.css` 가 이를 `.vbg-report` 의 `color-scheme` 으로 잇는다.
- 페이지 크기 한도 16MB. 폰트 내장으로 기본 2.8MB 가 나간다. 이미지를 많이 심으면 확인한다.
- 이미 공유된 페이지를 갱신하면 공유 핀은 이전 판에 남는다. 외부 뷰어에게 새 판을 보이려면 핀을 옮겨야 한다고 사용자에게 알린다.

## 글

독자는 대개 비개발자다.

- 헤딩은 답을 담되 명사형으로 끝낸다. "리뷰에서 찾은 세 가지", "빠져 있는 한 조각, 일본어 CS". 장르명("개요", "일정") 도, "~합니다" 문장도 아니다. 한국어 보고서는 헤딩에 존댓말을 쓰지 않는다.
- 예외는 화자가 드러나야 하는 약속·제안 하나. "이번 메가와리부터 유어케이스가 채운의 일본 운영팀이 되겠습니다". 페이지에 하나면 충분하다.
- 헤딩은 말로 하는 표현으로. "순환이 끊기는 지점" 이 아니라 "빠져 있는 한 조각". 한자어 명사 연쇄는 본문에서도 피하지만 헤딩에서는 더 눈에 띈다.
- 코드·식별자·수치는 원문 유지. 버튼·축 라벨은 짧아도 되지만 본문은 완전한 문장.
- 일본어·중국어 원문을 인용하면 그 요소에 `lang="ja"` / `lang="zh"` 를 단다. 안 달면 어절 단위 줄바꿈이 걸려 한 줄로 뻗는다.

## 우리 규칙

### 이미지와 설명의 카드

이미지와 그 해석·근거를 하나의 단위로 묶을 때는 [이미지·설명 카드 규칙](references/image-caption-card.md)을 읽는다. 이는 2026-09-10 Chaewun 작업에서 선택한 패턴이며, 모든 섹션을 카드로 감싸는 규칙이 아니다. 카드 외곽에 이미지를 패딩 없이 붙이고 설명에만 여백을 둔다. 이미지 비율뿐 아니라 내부 글자의 가독성과 설명 길이에 따라 좌우·상하 배치를 선택한다.

Vercel 에서 가져온 것이 아니라 우리 페이지 리뷰에서 반복 지적돼 들어온 규칙만 여기 쌓는다. 한 줄에 하나, 관찰 가능한 문장으로 ("답답하다" 가 아니라 "표가 가용 폭을 쓰지 않는다"), 지적된 날짜와 페이지를 적는다.

- 2026-09-09, DOMO 제안: 한국어 헤딩이 어절 중간에서 끊긴다 → `page.css` 에 `word-break: keep-all`.
- 2026-09-09, K-뷰티 일본 진출: 두 열 비교 표에서 짧은 열이 오른쪽 끝에 붙는다 → `vbg-custom-peer-cols`.
- 2026-09-10, Mega Launch: `colspan` 행이 있는 표는 열 폭이 깨진다 → 그 내용은 표 아래 문장으로.
- 2026-09-10, Chaewun 일본 제안: 표 셀처럼 좁은 칸에서 한글 어절이 중간에 끊긴다 → `page.css` 의 `keep-all` 을 헤딩에서 `.vbg-report` 전체로 넓혔다. 일본어는 공백이 없어 `[lang="ja"]` 만 `normal` 로 되돌린다.
- 2026-09-10, Chaewun 일본 제안: h3 바로 뒤 표가 헤딩에서 문단 세 개 분량 떨어진다 → `page.css` 에 헤딩 + 근거 블록은 `space-3` 규칙. caption 이 헤딩과 같은 말이면 `vbg-visually-hidden` 으로 감춘다.
- 2026-09-10, Chaewun 일본 제안: "~합니다" 로 끝나는 헤딩이 발표 대본처럼 읽힌다 → 「글」 절에 헤딩은 명사형 종결, 약속·제안 하나만 예외.
- 2026-09-10, Chaewun 일본 제안: `vbg-next-step` 에 자식 4개를 넣고 `vbg-section` 과 겹쳐 걸어 라벨이 붕 뜨고 12열이 깨졌다 → 「공개 API」 절에 컴포넌트 계약 확인.

## 파일

- `assets/brand.css` Vercel 공개 CSS. 폰트 스택만 프리텐다드로 바꾸고 Vercel 로고 마스크 URL 을 지웠다. 읽지 않는다.
- `assets/font.css` Pretendard Variable @font-face, base64 내장. 읽지 않는다.
- `assets/page.css` 테마 브릿지, keep-all, `vbg-custom-*` 훅. 훅을 추가할 때만 연다.
- `scripts/build.sh` 제목 + CSS 3개 + 본문을 한 파일로.
- `scripts/preview.sh` 라이트·다크·모바일 스크린샷.
- `references/vbg-api.md` 공개 클래스·`data-*` 변형·토큰 전체 목록.
- `references/vercel-design.md` 원문. 계산기·차트·그리드 세부 규칙이 필요할 때만 해당 절을 찾아 읽는다.
