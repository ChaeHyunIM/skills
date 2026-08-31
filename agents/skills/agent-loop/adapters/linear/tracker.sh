#!/usr/bin/env bash
# agent-loop tracker adapter — Linear implementation (generic, config-driven).
#
# Same verb contract as the github adapter (see its header, and CONTRACT.md's
# [Tracker adapter] for the verb table). Selected per project via
# <repo>/.claude/agent-loop/config (TRACKER=linear).
#
# Representation on Linear:
#   - loop state  = one `agent:<state>` label (workspace "Agent" group)
#   - team status moves alongside, for the humans' board:
#       ready → $STATUS_READY · in-progress → $STATUS_STARTED ·
#       awaiting-review / in-review → $STATUS_REVIEW · landed → $STATUS_DONE
#       blocked keeps the current status (no team-status equivalent)
#   - there is no merge-ready state: the merge signature is the land invocation
#   - blocking edges = native "blocks" relations (blocked-by is read from
#     inverseRelations — the relation is stored on the blocking side)
#   - PR binding = Linear's GitHub integration; `link-line` prints the magic
#     word ("Fixes ABC-nn") so the merge of a ticket's own 1:1 PR moves it to Done
#
# Linear-only extra verb:
#   bootstrap   create the "Agent" label group and its five `agent:*` labels
#               if missing. Run once per workspace.
#
# 공통 속성 명령:
#   planning-context
#               쓰기 가능한 네이티브 속성과 현재 Cycle 근거를 제공한다.
#               `create`는 승인된 값을 선택적 세 번째 JSON 인자로 받아
#               이슈를 만들기 전에 전부 검증한다.
#
# Config (sourced from <repo>/.claude/agent-loop/config):
#   LINEAR_TEAM_KEY   required — the team whose tickets the loop works (e.g. YOU)
#   STATUS_READY / STATUS_STARTED / STATUS_REVIEW / STATUS_DONE
#                     optional — workflow status NAMES; defaults below match
#                     Linear's stock names except STATUS_REVIEW
#   LINEAR_ESTIMATE_VALUES
#                     선택 — 팀에서 활성화한 Estimate scale의 정수 목록.
#                     Linear 공개 API는 이 설정을 노출하지 않으므로, 값이 없으면
#                     광고 대상 Cycle에서 실제로 관측된 값만 제공하고 추측하지 않는다.
# Team and status ids are resolved from these names at runtime, per invocation —
# adapter calls are rare enough that a cache would only add staleness risk.
#
# Ticket ids: verbs accept "ABC-45" or a bare "45" (prefixed with the team key).
# TRACKER_PARENT (env, optional): parent ticket identifier for `create` —
#   to-tickets sets it to publish slices as sub-issues of a team-level ticket.
#
# Auth: LINEAR_API_KEY from the environment, else from
# <repo>/.claude/agent-loop/.env.local (gitignored). Personal keys: Linear →
# Settings → API.

set -euo pipefail

die() { echo "tracker: $*" >&2; exit 1; }

ROOT=$(git rev-parse --show-toplevel)
CONF="$ROOT/.claude/agent-loop/config"
# shellcheck disable=SC1090
[ -f "$CONF" ] && source "$CONF"
if [ -z "${LINEAR_API_KEY:-}" ] && [ -f "$ROOT/.claude/agent-loop/.env.local" ]; then
  # shellcheck disable=SC1091
  source "$ROOT/.claude/agent-loop/.env.local"
fi
[ -n "${LINEAR_API_KEY:-}" ] || die "LINEAR_API_KEY not set — put it in .claude/agent-loop/.env.local"
[ -n "${LINEAR_TEAM_KEY:-}" ] || die "LINEAR_TEAM_KEY not set — put it in .claude/agent-loop/config"

TEAM_KEY="$LINEAR_TEAM_KEY"
STATUS_READY="${STATUS_READY:-Todo}"
STATUS_STARTED="${STATUS_STARTED:-In Progress}"
STATUS_REVIEW="${STATUS_REVIEW:-In Review / QA}"
STATUS_DONE="${STATUS_DONE:-Done}"

STATES=(ready in-progress awaiting-review in-review blocked)

gql() { # gql <query> [<variables-json>]
  local out vars="${2:-}"
  [ -n "$vars" ] || vars='{}'
  out=$(curl -sfS https://api.linear.app/graphql \
    -H "Content-Type: application/json" -H "Authorization: $LINEAR_API_KEY" \
    --data "$(jq -n --arg q "$1" --argjson v "$vars" '{query:$q,variables:$v}')") \
    || die "GraphQL request failed"
  if [ "$(echo "$out" | jq 'has("errors")')" = "true" ]; then
    die "GraphQL error: $(echo "$out" | jq -c .errors)"
  fi
  echo "$out"
}

ident() { # bare number → TEAM_KEY-number
  case "$1" in
    [0-9]*) echo "$TEAM_KEY-$1" ;;
    *)      echo "$1" ;;
  esac
}

uuid_of() {
  gql 'query($id:String!){issue(id:$id){id}}' "$(jq -n --arg id "$(ident "$1")" '{id:$id}')" \
    | jq -r '.data.issue.id'
}

team() { # {"id":..., "<status name>": "<state uuid>", ...}
  gql 'query($k:String!){teams(filter:{key:{eq:$k}}){nodes{id states{nodes{id name}}}}}' \
    "$(jq -n --arg k "$TEAM_KEY" '{k:$k}')" \
    | jq '.data.teams.nodes[0] // error("team \(env.LINEAR_TEAM_KEY // "?") not found")
        | {id} + ([.states.nodes[] | {(.name): .id}] | add)'
}

state_id_of() { # state_id_of <team-json> <status name>
  local sid
  sid=$(echo "$1" | jq -r --arg n "$2" '.[$n] // empty')
  [ -n "$sid" ] || die "workflow status '$2' not found in team $TEAM_KEY — set STATUS_* in config"
  echo "$sid"
}

status_name_for() {
  case "$1" in
    ready)           echo "$STATUS_READY" ;;
    in-progress)     echo "$STATUS_STARTED" ;;
    awaiting-review) echo "$STATUS_REVIEW" ;;
    in-review)       echo "$STATUS_REVIEW" ;;
    blocked)         echo "" ;;   # no team-status equivalent — status stays put
    *) die "unknown state '$1'" ;;
  esac
}

agent_labels() { # name → id map for every agent:* label
  gql 'query{issueLabels(filter:{name:{startsWith:"agent:"}}){nodes{id name}}}' \
    | jq '[.data.issueLabels.nodes[] | {(.name): .id}] | add // {}'
}

configured_estimate_values() {
  local raw="${LINEAR_ESTIMATE_VALUES:-}" values
  if [ -z "$raw" ]; then
    echo '[]'
    return
  fi
  values=$(jq -en --arg raw "$raw" '
      $raw | split(",") | map(gsub("^\\s+|\\s+$"; ""))
      | if any(.[]; . == "") then error("empty value") else map(tonumber) end
      | if any(.[]; . < 0 or . > 64 or . != floor)
        then error("values must be integers from 0 through 64")
        else unique end') \
    || die "LINEAR_ESTIMATE_VALUES must be comma-separated integers from 0 through 64"
  echo "$values"
}

planning_context() {
  local configured response cycle_ids issues
  configured=$(configured_estimate_values)
  response=$(gql 'query($k:String!){teams(filter:{key:{eq:$k}}){nodes{
      id cyclesEnabled defaultIssueEstimate
      activeCycle{id number name startsAt endsAt isActive isFuture isPast}
      cycles(first:10){nodes{id number name startsAt endsAt isActive isFuture isPast
        issueCountHistory completedIssueCountHistory scopeHistory completedScopeHistory}}
    }}}' "$(jq -n --arg k "$TEAM_KEY" '{k:$k}')")
  cycle_ids=$(echo "$response" | jq '[
      (.data.teams.nodes[0].activeCycle | select(. != null)),
      (.data.teams.nodes[0].cycles.nodes[] | select(.isFuture))]
      | sort_by(.startsAt) | .[0:3] | map(.id)')
  issues='{"nodes":[],"pageInfo":{"hasNextPage":false}}'
  if [ "$(echo "$cycle_ids" | jq 'length')" -gt 0 ]; then
    issues=$(gql 'query($k:String!,$ids:[ID!]!){issues(
        filter:{team:{key:{eq:$k}},cycle:{id:{in:$ids}}},first:250){
          nodes{cycle{id} estimate} pageInfo{hasNextPage}}}' \
      "$(jq -n --arg k "$TEAM_KEY" --argjson ids "$cycle_ids" '{k:$k,ids:$ids}')" \
      | jq '.data.issues')
  fi

  echo "$response" | jq --argjson configured "$configured" --argjson issues "$issues" '
    .data.teams.nodes[0] // error("team not found")
    | . as $team
    | ([$issues.nodes[]?.estimate | select(. != null)] | unique) as $observed
    | ([$team.cycles.nodes[]
        | select((.scopeHistory | length) > 0 and (.issueCountHistory | length) > 0)
        | select(.scopeHistory[-1] != .issueCountHistory[-1])] | length > 0) as $scopeDiffers
    | (if ($configured | length) > 0 then $configured else $observed end) as $estimateValues
    | (($estimateValues | length) > 0 or $scopeDiffers) as $usesEstimates
    | (if $usesEstimates then "points" else "issues" end) as $unit
    | ([($team.activeCycle | select(. != null)),
        ($team.cycles.nodes[] | select(.isFuture))]
       | sort_by(.startsAt) | .[0:3]
       | map({
           value: .id,
           label: (if (.name // "") != "" then .name else "Cycle \(.number)" end),
           state: (if .isActive then "active" else "upcoming" end),
           number,
           startsAt,
           endsAt,
           scope: (if ($issues.pageInfo.hasNextPage // false) then null
             elif $unit == "points"
             then ([.id as $cycleId | $issues.nodes[]
                    | select(.cycle.id == $cycleId)
                    | (.estimate // $team.defaultIssueEstimate)] | add // 0)
             else ([.id as $cycleId | $issues.nodes[]
                    | select(.cycle.id == $cycleId)] | length)
             end),
           scopeTruncated: ($issues.pageInfo.hasNextPage // false)
         })) as $cycleValues
    | ([$team.cycles.nodes[] | select(.isPast)]
       | sort_by(.endsAt) | reverse | .[0:3]
       | map({
           number,
           startsAt,
           endsAt,
           completed: (if $unit == "points"
             then (.completedScopeHistory[-1] // 0)
             else (.completedIssueCountHistory[-1] // 0)
           end)
         })) as $throughputCycles
    | {
        properties:
          ((if ($estimateValues | length) > 0 then [{
              key: "estimate",
              label: "Estimate",
              kind: "enum",
              semantics: "relative-size",
              values: [$estimateValues[] | {value: ., label: tostring}],
              context: {
                unestimatedWeight: $team.defaultIssueEstimate,
                valuesSource: (if ($configured | length) > 0 then "config" else "observed" end)
              }
            }] else [] end)
          + (if $team.cyclesEnabled and ($cycleValues | length) > 0 then [{
              key: "cycle",
              label: "Cycle",
              kind: "enum",
              semantics: "delivery-window",
              values: $cycleValues,
              context: {
                unit: $unit,
                unestimatedWeight: $team.defaultIssueEstimate,
                recentThroughput: {
                  cycles: $throughputCycles,
                  average: (if ($throughputCycles | length) > 0
                    then ([$throughputCycles[].completed] | add / length)
                    else null end)
                }
              }
            }] else [] end)
          + [{
              key: "priority",
              label: "Priority",
              kind: "enum",
              semantics: "urgency",
              default: "none",
              values: [
                {value:"none",label:"No priority",level:"neutral"},
                {value:"low",label:"Low",level:"low"},
                {value:"medium",label:"Medium",level:"medium"},
                {value:"high",label:"High",level:"high"},
                {value:"urgent",label:"Urgent",level:"critical"}
              ]
            }, {
              key: "dueDate",
              label: "Due date",
              kind: "date",
              semantics: "external-deadline",
              format: "YYYY-MM-DD"
            }])
      }'
}

linear_property_input() {
  local raw="$1" properties unknown input priority due context estimate cycle
  properties=$(echo "$raw" | jq -ec '
      if type == "object" then . else error("expected an object") end') \
    || die "properties-json must be a JSON object"
  unknown=$(echo "$properties" | jq -c 'keys - ["cycle","dueDate","estimate","priority"]')
  [ "$unknown" = "[]" ] || die "unsupported properties: $unknown"
  input='{}'

  if [ "$(echo "$properties" | jq 'has("priority")')" = "true" ]; then
    priority=$(echo "$properties" | jq -er '
      .priority | if type == "string" then . else error("expected a string") end') \
      || die "priority must be one of none, low, medium, high, urgent"
    case "$priority" in
      none)   priority=0 ;;
      urgent) priority=1 ;;
      high)   priority=2 ;;
      medium) priority=3 ;;
      low)    priority=4 ;;
      *) die "priority must be one of none, low, medium, high, urgent" ;;
    esac
    input=$(jq -n --argjson input "$input" --argjson priority "$priority" \
      '$input + {priority:$priority}')
  fi

  if [ "$(echo "$properties" | jq 'has("dueDate")')" = "true" ]; then
    due=$(echo "$properties" | jq -er '
      .dueDate | if type == "string" then . else error("expected a string") end') \
      || die "dueDate must use YYYY-MM-DD"
    jq -en --arg d "$due" '
      try ($d | capture("^(?<year>[0-9]{4})-(?<month>[0-9]{2})-(?<day>[0-9]{2})$")
        | (.year | tonumber) as $year
        | (.month | tonumber) as $month
        | (.day | tonumber) as $day
        | if $year < 1 or $month < 1 or $month > 12 then false
          else ([31,
            (if ($year % 400 == 0) or ($year % 4 == 0 and $year % 100 != 0) then 29 else 28 end),
            31,30,31,30,31,31,30,31,30,31][$month - 1]) as $lastDay
            | $day >= 1 and $day <= $lastDay
          end) catch false' \
      > /dev/null || die "dueDate must be a real date in YYYY-MM-DD"
    input=$(jq -n --argjson input "$input" --arg due "$due" '$input + {dueDate:$due}')
  fi

  if [ "$(echo "$properties" | jq 'has("estimate") or has("cycle")')" = "true" ]; then
    context=$(planning_context)
  fi

  if [ "$(echo "$properties" | jq 'has("estimate")')" = "true" ]; then
    estimate=$(echo "$properties" | jq -er '
      .estimate | if type == "number" and . == floor then . else error("expected an integer") end') \
      || die "estimate must be an advertised integer"
    echo "$context" | jq -e --argjson estimate "$estimate" '
      [.properties[] | select(.key == "estimate") | .values[].value] | index($estimate) != null' \
      > /dev/null || die "estimate is not currently advertised by planning-context"
    input=$(jq -n --argjson input "$input" --argjson estimate "$estimate" \
      '$input + {estimate:$estimate}')
  fi

  if [ "$(echo "$properties" | jq 'has("cycle")')" = "true" ]; then
    cycle=$(echo "$properties" | jq -er '
      .cycle | if type == "string" and length > 0 then . else error("expected a string") end') \
      || die "cycle must be an advertised value"
    echo "$context" | jq -e --arg cycle "$cycle" '
      [.properties[] | select(.key == "cycle") | .values[].value] | index($cycle) != null' \
      > /dev/null || die "cycle is not currently advertised by planning-context"
    input=$(jq -n --argjson input "$input" --arg cycle "$cycle" '$input + {cycleId:$cycle}')
  fi

  echo "$input"
}

# Same {number,…,state} projection as the github adapter — .state is open/closed
ISSUE_FIELDS='identifier title description url updatedAt state{type} labels{nodes{name}}'
project_issue='{number:.identifier,title:.title,body:(.description//""),
  state:(if .state.type=="completed" or .state.type=="canceled" or .state.type=="duplicate" then "CLOSED" else "OPEN" end),
  labels:[.labels.nodes[].name],url:.url,updatedAt:.updatedAt}'

verb="${1:-}"; shift || true

case "$verb" in

  bootstrap)
    labels=$(agent_labels)
    group_id=$(gql 'query{issueLabels(filter:{name:{eq:"Agent"}}){nodes{id}}}' \
      | jq -r '.data.issueLabels.nodes[0].id // empty')
    if [ -z "$group_id" ]; then
      group_id=$(gql 'mutation($i:IssueLabelCreateInput!){issueLabelCreate(input:$i){issueLabel{id}}}' \
        "$(jq -n '{i:{name:"Agent",color:"#95999f",isGroup:true,
          description:"agent-loop state machine only — not a label humans touch (the merge signature is the land invocation)"}}')" \
        | jq -r '.data.issueLabelCreate.issueLabel.id')
      echo "created group Agent"
    fi
    for s in "${STATES[@]}"; do
      if [ "$(echo "$labels" | jq --arg n "agent:$s" 'has($n)')" != "true" ]; then
        gql 'mutation($i:IssueLabelCreateInput!){issueLabelCreate(input:$i){issueLabel{id}}}' \
          "$(jq -n --arg n "agent:$s" --arg p "$group_id" '{i:{name:$n,color:"#95999f",parentId:$p}}')" \
          > /dev/null
        echo "created agent:$s"
      fi
    done
    echo "bootstrap complete"
    ;;

  list)
    state="${1:?usage: tracker list <state>}"
    status_name_for "$state" > /dev/null   # validates the name
    gql "query(\$k:String!,\$l:String!){issues(filter:{team:{key:{eq:\$k}},labels:{name:{eq:\$l}},
        state:{type:{nin:[\"completed\",\"canceled\",\"duplicate\"]}}},first:100){nodes{$ISSUE_FIELDS}}}" \
      "$(jq -n --arg k "$TEAM_KEY" --arg l "agent:$state" '{k:$k,l:$l}')" \
      | jq "[.data.issues.nodes[] | $project_issue | {number,title,body,updatedAt}]"
    ;;

  list-startable)
    # blocked-by lives in inverseRelations of type "blocks" — the relation is
    # stored on the blocking issue, so it must be read from the reverse side.
    # No server-side filter exists for it; filtered client-side.
    gql "query(\$k:String!){issues(filter:{team:{key:{eq:\$k}},labels:{name:{eq:\"agent:ready\"}},
        state:{type:{nin:[\"completed\",\"canceled\",\"duplicate\"]}}},first:100){nodes{identifier
        inverseRelations{nodes{type issue{identifier state{type}}}}}}}" \
      "$(jq -n --arg k "$TEAM_KEY" '{k:$k}')" \
      | jq '[.data.issues.nodes[]
          | select([.inverseRelations.nodes[]? | select(.type=="blocks")
              | select(.issue.state.type | IN("completed","canceled","duplicate") | not)] == [])
          | .identifier]'
    ;;

  show)
    id=$(ident "${1:?usage: tracker show <id>}")
    gql "query(\$id:String!){issue(id:\$id){$ISSUE_FIELDS}}" "$(jq -n --arg id "$id" '{id:$id}')" \
      | jq ".data.issue | $project_issue | del(.updatedAt)"
    ;;

  blockers)
    id=$(ident "${1:?usage: tracker blockers <id>}")
    gql 'query($id:String!){issue(id:$id){inverseRelations{nodes{type issue{identifier state{type}}}}}}' \
      "$(jq -n --arg id "$id" '{id:$id}')" \
      | jq '[.data.issue.inverseRelations.nodes[] | select(.type=="blocks")
          | {number:.issue.identifier,
             state:(if .issue.state.type | IN("completed","canceled","duplicate") then "closed" else "open" end)}]'
    ;;

  add-edge)
    id="${1:?usage: tracker add-edge <id> <blocker-id>}"
    blocker="${2:?usage: tracker add-edge <id> <blocker-id>}"
    gql 'mutation($b:String!,$i:String!){issueRelationCreate(input:{issueId:$b,relatedIssueId:$i,type:blocks}){issueRelation{id}}}' \
      "$(jq -n --arg b "$(uuid_of "$blocker")" --arg i "$(uuid_of "$id")" '{b:$b,i:$i}')" > /dev/null
    jq -n --arg id "$(ident "$id")" --arg b "$(ident "$blocker")" '{registered:$id,blocked_by:$b}'
    ;;

  transition)
    id="${1:?usage: tracker transition <id> <state>}"
    state="${2:?usage: tracker transition <id> <state>}"
    status_name=$(status_name_for "$state")
    labels=$(agent_labels)
    target_id=$(echo "$labels" | jq -r --arg n "agent:$state" '.[$n] // empty')
    [ -n "$target_id" ] || die "label agent:$state missing — run 'tracker bootstrap' first"
    uuid=$(uuid_of "$id")
    current=$(gql 'query($id:String!){issue(id:$id){labels{nodes{id}}}}' \
      "$(jq -n --arg id "$uuid" '{id:$id}')" | jq '[.data.issue.labels.nodes[].id]')
    # strip every agent:* label, add the one target — a ticket is in one state
    new_ids=$(jq -n --argjson cur "$current" --argjson agents "$(echo "$labels" | jq '[.[]]')" \
      --arg t "$target_id" '($cur - $agents) + [$t] | unique')
    status_input="{}"
    if [ -n "$status_name" ]; then
      status_input=$(jq -n --arg s "$(state_id_of "$(team)" "$status_name")" '{stateId:$s}')
    fi
    input=$(jq -n --argjson l "$new_ids" --argjson s "$status_input" '{labelIds:$l} + $s')
    gql 'mutation($id:String!,$i:IssueUpdateInput!){issueUpdate(id:$id,input:$i){success}}' \
      "$(jq -n --arg id "$uuid" --argjson i "$input" '{id:$id,i:$i}')" > /dev/null
    jq -n --arg id "$(ident "$id")" --arg s "$state" '{issue:$id,state:$s}'
    ;;

  comment)
    id="${1:?usage: tracker comment <id> <body-file>}"
    file="${2:?usage: tracker comment <id> <body-file>}"
    [ -f "$file" ] || die "no such file: $file"
    gql 'mutation($id:String!,$b:String!){commentCreate(input:{issueId:$id,body:$b}){comment{url}}}' \
      "$(jq -n --arg id "$(uuid_of "$id")" --rawfile b "$file" '{id:$id,b:$b}')" \
      | jq -r '.data.commentCreate.comment.url'
    ;;

  pr-for)
    id=$(ident "${1:?usage: tracker pr-for <id> [--merged]}")
    want="OPEN"; [ "${2:-}" = "--merged" ] && want="MERGED"
    # PR attachments come from Linear's GitHub integration; branch and state
    # details are filled in through gh.
    urls=$(gql 'query($id:String!){issue(id:$id){attachments{nodes{url}}}}' \
      "$(jq -n --arg id "$id" '{id:$id}')" \
      | jq -r '.data.issue.attachments.nodes[].url | select(test("github\\.com/.+/pull/"))')
    out="[]"
    for u in $urls; do
      pr=$(gh pr view "$u" --json number,url,headRefName,baseRefName,state 2>/dev/null) || continue
      out=$(jq -n --argjson acc "$out" --argjson pr "$pr" --arg want "$want" \
        '$acc + (if $pr.state == $want then [$pr | del(.state)] else [] end)')
    done
    echo "$out"
    ;;

  link-line)
    # Linear's magic word — binds the PR and moves the ticket to Done on merge,
    # which is the correct signal here because tickets and PRs are 1:1.
    echo "Fixes $(ident "${1:?usage: tracker link-line <id>}")"
    ;;

  planning-context)
    planning_context
    ;;

  create)
    title="${1:?usage: tracker create <title> <body-file> [<properties-json>]}"
    file="${2:?usage: tracker create <title> <body-file> [<properties-json>]}"
    properties="${3:-}"
    [ -n "$properties" ] || properties='{}'
    [ -f "$file" ] || die "no such file: $file"
    property_input=$(linear_property_input "$properties")
    labels=$(agent_labels)
    ready_id=$(echo "$labels" | jq -r '.["agent:ready"] // empty')
    [ -n "$ready_id" ] || die "label agent:ready missing — run 'tracker bootstrap' first"
    t=$(team)
    parent_input="{}"
    if [ -n "${TRACKER_PARENT:-}" ]; then
      parent_uuid=$(uuid_of "$TRACKER_PARENT")
      # Linear 는 하위 이슈에 부모의 프로젝트·담당자를 자동 상속하지 않는다 — 부모에 있으면 따라간다
      parent_meta=$(gql 'query($id:String!){issue(id:$id){project{id} assignee{id}}}' \
        "$(jq -n --arg id "$parent_uuid" '{id:$id}')" | jq '.data.issue')
      parent_input=$(jq -n --arg p "$parent_uuid" --argjson m "$parent_meta" \
        '{parentId:$p}
         + (if $m.project then {projectId:$m.project.id} else {} end)
         + (if $m.assignee then {assigneeId:$m.assignee.id} else {} end)')
    fi
    input=$(jq -n --arg t "$title" --rawfile d "$file" \
      --arg team "$(echo "$t" | jq -r .id)" \
      --arg s "$(state_id_of "$t" "$STATUS_READY")" --arg l "$ready_id" \
      --argjson p "$parent_input" --argjson properties "$property_input" \
      '{teamId:$team,title:$t,description:$d,stateId:$s,labelIds:[$l]} + $p + $properties')
    gql 'mutation($i:IssueCreateInput!){issueCreate(input:$i){issue{identifier url}}}' \
      "$(jq -n --argjson i "$input" '{i:$i}')" \
      | jq -r '.data.issueCreate.issue.url'
    ;;

  landed)
    id="${1:?usage: tracker landed <id>}"
    uuid=$(uuid_of "$id")
    cur=$(gql 'query($id:String!){issue(id:$id){state{type} labels{nodes{id}}}}' \
      "$(jq -n --arg id "$uuid" '{id:$id}')")
    # agent:* labels are cleared either way; the move to Done happens only when
    # the magic-word automation missed
    new_ids=$(jq -n --argjson cur "$(echo "$cur" | jq '[.data.issue.labels.nodes[].id]')" \
      --argjson agents "$(agent_labels | jq '[.[]]')" '$cur - $agents')
    if [ "$(echo "$cur" | jq -r '.data.issue.state.type')" = "completed" ]; then
      gql 'mutation($id:String!,$i:IssueUpdateInput!){issueUpdate(id:$id,input:$i){success}}' \
        "$(jq -n --arg id "$uuid" --argjson l "$new_ids" '{id:$id,i:{labelIds:$l}}')" > /dev/null
      jq -n --arg id "$(ident "$id")" '{issue:$id,closed:"already"}'
    else
      done_id=$(state_id_of "$(team)" "$STATUS_DONE")
      gql 'mutation($id:String!,$i:IssueUpdateInput!){issueUpdate(id:$id,input:$i){success}}' \
        "$(jq -n --arg id "$uuid" --argjson l "$new_ids" --arg s "$done_id" '{id:$id,i:{labelIds:$l,stateId:$s}}')" > /dev/null
      jq -n --arg id "$(ident "$id")" '{issue:$id,closed:"by adapter — automation missed"}'
    fi
    ;;

  *)
    die "unknown verb '${verb:-}' — see the header of this script"
    ;;
esac
