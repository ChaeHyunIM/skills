#!/usr/bin/env bash
# Reads the `검증 대상` sha out of a PR's `## 완료 조건 검증` record and says whether that record still
# describes the PR head. Merge commits alone (a base sync) change no PR-side line, so they keep it current.
#
#   usage: verified-head.sh <PR> [<worktree>]        worktree defaults to the current repo
#   stdout: current <sha> | stale <sha> <non-merge commits after it> | missing [<why>]
#   exit:   0 current · 1 stale · 2 missing (no record, no sha, or a sha this repo does not know)
set -uo pipefail

PR=${1:?usage: verified-head.sh <PR> [<worktree>]}
WT=${2:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}

json=$(gh pr view "$PR" --json body,headRefOid,headRefName) || { echo "missing gh pr view failed"; exit 2; }
head=$(printf '%s' "$json" | node -pe 'JSON.parse(require("fs").readFileSync(0,"utf8")).headRefOid')
branch=$(printf '%s' "$json" | node -pe 'JSON.parse(require("fs").readFileSync(0,"utf8")).headRefName')
# Cut at the first ` · ` before scanning: the 환경 text that follows can carry its own hex-looking run
# (a date, a port set), and the sha is always in the first segment — as a link, in backticks or bare.
sha=$(printf '%s' "$json" | node -pe 'JSON.parse(require("fs").readFileSync(0,"utf8")).body' \
  | grep -m1 '^검증 대상:' | sed 's/ · .*//' | grep -oE '[0-9a-f]{7,40}' | head -1)

[ -n "$sha" ] || { echo "missing no 검증 대상 in the PR body"; exit 2; }

git -C "$WT" fetch -q -p origin "$branch" 2>/dev/null || git -C "$WT" fetch -q -p origin
git -C "$WT" cat-file -e "$sha^{commit}" 2>/dev/null || { echo "missing $sha is unknown to $WT"; exit 2; }
git -C "$WT" cat-file -e "$head^{commit}" 2>/dev/null || { echo "missing PR head $head is unknown to $WT"; exit 2; }

n=$(git -C "$WT" rev-list --count --no-merges "$sha..$head")
if [ "$n" = 0 ]; then echo "current $sha"; exit 0; fi
echo "stale $sha $n"; exit 1
