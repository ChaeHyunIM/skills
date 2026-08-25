#!/usr/bin/env bash
# Prints a periodic one-line progress digest for the nested `claude -p` review.
# A nested session has no TUI, so /code-review's progress tree is invisible; this replaces it.
# It reads the JSONL with shell alone, so polling costs no model turns.
#
#   usage: monitor.sh <issue-number> <round> <jsonl-path> <done-path>
#
# Exits as soon as the .done file appears. A crashed review also writes .done (with a non-zero
# code), so the monitor never goes silent on failure.
#
# Progress lines are user-facing, so they are written in Korean (CONTRACT output convention).
set -u

N="$1"; K="$2"; J="$3"; D="$4"

# 3 minutes between progress lines. A round usually runs 10-40 minutes; more often is noise,
# less often reads as hung.
TICK_SECONDS=180
# 5 seconds between .done re-checks, so the closing line is at most 5s late.
POLL_SECONDS=5
POLLS_PER_TICK=$((TICK_SECONDS / POLL_SECONDS))

# Shared filter: tool_use blocks inside assistant events.
TU='select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")'

# Every jq call discards stderr: the file is being appended to while it is read, so the last line
# is often half-written. jq still emits everything it parsed before that point, which undercounts
# by at most one call — irrelevant for a progress line.
count_tools() { jq -r "$TU | .name" "$J" 2>/dev/null | wc -l | tr -d ' '; }
count_agents() { jq -r "$TU | select(.name==\"Task\" or .name==\"Agent\") | .name" "$J" 2>/dev/null | wc -l | tr -d ' '; }
last_tool() {
  jq -r "$TU | .name + \" \" + ((.input.file_path // .input.pattern // .input.command // \"\") | tostring)" \
    "$J" 2>/dev/null | tail -1 | cut -c1-80
}

elapsed=0
while true; do
  for _ in $(seq "$POLLS_PER_TICK"); do
    [ -f "$D" ] && break
    sleep "$POLL_SECONDS"
  done

  if [ -f "$D" ]; then
    echo "[리뷰 #${N} r${K}] 종료 exit=$(cat "$D") · 도구 $(count_tools)회 · 서브에이전트 $(count_agents)"
    break
  fi

  elapsed=$((elapsed + TICK_SECONDS))
  echo "[리뷰 #${N} r${K}] $((elapsed / 60))분 경과 · 도구 $(count_tools)회 · 서브에이전트 $(count_agents) · 최근: $(last_tool)"
done
