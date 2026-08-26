#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?usage: append_worklog.sh <target.md> <session-block.md>}"
BLOCK="${2:?session block required}"

[[ -f "$TARGET" ]] || { echo "target does not exist: $TARGET" >&2; exit 2; }
[[ -f "$BLOCK" ]] || { echo "session block does not exist: $BLOCK" >&2; exit 2; }
grep -q '^## ' "$BLOCK" || { echo "session block must contain a level-2 heading" >&2; exit 2; }

printf '\n\n---\n\n' >> "$TARGET"
cat "$BLOCK" >> "$TARGET"
