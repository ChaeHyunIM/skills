#!/usr/bin/env bash
set -euo pipefail

N="${1:?usage: prepare-worktree.sh <issue-number> <slug> [base-branch]}"
SLUG="${2:?slug required}"
BASE="${3:-}"

[[ "$N" =~ ^[A-Za-z0-9-]+$ ]] || { echo "invalid issue identifier" >&2; exit 64; }
[[ "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "slug must use lowercase ASCII words and hyphens" >&2; exit 64; }
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LOOP="$SCRIPT_DIR/../../agent-loop/scripts"
CHECK="$LOOP/check-worktree.sh"
. "$LOOP/load-config.sh"

ROOT=$(git rev-parse --show-toplevel)
agent_loop_load_config "$ROOT"
WT="$ROOT/.claude/worktrees/issue-$N-$SLUG"
BRANCH="agent/issue-$N-$SLUG"

if [ -d "$WT" ]; then
  bash "$CHECK" "$WT" >/dev/null
  [ "$(git -C "$WT" symbolic-ref --quiet --short HEAD)" = "$BRANCH" ] || { echo "existing worktree is on another branch" >&2; exit 3; }
  if git -C "$WT" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    [ "$(git -C "$WT" rev-list --count "origin/$BRANCH..HEAD")" = 0 ] || { echo "existing worktree has local-only commits" >&2; exit 3; }
  fi
  echo "worktree exists — reusing: $WT"
else
  git -C "$ROOT" fetch origin
  if [ -n "$BASE" ]; then
    git -C "$ROOT" worktree add "$WT" -b "$BRANCH" "$BASE"
  else
    git -C "$ROOT" worktree add "$WT" "$BRANCH"
  fi
fi

bash "$CHECK" "$WT" >/dev/null

if [ -n "${INSTALL_CMD:-}" ]; then
  (cd "$WT" && eval "$INSTALL_CMD")
else
  echo "INSTALL_CMD is empty in $AGENT_LOOP_CONFIG; dependencies were not installed" >&2
fi

# gitignore된 생성 파일은 새 worktree에 없으므로 메인 체크아웃에서 복사한다.
copied=0
for pattern in ${COPY_FROM_MAIN:-}; do
  for src in "$ROOT"/$pattern; do
    [ -f "$src" ] || continue
    dst="$WT/${src#"$ROOT"/}"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    copied=$((copied + 1))
  done
done
[ -n "${COPY_FROM_MAIN:-}" ] && [ "$copied" -eq 0 ] && echo "WARN: COPY_FROM_MAIN matched no files in the main checkout — generate the files there first" >&2

echo "ready: $WT (branch $BRANCH); generated files copied: $copied"
