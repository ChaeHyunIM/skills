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
# Config (sourced from <repo>/.claude/agent-loop/config):
#   LINEAR_TEAM_KEY   required — the team whose tickets the loop works (e.g. YOU)
#   STATUS_READY / STATUS_STARTED / STATUS_REVIEW / STATUS_DONE
#                     optional — workflow status NAMES; defaults below match
#                     Linear's stock names except STATUS_REVIEW
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

  create)
    title="${1:?usage: tracker create <title> <body-file>}"
    file="${2:?usage: tracker create <title> <body-file>}"
    [ -f "$file" ] || die "no such file: $file"
    labels=$(agent_labels)
    ready_id=$(echo "$labels" | jq -r '.["agent:ready"] // empty')
    [ -n "$ready_id" ] || die "label agent:ready missing — run 'tracker bootstrap' first"
    t=$(team)
    parent_input="{}"
    if [ -n "${TRACKER_PARENT:-}" ]; then
      parent_input=$(jq -n --arg p "$(uuid_of "$TRACKER_PARENT")" '{parentId:$p}')
    fi
    input=$(jq -n --arg t "$title" --rawfile d "$file" \
      --arg team "$(echo "$t" | jq -r .id)" \
      --arg s "$(state_id_of "$t" "$STATUS_READY")" --arg l "$ready_id" --argjson p "$parent_input" \
      '{teamId:$team,title:$t,description:$d,stateId:$s,labelIds:[$l]} + $p')
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
