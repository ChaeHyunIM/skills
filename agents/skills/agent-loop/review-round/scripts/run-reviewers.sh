#!/usr/bin/env bash
# Runs Claude and Codex reviewers concurrently for one pinned review round.
#
# usage: run-reviewers.sh <worktree> <issue> <round> <comparison-ref> <head> \
#          <codex-model> <effort> <scratch-dir> [normalized Claude /code-review args...]
set -u

if [ "$#" -lt 8 ]; then
  echo "usage: run-reviewers.sh <worktree> <issue> <round> <comparison-ref> <head> <codex-model> <effort> <scratch-dir> [claude args...]" >&2
  exit 64
fi

WORKTREE="$1"
N="$2"
K="$3"
COMPARISON_REF="$4"
EXPECTED_HEAD="$5"
CODEX_MODEL="$6"
EFFORT="$7"
SCRATCH="$8"
shift 8
CLAUDE_ARGS=("$@")

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_HELPER="$SCRIPT_DIR/codex-review.sh"
MONITOR="$SCRIPT_DIR/monitor.sh"

[ -d "$WORKTREE" ] || { echo "worktree does not exist: $WORKTREE" >&2; exit 66; }
[ -d "$SCRATCH" ] || { echo "scratch directory does not exist: $SCRATCH" >&2; exit 66; }
command -v claude >/dev/null || { echo "claude CLI is not installed" >&2; exit 69; }

bash "$CODEX_HELPER" preflight "$CODEX_MODEL" "$EFFORT" || exit $?

ACTUAL_HEAD="$(git -C "$WORKTREE" rev-parse HEAD)"
if [ "$ACTUAL_HEAD" != "$EXPECTED_HEAD" ]; then
  echo "worktree head changed before review: expected=$EXPECTED_HEAD actual=$ACTUAL_HEAD" >&2
  exit 4
fi

CLAUDE_JSONL="$SCRATCH/review-${N}-r${K}.jsonl"
CLAUDE_ERR="$SCRATCH/review-${N}-r${K}.err"
CLAUDE_DONE="$SCRATCH/review-${N}-r${K}.done"
CODEX_JSONL="$SCRATCH/codex-review-${N}-r${K}.jsonl"
CODEX_RESULT="$SCRATCH/codex-review-${N}-r${K}.json"
CODEX_ERR="$SCRATCH/codex-review-${N}-r${K}.err"
CODEX_DONE="$SCRATCH/codex-review-${N}-r${K}.done"

rm -f "$CLAUDE_JSONL" "$CLAUDE_ERR" "$CLAUDE_DONE" \
  "$CODEX_JSONL" "$CODEX_RESULT" "$CODEX_ERR" "$CODEX_DONE"

CLAUDE_PROMPT="/code-review"
if [ "${#CLAUDE_ARGS[@]}" -gt 0 ]; then
  CLAUDE_PROMPT="$CLAUDE_PROMPT ${CLAUDE_ARGS[*]}"
fi

CLAUDE_PID=""
CODEX_PID=""
terminate_children() {
  [ -z "$CLAUDE_PID" ] || kill "$CLAUDE_PID" 2>/dev/null || true
  [ -z "$CODEX_PID" ] || kill "$CODEX_PID" 2>/dev/null || true
}
trap 'terminate_children; exit 130' INT TERM HUP

(
  set +e
  (
    # claude -p reads piped stdin as extra input; a harness exec session keeps the pipe open
    # forever, so detach stdin the same way the Codex helper does.
    cd "$WORKTREE" &&
      CLAUDE_CODE_REPORT_FINDINGS=1 claude -p "$CLAUDE_PROMPT" \
        --output-format stream-json --verbose </dev/null
  ) >"$CLAUDE_JSONL" 2>"$CLAUDE_ERR"
  code=$?
  printf '%s\n' "$code" >"$CLAUDE_DONE"
  exit "$code"
) &
CLAUDE_PID=$!

(
  set +e
  bash "$CODEX_HELPER" run \
    "$WORKTREE" "$COMPARISON_REF" "$EXPECTED_HEAD" "$CODEX_MODEL" "$EFFORT" "$CODEX_RESULT" \
    >"$CODEX_JSONL" 2>"$CODEX_ERR"
  code=$?
  printf '%s\n' "$code" >"$CODEX_DONE"
  exit "$code"
) &
CODEX_PID=$!

REVIEW_TICK_SECONDS="${REVIEW_TICK_SECONDS:-30}" bash "$MONITOR" "$N" "$K" \
  "$CLAUDE_JSONL" "$CLAUDE_DONE" "$CODEX_JSONL" "$CODEX_DONE"
MONITOR_EXIT=$?

if [ "$MONITOR_EXIT" -eq 124 ]; then
  echo "reviewers exceeded REVIEW_MAX_SECONDS; terminating both" >&2
  terminate_children
  wait "$CLAUDE_PID" 2>/dev/null
  wait "$CODEX_PID" 2>/dev/null
  trap - INT TERM HUP
  exit 124
fi

wait "$CLAUDE_PID"
CLAUDE_WAIT=$?
wait "$CODEX_PID"
CODEX_WAIT=$?
trap - INT TERM HUP

ACTUAL_HEAD="$(git -C "$WORKTREE" rev-parse HEAD)"
if [ "$ACTUAL_HEAD" != "$EXPECTED_HEAD" ]; then
  echo "worktree head moved during review: expected=$EXPECTED_HEAD actual=$ACTUAL_HEAD" >&2
  exit 4
fi

if [ "$CLAUDE_WAIT" -ne 0 ] || [ "$CODEX_WAIT" -ne 0 ]; then
  echo "reviewer failed: Claude=$CLAUDE_WAIT Codex=$CODEX_WAIT" >&2
  exit 1
fi

exit 0
