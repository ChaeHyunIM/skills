#!/usr/bin/env bash
# Runs and extracts one subscription-backed local Codex review for a pinned branch head.
#
#   preflight <model> <effort>
#   run       <worktree> <comparison-ref> <head> <model> <effort> <result-path>
#   extract   <result-path> <head> <model> <effort>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEMA="$SCRIPT_DIR/../references/codex-findings.schema.json"

usage() {
  echo "usage: codex-review.sh <preflight|run|extract> ..." >&2
  exit 64
}

assert_head() {
  local worktree="$1" expected="$2" actual
  actual=$(git -C "$worktree" rev-parse HEAD)
  if [ "$actual" != "$expected" ]; then
    echo "Worktree head moved during Codex review: expected=$expected actual=$actual" >&2
    exit 4
  fi
}

preflight() {
  local model="$1" effort="$2" login_status

  command -v codex >/dev/null || { echo "codex CLI is not installed" >&2; exit 69; }
  command -v jq >/dev/null || { echo "jq is not installed" >&2; exit 69; }

  if [ -n "${CODEX_API_KEY:-}" ] || [ -n "${OPENAI_API_KEY:-}" ]; then
    echo "API key environment variable is set; refusing subscription-backed Codex review" >&2
    exit 78
  fi

  login_status=$(codex login status 2>&1 || true)
  if ! grep -Fq "Logged in using ChatGPT" <<<"$login_status"; then
    echo "Codex CLI is not logged in using ChatGPT" >&2
    exit 77
  fi

  if ! codex debug models --bundled 2>/dev/null | jq -e \
    --arg model "$model" --arg effort "$effort" '
      any(.models[];
        .slug == $model and
        any(.supported_reasoning_levels[]?; .effort == $effort)
      )
    ' >/dev/null; then
    echo "Unsupported Codex model/effort: $model/$effort" >&2
    exit 64
  fi

  jq -e . "$SCHEMA" >/dev/null
}

run_review() {
  local worktree="$1" comparison_ref="$2" head="$3" model="$4" effort="$5" result_path="$6"
  local prompt

  preflight "$model" "$effort"
  assert_head "$worktree" "$head"

  prompt="\$review-agent Review the base-branch change that would merge from the current HEAD into ${comparison_ref}. Follow the skill's review criteria and inspect the complete diff. Use the supplied output schema instead of the skill's prose result format."

  # codex exec appends piped stdin as a <stdin> block and reads it to EOF. Under a harness exec
  # session the inherited stdin pipe never closes, so detach it or the review hangs before starting.
  codex exec \
    --cd "$worktree" \
    --ephemeral \
    --json \
    --model "$model" \
    --config "model_reasoning_effort=\"$effort\"" \
    --sandbox read-only \
    --output-schema "$SCHEMA" \
    --output-last-message "$result_path" \
    "$prompt" </dev/null

  assert_head "$worktree" "$head"
}

extract() {
  local result_path="$1" head="$2" model="$3" effort="$4"

  jq -e '
    .level == "codex" and
    (.findings | type == "array") and
    all(.findings[];
      (.file | type == "string") and
      (.line | type == "number") and .line >= 1 and (.line | floor) == .line and
      (.summary | type == "string") and
      (.short_summary | type == "string") and (.short_summary | length) >= 1 and (.short_summary | length) <= 60 and
      (.failure_scenario | type == "string") and
      (.category | IN("P0", "P1", "P2", "P3"))
    )
  ' "$result_path" >/dev/null || {
    echo "Codex result does not match the findings contract" >&2
    exit 3
  }

  jq -c \
    --arg head "$head" \
    --arg model "$model" \
    --arg effort "$effort" '
      . + {
        reviewed_head: $head,
        model: $model,
        effort: $effort,
        findings: [.findings[] + {source: "Codex"}]
      }
    ' "$result_path"
}

[ "$#" -ge 1 ] || usage
command="$1"
shift

case "$command" in
  preflight)
    [ "$#" -eq 2 ] || usage
    preflight "$@"
    ;;
  run)
    [ "$#" -eq 6 ] || usage
    run_review "$@"
    ;;
  extract)
    [ "$#" -eq 4 ] || usage
    extract "$@"
    ;;
  *)
    usage
    ;;
esac
