#!/usr/bin/env bash
set -euo pipefail

WT=${1:?usage: check-worktree.sh <worktree> [expected-head]}
EXPECTED=${2:-}
ACTUAL_DIR=$(cd "$WT" && pwd -P)
ROOT=$(git -C "$WT" rev-parse --show-toplevel)
ROOT=$(cd "$ROOT" && pwd -P)

# 빈 worktree 디렉터리에서 상위 저장소로 빠지는 Git 탐색을 막는다.
if [ "$ACTUAL_DIR" != "$ROOT" ]; then
  echo "worktree root mismatch: $ACTUAL_DIR" >&2
  exit 3
fi
if [ -n "$(git -C "$WT" status --porcelain --untracked-files=normal)" ]; then
  echo "worktree has local changes; preserve them before continuing" >&2
  exit 3
fi
HEAD_SHA=$(git -C "$WT" rev-parse HEAD)
if [ -n "$EXPECTED" ]; then
  EXPECTED_SHA=$(git -C "$WT" rev-parse --verify "$EXPECTED^{commit}")
  if [ "$HEAD_SHA" != "$EXPECTED_SHA" ]; then
    echo "worktree head differs from the expected target" >&2
    exit 4
  fi
fi
printf '%s\n' "$HEAD_SHA"
