# 사용할 수 있는 CSS 클래스와 변수

필요한 부분을 찾아 읽는 문서다. 배치, 글자, 표, 그래프, 계산기 순서로 정리했다. 각 클래스의 옵션과 CSS 변수는 뒤에 있다.

여기에 있는 이름을 그대로 쓴다. 비슷한 이름을 추측해서 만들지 않는다. 예를 들어 `vbg-stat-detail` 대신 `vbg-stat-note`를 만들면 스타일이 적용되지 않는다. 맞는 클래스가 없으면 내용에 맞는 HTML 태그를 쓰고, 페이지 전용 클래스 이름을 `vbg-custom-*`로 시작한다. 그래프의 선이나 막대에 붙이는 이름은 `vbg-viz-*`로 시작할 수 있다.

기본 클래스는 `assets/brand.css`에 있다. 설명은 Vercel `design.md`의 「Use the published CSS API」에서 가져왔다. 우리가 추가한 스타일은 마지막 절에 따로 적었다.

## 페이지 구조와 배치

### 페이지를 감싸는 요소

| 클래스 | 쓰는 곳 | 주의할 점 |
|---|---|---|
| `vbg-report`, `vbg-shell` | 페이지 전체를 감싸는 요소 | [HTML 기본 구조 예시](html-shell.md)를 참고한다. |
| `vbg-skip-link` | 본문으로 건너뛰는 링크 | 링크가 실제 본문 위치를 가리키게 한다. |
| `vbg-header`, `vbg-masthead` | 페이지 머리말 | 브랜드와 문서 정보를 넣는다. |
| `vbg-identity` | 브랜드 이름 | 실제 브랜드 정보를 쓴다. |
| `vbg-document-meta` | 머리말 오른쪽의 문서 정보 | 확인된 정보를 최대 두 개까지 넣는다. |
| `vbg-recipient`, `vbg-state`, `vbg-date`, `vbg-confidentiality` | 받는 사람, 문서 상태, 날짜, 기밀 여부 | 자료에 없는 정보는 만들지 않는다. |
| `vbg-footer`, `vbg-sources` | 꼬리말과 출처 | 본문 뒤에 둔다. |
| `vbg-wordmark`, `vbg-logo` | Vercel 로고용 클래스 | 우리 페이지에서는 쓰지 않는다. |

### 내용을 나누고 나란히 놓기

| 클래스 | 쓰는 곳 | 배치 방법 |
|---|---|---|
| `vbg-opening` | 페이지 첫 부분 | 기본은 내용을 위아래로 놓는다. `data-layout="split"`이면 결론과 근거를 7:5로 나눈다. |
| `vbg-opening-claim`, `vbg-opening-proof`, `vbg-opening-context` | 첫 부분의 결론, 근거, 보충 설명 | 나란히 배치할 때는 결론이 7칸, 근거가 5칸을 쓴다. |
| `vbg-section` | 주제별로 나눈 본문 | 12칸 그리드다. 바로 안에 놓인 `h2`, `h3`, `h4`, `p`, `ul`, `ol`, `dl`, `blockquote`, `.vbg-reading`은 7칸, 표·그래프 등 나머지는 12칸 전체를 쓴다. |
| `vbg-chapter` | 내용이 크게 바뀌는 부분 | 모든 단락에 반복해서 쓰지 않는다. |
| `vbg-reading`, `vbg-flow` | 여러 문단으로 이어지는 본문 | 글을 묶어 배치할 때 쓴다. |
| `vbg-grid` | 내용을 여러 칸에 배치할 때 | 안에 넣는 요소의 너비는 `vbg-span-*`으로 고른다. |
| `vbg-span-4`, `vbg-span-5`, `vbg-span-6`, `vbg-span-7`, `vbg-span-8`, `vbg-span-12` | 그리드 안 요소의 너비 | 필요한 칸 수에 맞는 이름을 쓴다. 목록에 없는 숫자는 만들지 않는다. |
| `vbg-split` | 두 내용을 나란히 놓을 때 | 기본은 7:5다. `data-ratio="equal"`은 1:1, `wide`는 한쪽을 더 넓게 둔다. |
| `vbg-stack` | 내용을 위아래로 놓을 때 | `data-gap`으로 간격을 고른다. |
| `vbg-cluster` | 짧은 항목을 한데 묶을 때 | 같은 묶음에 속하는 항목에 쓴다. |
| `vbg-band` | 배경색을 달리해 한 부분을 강조할 때 | `data-tone="contrast"`를 쓰며, 한 페이지에서 한 곳에만 쓴다. |

## 글자와 짧은 설명

| 클래스 | 쓰는 곳 | 주의할 점 |
|---|---|---|
| `vbg-title` | 보통의 페이지 제목 | `h1`에 쓴다. |
| `vbg-display` | 특별히 크게 보여줄 문장 | 페이지에서 가장 중요한 문장 하나를 크게 강조할 필요가 있을 때만 쓴다. |
| `vbg-heading-24` | 큰 단락의 제목 | `h2`에 쓴다. |
| `vbg-heading-20`, `vbg-heading-16` | 그 아래의 작은 제목 | 제목 단계에 맞춰 `h3`, `h4`에 쓴다. |
| `vbg-lede` | 내용을 이해하는 데 필요한 배경 설명 | 한 문단으로 짧게 쓴다. |
| `vbg-context` | 함께 알아야 할 짧은 설명 | 주된 설명에 덧붙인다. |
| `vbg-label` | 짧은 이름이나 항목명 | 긴 본문에 쓰지 않는다. |
| `vbg-caption`, `vbg-meta` | 표·그림 설명이나 문서 정보 | 본문보다 덜 중요한 짧은 설명에만 쓴다. |
| `vbg-mono` | 코드나 식별자 | 문장 전체에 씌우지 않는다. |
| `vbg-numeric` | 나란히 비교하는 숫자 | 숫자 열의 제목과 값 양쪽에 붙인다. |
| `vbg-visually-hidden` | 화면에는 숨기되 화면 읽기 프로그램에는 제공할 내용 | 바로 앞 제목과 같은 표 설명 등을 처리할 때 쓴다. |
| `vbg-formula` | 계산식 | 실제 계산에 쓴 식을 적는다. |
| `vbg-link` | 본문 링크 | 원문이나 관련 자료를 연결한다. |
| `vbg-list`, `vbg-list-compact` | 목록 | 보통은 기본 목록을 쓰고, 항목이 많아 좁은 간격이 필요할 때만 `compact`를 쓴다. |

## 표와 숫자, 비교 설명

| 클래스 | 쓰는 곳 | 주의할 점 |
|---|---|---|
| `vbg-table-wrap` | 표를 감싸는 요소 | 안에 `<table>`을 바로 넣는다. |
| `vbg-stat-strip` | 숫자 여러 개를 나란히 비교할 때 | 안에 `vbg-stat`을 넣는다. |
| `vbg-stat` | 비교할 숫자 하나 | `vbg-stat-label`, `vbg-stat-value`, 필요한 경우 `vbg-stat-detail`을 넣는다. |
| `vbg-stat-label`, `vbg-stat-value`, `vbg-stat-detail` | 숫자의 이름, 값, 보충 설명 | 무엇을 나타내는 숫자인지 알 수 있게 쓴다. |
| `vbg-comparison` | 여러 대안의 차이를 보여줄 때 | 같은 항목끼리 맞춰 읽게 하려면 `data-align="rows"`를 쓴다. |
| `vbg-note` | 주의사항이나 짧은 안내 | 필요하면 `data-tone`으로 안내 종류를 고른다. |
| `vbg-next-step` | 다음 행동 안내 | 바로 안에 라벨 `p.vbg-label`과 설명 문단, 두 요소만 넣으면 4:8로 나란히 배치된다. 셋 이상이면 위아래로 쌓인다. |
| `vbg-decision`, `vbg-recommendation`, `vbg-evidence` | 결정, 추천, 근거를 담는 부분 | 같은 내용을 여러 형태로 반복하지 않는다. |
| `vbg-surface`, `vbg-callout` | 내용을 따로 묶거나 눈에 띄게 안내할 때 | 배경과 테두리는 꼭 필요할 때만 쓴다. |

`vbg-next-step`과 `vbg-section`은 둘 다 그리드 배치를 정한다. 한 요소에 두 클래스를 함께 붙이지 않는다. 2026-09-10 Chaewun 일본 제안에서 두 클래스를 겹쳐 쓰고 자식 요소를 네 개 넣었더니, 라벨 위치와 12칸 배치가 어긋났다.

`vbg-stat`의 `data-priority`는 숫자의 글자 크기를 바꾼다. 같은 중요도로 비교할 숫자에는 서로 다른 `data-priority`를 주지 않는다. 글자 크기와 행 높이가 달라진다.

### 표를 만들 때 지킬 것

- 표에 `caption`을 붙인다. 표를 소개하는 문장은 표 위에 두고, 표는 해당 단락의 전체 너비를 쓴다.
- 숫자 열은 제목인 `th`와 값인 `td` 양쪽에 `class="vbg-numeric"`을 붙인다. 글자 열은 왼쪽으로 맞춘다. 표의 제목 셀에는 어떤 행이나 열을 설명하는지 나타내는 `scope`를 붙인다.
- 두세 열을 같은 중요도로 비교한다면 `vbg-custom-peer-cols`를 쓴다. 너비에 관한 설명은 마지막 절에 있다.
- 넓은 표는 감싸는 요소에 `data-mobile="stack"`을 붙인다. 열이 다섯 개를 넘거나 열 제목이 여러 줄로 접히면 열을 줄이거나 표를 나눈다. 필요한 정보는 계속 찾아볼 수 있어야 한다.
- `colspan`으로 여러 열을 가로질러 셀을 합치지 않는다. 그 내용은 표 아래 문장으로 쓴다. 2026-09-10 Mega Launch에서 합쳐진 셀 때문에 열 너비가 어긋났다.
- 같은 분류가 반복된다는 이유만으로 열 하나를 낭비하지 않는다. 비교하는 숫자는 단위와 소수점 자릿수를 맞춘다.

## 그래프

| 클래스 | 쓰는 곳 | 주의할 점 |
|---|---|---|
| `vbg-chart` | 그래프 전체 | `figure`에 붙인다. 제목, 그래프, 설명을 함께 넣는다. |
| `vbg-chart-header`, `vbg-chart-viewport` | 그래프 제목 부분과 그래프가 보이는 영역 | 이름에 맞는 요소에 붙인다. |
| `vbg-legend` | 색이나 선의 의미를 설명하는 범례 | 각 항목에 직접 이름을 붙일 수 있으면 범례를 따로 만들지 않는다. |
| `vbg-bar-comparison`, `vbg-bar-list` | 막대그래프로 여러 값을 비교할 때 | 모든 값을 같은 기준으로 그린다. |
| `vbg-bar`, `vbg-bar-label`, `vbg-bar-value` | 막대 항목과 그 이름, 값 | 이름과 숫자가 어느 막대에 속하는지 분명하게 놓는다. |
| `vbg-bar-track`, `vbg-bar-fill` | 막대의 전체 범위와 값에 해당하는 길이 | 값의 차이가 실제 길이에 드러나게 한다. |

SVG 안에서는 다음 클래스를 쓴다.

| 클래스 | 쓰는 곳 |
|---|---|
| `vbg-chart-axis`, `vbg-chart-gridline` | 축과 눈금선 |
| `vbg-series-stroke`, `vbg-series-fill` | 데이터의 선과 채운 영역 |
| `vbg-data-point` | 각 데이터를 나타내는 점 |
| `vbg-chart-direct-label`, `vbg-chart-value` | 그래프에 직접 붙이는 이름과 숫자 |
| `vbg-chart-annotation`, `vbg-chart-annotation-line` | 보충 설명과 그 설명이 가리키는 선 |
| `vbg-series-1`, `vbg-series-2`, `vbg-series-3`, `vbg-series-4`, `vbg-series-5`, `vbg-series-6` | 데이터 묶음별 색 |

선인지 채운 영역인지에 따라 `vbg-series-stroke`나 `vbg-series-fill`을 고르고, 색을 정하는 번호 클래스를 함께 붙인다. `vbg-series-fill-1`처럼 합친 이름은 없다.

## 계산기와 입력창

| 클래스 | 쓰는 곳 | 주의할 점 |
|---|---|---|
| `vbg-calculator` | 계산기 전체 | 바로 안에 입력 부분과 결과 부분을 넣는다. |
| `vbg-calculator-inputs`, `vbg-calculator-output` | 입력 부분과 결과 부분 | 이 요소들과 `vbg-calculator` 사이에 다른 요소를 끼우지 않는다. |
| `vbg-control-group` | 관련 입력 항목 묶음 | 함께 입력하는 항목을 묶는다. |
| `vbg-field`, `vbg-unit-field` | 일반 입력창과 단위가 붙은 입력창 | 잘못된 값은 `data-invalid="true"`로 표시한다. |
| `vbg-unit-prefix`, `vbg-unit-suffix` | 값 앞이나 뒤에 붙이는 단위 | 실제 입력값의 단위를 쓴다. |
| `vbg-helper`, `vbg-error` | 입력 안내와 오류 설명 | 무엇을 입력하거나 고쳐야 하는지 적는다. |
| `vbg-range-ends`, `vbg-range-min`, `vbg-range-max` | 입력 범위의 양 끝과 최솟값·최댓값 | 허용하는 범위를 보여준다. |
| `vbg-result-group`, `vbg-result` | 여러 결과의 묶음과 개별 결과 | 같은 계산에 속한 결과를 함께 둔다. |
| `vbg-result-label`, `vbg-result-value`, `vbg-result-detail` | 결과 이름, 값, 보충 설명 | 계산 결과를 이해하는 데 필요한 내용을 적는다. |
| `vbg-button` | 계산기 안의 조작 버튼 | 본문의 링크를 버튼처럼 꾸미는 데 쓰지 않는다. |

자세한 배치와 동작은 [Vercel 원문](vercel-design.md)의 「Calculators and interaction」을 참고한다.

## 클래스에 붙일 수 있는 옵션

아래는 CSS가 지원하는 `data-*` 속성이다. 표에 없는 속성이나 값을 추측해 만들지 않는다. 같은 행에 있는 선택 가능한 값은 쉼표로 구분했다.

| 클래스 | 속성 | 선택 가능한 값 |
|---|---|---|
| `vbg-band` | `data-tone` | `contrast` |
| `vbg-bar`, `vbg-series-stroke` | `data-role` | `primary`, `reference` |
| `vbg-button` | `data-selected` | `true` |
| `vbg-button` | `data-state` | `active` |
| `vbg-calculator`, `vbg-callout`, `vbg-surface` | `data-contained` | `true` |
| `vbg-calculator`, `vbg-callout`, `vbg-surface` | `data-variant` | `contained` |
| `vbg-calculator` | `data-layout` | `split` |
| `vbg-callout`, `vbg-note` | `data-tone` | `error`, `info`, `success`, `warning` |
| `vbg-chart` | `data-mobile` | `scroll` |
| `vbg-comparison` | `data-align` | `rows` |
| `vbg-decision`, `vbg-result` | `data-priority` | `primary` |
| `vbg-field`, `vbg-unit-field` | `data-invalid` | `true` |
| `vbg-link` | `data-variant` | `highlight`, `secondary` |
| `vbg-opening` | `data-layout` | `split`, `stack` |
| `vbg-report` | `data-theme` | `auto`, `dark`, `light` |
| `vbg-split` | `data-ratio` | `equal`, `wide` |
| `vbg-stack` | `data-gap` | `group`, `section`, `tight` |
| `vbg-stat-strip` | `data-count` | `4` |
| `vbg-stat` | `data-priority` | `primary`, `supporting` |
| `vbg-state` | `data-status` | `verified` |
| `vbg-table-wrap` | `data-density` | `compact` |
| `vbg-table-wrap` | `data-mobile` | `stack` |
| `vbg-table-wrap` | `data-sticky-first` | `true` |
| `vbg-table-wrap` | `data-variant` | `comparison` |

## 페이지 전용 CSS에서 사용할 변수

색, 글자 크기, 간격은 아래에 미리 정해 둔 값을 쓴다. 예를 들어 `var(--vbg-space-4)`처럼 `var()`로 읽는다. `vbg-custom-*` 규칙 안에서 사용하며, 새 `--vbg-*` 변수를 만들거나 기존 값을 다시 정의하지 않는다.

### 배경과 글자 색

| 용도 | 변수 |
|---|---|
| 기본 배경과 보조 배경 | `--vbg-surface-primary`, `--vbg-surface-secondary` |
| 강조한 부분의 배경 | `--vbg-surface-contrast` |
| 기본 글자와 보조 글자 | `--vbg-text-primary`, `--vbg-text-secondary` |
| 강조한 배경 위의 글자 | `--vbg-text-on-contrast`, `--vbg-text-on-contrast-secondary` |
| 테두리 강도 | `--vbg-border-subtle`, `--vbg-border-default`, `--vbg-border-strong` |
| 강조한 배경 위의 테두리 | `--vbg-border-on-contrast` |
| 키보드로 선택한 요소의 표시 | `--vbg-focus` |
| 안내, 성공, 주의, 오류 색 | `--vbg-color-info`, `--vbg-color-success`, `--vbg-color-warning`, `--vbg-color-error` |
| 그래프의 데이터 묶음별 색 | `--vbg-chart-1`부터 `--vbg-chart-6`까지 |

### 간격과 모서리

| 용도 | 변수 |
|---|---|
| 같은 묶음 안의 간격 | `--vbg-space-2`, `--vbg-space-3`, `--vbg-space-4` |
| 묶음 사이의 간격 | `--vbg-space-6`, `--vbg-space-8` |
| 큰 단락 사이의 간격 | `--vbg-space-8`, `--vbg-space-10`, `--vbg-space-12` |
| 그 밖에 사용할 수 있는 간격 | `--vbg-space-1`, `--vbg-space-5` |
| 내용이 크게 바뀌는 부분의 간격 | `--vbg-space-16`. 큰 내용 묶음 사이에서만 쓴다. |
| 모서리 둥글기 | `--vbg-radius-small`, `--vbg-radius` |

### 글자 크기와 굵기, 줄 간격

| 용도 | 변수 |
|---|---|
| 가장 큰 글자와 페이지 제목 크기 | `--vbg-type-display`, `--vbg-type-page-title` |
| 제목 크기 | `--vbg-type-title`, `--vbg-type-section`, `--vbg-type-subsection` |
| 소개 문단과 본문 크기 | `--vbg-type-lede`, `--vbg-type-body` |
| 좁은 간격의 본문과 짧은 이름, 문서 정보 크기 | `--vbg-type-compact`, `--vbg-type-label`, `--vbg-type-metadata` |
| 글자 굵기 | `--vbg-weight-regular`, `--vbg-weight-heading`, `--vbg-weight-medium`, `--vbg-weight-semibold` |
| 본문과 짧은 설명의 줄 간격 | `--vbg-leading-body`, `--vbg-leading-compact`, `--vbg-leading-caption` |
| 가장 큰 글자와 페이지 제목의 줄 간격 | `--vbg-leading-display`, `--vbg-leading-page-title` |
| 제목의 줄 간격 | `--vbg-leading-title`, `--vbg-leading-section`, `--vbg-leading-subsection` |
| 소개 문단의 줄 간격 | `--vbg-leading-lede` |

## 우리가 추가한 스타일

아래 스타일은 `assets/page.css`에 있다.

| 클래스 또는 규칙 | 쓰는 곳과 동작 | 추가한 이유 |
|---|---|---|
| `vbg-custom-process`, `vbg-custom-step` | 작업 순서를 위아래로 나열한다. 각 단계는 `vbg-custom-step-label`(단계 이름), `vbg-custom-step-title`(한 문장 설명), `vbg-custom-step-gate`(조건이나 주의점) 세 문단으로 쓴다. | 단계와 조건을 함께 보여주기 위한 배치다. |
| `vbg-custom-peer-cols` | 표의 비교 열 너비를 맞춘다. 화면 너비가 801px 이상이면 `table-layout: fixed`를 쓰고 첫 열을 20%로 둔다. | 2026-09-09 K-뷰티 일본 진출 페이지에서 짧은 열이 오른쪽 끝에 붙어 보였다. |
| `vbg-custom-logo` | 로고 너비를 112px로 둔다. | 로고를 넣을 때 쓰는 클래스다. |
| `data-theme` 연결 | 문서의 최상위 요소에 설정된 테마를 `.vbg-report`의 `color-scheme`에 반영한다. | 게시 도구에서 선택한 테마에 맞추기 위해서다. |
| 한국어 줄바꿈 | `.vbg-report` 전체에 `word-break: keep-all`과 `overflow-wrap: break-word`를 쓴다. 일본어인 `[lang="ja"]`는 `normal`로 처리한다. | 2026-09-09 DOMO 제안의 제목이 어절 중간에서 끊겼다. 2026-09-10 Chaewun 일본 제안의 좁은 표 셀에서도 같은 문제가 생겨 페이지 전체에 적용했다. |
| 제목 바로 다음 표·그래프의 간격 | `space-3` 간격을 쓴다. 표 설명이 바로 앞 제목과 같으면 `vbg-visually-hidden`으로 숨긴다. | 2026-09-10 Chaewun 일본 제안에서 h3 다음 표가 문단 세 개 분량만큼 떨어져 보였다. |
