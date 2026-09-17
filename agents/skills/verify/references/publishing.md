# PR에 검증 결과 적기

`implement`와 `verify`가 함께 사용한다. 결과의 판단 기준과 재사용 방법은 [공통 검증 규칙](../../agent-loop/references/verification.md)을 따른다.

1. 완료 조건 원문과 판정·근거, 검증한 커밋의 전체 SHA와 환경을 `results.json`에 적는다. UI 기록물은 해당 항목의 `media`에 넣는다: 새 화면 `image` + `video`, 기존 화면 변경 `pair`, 흐름 추가·변경 `video`. 형식은 [evidence-block.mjs](../scripts/evidence-block.mjs) 첫 주석을 따른다.
2. 기존 PR을 고칠 때는 최신 본문을 파일로 읽는다. PR head와 완료 조건이 검증할 때와 같은지 확인한다. 새 PR은 티켓 연결 정보, 구현 설명, 검증 결과를 함께 준비한다.
3. 아래 스크립트로 본문을 만든다. 검증 마커 밖의 글은 그대로 둔다. 중복된 섹션이나 마커가 있어 어느 쪽인지 모호하면 임의로 지우지 않는다.

```bash
node ~/.agents/skills/verify/scripts/evidence-block.mjs --results <results.json> --body-file <latest-body.md> > <next-body.md>
```

4. 새 PR은 구현을 마친 `implement`에서 만든다. 기존 PR은 `gh pr edit <PR> --body-file <next-body.md>`로 갱신한다. 저장 직전에 읽은 본문이 달라졌으면 최신 본문에 결과를 반영한다.
5. 게시 후 본문과 head를 다시 읽고 첨부가 열리고 재생되는지 확인한다. 다른 글을 보존하고 PR에 로컬 경로를 남기지 않는다. 다른 사람도 편집 중이면 준비한 결과를 보존하고 해당 저장만 보류한다.

[조건별 필수 기록물](routes.md)을 빠짐없이 연결하되 같은 파일은 재사용한다.

`gh pr edit --help`로 `--attach` 지원 여부를 확인한다. 지원하면 `evidence-block.mjs --results <file> --attach-list`에서 출력한 파일을 첨부한다.

지원하지 않으면 사용 가능한 승인된 첨부 수단을 확인한다. 첨부가 막히면 PR에는 결과·재현 방법·`PR 첨부 미완료: <원인>`을 적고, 채팅에는 로컬 기록물을 미리보기나 열리는 파일 링크로 제공한다. PR에 로컬 경로를 게시하지 않는다. `--no-publish`·로컬 검증은 로컬 전달로 마친다.

영상은 본문에서 별도 줄에 둔다. 변경 전후 영상을 나란히 놓아야 하면 [Playwright 문서의 첨부 방법](web-playwright.md)을 읽는다. 공개 이미지 호스트에 대신 올리거나 인증 정보와 실제 사용자 데이터를 노출하지 않는다.
