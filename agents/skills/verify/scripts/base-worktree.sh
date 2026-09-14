#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
ROOT=$(cd "$ROOT" && pwd -P)

if [ "${1:-}" = "--remove" ]; then
  wt=${2:?name the worktree created by this verification run}
  wt=$(cd "$wt" && pwd -P)
  case "$wt" in "$ROOT"/.claude/worktrees/verify-base-*) ;; *) echo "not a verification worktree in this repository" >&2; exit 3;; esac
  script_dir=$(cd "$(dirname "$0")" && pwd)
  bash "$script_dir/../../agent-loop/scripts/check-worktree.sh" "$wt" >/dev/null
  git -C "$ROOT" worktree remove "$wt"
  echo "removed $wt" >&2
  exit 0
fi

BASE="${1:?usage: base-worktree.sh <base-ref> | --remove <path>}"
SHA=$(git -C "$ROOT" rev-parse --verify "$BASE^{commit}")
WT="$ROOT/.claude/worktrees/verify-base-$SHA"

if [ -d "$WT" ]; then
  script_dir=$(cd "$(dirname "$0")" && pwd)
  bash "$script_dir/../../agent-loop/scripts/check-worktree.sh" "$WT" "$SHA" >/dev/null
  echo "reusing $WT" >&2
else
  git -C "$ROOT" worktree add --detach "$WT" "$SHA" >&2
fi

(cd "$WT" && pnpm install --reporter=silent) >&2

copied=0
for src in "$ROOT"/apps/*/src/routeTree.gen.ts; do
  [ -f "$src" ] || continue
  dst="$WT/${src#"$ROOT"/}"
  [ -d "$(dirname "$dst")" ] || continue          # base에는 아직 이 앱이 없을 수 있다.
  cp "$src" "$dst"; copied=$((copied+1))
done

envs=0
while IFS= read -r src; do
  rel="${src#"$ROOT"/}"
  [ -d "$WT/$(dirname "$rel")" ] || continue
  cp "$src" "$WT/$rel"; envs=$((envs+1))
done < <(find "$ROOT" -maxdepth 3 \( -name '.env.local' -o -name '.dev.vars' -o -name '.dev.vars.local' \) -not -path '*/node_modules/*' -not -path '*/.claude/*')

echo "ready: $WT (base $BASE@$SHA, $copied routeTree, $envs env files copied)" >&2
echo "$WT"
