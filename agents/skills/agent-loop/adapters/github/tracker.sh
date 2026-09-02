#!/usr/bin/env bash
# agent-loop tracker adapter — GitHub Issues implementation.
#
# The adapter is the ONLY place that knows how loop states are represented on the
# platform (here: labels). Skills speak the abstract verbs below and never call
# the platform CLI for issue state directly. PR-side operations (gh pr view /
# comment / merge) are NOT tracker verbs — PRs live on GitHub regardless of
# which tracker a project uses.
#
# Verbs (all JSON on stdout unless noted):
#   list <state>              issues in one loop state: [{number,title,body,updatedAt}]
#   list-startable            'ready' issues with no open native blocker: [numbers].
#                             Ordering hint only — the search index lags writes;
#                             implement's blocker gate reads `blockers <id>` and is the verdict.
#   show <id>                 {number,title,body,state,labels,url}
#   blockers <id>             native dependency edges: [{number,state}]
#   add-edge <id> <blocker>   register a native blocked-by edge
#   transition <id> <state>   clear every loop state marker, set <state>
#   comment <id> <body-file>  post an issue comment
#   pr-for <id> [--merged]    the PR tied to this ticket: [{number,url,headRefName,baseRefName}]
#   link-line <id>            the text a PR body must carry to bind PR → ticket (prints raw)
#   planning-context          쓰기 가능한 네이티브 속성과 계획 근거
#   create <title> <body-file> [<properties-json>]
#                             'ready' 티켓을 만들고 id를 출력한다(raw)
#                             TRACKER_PARENT 가 설정돼 있으면 거부한다 — 네이티브 parent 매핑이 아직 없다
#   landed <id>               after merge: verify the tracker recorded completion; close if not
#
# States: ready | in-progress | awaiting-review | in-review | blocked
# GitHub mapping: ready-for-agent, agent-in-progress, agent-awaiting-review,
#                 agent-in-review, agent-blocked
#
# There is no merge-ready state: the merge signature is the land invocation
# itself (CONTRACT's [Loop map]).

set -euo pipefail

die() { echo "tracker: $*" >&2; exit 1; }

label_of() {
  case "$1" in
    ready)            echo "ready-for-agent" ;;
    in-progress)      echo "agent-in-progress" ;;
    awaiting-review)  echo "agent-awaiting-review" ;;
    in-review)        echo "agent-in-review" ;;
    blocked)          echo "agent-blocked" ;;
    *) die "unknown state '$1'" ;;
  esac
}

ALL_LABELS=(ready-for-agent agent-in-progress agent-awaiting-review agent-in-review agent-blocked)

repo() { gh repo view --json nameWithOwner -q .nameWithOwner; }

verb="${1:-}"; shift || true

case "$verb" in

  list)
    state="${1:?usage: tracker list <state>}"
    gh issue list --label "$(label_of "$state")" --state open \
      --json number,title,body,updatedAt
    ;;

  list-startable)
    gh issue list --label ready-for-agent --state open --search "-is:blocked" \
      --json number --jq '[.[].number]'
    ;;

  show)
    id="${1:?usage: tracker show <id>}"
    gh issue view "$id" --json number,title,body,state,labels,url \
      --jq '{number,title,body,state,url,labels:[.labels[].name]}'
    ;;

  blockers)
    id="${1:?usage: tracker blockers <id>}"
    # The raw response carries a full issue object per edge — always narrow with --jq.
    gh api "repos/$(repo)/issues/$id/dependencies/blocked_by" \
      --jq '[.[] | {number: .number, state: .state}]'
    ;;

  add-edge)
    id="${1:?usage: tracker add-edge <id> <blocker-id>}"
    blocker="${2:?usage: tracker add-edge <id> <blocker-id>}"
    # -F, not -f: the endpoint wants an integer database id; a quoted one is a 422.
    blocker_db_id=$(gh api "repos/$(repo)/issues/$blocker" --jq '.id')
    gh api -X POST "repos/$(repo)/issues/$id/dependencies/blocked_by" -F "issue_id=$blocker_db_id" \
      --jq '{registered: .number}'
    ;;

  transition)
    id="${1:?usage: tracker transition <id> <state>}"
    state="${2:?usage: tracker transition <id> <state>}"
    target=$(label_of "$state")
    args=()
    for l in "${ALL_LABELS[@]}"; do
      [ "$l" = "$target" ] || args+=(--remove-label "$l")
    done
    # Removing a label the issue doesn't carry is harmless, so one call covers
    # every source state — and clearing all others is what keeps state single.
    gh issue edit "$id" "${args[@]}" --add-label "$target" > /dev/null
    echo "{\"issue\": $id, \"state\": \"$state\"}"
    ;;

  comment)
    id="${1:?usage: tracker comment <id> <body-file>}"
    file="${2:?usage: tracker comment <id> <body-file>}"
    [ -f "$file" ] || die "no such file: $file"
    gh issue comment "$id" --body-file "$file"
    ;;

  pr-for)
    id="${1:?usage: tracker pr-for <id> [--merged]}"
    state_flag="open"
    [ "${2:-}" = "--merged" ] && state_flag="merged"
    # GitHub's --search is full-text and happily returns unrelated PRs, so the
    # binding is re-verified on the body: only a literal "Closes #<id>" counts.
    out=$(gh pr list --search "Closes #$id" --state "$state_flag" \
      --json number,url,headRefName,baseRefName,body \
      --jq "[.[] | select(.body | test(\"[Cc]loses #$id\\\\b\")) | del(.body)]")
    # The search index also lags for minutes after PR creation — fall back to
    # the branch convention before declaring "no PR".
    if [ "$out" = "[]" ]; then
      out=$(gh pr list --state "$state_flag" --json number,url,headRefName,baseRefName \
        --jq "[.[] | select(.headRefName | startswith(\"agent/issue-$id-\"))]")
    fi
    echo "$out"
    ;;

  link-line)
    id="${1:?usage: tracker link-line <id>}"
    echo "Closes #$id"
    ;;

  planning-context)
    jq -n '{properties:[]}'
    ;;

  create)
    title="${1:?usage: tracker create <title> <body-file> [<properties-json>]}"
    file="${2:?usage: tracker create <title> <body-file> [<properties-json>]}"
    properties="${3:-}"
    [ -n "$properties" ] || properties='{}'
    [ -f "$file" ] || die "no such file: $file"
    properties=$(echo "$properties" | jq -ec 'if type == "object" then . else error("expected an object") end') \
      || die "properties-json must be a JSON object"
    [ "$(echo "$properties" | jq 'length')" -eq 0 ] \
      || die "GitHub adapter does not advertise writable ticket properties"
    # 티켓 본문은 부모를 적지 않으므로(CONTRACT [Tracker adapter]) 네이티브 관계를 못 만들면 부모가 통째로 사라진다
    [ -z "${TRACKER_PARENT:-}" ] \
      || die "GitHub adapter does not register a native parent yet — TRACKER_PARENT must stay unset"
    gh issue create --title "$title" --body-file "$file" --label ready-for-agent
    ;;

  landed)
    id="${1:?usage: tracker landed <id>}"
    # GitHub closes the ticket itself (issue-lifecycle.yml on merge). Verify, and
    # close only if that automation missed — so behaviour is confirm-first.
    state=$(gh issue view "$id" --json state -q .state)
    if [ "$state" != "CLOSED" ]; then
      gh issue close "$id" --reason completed
      echo "{\"issue\": $id, \"closed\": \"by adapter — automation missed\"}"
    else
      echo "{\"issue\": $id, \"closed\": \"already\"}"
    fi
    ;;

  *)
    die "unknown verb '${verb:-}' — see the header of this script"
    ;;
esac
