# vbg 공개 API

`assets/brand.css` 가 제공하는 클래스·변형·토큰. 여기 있는 이름만 쓴다. 없는 이름을 추측하거나 다른 프리미티브에서 이름을 유추하지 않는다(`vbg-stat-note` 같은 동의어 금지). 맞는 것이 없으면 semantic HTML 에 `vbg-custom-*`(레이아웃) 또는 `vbg-viz-*`(시각화 마크) 훅을 쓴다. 출처는 Vercel design.md 「Use the published CSS API」 절.

## 골격과 레이아웃

`vbg-report` `vbg-shell` `vbg-skip-link` `vbg-header` `vbg-masthead` `vbg-identity` `vbg-wordmark`(Vercel 마스크, 우리는 안 씀) `vbg-document-meta` `vbg-recipient` `vbg-state` `vbg-date` `vbg-confidentiality` `vbg-context` `vbg-opening` `vbg-opening-claim` `vbg-opening-proof` `vbg-opening-context` `vbg-section` `vbg-chapter` `vbg-reading` `vbg-flow` `vbg-stack` `vbg-cluster` `vbg-grid` `vbg-split` `vbg-band` `vbg-span-4` `vbg-span-5` `vbg-span-6` `vbg-span-7` `vbg-span-8` `vbg-span-12` `vbg-footer` `vbg-logo`(Vercel 마스크, 우리는 안 씀)

레이아웃 동작 요약.
- `.vbg-section` 은 12열 grid. 직계 `h2 h3 h4 p ul ol dl blockquote .vbg-reading` 은 7열, 나머지(표·차트·`.vbg-comparison` 등)는 12열 전부.
- `.vbg-opening[data-layout="split"]` 은 claim 7열 + proof 5열. 기본(속성 없음)은 세로 스택.
- `.vbg-split` 은 7:5, `[data-ratio="equal"]` 은 1:1, `[data-ratio="wide"]` 는 넓은 쪽 우선.
- `.vbg-stack[data-gap="tight|group|section"]` 로 세로 간격.

## 타입과 근거

`vbg-title` `vbg-display` `vbg-heading-24` `vbg-heading-20` `vbg-heading-16` `vbg-lede` `vbg-label` `vbg-meta` `vbg-caption` `vbg-mono` `vbg-numeric` `vbg-visually-hidden` `vbg-note` `vbg-formula` `vbg-sources` `vbg-stat-strip` `vbg-stat` `vbg-stat-label` `vbg-stat-value` `vbg-stat-detail` `vbg-comparison` `vbg-table-wrap` `vbg-chart` `vbg-chart-header` `vbg-chart-viewport` `vbg-legend` `vbg-bar-comparison` `vbg-bar-list` `vbg-bar` `vbg-bar-label` `vbg-bar-value` `vbg-bar-track` `vbg-bar-fill` `vbg-link` `vbg-list` `vbg-list-compact` `vbg-next-step` `vbg-decision` `vbg-recommendation` `vbg-evidence` `vbg-surface` `vbg-callout`

타입 role 사용처.
- `vbg-display` 페이지를 정의하는 문장 하나에만, 크기가 earned 될 때.
- `vbg-title` 보통의 페이지 제목(h1).
- `vbg-heading-24` 큰 섹션 전환(h2). `vbg-heading-20` `vbg-heading-16` 하위 구조(h3, h4).
- `vbg-lede` 짧은 오리엔테이션 한 문단. `vbg-context` 보조 라벨 문장.
- `vbg-label` 짧은 이름. `vbg-caption` `vbg-meta` 종속 맥락에만.

시각화 클래스(인라인 SVG 안): `vbg-chart-axis` `vbg-chart-gridline` `vbg-series-stroke` `vbg-series-fill` `vbg-data-point` `vbg-chart-direct-label` `vbg-chart-value` `vbg-chart-annotation` `vbg-chart-annotation-line` `vbg-series-1` ~ `vbg-series-6`. fill/stroke role 과 번호 series 를 조합한다. `vbg-series-fill-1` 같은 합성 이름은 없다.

## 계산기

`vbg-calculator` `vbg-calculator-inputs` `vbg-calculator-output` `vbg-control-group` `vbg-field` `vbg-unit-field` `vbg-unit-prefix` `vbg-unit-suffix` `vbg-helper` `vbg-error` `vbg-range-ends` `vbg-range-min` `vbg-range-max` `vbg-result-group` `vbg-result` `vbg-result-label` `vbg-result-value` `vbg-result-detail` `vbg-button`

`.vbg-calculator` 가 `.vbg-calculator-inputs` 와 `.vbg-calculator-output` 을 직접 소유한다. 사이에 래퍼를 끼우지 않는다. 세부는 `vercel-design.md` 「Calculators and interaction」.

## data-* 변형 (CSS 에서 추출)

- `.vbg-band[data-tone="contrast"]`
- `.vbg-bar[data-role="primary"]`
- `.vbg-bar[data-role="reference"]`
- `.vbg-button[data-selected="true"]`
- `.vbg-button[data-state="active"]`
- `.vbg-calculator[data-contained="true"]`
- `.vbg-calculator[data-layout="split"]`
- `.vbg-calculator[data-variant="contained"]`
- `.vbg-callout[data-contained="true"]`
- `.vbg-callout[data-tone="error"]`
- `.vbg-callout[data-tone="info"]`
- `.vbg-callout[data-tone="success"]`
- `.vbg-callout[data-tone="warning"]`
- `.vbg-callout[data-variant="contained"]`
- `.vbg-chart[data-mobile="scroll"]`
- `.vbg-comparison[data-align="rows"]`
- `.vbg-decision[data-priority="primary"]`
- `.vbg-field[data-invalid="true"]`
- `.vbg-link[data-variant="highlight"]`
- `.vbg-link[data-variant="secondary"]`
- `.vbg-note[data-tone="error"]`
- `.vbg-note[data-tone="info"]`
- `.vbg-note[data-tone="success"]`
- `.vbg-note[data-tone="warning"]`
- `.vbg-opening[data-layout="split"]`
- `.vbg-opening[data-layout="stack"]`
- `.vbg-report[data-theme="auto"]`
- `.vbg-report[data-theme="dark"]`
- `.vbg-report[data-theme="light"]`
- `.vbg-result[data-priority="primary"]`
- `.vbg-series-stroke[data-role="primary"]`
- `.vbg-series-stroke[data-role="reference"]`
- `.vbg-split[data-ratio="equal"]`
- `.vbg-split[data-ratio="wide"]`
- `.vbg-stack[data-gap="group"]`
- `.vbg-stack[data-gap="section"]`
- `.vbg-stack[data-gap="tight"]`
- `.vbg-stat-strip[data-count="4"]`
- `.vbg-stat[data-priority="primary"]`
- `.vbg-stat[data-priority="supporting"]`
- `.vbg-state[data-status="verified"]`
- `.vbg-surface[data-contained="true"]`
- `.vbg-surface[data-variant="contained"]`
- `.vbg-table-wrap[data-density="compact"]`
- `.vbg-table-wrap[data-mobile="stack"]`
- `.vbg-table-wrap[data-sticky-first="true"]`
- `.vbg-table-wrap[data-variant="comparison"]`
- `.vbg-unit-field[data-invalid="true"]`

## 페이지 CSS 가 읽어도 되는 토큰

`vbg-custom-*` 규칙 안에서 `var()` 로만 쓴다. 새 `--vbg-*` 토큰을 만들거나 재선언하지 않는다.

- 면·글자: `--vbg-surface-primary` `--vbg-surface-secondary` `--vbg-surface-contrast` `--vbg-text-primary` `--vbg-text-secondary` `--vbg-text-on-contrast` `--vbg-text-on-contrast-secondary`
- 경계·상태: `--vbg-border-subtle` `--vbg-border-default` `--vbg-border-strong` `--vbg-border-on-contrast` `--vbg-focus` `--vbg-color-info` `--vbg-color-success` `--vbg-color-warning` `--vbg-color-error`
- 데이터: `--vbg-chart-1` ~ `--vbg-chart-6`
- 간격·모양: `--vbg-space-1` `-2` `-3` `-4` `-5` `-6` `-8` `-10` `-12` `-16` `--vbg-radius-small` `--vbg-radius`
- 글자 크기: `--vbg-type-display` `-page-title` `-title` `-section` `-subsection` `-lede` `-body` `-compact` `-label` `-metadata`
- 굵기·행간: `--vbg-weight-regular` `-heading` `-medium` `-semibold` `--vbg-leading-body` `-compact` `-caption` `-display` `-page-title` `-title` `-section` `-subsection` `-lede`

간격 쓰임새. 그룹 안 `space-2`~`4`, 그룹 사이 `6`~`8`, 섹션 전환 `8`~`12`, `16` 은 chapter 전환에만.

## 우리 훅 (`assets/page.css`)

- `.vbg-custom-process` > `.vbg-custom-step` (`.vbg-custom-step-label` `-title` `-gate`): 세로 시퀀스. 단계명·한 문장·조건.
- `table.vbg-custom-peer-cols`: 801px 이상에서 `table-layout: fixed`, 첫 열 20%. 동등 비교 열의 폭을 맞춘다.
- `.vbg-custom-logo`: 112px 폭 브랜드 로고 이미지.
- 테마 브릿지: 루트의 `data-theme` 을 `.vbg-report` 의 `color-scheme` 으로.
- `word-break: keep-all`: h1~h4, `.vbg-title`, `.vbg-lede`, `.vbg-custom-step-title`, `th`.
