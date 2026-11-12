# PR 본문 규칙의 배경

[write-pr](../SKILL.md)의 규칙을 왜 만들었는지 적은 문서다. 규칙을 다시 살펴봐야 할 때만 읽는다.

**같은 내용의 섹션이 PR마다 다른 이름으로 쓰였고, 본문 대부분이 코드를 다시 설명했다.**

- 확인한 사실(2026-09-18): doko-monorepo PR 200개(2026-07-27 ~ 09-17)를 읽었다. 변경 내용 섹션은 `변경`·`구현`·`무엇이 달라지나`·`한 일` 등 20가지가 넘는 이름으로 쓰였고, 헤딩이 없는 본문도 34개였다. 마이그레이션은 61개, 배포 순서는 26개 PR에서 언급됐지만 위치가 정해져 있지 않았다. 본문 길이 중앙값은 약 1,700자였다. PR #383의 구현 설명 한 문단은 `packages/core/src/modules/gift-shop/repository.ts`의 주석과 같은 내용이었다.
- 현재 규칙: PR 본문은 사람이 읽는다. 에이전트는 코드베이스에서 맥락을 얻으므로 코드로 알 수 있는 내용은 본문에 쓰지 않는다. 섹션 이름을 고정하고, 배포 영향은 "없음"이라도 반드시 채운다.
- 다시 확인할 상황: 리뷰어가 본문만으로 판단하지 못해 diff 설명을 따로 요청하는 일이 반복되면 `리뷰 포인트`의 기준을 다시 본다.

**이미지 표시는 Chrome이 아니라 ImageMagick으로 그린다.**

- 확인한 사실(2026-11-12): 처음에는 이미지 위에 SVG를 얹은 HTML을 headless Chrome으로 찍었다. Claude Code에서는 됐지만, `codex exec --sandbox workspace-write` 안에서는 Chrome이 시작하자마자 `SIGABRT`(exit 134)로 죽었다. `codex sandbox`로 재현해 `--no-sandbox`, `--single-process`, `--disable-features=MachPortRendezvous`를 각각 붙여 봐도 같았다. 같은 샌드박스에서 ImageMagick은 정상으로 그렸고, Claude Code와 Codex의 출력은 픽셀 단위로 같았다.
- 현재 규칙: `scripts/annotate.mjs`는 Node와 ImageMagick만 쓴다. 화살촉 좌표는 스크립트가 계산해 ImageMagick에는 도형만 넘긴다.
- 다시 확인할 상황: Codex 샌드박스가 Mach 통신을 허용하거나, 표시에 글꼴·그림자처럼 ImageMagick으로 그리기 어려운 요소가 필요해질 때.
