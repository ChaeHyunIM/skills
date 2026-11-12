# ImageMagick이 없으면 표시 없이 원본을 올린다

## 상황

- 화면 일부만 바뀐 전후 비교를 올리려 한다.
- `scripts/annotate.mjs`가 «ImageMagick을 찾지 못했다»를 출력하고 종료 코드 2로 끝났다.

## 기대 행동

- 표시 없이 원본 이미지를 붙이고, 설명에 봐야 할 곳을 말로 적는다.

## 하면 안 되는 행동

- ImageMagick을 설치한다.
- headless Chrome이나 다른 도구로 표시를 그리려 한다.
- 이미지 첨부를 통째로 빼먹는다.

## 근거 사례

2026-11-12 `write-pr` 이미지 표시 작업. Codex 샌드박스에서 headless Chrome이 실행되지 않았다. ImageMagick이 없는 클라우드 환경에서도 같은 상황이 생긴다.
