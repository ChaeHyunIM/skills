#!/usr/bin/env bash
# Detached worktree at the base commit, ready to run dev servers, so "before" is the real base.
#
#   usage: base-worktree.sh <base-branch>    prints the worktree path on stdout (progress on stderr)
#          base-worktree.sh --remove         removes every verify-base worktree
#
# Uses the LOCAL branch (CONTRACT: the user's unpushed base commits are usually the prerequisite).
# Copies gitignored files the servers need: routeTree.gen.ts and the env files. Env files are copied
# byte-for-byte and never printed.
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)

if [ "${1:-}" = "--remove" ]; then
  for wt in "$ROOT"/.claude/worktrees/verify-base-*; do
    [ -d "$wt" ] || continue
    git -C "$ROOT" worktree remove --force "$wt" && echo "removed $wt" >&2
  done
  git -C "$ROOT" worktree prune
  exit 0
fi

BASE="${1:?usage: base-worktree.sh <base-branch> | --remove}"
SHA=$(git -C "$ROOT" rev-parse --verify --short "$BASE^{commit}")
WT="$ROOT/.claude/worktrees/verify-base-$SHA"

if [ -d "$WT" ]; then
  echo "reusing $WT" >&2
else
  git -C "$ROOT" worktree add --detach "$WT" "$SHA" >&2
fi

(cd "$WT" && pnpm install --reporter=silent) >&2

copied=0
for src in "$ROOT"/apps/*/src/routeTree.gen.ts; do
  [ -f "$src" ] || continue
  dst="$WT/${src#"$ROOT"/}"
  [ -d "$(dirname "$dst")" ] || continue          # the base may predate this app
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
