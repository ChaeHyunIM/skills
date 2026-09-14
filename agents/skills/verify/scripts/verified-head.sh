#!/usr/bin/env bash
# SHA 동일성만 판정한다. 각 완료 조건의 근거와 환경은 호출자가 별도로 대조한다.
# 출력: current <sha> (0), stale <sha> <양쪽 고유 커밋 수> (1), missing <이유> (2).
set -euo pipefail

PR=${1:?usage: verified-head.sh <PR> [<worktree>]}
WT=${2:-$(git rev-parse --show-toplevel)}
missing() { printf 'missing %s\n' "$1"; exit 2; }

json=$(gh pr view "$PR" --json body,headRefOid,headRefName) || missing 'gh pr view failed'
parsed=$(printf '%s' "$json" | node -e '
  const fs = require("fs");
  try {
    const pr = JSON.parse(fs.readFileSync(0, "utf8"));
    if (!/^[0-9a-f]{40}$/.test(pr.headRefOid) || typeof pr.headRefName !== "string" || /[\s\x00-\x1f]/.test(pr.headRefName)) throw Error("invalid PR head");
    const body = pr.body ?? "";
    const sections = [...body.matchAll(/^## 완료 조건 검증[ \t]*\r?$/gm)];
    if (sections.length !== 1) throw Error("verification section missing or ambiguous");
    const rest = body.slice(sections[0].index + sections[0][0].length);
    const next = rest.search(/^#{1,2} /m);
    const section = next < 0 ? rest : rest.slice(0, next);
    const targets = [...section.matchAll(/^검증 대상:[ \t]*(.+)$/gm)];
    if (targets.length !== 1) throw Error("verification target missing or ambiguous");
    const token = targets[0][1].split(" · ")[0].trim();
    let sha;
    const plain = token.match(/^`?([0-9a-f]{7,40})`?$/);
    const link = token.match(/^\[([^\]]+)\]\(https:\/\/[^\s)]+\/commit\/([0-9a-f]{7,40})\)$/);
    if (plain) sha = plain[1];
    else if (link) {
      sha = link[2];
      if (/^[0-9a-f]{7,40}$/.test(link[1]) && !sha.startsWith(link[1]) && !link[1].startsWith(sha)) throw Error("target label and URL disagree");
    } else throw Error("invalid verification SHA");
    process.stdout.write([sha, pr.headRefOid, pr.headRefName].join("\t"));
  } catch (error) {
    process.stderr.write(error.message + "\n");
    process.exit(1);
  }
') || missing 'invalid verification record'
IFS=$'\t' read -r sha head branch <<< "$parsed"

if ! git -C "$WT" cat-file -e "$head^{commit}" 2>/dev/null || ! git -C "$WT" cat-file -e "$sha^{commit}" 2>/dev/null; then
  git -C "$WT" fetch --no-recurse-submodules -q origin "$branch" || missing 'cannot fetch PR commits'
fi
record=$(git -C "$WT" rev-parse --verify "$sha^{commit}" 2>/dev/null) || missing 'unknown verification commit'
actual=$(git -C "$WT" rev-parse --verify "$head^{commit}" 2>/dev/null) || missing 'unknown PR head'

if [ "$record" = "$actual" ]; then
  printf 'current %s\n' "$record"
  exit 0
fi
# rollback·분기에도 0으로 보이지 않도록 시간 순서 대신 대칭 차이를 보고한다.
n=$(git -C "$WT" rev-list --count "$record...$actual") || missing 'cannot compare commits'
printf 'stale %s %s\n' "$record" "$n"
exit 1
