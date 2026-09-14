# Claude에서 엔진 실행

공통 workflow의 준비를 마친 뒤 **공동 러너 하나**를 백그라운드 Bash로 실행한다. nested CLI stdin은 러너가 분리한다.

```bash
Bash(run_in_background: true):
  bash ~/.agents/skills/agent-loop/review-round/scripts/run-reviewers.sh \
    <worktree> <N> <K> "$COMPARISON_REF" "$ROUND_BASE" \
    "$CODEX_MODEL" "$EFFORT" <scratch> <normalized-Claude-args...> <PR>
```

scratch는 `mktemp -d`로 이번 실행에 새로 만들고 경로를 유지한다. foreground 도구 한도를 넘을 수 있으므로 백그라운드 완료 알림으로 공통 workflow의 결과 처리를 재개한다. 중복 러너나 두 번째 엔진을 시작하지 않는다.

자동 완료 알림이 없는 런타임이면 기존 `Monitor`로 `scripts/monitor.sh`에 두 JSONL·done 경로를 전달해 완료를 알리게 한다. 알림이 오면 원래 러너의 종료와 두 엔진 결과를 확인하고 이어간다. 단순한 채팅 종료를 라운드 완료로 보고하지 않는다.

Codex 진입점은 `exec_command` 세션을 기다리고, 이 진입점은 Claude의 백그라운드 완료 알림을 사용한다. 판단·수정·게시 규칙은 동일한 workflow를 따른다.
