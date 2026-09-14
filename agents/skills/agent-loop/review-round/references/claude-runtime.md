# Claude에서 리뷰 실행하기

공통 진행 방법의 준비를 마친 뒤 두 리뷰어를 함께 실행하는 스크립트 하나를 백그라운드 Bash로 시작한다. 별도로 실행하는 CLI가 입력을 기다리지 않도록 스크립트에서 stdin을 분리한다.

```bash
Bash(run_in_background: true):
  bash ~/.agents/skills/agent-loop/review-round/scripts/run-reviewers.sh \
    <worktree> <N> <K> "$COMPARISON_REF" "$ROUND_BASE" \
    "$CODEX_MODEL" "$EFFORT" <scratch> <normalized-Claude-args...> <PR>
```

임시 폴더는 `mktemp -d`로 이번 실행에 새로 만들고 경로를 기억한다. 도구가 앞에서 기다릴 수 있는 시간을 넘길 수 있으므로 백그라운드 완료 알림을 받은 뒤 결과 처리를 이어간다. 기다리는 중에 실행 스크립트나 리뷰어를 하나 더 시작하지 않는다.

자동 완료 알림이 없는 환경에서는 기존 `Monitor`로 `scripts/monitor.sh`를 실행한다. 두 리뷰어의 JSONL 로그와 완료 표시(done) 파일 경로를 전달해 끝났을 때 알리도록 한다. 알림을 받으면 원래 스크립트가 종료됐는지와 두 결과를 확인하고 이어간다. 채팅 응답이 끝났다는 이유만으로 리뷰가 완료됐다고 보고하지 않는다.

Codex에서는 `exec_command` 세션을 기다리고, Claude에서는 백그라운드 완료 알림을 사용한다. 이후 판단, 수정, 게시 방법은 같다.
