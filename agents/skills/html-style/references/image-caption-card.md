# 이미지와 설명을 한 카드로 묶기

출처: 2026-09-10 Chaewun 제안서 작업에서 사용자가 선택한 패턴. 모든 이미지를 카드로 만드는 규칙은 아니다. 이미지의 의미·근거를 바로 옆이나 아래에서 설명해야 하고, 둘을 하나의 단위로 읽게 할 때 사용한다. 사용자의 별도 배치 지시가 우선한다.

## 배치 결정

원본 이미지의 가로세로 비율만 보지 않는다. 실제 카드 폭에서 이미지 안의 글자·제품·도표가 읽히는지, 설명 길이와 이미지 높이가 균형을 이루는지 함께 본다.

| 이미지와 설명의 조건 | 먼저 시도할 배치 | 바꿔야 하는 신호 |
|---|---|---|
| 가로 이미지 + 짧은 설명, 줄인 뒤에도 내용이 읽힘 | 이미지 왼쪽, 본문 오른쪽. 이미지 폭 60~70%에서 시작 | 이미지 글자가 작아지거나 본문 때문에 이미지 위아래에 큰 빈 면이 생기면 상하로 |
| 글자가 많은 배너·차트·스크린샷, 아주 넓고 낮은 이미지 | 이미지 위, 본문 아래. 이미지에 카드 전체 폭을 제공 | 설명이 길면 본문을 의미 단위로 정리하고, 카드 밖의 후속 본문으로 분리 |
| 정사각형·세로 제품 사진 + 짧거나 중간 길이 설명 | 좌우 배치. 이미지 폭 40~50%에서 시작 | 작은 화면에서 본문이 좁아지면 상하로 |
| 긴 포스터·인포그래픽, 원본을 통째로 보면 너무 작아짐 | 넓은 상하 배치와 원본 보기 링크 | 과도한 카드 높이를 피하려고 핵심 내용을 자르거나 찌그러뜨리지 않음 |

비율은 출발점이지 고정값이 아니다. 본문을 이미지 왼쪽에 놓는 것은 앞뒤 섹션의 읽기 순서나 사용자 요청이 뒷받침할 때 선택한다. 장식적인 좌우 교대는 하지 않는다.

## 이미지와 면

- 카드 한 겹에 이미지와 설명을 함께 넣는다. 얇은 1px 테두리, 둥근 바깥 모서리, `overflow: hidden`을 사용한다. 기본 그림자는 없다.
- 카드와 이미지 래퍼에는 패딩을 주지 않는다. 이미지가 카드 외곽에 닿게 한다. 이미지에 별도의 둥근 모서리나 안쪽 액자를 더하지 않는다.
- 패딩은 본문에만 둔다. 기본은 `space-6`, 좁은 화면에서는 `space-4`~`space-5`. 앞의 소개 문장과 카드는 `space-3`에서 시작한다. 부모 grid의 gap과 문단 margin까지 합친 실제 간격을 확인한다.
- 면·테두리·글자는 기존 공개 토큰을 사용한다. 사진의 배경색을 임의로 추측해 빈 영역에 덧칠하지 않는다. 다크 테마에서도 원본 이미지는 재색칠하지 않는다.
- **글자·로고·차트·패키지 정보가 있는 이미지는 원본 전체 보존이 우선이다.** 기본은 `width: 100%; height: auto`. 좌우 배치가 맞지 않으면 상하로 바꾼다. 꽉 채우기 위해 `object-fit: cover`로 내용을 자르거나 `fill`로 왜곡하지 않는다.
- 여백을 잘라도 되는 사진만 `height: 100%; object-fit: cover`를 쓸 수 있다. 주요 피사체가 남는 `object-position`을 고른다. 이미지 자체의 여백과 CSS 패딩은 구분한다.

## 본문과 반응형

- `figure` 안에 이미지와 `figcaption`을 둔다. 이미지 대체 텍스트에는 이미지의 핵심 메시지를 담는다.
- 이미지에 이미 있는 제목을 본문에 반복하지 않는다. 본문은 이미지 해석·리뷰 근거·한정어를 보완한다. 일본어 인용에는 `lang="ja"`를 단다.
- 짧은 설명이면 문단으로 끝낸다. 실제로 서로 다른 근거가 둘일 때만 두 묶음으로 나눈다. 내부 카드·badge·장식 라벨은 추가하지 않는다.
- 본문이 길다고 폰트를 줄여 맞추지 않는다. 내용을 보존하면서 상하 배치를 선택하거나 후속 본문으로 분리한다.
- 좌우 배치는 콘텐츠가 읽히지 않는 폭에서 이미지 위·본문 아래로 전환한다. 800px은 시작점일 뿐, 실제 카드 폭과 설명 언어로 결정한다. 모바일 이미지는 전체 폭과 원본 비율을 유지한다.

## 페이지 안에서 쓰는 예시

다음은 공개 CSS에 새 클래스를 추가한 것이 아니라, 페이지 본문 안에 선언하는 `vbg-custom-*` 예시다. 기본은 잘리지 않는 상하 배치다. 위 기준을 통과한 경우에만 `data-layout="side"`를 선택한다.

```html
<style>
.vbg-custom-media-card {
  display: grid;
  margin: var(--vbg-space-3) 0 0;
  padding: 0;
  overflow: hidden;
  border: 1px solid var(--vbg-border-default);
  border-radius: var(--vbg-space-4);
  background: var(--vbg-surface-primary);
}
.vbg-custom-media-card > img {
  display: block;
  width: 100%;
  height: auto;
  min-width: 0;
}
.vbg-custom-media-copy {
  min-width: 0;
  padding: var(--vbg-space-6);
  align-self: center;
}
.vbg-custom-media-copy > :first-child { margin-top: 0; }
.vbg-custom-media-copy > :last-child { margin-bottom: 0; }
@media (min-width: 801px) {
  .vbg-custom-media-card[data-layout="side"] {
    grid-template-columns: minmax(0, 2fr) minmax(0, 1fr);
    align-items: start;
  }
}
@media (max-width: 800px) {
  .vbg-custom-media-copy { padding: var(--vbg-space-5); }
}
</style>
<figure class="vbg-custom-media-card" data-layout="stack">
  <img src="IMAGE_DATA_URI" alt="이미지의 핵심 메시지">
  <figcaption class="vbg-custom-media-copy">
    <p>이미지가 전달하는 메시지를 뒷받침하는 설명.</p>
  </figcaption>
</figure>
```

예시의 이미지·대체 텍스트·문단은 실제 자료로 교체한다. 이미지와 본문 높이가 크게 다른 좌우 배치를 그대로 확정하지 않는다.

## 확인

기존 미리보기 단계에서 이미지 잘림·글자 가독성, 카드 안의 불필요한 빈 면, 이미지 가장자리의 패딩, 안내 문장과 카드 사이 실제 간격, 모바일·다크 테마를 확인한다. 미리보기가 제한되면 화면 확인을 했다고 말하지 않는다.
