#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEMA="$SCRIPT_DIR/../references/codex-findings.schema.json"

usage() {
  echo "usage: codex-review.sh <preflight|run|extract> ..." >&2
  exit 64
}

assert_head() {
  bash "$SCRIPT_DIR/../../scripts/check-worktree.sh" "$1" "$2" >/dev/null
}

preflight() {
  local model="$1" effort="$2" login_status catalog

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

  if ! catalog=$(codex debug models); then
    echo "Could not read the Codex model catalog" >&2
    exit 69
  fi
  if ! jq -e '.models | type == "array"' <<<"$catalog" >/dev/null; then
    echo "Invalid Codex model catalog" >&2
    exit 69
  fi
  # CLI 목록은 앱에서 사용 가능한 모델을 빠뜨릴 수 있어 부재만으로 지원 불가를 단정하지 않는다.
  if ! jq -e --arg model "$model" 'any(.models[]; .slug == $model)' <<<"$catalog" >/dev/null; then
    echo "Model absent from CLI catalog: $model; keeping the requested model for the single review attempt" >&2
  elif ! jq -e --arg model "$model" --arg effort "$effort" '
      any(.models[];
        .slug == $model and
        any(.supported_reasoning_levels[]?; .effort == $effort)
      )
    ' <<<"$catalog" >/dev/null; then
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

  # 실행 환경이 stdin 파이프를 닫지 않으면 Codex가 EOF를 기다리므로 입력을 분리한다.
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
