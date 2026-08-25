#!/usr/bin/env bash
# Gather, in one shot, the runtime context needed to write a worklog:
#   - today's date / target file path / file-exists (append vs create)
#   - current Claude Code session id (CLAUDE_CODE_SESSION_ID)
#   - recent commits in the current working dir (hash|isodate|author|subject)
#
# If this is not a git repo (or git is missing), leave the commit section empty
# and exit cleanly (spec: omit commits without erroring when there are none).
#
# Usage:  worklog_context.sh [worklog_dir] [commit_count] [date_override]
#   worklog_dir    default ~/Desktop/worklog
#   commit_count   number of recent commits to show (default 25)
#   date_override  YYYY-MM-DD. When documenting a past transcript, force the file
#                  to use that session's date instead of today (pass the
#                  "Session date (KST)" value from extract_transcript.py).
#                  Empty -> today's date.

set -u

WORKLOG_DIR="${1:-$HOME/Desktop/worklog}"
COMMIT_COUNT="${2:-25}"
DATE_OVERRIDE="${3:-}"

if [ -n "$DATE_OVERRIDE" ]; then
  DATE="$DATE_OVERRIDE"
else
  DATE="$(date +%Y-%m-%d)"
fi
NOW="$(date +%H:%M)"
TARGET="$WORKLOG_DIR/$DATE.md"

echo "DATE: $DATE"
echo "NOW: $NOW"
echo "WORKLOG_DIR: $WORKLOG_DIR"
echo "TARGET: $TARGET"
if [ -f "$TARGET" ]; then
  echo "FILE_EXISTS: true"
  echo "MODE: append"
else
  echo "FILE_EXISTS: false"
  echo "MODE: create"
fi

echo "SESSION_ID: ${CLAUDE_CODE_SESSION_ID:-unknown}"

echo ""
echo "=== RECENT COMMITS (hash|date|author|subject) ==="
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git --no-pager log -n "$COMMIT_COUNT" \
    --date=format:'%Y-%m-%d %H:%M' \
    --pretty=format:'%h|%ad|%an|%s' 2>/dev/null || true
  echo ""
else
  echo "(not a git repo — commit references omitted)"
fi
