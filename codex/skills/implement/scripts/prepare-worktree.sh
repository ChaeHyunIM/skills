#!/usr/bin/env bash
# Creates an issue's worktree and leaves it immediately usable (CONTRACT worktree convention).
#
#   usage: prepare-worktree.sh <issue-number> <slug> [base-branch]
#
#   With a base, cuts a new branch from it (fresh start).
#   Without one, attaches a worktree to the existing branch (rework).
#
# An existing worktree is left in place; only pnpm install and the routeTree copy re-run,
# so the script is safe to run again.
set -euo pipefail

N="${1:?usage: prepare-worktree.sh <issue-number> <slug> [base-branch]}"
SLUG="${2:?slug required}"
BASE="${3:-}"

ROOT=$(git rev-parse --show-toplevel)
WT="$ROOT/.claude/worktrees/issue-$N-$SLUG"
BRANCH="agent/issue-$N-$SLUG"

if [ -d "$WT" ]; then
  echo "worktree exists — reusing: $WT"
else
  git -C "$ROOT" fetch origin
  if [ -n "$BASE" ]; then
    git -C "$ROOT" worktree add "$WT" -b "$BRANCH" "$BASE"
  else
    # Rework: the branch already exists and has its base pinned.
    git -C "$ROOT" worktree add "$WT" "$BRANCH"
  fi
fi

# Monorepo pnpm links are installed per worktree. Without this, check-types breaks.
(cd "$WT" && pnpm install)

# routeTree.gen.ts is gitignored, so a new worktree lacks it. `tsr generate` silently drops the
# declare module block, so copy from the main checkout instead.
copied=0
for app in admin doko; do
  src="$ROOT/apps/$app/src/routeTree.gen.ts"
  dst="$WT/apps/$app/src/routeTree.gen.ts"
  if [ -f "$src" ]; then
    cp "$src" "$dst"
    copied=$((copied + 1))
  fi
done
[ "$copied" -eq 0 ] && echo "WARN: no routeTree.gen.ts found — generate it in the main checkout first" >&2

echo "ready: $WT (branch $BRANCH, $copied routeTree copied)"
