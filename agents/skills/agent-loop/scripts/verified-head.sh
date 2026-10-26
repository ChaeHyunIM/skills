#!/usr/bin/env bash
# SHA 동일성만 판정한다. 각 완료 조건의 근거와 환경은 호출자가 별도로 대조한다.
# 출력: current <sha> (0), stale <sha> <양쪽 고유 커밋 수> (1), missing <이유> (2).
# gh 가 없는 클라우드 런타임도 있어 PR 은 VERIFIED_HEAD_PR_JSON 파일 → gh → GH_TOKEN/GITHUB_TOKEN 으로 REST 호출 순으로 읽는다.
# 파일은 gh 의 --json body,headRefOid,headRefName 모양이나 REST(MCP) 의 pull request 모양 둘 다 받는다.
set -euo pipefail

PR=${1:?usage: verified-head.sh <PR> [<worktree>]}
WT=${2:-$(git rev-parse --show-toplevel)}
missing() { printf 'missing %s\n' "$1"; exit 2; }

pr_json() {
  if [ -n "${VERIFIED_HEAD_PR_JSON:-}" ]; then cat "$VERIFIED_HEAD_PR_JSON"; return; fi
  if command -v gh >/dev/null 2>&1 && gh pr view "$PR" --json body,headRefOid,headRefName 2>/dev/null; then return; fi
  local token=${GH_TOKEN:-${GITHUB_TOKEN:-}} repo
  [ -n "$token" ] || return 1
  # 클라우드 세션의 origin 은 프록시 URL 이라 호스트가 아닌 마지막 두 경로 조각을 owner/repo 로 쓴다.
  repo=${GITHUB_REPOSITORY:-$(git -C "$WT" remote get-url origin | sed -E 's#\.git$##; s#^.*[:/]([^/:]+/[^/]+)$#\1#')}
  curl -fsS -H "Authorization: Bearer $token" -H 'Accept: application/vnd.github+json' \
    "${GITHUB_API_URL:-https://api.github.com}/repos/$repo/pulls/$PR"
}

json=$(pr_json) || missing 'cannot read PR (no VERIFIED_HEAD_PR_JSON, gh, or GH_TOKEN)'
parsed=$(printf '%s' "$json" | node -e '
  const fs = require("fs");
  try {
    const raw = JSON.parse(fs.readFileSync(0, "utf8"));
    const pr = { body: raw.body, headRefOid: raw.headRefOid ?? raw.head?.sha, headRefName: raw.headRefName ?? raw.head?.ref };
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
