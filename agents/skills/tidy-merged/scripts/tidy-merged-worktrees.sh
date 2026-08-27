#!/usr/bin/env bash
# 머지된 agent/issue-* PR 의 로컬 워크트리와 브랜치를 정리한다.
#
# 유실 방지의 축은 headMatchesPr — GitHub 이 머지했다고 기록한 SHA 와 로컬 HEAD 가
# 같을 때만 지운다. 같으면 로컬에만 남은 커밋이 있을 수 없다.
#
# 세션은 지우지 않는다. claude CLI 에 세션 삭제 명령이 없어서, 지운 워크트리를 cwd 로
# 쓰던 세션의 이름·pid 만 출력하고 ctrl+x 는 사람이 누른다. Codex task 도 이 스크립트에서
# 열거나 닫지 않는다 — 실행 중이면 해당 워크트리를 건너뛸 뿐이다.
#
# 사용:
#   tidy-merged-worktrees.sh [--repo <path>] [--dry-run]
#   --repo 를 생략하면 현재 위치의 저장소를 쓴다. 워크트리 안에서 실행해도 메인 체크아웃을 찾는다.
#   tidy-merged-worktrees.sh --report            판정 근거를 JSON 으로만 출력

set -uo pipefail

CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"
GH_BIN="${GH_BIN:-/opt/homebrew/bin/gh}"
JQ_BIN="${JQ_BIN:-/usr/bin/jq}"
SQLITE_BIN="${SQLITE_BIN:-/usr/bin/sqlite3}"
CODEX_STATE_ROOT="${CODEX_HOME:-$HOME/.codex}"
if [[ -z "${CODEX_STATE_DB:-}" ]]; then
  CODEX_STATE_DB="$(find "$CODEX_STATE_ROOT" -maxdepth 1 -type f -name 'state*.sqlite' -print 2>/dev/null |
    sort -V | tail -1)"
fi

REPO=""
INVOCATION_CWD="$(pwd -P)"
DRY=0
REPORT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --report) REPORT=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# 특정 레포로 기본값을 고정하면 다른 레포에서 조용히 0 건을 반환하고 성공한 것처럼 보인다.
if [[ -z "$REPO" ]]; then
  # 워크트리 안에서 실행해도 메인 체크아웃을 기준으로 삼는다
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || common_dir=""
  [[ -n "$common_dir" ]] && REPO="$(dirname "$common_dir")"
fi
[[ -n "$REPO" ]] || { echo "git 저장소 안에서 실행하거나 --repo 로 지정한다" >&2; exit 2; }
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "repo 아님: $REPO" >&2; exit 2; }
cd "$REPO" || exit 2

WT_ROOTS=("$REPO/.agents/worktrees" "$REPO/.claude/worktrees")

# 원격 상태가 낡으면 머지 판정이 통째로 틀어지므로 먼저 맞춘다
git fetch --prune --quiet origin 2>/dev/null

CLAUDE_STATUS_OK=1
SESSIONS="[]"
if command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  if ! SESSIONS="$("$CLAUDE_BIN" agents --json --all --cwd "$REPO" 2>/dev/null)" ||
     ! printf '%s' "$SESSIONS" | "$JQ_BIN" -e 'type == "array"' >/dev/null 2>&1; then
    CLAUDE_STATUS_OK=0
    SESSIONS="[]"
  fi
fi

removed=0; skipped=0
declare -a orphan_sessions=()
declare -a reports=()

is_managed_worktree() {
  local path="$1" root
  for root in "${WT_ROOTS[@]}"; do
    [[ "$path" == "$root"/* ]] && return 0
  done
  return 1
}

# Codex 활성 task 수. 상태 DB가 없으면 이 머신에 Codex task 상태가 없다는 뜻이라 0,
# 있는데 못 읽거나 현재 스키마를 해석할 수 없으면 판정 불가라 -1이다.
codex_busy_count() {
  local target="$1"
  if [[ -z "$CODEX_STATE_DB" || ! -e "$CODEX_STATE_DB" ]]; then
    echo 0
    return 0
  fi
  if [[ ! -r "$CODEX_STATE_DB" || ! -x "$SQLITE_BIN" ]]; then
    echo -1
    return 0
  fi

  local count=0 thread_cwd rollout_path lifecycle rows
  rows="$("$SQLITE_BIN" -separator $'\t' "$CODEX_STATE_DB" \
    'SELECT cwd, rollout_path FROM threads WHERE archived = 0;' 2>/dev/null)" || {
      echo -1
      return 0
    }
  while IFS=$'\t' read -r thread_cwd rollout_path; do
    [[ -n "$thread_cwd" && -n "$rollout_path" ]] || continue
    [[ "$thread_cwd" == "$target" || "$thread_cwd" == "$target/"* ]] || continue
    if [[ ! -r "$rollout_path" ]]; then
      count=$((count + 1))
      continue
    fi
    if ! lifecycle="$("$JQ_BIN" -r '
        select(.type == "event_msg")
        | select(.payload.type == "task_started" or .payload.type == "task_complete")
        | .payload.type
      ' "$rollout_path" 2>/dev/null | tail -1)"; then
      count=$((count + 1))
      continue
    fi
    if [[ -z "$lifecycle" || "$lifecycle" == "task_started" ]]; then
      count=$((count + 1))
    fi
  done <<< "$rows"
  echo "$count"
}

judge() {
  local path="$1" br="$2"
  [[ -n "$path" && -n "$br" ]] || return 0
  is_managed_worktree "$path" || return 0

  local pr pr_state merged_at head_oid
  pr="$("$GH_BIN" pr list --head "$br" --state all --limit 1 \
        --json state,number,mergedAt,headRefOid,baseRefName --jq '.[0]' 2>/dev/null)"
  [[ -n "$pr" ]] || pr='{}'
  pr_state="$(printf '%s' "$pr" | "$JQ_BIN" -r '.state      // "NONE"')"
  merged_at="$(printf '%s' "$pr" | "$JQ_BIN" -r '.mergedAt   // ""')"
  head_oid="$(printf '%s' "$pr"  | "$JQ_BIN" -r '.headRefOid // ""')"

  local local_head dirty untracked stash_count busy codex_busy beyond unpushed
  local_head="$(git -C "$path" rev-parse HEAD 2>/dev/null)"
  dirty="$(git -C "$path" status --porcelain 2>/dev/null)"
  untracked="$(git -C "$path" ls-files --others --exclude-standard 2>/dev/null)"
  stash_count="$(git stash list 2>/dev/null | grep -c "$br" || true)"
  busy="$(printf '%s' "$SESSIONS" | "$JQ_BIN" -r --arg p "$path" \
    '[.[] | select(.cwd == $p and .status == "busy")] | length')"
  codex_busy="$(codex_busy_count "$path")"
  beyond=""
  [[ -n "$head_oid" && "$head_oid" != "$local_head" ]] &&
    beyond="$(git -C "$path" log --oneline "$head_oid..$local_head" 2>/dev/null)"
  unpushed="$(git -C "$path" log --oneline "$br" --not --remotes 2>/dev/null)"

  if [[ "$REPORT" == "1" ]]; then
    reports+=("$("$JQ_BIN" -n --arg branch "$br" --arg path "$path" --argjson pr "$pr" \
      --arg localHead "$local_head" --arg dirty "$dirty" --arg untracked "$untracked" \
      --argjson stashCount "${stash_count:-0}" --argjson busy "${busy:-0}" \
      --argjson claudeStatusKnown "$CLAUDE_STATUS_OK" \
      --argjson codexBusy "${codex_busy:--1}" \
      --arg beyond "$beyond" --arg unpushed "$unpushed" \
      '{branch:$branch, path:$path, pr:$pr, localHead:$localHead,
        headMatchesPr:(($pr.headRefOid // "") != "" and $pr.headRefOid == $localHead),
        dirty:($dirty|split("\n")|map(select(length>0))),
        untracked:($untracked|split("\n")|map(select(length>0))),
        stashCount:$stashCount, claudeStatusKnown:($claudeStatusKnown == 1),
        busyClaudeSessions:$busy, busyCodexTasks:$codexBusy,
        beyondMergedSha:($beyond|split("\n")|map(select(length>0))),
        unpushed:($unpushed|split("\n")|map(select(length>0)))}')")
    return 0
  fi

  # ── 판정: 모든 조건을 만족해야 지운다 ──
  if [[ "$pr_state" != "MERGED" || -z "$merged_at" ]]; then
    echo "skip  $br — PR 상태 $pr_state"; ((skipped++)); return 0
  fi
  if [[ -z "$head_oid" || "$head_oid" != "$local_head" ]]; then
    echo "skip  $br — 머지된 SHA 와 로컬 HEAD 불일치, 로컬 전용 커밋 가능성"
    [[ -n "$beyond" ]] && echo "$beyond" | sed 's/^/        /'
    ((skipped++)); return 0
  fi
  if [[ -n "$dirty" || -n "$untracked" ]]; then
    echo "skip  $br — 미커밋 변경 또는 untracked 파일 있음"; ((skipped++)); return 0
  fi
  if [[ "${stash_count:-0}" != "0" ]]; then
    echo "skip  $br — 이 브랜치의 stash 가 남아 있음"; ((skipped++)); return 0
  fi
  if [[ "$CLAUDE_STATUS_OK" != "1" ]]; then
    echo "skip  $br — Claude 활성 세션 상태를 확인할 수 없음"; ((skipped++)); return 0
  fi
  if [[ "${busy:-0}" != "0" ]]; then
    echo "skip  $br — 이 워크트리에서 Claude 세션이 실행 중"; ((skipped++)); return 0
  fi
  if [[ "${codex_busy:--1}" == "-1" ]]; then
    echo "skip  $br — Codex 활성 task 상태를 확인할 수 없음"; ((skipped++)); return 0
  fi
  if [[ "${codex_busy:-0}" != "0" ]]; then
    echo "skip  $br — 이 워크트리에서 Codex task 가 실행 중"; ((skipped++)); return 0
  fi
  if [[ "$INVOCATION_CWD" == "$path" || "$INVOCATION_CWD" == "$path/"* ]]; then
    echo "skip  $br — 지금 이 스크립트가 실행된 작업 디렉터리"; ((skipped++)); return 0
  fi

  if [[ "$DRY" == "1" ]]; then
    echo "dry   $br — 삭제 예정 (PR #$(printf '%s' "$pr" | "$JQ_BIN" -r '.number'))"
    ((removed++)); return 0
  fi

  if git worktree remove "$path" 2>/dev/null; then
    git branch -D "$br" >/dev/null 2>&1
    while IFS= read -r line; do
      [[ -n "$line" ]] && orphan_sessions+=("$line")
    done < <(printf '%s' "$SESSIONS" | "$JQ_BIN" -r --arg p "$path" \
      '.[] | select(.cwd == $p) | "  - \(.name)  pid=\(.pid)  status=\(.status // "-")"')
    echo "clean $br — 워크트리+브랜치 삭제"
    ((removed++))
  else
    echo "skip  $br — worktree remove 실패"
    ((skipped++))
  fi
}

current_path=""; current_branch=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*) current_path="${line#worktree }" ;;
    "branch "*)   current_branch="${line#branch }" ;;
    "")           judge "$current_path" "${current_branch#refs/heads/}"; current_path=""; current_branch="" ;;
  esac
done < <(git worktree list --porcelain; echo)

if [[ "$REPORT" == "1" ]]; then
  printf '%s\n' "${reports[@]:-}" | "$JQ_BIN" -s '.'
  exit 0
fi

if [[ "$DRY" != "1" ]]; then
  git worktree prune
fi

echo "---"
echo "정리 $removed · 건너뜀 $skipped"

if [[ ${#orphan_sessions[@]} -gt 0 ]]; then
  echo "손으로 지울 Claude 세션 (ctrl+x 두 번):"
  printf '%s\n' "${orphan_sessions[@]}"
fi
