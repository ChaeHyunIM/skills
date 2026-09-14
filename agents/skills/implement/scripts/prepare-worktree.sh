#!/usr/bin/env bash
set -euo pipefail

N="${1:?usage: prepare-worktree.sh <issue-number> <slug> [base-branch]}"
SLUG="${2:?slug required}"
BASE="${3:-}"

[[ "$N" =~ ^[A-Za-z0-9-]+$ ]] || { echo "invalid issue identifier" >&2; exit 64; }
[[ "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "slug must use lowercase ASCII words and hyphens" >&2; exit 64; }
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CHECK="$SCRIPT_DIR/../../agent-loop/scripts/check-worktree.sh"

ROOT=$(git rev-parse --show-toplevel)
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

# pnpm 링크는 worktree마다 필요하므로 설치를 생략하면 타입 검사가 실패한다.
(cd "$WT" && pnpm install)

# gitignore 대상인 routeTree를 새로 생성하면 declare module이 누락될 수 있어 원본을 복사한다.
copied=0
for src in "$ROOT"/apps/*/src/routeTree.gen.ts; do
  [ -f "$src" ] || continue
  dst="$WT/${src#"$ROOT"/}"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  copied=$((copied + 1))
done
[ "$copied" -eq 0 ] && echo "WARN: no routeTree.gen.ts found — generate it in the main checkout first" >&2

echo "ready: $WT (branch $BRANCH, $copied routeTree copied)"
