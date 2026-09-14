# Codex에서 엔진 실행

공통 workflow의 준비를 마친 뒤 실행한다. 같은 러너를 두 번 띄우지 않는다.

```bash
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/review-round-<N>-r<K>.XXXXXX")
bash ~/.agents/skills/agent-loop/review-round/scripts/run-reviewers.sh \
  <worktree> <N> <K> "$COMPARISON_REF" "$ROUND_BASE" \
  "$CODEX_MODEL" "$EFFORT" "$SCRATCH" <normalized-Claude-args...> <PR>
```

- nested CLI의 네트워크와 사용자 CLI 상태 쓰기가 필요하면 이 러너 호출만 sandbox escalation을 요청한다. nested Codex 셸의 read-only sandbox는 유지한다.
- `exec_command`의 짧은 초기 yield로 시작한다. `session_id`가 있으면 같은 세션을 `write_stdin`으로 30초 간격으로 기다리고 유의미한 진행을 알린다. 끝나면 같은 턴에서 공통 workflow의 결과 처리로 이어간다.
- 러너는 두 JSONL·stderr·결과·done을 기록하고 digest를 출력한다. 기본 3600초 제한 초과는 실패다. 실패한 엔진을 자동 재시도하지 않는다.
