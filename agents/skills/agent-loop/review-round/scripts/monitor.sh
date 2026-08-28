#!/usr/bin/env bash
# Prints a periodic progress digest while local Claude and Codex reviews inspect the same pinned head.
#
#   usage: monitor.sh <issue-number> <round> \
#            <claude-jsonl> <claude-done> <codex-jsonl> <codex-done>
#
# Exits after both .done files exist. Each background wrapper writes its process exit code even when
# the reviewer fails. If a wrapper is killed before writing its .done (orphaned monitor), the
# REVIEW_MAX_SECONDS cap still ends the loop: exit 124 means the reviews outran the cap.
set -u

N="$1"; K="$2"; CLAUDE_JSONL="$3"; CLAUDE_DONE="$4"
CODEX_JSONL="$5"; CODEX_DONE="$6"

TICK_SECONDS="${REVIEW_TICK_SECONDS:-180}"
POLL_SECONDS="${REVIEW_POLL_SECONDS:-5}"
MAX_SECONDS="${REVIEW_MAX_SECONDS:-3600}"
POLLS_PER_TICK=$((TICK_SECONDS / POLL_SECONDS))

CLAUDE_TOOL='select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")'

count_claude_tools() {
  jq -r "$CLAUDE_TOOL | .name" "$CLAUDE_JSONL" 2>/dev/null | wc -l | tr -d ' '
}

count_claude_agents() {
  jq -r "$CLAUDE_TOOL | select(.name==\"Task\" or .name==\"Agent\") | .name" \
    "$CLAUDE_JSONL" 2>/dev/null | wc -l | tr -d ' '
}

last_claude_tool() {
  jq -r "$CLAUDE_TOOL | .name + \" \" + ((.input.file_path // .input.pattern // .input.command // \"\") | tostring)" \
    "$CLAUDE_JSONL" 2>/dev/null | tail -1 | cut -c1-60
}

count_codex_items() {
  jq -r 'select(.type=="item.completed") | .item.type' "$CODEX_JSONL" 2>/dev/null \
    | wc -l | tr -d ' '
}

last_codex_item() {
  jq -r '
    select(.type=="item.started" or .type=="item.completed")
    | .item
    | .type + " " + ((.command // .name // "") | tostring)
  ' "$CODEX_JSONL" 2>/dev/null | tail -1 | cut -c1-60
}

elapsed=0
while true; do
  for _ in $(seq "$POLLS_PER_TICK"); do
    if [ -f "$CLAUDE_DONE" ] && [ -f "$CODEX_DONE" ]; then
      break
    fi
    sleep "$POLL_SECONDS"
  done

  if [ -f "$CLAUDE_DONE" ] && [ -f "$CODEX_DONE" ]; then
    echo "[리뷰 #${N} r${K}] 종료 Claude exit=$(cat "$CLAUDE_DONE") · Codex exit=$(cat "$CODEX_DONE") · Claude 도구 $(count_claude_tools)회/서브에이전트 $(count_claude_agents) · Codex 작업 $(count_codex_items)회"
    break
  fi

  elapsed=$((elapsed + TICK_SECONDS))
  if [ "$elapsed" -ge "$MAX_SECONDS" ]; then
    echo "[리뷰 #${N} r${K}] 제한 시간 ${MAX_SECONDS}초 초과 — 모니터 중단 (exit 124)"
    exit 124
  fi
  echo "[리뷰 #${N} r${K}] $((elapsed / 60))분 경과 · Claude $(count_claude_tools)회/서브에이전트 $(count_claude_agents) · Codex $(count_codex_items)회 · 최근 Claude: $(last_claude_tool) · Codex: $(last_codex_item)"
done
