#!/usr/bin/env bash
# Extracts the finding list from a nested review's JSONL.
#
#   usage: extract-findings.sh <jsonl-path>
#
# Normal path: when CLAUDE_CODE_REPORT_FINDINGS=1 takes effect, the findings arrive as a single
# ReportFindings tool_use event rather than prose. Neither the env var nor the stream-json shape of
# ReportFindings is part of Claude Code's documented CLI surface — this is a pinned undocumented
# contract, and the prose fallback below is the safety net for the CLI update that drops it.
# Its .input is printed verbatim:
#   {level, findings:[{file, line, summary, short_summary, failure_scenario, category, verdict?}]}
#
# Fallback: no ReportFindings event means the CLI stopped honouring the env var. The last result
# event is printed as prose and the caller is told to report the round as degraded.
#
# Exit codes: 0 = structured, 2 = prose fallback, 3 = neither (do not guess at findings)
set -u

J="${1:?usage: extract-findings.sh <jsonl-path>}"

structured=$(jq -c 'select(.type=="assistant") | .message.content[]?
                    | select(.type=="tool_use" and .name=="ReportFindings") | .input' \
             "$J" 2>/dev/null | tail -1)

if [ -n "$structured" ]; then
  echo "$structured"
  # 32 is the ReportFindings schema cap on `findings`. Exactly 32 means the list was truncated,
  # so the caller must say so in the round comment instead of presenting it as the full set.
  n=$(printf '%s' "$structured" | jq '.findings | length' 2>/dev/null || echo 0)
  [ "$n" = "32" ] && echo "WARN: findings hit the schema cap of 32 — the list is truncated" >&2
  exit 0
fi

prose=$(jq -r 'select(.type=="result") | .result' "$J" 2>/dev/null | tail -1)

if [ -n "$prose" ]; then
  echo "WARN: no ReportFindings event — prose fallback. Report the round as degraded" >&2
  echo "$prose"
  exit 2
fi

echo "ERROR: neither a ReportFindings event nor a usable result. Do not guess at findings" >&2
exit 3
