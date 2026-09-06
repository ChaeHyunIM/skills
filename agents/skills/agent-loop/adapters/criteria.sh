#!/usr/bin/env bash

criteria_dispatch() (
  set -euo pipefail
  local verb="$1" id="$2" helper temp
  shift 2
  helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/criteria.py"
  command -v python3 > /dev/null || die "criteria requires python3"
  if [ "$verb" = criteria ]; then
    [ "$#" -eq 0 ] || die "usage: tracker criteria <id>"
    criteria_fetch "$id" | python3 "$helper" read
    exit
  fi
  [ "$#" -eq 2 ] || die "usage: tracker check <id> <criteria-snapshot.json> <checks.json>"
  [ -f "$1" ] && [ -f "$2" ] || die "snapshot and checks must be JSON files"
  temp=$(mktemp -d "${TMPDIR:-/tmp}/agent-loop-criteria.XXXXXX")
  trap 'rm -rf "$temp"' EXIT
  cp "$1" "$temp/expected.json"
  cp "$2" "$temp/checks.json"
  criteria_fetch "$id" > "$temp/before.json"
  python3 "$helper" prepare "$temp/expected.json" "$temp/checks.json" "$temp/before.json" > "$temp/prepared.json"
  jq -j '.body' "$temp/prepared.json" > "$temp/body.md"
  # API에 원자적 버전 조건을 걸지 못하므로 쓰기 직전에도 최신 본문을 대조한다.
  criteria_fetch "$id" > "$temp/latest.json"
  python3 "$helper" guard "$temp/expected.json" "$temp/latest.json"
  if [ "$(jq -r '.changed' "$temp/prepared.json")" = true ]; then
    criteria_write "$id" "$temp/body.md" "$temp/latest.json"
    criteria_fetch "$id" > "$temp/after.json"
  else
    cp "$temp/latest.json" "$temp/after.json"
  fi
  python3 "$helper" verify "$temp/prepared.json" "$temp/after.json"
)
