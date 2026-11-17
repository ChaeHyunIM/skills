#!/usr/bin/env bash
# 저장소의 .agents/agent-loop/config를 읽는 함수들. 이 파일은 source해서 사용한다.
#
#   agent_loop_load_config <checkout-dir>   config를 source하고 AGENT_LOOP_CONFIG에 파일 경로를 저장한다.
#   require_config <KEY>...                 값이 비어 있는 키가 있으면 78을 반환한다.
#   app_value <app> <PREFIX>                PREFIX_<app> 값을 출력한다. 앱 이름의 -는 _로 바꾼다.
#
# worktree에 config가 없으면 메인 체크아웃의 파일을 쓴다.
# 예전 위치 .claude/agent-loop/config도 읽되, 옮기라고 경고한다.

agent_loop_load_config() {
  local dir=${1:-.} root main f
  root=$(git -C "$dir" rev-parse --show-toplevel) || return 78
  main=$(git -C "$root" worktree list --porcelain | sed -n '1s/^worktree //p')
  for f in "$root/.agents/agent-loop/config" "$main/.agents/agent-loop/config" \
           "$root/.claude/agent-loop/config" "$main/.claude/agent-loop/config"; do
    if [ -f "$f" ]; then
      case $f in */.claude/*) echo "WARN: $f is the legacy location — move it to .agents/agent-loop/config" >&2 ;; esac
      # shellcheck disable=SC1090
      . "$f"
      AGENT_LOOP_CONFIG=$f
      return 0
    fi
  done
  echo "missing $root/.agents/agent-loop/config — copy $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/config.example and configure it for this project" >&2
  return 78
}

require_config() {
  local k
  for k in "$@"; do
    [ -n "${!k:-}" ] || { echo "$k is missing or empty in $AGENT_LOOP_CONFIG" >&2; return 78; }
  done
}

app_value() {
  local name="$2_${1//-/_}"
  printf '%s' "${!name:-}"
}
