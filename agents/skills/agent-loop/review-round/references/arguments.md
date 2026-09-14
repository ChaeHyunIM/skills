# 리뷰 실행 인자

첫 인자는 티켓 번호다. 리뷰는 명시 호출당 두 엔진 각각 한 번이며 자동 재시도하지 않는다.

## 모델과 effort

`review-round/settings.json`의 기본값은 둘 다 `inherit`다. **리뷰를 호출하는 매 세션에서 실행 시점의 모델·effort를 읽는다.** 스킬을 수정한 세션의 값이나 이전 라운드의 값을 저장해 재사용하지 않는다.

값별 우선순위는 이번 호출의 명시 인자 → 사용자가 settings에 지정한 값 → 현재 세션 상속이다. `--codex-model <model>`은 모델만, 첫 effort 인자는 effort만 덮어쓴다. 생략한 나머지 값은 상속한다.

```bash
RESOLVED=$(python3 ~/.agents/skills/agent-loop/review-round/scripts/resolve-settings.py) || exit $?
CODEX_MODEL=$(printf '%s' "$RESOLVED" | jq -r .codexModel)
EFFORT=$(printf '%s' "$RESOLVED" | jq -r .effort)
```

명시 인자가 있을 때만 resolver에 `--codex-model <model>`·`--effort <effort>`를 추가한다. 사용자 입력은 인자 배열로 전달한다. resolver의 `sources`로 값별 출처를 확인하고, 확정한 모델·effort를 러너와 결과 추출에 동일하게 넘긴다. 다음 라운드에서는 다시 조회한다.

resolver는 `CODEX_THREAD_ID`(없으면 `CODEX_SESSION_ID`)에 정확히 대응하는 Codex 상태 DB를 읽기 전용으로 조회한다. 구형 저장소는 같은 ID의 rollout에서 마지막 `turn_context`를 읽는다. 세션 정보가 없으면 전역 config나 마지막으로 쓴 다른 세션을 현재 값으로 간주하지 않는다. Claude에서 호출하는 등 현재 Codex 세션이 없으면 이 세션에서 사용자가 정한 Codex 모델·effort를 명시 인자로 전달하고, 정한 값이 없을 때만 누락한 값을 묻는다. Claude 모델명을 Codex 모델로 바꾸어 추측하지 않는다.

## 엔진 인자와 실행 범위

- 확정한 effort가 `low`·`medium`·`high`·`xhigh`·`max`이면 양쪽에 사용한다. Claude 인자 첫 토큰에도 명시하여 `/code-review`가 경로로 해석하지 않게 한다. `--codex-model`은 Claude에 넘기지 않는다.
- 상속하거나 명시한 effort가 두 엔진 공통 범위 밖이면 어느 엔진도 시작하지 않고 지원되는 effort를 요청한다. `ultra`에는 Claude의 별도 클라우드 리뷰 경로가 필요하다. 생략된 값을 medium 등으로 자동 하향하지 않는다.
- `--fix`·`--comment`는 제거하고 알린다. finding 처분과 게시 주체는 바깥 루프다.
- 나머지 Claude 인자는 배열로 유지한다. 마지막에 **PR 번호**를 붙여 실제 PR base를 비교 대상으로 사용하게 한다.
- `codex-review.sh preflight "$CODEX_MODEL" "$EFFORT"`는 ChatGPT 로그인, API 키 환경 변수 부재, 결과 스키마와 현재 CLI 모델 목록을 확인한다. `--bundled`로 제한하지 않는다. 목록에 있는 모델의 미지원 effort는 실행 전에 거부한다. 앱의 모델이 CLI 목록에 없을 수 있으므로 목록 부재는 알리되 확정한 모델을 그대로 한 번 실행한다. 서버가 거부하면 라운드 실패로 남기고 모델 교체·자동 재시도는 하지 않는다.
- `COMPARISON_REF`는 fetch한 PR base의 **고정 SHA**다. 움직이는 branch 이름으로 리뷰 범위를 다시 고르지 않는다. 리뷰 중 remote PR head/base가 바뀌면 해당 라운드를 적용 전에 중단한다.
