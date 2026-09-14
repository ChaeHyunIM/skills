# 검증 기록 게시

`implement`와 `verify`가 공유한다. 결과의 의미·재사용은 `agent-loop/references/verification.md`를 따른다.

1. 모든 조건의 원문·판정·근거를 `results.json`에 적는다. 스키마는 `scripts/evidence-block.mjs` 머리말에 있다. 실제 full commit과 환경을 기록한다.
2. PR을 갱신할 때는 최신 본문을 파일로 받고 head·조건이 실행 대상과 여전히 일치하는지 확인한다. 새 PR의 본문은 바인딩·구현 설명과 결과를 함께 준비한다.
3. 아래 헬퍼로 렌더한다. 검증 마커 밖은 그대로 보존한다. 모호한 중복 섹션·마커를 임의로 지우지 않는다.

```bash
node ~/.agents/skills/verify/scripts/evidence-block.mjs --results <results.json> --body-file <latest-body.md> > <next-body.md>
```

4. 새 PR은 구현이 끝난 `implement`가 생성한다. 기존 PR은 `gh pr edit <PR> --body-file <next-body.md>`로 갱신한다. 저장 직전 읽은 본문이 달라졌으면 최신 본문에 다시 결합한다.
5. 게시 뒤 본문·head를 읽어 다른 글이 보존됐는지, 로컬 매체 경로가 남지 않았는지 확인한다. 동시 편집이 발견되면 결과를 보존하고 그 쓰기만 멈춘다.

매체는 조건을 설명하는 데 필요한 것만 붙인다. `gh pr edit --help`로 현재 `--attach` 지원을 확인하고, 지원하면 `evidence-block.mjs --results <file> --attach-list`의 파일을 첨부한다. 미지원이면 매체 없는 텍스트 블록에 재현 방법을 적고 로컬 산출물 위치를 보고한다. 링크가 깨질 로컬 경로를 PR에 게시하지 않는다.

영상은 자기 줄에 둔다. before/after 영상 표가 필요한 경우의 GitHub 첨부 절차는 `web-playwright.md`를 읽는다. 공개 이미지 호스트로 우회하거나 인증·실사용자 데이터를 노출하지 않는다.
