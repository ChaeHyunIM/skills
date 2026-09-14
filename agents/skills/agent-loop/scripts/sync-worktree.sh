#!/usr/bin/env bash
set -euo pipefail

WT=${1:?usage: sync-worktree.sh <worktree> <branch>}
BRANCH=${2:?branch required}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
bash "$SCRIPT_DIR/check-worktree.sh" "$WT" >/dev/null
git check-ref-format --branch "$BRANCH" >/dev/null
if [ "$(git -C "$WT" symbolic-ref --quiet --short HEAD)" != "$BRANCH" ]; then
  echo "worktree is not on the requested branch" >&2
  exit 3
fi

git -C "$WT" fetch --no-recurse-submodules origin "refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"
REMOTE="refs/remotes/origin/$BRANCH"
if [ "$(git -C "$WT" rev-list --count "$REMOTE..HEAD")" != 0 ]; then
  echo "local-only commits exist; preserve them before continuing" >&2
  exit 3
fi
bash "$SCRIPT_DIR/check-worktree.sh" "$WT" >/dev/null
# reset 없이 앞선 원격 커밋만 가져와 로컬 작업을 버리지 않는다.
git -C "$WT" merge --ff-only "$REMOTE" >&2
bash "$SCRIPT_DIR/check-worktree.sh" "$WT" "$REMOTE"
