# HTML 기본 구조 예시

새 본문 파일을 만들 때 참고한다. 전체 내용을 `.vbg-report`와 `.vbg-shell`로 감싸고, 본문으로 건너뛰는 링크와 머리말, 본문(`main`), 꼬리말을 둔다. `.vbg-report`는 `body`가 아닌 `div`에 붙인다.

아래 예시는 **결론과 근거를 나란히 보여줄 때** 쓴다. 다른 페이지는 내용에 맞게 본문을 바꾼다.

- 비교 페이지는 같은 항목끼리 나란히 놓아 차이를 쉽게 찾을 수 있게 한다.
- 변화 추이를 보여주는 페이지는 가장 눈에 띄는 변화를 먼저 보여준다.
- 계산기는 첫 화면에서 바로 쓸 수 있게 한다. 예시에 있는 설명 문단을 계산기 앞에 그대로 붙이지 않는다.

근거를 별도 칸에 둘 필요가 없으면 `split`을 쓰지 않는다.

```html
<div class="vbg-report">
  <div class="vbg-shell">
    <a class="vbg-skip-link" href="#main">본문으로 건너뛰기</a>
    <header class="vbg-header">
      <div class="vbg-masthead">
        <span class="vbg-identity"><span>브랜드명</span></span>
        <div class="vbg-document-meta">
          <span class="vbg-recipient">받는 사람</span>
          <span class="vbg-state">문서 상태 또는 날짜</span>
        </div>
      </div>
    </header>
    <main id="main">
      <section class="vbg-opening" data-layout="split" aria-labelledby="page-title">
        <div class="vbg-opening-claim">
          <h1 id="page-title" class="vbg-title">가장 중요한 결론</h1>
          <p class="vbg-lede">이 결론이 중요한 이유를 설명한다.</p>
          <p class="vbg-context">자료의 출처와 주의해서 읽어야 할 점을 적는다.</p>
        </div>
        <div class="vbg-opening-proof">결론을 뒷받침하는 자료</div>
      </section>
      <section class="vbg-section" aria-labelledby="h-1">
        <h2 id="h-1" class="vbg-heading-24">이어서 알아야 할 내용</h2>
        <p>제목의 내용을 설명한다.</p>
      </section>
    </main>
    <footer class="vbg-footer">
      <span class="vbg-identity"><span>브랜드명</span></span>
      <span class="vbg-sources">출처</span>
    </footer>
  </div>
</div>
```

예시의 브랜드명, 문서 정보, 본문은 실제 자료로 바꾼다. 머리말 오른쪽에는 받는 사람이나 날짜처럼 확인된 정보를 최대 두 개까지 적는다. 없는 정보는 생략한다.

마지막에는 결론이 무엇을 뜻하는지, 다음에 무엇을 해야 하는지, 아직 무엇을 결정하지 못했는지 중 자료에 맞는 내용을 적는다. 짧은 제목과 한 문단으로 다음 행동을 안내할 때는 `vbg-next-step`을 쓸 수 있다.

각 요소를 어떻게 넣어야 하는지는 [사용할 수 있는 CSS 클래스와 변수](vbg-api.md)에서 확인한다. 게시 도구가 `<html>`, `<head>`, `<body>`를 자동으로 붙이는지는 [HTML 파일 만들기와 게시하기](delivery.md)를 참고한다.
