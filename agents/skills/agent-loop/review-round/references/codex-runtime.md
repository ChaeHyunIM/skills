# Codex에서 리뷰 실행하기

공통 진행 방법의 준비를 마친 뒤 실행한다. 같은 실행 스크립트를 두 번 띄우지 않는다.

```bash
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/review-round-<N>-r<K>.XXXXXX")
bash ~/.agents/skills/agent-loop/review-round/scripts/run-reviewers.sh \
  <worktree> <N> <K> "$COMPARISON_REF" "$ROUND_BASE" \
  "$CODEX_MODEL" "$EFFORT" "$SCRATCH" <normalized-Claude-args...> <PR>
```

- 별도로 실행하는 CLI에 네트워크 접근이나 사용자 CLI 상태를 기록할 권한이 필요하면, 이 실행 명령에 한해서 sandbox 권한 확대를 요청한다. 리뷰하는 Codex의 셸은 read-only sandbox를 유지한다.
- `exec_command`는 짧은 초기 대기 시간으로 시작한다. `session_id`가 돌아오면 같은 세션을 `write_stdin`으로 30초 간격으로 기다리고, 의미 있는 진행이 있을 때 알린다. 끝나면 같은 턴에서 공통 진행 방법의 결과 처리로 이어간다.
- 스크립트는 두 리뷰어의 JSONL 로그, 오류 출력, 결과 파일, 완료 표시를 남기고 요약을 출력한다. 기본 제한 시간인 3600초를 넘으면 실패다. 실패한 리뷰어를 자동으로 다시 실행하지 않는다.
