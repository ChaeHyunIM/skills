#!/usr/bin/env bash
# Starts or stops one port set of dev servers so the same spec can run against head and base.
#
#   usage: dev-servers.sh start <head|base> <checkout-dir> <app>...    apps: api doko admin doko-app
#          dev-servers.sh stop  <head|base>
#          dev-servers.sh status
#
#   ports  head: api 4000 · doko 3000 · admin 3001 · metro 8081
#          base: api 4100 · doko 3100 · admin 3101 · metro 8082
#
# A web app is started with VITE_API_BASE_URL pointing at its own set's API, so start `api` in the same
# set first (or in the same call — order below is api, then web). Logs and pids live under
# <main-root>/.e2e/servers/<set>/ so `stop` works from any checkout.
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel)
STATE="$ROOT/.e2e/servers"

port() {
  case "$1:$2" in
    head:api) echo 4000;; head:doko) echo 3000;; head:admin) echo 3001;; head:doko-app) echo 8081;;
    base:api) echo 4100;; base:doko) echo 3100;; base:admin) echo 3101;; base:doko-app) echo 8082;;
    *) echo "unknown set/app: $1/$2" >&2; return 1;;
  esac
}

wait_http() {
  local url=$1 i
  for i in $(seq 1 90); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)" != "000" ] && return 0
    sleep 1
  done
  return 1
}

start_one() {
  local set=$1 dir=$2 app=$3 p api log pidf
  p=$(port "$set" "$app") || return 1
  api=$(port "$set" api)
  mkdir -p "$STATE/$set"
  log="$STATE/$set/$app.log"; pidf="$STATE/$set/$app.pid"
  if [ -f "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then
    echo "$app already running (set $set, port $p)"; return 0
  fi
  if lsof -ti "tcp:$p" >/dev/null 2>&1; then
    echo "port $p is taken by another process — stop it first (lsof -i :$p)" >&2; return 1
  fi
  case "$app" in
    api)      (cd "$dir/apps/api"   && nohup pnpm exec wrangler dev --port "$p" >"$log" 2>&1 & echo $! >"$pidf") ;;
    doko)     (cd "$dir/apps/doko"  && VITE_API_BASE_URL="http://localhost:$api" nohup pnpm exec vite dev --port "$p" --strictPort >"$log" 2>&1 & echo $! >"$pidf") ;;
    admin)    (cd "$dir/apps/admin" && VITE_API_BASE_URL="http://localhost:$api" nohup pnpm exec vite dev --port "$p" --strictPort >"$log" 2>&1 & echo $! >"$pidf") ;;
    doko-app) (cd "$dir/apps/doko-app" && CI=1 nohup pnpm exec expo start --port "$p" >"$log" 2>&1 & echo $! >"$pidf") ;;
  esac
  if wait_http "http://localhost:$p/"; then
    echo "$app up: http://localhost:$p  (log: $log)"
  else
    echo "$app did not answer on $p within 90 s — see $log" >&2; return 1
  fi
}

stop_set() {
  local set=$1 app p pidf pid
  for app in api doko admin doko-app; do
    p=$(port "$set" "$app")
    pidf="$STATE/$set/$app.pid"
    if [ -f "$pidf" ]; then
      pid=$(cat "$pidf")
      pkill -P "$pid" 2>/dev/null; kill "$pid" 2>/dev/null
      rm -f "$pidf"
    fi
    lsof -ti "tcp:$p" 2>/dev/null | xargs -r kill 2>/dev/null
  done
  echo "set $set stopped"
}

status() {
  local set app p
  for set in head base; do
    for app in api doko admin doko-app; do
      p=$(port "$set" "$app")
      if lsof -ti "tcp:$p" >/dev/null 2>&1; then echo "$set/$app  listening on $p"; fi
    done
  done
}

cmd=${1:-}; shift || true
case "$cmd" in
  start)
    set=${1:?set (head|base)}; dir=${2:?checkout dir}; shift 2
    [ $# -gt 0 ] || { echo "no apps given" >&2; exit 1; }
    # api first so a web app in the same call finds its API.
    for app in "$@"; do [ "$app" = api ] && start_one "$set" "$dir" api; done
    rc=0
    for app in "$@"; do [ "$app" = api ] || start_one "$set" "$dir" "$app" || rc=1; done
    exit $rc ;;
  stop)   stop_set "${1:?set (head|base)}" ;;
  status) status ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac
