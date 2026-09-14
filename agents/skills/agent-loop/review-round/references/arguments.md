# 리뷰 실행 옵션

첫 인자는 티켓 번호다. 사용자가 한 번 호출하면 두 리뷰어를 각각 한 번 실행한다. 자동 재시도하지 않는다.

## 모델과 effort 정하기

`review-round/settings.json`의 기본값은 둘 다 `inherit`다. 리뷰를 호출할 때마다 그 Codex 세션의 모델과 effort를 가져온다. 스킬을 수정하던 세션이나 이전 라운드의 값을 저장해 재사용하지 않는다.

각 값은 이번 호출에 명시한 옵션, 사용자가 settings에 지정한 값, 현재 세션의 값 순서로 정한다. `--codex-model <model>`은 모델만, 첫 effort 인자는 effort만 바꾼다. 지정하지 않은 나머지 값은 상속한다.

```bash
RESOLVED=$(python3 ~/.agents/skills/agent-loop/review-round/scripts/resolve-settings.py) || exit $?
CODEX_MODEL=$(printf '%s' "$RESOLVED" | jq -r .codexModel)
EFFORT=$(printf '%s' "$RESOLVED" | jq -r .effort)
```

사용자가 지정한 경우에만 위 스크립트에 `--codex-model <model>`·`--effort <effort>`를 추가한다. 입력은 인자 배열로 전달한다. 출력의 `sources`에서 값이 어디서 왔는지 확인하고, 정한 모델과 effort를 리뷰 실행과 결과 추출에 똑같이 사용한다. 다음 라운드는 새로 조회한다.

스크립트는 `CODEX_THREAD_ID`가 가리키는 Codex 세션을 상태 DB에서 읽기 전용으로 확인한다. 없으면 `CODEX_SESSION_ID`를 쓴다. 구형 저장소에서는 같은 세션 ID의 rollout 파일에서 마지막 `turn_context`를 읽는다. 세션 정보를 못 찾았다고 전역 config나 다른 세션의 마지막 설정을 현재 값으로 사용하지 않는다.

Claude에서 호출하는 등 현재 Codex 세션이 없으면, 이번 세션에서 사용자가 정한 Codex 모델과 effort를 명시 인자로 전달한다. 정한 값이 없을 때만 빠진 값을 묻는다. Claude 모델명을 보고 Codex 모델을 추측하지 않는다.

## 두 리뷰어에 옵션 전달하기

- 정한 effort가 `low`·`medium`·`high`·`xhigh`·`max`이면 양쪽에 사용한다. `/code-review`가 경로로 잘못 읽지 않도록 Claude 인자 첫 토큰에도 effort를 넣는다. `--codex-model`은 Claude에 넘기지 않는다.
- 상속하거나 지정한 effort를 두 리뷰어가 함께 지원하지 않으면 어느 쪽도 시작하지 않고 지원되는 값을 요청한다. `ultra`는 Claude의 별도 클라우드 리뷰 방식이 필요하다. 값을 생략했다고 medium 등으로 자동으로 낮추지 않는다.
- `--fix`·`--comment`는 빼고 사용자에게 알린다. 지적을 처리하고 코멘트를 올리는 일은 리뷰 결과를 받은 에이전트가 맡는다.
- 나머지 Claude 인자는 배열로 유지한다. 실제 PR의 base를 비교하도록 마지막에 PR 번호를 붙인다.

## 실행 전 확인

`codex-review.sh preflight "$CODEX_MODEL" "$EFFORT"`로 로그인과 실행 준비를 확인한다.

- ChatGPT로 로그인했고 API 키 환경 변수가 설정돼 있지 않은지 확인한다. 결과 스키마와 현재 CLI 모델 목록도 확인한다.
- 번들 모델 목록만 읽도록 `--bundled`를 붙이지 않는다. 목록에 있는 모델이 해당 effort를 지원하지 않으면 실행 전에 거부한다.
- 앱에서 쓰는 모델이 CLI 목록에 없을 수도 있다. 목록에 없다는 사실은 알리되 정한 모델을 그대로 한 번 실행한다. 서버가 거부하면 실패로 남기고 모델을 바꾸거나 자동 재시도하지 않는다.
- `COMPARISON_REF`에는 fetch한 PR base의 고정 SHA를 넣는다. 실행 중 움직일 수 있는 브랜치 이름으로 비교 범위를 다시 고르지 않는다. 리뷰 중 원격 PR의 head나 base가 달라졌으면 결과를 반영하기 전에 해당 라운드를 중단한다.
